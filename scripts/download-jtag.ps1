[CmdletBinding()]
param([string]$Bitstream = '',[int]$DeviceIndex = 0)

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
. (Join-Path $PSScriptRoot 'common.ps1')
$projectName = Get-TemplateProjectName $root
$pdsRoot = if ($env:PANGO_PDS_ROOT) { $env:PANGO_PDS_ROOT } else { 'E:\APP\PDS\PDS_2022.2-SP6.4' }
$pdsBin = Join-Path $pdsRoot 'bin'
if (-not (Test-Path -LiteralPath $pdsBin)) { throw "PDS tools not found: $pdsBin. Set PANGO_PDS_ROOT to your PDS installation directory." }
if (-not $Bitstream) {$Bitstream = Join-Path $root "prj\$projectName.sbit"}
$env:SBIT_FILE = (Resolve-Path -LiteralPath $Bitstream).Path
$env:DEVICE_INDEX = [string]$DeviceIndex
$result = Invoke-CdtScript $root $pdsBin (Join-Path $PSScriptRoot 'download-jtag.tcl') 'jtag-download.log'
if ($result.Text -notmatch 'The done bit is 1') {throw "JTAG download completed without DONE=1: $($result.Log)"}
Write-Host 'RESULT: status=PASS tool=CDT step=jtag-download'