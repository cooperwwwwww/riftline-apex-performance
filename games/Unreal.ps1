# Riftline support for Unreal Engine games. Dot-sourced by Apex-Performance.ps1.
# Unreal games keep their graphics settings in Saved\Config\<platform>\GameUserSettings.ini
# using the engine's standard keys, so one editor covers every game listed below. Riftline only
# writes the keys in $script:UnrealKeys, backs the file up first and refuses while the game runs.

# Folder is relative to %LOCALAPPDATA%. Process is a wildcard for the running-game check.
$script:UnrealGames = @(
    @{ id = 'thefinals';     name = 'THE FINALS';         appid = '2073850'; folder = 'Discovery\Saved\Config\WindowsClient';        process = 'Discovery*';            embark = $true }
    @{ id = 'arcraiders';    name = 'ARC Raiders';        appid = '1808500'; folder = 'PioneerGame\Saved\Config\WindowsClient';      process = 'PioneerGame*';          embark = $true }
    @{ id = 'fortnite';      name = 'Fortnite';           appid = '';        folder = 'FortniteGame\Saved\Config\WindowsClient';     process = 'FortniteClient*';       embark = $false }
    @{ id = 'marvelrivals';  name = 'Marvel Rivals';      appid = '2767030'; folder = 'Marvel\Saved\Config\Windows';                 process = 'Marvel-Win64*';         embark = $false }
    @{ id = 'deadbydaylight'; name = 'Dead by Daylight';  appid = '381210';  folder = 'DeadByDaylight\Saved\Config\WindowsClient';   process = 'DeadByDaylight*';       embark = $false }
    @{ id = 'pubg';          name = 'PUBG: Battlegrounds'; appid = '578080'; folder = 'TslGame\Saved\Config\WindowsNoEditor';        process = 'TslGame*';              embark = $false }
    @{ id = 'palworld';      name = 'Palworld';           appid = '1623730'; folder = 'Pal\Saved\Config\Windows';                    process = 'Palworld*';             embark = $false }
    @{ id = 'satisfactory';  name = 'Satisfactory';       appid = '526870';  folder = 'FactoryGame\Saved\Config\Windows';            process = 'FactoryGame*';          embark = $false }
    @{ id = 'deeprock';      name = 'Deep Rock Galactic'; appid = '548430';  folder = 'FSD\Saved\Config\WindowsNoEditor';            process = 'FSD-Win64*';            embark = $false }
    @{ id = 'squad';         name = 'Squad';              appid = '393380';  folder = 'SquadGame\Saved\Config\WindowsNoEditor';      process = 'SquadGame*';            embark = $false }
    @{ id = 'readyornot';    name = 'Ready or Not';       appid = '1144200'; folder = 'ReadyOrNot\Saved\Config\Windows';             process = 'ReadyOrNot*';           embark = $false }
    @{ id = 'hellletloose';  name = 'Hell Let Loose';     appid = '686810';  folder = 'HLL\Saved\Config\WindowsNoEditor';            process = 'HLL-Win64*';            embark = $false }
)

