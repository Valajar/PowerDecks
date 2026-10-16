# Launches Balatro through Steam, waits for it to boot (or exit), optionally copies the Lovely dump,
# then closes the game. Prints the path of the log this launch produced.
param(
    [string]$CopyDumpTo = "",
    [int]$BootTimeout = 150,
    [int]$SettleSeconds = 6,
    # Runs the PowerDecks self-test: the game drives itself and quits when finished.
    [switch]$SelfTest,
    [int]$SelfTestTimeout = 460,
    [string]$ShotsDir = (Join-Path $env:TEMP "pwr_selftest_shots")
)

$balatro = "C:\Users\Noah-\AppData\Roaming\Balatro"
$mods = "$balatro\mods"
$logDir = "$mods\lovely\log"
$marker = "$mods\PowerDecks\dev\RUN_SELFTEST"

function Get-SaveState {
    $files = @(Get-ChildItem $balatro -File -Filter *.jkr) + @(Get-ChildItem "$balatro\1", "$balatro\2", "$balatro\3" -File -Recurse -ErrorAction SilentlyContinue)
    $state = @{}
    foreach ($f in $files) { $state[$f.FullName.Substring($balatro.Length)] = (Get-FileHash $f.FullName -Algorithm MD5).Hash }
    $state
}

if (Get-Process -Name Balatro -ErrorAction SilentlyContinue) {
    "ABORT: Balatro is already running"
    exit 2
}

$savesBefore = Get-SaveState
$playlogBefore = @(Get-ChildItem "$mods\PlayLog\playlog_runs" -ErrorAction SilentlyContinue).Count
$before = @(Get-ChildItem $logDir | Select-Object -ExpandProperty Name)
$log = $null
$booted = $false
$closedHow = "never started"

try {
    if ($SelfTest) { Set-Content -Path $marker -Value "delete this file to disable the self-test" }
    Start-Process "steam://rungameid/2379780"

    $proc = $null
    $deadline = (Get-Date).AddSeconds(90)
    while (-not $proc -and (Get-Date) -lt $deadline) {
        Start-Sleep -Milliseconds 500
        $proc = Get-Process -Name Balatro -ErrorAction SilentlyContinue | Select-Object -First 1
    }
    if (-not $proc) { "ABORT: Balatro process never appeared"; exit 3 }
    $startedAt = Get-Date

    $deadline = (Get-Date).AddSeconds($BootTimeout)
    while ((Get-Date) -lt $deadline) {
        Start-Sleep -Milliseconds 700
        if (-not $log) {
            $log = Get-ChildItem $logDir | Where-Object { $before -notcontains $_.Name } | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        }
        if ($log) {
            $txt = Get-Content $log.FullName -Raw -ErrorAction SilentlyContinue
            if ($txt -match "futil: loaded startup" -or $txt -match "\[DebugPlus\] Press") { $booted = $true; break }
            if ($txt -match "Oops! The game crashed" -or $txt -match "stack traceback") { break }
        }
        if (-not (Get-Process -Name Balatro -ErrorAction SilentlyContinue)) { break }
    }

    if ($SelfTest) {
        $deadline = (Get-Date).AddSeconds($SelfTestTimeout)
        while ((Get-Process -Name Balatro -ErrorAction SilentlyContinue) -and (Get-Date) -lt $deadline) {
            Start-Sleep -Milliseconds 800
            $txt = Get-Content $log.FullName -Raw -ErrorAction SilentlyContinue
            if ($txt -match "Oops! The game crashed") { Start-Sleep -Seconds 2; break }
        }
    } else {
        Start-Sleep -Seconds $SettleSeconds
    }

    if ($CopyDumpTo) {
        if (Test-Path $CopyDumpTo) { Remove-Item $CopyDumpTo -Recurse -Force }
        Copy-Item "$mods\lovely\dump" $CopyDumpTo -Recurse
    }

    $alive = Get-Process -Name Balatro -ErrorAction SilentlyContinue
    $closedHow = "exited on its own after $([int]((Get-Date) - $startedAt).TotalSeconds)s"
    if ($alive) {
        $alive | ForEach-Object { [void]$_.CloseMainWindow() }
        $deadline = (Get-Date).AddSeconds(15)
        while ((Get-Process -Name Balatro -ErrorAction SilentlyContinue) -and (Get-Date) -lt $deadline) { Start-Sleep -Milliseconds 500 }
        $closedHow = "closed via window close after $([int]((Get-Date) - $startedAt).TotalSeconds)s"
        if (Get-Process -Name Balatro -ErrorAction SilentlyContinue) {
            Get-Process -Name Balatro | Stop-Process -Force
            $closedHow = "force-stopped"
        }
    }
}
finally {
    if (Test-Path $marker) { Remove-Item $marker -Force }
}

# Collect the self-test screenshots out of the game's save folder
$shots = @(Get-ChildItem $balatro -File -Filter "pwr_selftest_*.png" -ErrorAction SilentlyContinue)
if ($shots.Count) {
    New-Item -ItemType Directory -Force $ShotsDir | Out-Null
    $shots | Move-Item -Destination $ShotsDir -Force
    "screenshots: $($shots.Count) moved to $ShotsDir"
}

"booted=$booted  end=$closedHow"
if ($log) { "log=$($log.FullName)" } else { "log=<none found>" }

Start-Sleep -Seconds 2
$savesAfter = Get-SaveState
$changed = @($savesAfter.Keys | Where-Object { $savesBefore[$_] -ne $savesAfter[$_] }) + @($savesBefore.Keys | Where-Object { -not $savesAfter.ContainsKey($_) })
if ($changed.Count) { "save files changed: $($changed -join ', ')" } else { "save files changed: none" }
"playlog runs: $playlogBefore -> $(@(Get-ChildItem "$mods\PlayLog\playlog_runs" -ErrorAction SilentlyContinue).Count)"

if ($log) {
    $lines = Get-Content $log.FullName
    $hits = $lines | Select-String -Pattern "\[PWRTEST\]|PowerDecks|Oops! The game crashed|stack traceback|attempt to|ERROR ::" -SimpleMatch:$false
    "--- relevant log lines: $($hits.Count)"
}
