# health-check-hyperv.ps1 - Bilan de sante d'un hote Hyper-V (tache quotidienne Tactical RMM)
# PowerShell 5.1, module Hyper-V natif, aucune dependance externe.
#
# Controles : volumes fixes, disques physiques, RAM, services vmms/vmcompute,
# etat + heartbeat de chaque VM, anciens checkpoints, croissance possible des
# VHDX dynamiques vs espace libre, erreurs VMMS sur 24 h, redemarrage en attente.
#
# Sortie : une ligne JSON (derniere ligne de stdout).
# Code retour : 0 = pass ou warn, 1 = fail. La tache passe donc en "failing"
# dans le RMM (et declenche l'alerte) uniquement sur un vrai probleme.
#
# Arguments (script_args de la tache) :
#   -IgnoreVM 'Nom1','Nom2'   VM volontairement arretees, non controlees
#   -DiskWarnPct 15 -DiskFailPct 5 -RamWarnPct 85 -RamFailPct 95 -CheckpointMaxDays 7
param(
    [string[]]$IgnoreVM = @(),
    [int]$DiskWarnPct = 15,
    [int]$DiskFailPct = 5,
    [int]$RamWarnPct = 85,
    [int]$RamFailPct = 95,
    [int]$CheckpointMaxDays = 7
)
$ErrorActionPreference = 'Stop'
# Avec "powershell -File", 'A','B' arrive en une seule chaine : on decoupe ici.
$IgnoreVM = @($IgnoreVM | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim(" '`"") } | Where-Object { $_ })
$rank = @{ pass = 0; warn = 1; fail = 2 }
$script:overall = 'pass'
$problems = New-Object System.Collections.Generic.List[string]
function Set-Level([string]$level, [string]$why) {
    if ($rank[$level] -gt $rank[$script:overall]) { $script:overall = $level }
    if ($level -ne 'pass') { $problems.Add("${level}: $why") }
}
$checks = [ordered]@{}

# ---------- Volumes fixes (tous, pas seulement C/D) ----------
$vols = @()
try {
    foreach ($v in Get-Volume | Where-Object { $_.DriveLetter -and $_.DriveType -eq 'Fixed' -and $_.Size -gt 0 }) {
        $pct = [math]::Round(100 * $v.SizeRemaining / $v.Size, 1)
        $lvl = if ($pct -lt $DiskFailPct) { 'fail' } elseif ($pct -lt $DiskWarnPct) { 'warn' } else { 'pass' }
        if ($v.HealthStatus -ne 'Healthy') { $lvl = 'fail' }
        Set-Level $lvl "volume $($v.DriveLetter): $pct% libre, $($v.HealthStatus)"
        $vols += [ordered]@{ drive = "$($v.DriveLetter):"; free_gb = [math]::Round($v.SizeRemaining / 1GB, 1); total_gb = [math]::Round($v.Size / 1GB, 1); free_pct = $pct; health = "$($v.HealthStatus)"; level = $lvl }
    }
    if ($vols.Count -eq 0) { Set-Level 'fail' 'aucun volume fixe lu' }
} catch { Set-Level 'fail' "lecture volumes: $($_.Exception.Message)" }
$checks.volumes = $vols

# ---------- Disques physiques / RAID ----------
$pd = @()
try {
    foreach ($d in Get-PhysicalDisk) {
        $ok = ("$($d.HealthStatus)" -eq 'Healthy')
        if (-not $ok) { Set-Level 'fail' "disque $($d.FriendlyName): $($d.HealthStatus)/$($d.OperationalStatus)" }
        $pd += [ordered]@{ name = $d.FriendlyName; media = "$($d.MediaType)"; health = "$($d.HealthStatus)"; status = "$($d.OperationalStatus)" }
    }
} catch { Set-Level 'warn' "lecture disques physiques: $($_.Exception.Message)" }
$checks.physical_disks = $pd

# ---------- RAM de l'hote ----------
$os = Get-CimInstance Win32_OperatingSystem
$used = [math]::Round(100 * (1 - $os.FreePhysicalMemory / $os.TotalVisibleMemorySize), 1)
$lvl = if ($used -gt $RamFailPct) { 'fail' } elseif ($used -gt $RamWarnPct) { 'warn' } else { 'pass' }
Set-Level $lvl "RAM utilisee $used%"
$checks.ram = [ordered]@{ used_pct = $used; total_gb = [math]::Round($os.TotalVisibleMemorySize / 1MB, 1); level = $lvl }

# ---------- Services Hyper-V ----------
$svc = [ordered]@{}
foreach ($n in 'vmms', 'vmcompute') {
    $s = Get-Service -Name $n -ErrorAction SilentlyContinue
    $st = if ($s) { "$($s.Status)" } else { 'NotInstalled' }
    if ($st -ne 'Running') { Set-Level 'fail' "service $n $st" }
    $svc[$n] = $st
}
$checks.services = $svc

# ---------- VM : etat, heartbeat, checkpoints ----------
$vmlist = @()
$vhdGrowthGb = @{}
if ($svc['vmms'] -eq 'Running') {
    try {
        foreach ($vm in Get-VM) {
            $ignored = $IgnoreVM -contains $vm.Name
            $state = "$($vm.State)"; $hb = "$($vm.Heartbeat)"
            $lvl = 'pass'
            if (-not $ignored) {
                if ($state -ne 'Running') { $lvl = 'fail'; Set-Level 'fail' "VM $($vm.Name) $state" }
                elseif ($hb -and $hb -notlike 'Ok*' -and $hb -ne 'NoContact' ) { $lvl = 'warn'; Set-Level 'warn' "VM $($vm.Name) heartbeat $hb" }
            }
            $old = @(Get-VMSnapshot -VM $vm -ErrorAction SilentlyContinue | Where-Object { $_.CreationTime -lt (Get-Date).AddDays(-$CheckpointMaxDays) })
            if ($old.Count -gt 0) { Set-Level 'warn' "VM $($vm.Name): $($old.Count) checkpoint(s) > $CheckpointMaxDays j" }
            foreach ($hd in Get-VMHardDiskDrive -VM $vm) {
                $vhd = Get-VHD -Path $hd.Path -ErrorAction SilentlyContinue
                if ($vhd -and "$($vhd.VhdType)" -ne 'Fixed') {
                    $root = [System.IO.Path]::GetPathRoot($hd.Path).Substring(0, 2)
                    $vhdGrowthGb[$root] = [double]$vhdGrowthGb[$root] + ($vhd.Size - $vhd.FileSize) / 1GB
                }
            }
            $vmlist += [ordered]@{ name = $vm.Name; state = $state; heartbeat = $hb; uptime_h = [int]$vm.Uptime.TotalHours; old_checkpoints = $old.Count; ignored = $ignored; level = $lvl }
        }
    } catch { Set-Level 'fail' "lecture VM: $($_.Exception.Message)" }
}
$checks.vms = $vmlist

# ---------- Sur-allocation des VHDX dynamiques ----------
$growth = @()
foreach ($drv in $vhdGrowthGb.Keys) {
    $vol = $vols | Where-Object { $_.drive -eq $drv }
    $g = [math]::Round($vhdGrowthGb[$drv], 1)
    if ($vol -and $g -gt $vol.free_gb) { Set-Level 'warn' "VHDX dynamiques sur ${drv}: +$g Go possibles pour $($vol.free_gb) Go libres" }
    $growth += [ordered]@{ drive = $drv; max_growth_gb = $g; free_gb = $(if ($vol) { $vol.free_gb } else { $null }) }
}
$checks.vhdx_overcommit = $growth

# ---------- Journal Hyper-V VMMS : erreurs 24 h ----------
$evt = 0
try { $evt = @(Get-WinEvent -FilterHashtable @{ LogName = 'Microsoft-Windows-Hyper-V-VMMS-Admin'; Level = 1, 2; StartTime = (Get-Date).AddHours(-24) } -ErrorAction Stop).Count }
catch { if ($_.Exception.Message -notmatch 'No events|Aucun') { $evt = -1 } }
if ($evt -gt 0) { Set-Level 'warn' "$evt erreur(s) Hyper-V-VMMS sur 24 h" }
$checks.vmms_errors_24h = $evt

# ---------- Redemarrage en attente / uptime ----------
$pending = (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending') -or
           (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired')
$uptimeD = [math]::Round(((Get-Date) - $os.LastBootUpTime).TotalDays, 1)
if ($pending) { Set-Level 'warn' "redemarrage en attente (uptime $uptimeD j)" }
$checks.host = [ordered]@{ os = $os.Caption; uptime_days = $uptimeD; reboot_pending = $pending }

# ---------- Resultat ----------
$result = [ordered]@{
    check     = 'hyperv-health'
    host      = $env:COMPUTERNAME
    timestamp = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    overall   = $script:overall
    problems  = @($problems)
    checks    = $checks
}
Write-Output ($result | ConvertTo-Json -Depth 6 -Compress)
if ($script:overall -eq 'fail') { exit 1 } else { exit 0 }
