#!/bin/bash
# Surveillance PostgreSQL
# Alerte si problèmes de connexion, performance, ou espace disque

SEUIL_CONNEXIONS=80        # Alerte si > 80% des connexions max utilisées
SEUIL_ESPACE=85            # Alerte si utilisation espace > 85%
LOG_FILE="/var/log/tacticalrmm-postgresql-check.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Vérifier si PostgreSQL est installé et accessible
check_postgresql_available() {
    if ! command -v psql &> /dev/null; then
        echo "[ERREUR] PostgreSQL client non installé"
        return 1
    fi
    
    # Essayer de se connecter avec les credentials par défaut
    if ! psql -c "SELECT 1;" > /dev/null 2>&1; then
        echo "[ERREUR] Impossible de se connecter à PostgreSQL"
        echo "Assurez-vous que le fichier ~/.pgpass est configuré ou utilisez les variables d'environnement:"
        echo "  export PGHOST=localhost"
        echo "  export PGUSER=postgres"
        echo "  export PGPASSWORD=votre_mot_de_passe"
        return 1
    fi
    
    return 0
}

# Obtenir les statistiques PostgreSQL
get_postgresql_stats() {
    echo "=== Statistiques PostgreSQL ==="
    
    # Version
    VERSION=$(psql -t -c "SELECT version();" | head -1 | cut -d' ' -f2)
    echo "Version: $VERSION"
    
    # Uptime
    UPTIME=$(psql -t -c "SELECT date_trunc('second', current_timestamp - pg_postmaster_start_time()) AS uptime;" | tr -d ' ')
    echo "Uptime: $UPTIME"
    
    # Connexions
    MAX_CONNECTIONS=$(psql -t -c "SHOW max_connections;" | tr -d ' ')
    CURRENT_CONNECTIONS=$(psql -t -c "SELECT count(*) FROM pg_stat_activity;" | tr -d ' ')
    CONNECTIONS_PERCENT=$((CURRENT_CONNECTIONS * 100 / MAX_CONNECTIONS))
    
    echo "Connexions: $CURRENT_CONNECTIONS / $MAX_CONNECTIONS ($CONNECTIONS_PERCENT%)"
    
    # Requêtes en cours
    ACTIVE_QUERIES=$(psql -t -c "SELECT count(*) FROM pg_stat_activity WHERE state = 'active';" | tr -d ' ')
    echo "Requêtes actives: $ACTIVE_QUERIES"
    
    # Taille totale des bases de données
    TOTAL_SIZE=$(psql -t -c "SELECT pg_size_pretty(sum(pg_database_size(datname))::bigint) FROM pg_database;" | tr -d ' ')
    echo "Taille totale: $TOTAL_SIZE"
    
    # Cache hit ratio
    CACHE_HIT_RATIO=$(psql -t -c "SELECT round(blks_hit::float/(blks_hit+blks_read)*100, 2) FROM pg_stat_database WHERE datname = current_database();" | tr -d ' ')
    if [ "$CACHE_HIT_RATIO" != "NaN" ]; then
        echo "Cache hit ratio: ${CACHE_HIT_RATIO}%"
    fi
}

# Vérifier l'espace disque utilisé par PostgreSQL
check_postgresql_disk_usage() {
    echo ""
    echo "--- Utilisation espace disque PostgreSQL ---"
    
    # Trouver le répertoire de données PostgreSQL
    DATA_DIR=$(psql -t -c "SHOW data_directory;" | tr -d ' ')
    
    if [ -d "$DATA_DIR" ]; then
        echo "Répertoire des données: $DATA_DIR"
        du -sh "$DATA_DIR"
        
        # Vérifier l'utilisation du système de fichiers
        USAGE=$(df -h "$DATA_DIR" | awk 'NR==2 {print $5}' | tr -d '%')
        echo "Utilisation système de fichiers: ${USAGE}%"
        
        if [ "$USAGE" -gt "$SEUIL_ESPACE" ]; then
            echo "[ALERTE] Espace disque PostgreSQL > ${SEUIL_ESPACE}%"
            return 1
        fi
    else
        echo "Répertoire des données non trouvé"
    fi
    
    return 0
}

# Vérifier les tables volumineuses
check_large_tables() {
    echo ""
    echo "--- Top 10 tables volumineuses ---"
    
    psql -c "SELECT 
        schemaname AS schema,
        tablename AS table,
        pg_size_pretty(pg_total_relation_size(schemaname || '.' || tablename)) AS size,
        pg_size_pretty(pg_total_relation_size(schemaname || '.' || tablename) - pg_relation_size(schemaname || '.' || tablename)) AS external
    FROM pg_tables 
    WHERE schemaname NOT IN ('information_schema', 'pg_catalog')
    ORDER BY pg_total_relation_size(schemaname || '.' || tablename) DESC 
    LIMIT 10;"
}

# Vérifier les requêtes longues
check_long_queries() {
    echo ""
    echo "--- Requêtes longues (> 5 minutes) ---"
    
    LONG_QUERIES=$(psql -t -c "SELECT count(*) FROM pg_stat_activity WHERE state = 'active' AND now() - query_start > interval '5 minutes';" | tr -d ' ')
    
    if [ "$LONG_QUERIES" -gt 0 ]; then
        echo "[ALERTE] $LONG_QUERIES requêtes longues détectées"
        psql -c "SELECT 
            pid,
            usename,
            application_name,
            client_addr,
            now() - query_start AS duration,
            state,
            left(query, 50) AS query_preview
        FROM pg_stat_activity 
        WHERE state = 'active' AND now() - query_start > interval '5 minutes'
        ORDER BY duration DESC;"
        return 1
    else
        echo "Aucune requête longue"
    fi
    
    return 0
}

