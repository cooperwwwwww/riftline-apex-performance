# Riftline Overwatch 2 support. Dot-sourced by Apex-Performance.ps1.
# Overwatch keeps its graphics settings in Documents\Overwatch\Settings\Settings_v0.ini and
# only writes keys that differ from the game defaults. Riftline edits only the keys listed in
# $script:OverwatchKeys, backs the file up first, and never touches anything else in it.

$script:OverwatchAppId = '2357570'

# Every key Riftline may write, with the values it accepts. Anything else is rejected.
$script:OverwatchKeys = [ordered]@{
    'WindowMode'              = @{ Section = 'Render.13'; Allowed = @('0', '1', '2') }                 # 0 fullscreen, 1 borderless, 2 windowed
    'FullScreenWidth'         = @{ Section = 'Render.13'; Pattern = '^\d{3,4}$' }
    'FullScreenHeight'        = @{ Section = 'Render.13'; Pattern = '^\d{3,4}$' }
    'FullScreenRefresh'       = @{ Section = 'Render.13'; Pattern = '^\d{2,3}$' }
    'FrameRateCap'            = @{ Section = 'Render.13'; Pattern = '^\d{2,3}$' }
    'UseCustomFrameRates'     = @{ Section = 'Render.13'; Allowed = @('0', '1') }
    'LimitToRefresh'          = @{ Section = 'Render.13'; Allowed = @('0', '1') }
    'VerticalSyncEnabled'     = @{ Section = 'Render.13'; Allowed = @('0', '1') }
    'TripleBufferingEnabled'  = @{ Section = 'Render.13'; Allowed = @('0', '1') }
    'CpuForceSyncEnabled'     = @{ Section = 'Render.13'; Allowed = @('0', '1') }                      # "Reduce buffering"
    'ShowFPSCounter'          = @{ Section = 'Render.13'; Allowed = @('0', '1') }
    'GraphicsAPI'             = @{ Section = 'Render.13'; Allowed = @('Dx11', 'Dx12') }
    'TextureDetail'           = @{ Section = 'Render.13'; Allowed = @('1', '2', '3', '4') }
    'ModelQuality'            = @{ Section = 'Render.13'; Allowed = @('1', '2', '3', '4') }
    'LightQuality'            = @{ Section = 'Render.13'; Allowed = @('0', '1', '2', '3') }
    'AADetail'                = @{ Section = 'Render.13'; Allowed = @('0', '1', '2', '3') }
    'MaxAnisotropy'           = @{ Section = 'Render.13'; Allowed = @('1', '2', '4', '8', '16') }
    # Overwatch resets 0 to Medium when it saves, so the lowest real level is 1 (Low).
    'DirectionalShadowDetail' = @{ Section = 'Render.13'; Allowed = @('1', '2', '3', '4') }
    'SimpleDirectionalShadows' = @{ Section = 'Render.13'; Allowed = @('0', '1') }
    'TranslucentShadowDetail' = @{ Section = 'Render.13'; Allowed = @('0') }
    'SSAOEnabled'             = @{ Section = 'Render.13'; Allowed = @('0', '1') }
    'LocalReflections'        = @{ Section = 'Render.13'; Allowed = @('0', '1') }
    'SSLRDetailLevel'         = @{ Section = 'Render.13'; Allowed = @('0') }
    'RefractionDetail'        = @{ Section = 'Render.13'; Allowed = @('0', '1') }
    'DynamicAmbient'          = @{ Section = 'Render.13'; Allowed = @('0', '1') }
    # Overwatch saves fog as 1-3 (Low-High); it resets anything else to High, so 0 is not offered.
    'LocalFogDetail'          = @{ Section = 'Render.13'; Allowed = @('1', '2', '3') }
    'ShowIntro'               = @{ Section = 'Cinematics.1'; Allowed = @('0', '1') }
    # Volumes are stored as percentages with six decimals, e.g. "70.000000".
    'MasterVolume'            = @{ Section = 'Sound.3'; Pattern = '^(\d{1,2}|100)\.000000$' }
    'MusicVolume'             = @{ Section = 'Sound.3'; Pattern = '^(\d{1,2}|100)\.000000$' }
    'SFXVolume'               = @{ Section = 'Sound.3'; Pattern = '^(\d{1,2}|100)\.000000$' }
    'VoiceChatVolume'         = @{ Section = 'Sound.3'; Pattern = '^(\d{1,2}|100)\.000000$' }
}

