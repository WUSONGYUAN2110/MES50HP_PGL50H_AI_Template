[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent

function Fail([string]$Message) { throw "VALIDATION_ERROR: $Message" }
function Require-File([string]$RelativePath) {
    $path = Join-Path $root $RelativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { Fail "Missing required file: $RelativePath" }
}
function Read-RequiredConfig([string]$Name) {
    $escaped = [regex]::Escape($Name)
    $pattern = '(?m)^\s*set\s+template_config\(' + $escaped + '\)\s+(?:"([^"]*)"|\{([^}]*)\}|(\S+))\s*$'
    $match = [regex]::Match($config, $pattern)
    if (-not $match.Success) { Fail "Missing template_config($Name) in config.tcl" }
    if ($match.Groups[1].Success) { return $match.Groups[1].Value }
    if ($match.Groups[2].Success) { return $match.Groups[2].Value }
    return $match.Groups[3].Value
}

$requiredFiles = @(
    'AGENTS.md', 'config.tcl', 'doc/mes50hp_pinout.csv', 'doc/flash_list_usr_cd.cfl',
    'prj/run.tcl', 'prj/bootstrap/run.tcl', 'sim/run.do',
    'scripts/invoke-pango.ps1', 'scripts/clean-generated.ps1',
    'scripts/download-jtag.ps1', 'scripts/program-flash.ps1'
)
foreach ($file in $requiredFiles) { Require-File $file }

$config = Get-Content -LiteralPath (Join-Path $root 'config.tcl') -Raw
$projectName = Read-RequiredConfig 'project_name'
$topName = Read-RequiredConfig 'top_name'
$defaultTb = Read-RequiredConfig 'default_tb'
$enabledGroups = @((Read-RequiredConfig 'enabled_pin_groups') -split '\s+' | Where-Object { $_ })

if ($projectName -notmatch '^[A-Za-z][A-Za-z0-9_-]*$') { Fail "Invalid project_name: $projectName" }
if ([string]::IsNullOrWhiteSpace($topName)) { Fail 'top_name must not be empty' }
if ([string]::IsNullOrWhiteSpace($defaultTb)) { Fail 'default_tb must not be empty' }
if ($enabledGroups.Count -eq 0) { Fail 'enabled_pin_groups must not be empty' }

$csvPath = Join-Path $root 'doc/mes50hp_pinout.csv'
$rows = @(Import-Csv -LiteralPath $csvPath -Header group,port,pin,direction,vccio,standard,drive,clock_period,mode,description,manual_table | Select-Object -Skip 1)
if ($rows.Count -eq 0) { Fail 'mes50hp_pinout.csv contains no data rows' }
$knownGroups = @($rows | ForEach-Object group | Sort-Object -Unique)
foreach ($group in $enabledGroups) {
    if ($knownGroups -notcontains $group) { Fail "enabled pin group is not present in pinout CSV: $group" }
    $active = @($rows | Where-Object { $_.group -eq $group })
    if ($active.Count -eq 0) { Fail "enabled pin group has no rows: $group" }
    if (@($active | Where-Object { $_.mode -ne 'gpio' }).Count -gt 0) { Fail "enabled pin group contains non-gpio rows: $group" }
}

$activeRows = @($rows | Where-Object { $enabledGroups -contains $_.group })
$duplicatePins = @($activeRows | Group-Object pin | Where-Object Count -gt 1)
if ($duplicatePins.Count -gt 0) { Fail "enabled pin groups reuse package pins: $($duplicatePins.Name -join ', ')" }

foreach ($dir in @('rtl','sim')) {
    if (-not (Test-Path -LiteralPath (Join-Path $root $dir) -PathType Container)) { Fail "Missing source directory: $dir" }
}

$forbiddenTracked = @()
if ((Get-Command git -ErrorAction SilentlyContinue) -and (Test-Path -LiteralPath (Join-Path $root '.git') -PathType Container)) {
    $forbiddenTracked = @(git -C $root ls-files -- 'prj/work/*' 'prj/generated/*' 'sim/work/*' 'logs/*' '*.wlf' '*.sbit' '*.bin' 2> $null)
}
if ($forbiddenTracked.Count -gt 0) { Fail "Generated/runtime files are tracked: $($forbiddenTracked -join ', ')" }

Write-Host "VALIDATION_PASS: project=$projectName top=$topName groups=$($enabledGroups -join ',') rows=$($activeRows.Count)"
