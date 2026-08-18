[CmdletBinding()]
param(
    [Parameter(Mandatory,Position=0)]
    [ValidateSet('check','sim','compile','synth','pnr','timing','build','all')]
    [string]$Step
)

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
. (Join-Path $PSScriptRoot 'common.ps1')
$projectName = Get-TemplateProjectName $root
$logDir = Join-Path $root 'logs'
$pdsRoot = if ($env:PANGO_PDS_ROOT) { $env:PANGO_PDS_ROOT } else { 'E:\APP\PDS\PDS_2022.2-SP6.4' }
$pds = Join-Path $pdsRoot 'bin\pds_shell.exe'
$modelsimRoot = if ($env:PANGO_MODELSIM_ROOT) { $env:PANGO_MODELSIM_ROOT } else { 'E:\APP\ModelSim' }
$vsim = Join-Path $modelsimRoot 'win64\vsim.exe'
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
if (-not (Test-Path -LiteralPath $pds)) { throw "PDS executable not found: $pds. Set PANGO_PDS_ROOT to your PDS installation directory." }
if (-not (Test-Path -LiteralPath $vsim)) { throw "ModelSim executable not found: $vsim. Set PANGO_MODELSIM_ROOT to your ModelSim installation directory." }

function Invoke-ModelSim {
    $log = Join-Path $logDir 'modelsim-sim.log'
    $transcript = Join-Path $logDir 'modelsim-transcript.log'
    $runDo = (Join-Path $root 'sim\run.do').Replace('\','/')
    $env:MES50HP_TEMPLATE_ROOT = $root
    Write-Host 'RUN: tool=ModelSim step=sim'
    Write-Host "LOG: $log"
    Push-Location $logDir
    $ErrorActionPreference = 'Continue'
    $output = & $vsim -c -l $transcript -do "do {$runDo}" 2>&1
    $code = $LASTEXITCODE
    $ErrorActionPreference = 'Stop'
    Pop-Location
    $output | Set-Content -LiteralPath $log -Encoding utf8
    $text = Get-Content -LiteralPath $log -Raw
    if ($code -ne 0 -or $text -notmatch 'TEST_PASS' -or $text -match '(?m)^\s*(\*\* Error:|# Error:)') {
        Write-Host 'RESULT: status=FAIL tool=ModelSim step=sim'
        throw "ModelSim failed: $log"
    }
    Write-Host 'SUCCESS: ModelSim step sim completed.'
    Write-Host 'RESULT: status=PASS tool=ModelSim step=sim'
}

function Test-PdsQuality([string]$PdsStep,[string]$Text,[string]$Work) {
    if ($Text -match '(?m)^\s*E:') {throw 'PDS emitted an error record.'}

    $allowedPorts = @(Get-TemplateListSetting $root 'allowed_unconstrained_ports')
    $unconstrained = [regex]::Matches($Text,"(?m)^\s*W:\s+Timing-408[67]:\s+Port '([^']+)' is not constrained")
    foreach ($match in $unconstrained) {
        $port = $match.Groups[1].Value
        if ($allowedPorts -notcontains $port) {throw "Unconstrained port is not allowed: $port"}
    }

    $timingWarnings = [regex]::Matches($Text,'(?m)^\s*W:\s+(Timing-\d+):')
    foreach ($match in $timingWarnings) {
        if ($match.Groups[1].Value -notin @('Timing-4086','Timing-4087')) {
            throw "Unhandled PDS timing warning: $($match.Groups[1].Value)"
        }
    }

    if ($PdsStep -in @('timing','all')) {
        $reports = @(Get-ChildItem -LiteralPath (Join-Path $Work 'report_timing') -Filter '*.rtr' -File)
        if ($reports.Count -ne 1) {throw "Expected one timing report, found $($reports.Count)."}
        $report = Get-Content -LiteralPath $reports[0].FullName -Raw
        if ($report -notmatch 'Design Summary\s*:\s*All Constraints Met\.' -or $report -match 'Slack\s+\(VIOLATED\)') {
            throw "Timing constraints are not met: $($reports[0].FullName)"
        }
    }
}

function Invoke-Pds([string]$PdsStep,[string]$PublicStep) {
    $work = Join-Path $root 'prj\work'
    Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Force -Path $work | Out-Null
    $bootstrap = Join-Path $root 'prj\bootstrap\run.tcl'

    $log = Join-Path $logDir "pds-$PublicStep.log"
    $env:PDS_STEP = $PdsStep
    $env:MES50HP_TEMPLATE_ROOT = $root
    Write-Host "RUN: tool=PDS step=$PublicStep"
    Write-Host "LOG: $log"

    Push-Location $work
    $ErrorActionPreference = 'Continue'
    $bootOutput = & $pds -file $bootstrap 2>&1
    $code = $LASTEXITCODE
    $flowOutput = @()
    if ($code -eq 0) {
        $flowOutput = & $pds -file (Join-Path $root 'prj\run.tcl') 2>&1
        $code = $LASTEXITCODE
    }
    $ErrorActionPreference = 'Stop'
    Pop-Location

    $text = (@($bootOutput) + @($flowOutput) | Out-String)
    $text = [regex]::Replace($text,'(?s)\s*Executing : synthesize -ads -help.*?Executing : synthesize -help successfully\.\s*','')
    $text | Set-Content -LiteralPath $log -Encoding utf8
    if ($code -ne 0 -or $text -notmatch "SUCCESS: PDS step") {
        Write-Host "RESULT: status=FAIL tool=PDS step=$PublicStep"
        throw "PDS failed: $log"
    }
    try {
        Test-PdsQuality $PdsStep $text $work
    } catch {
        Add-Content -LiteralPath $log -Encoding utf8 -Value "QUALITY_FAIL: $($_.Exception.Message)"
        Write-Host "RESULT: status=FAIL tool=PDS step=$PublicStep"
        throw
    }
    Add-Content -LiteralPath $log -Encoding utf8 -Value 'QUALITY_PASS: errors=0 timing=met unconstrained=allowlisted'

    if ($PdsStep -eq 'all') {
        $bitDir = Join-Path $work 'generate_bitstream'
        $sbit = @(Get-ChildItem -LiteralPath $bitDir -Filter '*.sbit' -File)
        $bin = @(Get-ChildItem -LiteralPath $bitDir -Filter '*.bin' -File)
        if ($sbit.Count -ne 1 -or $bin.Count -ne 1) {throw 'Expected one SBIT and one BIN.'}
        Copy-Item $sbit[0].FullName (Join-Path $root "prj\$projectName.sbit") -Force
        Copy-Item $bin[0].FullName (Join-Path $root "prj\$projectName.bin") -Force
    }
    Write-Host "SUCCESS: PDS step $PublicStep completed."
    Write-Host "RESULT: status=PASS tool=PDS step=$PublicStep"
}

switch ($Step) {
    'sim' { Invoke-ModelSim }
    'all' { Invoke-ModelSim; Invoke-Pds 'all' 'all' }
    'build' { Invoke-Pds 'all' 'build' }
    default { Invoke-Pds $Step $Step }
}