function Get-OverwatchSettingsPath {
    if ($env:RIFTLINE_OW_SETTINGS) { return $env:RIFTLINE_OW_SETTINGS }   # self-test only
    $documents = [Environment]::GetFolderPath('MyDocuments')
    return (Join-Path $documents 'Overwatch\Settings\Settings_v0.ini')
}

function Get-OverwatchBackupFolder {
    if ($env:RIFTLINE_OW_BACKUPS) { return $env:RIFTLINE_OW_BACKUPS }   # self-test only
    return (Join-Path $env:LOCALAPPDATA 'ApexPerformanceHelper\Backups\Overwatch')
}

function Test-OverwatchRunning {
    if ($env:RIFTLINE_OW_SETTINGS) { return $false }   # self-test works on a copy, so a running game does not matter
    return [bool](Get-Process -Name 'Overwatch' -ErrorAction SilentlyContinue)
}

function Read-OverwatchIni {
    param([Parameter(Mandatory)][string]$Path)
    $text = [System.IO.File]::ReadAllText($Path)
    $newline = if ($text.Contains("`r`n")) { "`r`n" } else { "`n" }
    $lines = [System.Collections.Generic.List[string]]::new()
    foreach ($line in ($text -split "\r?\n")) { $lines.Add($line) }
    # Drop the empty entry a trailing newline produces; it is re-added on save.
    $endsWithNewline = $text.EndsWith("`n")
    if ($endsWithNewline -and $lines.Count -gt 0 -and $lines[$lines.Count - 1] -eq '') { $lines.RemoveAt($lines.Count - 1) }
    return [pscustomobject]@{ Lines = $lines; Newline = $newline; EndsWithNewline = $endsWithNewline }
}

function Get-OverwatchIniValues {
    param([Parameter(Mandatory)]$Ini)
    $values = @{}
    $section = ''
    foreach ($line in $Ini.Lines) {
        if ($line -match '^\s*\[([^\]]+)\]\s*$') { $section = $Matches[1]; continue }
        if ($line -match '^\s*([A-Za-z0-9_]+)\s*=\s*"?([^"]*)"?\s*$') { $values["$section|$($Matches[1])"] = $Matches[2] }
    }
    return $values
}

