function Get-TemplateProjectName([string]$Root) {
    $text = Get-Content -LiteralPath (Join-Path $Root 'config.tcl') -Raw
    $match = [regex]::Match($text, '(?m)^\s*set\s+template_config\(project_name\)\s+"([^"]+)"')
    if (-not $match.Success) {throw 'Missing template_config(project_name) in config.tcl.'}
    $match.Groups[1].Value
}

function Get-TemplateScalarSetting([string]$Root,[string]$Name) {
    $text = Get-Content -LiteralPath (Join-Path $Root 'config.tcl') -Raw
    $key = [regex]::Escape($Name)
    $match = [regex]::Match($text, "(?m)^\s*set\s+template_config\($key\)\s+(?:`"([^`"]*)`"|(\S+))\s*$")
    if (-not $match.Success) {throw "Missing template_config($Name) in config.tcl."}
    if ($match.Groups[1].Success) {$match.Groups[1].Value} else {$match.Groups[2].Value}
}

function Get-TemplateListSetting([string]$Root,[string]$Name) {
    $text = Get-Content -LiteralPath (Join-Path $Root 'config.tcl') -Raw
    $key = [regex]::Escape($Name)
    $match = [regex]::Match($text, "(?ms)^\s*set\s+template_config\($key\)\s+\{(.*?)\}\s*$")
    if (-not $match.Success) {throw "Missing template_config($Name) in config.tcl."}
    @($match.Groups[1].Value -split '\s+' | Where-Object {$_})
}

function Get-FreeTcpPort {
    $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback,0)
    $listener.Start()
    try {$listener.LocalEndpoint.Port} finally {$listener.Stop()}
}

function Invoke-CdtScript(
    [string]$Root,
    [string]$PdsBin,
    [string]$Script,
    [string]$LogName
) {
    $logDir = Join-Path $Root 'logs'
    New-Item -ItemType Directory -Force -Path $logDir | Out-Null
    $runtimeScript = Join-Path $logDir ("runtime-" + [IO.Path]::GetFileName($Script))
    $logPath = Join-Path $logDir $LogName
    Copy-Item -LiteralPath $Script -Destination $runtimeScript -Force

    $port = $null
    $server = $null
    $serverProcessId = $null
    $oldIp = $env:JTAG_IP
    $oldPort = $env:JTAG_PORT
    try {
        $ready = $false
        for ($launch = 0; $launch -lt 3 -and -not $ready; $launch++) {
            $port = Get-FreeTcpPort
            $serverArgs = "-port $port -work_dir `"$logDir`""
            $server = Start-Process (Join-Path $PdsBin 'cdt_js.exe') -ArgumentList $serverArgs -WorkingDirectory $logDir -WindowStyle Hidden -PassThru
            for ($attempt = 0; $attempt -lt 50; $attempt++) {
                $listener = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1
                if ($listener) {$serverProcessId = $listener.OwningProcess; $ready = $true; break}
                Start-Sleep -Milliseconds 100
            }
            if (-not $ready) {
                if ($server -and -not $server.HasExited) {Stop-Process -Id $server.Id -Force -ErrorAction SilentlyContinue}
                Start-Sleep -Seconds 1
            }
        }
        if (-not $ready) {throw "CDT JTAG server did not open port $port."}

        $env:JTAG_IP = '127.0.0.1'
        $env:JTAG_PORT = [string]$port
        Push-Location $logDir
        try {
            $ErrorActionPreference = 'Continue'
            $output = & (Join-Path $PdsBin 'cdt_cfg_shell.exe') -file $runtimeScript 2>&1
            $code = $LASTEXITCODE
            $ErrorActionPreference = 'Stop'
        } finally {
            $ErrorActionPreference = 'Stop'
            Pop-Location
        }
        $output | Set-Content -LiteralPath $logPath -Encoding utf8
        $output | ForEach-Object {Write-Host $_}
        if ($code -ne 0) {throw "CDT command failed: $logPath"}
        [pscustomobject]@{Text=($output | Out-String);Log=$logPath}
    } finally {
        $env:JTAG_IP = $oldIp
        $env:JTAG_PORT = $oldPort
        if ($serverProcessId) {
            Stop-Process -Id $serverProcessId -Force -ErrorAction SilentlyContinue
            Wait-Process -Id $serverProcessId -Timeout 2 -ErrorAction SilentlyContinue
            Start-Sleep -Milliseconds 250
        }
        if ($server -and -not $server.HasExited) {Stop-Process -Id $server.Id -Force -ErrorAction SilentlyContinue}
        Remove-Item -LiteralPath $runtimeScript -Force -ErrorAction SilentlyContinue
    }
}
