[CmdletBinding()]
param([string]$Image = '',[int]$DeviceIndex = 0)

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
. (Join-Path $PSScriptRoot 'common.ps1')
$projectName = Get-TemplateProjectName $root
$pdsRoot = if ($env:PANGO_PDS_ROOT) { $env:PANGO_PDS_ROOT } else { 'E:\APP\PDS\PDS_2022.2-SP6.4' }
$pdsBin = Join-Path $pdsRoot 'bin'
$flashDb = Join-Path $pdsRoot 'arch\vendor\pango\arch\cdt\flash_list_usr_cd.cfl'
if (-not (Test-Path -LiteralPath $pdsBin)) { throw "PDS tools not found: $pdsBin. Set PANGO_PDS_ROOT to your PDS installation directory." }
if (-not $Image) {$Image = Join-Path $root "prj\$projectName.bin"}
$env:FLASH_FILE = (Resolve-Path -LiteralPath $Image).Path
$env:DEVICE_INDEX = [string]$DeviceIndex
$env:BOOT_WAIT_MS = Get-TemplateScalarSetting $root 'flash_boot_wait_ms'

$logDir = Join-Path $root 'logs'
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$sourceFlashDb = Join-Path $root 'doc\flash_list_usr_cd.cfl'
$backupFlashDb = Join-Path $logDir ("flash-list-backup-" + [guid]::NewGuid().ToString('N') + '.cfl')
$hadFlashDb = Test-Path -LiteralPath $flashDb
if ($hadFlashDb) {Copy-Item -LiteralPath $flashDb -Destination $backupFlashDb -Force}

try {
    Copy-Item -LiteralPath $sourceFlashDb -Destination $flashDb -Force
    $result = Invoke-CdtScript $root $pdsBin (Join-Path $PSScriptRoot 'program-flash.tcl') 'flash-program.log'
    $bootCheck = [regex]::Match($result.Text,'(?s)BOOT_CHECK_BEGIN(.*?)BOOT_CHECK_END')
    if (-not $bootCheck.Success -or $bootCheck.Groups[1].Value -notmatch 'done bit\):\s*1') {
        throw "Flash was verified but boot check did not reach DONE=1: $($result.Log)"
    }
    Write-Host 'RESULT: status=PASS tool=CDT step=flash-program-and-boot'
} finally {
    if ($hadFlashDb) {
        Copy-Item -LiteralPath $backupFlashDb -Destination $flashDb -Force
    } else {
        Remove-Item -LiteralPath $flashDb -Force -ErrorAction SilentlyContinue
    }
    Remove-Item -LiteralPath $backupFlashDb -Force -ErrorAction SilentlyContinue
}