$script:UnrealQuality = @('0', '1', '2', '3', '4')
# Section '*' means the game's own GameUserSettings section, found per file.
$script:UnrealKeys = [ordered]@{
    'sg.ResolutionQuality'       = @{ Section = 'ScalabilityGroups'; Pattern = '^(2[5-9]|[3-9]\d|100)$' }
    'sg.ViewDistanceQuality'     = @{ Section = 'ScalabilityGroups'; Allowed = $script:UnrealQuality }
    'sg.AntiAliasingQuality'     = @{ Section = 'ScalabilityGroups'; Allowed = $script:UnrealQuality }
    'sg.ShadowQuality'           = @{ Section = 'ScalabilityGroups'; Allowed = $script:UnrealQuality }
    'sg.GlobalIlluminationQuality' = @{ Section = 'ScalabilityGroups'; Allowed = $script:UnrealQuality }
    'sg.ReflectionQuality'       = @{ Section = 'ScalabilityGroups'; Allowed = $script:UnrealQuality }
    'sg.PostProcessQuality'      = @{ Section = 'ScalabilityGroups'; Allowed = $script:UnrealQuality }
    'sg.TextureQuality'          = @{ Section = 'ScalabilityGroups'; Allowed = $script:UnrealQuality }
    'sg.EffectsQuality'          = @{ Section = 'ScalabilityGroups'; Allowed = $script:UnrealQuality }
    'sg.FoliageQuality'          = @{ Section = 'ScalabilityGroups'; Allowed = $script:UnrealQuality }
    'sg.ShadingQuality'          = @{ Section = 'ScalabilityGroups'; Allowed = $script:UnrealQuality }
    'bUseVSync'                  = @{ Section = '*'; Allowed = @('True', 'False') }
    'bUseDynamicResolution'      = @{ Section = '*'; Allowed = @('True', 'False') }
    'FrameRateLimit'             = @{ Section = '*'; Pattern = '^\d{1,3}\.000000$' }
    'FullscreenMode'             = @{ Section = '*'; Allowed = @('0', '1', '2') }       # 0 fullscreen, 1 windowed fullscreen, 2 windowed
    'ResolutionSizeX'            = @{ Section = '*'; Pattern = '^\d{3,4}$' }
    'ResolutionSizeY'            = @{ Section = '*'; Pattern = '^\d{3,4}$' }
    'bUseD3D12InGame'            = @{ Section = 'D3DRHIPreference'; Allowed = @('True', 'False') }
    # Embark games (THE FINALS, ARC Raiders): only values seen in real files are accepted.
    'MotionBlurMode'             = @{ Section = '*'; Allowed = @('Off'); Embark = $true }
    'LensDistortionEnabled'      = @{ Section = '*'; Allowed = @('True', 'False'); Embark = $true }
    'DLSSFrameGenerationMode'    = @{ Section = '*'; Allowed = @('Off'); Embark = $true }
}
# Keys the engine keeps in step with the ones above.
$script:UnrealCompanions = @{
    'FullscreenMode'  = @('LastConfirmedFullscreenMode', 'PreferredFullscreenMode')
    'ResolutionSizeX' = @('LastUserConfirmedResolutionSizeX')
    'ResolutionSizeY' = @('LastUserConfirmedResolutionSizeY')
}

function Get-UnrealGame {
    param([Parameter(Mandatory)][string]$Id)
    $game = $script:UnrealGames | Where-Object { $_.id -eq $Id } | Select-Object -First 1
    if (-not $game) { throw 'Riftline does not support that game.' }
    return $game
}

function Get-UnrealSettingsPath {
    param([Parameter(Mandatory)]$Game)
    if ($env:RIFTLINE_UE_ROOT) { return (Join-Path (Join-Path $env:RIFTLINE_UE_ROOT $Game.folder) 'GameUserSettings.ini') }   # self-test only
    return (Join-Path (Join-Path $env:LOCALAPPDATA $Game.folder) 'GameUserSettings.ini')
}

function Get-UnrealBackupFolder {
    param([Parameter(Mandatory)]$Game)
    $root = if ($env:RIFTLINE_UE_BACKUPS) { $env:RIFTLINE_UE_BACKUPS } else { Join-Path $env:LOCALAPPDATA 'ApexPerformanceHelper\Backups' }
    return (Join-Path $root $Game.id)
}

function Test-UnrealGameRunning {
    param([Parameter(Mandatory)]$Game)
    if ($env:RIFTLINE_UE_ROOT) { return $false }
    return [bool](Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -like $Game.process })
}

function Read-UnrealIni {
    param([Parameter(Mandatory)][string]$Path)
    $text = [System.IO.File]::ReadAllText($Path)
    $newline = if ($text.Contains("`r`n")) { "`r`n" } else { "`n" }
    $lines = [System.Collections.Generic.List[string]]::new()
    foreach ($line in ($text -split "\r?\n")) { $lines.Add($line) }
    $endsWithNewline = $text.EndsWith("`n")
    if ($endsWithNewline -and $lines.Count -gt 0 -and $lines[$lines.Count - 1] -eq '') { $lines.RemoveAt($lines.Count - 1) }
    return [pscustomobject]@{ Lines = $lines; Newline = $newline; EndsWithNewline = $endsWithNewline }
}

