param(
    [string]$Dest = (Join-Path $PSScriptRoot 'phone_logs'),
    [string]$Device = '',
    [switch]$Watch,
    [int]$IntervalSeconds = 3,
    [string[]]$RemoteDir = @(
        '/sdcard/Android/data/com.vikavn.app/files/vika_logs',
        '/sdcard/Android/data/com.vikavn.app.dev/files/vika_logs'
    )
)

function Find-Adb {
    foreach ($root in @($env:ANDROID_HOME, $env:ANDROID_SDK_ROOT, 'E:\Android\Sdk', "$env:LOCALAPPDATA\Android\Sdk")) {
        if (-not $root) { continue }
        $path = Join-Path $root 'platform-tools\adb.exe'
        if (Test-Path $path) { return $path }
    }
    $cmd = Get-Command adb -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    throw 'adb not found. Install Android SDK platform-tools or set ANDROID_HOME.'
}

$adb = Find-Adb
$deviceArgs = @()
if ($Device) { $deviceArgs = @('-s', $Device) }
New-Item -ItemType Directory -Force -Path $Dest | Out-Null
$Dest = (Resolve-Path $Dest).Path

function Test-UpToDate([string]$local, [long]$size, [long]$mtime) {
    if (-not (Test-Path $local)) { return $false }
    $item = Get-Item $local
    $localMtime = ([DateTimeOffset]$item.LastWriteTimeUtc).ToUnixTimeSeconds()
    return ($item.Length -eq $size) -and ($localMtime -eq $mtime)
}

function Sync-Once {
    $count = 0
    foreach ($remoteDir in $RemoteDir) {
        $count += Sync-Dir $remoteDir
    }
    return $count
}

function Sync-Dir([string]$remoteDir) {
    $listing = & $adb @deviceArgs shell "cd $remoteDir 2>/dev/null && stat -c '%n|%s|%Y' vika_*.json 2>/dev/null"
    if ($LASTEXITCODE -ne 0 -or -not $listing) { return 0 }
    $count = 0
    foreach ($line in @($listing)) {
        $parts = $line.Trim().Split('|')
        if ($parts.Count -ne 3) { continue }
        $name = $parts[0]
        $local = Join-Path $Dest $name
        if (Test-UpToDate $local ([long]$parts[1]) ([long]$parts[2])) { continue }
        & $adb @deviceArgs pull -a "$remoteDir/$name" $local 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            $count++
            Write-Host ("{0}  {1}" -f (Get-Date -Format 'HH:mm:ss'), $name)
        }
    }
    return $count
}

Write-Host "Saving phone logs to $Dest"
if (-not $Watch) {
    $pulled = Sync-Once
    Write-Host "Pulled $pulled new or changed file(s)."
    return
}
Write-Host 'Watching the phone for new logs. Press Ctrl+C to stop.'
while ($true) {
    Sync-Once | Out-Null
    Start-Sleep -Seconds $IntervalSeconds
}
