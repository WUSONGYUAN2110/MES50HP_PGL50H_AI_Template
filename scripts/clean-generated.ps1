[CmdletBinding()]
param([switch]$IncludePublished)

$root = Split-Path $PSScriptRoot -Parent
. (Join-Path $PSScriptRoot 'common.ps1')
$projectName = Get-TemplateProjectName $root
foreach ($path in @('prj\work','prj\generated','sim\work','logs','log')) {
    Remove-Item -LiteralPath (Join-Path $root $path) -Recurse -Force -ErrorAction SilentlyContinue
}
foreach ($path in @('flow.pds','modelsim.ini','transcript','vsim.wlf')) {
    Remove-Item -LiteralPath (Join-Path $root $path) -Force -ErrorAction SilentlyContinue
}
Remove-Item -LiteralPath (Join-Path $root 'scripts\configuration_tcl.log') -Force -ErrorAction SilentlyContinue
if ($IncludePublished) {
    Remove-Item (Join-Path $root "prj\$projectName.sbit"),(Join-Path $root "prj\$projectName.bin") -Force -ErrorAction SilentlyContinue
}
