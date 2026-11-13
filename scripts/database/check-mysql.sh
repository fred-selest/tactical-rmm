#!/bin/bash
# Surveillance MySQL/MariaDB
# Alerte si problèmes de connexion, performance, ou espace disque

SEUIL_CONNEXIONS=80        # Alerte si > 80% des connexions max utilisées
SEUIL_SLOW_QUERIES=10      # Alerte si > 10 requêtes lentes par minute
SEUIL_ESPACE=85            # Alerte si utilisation espace > 85%
LOG_FILE="/var/log/tacticalrmm-mysql-check.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Vérifier si MySQL est installé et accessible
check_mysql_available() {
    if ! command -v mysql &> /dev/null; then
        echo "[ERREUR] MySQL client non installé"
        return 1
    fi
    
    # Essayer de se connecter avec les credentials par défaut
    if ! mysql -e "SELECT 1;" > /dev/null 2>&1; then
        echo "[ERREUR] Impossible de se connecter à MySQL"
        echo "Assurez-vous que le fichier ~/.my.cnf est configuré ou utilisez les variables d'environnement:"
        echo "  export MYSQL_HOST=localhost"
        echo "  export MYSQL_USER=root"
        echo "  export MYSQL_PASSWORD=votre_mot_de_passe"
        return 1
    fi
    
    return 0
}

# Obtenir les statistiques MySQL
get_mysql_stats() {
    echo "=== Statistiques MySQL ==="
    
    # Version
    VERSION=$(mysql -N -e "SELECT VERSION();")
    echo "Version: $VERSION"
    
    # Uptime
    UPTIME=$(mysql -N -e "SHOW GLOBAL STATUS LIKE 'Uptime';" | awk '{print $2}')
    UPTIME_HOURS=$((UPTIME / 3600))
    echo "Uptime: $UPTIME_HOURS heures"
    
    # Connexions
    MAX_CONNECTIONS=$(mysql -N -e "SHOW VARIABLES LIKE 'max_connections';" | awk '{print $2}')
    CURRENT_CONNECTIONS=$(mysql -N -e "SHOW STATUS LIKE 'Threads_connected';" | awk '{print $2}')
    CONNECTIONS_PERCENT=$((CURRENT_CONNECTIONS * 100 / MAX_CONNECTIONS))
    
    echo "Connexions: $CURRENT_CONNECTIONS / $MAX_CONNECTIONS ($CONNECTIONS_PERCENT%)"
    
    # Requêtes par seconde
    QUESTIONS=$(mysql -N -e "SHOW GLOBAL STATUS LIKE 'Questions';" | awk '{print $2}')
    QUERIES_PER_SECOND=$((QUESTIONS / UPTIME))
    echo "Requêtes/seconde: $QUERIES_PER_SECOND"
    
    # Buffer pool (pour InnoDB)
    if mysql -N -e "SHOW ENGINE INNODB STATUS;" > /dev/null 2>&1; then
        BUFFER_POOL_SIZE=$(mysql -N -e "SHOW VARIABLES LIKE 'innodb_buffer_pool_size';" | awk '{print $2}')
        BUFFER_POOL_READS=$(mysql -N -e "SHOW GLOBAL STATUS LIKE 'Innodb_buffer_pool_read_requests';" | awk '{print $2}')
        BUFFER_POOL_READS_MISSED=$(mysql -N -e "SHOW GLOBAL STATUS LIKE 'Innodb_buffer_pool_reads';" | awk '{print $2}')
        
        if [ "$BUFFER_POOL_READS" -gt 0 ]; then
            HIT_RATIO=$((100 - (BUFFER_POOL_READS_MISSED * 100 / BUFFER_POOL_READS)))
            echo "Buffer pool hit ratio: ${HIT_RATIO}%"
        fi
    fi
    
    # Requêtes lentes
    SLOW_QUERIES=$(mysql -N -e "SHOW GLOBAL STATUS LIKE 'Slow_queries';" | awk '{print $2}')
    echo "Requêtes lentes totales: $SLOW_QUERIES"
    
    # Verrous
    TABLE_LOCKS_WAITED=$(mysql -N -e "SHOW GLOBAL STATUS LIKE 'Table_locks_waited';" | awk '{print $2}')
    if [ "$TABLE_LOCKS_WAITED" -gt 0 ]; then
        echo "Verrous tables attendus: $TABLE_LOCKS_WAITED"
    fi
}

# Vérifier l'espace disque utilisé par MySQL
check_mysql_disk_usage() {
    echo ""
    echo "--- Utilisation espace disque MySQL ---"
    
    # Trouver le répertoire de données MySQL
    DATA_DIR=$(mysql -N -e "SHOW VARIABLES LIKE 'datadir';" | awk '{print $2}')
    
    if [ -d "$DATA_DIR" ]; then
        echo "Répertoire des données: $DATA_DIR"
        du -sh "$DATA_DIR"
        
        # Vérifier l'utilisation du système de fichiers
        USAGE=$(df -h "$DATA_DIR" | awk 'NR==2 {print $5}' | tr -d '%')
        echo "Utilisation système de fichiers: ${USAGE}%"
        
        if [ "$USAGE" -gt "$SEUIL_ESPACE" ]; then
            echo "[ALERTE] Espace disque MySQL > ${SEUIL_ESPACE}%"
            return 1
        fi
    else
        echo "Répertoire des données non trouvé"
    fi
    
    return 0
}