# The game's own settings section, e.g. [/Script/EmbarkUserSettings.EmbarkGameUserSettings].
function Get-UnrealUserSection {
    param([Parameter(Mandatory)]$Ini)
    $best = ''; $current = ''
    foreach ($line in $Ini.Lines) {
        if ($line -match '^\s*\[([^\]]+)\]\s*$') { $current = $Matches[1]; continue }
        if ($current -match 'GameUserSettings$' -and $line -match '^\s*(ResolutionSizeX|bUseVSync|FullscreenMode)\s*=') { return $current }
        if (-not $best -and $current -match 'GameUserSettings$') { $best = $current }
    }
    if ($best) { return $best }
    return '/Script/Engine.GameUserSettings'
}

function Get-UnrealIniValues {
    param([Parameter(Mandatory)]$Ini)
    $values = @{}; $section = ''
    foreach ($line in $Ini.Lines) {
        if ($line -match '^\s*\[([^\]]+)\]\s*$') { $section = $Matches[1]; continue }
        # First occurrence wins: Unreal repeats some keys (benchmark steps) and Riftline never edits those.
        if ($line -match '^\s*([A-Za-z0-9_.]+)\s*=(.*)$' -and -not $values.ContainsKey("$section|$($Matches[1])")) { $values["$section|$($Matches[1])"] = $Matches[2].Trim() }
    }
    return $values
}

function Set-UnrealIniValue {
    param([Parameter(Mandatory)]$Ini, [Parameter(Mandatory)][string]$Section, [Parameter(Mandatory)][string]$Key, [Parameter(Mandatory)][string]$Value, [switch]$OnlyIfPresent)
    $lines = $Ini.Lines
    $newLine = "$Key=$Value"
    $current = ''; $sectionStart = -1; $sectionEnd = -1; $found = $false
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^\s*\[([^\]]+)\]\s*$') {
            if ($sectionStart -ge 0 -and $sectionEnd -lt 0) { $sectionEnd = $i }
            $current = $Matches[1]
            if ($current -eq $Section -and $sectionStart -lt 0) { $sectionStart = $i }
            continue
        }
        if ($current -eq $Section -and $lines[$i] -match "^\s*$([regex]::Escape($Key))\s*=") { $lines[$i] = $newLine; $found = $true }
    }
    if ($found -or $OnlyIfPresent) { return }
    if ($sectionStart -lt 0) {
        if ($lines.Count -gt 0 -and $lines[$lines.Count - 1].Trim() -ne '') { $lines.Add('') }
        $lines.Add("[$Section]"); $lines.Add($newLine)
        return
    }
    if ($sectionEnd -lt 0) { $sectionEnd = $lines.Count }
    $insertAt = $sectionEnd
    while ($insertAt -gt $sectionStart + 1 -and $lines[$insertAt - 1].Trim() -eq '') { $insertAt-- }
    $lines.Insert($insertAt, $newLine)
}

function Save-UnrealIni {
    param([Parameter(Mandatory)]$Ini, [Parameter(Mandatory)][string]$Path)
    $text = ($Ini.Lines -join $Ini.Newline)
    if ($Ini.EndsWithNewline) { $text += $Ini.Newline }
    $item = Get-Item -LiteralPath $Path
    $wasReadOnly = $item.IsReadOnly
    if ($wasReadOnly) { $item.IsReadOnly = $false }
    try { [System.IO.File]::WriteAllText($Path, $text, [System.Text.UTF8Encoding]::new($false)) }
    finally { if ($wasReadOnly) { (Get-Item -LiteralPath $Path).IsReadOnly = $true } }
}

function Get-UnrealGameList {
    $list = foreach ($game in $script:UnrealGames) {
        $path = Get-UnrealSettingsPath -Game $game
        [pscustomobject]@{ id = $game.id; name = $game.name; appid = $game.appid; detected = (Test-Path -LiteralPath $path) }
    }
    return [pscustomobject]@{ ok = $true; games = @($list) }
}

