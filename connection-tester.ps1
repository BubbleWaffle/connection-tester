$config = Get-Content -Path "$PSScriptRoot\config.json" -Raw | ConvertFrom-Json

$interface = Get-NetIPInterface -InterfaceAlias $config.RouterInterface -ErrorAction SilentlyContinue

if (-not $interface) {
    Write-Host "[$(Get-Date -Format "yyyy-MM-dd HH:mm:ss")] Network interface '$($config.RouterInterface)' was not found." -ForegroundColor Red
    exit 1
}

$router = (Get-NetIPConfiguration -InterfaceAlias $config.RouterInterface).IPv4DefaultGateway.NextHop

if (-not $router) {
    Write-Host "[$(Get-Date -Format "yyyy-MM-dd HH:mm:ss")] Could not determine the default gateway for interface '$($config.RouterInterface)'." -ForegroundColor Red
    exit 1
}

$history = [System.Collections.Generic.Queue[object]]::new()

$logPath = "$PSScriptRoot\logs"

while ($true) {
    $routerPing = Test-Connection $router -Count 1 -ErrorAction SilentlyContinue

    $internetPing = Test-Connection $config.InternetHost -Count 1 -ErrorAction SilentlyContinue

    $result = [PSCustomObject]@{
        Time = "[$(Get-Date -Format "yyyy-MM-dd HH:mm:ss")]"
        Router = if ($routerPing) { "OK" } else { "Connection Lost" }
        Router_Ping = if ($routerPing) { "$($routerPing.ResponseTime) ms" } else { "-" }
        Internet = if ($internetPing) { "OK" } else { "Connection Lost" }
        Internet_Ping = if ($internetPing) { "$($internetPing.ResponseTime) ms" } else { "-" }
    }

    $history.Enqueue($result)

    if ($history.Count -gt $config.HistorySize) {
        $null = $history.Dequeue()
    }

    if (-not $routerPing -or 
        -not $internetPing -or
        $routerPing.ResponseTime -ge $config.MaxRouterResponseTime -or
        $internetPing.ResponseTime -ge $config.MaxInternetResponseTime) {

        $date = Get-Date -Format 'yyyy-MM-dd'

        if (-not (Test-Path $logPath)) {
            New-Item -Path $logPath -ItemType Directory -Force | Out-Null
        }

        $logFile = "$logPath\logs_$date.log"

        if (-not (Test-Path $logFile)) {
            @(
                "Time                  Router          Router_Ping  Internet        Internet_Ping"
                "----                  ------          -----------  --------        -------------"
            ) | Out-File -FilePath $logFile -Encoding UTF8
        }

        "{0,-21} {1,-15} {2,-12} {3,-15} {4}" -f $result.Time, $result.Router, $result.Router_Ping, $result.Internet, $result.Internet_Ping | Out-File -FilePath $logFile -Append -Encoding  UTF8
    }

    Clear-Host

    $history | Format-Table -AutoSize

    Start-Sleep -Seconds $config.IntervalSeconds
}