# Vérifier les verrous bloquants
check_blocking_locks() {
    echo ""
    echo "--- Verrous bloquants ---"
    
    BLOCKING_LOCKS=$(psql -t -c "SELECT count(*) FROM pg_stat_activity WHERE wait_event_type = 'Lock';" | tr -d ' ')
    
    if [ "$BLOCKING_LOCKS" -gt 0 ]; then
        echo "[ALERTE] $BLOCKING_LOCKS verrous bloquants détectés"
        psql -c "SELECT 
            blocked_locks.pid AS blocked_pid,
            blocked_activity.usename AS blocked_user,
            blocking_locks.pid AS blocking_pid,
            blocking_activity.usename AS blocking_user,
            blocked_activity.query AS blocked_statement,
            blocking_activity.query AS blocking_statement
        FROM pg_catalog.pg_locks blocked_locks
        JOIN pg_catalog.pg_stat_activity blocked_activity ON blocked_activity.pid = blocked_locks.pid
        JOIN pg_catalog.pg_locks blocking_locks 
            ON blocking_locks.locktype = blocked_locks.locktype
            AND blocking_locks.DATABASE IS NOT DISTINCT FROM blocked_locks.DATABASE
            AND blocking_locks.relation IS NOT DISTINCT FROM blocked_locks.relation
            AND blocking_locks.page IS NOT DISTINCT FROM blocked_locks.page
            AND blocking_locks.tuple IS NOT DISTINCT FROM blocked_locks.tuple
            AND blocking_locks.virtualxid IS NOT DISTINCT FROM blocked_locks.virtualxid
            AND blocking_locks.transactionid IS NOT DISTINCT FROM blocked_locks.transactionid
            AND blocking_locks.classid IS NOT DISTINCT FROM blocked_locks.classid
            AND blocking_locks.objid IS NOT DISTINCT FROM blocked_locks.objid
            AND blocking_locks.objsubid IS NOT DISTINCT FROM blocked_locks.objsubid
            AND blocking_locks.pid != blocked_locks.pid
        JOIN pg_catalog.pg_stat_activity blocking_activity ON blocking_activity.pid = blocking_locks.pid
        WHERE NOT blocked_locks.GRANTED
        LIMIT 5;"
        return 1
    else
        echo "Aucun verrou bloquant"
    fi
    
    return 0
}

# Vérifier l'autovacuum
check_autovacuum() {
    echo ""
    echo "--- État de l'autovacuum ---"
    
    AUTOVACUUM_RUNNING=$(psql -t -c "SELECT count(*) FROM pg_stat_activity WHERE query LIKE '%autovacuum%';" | tr -d ' ')
    if [ "$AUTOVACUUM_RUNNING" -gt 0 ]; then
        echo "Processus autovacuum actifs: $AUTOVACUUM_RUNNING"
    else
        echo "Pas de processus autovacuum actif"
    fi
    
    # Tables nécessitant un vacuum
    TABLES_NEEDING_VACUUM=$(psql -t -c "SELECT count(*) FROM pg_stat_user_tables WHERE n_dead_tup > 10000;" | tr -d ' ')
    if [ "$TABLES_NEEDING_VACUUM" -gt 0 ]; then
        echo "[ALERTE] $TABLES_NEEDING_VACUUM tables nécessitent un VACUUM"
        psql -c "SELECT schemaname, relname, n_dead_tup FROM pg_stat_user_tables WHERE n_dead_tup > 10000 ORDER BY n_dead_tup DESC LIMIT 5;"
        return 1
    fi
    
    return 0
}

echo "=== Surveillance PostgreSQL ==="
echo ""

# Vérification initiale
if ! check_postgresql_available; then
    exit 1
fi

get_postgresql_stats

ALERTE=0

# Vérifier l'espace disque
if ! check_postgresql_disk_usage; then
    ALERTE=1
fi

# Vérifier les tables volumineuses
check_large_tables

# Vérifier les requêtes longues
if ! check_long_queries; then
    ALERTE=1
fi

# Vérifier les verrous bloquants
if ! check_blocking_locks; then
    ALERTE=1
fi

# Vérifier l'autovacuum
if ! check_autovacuum; then
    ALERTE=1
fi

# Vérifier les connexions
MAX_CONNECTIONS=$(psql -t -c "SHOW max_connections;" | tr -d ' ')
CURRENT_CONNECTIONS=$(psql -t -c "SELECT count(*) FROM pg_stat_activity;" | tr -d ' ')
CONNECTIONS_PERCENT=$((CURRENT_CONNECTIONS * 100 / MAX_CONNECTIONS))

if [ "$CONNECTIONS_PERCENT" -gt "$SEUIL_CONNEXIONS" ]; then
    echo "[ALERTE] Utilisation des connexions > ${SEUIL_CONNEXIONS}% ($CONNECTIONS_PERCENT%)"
    ALERTE=1
fi

# Journaliser le résultat
if [ $ALERTE -eq 1 ]; then
    log "ALERTE: Problèmes PostgreSQL détectés"
else
    log "OK: PostgreSQL fonctionne normalement"
fi

exit $ALERTE