function Get-UnrealState {
    param([Parameter(Mandatory)][string]$Id)
    $game = Get-UnrealGame -Id $Id
    $path = Get-UnrealSettingsPath -Game $game
    $exists = Test-Path -LiteralPath $path
    $values = @{}; $section = ''
    if ($exists) {
        $ini = Read-UnrealIni -Path $path
        $section = Get-UnrealUserSection -Ini $ini
        $all = Get-UnrealIniValues -Ini $ini
        foreach ($key in $script:UnrealKeys.Keys) {
            $rule = $script:UnrealKeys[$key]
            if ($rule.ContainsKey('Embark') -and -not $game.embark) { continue }
            $sectionName = if ($rule.Section -eq '*') { $section } else { $rule.Section }
            if ($all.ContainsKey("$sectionName|$key")) { $values[$key] = $all["$sectionName|$key"] }
        }
        foreach ($extra in @('NvReflexMode', 'DLSSMode', 'ResolutionScalingMethod', 'RTXGIQuality')) { if ($all.ContainsKey("$section|$extra")) { $values[$extra] = $all["$section|$extra"] } }
    }
    $folder = Get-UnrealBackupFolder -Game $game
    return [pscustomobject]@{
        ok = $true; id = $game.id; name = $game.name; embark = [bool]$game.embark; appid = $game.appid
        settingsPath = $path; settingsExists = $exists; section = $section
        readOnly = $(if ($exists) { (Get-Item -LiteralPath $path).IsReadOnly } else { $false })
        running = (Test-UnrealGameRunning -Game $game)
        values = $values
        backups = $(if (Test-Path -LiteralPath $folder) { @(Get-ChildItem -LiteralPath $folder -Filter 'GameUserSettings-2*.ini').Count } else { 0 })
        hasOriginal = (Test-Path -LiteralPath (Join-Path $folder 'GameUserSettings-original.ini'))
        monitorRefresh = (Get-MonitorRefreshRate)
    }
}