function Set-OverwatchIniValue {
    param([Parameter(Mandatory)]$Ini, [Parameter(Mandatory)][string]$Section, [Parameter(Mandatory)][string]$Key, [Parameter(Mandatory)][string]$Value)
    $lines = $Ini.Lines
    $newLine = "$Key = `"$Value`""
    $current = ''; $sectionStart = -1; $sectionEnd = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^\s*\[([^\]]+)\]\s*$') {
            if ($sectionStart -ge 0 -and $sectionEnd -lt 0) { $sectionEnd = $i }
            $current = $Matches[1]
            if ($current -eq $Section) { $sectionStart = $i }
            continue
        }
        if ($current -eq $Section -and $lines[$i] -match "^\s*$([regex]::Escape($Key))\s*=") { $lines[$i] = $newLine; return }
    }
    if ($sectionStart -lt 0) {
        if ($lines.Count -gt 0 -and $lines[$lines.Count - 1].Trim() -ne '') { $lines.Add('') }
        $lines.Add("[$Section]"); $lines.Add($newLine); $lines.Add('')
        return
    }
    if ($sectionEnd -lt 0) { $sectionEnd = $lines.Count }
    # Insert after the last key in the section, before the blank line that separates sections.
    $insertAt = $sectionEnd
    while ($insertAt -gt $sectionStart + 1 -and $lines[$insertAt - 1].Trim() -eq '') { $insertAt-- }
    $lines.Insert($insertAt, $newLine)
}

function Save-OverwatchIni {
    param([Parameter(Mandatory)]$Ini, [Parameter(Mandatory)][string]$Path)
    $text = ($Ini.Lines -join $Ini.Newline)
    if ($Ini.EndsWithNewline) { $text += $Ini.Newline }
    $item = Get-Item -LiteralPath $Path
    $wasReadOnly = $item.IsReadOnly
    if ($wasReadOnly) { $item.IsReadOnly = $false }
    try { [System.IO.File]::WriteAllText($Path, $text, [System.Text.UTF8Encoding]::new($false)) }
    finally { if ($wasReadOnly) { (Get-Item -LiteralPath $Path).IsReadOnly = $true } }
}

function New-OverwatchBackup {
    param([Parameter(Mandatory)][string]$Path)
    $folder = Get-OverwatchBackupFolder
    New-Item -ItemType Directory -Force -Path $folder | Out-Null
    $original = Join-Path $folder 'Settings_v0-original.ini'
    if (-not (Test-Path -LiteralPath $original)) { Copy-Item -LiteralPath $Path -Destination $original }
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss-fff'
    $backup = Join-Path $folder "Settings_v0-$stamp.ini"
    Copy-Item -LiteralPath $Path -Destination $backup
    # Keep the newest 25 timestamped backups.
    Get-ChildItem -LiteralPath $folder -Filter 'Settings_v0-2*.ini' | Sort-Object Name -Descending | Select-Object -Skip 25 | Remove-Item -Force -ErrorAction SilentlyContinue
    return $backup
}

function Get-OverwatchInstall {
    foreach ($library in (Get-SteamLibraryFolders)) {
        $manifest = Join-Path (Join-Path $library 'steamapps') "appmanifest_$($script:OverwatchAppId).acf"
        if (Test-Path -LiteralPath $manifest) { return [pscustomobject]@{ launcher = 'Steam'; manifest = $manifest } }
    }
    foreach ($candidate in @("${env:ProgramFiles(x86)}\Overwatch", "$env:ProgramFiles\Overwatch")) {
        if ($candidate -and (Test-Path -LiteralPath (Join-Path $candidate 'Overwatch.exe'))) { return [pscustomobject]@{ launcher = 'Battle.net'; manifest = $null } }
    }
    return $null
}

function Get-OverwatchState {
    $path = Get-OverwatchSettingsPath
    $exists = Test-Path -LiteralPath $path
    $values = @{}
    if ($exists) {
        $all = Get-OverwatchIniValues -Ini (Read-OverwatchIni -Path $path)
        foreach ($key in $script:OverwatchKeys.Keys) {
            $lookup = "$($script:OverwatchKeys[$key].Section)|$key"
            if ($all.ContainsKey($lookup)) { $values[$key] = $all[$lookup] }
        }
        foreach ($extra in @('WindowedFullscreen', 'WindowedRefresh')) { if ($all.ContainsKey("Render.13|$extra")) { $values[$extra] = $all["Render.13|$extra"] } }
        # Every line in the file, for the read-only "Everything in your file" list. GPU IDs are left out.
        $everything = @($all.Keys | Where-Object { $_ -notmatch '^GPU\.|^environment\.' } | Sort-Object | ForEach-Object {
            $parts = $_ -split '\|', 2
            [pscustomobject]@{ section = $parts[0]; key = $parts[1]; value = $all[$_]; managed = $script:OverwatchKeys.Contains($parts[1]) }
        })
    } else { $everything = @() }
    $folder = Get-OverwatchBackupFolder
    $backups = if (Test-Path -LiteralPath $folder) { @(Get-ChildItem -LiteralPath $folder -Filter 'Settings_v0-2*.ini').Count } else { 0 }
    $install = Get-OverwatchInstall
    return [pscustomobject]@{
        ok = $true
        settingsPath = $path
        settingsExists = $exists
        readOnly = $(if ($exists) { (Get-Item -LiteralPath $path).IsReadOnly } else { $false })
        running = (Test-OverwatchRunning)
        values = $values
        backups = $backups
        hasOriginal = (Test-Path -LiteralPath (Join-Path $folder 'Settings_v0-original.ini'))
        launcher = $(if ($install) { $install.launcher } else { '' })
        monitorRefresh = (Get-MonitorRefreshRate)
        everything = $everything
        cacheMb = (Get-OverwatchCacheSize)
    }
}

function Get-OverwatchCacheFile {
    return (Join-Path (Split-Path -Parent (Split-Path -Parent (Get-OverwatchSettingsPath))) 'Cache\PipelineLibrary\PipelineLibrary.list')
}

function Get-OverwatchCacheSize {
    $file = Get-OverwatchCacheFile
    if (Test-Path -LiteralPath $file) { return [math]::Round((Get-Item -LiteralPath $file).Length / 1MB, 1) }
    return 0
}

# Overwatch rebuilds its shader pipeline cache on the next start; clearing it fixes stutter after updates.
function Clear-OverwatchShaderCache {
    if (Test-OverwatchRunning) { throw 'Close Overwatch completely before clearing its shader cache.' }
    $file = Get-OverwatchCacheFile
    if (-not (Test-Path -LiteralPath $file)) { return [pscustomobject]@{ ok = $true; message = 'The Overwatch shader cache is already empty.' } }
    Remove-Item -LiteralPath $file -Force
    return [pscustomobject]@{ ok = $true; message = 'Overwatch shader cache cleared. The first match after this may stutter while it rebuilds.' }
}

function Set-OverwatchFileLock {
    param([bool]$Locked)
    $path = Get-OverwatchSettingsPath
    if (-not (Test-Path -LiteralPath $path)) { throw 'Overwatch has not created its settings file yet.' }
    (Get-Item -LiteralPath $path).IsReadOnly = $Locked
    return [pscustomobject]@{ ok = $true; locked = $Locked }
}

function Set-OverwatchSettings {
    param($Values)
    $path = Get-OverwatchSettingsPath
    if (-not (Test-Path -LiteralPath $path)) { throw 'Overwatch has not created its settings file yet. Start Overwatch once, change any setting, and close it.' }
    if (Test-OverwatchRunning) { throw 'Close Overwatch completely first. It rewrites its settings file when it exits, which would undo these changes.' }
    $changes = [ordered]@{}
    foreach ($property in @($Values.PSObject.Properties)) {
        $key = [string]$property.Name; $value = [string]$property.Value
        if (-not $script:OverwatchKeys.Contains($key)) { throw "Riftline does not manage the Overwatch setting '$key'." }
        $rule = $script:OverwatchKeys[$key]
        if ($rule.ContainsKey('Allowed') -and ($rule.Allowed -cnotcontains $value)) { throw "'$value' is not a valid value for $key." }
        if ($rule.ContainsKey('Pattern') -and ($value -notmatch $rule.Pattern)) { throw "'$value' is not a valid value for $key." }
        $changes[$key] = $value
    }
    if ($changes.Count -eq 0) { return [pscustomobject]@{ ok = $true; message = 'Nothing to change.' } }
    # Keep the paired keys Overwatch expects in step with the ones the UI sets.
    if ($changes.Contains('WindowMode')) { $changes['WindowedFullscreen'] = $(if ($changes['WindowMode'] -eq '1') { '1' } else { '0' }) }
    if ($changes.Contains('FrameRateCap')) { $changes['UseCustomFrameRates'] = '1'; $changes['LimitToRefresh'] = '0' }
    elseif ($changes.Contains('LimitToRefresh') -and $changes['LimitToRefresh'] -eq '1') { $changes['UseCustomFrameRates'] = '0' }
    $backup = New-OverwatchBackup -Path $path
    $ini = Read-OverwatchIni -Path $path
    foreach ($key in $changes.Keys) {
        $section = if ($script:OverwatchKeys.Contains($key)) { $script:OverwatchKeys[$key].Section } else { 'Render.13' }
        Set-OverwatchIniValue -Ini $ini -Section $section -Key $key -Value ([string]$changes[$key])
    }
    Save-OverwatchIni -Ini $ini -Path $path
    return [pscustomobject]@{ ok = $true; backup = $backup; changed = @($changes.Keys); message = "Saved $($changes.Count) Overwatch setting$(if ($changes.Count -ne 1) { 's' })." }
}

function Restore-OverwatchBackup {
    param([ValidateSet('latest', 'original')][string]$Which = 'latest')
    $path = Get-OverwatchSettingsPath
    if (Test-OverwatchRunning) { throw 'Close Overwatch completely before restoring.' }
    $folder = Get-OverwatchBackupFolder
    $source = if ($Which -eq 'original') { Join-Path $folder 'Settings_v0-original.ini' } else { (Get-ChildItem -LiteralPath $folder -Filter 'Settings_v0-2*.ini' -ErrorAction SilentlyContinue | Sort-Object Name -Descending | Select-Object -First 1).FullName }
    if (-not $source -or -not (Test-Path -LiteralPath $source)) { throw 'There is no Overwatch backup to restore yet.' }
    $item = Get-Item -LiteralPath $path -ErrorAction SilentlyContinue
    $wasReadOnly = $item -and $item.IsReadOnly
    if ($wasReadOnly) { $item.IsReadOnly = $false }
    Copy-Item -LiteralPath $source -Destination $path -Force
    if ($Which -eq 'latest') { Remove-Item -LiteralPath $source -Force }   # step back one change at a time
    if ($wasReadOnly) { (Get-Item -LiteralPath $path).IsReadOnly = $true }
    return [pscustomobject]@{ ok = $true; message = $(if ($Which -eq 'original') { 'Overwatch settings were returned to how they were before Riftline.' } else { 'The last Overwatch change was undone.' }) }
}

function Start-Overwatch {
    $install = Get-OverwatchInstall
    if ($install -and $install.launcher -eq 'Steam') { Start-Process "steam://rungameid/$($script:OverwatchAppId)"; return }
    # Battle.net's product code for Overwatch is "Pro".
    Start-Process 'battlenet://Pro'
}

# Installed Steam games for the Games page. Redistributables and tools are left out.
function Get-RiftlineSteamGames {
    $tunable = @{ '1172470' = 'apex'; '2357570' = 'overwatch' }
    foreach ($unreal in $script:UnrealGames) { if ($unreal.appid) { $tunable[$unreal.appid] = $unreal.id } }
    $games = [System.Collections.Generic.List[object]]::new()
    $seen = @{}
    foreach ($library in (Get-SteamLibraryFolders)) {
        $apps = Join-Path $library 'steamapps'
        if (-not (Test-Path -LiteralPath $apps)) { continue }
        foreach ($manifest in (Get-ChildItem -LiteralPath $apps -Filter 'appmanifest_*.acf' -ErrorAction SilentlyContinue)) {
            try {
                $text = [System.IO.File]::ReadAllText($manifest.FullName)
                if ($text -notmatch '"appid"\s+"(\d+)"') { continue }
                $id = $Matches[1]
                if ($seen.ContainsKey($id)) { continue }
                $name = if ($text -match '"name"\s+"([^"]+)"') { $Matches[1] } else { "App $id" }
                if ($name -match '(?i)redistributable|proton|steam linux runtime|steamvr|soundtrack') { continue }
                $size = if ($text -match '"SizeOnDisk"\s+"(\d+)"') { [math]::Round([double]$Matches[1] / 1GB, 1) } else { 0 }
                $seen[$id] = $true
                $games.Add([pscustomobject]@{ appid = $id; name = $name; sizeGb = $size; tunable = $(if ($tunable.ContainsKey($id)) { $tunable[$id] } else { '' }) })
            } catch { }
        }
    }
    return [pscustomobject]@{ ok = $true; games = @($games | Sort-Object @{ Expression = { $_.tunable -eq '' } }, name) }
}

function Start-RiftlineSteamGame {
    param([Parameter(Mandatory)][string]$AppId)
    if ($AppId -notmatch '^\d{1,10}$') { throw 'That is not a Steam game ID.' }
    # Only games that are actually installed can be launched from the Games page.
    if (-not (@((Get-RiftlineSteamGames).games) | Where-Object { $_.appid -eq $AppId })) { throw 'That game is not installed in Steam.' }
    Start-Process "steam://rungameid/$AppId"
}

function Invoke-OverwatchSelfTest {
    $folder = Join-Path ([System.IO.Path]::GetTempPath()) ("rlow-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
    New-Item -ItemType Directory -Force -Path $folder | Out-Null
    $path = Join-Path $folder 'Settings_v0.ini'
    $original = "[Cinematics.1]`r`nShowIntro = `"1`"`r`n`r`n[Render.13]`r`nFrameRateCap = `"600`"`r`nWindowMode = `"1`"`r`nGraphicsAPI = `"Dx12`"`r`n`r`n[TankMenuItems.1]`r`nFPSOverlay = `"0`"`r`n"
    [System.IO.File]::WriteAllText($path, $original, [System.Text.UTF8Encoding]::new($false))
    $previous = $env:RIFTLINE_OW_SETTINGS; $previousBackups = $env:RIFTLINE_OW_BACKUPS
    $env:RIFTLINE_OW_SETTINGS = $path; $env:RIFTLINE_OW_BACKUPS = Join-Path $folder 'backups'
    try {
        $state = Get-OverwatchState
        if ($state.values['FrameRateCap'] -ne '600' -or $state.values['ShowIntro'] -ne '1') { throw 'Overwatch self-test failed: values were not read.' }
        $body = [pscustomobject]@{ FrameRateCap = '237'; WindowMode = '0'; ShowIntro = '0'; SSAOEnabled = '0'; GraphicsAPI = 'Dx11'; MusicVolume = '0.000000' }
        [void](Set-OverwatchSettings -Values $body)
        $text = [System.IO.File]::ReadAllText($path)
        foreach ($expected in @('FrameRateCap = "237"', 'WindowMode = "0"', 'WindowedFullscreen = "0"', 'UseCustomFrameRates = "1"', 'LimitToRefresh = "0"', 'ShowIntro = "0"', 'SSAOEnabled = "0"', 'GraphicsAPI = "Dx11"', 'FPSOverlay = "0"', '[Sound.3]', 'MusicVolume = "0.000000"')) {
            if (-not $text.Contains($expected)) { throw "Overwatch self-test failed: '$expected' missing after apply." }
        }
        if ($text -match '(?<!\r)\n') { throw 'Overwatch self-test failed: line endings changed.' }
        if ($text.IndexOf('SSAOEnabled') -gt $text.IndexOf('[TankMenuItems.1]')) { throw 'Overwatch self-test failed: new key landed in the wrong section.' }
        $rejected = $false
        try { [void](Set-OverwatchSettings -Values ([pscustomobject]@{ GPUName = 'x' })) } catch { $rejected = $true }
        if (-not $rejected) { throw 'Overwatch self-test failed: an unmanaged key was accepted.' }
        $rejected = $false
        try { [void](Set-OverwatchSettings -Values ([pscustomobject]@{ TextureDetail = '9' })) } catch { $rejected = $true }
        if (-not $rejected) { throw 'Overwatch self-test failed: an invalid value was accepted.' }
        [void](Restore-OverwatchBackup -Which 'original')
        if ([System.IO.File]::ReadAllText($path) -ne $original) { throw 'Overwatch self-test failed: original file was not restored exactly.' }
    } finally {
        $env:RIFTLINE_OW_SETTINGS = $previous; $env:RIFTLINE_OW_BACKUPS = $previousBackups
        Remove-Item -LiteralPath $folder -Recurse -Force -ErrorAction SilentlyContinue
    }
}
