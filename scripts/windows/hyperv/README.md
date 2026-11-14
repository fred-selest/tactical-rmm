# health-check-hyperv.ps1

Bilan de santé quotidien d'un hôte Hyper-V, lancé par une tâche Tactical RMM. En production sur HYPERV (CUISINEST), script RMM 267, tâche 1433.

| Contrôle | warn | fail |
|---|---|---|
| Volumes fixes (tous) | moins de 15 % libres | moins de 5 % libres, ou volume non sain |
| Disques physiques / RAID | | `HealthStatus` différent de Healthy |
| RAM de l'hôte | plus de 85 % | plus de 95 % |
| Services `vmms` et `vmcompute` | | non démarrés |
| Chaque VM | heartbeat dégradé | VM non démarrée (sauf `-IgnoreVM`) |
| Checkpoints de plus de 7 jours | présents | |
| VHDX dynamiques | croissance possible supérieure à l'espace libre | |
| Journal Hyper-V-VMMS-Admin, 24 h | erreurs présentes | |
| Redémarrage en attente | oui | |

Le script écrit une ligne JSON (`overall`, `problems`, `checks`). **Code retour : 1 si fail, sinon 0.** La tâche passe donc en « failing » dans le RMM, et déclenche l'alerte, seulement sur un vrai problème. L'ancienne version renvoyait toujours 0. Elle contrôlait aussi ADWS, DNS et NTDS, absents d'un hôte Hyper-V, et les comptait comme OK.

Arguments (`script_args`) : `-IgnoreVM 'VM1','VM2'` pour les VM volontairement arrêtées. Les seuils se règlent avec `-DiskWarnPct`, `-DiskFailPct`, `-RamWarnPct`, `-RamFailPct` et `-CheckpointMaxDays`. La liste `-IgnoreVM` est découpée par le script lui-même, car avec `powershell -File`, `'A','B'` arrive en une seule chaîne.

Tests réalisés sur l'hôte le 14/11/2026 :
- analyse syntaxique PowerShell : aucune erreur ;
- seuils forcés : `-DiskWarnPct 80` donne warn et le code 0, `-DiskFailPct 80` et `-RamFailPct 10` donnent fail et le code 1 ;
- `-IgnoreVM` fonctionne en `-File` comme en `-Command`.
