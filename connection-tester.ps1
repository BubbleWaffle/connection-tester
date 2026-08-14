$config = Get-Content -Path "$PSScriptRoot\config.json" -Raw | ConvertFrom-Json

$router = (Get-NetIPConfiguration -InterfaceAlias $config.RouterInterface).IPv4DefaultGateway.NextHop

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

        if (-not (Test-Path $logPath)) {
            New-Item -Path $logPath -ItemType Directory -Force | Out-Null
        }

        $csvPath = "$logPath\logs_$(Get-Date -Format 'yyyy-MM-dd').csv"

        if (Test-Path $csvPath) {
            $result | Export-Csv -Path $csvPath -NoTypeInformation -Append -Encoding UTF8
        }
        else {
            $result | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
        }
    }

    Clear-Host

    $history | Format-Table -AutoSize

    Start-Sleep -Seconds $config.IntervalSeconds
}