# Vérifier les tables corrompues
check_corrupted_tables() {
    echo ""
    echo "--- Vérification tables corrompues ---"
    
    # Cette vérification peut être longue, donc on la fait de manière sélective
    echo "Tables MyISAM avec état != OK:"
    mysql -N -e "SELECT table_schema, table_name, table_type, engine FROM information_schema.tables WHERE engine = 'MyISAM' AND table_schema NOT IN ('mysql', 'information_schema', 'performance_schema');" | while read db table type engine; do
        if [ -n "$db" ] && [ -n "$table" ]; then
            CHECK_RESULT=$(mysqlcheck -c "$db" "$table" 2>&1 | grep -v "OK")
            if [ -n "$CHECK_RESULT" ]; then
                echo "[ALERTE] Table corrompue: $db.$table"
                echo "  $CHECK_RESULT"
            fi
        fi
    done
    
    # Pour InnoDB, vérifier les erreurs dans le log
    echo "Vérification erreurs InnoDB dans les logs (si disponible):"
    if [ -f "/var/log/mysql/error.log" ]; then
        ERRORS=$(grep -i "innodb.*error" /var/log/mysql/error.log | tail -5)
        if [ -n "$ERRORS" ]; then
            echo "[ALERTE] Erreurs InnoDB détectées:"
            echo "$ERRORS"
        fi
    elif [ -f "/var/log/mysqld.log" ]; then
        ERRORS=$(grep -i "innodb.*error" /var/log/mysqld.log | tail -5)
        if [ -n "$ERRORS" ]; then
            echo "[ALERTE] Erreurs InnoDB détectées:"
            echo "$ERRORS"
        fi
    fi
}

# Vérifier les réplications (si configurées)
check_replication() {
    echo ""
    echo "--- État de la réplication ---"
    
    SLAVE_STATUS=$(mysql -N -e "SHOW SLAVE STATUS\G" 2>/dev/null)
    if [ -n "$SLAVE_STATUS" ]; then
        IO_RUNNING=$(echo "$SLAVE_STATUS" | grep "Slave_IO_Running:" | awk '{print $2}')
        SQL_RUNNING=$(echo "$SLAVE_STATUS" | grep "Slave_SQL_Running:" | awk '{print $2}')
        SECONDS_BEHIND=$(echo "$SLAVE_STATUS" | grep "Seconds_Behind_Master:" | awk '{print $2}')
        
        echo "IO Thread: $IO_RUNNING"
        echo "SQL Thread: $SQL_RUNNING"
        echo "Retard: $SECONDS_BEHIND secondes"
        
        if [ "$IO_RUNNING" != "Yes" ] || [ "$SQL_RUNNING" != "Yes" ]; then
            echo "[ALERTE] Problème de réplication détecté!"
            return 1
        fi
        
        if [ "$SECONDS_BEHIND" -gt 300 ]; then
            echo "[ALERTE] Réplication en retard de plus de 5 minutes!"
            return 1
        fi
    else
        echo "Pas de réplication configurée"
    fi
    
    return 0
}

# Vérifier les processus bloquants
check_blocking_processes() {
    echo ""
    echo "--- Processus bloquants ---"
    
    BLOCKING=$(mysql -N -e "SELECT COUNT(*) FROM information_schema.processlist WHERE TIME > 60 AND COMMAND != 'Sleep';")
    if [ "$BLOCKING" -gt 0 ]; then
        echo "[ALERTE] $BLOCKING processus bloquants détectés (> 60 secondes)"
        mysql -e "SELECT ID, USER, HOST, DB, COMMAND, TIME, STATE, INFO FROM information_schema.processlist WHERE TIME > 60 AND COMMAND != 'Sleep';"
        return 1
    else
        echo "Aucun processus bloquant"
    fi
    
    return 0
}

echo "=== Surveillance MySQL ==="
echo ""

# Vérification initiale
if ! check_mysql_available; then
    exit 1
fi

get_mysql_stats

ALERTE=0

# Vérifier l'espace disque
if ! check_mysql_disk_usage; then
    ALERTE=1
fi

# Vérifier les tables corrompues
check_corrupted_tables

# Vérifier la réplication
if ! check_replication; then
    ALERTE=1
fi

# Vérifier les processus bloquants
if ! check_blocking_processes; then
    ALERTE=1
fi

# Vérifier les connexions
MAX_CONNECTIONS=$(mysql -N -e "SHOW VARIABLES LIKE 'max_connections';" | awk '{print $2}')
CURRENT_CONNECTIONS=$(mysql -N -e "SHOW STATUS LIKE 'Threads_connected';" | awk '{print $2}')
CONNECTIONS_PERCENT=$((CURRENT_CONNECTIONS * 100 / MAX_CONNECTIONS))

if [ "$CONNECTIONS_PERCENT" -gt "$SEUIL_CONNEXIONS" ]; then
    echo "[ALERTE] Utilisation des connexions > ${SEUIL_CONNEXIONS}% ($CONNECTIONS_PERCENT%)"
    ALERTE=1
fi

# Journaliser le résultat
if [ $ALERTE -eq 1 ]; then
    log "ALERTE: Problèmes MySQL détectés"
else
    log "OK: MySQL fonctionne normalement"
fi

exit $ALERTE