function Set-UnrealSettings {
    param([Parameter(Mandatory)][string]$Id, $Values)
    $game = Get-UnrealGame -Id $Id
    $path = Get-UnrealSettingsPath -Game $game
    if (-not (Test-Path -LiteralPath $path)) { throw "$($game.name) has not created its settings file yet. Start the game once, change any setting and close it." }
    if (Test-UnrealGameRunning -Game $game) { throw "Close $($game.name) completely first. It saves its settings when it exits, which would undo these changes." }
    $changes = [ordered]@{}
    foreach ($property in @($Values.PSObject.Properties)) {
        $key = [string]$property.Name; $value = [string]$property.Value
        if (-not $script:UnrealKeys.Contains($key)) { throw "Riftline does not manage the setting '$key'." }
        $rule = $script:UnrealKeys[$key]
        if ($rule.ContainsKey('Embark') -and -not $game.embark) { throw "'$key' is not a $($game.name) setting." }
        if ($rule.ContainsKey('Allowed') -and ($rule.Allowed -cnotcontains $value)) { throw "'$value' is not a valid value for $key." }
        if ($rule.ContainsKey('Pattern') -and ($value -notmatch $rule.Pattern)) { throw "'$value' is not a valid value for $key." }
        $changes[$key] = $value
    }
    if ($changes.Count -eq 0) { return [pscustomobject]@{ ok = $true; message = 'Nothing to change.' } }
    $folder = Get-UnrealBackupFolder -Game $game
    New-Item -ItemType Directory -Force -Path $folder | Out-Null
    $original = Join-Path $folder 'GameUserSettings-original.ini'
    if (-not (Test-Path -LiteralPath $original)) { Copy-Item -LiteralPath $path -Destination $original }
    $backup = Join-Path $folder ("GameUserSettings-{0}.ini" -f (Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
    Copy-Item -LiteralPath $path -Destination $backup
    Get-ChildItem -LiteralPath $folder -Filter 'GameUserSettings-2*.ini' | Sort-Object Name -Descending | Select-Object -Skip 25 | Remove-Item -Force -ErrorAction SilentlyContinue
    $ini = Read-UnrealIni -Path $path
    $userSection = Get-UnrealUserSection -Ini $ini
    foreach ($key in $changes.Keys) {
        $rule = $script:UnrealKeys[$key]
        $section = if ($rule.Section -eq '*') { $userSection } else { $rule.Section }
        Set-UnrealIniValue -Ini $ini -Section $section -Key $key -Value $changes[$key]
        if ($script:UnrealCompanions.ContainsKey($key)) {
            foreach ($companion in $script:UnrealCompanions[$key]) { Set-UnrealIniValue -Ini $ini -Section $section -Key $companion -Value $changes[$key] -OnlyIfPresent }
        }
    }
    Save-UnrealIni -Ini $ini -Path $path
    return [pscustomobject]@{ ok = $true; backup = $backup; message = "Saved $($changes.Count) $($game.name) setting$(if ($changes.Count -ne 1) { 's' })." }
}

function Restore-UnrealBackup {
    param([Parameter(Mandatory)][string]$Id, [ValidateSet('latest', 'original')][string]$Which = 'latest')
    $game = Get-UnrealGame -Id $Id
    $path = Get-UnrealSettingsPath -Game $game
    if (Test-UnrealGameRunning -Game $game) { throw "Close $($game.name) completely before restoring." }
    $folder = Get-UnrealBackupFolder -Game $game
    $source = if ($Which -eq 'original') { Join-Path $folder 'GameUserSettings-original.ini' } else { (Get-ChildItem -LiteralPath $folder -Filter 'GameUserSettings-2*.ini' -ErrorAction SilentlyContinue | Sort-Object Name -Descending | Select-Object -First 1).FullName }
    if (-not $source -or -not (Test-Path -LiteralPath $source)) { throw "There is no $($game.name) backup to restore yet." }
    $item = Get-Item -LiteralPath $path -ErrorAction SilentlyContinue
    $wasReadOnly = $item -and $item.IsReadOnly
    if ($wasReadOnly) { $item.IsReadOnly = $false }
    Copy-Item -LiteralPath $source -Destination $path -Force
    if ($Which -eq 'latest') { Remove-Item -LiteralPath $source -Force }
    if ($wasReadOnly) { (Get-Item -LiteralPath $path).IsReadOnly = $true }
    return [pscustomobject]@{ ok = $true; message = $(if ($Which -eq 'original') { "$($game.name) settings were returned to how they were before Riftline." } else { "The last $($game.name) change was undone." }) }
}

function Set-UnrealFileLock {
    param([Parameter(Mandatory)][string]$Id, [bool]$Locked)
    $path = Get-UnrealSettingsPath -Game (Get-UnrealGame -Id $Id)
    if (-not (Test-Path -LiteralPath $path)) { throw 'The settings file does not exist yet.' }
    (Get-Item -LiteralPath $path).IsReadOnly = $Locked
    return [pscustomobject]@{ ok = $true; locked = $Locked }
}

function Start-UnrealGame {
    param([Parameter(Mandatory)][string]$Id)
    $game = Get-UnrealGame -Id $Id
    if ($game.id -eq 'fortnite') { Start-Process 'com.epicgames.launcher://apps/fn%3A4fe75bbc5a674f4f9b356b5c90567da5%3AFortnite?action=launch&silent=true'; return }
    if (-not $game.appid) { throw "Start $($game.name) from its own launcher." }
    Start-Process "steam://rungameid/$($game.appid)"
}

function Invoke-UnrealSelfTest {
    $root = Join-Path ([System.IO.Path]::GetTempPath()) ("rlue-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
    $previousRoot = $env:RIFTLINE_UE_ROOT; $previousBackups = $env:RIFTLINE_UE_BACKUPS
    $env:RIFTLINE_UE_ROOT = $root; $env:RIFTLINE_UE_BACKUPS = Join-Path $root 'backups'
    try {
        $game = Get-UnrealGame -Id 'thefinals'
        $path = Get-UnrealSettingsPath -Game $game
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $path) | Out-Null
        $original = ";METADATA=(Diff=true, UseCommands=true)`r`n[ScalabilityGroups]`r`nsg.ShadowQuality=3`r`nsg.ResolutionQuality=100`r`n`r`n[D3DRHIPreference]`r`nbUseD3D12InGame=True`r`n`r`n[/Script/EmbarkUserSettings.EmbarkGameUserSettings]`r`nbUseVSync=True`r`nFullscreenMode=1`r`nLastConfirmedFullscreenMode=1`r`nResolutionSizeX=2560`r`nLastUserConfirmedResolutionSizeX=2560`r`nLastGPUBenchmarkSteps=1.0`r`nLastGPUBenchmarkSteps=2.0`r`nFrameRateLimit=0.000000`r`n`r`n[/Script/Engine.GameUserSettings]`r`nbUseDesiredScreenHeight=False`r`n`r`n"
        [System.IO.File]::WriteAllText($path, $original, [System.Text.UTF8Encoding]::new($false))
        if (-not (@((Get-UnrealGameList).games) | Where-Object { $_.id -eq 'thefinals' -and $_.detected })) { throw 'Unreal self-test failed: game was not detected.' }
        $state = Get-UnrealState -Id 'thefinals'
        if ($state.section -ne '/Script/EmbarkUserSettings.EmbarkGameUserSettings' -or $state.values['sg.ShadowQuality'] -ne '3' -or $state.values['bUseVSync'] -ne 'True') { throw 'Unreal self-test failed: values were not read.' }
        [void](Set-UnrealSettings -Id 'thefinals' -Values ([pscustomobject]@{ 'sg.ShadowQuality' = '0'; 'sg.EffectsQuality' = '1'; bUseVSync = 'False'; FullscreenMode = '0'; ResolutionSizeX = '1920'; FrameRateLimit = '237.000000'; MotionBlurMode = 'Off' }))
        $text = [System.IO.File]::ReadAllText($path)
        foreach ($expected in @('sg.ShadowQuality=0', 'sg.EffectsQuality=1', 'bUseVSync=False', 'FullscreenMode=0', 'LastConfirmedFullscreenMode=0', 'ResolutionSizeX=1920', 'LastUserConfirmedResolutionSizeX=1920', 'FrameRateLimit=237.000000', 'MotionBlurMode=Off', 'LastGPUBenchmarkSteps=1.0', 'LastGPUBenchmarkSteps=2.0', 'bUseDesiredScreenHeight=False')) {
            if (-not $text.Contains($expected)) { throw "Unreal self-test failed: '$expected' missing after apply." }
        }
        if ($text -match 'PreferredFullscreenMode') { throw 'Unreal self-test failed: a companion key that was not in the file got added.' }
        if ($text.IndexOf('sg.EffectsQuality') -gt $text.IndexOf('[D3DRHIPreference]')) { throw 'Unreal self-test failed: new key landed in the wrong section.' }
        if ($text.IndexOf('MotionBlurMode') -gt $text.IndexOf('[/Script/Engine.GameUserSettings]')) { throw 'Unreal self-test failed: game key landed in the engine section.' }
        if ($text -match '(?<!\r)\n') { throw 'Unreal self-test failed: line endings changed.' }
        foreach ($bad in @(@{ 'sg.ShadowQuality' = '9' }, @{ GPUName = 'x' }, @{ FrameRateLimit = '60' })) {
            $rejected = $false
            try { [void](Set-UnrealSettings -Id 'thefinals' -Values ([pscustomobject]$bad)) } catch { $rejected = $true }
            if (-not $rejected) { throw "Unreal self-test failed: an invalid change was accepted ($(@($bad.Keys)[0]))." }
        }
        $rejected = $false
        try { [void](Get-UnrealGame -Id 'notagame') } catch { $rejected = $true }
        if (-not $rejected) { throw 'Unreal self-test failed: an unknown game was accepted.' }
        [void](Restore-UnrealBackup -Id 'thefinals' -Which 'original')
        if ([System.IO.File]::ReadAllText($path) -ne $original) { throw 'Unreal self-test failed: original file was not restored exactly.' }
    } finally {
        $env:RIFTLINE_UE_ROOT = $previousRoot; $env:RIFTLINE_UE_BACKUPS = $previousBackups
        Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
    }
}
