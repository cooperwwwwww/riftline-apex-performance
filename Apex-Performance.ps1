[CmdletBinding()]
param(
    [ValidateSet('Bridge', 'WebGui', 'Gui', 'Auto', 'TurboCurrent', 'Competitive', 'Performance1080', 'LowEnd720', 'UltraLow', 'Potato360', 'Balanced', 'Restore', 'CleanCache', 'Inspect', 'Launch', 'SelfTest')]
    [string]$Mode = 'Gui',
    [string]$ConfigPathOverride,
    [string]$BridgeAction,
    [string]$BridgePayloadPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-ApexRoot {
    if ($ConfigPathOverride) {
        return (Split-Path -Parent (Split-Path -Parent $ConfigPathOverride))
    }
    return (Join-Path ([Environment]::GetFolderPath('UserProfile')) 'Saved Games\Respawn\Apex')
}

function Get-VideoConfigPath {
    if ($ConfigPathOverride) { return $ConfigPathOverride }
    return (Join-Path (Get-ApexRoot) 'local\videoconfig.txt')
}

function Get-SettingsConfigPath {
    if ($ConfigPathOverride) { return (Join-Path (Split-Path -Parent $ConfigPathOverride) 'settings.cfg') }
    return (Join-Path (Get-ApexRoot) 'local\settings.cfg')
}

function Get-ApexConfigLockState {
    $path = Get-VideoConfigPath
    if (-not (Test-Path -LiteralPath $path)) { return $false }
    return [bool]((Get-Item -LiteralPath $path).Attributes -band [System.IO.FileAttributes]::ReadOnly)
}

function Set-ApexConfigLock {
    param([Parameter(Mandatory)][bool]$Locked)
    Assert-ApexClosed
    $path = Get-VideoConfigPath
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Apex video settings were not found: $path"
    }
    Set-ItemProperty -LiteralPath $path -Name IsReadOnly -Value $Locked
}

function Get-ProfileConfigPath {
    return (Join-Path (Get-ApexRoot) 'profile\profile.cfg')
}

function Test-ApexRunning {
    if ($ConfigPathOverride) { return $false }
    return [bool](Get-Process -Name 'r5apex', 'r5apex_dx12' -ErrorAction SilentlyContinue)
}

function Assert-ApexClosed {
    if (Test-ApexRunning) {
        throw 'Apex Legends is running. Close it completely, then try again.'
    }
}

function Read-VideoConfigText {
    param([Parameter(Mandatory)][string]$Path)
    $text = [System.IO.File]::ReadAllText($Path)
    return $text.TrimEnd([char]0)
}

function Get-VideoConfigValues {
    param([Parameter(Mandatory)][string]$Path)
    $values = @{}
    foreach ($line in ((Read-VideoConfigText -Path $Path) -split "`r?`n")) {
        if ($line -match '^\s*"([^"]+)"\s+"([^"]*)"') {
            $values[$Matches[1]] = $Matches[2]
        }
    }
    return $values
}

$script:RiftlineBackupKeepCount = 40

function Get-RiftlineBackupRoot {
    return (Join-Path $env:LOCALAPPDATA 'ApexPerformanceHelper\Backups')
}

function Remove-OldRiftlineBackups {
    param([Parameter(Mandatory)][string]$Pattern, [Parameter(Mandatory)][string]$BaselineName)
    # Older backups are only pruned once the permanent pre-Riftline baseline
    # exists, so "Return to regular Apex" can never lose its original source.
    $baseline = Join-Path (Get-RegularApexBaselineFolder) $BaselineName
    if (-not (Test-Path -LiteralPath $baseline)) { return }
    $backupRoot = Get-RiftlineBackupRoot
    if (-not (Test-Path -LiteralPath $backupRoot)) { return }
    $stale = @(Get-ChildItem -LiteralPath $backupRoot -Filter $Pattern -File -ErrorAction SilentlyContinue |
        Sort-Object Name -Descending | Select-Object -Skip $script:RiftlineBackupKeepCount)
    foreach ($file in $stale) { Remove-Item -LiteralPath $file.FullName -Force -ErrorAction SilentlyContinue }
}

function New-RiftlineBackup {
    param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)][string]$Prefix, [Parameter(Mandatory)][string]$Extension, [Parameter(Mandatory)][string]$BaselineName)
    $backupRoot = Get-RiftlineBackupRoot
    New-Item -ItemType Directory -Force -Path $backupRoot | Out-Null
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss-fff'
    $destination = Join-Path $backupRoot "$Prefix-$stamp$Extension"
    Copy-Item -LiteralPath $Path -Destination $destination -Force
    # A copied read-only config would otherwise make the backup itself read-only.
    Set-ItemProperty -LiteralPath $destination -Name IsReadOnly -Value $false -ErrorAction SilentlyContinue
    Remove-OldRiftlineBackups -Pattern "$Prefix-*$Extension" -BaselineName $BaselineName
    return $destination
}

function New-VideoConfigBackup {
    param([Parameter(Mandatory)][string]$Path)
    return (New-RiftlineBackup -Path $Path -Prefix 'videoconfig' -Extension '.txt' -BaselineName 'videoconfig.txt')
}

function New-SettingsConfigBackup {
    param([Parameter(Mandatory)][string]$Path)
    return (New-RiftlineBackup -Path $Path -Prefix 'settings' -Extension '.cfg' -BaselineName 'settings.cfg')
}

function New-ProfileConfigBackup {
    param([Parameter(Mandatory)][string]$Path)
    return (New-RiftlineBackup -Path $Path -Prefix 'profile' -Extension '.cfg' -BaselineName 'profile.cfg')
}

function Get-RegularApexBaselineFolder {
    return (Join-Path $env:LOCALAPPDATA 'ApexPerformanceHelper\Regular-Apex-Baseline')
}

function Ensure-RegularApexBaseline {
    $baselineFolder = Get-RegularApexBaselineFolder
    New-Item -ItemType Directory -Force -Path $baselineFolder | Out-Null
    $legacyBackupRoot = Join-Path $env:LOCALAPPDATA 'ApexPerformanceHelper\Backups'
    $items = @(
        @{ Target = (Join-Path $baselineFolder 'videoconfig.txt'); Current = (Get-VideoConfigPath); Pattern = 'videoconfig-*.txt' },
        @{ Target = (Join-Path $baselineFolder 'settings.cfg'); Current = (Get-SettingsConfigPath); Pattern = 'settings-*.cfg' },
        @{ Target = (Join-Path $baselineFolder 'profile.cfg'); Current = (Get-ProfileConfigPath); Pattern = 'profile-*.cfg' }
    )
    foreach ($item in $items) {
        if (Test-Path -LiteralPath $item.Target) { continue }
        $source = $null
        if (Test-Path -LiteralPath $legacyBackupRoot) {
            $source = Get-ChildItem -LiteralPath $legacyBackupRoot -Filter $item.Pattern -File -ErrorAction SilentlyContinue |
                Sort-Object Name | Select-Object -First 1
        }
        if ($source) { Copy-Item -LiteralPath $source.FullName -Destination $item.Target -Force }
        elseif (Test-Path -LiteralPath $item.Current) { Copy-Item -LiteralPath $item.Current -Destination $item.Target -Force }
    }
}

function Restore-RegularApex {
    Assert-ApexClosed
    Ensure-RegularApexBaseline
    $baselineFolder = Get-RegularApexBaselineFolder
    $videoBaseline = Join-Path $baselineFolder 'videoconfig.txt'
    if (-not (Test-Path -LiteralPath $videoBaseline)) { throw 'No original Apex video baseline was found. Start Apex once, close it, then open this helper before applying a profile.' }

    $targets = @(
        @{ Source = $videoBaseline; Target = (Get-VideoConfigPath) },
        @{ Source = (Join-Path $baselineFolder 'settings.cfg'); Target = (Get-SettingsConfigPath) },
        @{ Source = (Join-Path $baselineFolder 'profile.cfg'); Target = (Get-ProfileConfigPath) }
    )
    foreach ($item in $targets) {
        if (-not (Test-Path -LiteralPath $item.Source)) { continue }
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $item.Target) | Out-Null
        if (Test-Path -LiteralPath $item.Target) { Set-ItemProperty -LiteralPath $item.Target -Name IsReadOnly -Value $false -ErrorAction SilentlyContinue }
        Copy-Item -LiteralPath $item.Source -Destination $item.Target -Force
    }
    Save-LaunchOptions -LaunchOptions ''
    Clear-ActiveProfile
    Write-Host 'Regular Apex baseline restored. App-managed launch commands were cleared.' -ForegroundColor Green
}

function Write-SettingsConfigValues {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][hashtable]$Overrides
    )
    if (-not (Test-Path -LiteralPath $Path)) { return }
    $lines = [System.Collections.Generic.List[string]]::new()
    $seen = @{}
    foreach ($line in ([System.IO.File]::ReadAllLines($Path))) {
        if ($line -match '^(\s*)([^\s"]+)\s+"([^"]*)"(.*)$') {
            $indent = $Matches[1]; $key = $Matches[2]; $tail = $Matches[4]
            if ($Overrides.ContainsKey($key)) {
                $lines.Add(('{0}{1} "{2}"{3}' -f $indent, $key, $Overrides[$key], $tail))
                $seen[$key] = $true
                continue
            }
        }
        $lines.Add($line)
    }
    foreach ($key in ($Overrides.Keys | Sort-Object)) {
        if (-not $seen.ContainsKey($key)) { $lines.Add(('{0} "{1}"' -f $key, $Overrides[$key])) }
    }
    [System.IO.File]::WriteAllLines($Path, $lines, [System.Text.UTF8Encoding]::new($false))
}

function Write-VideoConfigValues {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][hashtable]$Overrides
    )
    $text = Read-VideoConfigText -Path $Path
    if ($text -notmatch '(?m)^\s*"VideoConfig"\s*$') {
        throw 'The file is not a recognized Apex videoconfig.txt.'
    }

    $seen = @{}
    $lines = [System.Collections.Generic.List[string]]::new()
    foreach ($line in ($text -split "`r?`n")) {
        if ($line -match '^(\s*)"([^"]+)"\s+"([^"]*)"(.*)$') {
            $indent = $Matches[1]
            $key = $Matches[2]
            $tail = $Matches[4]
            if ($Overrides.ContainsKey($key)) {
                $lines.Add(('{0}"{1}"{2}"{3}"{4}' -f $indent, $key, "`t`t", $Overrides[$key], $tail))
                $seen[$key] = $true
                continue
            }
        }
        $lines.Add($line)
    }

    $closingIndex = -1
    for ($i = $lines.Count - 1; $i -ge 0; $i--) {
        if ($lines[$i].Trim() -eq '}') { $closingIndex = $i; break }
    }
    if ($closingIndex -lt 0) { throw 'The closing brace is missing from videoconfig.txt.' }

    foreach ($key in ($Overrides.Keys | Sort-Object)) {
        if (-not $seen.ContainsKey($key)) {
            $lines.Insert($closingIndex, ("`t`"$key`"`t`t`"$($Overrides[$key])`""))
            $closingIndex++
        }
    }

    $attributes = (Get-Item -LiteralPath $Path).Attributes
    $wasReadOnly = (($attributes -band [System.IO.FileAttributes]::ReadOnly) -ne 0)
    if ($wasReadOnly) {
        Set-ItemProperty -LiteralPath $Path -Name IsReadOnly -Value $false
    }
    $output = ($lines -join "`r`n") + "`r`n" + [char]0
    try {
        [System.IO.File]::WriteAllText($Path, $output, [System.Text.UTF8Encoding]::new($false))
    } finally {
        if ($wasReadOnly -and (Test-Path -LiteralPath $Path)) {
            Set-ItemProperty -LiteralPath $Path -Name IsReadOnly -Value $true
        }
    }
}

function Get-NativeResolution {
    $path = Get-VideoConfigPath
    if (Test-Path -LiteralPath $path) {
        $values = Get-VideoConfigValues -Path $path
        $width = 0
        $height = 0
        if ($values.ContainsKey('setting.last_display_width')) { [void][int]::TryParse($values['setting.last_display_width'], [ref]$width) }
        if ($values.ContainsKey('setting.last_display_height')) { [void][int]::TryParse($values['setting.last_display_height'], [ref]$height) }
        if (($width -ge 1024) -and ($height -ge 576)) {
            return [pscustomobject]@{ Width = $width; Height = $height }
        }
    }

    try {
        $gpu = Get-CimInstance Win32_VideoController | Where-Object { $_.CurrentHorizontalResolution -gt 0 } | Select-Object -First 1
        if ($gpu) { return [pscustomobject]@{ Width = [int]$gpu.CurrentHorizontalResolution; Height = [int]$gpu.CurrentVerticalResolution } }
    } catch { }
    return [pscustomobject]@{ Width = 1920; Height = 1080 }
}

function Get-MonitorRefreshRate {
    # Highest refresh rate reported by an active display; 0 when Windows does not say.
    try {
        $rates = @(Get-CimInstance Win32_VideoController | ForEach-Object { [int]$_.CurrentRefreshRate } | Where-Object { $_ -ge 24 -and $_ -le 1000 })
        if ($rates.Count -gt 0) { return [int]($rates | Measure-Object -Maximum).Maximum }
    } catch { }
    return 0
}

function Get-CommonLowValues {
    return @{
        'setting.cl_gib_allow' = '0'
        'setting.cl_particle_fallback_base' = '3'
        'setting.cl_particle_fallback_multiplier' = '2'
        'setting.cl_ragdoll_maxcount' = '0'
        'setting.cl_ragdoll_self_collision' = '0'
        'setting.mat_forceaniso' = '1'
        'setting.mat_mip_linear' = '0'
        'setting.particle_cpu_level' = '0'
        'setting.r_createmodeldecals' = '0'
        'setting.r_decals' = '0'
        'setting.shadow_enable' = '0'
        'setting.shadow_depth_dimen_min' = '0'
        'setting.shadow_depth_upres_factor_max' = '0'
        'setting.shadow_maxdynamic' = '0'
        'setting.dvs_enable' = '0'
        'setting.volumetric_lighting' = '0'
        'setting.volumetric_fog' = '0'
        'setting.mat_vsync_mode' = '0'
        'setting.mat_backbuffer_count' = '1'
        'setting.mat_antialias_mode' = '0'
        'setting.csm_enabled' = '0'
        'setting.csm_coverage' = '0'
        'setting.csm_cascade_res' = '0'
        'setting.new_shadow_settings' = '1'
        'setting.dynamic_streaming_budget' = '1'
        'setting.map_detail_level' = '0'
        'setting.set_dress_level' = '0'
        'setting.ssao_enabled' = '0'
        'setting.ssao_downsample' = '1'
        'setting.ssao_quality' = '0'
    }
}

function Get-ProfileValues {
    param([Parameter(Mandatory)][ValidateSet('Competitive', 'Performance1080', 'LowEnd720', 'UltraLow', 'Potato360', 'Balanced')][string]$Profile)
    $native = Get-NativeResolution
    $values = Get-CommonLowValues

    switch ($Profile) {
        'Competitive' {
            $width = $native.Width; $height = $native.Height
            $values['setting.stream_memory'] = '160000'
            $values['setting.mat_picmip'] = '2'
            $values['setting.r_lod_switch_scale'] = '0.500000'
            $values['setting.fadeDistScale'] = '0.600000'
        }
        'Performance1080' {
            $width = 1920; $height = 1080
            if ($native.Width -lt 1920 -or $native.Height -lt 1080) { $width = $native.Width; $height = $native.Height }
            $values['setting.stream_memory'] = '160000'
            $values['setting.mat_picmip'] = '2'
            $values['setting.r_lod_switch_scale'] = '0.450000'
            $values['setting.fadeDistScale'] = '0.550000'
        }
        'LowEnd720' {
            $width = 1280; $height = 720
            $values['setting.stream_memory'] = '0'
            $values['setting.mat_picmip'] = '2'
            $values['setting.r_lod_switch_scale'] = '0.350000'
            $values['setting.fadeDistScale'] = '0.450000'
            $values['setting.dvs_enable'] = '1'
            $values['setting.dvs_gpuframetime_min'] = '15917'
            $values['setting.dvs_gpuframetime_max'] = '17417'
        }
        'UltraLow' {
            $width = 960; $height = 540
            $values['setting.stream_memory'] = '0'
            $values['setting.mat_picmip'] = '2'
            $values['setting.r_lod_switch_scale'] = '0.250000'
            $values['setting.fadeDistScale'] = '0.300000'
            $values['setting.dvs_enable'] = '1'
            $values['setting.dvs_gpuframetime_min'] = '21472'
            $values['setting.dvs_gpuframetime_max'] = '22972'
        }
        'Potato360' {
            $width = 640; $height = 360
            $values['setting.stream_memory'] = '0'
            $values['setting.mat_picmip'] = '2'
            $values['setting.mat_mip_linear'] = '0'
            $values['setting.r_lod_switch_scale'] = '0.250000'
            $values['setting.fadeDistScale'] = '0.250000'
            $values['setting.dvs_enable'] = '1'
            $values['setting.dvs_gpuframetime_min'] = '32583'
            $values['setting.dvs_gpuframetime_max'] = '34083'
        }
        'Balanced' {
            $width = $native.Width; $height = $native.Height
            $values['setting.stream_memory'] = '300000'
            $values['setting.mat_picmip'] = '1'
            $values['setting.mat_forceaniso'] = '2'
            $values['setting.r_lod_switch_scale'] = '0.600000'
            $values['setting.fadeDistScale'] = '0.700000'
            $values['setting.cl_particle_fallback_base'] = '0'
            $values['setting.cl_particle_fallback_multiplier'] = '1'
        }
    }

    $values['setting.defaultres'] = [string]$width
    $values['setting.defaultresheight'] = [string]$height
    $values['setting.last_display_width'] = [string]$native.Width
    $values['setting.last_display_height'] = [string]$native.Height
    $values['setting.fullscreen'] = '1'
    $values['setting.nowindowborder'] = '0'
    return $values
}

function Get-HardwareRecommendation {
    $cpuName = 'Unknown CPU'
    $gpuNames = @('Unknown GPU')
    try { $cpuName = (Get-CimInstance Win32_Processor | Select-Object -First 1).Name.Trim() } catch { }
    try {
        $detected = @(Get-CimInstance Win32_VideoController | ForEach-Object { $_.Name.Trim() } | Where-Object { $_ })
        if ($detected.Count -gt 0) { $gpuNames = $detected }
    } catch { }
    $gpuText = $gpuNames -join ' + '

    $profile = 'Performance1080'
    $label = '1080P PERFORMANCE'
    # Strong discrete GPUs keep native resolution. Entry-level cards in the same
    # families (RTX 3050 / RX 6400 / RX 6500) are routed to the 1080p profile.
    if ($gpuText -match '(?i)RTX\s*(20[6-9]0|30[6-9]0|40[6-9]0|50[6-9]0)|RTX\s*A[2-6]000|RX\s*(5[6-9]00|6[6-9][05]0|7[6-9]00|9[0-9]{3})|Arc\s*(A7[0-9]0|B[5-9][0-9]0)') {
        $profile = 'Competitive'; $label = 'COMPETITIVE NATIVE'
    } elseif ($gpuText -match '(?i)RTX\s*(20|30|40|50)\d\d|GTX\s*(9[6-8]0|10[5-8]0|16[5-6]0)|RX\s*(4[6-8]0|5[0-9]0|5500|6[45]00)|RX\s*Vega|Arc') {
        $profile = 'Performance1080'; $label = '1080P PERFORMANCE'
    } elseif ($gpuText -match '(?i)Intel.*(UHD|Iris|HD Graphics)|AMD Radeon\(TM\) Graphics|Vega') {
        $profile = 'LowEnd720'; $label = 'LOW-END 720P'
    }
    return [pscustomobject]@{ CPU = $cpuName; GPU = $gpuText; Profile = $profile; Label = $label }
}

function Apply-Profile {
    param([Parameter(Mandatory)][ValidateSet('Competitive', 'Performance1080', 'LowEnd720', 'UltraLow', 'Potato360', 'Balanced')][string]$Profile)
    Assert-ApexClosed
    $path = Get-VideoConfigPath
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Apex video settings were not found: $path`nStart Apex once, reach the lobby, close it, and try again."
    }
    Ensure-RegularApexBaseline
    $backup = New-VideoConfigBackup -Path $path
    Write-VideoConfigValues -Path $path -Overrides (Get-ProfileValues -Profile $Profile)
    $settingsPath = Get-SettingsConfigPath
    if (Test-Path -LiteralPath $settingsPath) {
        [void](New-SettingsConfigBackup -Path $settingsPath)
        $latency = switch ($Profile) {
            'Competitive' { @{ 'gfx_nvnUseLowLatency' = '1'; 'gfx_nvnUseLowLatencyBoost' = '1'; 'gfx_amdUseLowLatency' = '1'; 'chroma_enable' = '0' } }
            { $_ -in @('LowEnd720', 'UltraLow', 'Potato360') } { @{ 'gfx_nvnUseLowLatency' = '0'; 'gfx_nvnUseLowLatencyBoost' = '0'; 'gfx_amdUseLowLatency' = '0'; 'chroma_enable' = '0' } }
            default { @{ 'gfx_nvnUseLowLatency' = '1'; 'gfx_nvnUseLowLatencyBoost' = '0'; 'gfx_amdUseLowLatency' = '1'; 'chroma_enable' = '0' } }
        }
        Write-SettingsConfigValues -Path $settingsPath -Overrides $latency
    }
    $launchOptions = switch ($Profile) {
        'Competitive' { '+fps_max 0 -novid' }
        'Performance1080' { '+fps_max 144 -novid' }
        'LowEnd720' { '+fps_max 0 -novid +dvs_scale_min 0.5' }
        'UltraLow' { '+fps_max 45 -novid +dvs_scale_min 0.5' }
        'Potato360' { '+fps_max 30 -novid +dvs_scale_min 0.5' }
        'Balanced' { '+fps_max 120 -novid' }
    }
    Save-LaunchOptions -LaunchOptions $launchOptions
    Set-ActiveProfile -Type 'built-in' -Name $Profile
    Write-Host "$Profile preset applied." -ForegroundColor Green
    Write-Host "Settings: $path"
    Write-Host "Backup:   $backup"
    Write-Host "Launcher: $launchOptions"
}

function Apply-TurboCurrentResolution {
    Assert-ApexClosed
    $path = Get-VideoConfigPath
    if (-not (Test-Path -LiteralPath $path)) { throw "Apex video settings were not found: $path" }
    Ensure-RegularApexBaseline
    $current = Get-VideoConfigValues -Path $path
    $native = Get-NativeResolution
    $width = $native.Width; $height = $native.Height
    if ($current.ContainsKey('setting.defaultres')) { $parsedWidth = 0; if ([int]::TryParse($current['setting.defaultres'], [ref]$parsedWidth) -and $parsedWidth -ge 640) { $width = $parsedWidth } }
    if ($current.ContainsKey('setting.defaultresheight')) { $parsedHeight = 0; if ([int]::TryParse($current['setting.defaultresheight'], [ref]$parsedHeight) -and $parsedHeight -ge 360) { $height = $parsedHeight } }

    $values = Get-ProfileValues -Profile 'Potato360'
    $values['setting.defaultres'] = [string]$width
    $values['setting.defaultresheight'] = [string]$height
    $values['setting.dvs_enable'] = '1'
    $values['setting.dvs_gpuframetime_min'] = '7583'
    $values['setting.dvs_gpuframetime_max'] = '9083'
    $backup = New-VideoConfigBackup -Path $path
    Write-VideoConfigValues -Path $path -Overrides $values

    $settingsPath = Get-SettingsConfigPath
    if (Test-Path -LiteralPath $settingsPath) {
        [void](New-SettingsConfigBackup -Path $settingsPath)
        Write-SettingsConfigValues -Path $settingsPath -Overrides @{ 'gfx_nvnUseLowLatency' = '0'; 'gfx_nvnUseLowLatencyBoost' = '0'; 'gfx_amdUseLowLatency' = '0'; 'chroma_enable' = '0' }
    }
    Save-LaunchOptions -LaunchOptions '+fps_max 0 -novid +dvs_scale_min 0.5'
    Set-ActiveProfile -Type 'built-in' -Name 'TurboCurrent'
    Write-Host "Turbo applied at unchanged resolution: ${width}x${height}" -ForegroundColor Green
    Write-Host "Backup: $backup"
}

function Get-TextureBudgetMap {
    # Exact values Apex writes for each Texture Streaming Budget menu tier.
    return [ordered]@{ 'None' = '0'; 'Very Low' = '160000'; 'Low' = '300000'; 'Medium' = '600000'; 'High' = '1000000'; 'Very High' = '2000000'; 'Insane' = '3000000' }
}

function ConvertTo-TextureBudgetTier {
    param([AllowEmptyString()][string]$Value)
    $map = Get-TextureBudgetMap
    $clean = ([string]$Value).Trim()
    foreach ($tier in $map.Keys) { if ($tier -ieq $clean) { return $tier } }
    # Builds 22 and earlier used VRAM-size labels. Saved profiles keep working.
    $legacy = @{ '1 GB' = 'Very Low'; '2 GB' = 'Very Low'; '3 GB' = 'Medium'; '4 GB' = 'High'; '6 GB' = 'Very High'; '8 GB' = 'Insane' }
    if ($legacy.ContainsKey($clean)) { return $legacy[$clean] }
    throw "Unknown texture streaming budget: $Value"
}

function ConvertTo-ApexScaleValue {
    param([Parameter(Mandatory)][string]$Value, [Parameter(Mandatory)][string]$Name, [double]$Maximum = 2.0)
    $number = 0.0
    if (-not [double]::TryParse($Value.Trim(), [System.Globalization.NumberStyles]::Float, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$number) -or ($number -lt 0.1) -or ($number -gt $Maximum)) {
        throw "$Name must be Auto or a value from 0.10 through $($Maximum.ToString('0.00', [System.Globalization.CultureInfo]::InvariantCulture))."
    }
    return $number.ToString('0.000000', [System.Globalization.CultureInfo]::InvariantCulture)
}

function ConvertTo-ApexFovScale {
    param([Parameter(Mandatory)][string]$Fov)
    $degrees = 0
    if (-not [int]::TryParse($Fov.Trim(), [ref]$degrees) -or ($degrees -lt 70) -or ($degrees -gt 120)) {
        throw 'Field of view must be a whole number from 70 through 120.'
    }
    # Same linear mapping as Apex's own FOV slider: 70 = 1.0, 90 = 1.275, 110 = 1.55.
    $scale = 1.0 + (($degrees - 70) * 0.01375)
    return $scale.ToString('0.000000', [System.Globalization.CultureInfo]::InvariantCulture)
}

function ConvertFrom-ApexFovScale {
    param([AllowEmptyString()][string]$Scale)
    $value = 0.0
    if (-not [double]::TryParse($Scale, [System.Globalization.NumberStyles]::Float, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$value) -or ($value -le 0)) { return '' }
    # Builds 22 and earlier wrote FOV / 70 for some values. Show those as the value the user chose.
    $legacy = @{ '1.142857' = 80; '1.285714' = 90; '1.428571' = 100; '1.714286' = 120 }
    $key = $value.ToString('0.000000', [System.Globalization.CultureInfo]::InvariantCulture)
    if ($legacy.ContainsKey($key)) { return [string]$legacy[$key] }
    $degrees = [int][Math]::Round(70 + (($value - 1.0) / 0.01375))
    return [string][Math]::Max(70, [Math]::Min(120, $degrees))
}

function Apply-AdvancedSettings {
    param(
        [Parameter(Mandatory)][int]$Width,
        [Parameter(Mandatory)][int]$Height,
        [ValidateSet('Fullscreen', 'Borderless', 'Windowed')][string]$WindowMode,
        [string]$TextureBudget,
        [ValidateSet('High', 'Low', 'Very Low')][string]$TextureQuality,
        [ValidateSet('1x', '2x', '4x', '8x', '16x')][string]$Anisotropic,
        [ValidateSet('Off', 'TSAA')][string]$AntiAliasing,
        [ValidateSet('Minimum', 'Very Low', 'Low', 'Medium', 'High')][string]$ModelDetail,
        [ValidateSet('Low', 'Medium', 'High')][string]$ParticleDetail,
        [bool]$Shadows,
        [bool]$Effects,
        [bool]$AmbientOcclusion,
        [bool]$MapDecorations,
        [bool]$Decals,
        [bool]$Ragdolls,
        [bool]$VSync,
        [ValidateRange(0, 240)][int]$AdaptiveTarget,
        [ValidateSet('Keep current', 'Off', 'On', 'On + Boost')][string]$LowLatency,
        [bool]$Gibs = $false,
        [bool]$RagdollCollision = $false,
        [bool]$LinearMipFiltering = $false,
        [bool]$DynamicTextureBudget = $true,
        [ValidateSet(1, 2, 3)][int]$BackbufferCount = 1,
        [ValidateSet(0, 128, 256, 512, 1024)][int]$ShadowDepthMin = 0,
        [ValidateRange(0, 4)][int]$ShadowUpresFactor = 0,
        [ValidateRange(0, 8)][int]$MaxDynamicShadows = 0,
        [ValidateSet(0, 128, 256, 512, 1024)][int]$CsmResolution = 512,
        [ValidateSet(1, 2)][int]$ShadowCoverage = 1,
        [ValidateSet(0, 4)][int]$SsaoQuality = 0,
        [bool]$SsaoDownsample = $true,
        [string]$LodScale = 'Auto',
        [string]$FadeDistanceScale = 'Auto',
        [ValidateSet(1, 2)][int]$MapDetailLevel = 1,
        [ValidateSet(64, 128, 256)][int]$DecalLimit = 64,
        [ValidateSet('Auto', 'Default', 'Balanced', 'Aggressive')][string]$ParticleFallback = 'Auto',
        [string]$ViewFov = 'Keep current',
        [bool]$CustomReticle = $false,
        [ValidateRange(0, 255)][int]$ReticleRed = 37,
        [ValidateRange(0, 255)][int]$ReticleGreen = 244,
        [ValidateRange(0, 255)][int]$ReticleBlue = 238
    )
    if (($Width -lt 640) -or ($Width -gt 7680) -or ($Height -lt 360) -or ($Height -gt 4320)) {
        throw 'Custom resolution must be between 640x360 and 7680x4320.'
    }
    $TextureBudget = ConvertTo-TextureBudgetTier -Value $TextureBudget
    $fovScale = $null
    if ($ViewFov -ne 'Keep current') { $fovScale = ConvertTo-ApexFovScale -Fov $ViewFov }
    Assert-ApexClosed
    $path = Get-VideoConfigPath
    if (-not (Test-Path -LiteralPath $path)) { throw "Apex video settings were not found: $path" }
    $profilePath = Get-ProfileConfigPath
    if ((($ViewFov -ne 'Keep current') -or $CustomReticle) -and (-not (Test-Path -LiteralPath $profilePath))) { throw "Apex profile settings were not found: $profilePath" }
    Ensure-RegularApexBaseline

    $values = Get-CommonLowValues
    $native = Get-NativeResolution
    $values['setting.defaultres'] = [string]$Width
    $values['setting.defaultresheight'] = [string]$Height
    $values['setting.last_display_width'] = [string]$native.Width
    $values['setting.last_display_height'] = [string]$native.Height
    switch ($WindowMode) {
        'Fullscreen' { $values['setting.fullscreen'] = '1'; $values['setting.nowindowborder'] = '0' }
        'Borderless' { $values['setting.fullscreen'] = '0'; $values['setting.nowindowborder'] = '1' }
        'Windowed' { $values['setting.fullscreen'] = '0'; $values['setting.nowindowborder'] = '0' }
    }

    $budgetMap = Get-TextureBudgetMap
    $textureMap = @{ 'High' = '0'; 'Low' = '1'; 'Very Low' = '2' }
    $anisoMap = @{ '1x' = '1'; '2x' = '2'; '4x' = '4'; '8x' = '8'; '16x' = '16' }
    $modelMap = @{ 'Minimum' = '0.250000'; 'Very Low' = '0.350000'; 'Low' = '0.600000'; 'Medium' = '0.800000'; 'High' = '1.000000' }
    $particleMap = @{ 'Low' = '0'; 'Medium' = '1'; 'High' = '2' }
    $values['setting.stream_memory'] = $budgetMap[$TextureBudget]
    $values['setting.mat_picmip'] = $textureMap[$TextureQuality]
    $values['setting.mat_forceaniso'] = $anisoMap[$Anisotropic]
    $values['setting.mat_antialias_mode'] = $(if ($AntiAliasing -eq 'TSAA') { '12' } else { '0' })
    $values['setting.r_lod_switch_scale'] = $(if ($LodScale -eq 'Auto') { $modelMap[$ModelDetail] } else { ConvertTo-ApexScaleValue -Value $LodScale -Name 'Geometry LOD scale' -Maximum 2.0 })
    $values['setting.fadeDistScale'] = $(if ($FadeDistanceScale -eq 'Auto') { $modelMap[$ModelDetail] } else { ConvertTo-ApexScaleValue -Value $FadeDistanceScale -Name 'Object fade distance' -Maximum 1.0 })
    $values['setting.particle_cpu_level'] = $particleMap[$ParticleDetail]
    if ($ParticleFallback -eq 'Auto') { $ParticleFallback = switch ($ParticleDetail) { 'Low' { 'Aggressive' }; 'Medium' { 'Balanced' }; default { 'Default' } } }
    switch ($ParticleFallback) {
        'Aggressive' { $values['setting.cl_particle_fallback_base'] = '3'; $values['setting.cl_particle_fallback_multiplier'] = '2' }
        'Balanced' { $values['setting.cl_particle_fallback_base'] = '0'; $values['setting.cl_particle_fallback_multiplier'] = '1.75' }
        default { $values['setting.cl_particle_fallback_base'] = '0'; $values['setting.cl_particle_fallback_multiplier'] = '1' }
    }
    $values['setting.mat_vsync_mode'] = $(if ($VSync) { '1' } else { '0' })
    $values['setting.cl_gib_allow'] = $(if ($Gibs) { '1' } else { '0' })
    $values['setting.cl_ragdoll_self_collision'] = $(if ($RagdollCollision) { '1' } else { '0' })
    $values['setting.mat_mip_linear'] = $(if ($LinearMipFiltering) { '1' } else { '0' })
    $values['setting.dynamic_streaming_budget'] = $(if ($DynamicTextureBudget) { '1' } else { '0' })
    $values['setting.mat_backbuffer_count'] = [string]$BackbufferCount

    $values['setting.shadow_enable'] = $(if ($Shadows) { '1' } else { '0' })
    $values['setting.csm_enabled'] = $(if ($Shadows) { '1' } else { '0' })
    $values['setting.csm_coverage'] = $(if ($Shadows) { [string]$ShadowCoverage } else { '0' })
    $values['setting.csm_cascade_res'] = $(if ($Shadows) { [string]$CsmResolution } else { '0' })
    $values['setting.shadow_depth_dimen_min'] = $(if ($Shadows) { [string]$ShadowDepthMin } else { '0' })
    $values['setting.shadow_depth_upres_factor_max'] = $(if ($Shadows) { [string]$ShadowUpresFactor } else { '0' })
    $values['setting.shadow_maxdynamic'] = $(if ($Shadows) { [string]$MaxDynamicShadows } else { '0' })
    $values['setting.volumetric_lighting'] = $(if ($Effects) { '1' } else { '0' })
    $values['setting.volumetric_fog'] = $(if ($Effects) { '1' } else { '0' })
    $values['setting.ssao_enabled'] = $(if ($AmbientOcclusion) { '1' } else { '0' })
    $values['setting.ssao_quality'] = $(if ($AmbientOcclusion) { [string]$SsaoQuality } else { '0' })
    $values['setting.ssao_downsample'] = $(if ($SsaoDownsample) { '1' } else { '0' })
    $values['setting.map_detail_level'] = $(if ($MapDecorations) { [string]$MapDetailLevel } else { '0' })
    $values['setting.set_dress_level'] = $(if ($MapDecorations) { [string]$MapDetailLevel } else { '0' })
    $values['setting.r_createmodeldecals'] = $(if ($Decals) { '1' } else { '0' })
    $values['setting.r_decals'] = $(if ($Decals) { [string]$DecalLimit } else { '0' })
    $values['setting.cl_ragdoll_maxcount'] = $(if ($Ragdolls) { '8' } else { '0' })

    if ($AdaptiveTarget -eq 0) {
        $values['setting.dvs_enable'] = '0'
    } else {
        $frameTime = [int][Math]::Round(1000000 / $AdaptiveTarget)
        $values['setting.dvs_enable'] = '1'
        $values['setting.dvs_gpuframetime_min'] = [string][Math]::Max(1000, ($frameTime - 750))
        $values['setting.dvs_gpuframetime_max'] = [string]($frameTime + 750)
    }

    $backup = New-VideoConfigBackup -Path $path
    Write-VideoConfigValues -Path $path -Overrides $values

    if ($LowLatency -ne 'Keep current') {
        $settingsPath = Get-SettingsConfigPath
        if (Test-Path -LiteralPath $settingsPath) {
            [void](New-SettingsConfigBackup -Path $settingsPath)
            $lowLatencyValues = switch ($LowLatency) {
                'Off' { @{ 'gfx_nvnUseLowLatency' = '0'; 'gfx_nvnUseLowLatencyBoost' = '0'; 'gfx_amdUseLowLatency' = '0' } }
                'On' { @{ 'gfx_nvnUseLowLatency' = '1'; 'gfx_nvnUseLowLatencyBoost' = '0'; 'gfx_amdUseLowLatency' = '1' } }
                default { @{ 'gfx_nvnUseLowLatency' = '1'; 'gfx_nvnUseLowLatencyBoost' = '1'; 'gfx_amdUseLowLatency' = '1' } }
            }
            Write-SettingsConfigValues -Path $settingsPath -Overrides $lowLatencyValues
        }
    }
    $profileOverrides = @{}
    if ($fovScale) {
        $profileOverrides['cl_fovScale'] = $fovScale
    }
    if ($CustomReticle) {
        $profileOverrides['reticle_color'] = "$ReticleRed $ReticleGreen $ReticleBlue"
    }
    if ($profileOverrides.Count -gt 0) {
        [void](New-ProfileConfigBackup -Path $profilePath)
        Write-SettingsConfigValues -Path $profilePath -Overrides $profileOverrides
    }
    Write-Host "Advanced settings applied. Backup: $backup" -ForegroundColor Green
}

function Restore-LatestBackup {
    Assert-ApexClosed
    $backupRoot = Join-Path $env:LOCALAPPDATA 'ApexPerformanceHelper\Backups'
    $backup = Get-ChildItem -LiteralPath $backupRoot -Filter 'videoconfig-*.txt' -File -ErrorAction SilentlyContinue |
        Sort-Object Name -Descending | Select-Object -First 1
    if (-not $backup) { throw 'No Apex Performance Helper backup was found.' }
    $target = Get-VideoConfigPath
    $targetFolder = Split-Path -Parent $target
    New-Item -ItemType Directory -Force -Path $targetFolder | Out-Null
    if (Test-Path -LiteralPath $target) { Set-ItemProperty -LiteralPath $target -Name IsReadOnly -Value $false -ErrorAction SilentlyContinue }
    Copy-Item -LiteralPath $backup.FullName -Destination $target -Force
    $settingsBackup = Get-ChildItem -LiteralPath $backupRoot -Filter 'settings-*.cfg' -File -ErrorAction SilentlyContinue |
        Sort-Object Name -Descending | Select-Object -First 1
    if ($settingsBackup) {
        Copy-Item -LiteralPath $settingsBackup.FullName -Destination (Get-SettingsConfigPath) -Force
    }
    $profileBackup = Get-ChildItem -LiteralPath $backupRoot -Filter 'profile-*.cfg' -File -ErrorAction SilentlyContinue |
        Sort-Object Name -Descending | Select-Object -First 1
    if ($profileBackup) {
        $profileTarget = Get-ProfileConfigPath
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $profileTarget) | Out-Null
        Copy-Item -LiteralPath $profileBackup.FullName -Destination $profileTarget -Force
    }
    Write-Host "Restored video backup: $($backup.FullName)" -ForegroundColor Green
    if ($settingsBackup) { Write-Host "Restored low-latency backup: $($settingsBackup.FullName)" -ForegroundColor Green }
    if ($profileBackup) { Write-Host "Restored FOV backup: $($profileBackup.FullName)" -ForegroundColor Green }
}

function Clear-ApexPsoCache {
    Assert-ApexClosed
    $cache = Join-Path (Get-ApexRoot) 'local\psoCache.pso'
    if (Test-Path -LiteralPath $cache) {
        Remove-Item -LiteralPath $cache -Force
        Write-Host 'Apex PSO cache removed. It will rebuild; temporary stutter is normal.' -ForegroundColor Yellow
    } else {
        Write-Host 'No Apex PSO cache was found.' -ForegroundColor Yellow
    }
}

$script:RiftlineSteamCache = $null

function Get-SteamRoot {
    $candidates = [System.Collections.Generic.List[string]]::new()
    if ($env:RIFTLINE_STEAM_ROOT) { $candidates.Add($env:RIFTLINE_STEAM_ROOT) }
    if (-not $ConfigPathOverride) {
        foreach ($key in @('HKCU:\Software\Valve\Steam', 'HKLM:\SOFTWARE\WOW6432Node\Valve\Steam', 'HKLM:\SOFTWARE\Valve\Steam')) {
            try {
                $item = Get-ItemProperty -LiteralPath $key -ErrorAction Stop
                foreach ($name in @('SteamPath', 'InstallPath')) {
                    $property = $item.PSObject.Properties[$name]
                    if ($property -and $property.Value) { $candidates.Add(([string]$property.Value) -replace '/', '\') }
                }
            } catch { }
        }
        $candidates.Add('C:\Program Files (x86)\Steam')
        $candidates.Add('C:\Program Files\Steam')
    }
    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path -LiteralPath (Join-Path $candidate 'steamapps'))) { return $candidate }
    }
    return $null
}

function Get-SteamLibraryFolders {
    $root = Get-SteamRoot
    $libraries = [System.Collections.Generic.List[string]]::new()
    if (-not $root) { return @() }
    $libraries.Add($root)
    $vdf = Join-Path (Join-Path $root 'steamapps') 'libraryfolders.vdf'
    if (Test-Path -LiteralPath $vdf) {
        try {
            $text = [System.IO.File]::ReadAllText($vdf)
            # Current format: "path" "D:\\SteamLibrary". Legacy format: "1" "D:\\SteamLibrary".
            $found = @([regex]::Matches($text, '"path"\s+"([^"]+)"')) + @([regex]::Matches($text, '(?m)^\s*"\d+"\s+"([^"]+)"\s*$'))
            foreach ($match in $found) {
                $library = $match.Groups[1].Value -replace '\\\\', '\'
                if ($library -and -not ($libraries -icontains $library)) { $libraries.Add($library) }
            }
        } catch { }
    }
    return $libraries.ToArray()
}

function Get-SteamManifestPath {
    if ($null -ne $script:RiftlineSteamCache) { return $script:RiftlineSteamCache.Manifest }
    $manifest = $null
    foreach ($library in (Get-SteamLibraryFolders)) {
        $candidate = Join-Path (Join-Path $library 'steamapps') 'appmanifest_1172470.acf'
        if (Test-Path -LiteralPath $candidate) { $manifest = $candidate; break }
    }
    # Only cache a hit: Steam or a library drive may appear while the window stays open.
    if ($manifest) { $script:RiftlineSteamCache = [pscustomobject]@{ Manifest = $manifest } }
    return $manifest
}

function Get-SteamExecutable {
    $manifest = Get-SteamManifestPath
    if ($manifest) {
        $text = [System.IO.File]::ReadAllText($manifest)
        if ($text -match '"LauncherPath"\s+"([^"]+)"') {
            $candidate = $Matches[1] -replace '\\\\', '\'
            if (Test-Path -LiteralPath $candidate) { return $candidate }
        }
    }
    $root = Get-SteamRoot
    if ($root) {
        $candidate = Join-Path $root 'steam.exe'
        if (Test-Path -LiteralPath $candidate) { return $candidate }
    }
    if (-not $ConfigPathOverride) {
        try {
            $steamExe = (Get-ItemProperty -LiteralPath 'HKCU:\Software\Valve\Steam' -ErrorAction Stop).SteamExe
            if ($steamExe) { $steamExe = ([string]$steamExe) -replace '/', '\'; if (Test-Path -LiteralPath $steamExe) { return $steamExe } }
        } catch { }
        $known = @('C:\Program Files (x86)\Steam\steam.exe', 'C:\Program Files\Steam\steam.exe')
        foreach ($candidate in $known) { if (Test-Path -LiteralPath $candidate) { return $candidate } }
    }
    return $null
}

function Get-ApexInstallFolder {
    $manifest = Get-SteamManifestPath
    if (-not $manifest) { return $null }
    try {
        $text = [System.IO.File]::ReadAllText($manifest)
        if ($text -match '"installdir"\s+"([^"]+)"') {
            $folder = Join-Path (Split-Path -Parent $manifest) (Join-Path 'common' $Matches[1])
            if (Test-Path -LiteralPath $folder) { return $folder }
        }
    } catch { }
    return $null
}

function Get-SteamConfiguredLanguage {
    $manifest = Get-SteamManifestPath
    if (-not $manifest) { return '' }
    try {
        $text = [System.IO.File]::ReadAllText($manifest)
        if ($text -match '(?s)"UserConfig"\s*\{.*?"language"\s+"([^"]+)"') { return $Matches[1].ToLowerInvariant() }
    } catch { }
    return ''
}

function Get-InstalledApexVoiceLanguages {
    $root = Get-ApexInstallFolder
    if (-not $root) { return @() }
    $audio = Join-Path $root 'audio\ship'
    if (-not (Test-Path -LiteralPath $audio)) { return @() }
    return @(
        Get-ChildItem -LiteralPath $audio -Filter 'general_*.mstr' -File -ErrorAction SilentlyContinue |
            Where-Object { ($_.BaseName -notmatch '_patch_') -and ($_.BaseName -ne 'general_stream') } |
            ForEach-Object { if ($_.BaseName -match '^general_(.+)$') { $Matches[1].ToLowerInvariant() } } |
            Sort-Object -Unique
    )
}

function Get-InstalledApexLocalizationLanguages {
    $root = Get-ApexInstallFolder
    if (-not $root) { return @() }
    $paks = Join-Path $root 'paks\Win64'
    if (-not (Test-Path -LiteralPath $paks)) { return @() }
    return @(
        Get-ChildItem -LiteralPath $paks -Filter 'localization_*.rpak' -File -ErrorAction SilentlyContinue |
            ForEach-Object { if ($_.BaseName -match '^localization_([^()]+)') { $Matches[1].ToLowerInvariant() } } |
            Sort-Object -Unique
    )
}

function Normalize-RiftlineLaunchOptions {
    param([AllowEmptyString()][string]$LaunchOptions)
    $normalized = " $LaunchOptions "
    $installedLocalizations = @(Get-InstalledApexLocalizationLanguages)
    # Voice packs are owned by Steam's per-game language setting. Removing the
    # legacy Miles override avoids loading a pack while Steam is downloading,
    # updating, or switching it, which can crash Apex during engine startup.
    $normalized = [regex]::Replace($normalized, '(?i)\s+\+miles_language\s+[A-Za-z_]+', ' ')
    $normalized = [regex]::Replace($normalized, '(?i)\s+-language\s+([A-Za-z_]+)', {
        param($match)
        $language = $match.Groups[1].Value.ToLowerInvariant()
        if (($installedLocalizations.Count -eq 0) -or ($installedLocalizations -icontains $language)) { return $match.Value }
        return ' '
    })
    return ([regex]::Replace($normalized, '\s+', ' ').Trim())
}

function Get-LaunchOptionsPath {
    $folder = Join-Path $env:LOCALAPPDATA 'ApexPerformanceHelper'
    return (Join-Path $folder 'launch-options.txt')
}

function Get-CustomProfilesPath {
    return (Join-Path $env:LOCALAPPDATA 'ApexPerformanceHelper\custom-profiles.json')
}

function Get-ActiveProfilePath {
    return (Join-Path $env:LOCALAPPDATA 'ApexPerformanceHelper\active-profile.json')
}

function Get-ActiveProfile {
    $empty = [pscustomobject]@{ type = ''; name = '' }
    $path = Get-ActiveProfilePath
    if (-not (Test-Path -LiteralPath $path)) { return $empty }
    try {
        $active = ConvertFrom-Json -InputObject ([System.IO.File]::ReadAllText($path))
        $type = [string]$active.type
        $name = [string]$active.name
        if (($type -notin @('built-in','custom')) -or [string]::IsNullOrWhiteSpace($name)) { return $empty }
        if (($type -eq 'custom') -and (@(Get-CustomProfiles | Where-Object { [string]$_.Name -ieq $name }).Count -eq 0)) { return $empty }
        return [pscustomobject]@{ type = $type; name = $name }
    } catch { return $empty }
}

function Set-ActiveProfile {
    param(
        [Parameter(Mandatory)][ValidateSet('built-in','custom')][string]$Type,
        [Parameter(Mandatory)][string]$Name
    )
    $cleanName = $Name.Trim()
    if ([string]::IsNullOrWhiteSpace($cleanName) -or ($cleanName.Length -gt 40)) { throw 'The active profile name is invalid.' }
    $path = Get-ActiveProfilePath
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $path) | Out-Null
    $json = ConvertTo-Json -InputObject ([pscustomobject]@{ type = $Type; name = $cleanName }) -Compress
    [System.IO.File]::WriteAllText($path, $json, [System.Text.UTF8Encoding]::new($false))
}

function Clear-ActiveProfile {
    $path = Get-ActiveProfilePath
    if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Force }
}

function Get-CustomProfiles {
    $path = Get-CustomProfilesPath
    if (-not (Test-Path -LiteralPath $path)) { return @() }
    try {
        $content = [System.IO.File]::ReadAllText($path)
        if ([string]::IsNullOrWhiteSpace($content)) { return @() }
        $parsed = ConvertFrom-Json -InputObject $content
        $profiles = [System.Collections.Generic.List[object]]::new()
        $pending = [System.Collections.Generic.Queue[object]]::new()
        $pending.Enqueue($parsed)
        while ($pending.Count -gt 0) {
            $item = $pending.Dequeue()
            if ($null -eq $item) { continue }
            if (($item -is [System.Array]) -or ($item -is [System.Collections.IList])) {
                foreach ($nested in $item) { $pending.Enqueue($nested) }
                continue
            }
            if ($item.PSObject.Properties.Name -contains 'Name') { $profiles.Add($item) }
        }
        return $profiles.ToArray()
    } catch {
        throw "Custom profile file is invalid: $path"
    }
}

function Write-CustomProfiles {
    param([Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Profiles)
    $path = Get-CustomProfilesPath
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $path) | Out-Null
    [object[]]$snapshot = @($Profiles)
    $json = ConvertTo-Json -InputObject $snapshot -Depth 5
    [System.IO.File]::WriteAllText($path, $json, [System.Text.UTF8Encoding]::new($false))
}

function Save-CustomProfile {
    param([Parameter(Mandatory)][pscustomobject]$Profile)
    $name = ([string]$Profile.Name).Trim()
    if (($name.Length -lt 1) -or ($name.Length -gt 40)) { throw 'Profile name must be 1-40 characters.' }
    if ($name -match '[\r\n\0\\/:*?"<>|]') { throw 'Profile name contains a character Windows cannot safely use.' }
    $profiles = [System.Collections.Generic.List[object]]::new()
    foreach ($existing in (Get-CustomProfiles)) {
        if ([string]$existing.Name -ine $name) { $profiles.Add($existing) }
    }
    $Profile.Name = $name
    $profiles.Add($Profile)
    Write-CustomProfiles -Profiles $profiles.ToArray()
}

function Remove-CustomProfile {
    param([Parameter(Mandatory)][string]$Name)
    $active = Get-ActiveProfile
    $profiles = @((Get-CustomProfiles) | Where-Object { [string]$_.Name -ine $Name })
    Write-CustomProfiles -Profiles $profiles
    if (($active.type -eq 'custom') -and ($active.name -ieq $Name)) { Clear-ActiveProfile }
}

function Apply-CustomProfile {
    param([Parameter(Mandatory)][pscustomobject]$Profile)
    $ambientOcclusion = $false
    $mapDecorations = $false
    if ($Profile.PSObject.Properties.Name -contains 'AmbientOcclusion') { $ambientOcclusion = [bool]$Profile.AmbientOcclusion }
    if ($Profile.PSObject.Properties.Name -contains 'MapDecorations') { $mapDecorations = [bool]$Profile.MapDecorations }
    $expert = @{ Gibs = $false; RagdollCollision = $false; LinearMipFiltering = $false; DynamicTextureBudget = $true; BackbufferCount = 1; ShadowDepthMin = 0; ShadowUpresFactor = 0; MaxDynamicShadows = 0; CsmResolution = 512; ShadowCoverage = 1; SsaoQuality = 0; SsaoDownsample = $true; LodScale = 'Auto'; FadeDistanceScale = 'Auto'; MapDetailLevel = 1; DecalLimit = 64; ParticleFallback = 'Auto'; ViewFov = 'Keep current'; CustomReticle = $false; ReticleRed = 37; ReticleGreen = 244; ReticleBlue = 238 }
    foreach ($key in @($expert.Keys)) {
        if ($Profile.PSObject.Properties.Name -contains $key) { $expert[$key] = $Profile.PSObject.Properties[$key].Value }
    }
    Apply-AdvancedSettings -Width ([int]$Profile.Width) -Height ([int]$Profile.Height) -WindowMode ([string]$Profile.WindowMode) -TextureBudget ([string]$Profile.TextureBudget) -TextureQuality ([string]$Profile.TextureQuality) -Anisotropic ([string]$Profile.Anisotropic) -AntiAliasing ([string]$Profile.AntiAliasing) -ModelDetail ([string]$Profile.ModelDetail) -ParticleDetail ([string]$Profile.ParticleDetail) -Shadows ([bool]$Profile.Shadows) -Effects ([bool]$Profile.Effects) -AmbientOcclusion $ambientOcclusion -MapDecorations $mapDecorations -Decals ([bool]$Profile.Decals) -Ragdolls ([bool]$Profile.Ragdolls) -VSync ([bool]$Profile.VSync) -AdaptiveTarget ([int]$Profile.AdaptiveTarget) -LowLatency ([string]$Profile.LowLatency) -Gibs ([bool]$expert.Gibs) -RagdollCollision ([bool]$expert.RagdollCollision) -LinearMipFiltering ([bool]$expert.LinearMipFiltering) -DynamicTextureBudget ([bool]$expert.DynamicTextureBudget) -BackbufferCount ([int]$expert.BackbufferCount) -ShadowDepthMin ([int]$expert.ShadowDepthMin) -ShadowUpresFactor ([int]$expert.ShadowUpresFactor) -MaxDynamicShadows ([int]$expert.MaxDynamicShadows) -CsmResolution ([int]$expert.CsmResolution) -ShadowCoverage ([int]$expert.ShadowCoverage) -SsaoQuality ([int]$expert.SsaoQuality) -SsaoDownsample ([bool]$expert.SsaoDownsample) -LodScale ([string]$expert.LodScale) -FadeDistanceScale ([string]$expert.FadeDistanceScale) -MapDetailLevel ([int]$expert.MapDetailLevel) -DecalLimit ([int]$expert.DecalLimit) -ParticleFallback ([string]$expert.ParticleFallback) -ViewFov ([string]$expert.ViewFov) -CustomReticle ([bool]$expert.CustomReticle) -ReticleRed ([int]$expert.ReticleRed) -ReticleGreen ([int]$expert.ReticleGreen) -ReticleBlue ([int]$expert.ReticleBlue)
    Save-LaunchOptions -LaunchOptions ([string]$Profile.LaunchOptions)
    Set-ActiveProfile -Type 'custom' -Name ([string]$Profile.Name)
}

function Get-SavedLaunchOptions {
    $path = Get-LaunchOptionsPath
    if (Test-Path -LiteralPath $path) { return ([System.IO.File]::ReadAllText($path)).Trim() }
    return ''
}

function Assert-LaunchOptionsSafe {
    param([AllowEmptyString()][string]$LaunchOptions)
    if ($LaunchOptions.Length -gt 1024) { throw 'Steam launch commands must be 1024 characters or fewer.' }
    if ($LaunchOptions -match '[\r\n\0]') { throw 'Steam launch commands cannot contain line breaks or null characters.' }
}

function Save-LaunchOptions {
    param([AllowEmptyString()][string]$LaunchOptions)
    $LaunchOptions = Normalize-RiftlineLaunchOptions -LaunchOptions $LaunchOptions
    Assert-LaunchOptionsSafe -LaunchOptions $LaunchOptions
    $path = Get-LaunchOptionsPath
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $path) | Out-Null
    [System.IO.File]::WriteAllText($path, $LaunchOptions.Trim(), [System.Text.UTF8Encoding]::new($false))
}

function Get-NoBlackBarsLaunchArguments {
    param([Parameter(Mandatory)][int]$Width, [Parameter(Mandatory)][int]$Height)
    if (($Width -lt 640) -or ($Width -gt 7680) -or ($Height -lt 360) -or ($Height -gt 4320)) {
        throw 'Choose a valid resolution before enabling stretched mode.'
    }
    return "+mat_letterbox_aspect_goal 0 +mat_letterbox_aspect_threshold 0 +building_cubemaps `"1`" -w $Width -h $Height -fullscreen -multiple"
}

function Set-LetterboxLaunchMode {
    param(
        [Parameter(Mandatory)][bool]$NoBlackBars,
        [int]$Width = 0,
        [int]$Height = 0
    )
    $launchOptions = Get-SavedLaunchOptions
    # Remove every helper-managed stretched-resolution argument before applying
    # the selected mode. Repeated changes therefore never create duplicates.
    $launchOptions = [regex]::Replace(" $launchOptions ", '(?i)\s+\+mat_letterbox_aspect_(?:min|goal|threshold|max)\s+[^\s]+', ' ')
    $launchOptions = [regex]::Replace(" $launchOptions ", '(?i)\s+\+building_cubemaps\s+(?:"[^"]*"|[^\s]+)', ' ')
    $launchOptions = [regex]::Replace(" $launchOptions ", '(?i)\s+-(?:w|h)\s+\d+', ' ')
    $launchOptions = [regex]::Replace(" $launchOptions ", '(?i)\s+-(?:fullscreen|multiple)\b', ' ')
    $launchOptions = [regex]::Replace($launchOptions, '\s+', ' ').Trim()
    if ($NoBlackBars) {
        $launchOptions = (($launchOptions + ' ' + (Get-NoBlackBarsLaunchArguments -Width $Width -Height $Height)).Trim())
    }
    Save-LaunchOptions -LaunchOptions $launchOptions
    return $launchOptions
}

function Get-SteamRunUri {
    param([AllowEmptyString()][string]$LaunchOptions)
    $LaunchOptions = Normalize-RiftlineLaunchOptions -LaunchOptions $LaunchOptions
    Assert-LaunchOptionsSafe -LaunchOptions $LaunchOptions
    if ([string]::IsNullOrWhiteSpace($LaunchOptions)) { return 'steam://rungameid/1172470' }
    $encoded = [System.Uri]::EscapeDataString($LaunchOptions.Trim())
    return "steam://run/1172470//$encoded/"
}

function Launch-Apex {
    param([AllowEmptyString()][string]$LaunchOptions = '')
    $LaunchOptions = Normalize-RiftlineLaunchOptions -LaunchOptions $LaunchOptions
    $manifest = Get-SteamManifestPath
    if ($manifest) {
        Save-LaunchOptions -LaunchOptions $LaunchOptions
        $steamExecutable = Get-SteamExecutable
        if ($steamExecutable) {
            $arguments = '-applaunch 1172470'
            if (-not [string]::IsNullOrWhiteSpace($LaunchOptions)) { $arguments += ' ' + $LaunchOptions.Trim() }
            Start-Process -FilePath $steamExecutable -ArgumentList $arguments
        } else {
            Start-Process (Get-SteamRunUri -LaunchOptions $LaunchOptions)
        }
        Write-Host 'Apex launch request sent with the helper-managed commands.' -ForegroundColor Green
        return
    }
    throw 'A Steam Apex installation was not detected. Start Apex from the EA app or your normal launcher.'
}

function Show-Inspection {
    $hardware = Get-HardwareRecommendation
    $native = Get-NativeResolution
    Write-Host "CPU:        $($hardware.CPU)"
    Write-Host "GPU:        $($hardware.GPU)"
    Write-Host "Display:    $($native.Width)x$($native.Height)"
    Write-Host "Recommended: $($hardware.Label)"
    Write-Host "Config:     $(Get-VideoConfigPath)"
    Write-Host "Steam:      $(Get-SteamManifestPath)"
    Write-Host "Launcher:   $(Get-SteamExecutable)"
}

function Invoke-Build23SelfTest {
    param([string]$VideoPath, [string]$ProfileConfigPath, [string]$SettingsPath)
    # FOV math matches Apex's own slider, and old Riftline values read back as the value the user picked.
    if ((ConvertTo-ApexFovScale -Fov '110') -ne '1.550000') { throw 'Self-test failed: 110 FOV scale.' }
    if ((ConvertTo-ApexFovScale -Fov '104') -ne '1.467500') { throw 'Self-test failed: 104 FOV scale.' }
    if ((ConvertFrom-ApexFovScale -Scale '1.285714') -ne '90') { throw 'Self-test failed: legacy 90 FOV read-back.' }
    if ((ConvertFrom-ApexFovScale -Scale '1.55') -ne '110') { throw 'Self-test failed: Apex 110 FOV read-back.' }
    $fovRejected = $false; try { [void](ConvertTo-ApexFovScale -Fov '150') } catch { $fovRejected = $true }
    if (-not $fovRejected) { throw 'Self-test failed: out-of-range FOV was accepted.' }
    if ((ConvertTo-TextureBudgetTier -Value '3 GB') -ne 'Medium' -or (ConvertTo-TextureBudgetTier -Value 'insane') -ne 'Insane') { throw 'Self-test failed: texture budget tier mapping.' }

    # The full apply path through the shared dispatcher, then read the live files back.
    $body = ConvertFrom-Json -InputObject '{"width":1440,"height":1080,"windowMode":"Borderless","aspectMode":"stretched","textureBudget":"Very High","textureQuality":"Low","anisotropic":"8x","antiAliasing":"TSAA","modelDetail":"Medium","particleDetail":"Medium","shadows":true,"effects":false,"ambientOcclusion":true,"mapDecorations":true,"decals":true,"ragdolls":false,"vsync":false,"adaptiveTarget":144,"renderScaleFloor":70,"lowLatency":"On","gibs":false,"ragdollCollision":true,"linearMipFiltering":true,"dynamicTextureBudget":true,"backbufferCount":1,"shadowDepthMin":256,"shadowUpresFactor":1,"maxDynamicShadows":2,"csmResolution":512,"shadowCoverage":2,"ssaoQuality":4,"ssaoDownsample":true,"lodScale":"0.80","fadeDistanceScale":"0.70","mapDetailLevel":2,"decalLimit":128,"particleFallback":"Balanced","viewFov":"104","customReticle":true,"reticleRed":10,"reticleGreen":20,"reticleBlue":30,"launchOptions":"+fps_max 165 -novid +mat_letterbox_aspect_goal 0 +mat_letterbox_aspect_threshold 0 +building_cubemaps \"1\" -w 1440 -h 1080 -fullscreen -multiple"}'
    $result = Invoke-RiftlineAction -Action 'apply' -Body $body
    if (-not $result.ok -or -not $result.live.current) { throw 'Self-test failed: apply did not return the refreshed live state.' }
    $c = $result.live.current
    $expected = @{ width = 1440; height = 1080; windowMode = 'Fullscreen'; textureBudget = 'Very High'; textureQuality = 'Low'; anisotropic = '8x'; antiAliasing = 'TSAA'; particleDetail = 'Medium'; shadows = $true; effects = $false; ambientOcclusion = $true; mapDecorations = $true; decals = $true; ragdollCollision = $true; linearMipFiltering = $true; adaptiveTarget = 144; lowLatency = 'On'; shadowDepthMin = 256; maxDynamicShadows = 2; shadowCoverage = 2; ssaoQuality = 4; lodScale = '0.80'; fadeDistanceScale = '0.70'; mapDetailLevel = 2; decalLimit = 128; particleFallback = 'Balanced'; viewFov = '104' }
    foreach ($key in $expected.Keys) {
        if ([string]$c.$key -ne [string]$expected[$key]) { throw "Self-test failed: live read-back of $key was '$($c.$key)', expected '$($expected[$key])'." }
    }
    if ($result.live.reticleColor -ne '10 20 30') { throw 'Self-test failed: reticle read-back.' }

    # Steam on a secondary library drive.
    $steamRoot = Join-Path (Split-Path -Parent (Split-Path -Parent $VideoPath)) 'FakeSteam'
    $library = Join-Path (Split-Path -Parent (Split-Path -Parent $VideoPath)) 'FakeLibrary'
    New-Item -ItemType Directory -Force -Path (Join-Path $steamRoot 'steamapps'), (Join-Path $library 'steamapps') | Out-Null
    $escapedLibrary = $library -replace '\\', '\\'
    [System.IO.File]::WriteAllText((Join-Path (Join-Path $steamRoot 'steamapps') 'libraryfolders.vdf'), "`"libraryfolders`"`n{`n`t`"0`"`n`t{`n`t`t`"path`"`t`t`"$($steamRoot -replace '\\', '\\')`"`n`t}`n`t`"1`"`n`t{`n`t`t`"path`"`t`t`"$escapedLibrary`"`n`t}`n}`n")
    [System.IO.File]::WriteAllText((Join-Path (Join-Path $library 'steamapps') 'appmanifest_1172470.acf'), "`"AppState`"`n{`n`t`"installdir`"`t`t`"Apex Legends`"`n}`n")
    $previousSteamRoot = $env:RIFTLINE_STEAM_ROOT
    try {
        $env:RIFTLINE_STEAM_ROOT = $steamRoot
        $script:RiftlineSteamCache = $null
        $manifest = Get-SteamManifestPath
        if (-not $manifest -or ($manifest -notlike "$library*")) { throw "Self-test failed: Apex was not found on a secondary Steam library ($manifest)." }
    } finally {
        $env:RIFTLINE_STEAM_ROOT = $previousSteamRoot
        $script:RiftlineSteamCache = $null
    }

    # Backup pruning keeps a bounded history once the baseline exists.
    $originalKeep = $script:RiftlineBackupKeepCount
    try {
        $script:RiftlineBackupKeepCount = 3
        1..6 | ForEach-Object { [void](New-VideoConfigBackup -Path $VideoPath); Start-Sleep -Milliseconds 15 }
        $count = @(Get-ChildItem -LiteralPath (Get-RiftlineBackupRoot) -Filter 'videoconfig-*.txt' -File).Count
        if ($count -ne 3) { throw "Self-test failed: backup pruning kept $count files." }
        if (-not (Test-Path -LiteralPath (Join-Path (Get-RegularApexBaselineFolder) 'videoconfig.txt'))) { throw 'Self-test failed: baseline missing after pruning.' }
    } finally { $script:RiftlineBackupKeepCount = $originalKeep }
}

function Invoke-SelfTest {
    $path = Get-VideoConfigPath
    if (-not $ConfigPathOverride) { throw 'SelfTest requires -ConfigPathOverride.' }
    $folder = Split-Path -Parent $path
    New-Item -ItemType Directory -Force -Path $folder | Out-Null
    $sample = @'
"VideoConfig"
{
	"setting.sound_volume"		"0.750000"
	"setting.defaultres"		"1600"
	"setting.defaultresheight"		"900"
	"setting.configversion"		"10"
}
'@
    [System.IO.File]::WriteAllText($path, $sample + [char]0, [System.Text.UTF8Encoding]::new($false))
    $profileConfigPath = Get-ProfileConfigPath
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $profileConfigPath) | Out-Null
    [System.IO.File]::WriteAllText($profileConfigPath, "cl_fovScale `"1.55`"`r`nreticle_color `"`"`r`nmouse_sensitivity `"2.0`"`r`n", [System.Text.UTF8Encoding]::new($false))
    $settingsPath = Get-SettingsConfigPath
    [System.IO.File]::WriteAllText($settingsPath, "mouse_sensitivity `"1.7`"`r`ngfx_nvnUseLowLatency `"0`"`r`n", [System.Text.UTF8Encoding]::new($false))
    Ensure-RegularApexBaseline
    Write-VideoConfigValues -Path $path -Overrides (Get-ProfileValues -Profile 'LowEnd720')
    $result = Get-VideoConfigValues -Path $path
    if ($result['setting.defaultres'] -ne '1280') { throw 'Self-test failed: resolution was not updated.' }
    if ($result['setting.defaultresheight'] -ne '720') { throw 'Self-test failed: height was not updated.' }
    if ($result['setting.sound_volume'] -ne '0.750000') { throw 'Self-test failed: unrelated audio value changed.' }
    if ($result['setting.configversion'] -ne '10') { throw 'Self-test failed: config version changed.' }
    if ($result['setting.shadow_enable'] -ne '0') { throw 'Self-test failed: missing keys were not inserted.' }

    Apply-AdvancedSettings -Width 1111 -Height 777 -WindowMode 'Windowed' -TextureBudget '4 GB' -TextureQuality 'Very Low' -Anisotropic '8x' -AntiAliasing 'TSAA' -ModelDetail 'Medium' -ParticleDetail 'Medium' -Shadows $true -Effects $true -AmbientOcclusion $true -MapDecorations $true -Decals $true -Ragdolls $true -VSync $false -AdaptiveTarget 120 -LowLatency 'On + Boost' -Gibs $true -RagdollCollision $true -LinearMipFiltering $true -DynamicTextureBudget $false -BackbufferCount 2 -ShadowDepthMin 256 -ShadowUpresFactor 1 -MaxDynamicShadows 2 -CsmResolution 1024 -ShadowCoverage 2 -SsaoQuality 4 -SsaoDownsample $false -LodScale '1.50' -FadeDistanceScale '0.50' -MapDetailLevel 2 -DecalLimit 256 -ParticleFallback 'Balanced' -ViewFov '90' -CustomReticle $true -ReticleRed 37 -ReticleGreen 244 -ReticleBlue 238
    $advancedResult = Get-VideoConfigValues -Path $path
    if (($advancedResult['setting.defaultres'] -ne '1111') -or ($advancedResult['setting.defaultresheight'] -ne '777')) { throw 'Self-test failed: arbitrary resolution was not applied.' }
    if ($advancedResult['setting.stream_memory'] -ne '1000000') { throw 'Self-test failed: legacy 4 GB texture budget was not mapped to the High tier.' }
    if ($advancedResult['setting.cl_ragdoll_self_collision'] -ne '1') { throw 'Self-test failed: ragdoll collision was overwritten.' }
    if (($advancedResult['setting.dvs_enable'] -ne '1') -or (-not $advancedResult.ContainsKey('setting.dvs_gpuframetime_max'))) { throw 'Self-test failed: adaptive resolution was not applied.' }
    if (($advancedResult['setting.ssao_enabled'] -ne '1') -or ($advancedResult['setting.ssao_quality'] -ne '4') -or ($advancedResult['setting.set_dress_level'] -ne '2')) { throw 'Self-test failed: lighting or map decoration controls were not applied.' }
    if (($advancedResult['setting.cl_gib_allow'] -ne '1') -or ($advancedResult['setting.mat_mip_linear'] -ne '1') -or ($advancedResult['setting.mat_backbuffer_count'] -ne '2')) { throw 'Self-test failed: expert texture/effects controls were not applied.' }
    if (($advancedResult['setting.shadow_depth_dimen_min'] -ne '256') -or ($advancedResult['setting.csm_cascade_res'] -ne '1024') -or ($advancedResult['setting.csm_coverage'] -ne '2') -or ($advancedResult['setting.ssao_downsample'] -ne '0')) { throw 'Self-test failed: expert shadow/AO controls were not applied.' }
    if (($advancedResult['setting.r_lod_switch_scale'] -ne '1.500000') -or ($advancedResult['setting.fadeDistScale'] -ne '0.500000') -or ($advancedResult['setting.r_decals'] -ne '256') -or ($advancedResult['setting.cl_particle_fallback_multiplier'] -ne '1.75')) { throw 'Self-test failed: distance, decal, or particle-fallback controls were not applied.' }
    $profileConfigText = [System.IO.File]::ReadAllText($profileConfigPath)
    if (($profileConfigText -notmatch 'cl_fovScale "1\.275000"') -or ($profileConfigText -notmatch 'reticle_color "37 244 238"') -or ($profileConfigText -notmatch 'mouse_sensitivity "2\.0"')) { throw 'Self-test failed: FOV or reticle color was not applied safely to profile.cfg.' }
    $settingsText = [System.IO.File]::ReadAllText($settingsPath)
    if ($settingsText -notmatch 'gfx_nvnUseLowLatencyBoost "1"') { throw 'Self-test failed: low-latency boost was not applied.' }
    if ($settingsText -notmatch 'mouse_sensitivity "1.7"') { throw 'Self-test failed: unrelated settings.cfg values changed.' }
    $uri = Get-SteamRunUri -LaunchOptions '+fps_max 144 -novid'
    if ($uri -notmatch '^steam://run/1172470//') { throw 'Self-test failed: Steam launch URI was not built.' }
    Apply-Profile -Profile 'LowEnd720'
    if ((Get-SavedLaunchOptions) -ne '+fps_max 0 -novid +dvs_scale_min 0.5') { throw 'Self-test failed: built-in profile did not save its app-managed launcher settings.' }
    if (((Get-ActiveProfile).type -ne 'built-in') -or ((Get-ActiveProfile).name -ne 'LowEnd720')) { throw 'Self-test failed: built-in active profile was not remembered.' }
    Apply-Profile -Profile 'Potato360'
    $potatoResult = Get-VideoConfigValues -Path $path
    if (($potatoResult['setting.defaultres'] -ne '640') -or ($potatoResult['setting.defaultresheight'] -ne '360')) { throw 'Self-test failed: Potato 360p resolution was not applied.' }
    if (($potatoResult['setting.ssao_enabled'] -ne '0') -or ($potatoResult['setting.set_dress_level'] -ne '0')) { throw 'Self-test failed: Potato lighting/detail reductions were not applied.' }
    if ((Get-SavedLaunchOptions) -ne '+fps_max 30 -novid +dvs_scale_min 0.5') { throw 'Self-test failed: Potato launcher settings were not saved.' }
    $testProfile = [pscustomobject]@{ Name = 'Self Test'; Width = 1280; Height = 720; WindowMode = 'Fullscreen'; AspectMode = 'stretched'; TextureBudget = '3 GB'; TextureQuality = 'Low'; Anisotropic = '1x'; AntiAliasing = 'Off'; ModelDetail = 'Low'; ParticleDetail = 'Low'; Shadows = $false; Effects = $false; AmbientOcclusion = $false; MapDecorations = $false; Decals = $false; Ragdolls = $false; VSync = $false; AdaptiveTarget = 0; RenderScaleFloor = 70; LowLatency = 'On'; Gibs = $true; RagdollCollision = $false; LinearMipFiltering = $false; DynamicTextureBudget = $true; BackbufferCount = 1; ShadowDepthMin = 0; ShadowUpresFactor = 0; MaxDynamicShadows = 0; CsmResolution = 512; ShadowCoverage = 1; SsaoQuality = 0; SsaoDownsample = $true; MapDetailLevel = 1; DecalLimit = 64; LodScale = '0.35'; FadeDistanceScale = '0.50'; ParticleFallback = 'Balanced'; ViewFov = '120'; CustomReticle = $true; ReticleRed = 255; ReticleGreen = 64; ReticleBlue = 160; LaunchOptions = '+fps_max 120 -novid -language french +miles_language french' }
    Save-CustomProfile -Profile $testProfile
    $secondProfile = $testProfile.PSObject.Copy(); $secondProfile.Name = 'Second Test'; $secondProfile.Width = 1600
    Save-CustomProfile -Profile $secondProfile
    $profileList = @(Get-CustomProfiles)
    if (($profileList.Count -ne 2) -or ([string]$profileList[0].Name -ne 'Self Test') -or ([string]$profileList[1].Name -ne 'Second Test')) { throw 'Self-test failed: multiple custom profiles were combined instead of listed separately.' }
    $profilePath = Get-CustomProfilesPath
    $normalProfileJson = [System.IO.File]::ReadAllText($profilePath)
    [System.IO.File]::WriteAllText($profilePath, "[$normalProfileJson]", [System.Text.UTF8Encoding]::new($false))
    $recoveredProfiles = @(Get-CustomProfiles)
    if (($recoveredProfiles.Count -ne 2) -or ([string]$recoveredProfiles[1].Name -ne 'Second Test')) { throw 'Self-test failed: legacy nested custom profiles were not recovered.' }
    $loadedProfile = @(Get-CustomProfiles | Where-Object { $_.Name -eq 'Self Test' }) | Select-Object -First 1
    if ((-not $loadedProfile) -or ([int]$loadedProfile.Width -ne 1280)) { throw 'Self-test failed: custom profile was not saved.' }
    Apply-CustomProfile -Profile $loadedProfile
    if ((Get-SavedLaunchOptions) -ne '+fps_max 120 -novid -language french') { throw 'Self-test failed: custom profile language was not safely normalized.' }
    if ((Get-SavedLaunchOptions) -match 'miles_language') { throw 'Self-test failed: an unavailable voice pack command was not removed.' }
    if (((Get-ActiveProfile).type -ne 'custom') -or ((Get-ActiveProfile).name -ne 'Self Test') -or ([string]$loadedProfile.AspectMode -ne 'stretched')) { throw 'Self-test failed: custom active profile or Display state was not remembered.' }
    $stretchedOptions = Set-LetterboxLaunchMode -NoBlackBars $true -Width 2304 -Height 1728
    $expectedStretch = '+fps_max 120 -novid -language french +mat_letterbox_aspect_goal 0 +mat_letterbox_aspect_threshold 0 +building_cubemaps "1" -w 2304 -h 1728 -fullscreen -multiple'
    if (($stretchedOptions -ne $expectedStretch) -or ((Get-SavedLaunchOptions) -ne $stretchedOptions)) { throw 'Self-test failed: fullscreen no-black-bars launch commands were not added.' }
    $blackBarsOptions = Set-LetterboxLaunchMode -NoBlackBars $false
    if (($blackBarsOptions -ne '+fps_max 120 -novid -language french') -or ((Get-SavedLaunchOptions) -match 'mat_letterbox')) { throw 'Self-test failed: letterbox launch overrides were not removed.' }
    Save-LaunchOptions -LaunchOptions '+fps_max 120 +mat_letterbox_aspect_goal 0 +mat_letterbox_aspect_threshold 0 +building_cubemaps "1" -w 2304 -h 1728 -fullscreen -multiple'
    $legacyCleanedOptions = Set-LetterboxLaunchMode -NoBlackBars $false
    if ($legacyCleanedOptions -ne '+fps_max 120') { throw 'Self-test failed: legacy letterbox overrides were not removed.' }
    Save-LaunchOptions -LaunchOptions '+fps_max 120 -novid'
    if ((Get-VideoConfigValues -Path $path)['setting.cl_gib_allow'] -ne '1') { throw 'Self-test failed: custom profile expert settings were not applied.' }
    if ((Get-VideoConfigValues -Path $path)['setting.r_lod_switch_scale'] -ne '0.350000') { throw 'Self-test failed: custom profile distance setting was not applied.' }
    $customProfileText = [System.IO.File]::ReadAllText($profileConfigPath)
    if (($customProfileText -notmatch 'cl_fovScale "1\.687500"') -or ($customProfileText -notmatch 'reticle_color "255 64 160"')) { throw 'Self-test failed: custom profile 120 FOV or reticle was not applied.' }
    Apply-TurboCurrentResolution
    $turboResult = Get-VideoConfigValues -Path $path
    if (($turboResult['setting.defaultres'] -ne '1280') -or ($turboResult['setting.defaultresheight'] -ne '720')) { throw 'Self-test failed: Turbo changed the existing output resolution.' }
    if (($turboResult['setting.dvs_enable'] -ne '1') -or ((Get-SavedLaunchOptions) -notmatch 'dvs_scale_min 0.5')) { throw 'Self-test failed: Turbo 3D-resolution scaling was not enabled.' }
    Restore-LatestBackup
    if ([System.IO.File]::ReadAllText($profileConfigPath) -notmatch 'cl_fovScale "1\.275000"') { throw 'Self-test failed: FOV backup was not restored.' }
    Restore-RegularApex
    $regularResult = Get-VideoConfigValues -Path $path
    if (($regularResult['setting.defaultres'] -ne '1600') -or ($regularResult['setting.defaultresheight'] -ne '900')) { throw 'Self-test failed: regular Apex video baseline was not restored.' }
    if ([System.IO.File]::ReadAllText($profileConfigPath) -notmatch 'cl_fovScale "1\.55"') { throw 'Self-test failed: regular Apex FOV baseline was not restored.' }
    if ([System.IO.File]::ReadAllText($settingsPath) -notmatch 'gfx_nvnUseLowLatency "0"') { throw 'Self-test failed: regular Apex latency baseline was not restored.' }
    if ((Get-SavedLaunchOptions) -ne '') { throw 'Self-test failed: regular Apex restore did not clear app-managed launch commands.' }
    if (-not [string]::IsNullOrWhiteSpace((Get-ActiveProfile).name)) { throw 'Self-test failed: regular Apex restore did not clear the active profile.' }
    Invoke-Build23SelfTest -VideoPath $path -ProfileConfigPath $profileConfigPath -SettingsPath $settingsPath
    Remove-CustomProfile -Name 'Self Test'
    if (@(Get-CustomProfiles | Where-Object { $_.Name -eq 'Self Test' }).Count -ne 0) { throw 'Self-test failed: custom profile was not removed.' }
    Remove-CustomProfile -Name 'Second Test'
    Write-Host 'Self-test passed.' -ForegroundColor Green
}

function Invoke-Mode {
    param([string]$SelectedMode)
    switch ($SelectedMode) {
        'Auto' { $hardware = Get-HardwareRecommendation; Apply-Profile -Profile $hardware.Profile }
        'TurboCurrent' { Apply-TurboCurrentResolution }
        'Competitive' { Apply-Profile -Profile 'Competitive' }
        'Performance1080' { Apply-Profile -Profile 'Performance1080' }
        'LowEnd720' { Apply-Profile -Profile 'LowEnd720' }
        'UltraLow' { Apply-Profile -Profile 'UltraLow' }
        'Potato360' { Apply-Profile -Profile 'Potato360' }
        'Balanced' { Apply-Profile -Profile 'Balanced' }
        'Restore' { Restore-LatestBackup }
        'CleanCache' { Clear-ApexPsoCache }
        'Inspect' { Show-Inspection }
        'Launch' { Launch-Apex -LaunchOptions (Get-SavedLaunchOptions) }
        'SelfTest' { Invoke-SelfTest }
        default { throw "Unknown mode: $SelectedMode" }
    }
}

function Get-NearestOption {
    param([AllowEmptyString()][string]$Value, [Parameter(Mandatory)][double[]]$Options)
    $number = 0.0
    if (-not [double]::TryParse($Value, [System.Globalization.NumberStyles]::Float, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$number)) { return $null }
    $best = $Options[0]
    foreach ($option in $Options) { if ([Math]::Abs($option - $number) -lt [Math]::Abs($best - $number)) { $best = $option } }
    return $best
}

function Read-KeyValueConfig {
    param([Parameter(Mandatory)][string]$Path)
    $values = @{}
    if (-not (Test-Path -LiteralPath $Path)) { return $values }
    foreach ($line in [System.IO.File]::ReadAllLines($Path)) {
        if ($line -match '^\s*"?([^\s"]+)"?\s+"([^"]*)"') { $values[$Matches[1]] = $Matches[2] }
    }
    return $values
}

function Get-RiftlineCurrentSettings {
    # Translates the live Apex files into the interface's own vocabulary so the
    # app always opens on what Apex will actually use, not on placeholder values.
    $path = Get-VideoConfigPath
    if (-not (Test-Path -LiteralPath $path)) { return $null }
    $v = Get-VideoConfigValues -Path $path
    $invariant = [System.Globalization.CultureInfo]::InvariantCulture
    $get = { param($key) if ($v.ContainsKey($key)) { [string]$v[$key] } else { '' } }
    $isOn = { param($key) ((& $get $key) -match '^\s*[1-9]') }
    $current = [ordered]@{}

    $width = 0; $height = 0
    if ([int]::TryParse((& $get 'setting.defaultres'), [ref]$width) -and [int]::TryParse((& $get 'setting.defaultresheight'), [ref]$height) -and $width -ge 640 -and $height -ge 360) {
        $current.width = $width; $current.height = $height
    }
    if ($v.ContainsKey('setting.fullscreen')) {
        $current.windowMode = $(if (& $isOn 'setting.fullscreen') { 'Fullscreen' } elseif (& $isOn 'setting.nowindowborder') { 'Borderless' } else { 'Windowed' })
    }
    if ($v.ContainsKey('setting.stream_memory')) {
        $map = Get-TextureBudgetMap
        $nearest = Get-NearestOption -Value (& $get 'setting.stream_memory') -Options @($map.Values | ForEach-Object { [double]$_ })
        if ($null -ne $nearest) { foreach ($tier in $map.Keys) { if ([double]$map[$tier] -eq $nearest) { $current.textureBudget = $tier } } }
    }
    if ($v.ContainsKey('setting.mat_picmip')) {
        $picmip = Get-NearestOption -Value (& $get 'setting.mat_picmip') -Options @(0, 1, 2)
        if ($null -ne $picmip) { $current.textureQuality = @('High', 'Low', 'Very Low')[[int]$picmip] }
    }
    if ($v.ContainsKey('setting.mat_forceaniso')) {
        $aniso = Get-NearestOption -Value (& $get 'setting.mat_forceaniso') -Options @(1, 2, 4, 8, 16)
        if ($null -ne $aniso) { $current.anisotropic = "$([int]$aniso)x" }
    }
    if ($v.ContainsKey('setting.mat_antialias_mode')) { $current.antiAliasing = $(if (& $isOn 'setting.mat_antialias_mode') { 'TSAA' } else { 'Off' }) }
    $formatScale = { param($number) $number.ToString('0.00', $invariant) }
    # Exact values are returned (e.g. 0.45 from the 1080p profile) so re-applying
    # from the interface never nudges them to the nearest list entry.
    if ($v.ContainsKey('setting.r_lod_switch_scale')) {
        $lodExact = 0.0
        if ([double]::TryParse((& $get 'setting.r_lod_switch_scale'), [System.Globalization.NumberStyles]::Float, $invariant, [ref]$lodExact) -and $lodExact -ge 0.1 -and $lodExact -le 2.0) {
            $current.lodScale = (& $formatScale ([Math]::Round($lodExact, 2)))
            $model = Get-NearestOption -Value ($lodExact.ToString($invariant)) -Options @(0.25, 0.35, 0.6, 0.8, 1.0)
            $current.modelDetail = @{ '0.25' = 'Minimum'; '0.35' = 'Very Low'; '0.60' = 'Low'; '0.80' = 'Medium'; '1.00' = 'High' }[(& $formatScale $model)]
        }
    }
    if ($v.ContainsKey('setting.fadeDistScale')) {
        $fadeExact = 0.0
        if ([double]::TryParse((& $get 'setting.fadeDistScale'), [System.Globalization.NumberStyles]::Float, $invariant, [ref]$fadeExact) -and $fadeExact -ge 0.1 -and $fadeExact -le 1.0) {
            $current.fadeDistanceScale = (& $formatScale ([Math]::Round($fadeExact, 2)))
        }
    }
    if ($v.ContainsKey('setting.particle_cpu_level')) {
        $particle = Get-NearestOption -Value (& $get 'setting.particle_cpu_level') -Options @(0, 1, 2)
        if ($null -ne $particle) { $current.particleDetail = @('Low', 'Medium', 'High')[[int]$particle] }
    }
    if ($v.ContainsKey('setting.cl_particle_fallback_base')) {
        $base = & $get 'setting.cl_particle_fallback_base'; $multiplier = & $get 'setting.cl_particle_fallback_multiplier'
        $current.particleFallback = $(if ($base -match '^3') { 'Aggressive' } elseif ($multiplier -match '^1\.7') { 'Balanced' } elseif ($multiplier -match '^1(\.0+)?$') { 'Default' } else { 'Auto' })
    }
    $current.shadows = [bool]((& $isOn 'setting.csm_enabled') -or (& $isOn 'setting.shadow_enable'))
    $current.effects = [bool](& $isOn 'setting.volumetric_lighting')
    $current.ambientOcclusion = [bool](& $isOn 'setting.ssao_enabled')
    $current.mapDecorations = [bool](& $isOn 'setting.map_detail_level')
    $current.decals = [bool](& $isOn 'setting.r_createmodeldecals')
    $current.ragdolls = [bool](& $isOn 'setting.cl_ragdoll_maxcount')
    $current.vsync = [bool](& $isOn 'setting.mat_vsync_mode')
    $current.gibs = [bool](& $isOn 'setting.cl_gib_allow')
    $current.ragdollCollision = [bool](& $isOn 'setting.cl_ragdoll_self_collision')
    $current.linearMipFiltering = [bool](& $isOn 'setting.mat_mip_linear')
    if ($v.ContainsKey('setting.dynamic_streaming_budget')) { $current.dynamicTextureBudget = [bool](& $isOn 'setting.dynamic_streaming_budget') }
    if ($v.ContainsKey('setting.ssao_downsample')) { $current.ssaoDownsample = [bool](& $isOn 'setting.ssao_downsample') }
    $numeric = @(
        @{ Key = 'setting.mat_backbuffer_count'; Name = 'backbufferCount'; Options = @(1, 2, 3) },
        @{ Key = 'setting.shadow_depth_dimen_min'; Name = 'shadowDepthMin'; Options = @(0, 128, 256, 512, 1024) },
        @{ Key = 'setting.shadow_depth_upres_factor_max'; Name = 'shadowUpresFactor'; Options = @(0, 1, 2, 3, 4) },
        @{ Key = 'setting.shadow_maxdynamic'; Name = 'maxDynamicShadows'; Options = @(0, 1, 2, 4, 8) },
        @{ Key = 'setting.csm_cascade_res'; Name = 'csmResolution'; Options = @(0, 128, 256, 512, 1024) },
        @{ Key = 'setting.csm_coverage'; Name = 'shadowCoverage'; Options = @(1, 2) },
        @{ Key = 'setting.ssao_quality'; Name = 'ssaoQuality'; Options = @(0, 4) },
        @{ Key = 'setting.map_detail_level'; Name = 'mapDetailLevel'; Options = @(1, 2) },
        @{ Key = 'setting.r_decals'; Name = 'decalLimit'; Options = @(64, 128, 256) }
    )
    foreach ($item in $numeric) {
        if (-not $v.ContainsKey($item.Key)) { continue }
        $nearest = Get-NearestOption -Value (& $get $item.Key) -Options $item.Options
        if ($null -ne $nearest) { $current[$item.Name] = [int]$nearest }
    }
    if (& $isOn 'setting.dvs_enable') {
        $low = 0; $high = 0
        if ([int]::TryParse((& $get 'setting.dvs_gpuframetime_min'), [ref]$low) -and [int]::TryParse((& $get 'setting.dvs_gpuframetime_max'), [ref]$high) -and ($low + $high) -gt 0) {
            $fps = 1000000.0 / (($low + $high) / 2.0)
            $current.adaptiveTarget = [int](Get-NearestOption -Value ($fps.ToString($invariant)) -Options @(60, 75, 90, 120, 144, 165, 240))
        } else { $current.adaptiveTarget = 120 }
    } else { $current.adaptiveTarget = 0 }

    $settings = Read-KeyValueConfig -Path (Get-SettingsConfigPath)
    if ($settings.ContainsKey('gfx_nvnUseLowLatency') -or $settings.ContainsKey('gfx_amdUseLowLatency')) {
        $lowLatencyOn = ([string]$settings['gfx_nvnUseLowLatency'] -match '^[1-9]') -or ([string]$settings['gfx_amdUseLowLatency'] -match '^[1-9]')
        $current.lowLatency = $(if (-not $lowLatencyOn) { 'Off' } elseif ([string]$settings['gfx_nvnUseLowLatencyBoost'] -match '^[1-9]') { 'On + Boost' } else { 'On' })
    }
    $profileValues = Read-KeyValueConfig -Path (Get-ProfileConfigPath)
    if ($profileValues.ContainsKey('cl_fovScale')) {
        $fov = ConvertFrom-ApexFovScale -Scale ([string]$profileValues['cl_fovScale'])
        if ($fov) { $current.viewFov = $fov }
    }
    return [pscustomobject]$current
}

function Get-RiftlineState {
    $hardware = Get-HardwareRecommendation
    $native = Get-NativeResolution
    $configPath = Get-VideoConfigPath
    $steam = Get-SteamExecutable
    $reticleColor = ''
    $profilePath = Get-ProfileConfigPath
    if (Test-Path -LiteralPath $profilePath) {
        $profileText = [System.IO.File]::ReadAllText($profilePath)
        if ($profileText -match '(?m)^\s*reticle_color\s+"(\d{1,3}\s+\d{1,3}\s+\d{1,3})"') { $reticleColor = $Matches[1] }
    }
    return [pscustomobject]@{
        ok = $true
        hardware = [pscustomobject]@{ cpu = $hardware.CPU; gpu = $hardware.GPU; profile = $hardware.Profile; label = $hardware.Label }
        native = [pscustomobject]@{ width = $native.Width; height = $native.Height; refresh = (Get-MonitorRefreshRate) }
        configPath = $configPath
        configExists = (Test-Path -LiteralPath $configPath)
        configLocked = (Get-ApexConfigLockState)
        steamPath = $(if ($steam) { $steam } else { '' })
        launchOptions = (Get-SavedLaunchOptions)
        reticleColor = $reticleColor
        customProfiles = @(Get-CustomProfiles)
        activeProfile = (Get-ActiveProfile)
        steamLanguage = (Get-SteamConfiguredLanguage)
        installedVoiceLanguages = @(Get-InstalledApexVoiceLanguages)
        current = (Get-RiftlineCurrentSettings)
        apexRunning = (Test-ApexRunning)
        version = 25
    }
}

function Get-RiftlineLiveState {
    # Lightweight refresh used after every write so the interface re-reads the
    # files that were actually saved (no hardware scan, no Steam scan).
    $reticleColor = ''
    $profilePath = Get-ProfileConfigPath
    if (Test-Path -LiteralPath $profilePath) {
        $profileText = [System.IO.File]::ReadAllText($profilePath)
        if ($profileText -match '(?m)^\s*reticle_color\s+"(\d{1,3}\s+\d{1,3}\s+\d{1,3})"') { $reticleColor = $Matches[1] }
    }
    return [pscustomobject]@{
        ok = $true
        configExists = (Test-Path -LiteralPath (Get-VideoConfigPath))
        configLocked = (Get-ApexConfigLockState)
        launchOptions = (Get-SavedLaunchOptions)
        reticleColor = $reticleColor
        customProfiles = @(Get-CustomProfiles)
        activeProfile = (Get-ActiveProfile)
        current = (Get-RiftlineCurrentSettings)
        apexRunning = (Test-ApexRunning)
    }
}

function ConvertTo-RiftlineCustomProfile {
    param([Parameter(Mandatory)]$Body)
    $settings = $Body.settings
    return [pscustomobject]@{
        Name = [string]$Body.name; Width = [int]$settings.width; Height = [int]$settings.height; WindowMode = [string]$settings.windowMode; AspectMode = [string]$settings.aspectMode
        TextureBudget = [string]$settings.textureBudget; TextureQuality = [string]$settings.textureQuality; Anisotropic = [string]$settings.anisotropic
        AntiAliasing = [string]$settings.antiAliasing; ModelDetail = [string]$settings.modelDetail; ParticleDetail = [string]$settings.particleDetail
        Shadows = [bool]$settings.shadows; Effects = [bool]$settings.effects; AmbientOcclusion = [bool]$settings.ambientOcclusion
        MapDecorations = [bool]$settings.mapDecorations; Decals = [bool]$settings.decals; Ragdolls = [bool]$settings.ragdolls; VSync = [bool]$settings.vsync
        AdaptiveTarget = [int]$settings.adaptiveTarget; RenderScaleFloor = [int]$settings.renderScaleFloor; LowLatency = [string]$settings.lowLatency
        Gibs = [bool]$settings.gibs; RagdollCollision = [bool]$settings.ragdollCollision; LinearMipFiltering = [bool]$settings.linearMipFiltering
        DynamicTextureBudget = [bool]$settings.dynamicTextureBudget; BackbufferCount = [int]$settings.backbufferCount; ShadowDepthMin = [int]$settings.shadowDepthMin
        ShadowUpresFactor = [int]$settings.shadowUpresFactor; MaxDynamicShadows = [int]$settings.maxDynamicShadows; CsmResolution = [int]$settings.csmResolution
        ShadowCoverage = [int]$settings.shadowCoverage; SsaoQuality = [int]$settings.ssaoQuality; SsaoDownsample = [bool]$settings.ssaoDownsample
        LodScale = [string]$settings.lodScale; FadeDistanceScale = [string]$settings.fadeDistanceScale; MapDetailLevel = [int]$settings.mapDetailLevel; DecalLimit = [int]$settings.decalLimit
        ParticleFallback = [string]$settings.particleFallback; ViewFov = [string]$settings.viewFov
        CustomReticle = [bool]$settings.customReticle; ReticleRed = [int]$settings.reticleRed; ReticleGreen = [int]$settings.reticleGreen; ReticleBlue = [int]$settings.reticleBlue
        LaunchOptions = (Normalize-RiftlineLaunchOptions -LaunchOptions ([string]$settings.launchOptions))
    }
}

function Invoke-RiftlineApply {
    param([Parameter(Mandatory)]$Body)
    $windowMode = [string]$Body.windowMode
    # Stretched (no black bars) only works in exclusive fullscreen, so the saved
    # video config always matches the -fullscreen launch argument it relies on.
    if ([string]$Body.aspectMode -eq 'stretched') { $windowMode = 'Fullscreen' }
    Apply-AdvancedSettings -Width ([int]$Body.width) -Height ([int]$Body.height) -WindowMode $windowMode -TextureBudget ([string]$Body.textureBudget) -TextureQuality ([string]$Body.textureQuality) -Anisotropic ([string]$Body.anisotropic) -AntiAliasing ([string]$Body.antiAliasing) -ModelDetail ([string]$Body.modelDetail) -ParticleDetail ([string]$Body.particleDetail) -Shadows ([bool]$Body.shadows) -Effects ([bool]$Body.effects) -AmbientOcclusion ([bool]$Body.ambientOcclusion) -MapDecorations ([bool]$Body.mapDecorations) -Decals ([bool]$Body.decals) -Ragdolls ([bool]$Body.ragdolls) -VSync ([bool]$Body.vsync) -AdaptiveTarget ([int]$Body.adaptiveTarget) -LowLatency ([string]$Body.lowLatency) -Gibs ([bool]$Body.gibs) -RagdollCollision ([bool]$Body.ragdollCollision) -LinearMipFiltering ([bool]$Body.linearMipFiltering) -DynamicTextureBudget ([bool]$Body.dynamicTextureBudget) -BackbufferCount ([int]$Body.backbufferCount) -ShadowDepthMin ([int]$Body.shadowDepthMin) -ShadowUpresFactor ([int]$Body.shadowUpresFactor) -MaxDynamicShadows ([int]$Body.maxDynamicShadows) -CsmResolution ([int]$Body.csmResolution) -ShadowCoverage ([int]$Body.shadowCoverage) -SsaoQuality ([int]$Body.ssaoQuality) -SsaoDownsample ([bool]$Body.ssaoDownsample) -LodScale ([string]$Body.lodScale) -FadeDistanceScale ([string]$Body.fadeDistanceScale) -MapDetailLevel ([int]$Body.mapDetailLevel) -DecalLimit ([int]$Body.decalLimit) -ParticleFallback ([string]$Body.particleFallback) -ViewFov ([string]$Body.viewFov) -CustomReticle ([bool]$Body.customReticle) -ReticleRed ([int]$Body.reticleRed) -ReticleGreen ([int]$Body.reticleGreen) -ReticleBlue ([int]$Body.reticleBlue)
    Save-LaunchOptions -LaunchOptions ([string]$Body.launchOptions)
}

function Add-RiftlineLiveState {
    param([Parameter(Mandatory)][hashtable]$Result)
    $Result['ok'] = $true
    $Result['live'] = (Get-RiftlineLiveState)
    return [pscustomobject]$Result
}

function Invoke-RiftlineAction {
    # Single action dispatcher shared by the native window bridge and the
    # browser fallback, so both paths always behave identically.
    param([Parameter(Mandatory)][string]$Action, $Body)
    if ($null -eq $Body) { $Body = [pscustomobject]@{} }
    switch ($Action) {
        'state' { return (Get-RiftlineState) }
        'live' { return (Get-RiftlineLiveState) }
        'ping' { return [pscustomobject]@{ ok = $true } }
        'profile' {
            $profile = [string]$Body.profile
            if ($profile -eq 'Auto') { $profile = (Get-HardwareRecommendation).Profile }
            if ($profile -eq 'TurboCurrent') { Apply-TurboCurrentResolution }
            elseif ($profile -in @('Competitive','Performance1080','LowEnd720','UltraLow','Potato360','Balanced')) { Apply-Profile -Profile $profile }
            else { throw "Unknown profile: $profile" }
            return (Add-RiftlineLiveState @{ message = "$profile applied with a fresh backup."; activeProfile = (Get-ActiveProfile) })
        }
        'apply' {
            Invoke-RiftlineApply -Body $Body
            return (Add-RiftlineLiveState @{ message = 'Graphics, latency, FOV, reticle, and launch settings were backed up and applied.' })
        }
        'launch' { Launch-Apex -LaunchOptions ([string]$Body.launchOptions); return [pscustomobject]@{ ok = $true } }
        'save-launch' { Save-LaunchOptions -LaunchOptions ([string]$Body.launchOptions); return [pscustomobject]@{ ok = $true; launchOptions = (Get-SavedLaunchOptions) } }
        'custom-save' {
            Save-CustomProfile -Profile (ConvertTo-RiftlineCustomProfile -Body $Body)
            return [pscustomobject]@{ ok = $true; profiles = @(Get-CustomProfiles); activeProfile = (Get-ActiveProfile) }
        }
        'custom-apply' {
            $profile = @(Get-CustomProfiles) | Where-Object { [string]$_.Name -ieq [string]$Body.name } | Select-Object -First 1
            if ($null -eq $profile) { throw 'That saved profile no longer exists.' }
            Apply-CustomProfile -Profile $profile
            return (Add-RiftlineLiveState @{ message = "$($profile.Name) was backed up and applied."; profile = $profile; activeProfile = (Get-ActiveProfile) })
        }
        'custom-delete' {
            Remove-CustomProfile -Name ([string]$Body.name)
            return [pscustomobject]@{ ok = $true; profiles = @(Get-CustomProfiles); activeProfile = (Get-ActiveProfile) }
        }
        'config-lock' { Set-ApexConfigLock -Locked ([bool]$Body.locked); return [pscustomobject]@{ ok = $true; locked = (Get-ApexConfigLockState) } }
        'restore-latest' { Restore-LatestBackup; return (Add-RiftlineLiveState @{ message = 'The newest backups were restored.' }) }
        'restore-regular' { Restore-RegularApex; return (Add-RiftlineLiveState @{ message = 'The original Apex baseline was restored.' }) }
        'clear-cache' { Clear-ApexPsoCache; return [pscustomobject]@{ ok = $true; message = 'The PSO shader cache was cleared.' } }
        'shutdown' { return [pscustomobject]@{ ok = $true } }
        default { throw "Unknown Riftline action: $Action" }
    }
}

function Invoke-RiftlineBridge {
    $body = [pscustomobject]@{}
    try {
        if ($BridgePayloadPath -and (Test-Path -LiteralPath $BridgePayloadPath)) {
            $raw = [System.IO.File]::ReadAllText($BridgePayloadPath)
            if (-not [string]::IsNullOrWhiteSpace($raw)) { $body = ConvertFrom-Json -InputObject $raw }
        }
        # Engine functions print progress with Write-Host; only the marked JSON
        # line below is read by Riftline.exe.
        $result = Invoke-RiftlineAction -Action $BridgeAction -Body $body
    } catch {
        $result = [pscustomobject]@{ ok = $false; error = $_.Exception.Message }
    }
    $json = ConvertTo-Json -InputObject $result -Depth 8 -Compress
    [Console]::Out.WriteLine("__RIFTLINE_JSON__$json")
}

function Show-WebLauncher {
    $webRoot = Join-Path $PSScriptRoot 'web'
    $assetRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot 'assets'))
    $indexPath = Join-Path $webRoot 'index.html'
    if (-not (Test-Path -LiteralPath $indexPath)) { throw "Riftline web files are missing: $webRoot" }

    # A failed Start() disposes the HttpListener, so every port gets a fresh one.
    # Without this, one busy port (e.g. an older Riftline window) blocked every retry.
    $listener = $null
    $port = 17317
    while ($port -lt 17347) {
        $candidate = New-Object System.Net.HttpListener
        try {
            $candidate.Prefixes.Add("http://127.0.0.1:$port/")
            $candidate.Start()
            $listener = $candidate
            break
        } catch {
            try { $candidate.Close() } catch { }
            $port++
        }
    }
    if ($null -eq $listener) { throw 'Riftline could not open a private localhost port.' }

    $token = [Guid]::NewGuid().ToString('N')
    $running = $true
    $lastRequest = [DateTime]::UtcNow
    $contentTypes = @{ '.webp' = 'image/webp'; '.jpg' = 'image/jpeg'; '.jpeg' = 'image/jpeg'; '.png' = 'image/png'; '.ico' = 'image/x-icon' }

    function Send-WebBytes {
        param(
            [Parameter(Mandatory)]$Response,
            [Parameter(Mandatory)][byte[]]$Bytes,
            [Parameter(Mandatory)][string]$ContentType,
            [int]$StatusCode = 200
        )
        $Response.StatusCode = $StatusCode
        $Response.ContentType = $ContentType
        $Response.ContentLength64 = $Bytes.Length
        $Response.KeepAlive = $false
        $Response.Headers['Cache-Control'] = 'no-store'
        $Response.OutputStream.Write($Bytes, 0, $Bytes.Length)
        $Response.OutputStream.Close()
        $Response.Close()
    }

    function Send-WebText {
        param($Response, [string]$Text, [string]$ContentType = 'text/plain; charset=utf-8', [int]$StatusCode = 200)
        Send-WebBytes -Response $Response -Bytes ([System.Text.Encoding]::UTF8.GetBytes($Text)) -ContentType $ContentType -StatusCode $StatusCode
    }

    function Send-WebJson {
        param($Response, $Value, [int]$StatusCode = 200)
        $json = ConvertTo-Json -InputObject $Value -Depth 8 -Compress
        Send-WebText -Response $Response -Text $json -ContentType 'application/json; charset=utf-8' -StatusCode $StatusCode
    }

    function Read-WebJson {
        param($Request)
        $reader = New-Object System.IO.StreamReader($Request.InputStream, $Request.ContentEncoding)
        try { $raw = $reader.ReadToEnd() } finally { $reader.Dispose() }
        if ([string]::IsNullOrWhiteSpace($raw)) { return [pscustomobject]@{} }
        return ConvertFrom-Json -InputObject $raw
    }

    $url = "http://127.0.0.1:$port/"
    [object[]]$edgeCandidates = @(${env:ProgramFiles(x86)}, $env:ProgramFiles) | Where-Object { $_ } |
        ForEach-Object { Join-Path $_ 'Microsoft\Edge\Application\msedge.exe' } | Where-Object { Test-Path -LiteralPath $_ }
    if ($env:RIFTLINE_NO_BROWSER -eq '1') {
        Write-Host "RIFTLINE_URL=$url"
    } elseif ($edgeCandidates.Count -gt 0) {
        Start-Process -FilePath $edgeCandidates[0] -ArgumentList "--app=$url", '--start-maximized'
    } else {
        Start-Process $url
    }

    # The window pings every 20 s, but browsers freeze background windows while a
    # fullscreen game runs. Stopping after a few idle minutes made every action fail
    # with "Failed to fetch" once Apex was closed, so the server now stays up until
    # the window says goodbye, with a long idle limit only as a leak guard.
    $goodbyeAt = $null
    $pending = $null
    try {
        while ($running -and $listener.IsListening) {
            if ($null -eq $pending) { $pending = $listener.BeginGetContext($null, $null) }
            if (-not $pending.AsyncWaitHandle.WaitOne(2000)) {
                if (($null -ne $goodbyeAt) -and ([DateTime]::UtcNow -ge $goodbyeAt)) { break }
                if (([DateTime]::UtcNow - $lastRequest).TotalHours -ge 12) { break }
                continue
            }
            $context = $listener.EndGetContext($pending)
            $pending = $null
            $request = $context.Request
            $response = $context.Response
            $lastRequest = [DateTime]::UtcNow
            $goodbyeAt = $null
            $path = $request.Url.AbsolutePath.ToLowerInvariant()

            try {
                if ($path.StartsWith('/api/')) {
                    $suppliedToken = [string]$request.Headers['X-Riftline-Token']
                    if ([string]::IsNullOrWhiteSpace($suppliedToken)) { $suppliedToken = [string]$request.QueryString['token'] }
                    if ($suppliedToken -ne $token) {
                        Send-WebJson -Response $response -Value @{ ok = $false; error = 'Invalid local session token.' } -StatusCode 403
                        continue
                    }
                    $action = $path.Substring(5)
                    if ($action -eq 'goodbye') {
                        # Sent when the window closes; a reload cancels it by making a new request.
                        $goodbyeAt = [DateTime]::UtcNow.AddSeconds(8)
                        Send-WebJson -Response $response -Value @{ ok = $true }
                        continue
                    }
                    $body =$(if ($request.HttpMethod -eq 'POST') { Read-WebJson $request } else { [pscustomobject]@{} })
                    try {
                        $result = Invoke-RiftlineAction -Action $action -Body $body
                        Send-WebJson -Response $response -Value $result
                    } catch {
                        Send-WebJson -Response $response -Value @{ ok = $false; error = $_.Exception.Message } -StatusCode 500
                    }
                    if ($action -eq 'shutdown') { $running = $false }
                    continue
                }

                switch ($path) {
                    '/' {
                        $html = [System.IO.File]::ReadAllText($indexPath).Replace('__TOKEN__', $token)
                        Send-WebText -Response $response -Text $html -ContentType 'text/html; charset=utf-8'
                    }
                    '/styles.css' { Send-WebBytes -Response $response -Bytes ([System.IO.File]::ReadAllBytes((Join-Path $webRoot 'styles.css'))) -ContentType 'text/css; charset=utf-8' }
                    '/extras.css' { Send-WebBytes -Response $response -Bytes ([System.IO.File]::ReadAllBytes((Join-Path $webRoot 'extras.css'))) -ContentType 'text/css; charset=utf-8' }
                    '/app.js' { Send-WebBytes -Response $response -Bytes ([System.IO.File]::ReadAllBytes((Join-Path $webRoot 'app.js'))) -ContentType 'application/javascript; charset=utf-8' }
                    '/arena.png' { Send-WebBytes -Response $response -Bytes ([System.IO.File]::ReadAllBytes((Join-Path $PSScriptRoot 'assets\riftline-arena.png'))) -ContentType 'image/png' }
                    '/app-icon.png' { Send-WebBytes -Response $response -Bytes ([System.IO.File]::ReadAllBytes((Join-Path $PSScriptRoot 'assets\app-icon.png'))) -ContentType 'image/png' }
                    '/favicon.ico' { Send-WebText -Response $response -Text '' -StatusCode 204 }
                    default {
                        # Preview images and backgrounds referenced as ../assets/... from the UI.
                        $served = $false
                        if ($path.StartsWith('/assets/')) {
                            $relative = [System.Uri]::UnescapeDataString($request.Url.AbsolutePath.Substring(8)) -replace '/', [System.IO.Path]::DirectorySeparatorChar
                            $full = [System.IO.Path]::GetFullPath((Join-Path $assetRoot $relative))
                            $extension = [System.IO.Path]::GetExtension($full).ToLowerInvariant()
                            if ($full.StartsWith($assetRoot + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase) -and $contentTypes.ContainsKey($extension) -and (Test-Path -LiteralPath $full -PathType Leaf)) {
                                Send-WebBytes -Response $response -Bytes ([System.IO.File]::ReadAllBytes($full)) -ContentType $contentTypes[$extension]
                                $served = $true
                            }
                        }
                        if (-not $served) { Send-WebJson -Response $response -Value @{ ok = $false; error = 'Not found.' } -StatusCode 404 }
                    }
                }
            } catch {
                if ($response.OutputStream.CanWrite) {
                    Send-WebJson -Response $response -Value @{ ok = $false; error = $_.Exception.Message } -StatusCode 500
                }
            }
        }
    } finally {
        if ($listener.IsListening) { $listener.Stop() }
        $listener.Close()
    }
}

function Show-Launcher {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    [System.Windows.Forms.Application]::EnableVisualStyles()

    $bg = [System.Drawing.ColorTranslator]::FromHtml('#080B11')
    $panel = [System.Drawing.ColorTranslator]::FromHtml('#11161F')
    $button = [System.Drawing.ColorTranslator]::FromHtml('#1A2230')
    $border = [System.Drawing.ColorTranslator]::FromHtml('#303A49')
    $text = [System.Drawing.ColorTranslator]::FromHtml('#F5F1EB')
    $muted = [System.Drawing.ColorTranslator]::FromHtml('#94A0AF')
    $red = [System.Drawing.ColorTranslator]::FromHtml('#E5493F')
    $green = [System.Drawing.ColorTranslator]::FromHtml('#278C69')
    $blue = [System.Drawing.ColorTranslator]::FromHtml('#275EA8')
    $orange = [System.Drawing.ColorTranslator]::FromHtml('#B35B2B')
    $purple = [System.Drawing.ColorTranslator]::FromHtml('#7650A8')
    $accent = [System.Drawing.ColorTranslator]::FromHtml('#FF5A3C')
    $surface = [System.Drawing.ColorTranslator]::FromHtml('#0D121A')

    $form = New-Object System.Windows.Forms.Form
    $form.Text = 'Apex Legends Performance Helper'
    $form.ClientSize = New-Object System.Drawing.Size(780, 720)
    $form.StartPosition = 'CenterScreen'
    $form.FormBorderStyle = 'FixedSingle'
    $form.MaximizeBox = $false
    $form.BackColor = $bg
    $form.ForeColor = $text
    $form.Font = New-Object System.Drawing.Font('Segoe UI', 10)

    function New-Button {
        param([string]$Label, [int]$X, [int]$Y, [int]$Width, [int]$Height, [System.Drawing.Color]$Color = $button)
        $control = New-Object System.Windows.Forms.Button
        $control.Text = $Label
        $control.Location = New-Object System.Drawing.Point($X, $Y)
        $control.Size = New-Object System.Drawing.Size($Width, $Height)
        $control.FlatStyle = 'Flat'
        $control.FlatAppearance.BorderColor = $border
        $control.BackColor = $Color
        $control.ForeColor = $text
        $control.Cursor = [System.Windows.Forms.Cursors]::Hand
        return $control
    }

    $header = New-Object System.Windows.Forms.Panel
    $header.Location = New-Object System.Drawing.Point(0, 0)
    $header.Size = New-Object System.Drawing.Size(780, 92)
    $header.BackColor = $panel
    $form.Controls.Add($header)

    $title = New-Object System.Windows.Forms.Label
    $title.Text = 'APEX LEGENDS PERFORMANCE HELPER'
    $title.Location = New-Object System.Drawing.Point(24, 14)
    $title.Size = New-Object System.Drawing.Size(730, 36)
    $title.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 19)
    $title.ForeColor = [System.Drawing.ColorTranslator]::FromHtml('#FF6262')
    $header.Controls.Add($title)

    $subtitle = New-Object System.Windows.Forms.Label
    $subtitle.Text = 'Safe, reversible video presets. No injection, game-file edits, or anti-cheat bypass.'
    $subtitle.Location = New-Object System.Drawing.Point(27, 54)
    $subtitle.Size = New-Object System.Drawing.Size(730, 24)
    $subtitle.ForeColor = $muted
    $header.Controls.Add($subtitle)

    $hardware = Get-HardwareRecommendation
    $native = Get-NativeResolution
    $detected = New-Object System.Windows.Forms.Label
    $detected.Text = "Detected: $($hardware.GPU) | $($native.Width)x$($native.Height)`r`nAUTO will use: $($hardware.Label)"
    $detected.Location = New-Object System.Drawing.Point(24, 104)
    $detected.Size = New-Object System.Drawing.Size(732, 44)
    $detected.ForeColor = $muted
    $form.Controls.Add($detected)

    $pick = New-Object System.Windows.Forms.Label
    $pick.Text = '1   CHOOSE A PRESET'
    $pick.Location = New-Object System.Drawing.Point(24, 154)
    $pick.Size = New-Object System.Drawing.Size(732, 26)
    $pick.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 12)
    $pick.ForeColor = [System.Drawing.ColorTranslator]::FromHtml('#FF7A7A')
    $form.Controls.Add($pick)

    $auto = New-Button -Label "AUTO - RECOMMENDED`r`nBest starting point for this PC" -X 24 -Y 184 -Width 732 -Height 60 -Color $red
    $competitive = New-Button -Label "COMPETITIVE`r`nNative resolution / low effects" -X 24 -Y 254 -Width 232 -Height 58 -Color $blue
    $perf1080 = New-Button -Label "1080P PERFORMANCE`r`nLow effects / clearer image" -X 274 -Y 254 -Width 232 -Height 58 -Color $green
    $low720 = New-Button -Label "LOW-END 720P`r`nFor old or integrated GPUs" -X 524 -Y 254 -Width 232 -Height 58 -Color $orange
    $ultra = New-Button -Label "ULTRA LOW`r`n960x540 / very blurry" -X 24 -Y 322 -Width 357 -Height 54 -Color $orange
    $balanced = New-Button -Label "BALANCED`r`nNative resolution / cleaner image" -X 399 -Y 322 -Width 357 -Height 54 -Color $purple
    $form.Controls.AddRange(@($auto, $competitive, $perf1080, $low720, $ultra, $balanced))

    $customLabel = New-Object System.Windows.Forms.Label
    $customLabel.Text = '2   OPTIONAL CUSTOM DISPLAY'
    $customLabel.Location = New-Object System.Drawing.Point(24, 392)
    $customLabel.Size = New-Object System.Drawing.Size(732, 26)
    $customLabel.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 12)
    $customLabel.ForeColor = [System.Drawing.ColorTranslator]::FromHtml('#FF7A7A')
    $form.Controls.Add($customLabel)

    $customPanel = New-Object System.Windows.Forms.Panel
    $customPanel.Location = New-Object System.Drawing.Point(24, 424)
    $customPanel.Size = New-Object System.Drawing.Size(732, 126)
    $customPanel.BackColor = $panel
    $form.Controls.Add($customPanel)

    $labels = @('Resolution', 'Window mode', 'Graphics')
    for ($i = 0; $i -lt 3; $i++) {
        $label = New-Object System.Windows.Forms.Label
        $label.Text = $labels[$i]
        $label.Location = New-Object System.Drawing.Point((15 + ($i * 235)), 10)
        $label.Size = New-Object System.Drawing.Size(210, 22)
        $customPanel.Controls.Add($label)
    }
    $resolution = New-Object System.Windows.Forms.ComboBox
    $resolution.Location = New-Object System.Drawing.Point(15, 35); $resolution.Size = New-Object System.Drawing.Size(210, 28)
    $resolution.DropDownStyle = 'DropDownList'; [void]$resolution.Items.AddRange(@('Native','1920x1080','1600x900','1280x720','960x540')); $resolution.SelectedIndex = 0
    $window = New-Object System.Windows.Forms.ComboBox
    $window.Location = New-Object System.Drawing.Point(250, 35); $window.Size = New-Object System.Drawing.Size(210, 28)
    $window.DropDownStyle = 'DropDownList'; [void]$window.Items.AddRange(@('Fullscreen','Borderless','Windowed')); $window.SelectedIndex = 0
    $quality = New-Object System.Windows.Forms.ComboBox
    $quality.Location = New-Object System.Drawing.Point(485, 35); $quality.Size = New-Object System.Drawing.Size(230, 28)
    $quality.DropDownStyle = 'DropDownList'; [void]$quality.Items.AddRange(@('Competitive','Balanced','Low')); $quality.SelectedIndex = 0
    $applyCustom = New-Button -Label 'APPLY CUSTOM DISPLAY' -X 15 -Y 72 -Width 700 -Height 42 -Color $purple
    $customPanel.Controls.AddRange(@($resolution, $window, $quality, $applyCustom))

    $playLabel = New-Object System.Windows.Forms.Label
    $playLabel.Text = '3   PLAY'
    $playLabel.Location = New-Object System.Drawing.Point(24, 566)
    $playLabel.Size = New-Object System.Drawing.Size(732, 26)
    $playLabel.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 12)
    $playLabel.ForeColor = [System.Drawing.ColorTranslator]::FromHtml('#FF7A7A')
    $form.Controls.Add($playLabel)

    $play = New-Button -Label 'PLAY APEX LEGENDS' -X 24 -Y 596 -Width 732 -Height 52 -Color $green
    $restore = New-Button -Label 'RESTORE NEWEST BACKUP' -X 24 -Y 660 -Width 230 -Height 34
    $cache = New-Button -Label 'CLEAR SHADER CACHE' -X 264 -Y 660 -Width 200 -Height 34
    $inspect = New-Button -Label 'SHOW LOCATIONS' -X 474 -Y 660 -Width 150 -Height 34
    $form.Controls.AddRange(@($play, $restore, $cache, $inspect))

    $status = New-Object System.Windows.Forms.Label
    $status.Text = 'Ready. Close Apex before applying.'
    $status.Location = New-Object System.Drawing.Point(632, 657)
    $status.Size = New-Object System.Drawing.Size(124, 48)
    $status.TextAlign = 'TopRight'
    $status.ForeColor = $muted
    $form.Controls.Add($status)

    function Set-Status { param([string]$Message, [bool]$Error = $false); $status.ForeColor = $(if ($Error) { [System.Drawing.Color]::Tomato } else { [System.Drawing.Color]::LightGreen }); $status.Text = $Message }
    function Run-UiAction { param([scriptblock]$Action, [string]$Success); try { & $Action; Set-Status $Success } catch { Set-Status $_.Exception.Message $true } }

    $auto.Add_Click({ Run-UiAction { Apply-Profile -Profile $hardware.Profile } "Applied $($hardware.Label)." })
    $competitive.Add_Click({ Run-UiAction { Apply-Profile -Profile 'Competitive' } 'Competitive applied.' })
    $perf1080.Add_Click({ Run-UiAction { Apply-Profile -Profile 'Performance1080' } '1080p applied.' })
    $low720.Add_Click({ Run-UiAction { Apply-Profile -Profile 'LowEnd720' } '720p applied.' })
    $ultra.Add_Click({ Run-UiAction { Apply-Profile -Profile 'UltraLow' } 'Ultra Low applied.' })
    $balanced.Add_Click({ Run-UiAction { Apply-Profile -Profile 'Balanced' } 'Balanced applied.' })
    $applyCustom.Add_Click({ Run-UiAction { Apply-CustomDisplay -Resolution ([string]$resolution.SelectedItem) -WindowMode ([string]$window.SelectedItem) -Quality ([string]$quality.SelectedItem) } 'Custom settings applied.' })
    $play.Add_Click({ Run-UiAction { Launch-Apex } 'Starting through Steam...' })
    $restore.Add_Click({ Run-UiAction { Restore-LatestBackup } 'Backup restored.' })
    $cache.Add_Click({ Run-UiAction { Clear-ApexPsoCache } 'Cache cleared; rebuild expected.' })
    $inspect.Add_Click({ [System.Windows.Forms.MessageBox]::Show("Config:`r`n$(Get-VideoConfigPath)`r`n`r`nSteam manifest:`r`n$(Get-SteamManifestPath)", 'Apex locations', 'OK', 'Information') | Out-Null })
    [void]$form.ShowDialog()
}

function Show-LauncherV2 {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    Add-Type -AssemblyName Microsoft.VisualBasic
    [System.Windows.Forms.Application]::EnableVisualStyles()
    Ensure-RegularApexBaseline

    $bg = [System.Drawing.ColorTranslator]::FromHtml('#080B11')
    $panel = [System.Drawing.ColorTranslator]::FromHtml('#11161F')
    $button = [System.Drawing.ColorTranslator]::FromHtml('#1A2230')
    $border = [System.Drawing.ColorTranslator]::FromHtml('#303A49')
    $text = [System.Drawing.ColorTranslator]::FromHtml('#F5F1EB')
    $muted = [System.Drawing.ColorTranslator]::FromHtml('#94A0AF')
    $red = [System.Drawing.ColorTranslator]::FromHtml('#E5493F')
    $green = [System.Drawing.ColorTranslator]::FromHtml('#278C69')
    $blue = [System.Drawing.ColorTranslator]::FromHtml('#275EA8')
    $orange = [System.Drawing.ColorTranslator]::FromHtml('#B35B2B')
    $purple = [System.Drawing.ColorTranslator]::FromHtml('#7650A8')
    $accent = [System.Drawing.ColorTranslator]::FromHtml('#FF5A3C')
    $surface = [System.Drawing.ColorTranslator]::FromHtml('#0D121A')

    $form = New-Object System.Windows.Forms.Form
    $form.Text = 'Riftline - Apex Performance Suite 18.0'
    $form.ClientSize = New-Object System.Drawing.Size(1180, 760)
    $form.StartPosition = 'CenterScreen'
    $form.FormBorderStyle = 'FixedSingle'
    $form.MaximizeBox = $false
    $form.BackColor = $bg
    $form.ForeColor = $text
    $form.Font = New-Object System.Drawing.Font('Segoe UI', 9.5)
    $form.KeyPreview = $true
    $backgroundArt = $null
    $backgroundPath = Join-Path $PSScriptRoot 'assets\riftline-arena.png'
    if (Test-Path -LiteralPath $backgroundPath) {
        $sourceArt = [System.Drawing.Image]::FromFile($backgroundPath)
        try { $backgroundArt = New-Object System.Drawing.Bitmap($sourceArt) } finally { $sourceArt.Dispose() }
        $form.BackgroundImage = $backgroundArt; $form.BackgroundImageLayout = 'Stretch'
    }

    function New-V2Button {
        param([string]$Label, [int]$X, [int]$Y, [int]$Width, [int]$Height, [System.Drawing.Color]$Color = $button)
        $control = New-Object System.Windows.Forms.Button
        $control.Text = $Label; $control.Location = New-Object System.Drawing.Point($X, $Y)
        $control.Size = New-Object System.Drawing.Size($Width, $Height); $control.FlatStyle = 'Flat'
        $control.FlatAppearance.BorderColor = $border; $control.FlatAppearance.BorderSize = 1; $control.BackColor = $Color; $control.ForeColor = $text
        $control.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 9.25)
        $control.Cursor = [System.Windows.Forms.Cursors]::Hand
        $baseColor = $Color
        $control.Add_MouseEnter({ $this.FlatAppearance.BorderColor = $accent; $this.ForeColor = [System.Drawing.Color]::White })
        $control.Add_MouseLeave({ $this.FlatAppearance.BorderColor = $border; $this.ForeColor = $text })
        return $control
    }

    function New-V2Combo {
        param([object[]]$Items, [int]$X, [int]$Y, [int]$Width, [int]$SelectedIndex = 0)
        $control = New-Object System.Windows.Forms.ComboBox
        $control.Location = New-Object System.Drawing.Point($X, $Y); $control.Size = New-Object System.Drawing.Size($Width, 28)
        $control.DropDownStyle = 'DropDownList'; $control.FlatStyle = 'Flat'; $control.BackColor = $button; $control.ForeColor = $text
        [void]$control.Items.AddRange($Items); $control.SelectedIndex = $SelectedIndex
        return $control
    }

    function New-V2Label {
        param([string]$Label, [int]$X, [int]$Y, [int]$Width, [int]$Height = 22)
        $control = New-Object System.Windows.Forms.Label
        $control.Text = $Label; $control.Location = New-Object System.Drawing.Point($X, $Y)
        $control.Size = New-Object System.Drawing.Size($Width, $Height); $control.ForeColor = $text
        return $control
    }

    $header = New-Object System.Windows.Forms.Panel
    $header.Location = New-Object System.Drawing.Point(0, 0); $header.Size = New-Object System.Drawing.Size(1180, 82); $header.BackColor = $surface
    $form.Controls.Add($header)
    $title = New-V2Label -Label 'RIFTLINE' -X 24 -Y 10 -Width 310 -Height 37
    $title.Font = New-Object System.Drawing.Font('Arial Narrow', 23, [System.Drawing.FontStyle]::Bold); $title.ForeColor = $text
    $header.Controls.Add($title)
    $hardware = Get-HardwareRecommendation; $native = Get-NativeResolution
    $brandAccent = New-Object System.Windows.Forms.Panel
    $brandAccent.Location = New-Object System.Drawing.Point(24, 51); $brandAccent.Size = New-Object System.Drawing.Size(52, 3); $brandAccent.BackColor = $accent
    $header.Controls.Add($brandAccent)
    $subtitle = New-V2Label -Label "APEX PERFORMANCE SUITE  /  18.0" -X 88 -Y 43 -Width 290
    $subtitle.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 8.5); $subtitle.ForeColor = $muted; $header.Controls.Add($subtitle)
    $hardwarePill = New-V2Label -Label "$($hardware.GPU)  |  $($native.Width)x$($native.Height)" -X 392 -Y 28 -Width 390 -Height 26
    $hardwarePill.TextAlign = 'MiddleCenter'; $hardwarePill.BackColor = $panel; $hardwarePill.ForeColor = $muted; $header.Controls.Add($hardwarePill)

    $contentHost = New-Object System.Windows.Forms.Panel
    $contentHost.Location = New-Object System.Drawing.Point(216, 96); $contentHost.Size = New-Object System.Drawing.Size(950, 620); $contentHost.BackColor = $bg
    $form.Controls.Add($contentHost)
    $tabs = New-Object System.Windows.Forms.TabControl
    $tabs.Location = New-Object System.Drawing.Point(-4, -30); $tabs.Size = New-Object System.Drawing.Size(958, 654)
    $tabs.Alignment = 'Top'; $tabs.Appearance = 'FlatButtons'; $tabs.SizeMode = 'Fixed'; $tabs.ItemSize = New-Object System.Drawing.Size(1, 1)
    $tabs.Multiline = $true; $tabs.BackColor = $bg
    $contentHost.Controls.Add($tabs)
    $quickTab = New-Object System.Windows.Forms.TabPage; $quickTab.Text = '01   HOME'; $quickTab.BackColor = $bg; $quickTab.ForeColor = $text
    $advancedTab = New-Object System.Windows.Forms.TabPage; $advancedTab.Text = '02   DISPLAY'; $advancedTab.BackColor = $bg; $advancedTab.ForeColor = $text
    $expertTab = New-Object System.Windows.Forms.TabPage; $expertTab.Text = '03   GRAPHICS'; $expertTab.BackColor = $bg; $expertTab.ForeColor = $text
    $steamTab = New-Object System.Windows.Forms.TabPage; $steamTab.Text = '04   LAUNCH'; $steamTab.BackColor = $bg; $steamTab.ForeColor = $text
    $toolsTab = New-Object System.Windows.Forms.TabPage; $toolsTab.Text = '05   SAFETY'; $toolsTab.BackColor = $bg; $toolsTab.ForeColor = $text
    $tabs.Controls.AddRange(@($quickTab, $advancedTab, $expertTab, $steamTab, $toolsTab))
    if ($backgroundArt) {
        foreach ($page in @($quickTab, $advancedTab, $expertTab, $steamTab, $toolsTab)) {
            $page.BackgroundImage = $backgroundArt; $page.BackgroundImageLayout = 'Stretch'
        }
        $form.Add_FormClosed({ $backgroundArt.Dispose() })
    }

    $sidebar = New-Object System.Windows.Forms.Panel
    $sidebar.Location = New-Object System.Drawing.Point(14, 96); $sidebar.Size = New-Object System.Drawing.Size(192, 620); $sidebar.BackColor = $surface
    $form.Controls.Add($sidebar); $sidebar.BringToFront()
    $navTitle = New-V2Label -Label 'CONTROL DECK' -X 16 -Y 17 -Width 160 -Height 24
    $navTitle.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 8.5); $navTitle.ForeColor = $muted; $sidebar.Controls.Add($navTitle)
    $navButtons = @(
        (New-V2Button -Label '01   HOME' -X 10 -Y 52 -Width 172 -Height 48),
        (New-V2Button -Label '02   DISPLAY' -X 10 -Y 108 -Width 172 -Height 48),
        (New-V2Button -Label '03   GRAPHICS' -X 10 -Y 164 -Width 172 -Height 48),
        (New-V2Button -Label '04   LAUNCH' -X 10 -Y 220 -Width 172 -Height 48),
        (New-V2Button -Label '05   SAFETY' -X 10 -Y 276 -Width 172 -Height 48)
    )
    foreach ($navButton in $navButtons) { $navButton.TextAlign = 'MiddleLeft'; $navButton.Padding = New-Object System.Windows.Forms.Padding(14, 0, 0, 0); $sidebar.Controls.Add($navButton) }
    $connection = New-V2Label -Label $(if (Test-Path -LiteralPath (Get-VideoConfigPath)) { 'CONFIG CONNECTED' } else { 'CONFIG NOT FOUND' }) -X 18 -Y 555 -Width 158 -Height 22
    $connection.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 8); $connection.ForeColor = $(if (Test-Path -LiteralPath (Get-VideoConfigPath)) { [System.Drawing.Color]::LightGreen } else { [System.Drawing.Color]::Khaki }); $sidebar.Controls.Add($connection)
    $navVersion = New-V2Label -Label 'RIFTLINE  /  BUILD 18' -X 18 -Y 580 -Width 158 -Height 22
    $navVersion.ForeColor = $muted; $sidebar.Controls.Add($navVersion)
    $navButtons[0].Add_Click({ $tabs.SelectedTab = $quickTab })
    $navButtons[1].Add_Click({ $tabs.SelectedTab = $advancedTab })
    $navButtons[2].Add_Click({ $tabs.SelectedTab = $expertTab })
    $navButtons[3].Add_Click({ $tabs.SelectedTab = $steamTab })
    $navButtons[4].Add_Click({ $tabs.SelectedTab = $toolsTab })
    $updateNavigation = {
        for ($navIndex = 0; $navIndex -lt $navButtons.Count; $navIndex++) {
            $active = ($navIndex -eq $tabs.SelectedIndex)
            $navButtons[$navIndex].BackColor = $(if ($active) { $button } else { $surface })
            $navButtons[$navIndex].ForeColor = $(if ($active) { $text } else { $muted })
            $navButtons[$navIndex].FlatAppearance.BorderColor = $(if ($active) { $accent } else { $surface })
        }
    }
    $tabs.Add_SelectedIndexChanged({ & $updateNavigation }); & $updateNavigation

    $statusBar = New-Object System.Windows.Forms.Panel
    $statusBar.Location = New-Object System.Drawing.Point(0, 724); $statusBar.Size = New-Object System.Drawing.Size(1180, 36); $statusBar.BackColor = $surface; $form.Controls.Add($statusBar)
    $status = New-V2Label -Label 'READY  /  Close Apex before applying graphics settings.' -X 24 -Y 0 -Width 1120 -Height 36
    $status.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 8.75); $status.ForeColor = $muted; $status.TextAlign = 'MiddleLeft'; $statusBar.Controls.Add($status)
    function Set-V2Status { param([string]$Message, [bool]$IsError = $false); $status.ForeColor = $(if ($IsError) { [System.Drawing.Color]::Tomato } else { [System.Drawing.Color]::LightGreen }); $status.Text = $Message }
    function Run-V2Action {
        param([scriptblock]$Action, [string]$Success)
        try { & $Action; Set-V2Status $Success }
        catch {
            $friendlyError = $_.Exception.Message
            Set-V2Status $friendlyError $true
            [System.Windows.Forms.MessageBox]::Show("The action could not finish:`r`n`r`n$friendlyError`r`n`r`nClose Apex and try again. If Apex has never been opened on this Windows account, open it once first so it creates its settings files.", 'Apex Performance Helper - action needed', 'OK', 'Warning') | Out-Null
        }
    }

    $quickInfo = New-V2Label -Label "QUICK START:  Close Apex  >  Click APPLY AUTO  >  Click PLAY APEX.  That's all you need.`r`nThe other tabs are optional. Every Apply creates a backup." -X 18 -Y 10 -Width 760 -Height 38
    $quickInfo.ForeColor = $muted; $quickTab.Controls.Add($quickInfo)
    $auto = New-V2Button -Label "1) APPLY AUTO - RECOMMENDED`r`n$($hardware.Label)" -X 18 -Y 50 -Width 760 -Height 64 -Color $red
    $competitive = New-V2Button -Label "COMPETITIVE NATIVE`r`nClear aim + low effects | uncapped" -X 18 -Y 130 -Width 240 -Height 67 -Color $blue
    $perf1080 = New-V2Button -Label "SMOOTH 1080P`r`nClear + fast | 144 FPS cap" -X 278 -Y 130 -Width 240 -Height 67 -Color $green
    $low720 = New-V2Button -Label "RAW MAX FPS 720P`r`nMinimum effects | uncapped" -X 538 -Y 130 -Width 240 -Height 67 -Color $orange
    $ultra = New-V2Button -Label "EMERGENCY 540P`r`nVery weak PCs | 45 FPS cap" -X 18 -Y 213 -Width 240 -Height 60 -Color $orange
    $potato = New-V2Button -Label "POTATO 360P`r`nLowest quality | 30 FPS cap" -X 278 -Y 213 -Width 240 -Height 60 -Color $red
    $balanced = New-V2Button -Label "QUALITY + FPS`r`nNative | 120 FPS cap" -X 538 -Y 213 -Width 240 -Height 60 -Color $purple
    $turbo = New-V2Button -Label 'TURBO - KEEP CURRENT RESOLUTION | Lowest graphics, uncapped FPS, no resolution change' -X 18 -Y 283 -Width 760 -Height 42 -Color $red
    $quickTab.Controls.AddRange(@($auto, $competitive, $perf1080, $low720, $ultra, $potato, $balanced, $turbo))
    $customLabel = New-V2Label -Label 'YOUR SAVED CUSTOM PROFILES' -X 18 -Y 335 -Width 300
    $customLabel.ForeColor = [System.Drawing.ColorTranslator]::FromHtml('#FF7A7A'); $quickTab.Controls.Add($customLabel)
    $customProfiles = New-V2Combo -Items @('(no saved profiles)') -X 18 -Y 362 -Width 370
    $applyCustomProfile = New-V2Button -Label 'APPLY PROFILE' -X 405 -Y 360 -Width 178 -Height 32 -Color $purple
    $deleteCustomProfile = New-V2Button -Label 'DELETE PROFILE' -X 600 -Y 360 -Width 178 -Height 32
    $quickTab.Controls.AddRange(@($customProfiles, $applyCustomProfile, $deleteCustomProfile))
    $savedText = Get-SavedLaunchOptions
    $savedLabel = New-V2Label -Label "App-managed launch settings: $(if ($savedText) { $savedText } else { '(none yet)' })" -X 18 -Y 403 -Width 760 -Height 30
    $savedLabel.ForeColor = $muted; $quickTab.Controls.Add($savedLabel)
    $playSaved = New-V2Button -Label '2) PLAY APEX WITH THE APPLIED PROFILE' -X 18 -Y 440 -Width 760 -Height 42 -Color $green
    $restoreRegular = New-V2Button -Label 'RESTORE REGULAR APEX — UNDO ALL APPLIED HELPER SETTINGS' -X 18 -Y 490 -Width 760 -Height 25 -Color $orange
    $quickTab.Controls.AddRange(@($playSaved, $restoreRegular))

    function Update-CustomProfileList {
        $selectedName = [string]$customProfiles.SelectedItem
        $customProfiles.Items.Clear()
        $profiles = @(Get-CustomProfiles)
        if ($profiles.Count -eq 0) { [void]$customProfiles.Items.Add('(no saved profiles)') }
        else { foreach ($profile in $profiles) { [void]$customProfiles.Items.Add([string]$profile.Name) } }
        $newIndex = $customProfiles.Items.IndexOf($selectedName)
        $customProfiles.SelectedIndex = $(if ($newIndex -ge 0) { $newIndex } else { 0 })
    }
    Update-CustomProfileList

    $displayGroup = New-Object System.Windows.Forms.GroupBox
    $displayGroup.Text = '1 + 2. Choose resolution and screen shape'; $displayGroup.Location = New-Object System.Drawing.Point(14, 12); $displayGroup.Size = New-Object System.Drawing.Size(375, 450); $displayGroup.ForeColor = $text
    $advancedTab.Controls.Add($displayGroup)
    $displayGroup.Controls.Add((New-V2Label -Label 'Width' -X 16 -Y 27 -Width 150))
    $displayGroup.Controls.Add((New-V2Label -Label 'Height' -X 194 -Y 27 -Width 150))
    $widthBox = New-Object System.Windows.Forms.TextBox; $widthBox.Location = New-Object System.Drawing.Point(16, 49); $widthBox.Size = New-Object System.Drawing.Size(150, 27); $widthBox.Text = [string]$native.Width
    $heightBox = New-Object System.Windows.Forms.TextBox; $heightBox.Location = New-Object System.Drawing.Point(194, 49); $heightBox.Size = New-Object System.Drawing.Size(150, 27); $heightBox.Text = [string]$native.Height
    $displayGroup.Controls.AddRange(@($widthBox, $heightBox))
    $moreResolutions = New-V2Button -Label 'CHOOSE RESOLUTION + ASPECT RATIO...' -X 16 -Y 84 -Width 331 -Height 38 -Color $blue
    $nativeButton = New-V2Button -Label "NATIVE`r`n$($native.Width)x$($native.Height)" -X 16 -Y 130 -Width 105 -Height 36 -Color $blue
    $res1080 = New-V2Button -Label '1920x1080' -X 129 -Y 130 -Width 105 -Height 36
    $res720 = New-V2Button -Label '1280x720' -X 242 -Y 130 -Width 105 -Height 36
    $res900 = New-V2Button -Label '1600x900' -X 16 -Y 130 -Width 105 -Height 36; $res900.Visible = $false
    $res768 = New-V2Button -Label '640x360' -X 129 -Y 130 -Width 105 -Height 36; $res768.Visible = $false
    $res540 = New-V2Button -Label '960x540' -X 242 -Y 130 -Width 105 -Height 36; $res540.Visible = $false
    $displayGroup.Controls.AddRange(@($moreResolutions, $nativeButton, $res1080, $res720, $res900, $res768, $res540))
    $displayGroup.Controls.Add((New-V2Label -Label 'Screen shape' -X 16 -Y 176 -Width 180))
    $aspectMode = New-V2Combo -Items @('Game-side stretched — no black bars','Game default — keep black bars','Do not change') -X 16 -Y 198 -Width 331 -SelectedIndex $(if (($savedText -match '(?i)mat_letterbox_aspect_(?:goal|threshold|min)') -or [string]::IsNullOrWhiteSpace($savedText)) { 0 } else { 2 })
    $displayGroup.Controls.Add($aspectMode)
    $scalingGuide = New-V2Button -Label 'HOW GAME-SIDE STRETCHING WORKS' -X 16 -Y 232 -Width 331 -Height 30 -Color $orange
    $displayGroup.Controls.Add($scalingGuide)
    $displayGroup.Controls.Add((New-V2Label -Label 'Window mode — Fullscreen is best for stretched' -X 16 -Y 272 -Width 330))
    $windowMode = New-V2Combo -Items @('Fullscreen','Borderless','Windowed') -X 16 -Y 294 -Width 331
    $displayGroup.Controls.Add($windowMode)
    $displayGroup.Controls.Add((New-V2Label -Label 'Automatic 3D scaling FPS target (optional)' -X 16 -Y 332 -Width 300))
    $adaptive = New-V2Combo -Items @('Off','60','75','90','120','144','165','240') -X 16 -Y 354 -Width 331
    $displayGroup.Controls.Add($adaptive)
    $displayGroup.Controls.Add((New-V2Label -Label 'Lowest 3D quality when scaling is active' -X 16 -Y 392 -Width 300))
    $renderScale = New-V2Combo -Items @('50%','55%','60%','65%','70%','75%','80%','85%','90%','95%','100%') -X 16 -Y 414 -Width 331 -SelectedIndex 0
    $displayGroup.Controls.Add($renderScale)

    $graphicsGroup = New-Object System.Windows.Forms.GroupBox
    $graphicsGroup.Text = '3. Choose picture quality — lower settings give more FPS'; $graphicsGroup.Location = New-Object System.Drawing.Point(402, 12); $graphicsGroup.Size = New-Object System.Drawing.Size(390, 450); $graphicsGroup.ForeColor = $text
    $advancedTab.Controls.Add($graphicsGroup)
    $graphicsLabels = @('Texture memory','Texture detail','Texture sharpness','Smooth edges','Model / draw detail','Particle detail')
    $graphicsCombos = @()
    $graphicsItems = @(
        @('None','1 GB','2 GB','3 GB','4 GB','6 GB','8 GB'),
        @('High','Low','Very Low'),
        @('1x','2x','4x','8x','16x'),
        @('Off','TSAA'),
        @('Minimum','Very Low','Low','Medium','High'),
        @('Low','Medium','High')
    )
    $selected = @(3,1,0,0,2,0)
    for ($i = 0; $i -lt 6; $i++) {
        $y = 28 + ($i * 43)
        $graphicsGroup.Controls.Add((New-V2Label -Label $graphicsLabels[$i] -X 14 -Y $y -Width 190))
        $combo = New-V2Combo -Items $graphicsItems[$i] -X 214 -Y ($y - 4) -Width 155 -SelectedIndex $selected[$i]
        $graphicsGroup.Controls.Add($combo); $graphicsCombos += $combo
    }
    $graphicsGroup.Controls.Add((New-V2Label -Label 'Input-lag reduction' -X 14 -Y 288 -Width 190))
    $lowLatency = New-V2Combo -Items @('Keep current','Off','On','On + Boost') -X 214 -Y 284 -Width 155 -SelectedIndex 0
    $graphicsGroup.Controls.Add($lowLatency)
    $shadowCheck = New-Object System.Windows.Forms.CheckBox; $shadowCheck.Text = 'Sun shadows'; $shadowCheck.Location = New-Object System.Drawing.Point(14, 329); $shadowCheck.Size = New-Object System.Drawing.Size(170, 25)
    $effectsCheck = New-Object System.Windows.Forms.CheckBox; $effectsCheck.Text = 'Fog and light effects'; $effectsCheck.Location = New-Object System.Drawing.Point(200, 329); $effectsCheck.Size = New-Object System.Drawing.Size(175, 25)
    $aoCheck = New-Object System.Windows.Forms.CheckBox; $aoCheck.Text = 'Extra lighting/shading'; $aoCheck.Location = New-Object System.Drawing.Point(14, 358); $aoCheck.Size = New-Object System.Drawing.Size(180, 25)
    $mapDecorCheck = New-Object System.Windows.Forms.CheckBox; $mapDecorCheck.Text = 'Extra map decoration'; $mapDecorCheck.Location = New-Object System.Drawing.Point(200, 358); $mapDecorCheck.Size = New-Object System.Drawing.Size(175, 25)
    $decalsCheck = New-Object System.Windows.Forms.CheckBox; $decalsCheck.Text = 'Impact marks'; $decalsCheck.Location = New-Object System.Drawing.Point(14, 387); $decalsCheck.Size = New-Object System.Drawing.Size(125, 25)
    $ragdollsCheck = New-Object System.Windows.Forms.CheckBox; $ragdollsCheck.Text = 'Ragdolls'; $ragdollsCheck.Location = New-Object System.Drawing.Point(150, 387); $ragdollsCheck.Size = New-Object System.Drawing.Size(100, 25)
    $vsyncCheck = New-Object System.Windows.Forms.CheckBox; $vsyncCheck.Text = 'V-Sync'; $vsyncCheck.Location = New-Object System.Drawing.Point(272, 387); $vsyncCheck.Size = New-Object System.Drawing.Size(90, 25)
    $graphicsGroup.Controls.AddRange(@($shadowCheck, $effectsCheck, $aoCheck, $mapDecorCheck, $decalsCheck, $ragdollsCheck, $vsyncCheck))
    $applyAdvanced = New-V2Button -Label 'APPLY THESE SETTINGS' -X 14 -Y 470 -Width 365 -Height 40 -Color $green
    $saveCustomProfile = New-V2Button -Label 'SAVE AS PROFILE' -X 389 -Y 470 -Width 190 -Height 40 -Color $blue
    $openHidden = New-V2Button -Label 'MORE FPS CONTROLS  >' -X 589 -Y 470 -Width 203 -Height 40 -Color $red
    $advancedTab.Controls.AddRange(@($applyAdvanced, $saveCustomProfile, $openHidden))

    $expertIntro = New-V2Label -Label 'Choose a starting preset below. These controls keep the resolution you chose on the previous page.' -X 18 -Y 8 -Width 760 -Height 32
    $expertIntro.ForeColor = $muted; $expertTab.Controls.Add($expertIntro)
    $hiddenBest = New-V2Button -Label "MOST FPS`r`nLowest picture quality" -X 14 -Y 43 -Width 240 -Height 45 -Color $red
    $hiddenMedium = New-V2Button -Label "BALANCED`r`nGood FPS + clearer image" -X 276 -Y 43 -Width 240 -Height 45 -Color $green
    $hiddenQuality = New-V2Button -Label "BEST PICTURE`r`nLowest FPS of these presets" -X 538 -Y 43 -Width 254 -Height 45 -Color $purple
    $expertTab.Controls.AddRange(@($hiddenBest, $hiddenMedium, $hiddenQuality))
    $memoryGroup = New-Object System.Windows.Forms.GroupBox
    $memoryGroup.Text = 'Textures, memory, and debris'; $memoryGroup.Location = New-Object System.Drawing.Point(14, 96); $memoryGroup.Size = New-Object System.Drawing.Size(375, 260); $memoryGroup.ForeColor = $text
    $expertTab.Controls.Add($memoryGroup)
    $mipLinearCheck = New-Object System.Windows.Forms.CheckBox; $mipLinearCheck.Text = 'Smooth texture transitions'; $mipLinearCheck.Location = New-Object System.Drawing.Point(16, 28); $mipLinearCheck.Size = New-Object System.Drawing.Size(330, 25)
    $memoryGroup.Controls.Add($mipLinearCheck)
    $mipHelp = New-V2Label -Label 'Off is rougher but cheapest; On smooths texture transitions.' -X 16 -Y 53 -Width 340 -Height 34; $mipHelp.ForeColor = $muted; $memoryGroup.Controls.Add($mipHelp)
    $dynamicBudgetCheck = New-Object System.Windows.Forms.CheckBox; $dynamicBudgetCheck.Text = 'Let Apex adjust texture memory'; $dynamicBudgetCheck.Location = New-Object System.Drawing.Point(16, 88); $dynamicBudgetCheck.Size = New-Object System.Drawing.Size(340, 25); $dynamicBudgetCheck.Checked = $true
    $memoryGroup.Controls.Add($dynamicBudgetCheck)
    $dynamicHelp = New-V2Label -Label 'On lets Apex adapt streaming memory; turn Off only when testing stutter.' -X 16 -Y 113 -Width 340 -Height 34; $dynamicHelp.ForeColor = $muted; $memoryGroup.Controls.Add($dynamicHelp)
    $memoryGroup.Controls.Add((New-V2Label -Label 'Queued display frames' -X 16 -Y 153 -Width 210))
    $backbuffer = New-V2Combo -Items @('1','2','3') -X 258 -Y 149 -Width 90 -SelectedIndex 0; $memoryGroup.Controls.Add($backbuffer)
    $backbufferHelp = New-V2Label -Label '1 uses least memory/latency. Higher values can smooth V-Sync.' -X 16 -Y 181 -Width 340 -Height 34; $backbufferHelp.ForeColor = $muted; $memoryGroup.Controls.Add($backbufferHelp)
    $gibsCheck = New-Object System.Windows.Forms.CheckBox; $gibsCheck.Text = 'Combat debris'; $gibsCheck.Location = New-Object System.Drawing.Point(16, 220); $gibsCheck.Size = New-Object System.Drawing.Size(160, 25)
    $ragdollCollisionCheck = New-Object System.Windows.Forms.CheckBox; $ragdollCollisionCheck.Text = 'Ragdoll collision'; $ragdollCollisionCheck.Location = New-Object System.Drawing.Point(190, 220); $ragdollCollisionCheck.Size = New-Object System.Drawing.Size(165, 25)
    $memoryGroup.Controls.AddRange(@($gibsCheck, $ragdollCollisionCheck))

    $shadowGroup = New-Object System.Windows.Forms.GroupBox
    $shadowGroup.Text = 'Shadow and lighting quality'; $shadowGroup.Location = New-Object System.Drawing.Point(402, 96); $shadowGroup.Size = New-Object System.Drawing.Size(390, 260); $shadowGroup.ForeColor = $text
    $expertTab.Controls.Add($shadowGroup)
    $shadowGroup.Controls.Add((New-V2Label -Label 'Minimum shadow detail' -X 14 -Y 31 -Width 205))
    $shadowDepth = New-V2Combo -Items @('0','128','256','512','1024') -X 222 -Y 27 -Width 145 -SelectedIndex 0; $shadowGroup.Controls.Add($shadowDepth)
    $shadowGroup.Controls.Add((New-V2Label -Label 'Shadow upscaling' -X 14 -Y 73 -Width 205))
    $shadowUpres = New-V2Combo -Items @('0','1','2','3','4') -X 222 -Y 69 -Width 145 -SelectedIndex 0; $shadowGroup.Controls.Add($shadowUpres)
    $shadowGroup.Controls.Add((New-V2Label -Label 'Maximum dynamic shadows' -X 14 -Y 115 -Width 205))
    $maxDynamicShadows = New-V2Combo -Items @('0','1','2','4','8') -X 222 -Y 111 -Width 145 -SelectedIndex 0; $shadowGroup.Controls.Add($maxDynamicShadows)
    $shadowGroup.Controls.Add((New-V2Label -Label 'Sun-shadow resolution' -X 14 -Y 157 -Width 205))
    $csmResolution = New-V2Combo -Items @('0','256','512','1024') -X 222 -Y 153 -Width 145 -SelectedIndex 2; $shadowGroup.Controls.Add($csmResolution)
    $ssaoDownsampleCheck = New-Object System.Windows.Forms.CheckBox; $ssaoDownsampleCheck.Text = 'Downsample ambient occlusion'; $ssaoDownsampleCheck.Location = New-Object System.Drawing.Point(14, 199); $ssaoDownsampleCheck.Size = New-Object System.Drawing.Size(245, 25); $ssaoDownsampleCheck.Checked = $true
    $shadowGroup.Controls.Add($ssaoDownsampleCheck)
    $shadowHelp = New-V2Label -Label 'These only matter when Sun Shadows or Extra Lighting are enabled on Resolution + FPS. Zeros are fastest.' -X 14 -Y 225 -Width 350 -Height 30; $shadowHelp.ForeColor = $muted; $shadowGroup.Controls.Add($shadowHelp)

    $distanceGroup = New-Object System.Windows.Forms.GroupBox
    $distanceGroup.Text = 'Draw distance and field of view — smaller values usually give more FPS'
    $distanceGroup.Location = New-Object System.Drawing.Point(14, 366); $distanceGroup.Size = New-Object System.Drawing.Size(580, 144); $distanceGroup.ForeColor = $text
    $expertTab.Controls.Add($distanceGroup)
    $distanceGroup.Controls.Add((New-V2Label -Label 'Distant model quality (smaller = faster)' -X 14 -Y 25 -Width 310))
    $lodScale = New-V2Combo -Items @('0.25','0.35','0.50','0.60','0.70','0.80','1.00') -X 358 -Y 21 -Width 195 -SelectedIndex 3
    $distanceGroup.Controls.Add($lodScale)
    $distanceGroup.Controls.Add((New-V2Label -Label 'Object fade distance (smaller = faster)' -X 14 -Y 55 -Width 310))
    $fadeDistanceScale = New-V2Combo -Items @('0.25','0.35','0.50','0.60','0.70','0.80','1.00') -X 358 -Y 51 -Width 195 -SelectedIndex 3
    $distanceGroup.Controls.Add($fadeDistanceScale)
    $distanceGroup.Controls.Add((New-V2Label -Label 'Cheaper particles when FPS drops' -X 14 -Y 85 -Width 310))
    $particleFallback = New-V2Combo -Items @('Aggressive','Balanced','Default') -X 358 -Y 81 -Width 195 -SelectedIndex 0
    $distanceGroup.Controls.Add($particleFallback)
    $distanceGroup.Controls.Add((New-V2Label -Label 'Field of view (smaller may be faster)' -X 14 -Y 115 -Width 310))
    $viewFov = New-V2Combo -Items @('Keep current','70','80','90','100','110','120') -X 358 -Y 111 -Width 195 -SelectedIndex 0
    $distanceGroup.Controls.Add($viewFov)
    $resetExpert = New-V2Button -Label 'LOAD LOWEST VALUES' -X 610 -Y 366 -Width 182 -Height 32 -Color $red
    $explainExpert = New-V2Button -Label 'WHAT DOES THIS DO?' -X 610 -Y 405 -Width 182 -Height 32 -Color $blue
    $applyHidden = New-V2Button -Label 'APPLY ALL CHANGES' -X 610 -Y 444 -Width 182 -Height 36 -Color $green
    $expertTab.Controls.AddRange(@($resetExpert, $explainExpert, $applyHidden))

    $advancedTips = New-Object System.Windows.Forms.ToolTip
    $advancedTips.AutoPopDelay = 14000; $advancedTips.InitialDelay = 350; $advancedTips.ReshowDelay = 100
    $advancedTips.SetToolTip($hiddenBest, 'Loads the lowest-quality Custom and Advanced values for maximum FPS. Output width and height stay unchanged.')
    $advancedTips.SetToolTip($hiddenMedium, 'Loads a balanced mix of low-cost effects and clearer textures. Output width and height stay unchanged.')
    $advancedTips.SetToolTip($hiddenQuality, 'Loads high textures, filtering, shadows, effects, and ambient occlusion. This costs the most FPS.')
    $advancedTips.SetToolTip($mipLinearCheck, 'Smooths the change between texture mip levels. Off can be slightly cheaper but makes transitions harsher.')
    $advancedTips.SetToolTip($dynamicBudgetCheck, 'Lets Apex adjust texture-streaming memory dynamically. On is recommended for most PCs.')
    $advancedTips.SetToolTip($backbuffer, '1 uses the least memory and queueing. 2 or 3 can smooth V-Sync but may add latency.')
    $advancedTips.SetToolTip($gibsCheck, 'Controls small debris fragments from combat. Off reduces a little rendering and simulation work.')
    $advancedTips.SetToolTip($ragdollCollisionCheck, 'Controls collision calculations between ragdolls. Off reduces physics work.')
    $advancedTips.SetToolTip($shadowDepth, 'Minimum shadow-map allocation. 0 is fastest; higher values reserve more shadow detail.')
    $advancedTips.SetToolTip($shadowUpres, 'Shadow-map upscaling level. 0 is fastest; higher values can improve shadows while increasing GPU cost.')
    $advancedTips.SetToolTip($maxDynamicShadows, 'Limits simultaneous moving-object shadows. 0 is fastest; higher limits add GPU and CPU work.')
    $advancedTips.SetToolTip($csmResolution, 'Resolution of cascaded sun-shadow maps. 0/256 is fastest; 1024 is clearest and most expensive.')
    $advancedTips.SetToolTip($ssaoDownsampleCheck, 'On renders ambient occlusion at reduced resolution for more FPS. It matters only when AO is enabled.')
    $advancedTips.SetToolTip($lodScale, 'Controls how soon distant geometry switches to cheaper low-detail models. 0.25 is fastest; 1.00 keeps detail farther away.')
    $advancedTips.SetToolTip($fadeDistanceScale, 'Controls how far minor objects and effects remain visible. 0.25 fades nonessential detail sooner; 1.00 keeps it farther away.')
    $advancedTips.SetToolTip($particleFallback, 'Aggressive switches complex particle systems to cheaper variants sooner under load. It does not remove gameplay smoke or player abilities.')
    $advancedTips.SetToolTip($viewFov, 'A lower FOV renders less of the world and may improve GPU-limited FPS, but narrows your view. Riftline exposes 70 through 120; Apex may clamp values beyond its current menu range.')
    $advancedTips.SetToolTip($mapDecorCheck, 'Off lowers the engine-supported map detail/set-dressing values. It does not force-remove tactical grass, smoke, or player effects.')

    function Show-AdvancedExplanation {
        $helpForm = New-Object System.Windows.Forms.Form
        $helpForm.Text = 'Advanced settings explained'
        $helpForm.ClientSize = New-Object System.Drawing.Size(720, 640)
        $helpForm.StartPosition = 'CenterParent'; $helpForm.BackColor = $bg; $helpForm.ForeColor = $text
        $helpForm.Font = New-Object System.Drawing.Font('Segoe UI', 10)
        $helpBox = New-Object System.Windows.Forms.TextBox
        $helpBox.Location = New-Object System.Drawing.Point(16, 16); $helpBox.Size = New-Object System.Drawing.Size(688, 566)
        $helpBox.Multiline = $true; $helpBox.ReadOnly = $true; $helpBox.ScrollBars = 'Vertical'
        $helpBox.BackColor = $panel; $helpBox.ForeColor = $text
        $helpBox.Text = @"
HOW THE THREE PRESETS WORK

BEST FPS: Loads the lowest texture, model, particle, shadow, lighting, debris, and physics values. It enables adaptive 3D rendering with a 50% floor, FOV 90, and an uncapped frame rate. Your output width and height are not changed. This gives the largest practical competitive FPS gain but the blurriest/roughest image.

MEDIUM: Uses low textures, medium models/particles, no costly shadows or ambient occlusion, FOV 100, a 144 FPS cap, and full 3D resolution. It is the balanced starting point.

QUALITY: Enables high textures, 16x filtering, TSAA, high models/particles, shadows, volumetric effects, ambient occlusion, debris, ragdoll collision, and FOV 110. It keeps full 3D resolution and costs the most FPS.

INDIVIDUAL ADVANCED CONTROLS

Linear mip filtering [mat_mip_linear]
Smooths the visible transitions between lower-resolution texture mip levels. Off can be marginally cheaper and looks harsher or more pixelated. The FPS difference is normally small.

Dynamic texture budget [dynamic_streaming_budget]
Allows Apex to adjust texture-streaming memory use while playing. On is recommended and can help avoid VRAM pressure. Turning it off is mainly useful for troubleshooting texture-streaming stutter.

Backbuffers [mat_backbuffer_count]
Controls how many completed frames can be buffered for display. 1 uses the least VRAM and usually has the lowest latency. 2 or 3 may make V-Sync smoother, but can increase memory use and input delay.

Gibs [cl_gib_allow]
Enables small combat debris fragments. Off removes that minor visual effect and reduces a little rendering/simulation work.

Ragdoll collision
Allows fallen character bodies to perform extra collision calculations. Off reduces physics work and is best for weak CPUs.

Shadow-map minimum [shadow_depth_dimen_min]
Sets the minimum shadow-map allocation. 0 is the fastest. Higher numbers preserve more shadow detail and consume more GPU memory. It only matters when Sun Shadows are enabled on Custom Tuning.

Shadow upscaling [shadow_depth_upres_factor_max]
Controls the maximum shadow-map upscaling level. 0 minimizes shadow work. Higher values can improve shadow detail but increase GPU cost. It only matters when shadows are enabled.

Maximum dynamic shadows [shadow_maxdynamic]
Limits moving-object shadows. 0 is fastest. Higher limits allow more dynamic shadows and add CPU/GPU work. It only matters when shadows are enabled.

CSM cascade resolution [csm_cascade_res]
Controls cascaded sun-shadow-map resolution. 0 or 256 is cheapest; 512 is moderate; 1024 is clearer and more expensive. It is ignored while Sun Shadows are off.

Downsample ambient occlusion [ssao_downsample]
On renders ambient occlusion at reduced resolution, improving FPS but making contact shadows softer. Off uses fuller-quality AO and costs more. It is ignored while Ambient Occlusion is off.

Geometry LOD switch scale [r_lod_switch_scale]
Controls how soon distant world geometry and models switch to cheaper low-detail versions. 0.25 is the fastest and causes earlier visible model pop-in. 1.00 keeps detailed models farther away. This does not remove players.

Object/effect fade-distance scale [fadeDistScale]
Controls how soon minor distance-based objects and effects fade. 0.25 is fastest and can make scenery pop or disappear sooner; 1.00 keeps it visible farther away. This is the supported distance control closest to what people call a texture/render-distance tweak.

Particle fallback under load [cl_particle_fallback_base/multiplier]
Aggressive asks the engine to use cheaper particle variants sooner when loaded. Balanced waits longer; Default preserves the normal effect level. It does not remove smoke, abilities, player effects, or other gameplay-relevant visibility.

Field of view [cl_fovScale]
A lower FOV draws a narrower view and may provide a small improvement when the GPU is the limit. Riftline offers 70 through 120, including custom 120. Values beyond Apex's normal menu range may be clamped by the current game build. Changing FOV affects awareness and aiming feel, so Keep current is the default. The app backs up profile.cfg before changing it.

MAP DECORATIONS AND FOLIAGE
The Extra map decoration checkbox on Resolution + FPS sets the current engine's supported map-detail/set-dressing values to their low state. The app does not force-disable grass or foliage shaders because that can remove intended cover/visibility and may violate competitive-integrity rules.

BUTTONS AND SAFETY

LOAD LOWEST VALUES changes only the Extra FPS controls. APPLY ALL CHANGES writes both Resolution + FPS and Extra FPS after making a backup. The three presets never change output resolution.

The app deliberately excludes visibility-removal, developer/debug, networking, and anti-cheat-related commands.

FULL GAME-FILE SCAN
The complete 83.5 GB installation was scanned. It contains 46 persisted setting.* keys. This app controls every performance-related key; the remaining gamma and sound-volume keys do not affect FPS. Internal/debug cvars that are not supported saved video settings are intentionally excluded.
"@
        $closeHelp = New-V2Button -Label 'CLOSE' -X 270 -Y 593 -Width 180 -Height 34 -Color $blue
        $closeHelp.Add_Click({ $helpForm.Close() })
        $helpForm.Controls.AddRange(@($helpBox, $closeHelp))
        [void]$helpForm.ShowDialog($form)
    }

    $steamInfo = New-V2Label -Label "These settings are optional. The app passes them automatically when you click Play — you do not need to paste anything into Steam." -X 18 -Y 18 -Width 760 -Height 48
    $steamInfo.ForeColor = $muted; $steamTab.Controls.Add($steamInfo)
    $steamTab.Controls.Add((New-V2Label -Label 'FPS cap' -X 18 -Y 82 -Width 180))
    $fpsCap = New-V2Combo -Items @('0 (Unlimited)','60','75','90','120','138','144','165','180','240','300') -X 18 -Y 106 -Width 230 -SelectedIndex 6
    $steamTab.Controls.Add($fpsCap)
    $steamTab.Controls.Add((New-V2Label -Label 'FPS counter' -X 278 -Y 82 -Width 180))
    $fpsCounter = New-V2Combo -Items @('Off','Basic','Detailed') -X 278 -Y 106 -Width 230
    $steamTab.Controls.Add($fpsCounter)
    $skipIntro = New-Object System.Windows.Forms.CheckBox; $skipIntro.Text = 'Skip intro video (-novid)'; $skipIntro.Location = New-Object System.Drawing.Point(538, 93); $skipIntro.Size = New-Object System.Drawing.Size(220, 26); $skipIntro.Checked = $true
    $steamTab.Controls.Add($skipIntro)
    $uncapLobby = New-Object System.Windows.Forms.CheckBox; $uncapLobby.Text = 'Uncap lobby FPS (+lobby_max_fps 0)'; $uncapLobby.Location = New-Object System.Drawing.Point(538, 121); $uncapLobby.Size = New-Object System.Drawing.Size(240, 26); $uncapLobby.Checked = ($savedText -match '(?i)\+lobby_max_fps\s+0')
    $steamTab.Controls.Add($uncapLobby)
    $noBlackBars = New-Object System.Windows.Forms.CheckBox; $noBlackBars.Text = 'Game-side only: remove black bars using the resolution chosen on page 2'; $noBlackBars.Location = New-Object System.Drawing.Point(18, 158); $noBlackBars.Size = New-Object System.Drawing.Size(720, 26); $noBlackBars.Checked = (($savedText -match '(?i)\+mat_letterbox_aspect_(?:goal|threshold|min)') -or [string]::IsNullOrWhiteSpace($savedText))
    $steamTab.Controls.Add($noBlackBars)
    $steamTab.Controls.Add((New-V2Label -Label 'Additional commands (optional)' -X 18 -Y 189 -Width 300))
    $extraOptions = New-Object System.Windows.Forms.TextBox; $extraOptions.Location = New-Object System.Drawing.Point(18, 214); $extraOptions.Size = New-Object System.Drawing.Size(760, 28)
    $steamTab.Controls.Add($extraOptions)
    $steamTab.Controls.Add((New-V2Label -Label 'App-managed launch commands' -X 18 -Y 256 -Width 300))
    $optionsPreview = New-Object System.Windows.Forms.TextBox; $optionsPreview.Location = New-Object System.Drawing.Point(18, 281); $optionsPreview.Size = New-Object System.Drawing.Size(760, 77); $optionsPreview.Multiline = $true; $optionsPreview.ReadOnly = $true; $optionsPreview.BackColor = $panel; $optionsPreview.ForeColor = $text
    $steamTab.Controls.Add($optionsPreview)
    $refreshOptions = New-V2Button -Label 'UPDATE PREVIEW' -X 18 -Y 372 -Width 180 -Height 46 -Color $blue
    $copyOptions = New-V2Button -Label 'COPY COMMANDS' -X 211 -Y 372 -Width 180 -Height 46 -Color $purple
    $saveOptions = New-V2Button -Label 'SAVE AS DEFAULT' -X 404 -Y 372 -Width 180 -Height 46
    $launchOptions = New-V2Button -Label 'SAVE + PLAY APEX' -X 597 -Y 372 -Width 181 -Height 46 -Color $green
    $steamTab.Controls.AddRange(@($refreshOptions, $copyOptions, $saveOptions, $launchOptions))
    $steamWarning = New-V2Label -Label 'Not included: -high, forced thread counts, -preload, or forced DirectX flags. Those frequently hurt stability, fight Windows scheduling, or become obsolete after updates.' -X 18 -Y 442 -Width 760 -Height 55
    $steamWarning.ForeColor = $muted; $steamTab.Controls.Add($steamWarning)

    function Get-UiLaunchOptions {
        $cap = ([string]$fpsCap.SelectedItem -split ' ')[0]
        $parts = [System.Collections.Generic.List[string]]::new(); $parts.Add("+fps_max $cap")
        if ($skipIntro.Checked) { $parts.Add('-novid') }
        if ($uncapLobby.Checked) { $parts.Add('+lobby_max_fps 0') }
        if ([string]$fpsCounter.SelectedItem -eq 'Basic') { $parts.Add('+cl_showfps 1') }
        if ([string]$fpsCounter.SelectedItem -eq 'Detailed') { $parts.Add('+cl_showfps 4') }
        if ($noBlackBars.Checked) {
            $launchWidth = 0; $launchHeight = 0
            if ((-not [int]::TryParse($widthBox.Text, [ref]$launchWidth)) -or (-not [int]::TryParse($heightBox.Text, [ref]$launchHeight))) {
                throw 'Choose a whole-number width and height on page 2 before removing black bars.'
            }
            $parts.Add((Get-NoBlackBarsLaunchArguments -Width $launchWidth -Height $launchHeight))
        }
        if ([string]$adaptive.SelectedItem -ne 'Off') {
            $scalePercent = [int](([string]$renderScale.SelectedItem).TrimEnd('%'))
            $scaleValue = ($scalePercent / 100).ToString('0.00', [System.Globalization.CultureInfo]::InvariantCulture)
            $parts.Add("+dvs_scale_min $scaleValue")
        }
        if (-not [string]::IsNullOrWhiteSpace($extraOptions.Text)) { $parts.Add($extraOptions.Text.Trim()) }
        $result = $parts -join ' '; Assert-LaunchOptionsSafe -LaunchOptions $result; return $result
    }

    function Get-UiCustomProfile {
        param([Parameter(Mandatory)][string]$Name)
        $width = 0; $height = 0
        if (-not [int]::TryParse($widthBox.Text, [ref]$width)) { throw 'Width must be a whole number.' }
        if (-not [int]::TryParse($heightBox.Text, [ref]$height)) { throw 'Height must be a whole number.' }
        if (($width -lt 640) -or ($width -gt 7680) -or ($height -lt 360) -or ($height -gt 4320)) { throw 'Custom resolution must be between 640x360 and 7680x4320.' }
        $adaptiveTarget = $(if ([string]$adaptive.SelectedItem -eq 'Off') { 0 } else { [int]$adaptive.SelectedItem })
        return [pscustomobject]@{
            Name = $Name; Width = $width; Height = $height; WindowMode = [string]$windowMode.SelectedItem
            TextureBudget = [string]$graphicsCombos[0].SelectedItem; TextureQuality = [string]$graphicsCombos[1].SelectedItem
            Anisotropic = [string]$graphicsCombos[2].SelectedItem; AntiAliasing = [string]$graphicsCombos[3].SelectedItem
            ModelDetail = [string]$graphicsCombos[4].SelectedItem; ParticleDetail = [string]$graphicsCombos[5].SelectedItem
            Shadows = $shadowCheck.Checked; Effects = $effectsCheck.Checked; AmbientOcclusion = $aoCheck.Checked
            MapDecorations = $mapDecorCheck.Checked; Decals = $decalsCheck.Checked
            Ragdolls = $ragdollsCheck.Checked; VSync = $vsyncCheck.Checked; AdaptiveTarget = $adaptiveTarget
            RenderScaleFloor = [int](([string]$renderScale.SelectedItem).TrimEnd('%'))
            Gibs = $gibsCheck.Checked; RagdollCollision = $ragdollCollisionCheck.Checked
            LinearMipFiltering = $mipLinearCheck.Checked; DynamicTextureBudget = $dynamicBudgetCheck.Checked
            BackbufferCount = [int]$backbuffer.SelectedItem; ShadowDepthMin = [int]$shadowDepth.SelectedItem
            ShadowUpresFactor = [int]$shadowUpres.SelectedItem; MaxDynamicShadows = [int]$maxDynamicShadows.SelectedItem
            CsmResolution = [int]$csmResolution.SelectedItem; SsaoDownsample = $ssaoDownsampleCheck.Checked
            LodScale = [string]$lodScale.SelectedItem; FadeDistanceScale = [string]$fadeDistanceScale.SelectedItem
            ParticleFallback = [string]$particleFallback.SelectedItem; ViewFov = [string]$viewFov.SelectedItem
            LowLatency = [string]$lowLatency.SelectedItem; LaunchOptions = Get-UiLaunchOptions
        }
    }

    $help = New-Object System.Windows.Forms.TextBox
    $help.Location = New-Object System.Drawing.Point(18, 18); $help.Size = New-Object System.Drawing.Size(760, 252); $help.Multiline = $true; $help.ReadOnly = $true
    $help.ScrollBars = 'Vertical'; $help.BackColor = $panel; $help.ForeColor = $text
    $help.Text = @"
CUSTOM RESOLUTION
Enter any width from 640-7680 and height from 360-4320. Fullscreen is normally fastest. Non-native or unusual aspect ratios may stretch, letterbox, or be rejected by the display; Restore returns the newest backup.

MORE RESOLUTIONS + ASPECT RATIOS
Opens grouped presets for 16:9, 16:10, 4:3, 5:4, 3:2, 21:9, 32:10, and 32:9. The list includes 2304x1728. The picker fills Resolution + FPS; press Apply These Settings to write it.

BLACK BARS / STRETCHED
GAME-SIDE STRETCHED automatically saves the chosen Apex width and height with +mat_letterbox_aspect_goal 0, +mat_letterbox_aspect_threshold 0, +building_cubemaps "1", -fullscreen, and -multiple. It does not change the Windows desktop resolution, monitor menu, or GPU control panel. GAME DEFAULT removes those helper-managed overrides.

TEXTURE BUDGET
Keep this below available GPU memory. None reduces memory use but can increase texture pop-in. 3 GB is a safe performance starting point; a card with 8 GB or more can usually use 4-6 GB.

ADAPTIVE RESOLUTION
This changes only the internal 3D render resolution when the GPU cannot hold the target; output resolution and HUD stay unchanged. The render-scale floor controls how blurry it may become. It cannot fix a CPU bottleneck. Off gives a stable image.

LOW LATENCY
On + Boost can reduce latency on supported NVIDIA hardware but may use more power. Keep current is safest if unsure.

APP-MANAGED LAUNCHER
+fps_max sets a cap. A stable cap usually feels better than a wildly fluctuating maximum. The helper passes the saved settings directly to Steam's official -applaunch command, so you do not need to edit Steam Properties. Steam still runs in the background for ownership and anti-cheat startup.
"@
    $help.Lines = @($help.Text -split "`r?`n")
    $toolsTab.Controls.Add($help)
    $restore = New-V2Button -Label 'RESTORE NEWEST VIDEO + LATENCY + FOV BACKUPS' -X 18 -Y 294 -Width 760 -Height 54 -Color $blue
    $cache = New-V2Button -Label 'CLEAR PSO SHADER CACHE (TROUBLESHOOTING ONLY)' -X 18 -Y 364 -Width 370 -Height 54 -Color $orange
    $inspect = New-V2Button -Label 'SHOW DETECTED FILE LOCATIONS' -X 408 -Y 364 -Width 370 -Height 54
    $toolsTab.Controls.AddRange(@($restore, $cache, $inspect))
    $cacheNote = New-V2Label -Label 'Clearing the shader cache can cause temporary stutter while it rebuilds. Do this only for corrupted shaders or update-related graphical problems.' -X 18 -Y 436 -Width 760 -Height 44
    $cacheNote.ForeColor = $muted; $toolsTab.Controls.Add($cacheNote)
    $configSafety = New-Object System.Windows.Forms.GroupBox
    $configSafety.Text = 'CONFIG SAFETY'; $configSafety.Location = New-Object System.Drawing.Point(18, 486); $configSafety.Size = New-Object System.Drawing.Size(760, 74); $configSafety.ForeColor = $text
    $lockConfig = New-Object System.Windows.Forms.CheckBox
    $lockConfig.Text = 'Lock videoconfig.txt after changes'; $lockConfig.Location = New-Object System.Drawing.Point(18, 28); $lockConfig.Size = New-Object System.Drawing.Size(260, 26); $lockConfig.Checked = Get-ApexConfigLockState
    $lockHelp = New-V2Label -Label 'Prevents Apex from overwriting the current video config. Riftline preserves the lock when it applies settings.' -X 300 -Y 25 -Width 430 -Height 34
    $lockHelp.ForeColor = $muted
    $configSafety.Controls.AddRange(@($lockConfig, $lockHelp)); $toolsTab.Controls.Add($configSafety)

    $resolutionCatalog = [ordered]@{
        '16:9 - Widescreen' = @('640 x 360','854 x 480','960 x 540','1024 x 576','1280 x 720','1366 x 768','1600 x 900','1920 x 1080','2560 x 1440','3840 x 2160')
        '16:10 - Widescreen' = @('960 x 600','1280 x 800','1440 x 900','1680 x 1050','1920 x 1200','2560 x 1600')
        '4:3 - Classic / stretched' = @('640 x 480','800 x 600','960 x 720','1024 x 768','1152 x 864','1280 x 960','1440 x 1080','1600 x 1200','1920 x 1440','2304 x 1728','2560 x 1920')
        '5:4 - Classic / stretched' = @('640 x 512','800 x 640','960 x 768','1280 x 1024','1600 x 1280','2560 x 2048')
        '3:2 - Wide classic' = @('960 x 640','1440 x 960','1920 x 1280','2160 x 1440','2880 x 1920')
        '21:9 - Ultrawide' = @('1280 x 540','1720 x 720','2560 x 1080','3440 x 1440','3840 x 1600','5120 x 2160')
        '32:10 - Super ultrawide' = @('2560 x 800','3840 x 1200','5120 x 1600')
        '32:9 - Super ultrawide' = @('1920 x 540','2560 x 720','3840 x 1080','5120 x 1440','7680 x 2160')
    }

    function Show-ResolutionPresetPicker {
        $picker = New-Object System.Windows.Forms.Form
        $picker.Text = 'Resolution and aspect-ratio presets'
        $picker.ClientSize = New-Object System.Drawing.Size(620, 390)
        $picker.StartPosition = 'CenterParent'; $picker.FormBorderStyle = 'FixedDialog'; $picker.MaximizeBox = $false
        $picker.BackColor = $bg; $picker.ForeColor = $text; $picker.Font = New-Object System.Drawing.Font('Segoe UI', 10)

        $intro = New-V2Label -Label 'Choose an aspect ratio, then choose a resolution. This only fills the Custom width and height boxes; settings are not written until you press Apply Custom Settings.' -X 20 -Y 18 -Width 580 -Height 48
        $intro.ForeColor = $muted; $picker.Controls.Add($intro)
        $picker.Controls.Add((New-V2Label -Label 'Aspect ratio' -X 20 -Y 82 -Width 180))
        $aspectCombo = New-V2Combo -Items @($resolutionCatalog.Keys) -X 20 -Y 108 -Width 580
        $picker.Controls.Add($aspectCombo)
        $picker.Controls.Add((New-V2Label -Label 'Resolution' -X 20 -Y 153 -Width 180))
        $resolutionCombo = New-V2Combo -Items @($resolutionCatalog[$aspectCombo.SelectedItem]) -X 20 -Y 179 -Width 580
        $picker.Controls.Add($resolutionCombo)
        $fullscreenPreset = New-Object System.Windows.Forms.CheckBox
        $fullscreenPreset.Text = 'Set Window Mode to Fullscreen (recommended for stretched resolutions)'
        $fullscreenPreset.Location = New-Object System.Drawing.Point(20, 226); $fullscreenPreset.Size = New-Object System.Drawing.Size(570, 27); $fullscreenPreset.Checked = $true
        $picker.Controls.Add($fullscreenPreset)
        $warning = New-V2Label -Label 'Choose Game-side stretched on the main page to remove Apex black bars without changing the Windows desktop or monitor settings. Unsupported resolutions may still be rejected by Apex or the display.' -X 20 -Y 263 -Width 580 -Height 52
        $warning.ForeColor = [System.Drawing.Color]::Khaki; $picker.Controls.Add($warning)
        $useResolution = New-V2Button -Label 'USE THIS RESOLUTION' -X 20 -Y 328 -Width 380 -Height 42 -Color $green
        $cancelResolution = New-V2Button -Label 'CANCEL' -X 420 -Y 328 -Width 180 -Height 42
        $picker.Controls.AddRange(@($useResolution, $cancelResolution))

        $aspectCombo.Add_SelectedIndexChanged({
            $resolutionCombo.Items.Clear()
            [void]$resolutionCombo.Items.AddRange([object[]]$resolutionCatalog[[string]$aspectCombo.SelectedItem])
            if ($resolutionCombo.Items.Count -gt 0) { $resolutionCombo.SelectedIndex = 0 }
        })
        $useResolution.Add_Click({
            $selectedResolution = [string]$resolutionCombo.SelectedItem
            if ($selectedResolution -notmatch '^(\d+)\s*x\s*(\d+)$') { return }
            $widthBox.Text = $Matches[1]; $heightBox.Text = $Matches[2]
            if ($fullscreenPreset.Checked) { $windowMode.SelectedItem = 'Fullscreen' }
            Set-V2Status "Loaded $($widthBox.Text)x$($heightBox.Text). Press APPLY THESE SETTINGS when ready."
            $picker.Close()
        })
        $cancelResolution.Add_Click({ $picker.Close() })
        [void]$picker.ShowDialog($form)
    }

    function Show-ScalingGuide {
        $scalingForm = New-Object System.Windows.Forms.Form
        $scalingForm.Text = 'Game-side black bars setting'
        $scalingForm.ClientSize = New-Object System.Drawing.Size(660, 450)
        $scalingForm.StartPosition = 'CenterParent'; $scalingForm.FormBorderStyle = 'FixedDialog'; $scalingForm.MaximizeBox = $false
        $scalingForm.BackColor = $bg; $scalingForm.ForeColor = $text; $scalingForm.Font = New-Object System.Drawing.Font('Segoe UI', 10)
        $scalingIntro = New-V2Label -Label "Choose the result you want. This changes Apex only — no Windows desktop-resolution change, monitor menu, or GPU-control-panel setup is required." -X 20 -Y 16 -Width 620 -Height 58
        $scalingIntro.ForeColor = $muted; $scalingForm.Controls.Add($scalingIntro)
        $blackBarsButton = New-V2Button -Label "GAME DEFAULT`r`nKeep black bars" -X 20 -Y 82 -Width 300 -Height 58 -Color $blue
        $stretchedButton = New-V2Button -Label "GAME-SIDE STRETCHED`r`nRemove black bars" -X 340 -Y 82 -Width 300 -Height 58 -Color $orange
        $scalingForm.Controls.AddRange(@($blackBarsButton, $stretchedButton))
        $scalingInstructions = New-Object System.Windows.Forms.TextBox
        $scalingInstructions.Location = New-Object System.Drawing.Point(20, 155); $scalingInstructions.Size = New-Object System.Drawing.Size(620, 205)
        $scalingInstructions.Multiline = $true; $scalingInstructions.ReadOnly = $true; $scalingInstructions.ScrollBars = 'Vertical'
        $scalingInstructions.BackColor = $panel; $scalingInstructions.ForeColor = $text
        $scalingForm.Controls.Add($scalingInstructions)
        $copyScaling = New-V2Button -Label 'COPY GAME COMMANDS / DETAILS' -X 20 -Y 380 -Width 300 -Height 48 -Color $purple
        $closeScaling = New-V2Button -Label 'CLOSE' -X 340 -Y 380 -Width 300 -Height 48
        $scalingForm.Controls.AddRange(@($copyScaling, $closeScaling))

        function Set-ScalingInstructions {
            param([ValidateSet('BlackBars','Stretched')][string]$Mode)
            $wantBlackBars = $Mode -eq 'BlackBars'
            $resultText = $(if ($wantBlackBars) { 'GAME DEFAULT / KEEP BLACK BARS' } else { 'GAME-SIDE STRETCHED / REMOVE BLACK BARS' })
            $stretchWidth = 0; $stretchHeight = 0
            if (-not [int]::TryParse($widthBox.Text, [ref]$stretchWidth)) { throw 'Width must be a whole number.' }
            if (-not [int]::TryParse($heightBox.Text, [ref]$stretchHeight)) { throw 'Height must be a whole number.' }
            $scalingInstructions.Text = @"
$resultText

WHAT THE APP CHANGES
$(if ($wantBlackBars) { '- Removes the helper-managed Apex stretch commands.' } else { "- Sets Apex to $stretchWidth x $stretchHeight.`r`n- Forces Apex Fullscreen.`r`n- Saves: $(Get-NoBlackBarsLaunchArguments -Width $stretchWidth -Height $stretchHeight)" })

WHAT IT DOES NOT CHANGE
- Your Windows desktop resolution.
- Your monitor settings or monitor menu.
- NVIDIA, AMD, or Intel control-panel settings.
- Your normal resolution after Apex closes.

IMPORTANT
Fullscreen can temporarily switch the display mode only while Apex is open. Windows returns to the normal desktop mode after the game closes.
"@
            $windowMode.SelectedItem = 'Fullscreen'
            $noBlackBars.Checked = -not $wantBlackBars
            $aspectMode.SelectedIndex = $(if ($wantBlackBars) { 1 } else { 0 })
            $updatedOptions = Set-LetterboxLaunchMode -NoBlackBars (-not $wantBlackBars) -Width $stretchWidth -Height $stretchHeight
            $optionsPreview.Text = $updatedOptions
            $savedLabel.Text = "App-managed launch settings: $(if ($updatedOptions) { $updatedOptions } else { '(none — regular Apex letterboxing)' })"
            Set-V2Status "Saved: $resultText. Only Apex settings and launch commands were changed."
        }

        $blackBarsButton.Add_Click({ Set-ScalingInstructions -Mode 'BlackBars' })
        $stretchedButton.Add_Click({ Set-ScalingInstructions -Mode 'Stretched' })
        $copyScaling.Add_Click({
            if (-not [string]::IsNullOrWhiteSpace($scalingInstructions.Text)) { [System.Windows.Forms.Clipboard]::SetText($scalingInstructions.Text) }
        })
        $closeScaling.Add_Click({ $scalingForm.Close() })
        $scalingInstructions.Text = "Choose GAME DEFAULT or GAME-SIDE STRETCHED above.`r`n`r`nGame-side stretched changes Apex only. It does not require changing the Windows desktop resolution, monitor menus, or GPU-control-panel settings."
        [void]$scalingForm.ShowDialog($form)
    }

    # Persistent command bar: the two actions people use most stay visible on every page.
    $searchBox = New-Object System.Windows.Forms.TextBox
    $searchBox.Location = New-Object System.Drawing.Point(790, 27); $searchBox.Size = New-Object System.Drawing.Size(170, 28)
    $searchBox.Text = 'Search / Ctrl+K'; $searchBox.ForeColor = $muted; $searchBox.BackColor = $panel; $searchBox.BorderStyle = 'FixedSingle'
    $header.Controls.Add($searchBox)
    $topApply = New-V2Button -Label 'APPLY ALL' -X 970 -Y 23 -Width 96 -Height 36 -Color $accent
    $topLaunch = New-V2Button -Label 'LAUNCH' -X 1076 -Y 23 -Width 86 -Height 36 -Color $button
    $header.Controls.AddRange(@($topApply, $topLaunch))

    $searchBox.Add_GotFocus({ $searchBox.ForeColor = $text; $searchBox.SelectAll() })
    $searchBox.Add_LostFocus({ if ([string]::IsNullOrWhiteSpace($searchBox.Text)) { $searchBox.Text = 'Search / Ctrl+K'; $searchBox.ForeColor = $muted } })
    $searchBox.Add_KeyDown({
        param($sender, $eventArgs)
        if ($eventArgs.KeyCode -ne [System.Windows.Forms.Keys]::Enter) { return }
        $query = $searchBox.Text.Trim().ToLowerInvariant()
        if ($query -match 'resolution|display|screen|stretch|window|adaptive|scale') { $tabs.SelectedTab = $advancedTab }
        elseif ($query -match 'texture|shadow|effect|graphic|particle|lod|fov|latency|ragdoll') { $tabs.SelectedTab = $expertTab }
        elseif ($query -match 'launch|steam|fps cap|counter|intro|lobby|command') { $tabs.SelectedTab = $steamTab }
        elseif ($query -match 'restore|backup|cache|file|lock|safety|undo') { $tabs.SelectedTab = $toolsTab }
        elseif ($query -match 'profile|preset|auto|competitive|balanced|quality|turbo') { $tabs.SelectedTab = $quickTab }
        else { Set-V2Status "No category matched '$query'. Try texture, resolution, launch, profile, or restore." $true }
        $eventArgs.SuppressKeyPress = $true
    })
    $form.Add_KeyDown({
        param($sender, $eventArgs)
        if ($eventArgs.Control -and ($eventArgs.KeyCode -eq [System.Windows.Forms.Keys]::K)) {
            $searchBox.Focus(); $searchBox.SelectAll(); $eventArgs.SuppressKeyPress = $true
        }
    })

    # Center the retained v17 layouts inside the wider editor canvas.
    foreach ($page in @($quickTab, $advancedTab, $expertTab, $steamTab, $toolsTab)) {
        foreach ($child in @($page.Controls)) { $child.Left += 62; $child.Top += 18 }
    }

    function Set-RiftlineTheme {
        param([System.Windows.Forms.Control]$Root)
        foreach ($control in @($Root.Controls)) {
            if ($control -is [System.Windows.Forms.ComboBox]) {
                $control.FlatStyle = 'Flat'; $control.BackColor = $button; $control.ForeColor = $text
            } elseif ($control -is [System.Windows.Forms.TextBox]) {
                $control.BackColor = $panel; $control.ForeColor = $text; $control.BorderStyle = 'FixedSingle'
            } elseif ($control -is [System.Windows.Forms.GroupBox]) {
                $control.BackColor = $surface; $control.ForeColor = $text
            } elseif ($control -is [System.Windows.Forms.CheckBox]) {
                $control.FlatStyle = 'Flat'; $control.ForeColor = $text; $control.BackColor = [System.Drawing.Color]::Transparent
            } elseif ($control -is [System.Windows.Forms.Label]) {
                if ($control.BackColor -ne $panel) { $control.BackColor = [System.Drawing.Color]::Transparent }
            }
            if ($control.HasChildren) { Set-RiftlineTheme -Root $control }
        }
    }
    Set-RiftlineTheme -Root $form

    # A restrained opening fade keeps the interface feeling responsive without slowing it down.
    $form.Opacity = 0.94
    $openAnimation = New-Object System.Windows.Forms.Timer
    $openAnimation.Interval = 16
    $openAnimation.Add_Tick({
        if ($form.Opacity -ge 0.995) { $form.Opacity = 1; $openAnimation.Stop() }
        else { $form.Opacity = [Math]::Min(1, $form.Opacity + 0.02) }
    })
    $form.Add_Shown({ $openAnimation.Start() })

    $auto.Add_Click({ Run-V2Action { Apply-Profile -Profile $hardware.Profile; $savedLabel.Text = "App-managed launch settings: $(Get-SavedLaunchOptions)" } "Applied $($hardware.Label) graphics, latency, and launcher settings." })
    $competitive.Add_Click({ Run-V2Action { Apply-Profile -Profile 'Competitive'; $savedLabel.Text = "App-managed launch settings: $(Get-SavedLaunchOptions)" } 'Competitive Native profile applied.' })
    $perf1080.Add_Click({ Run-V2Action { Apply-Profile -Profile 'Performance1080'; $savedLabel.Text = "App-managed launch settings: $(Get-SavedLaunchOptions)" } 'Smooth 1080p profile applied.' })
    $low720.Add_Click({ Run-V2Action { Apply-Profile -Profile 'LowEnd720'; $savedLabel.Text = "App-managed launch settings: $(Get-SavedLaunchOptions)" } 'Max FPS 720p profile applied.' })
    $ultra.Add_Click({ Run-V2Action { Apply-Profile -Profile 'UltraLow'; $savedLabel.Text = "App-managed launch settings: $(Get-SavedLaunchOptions)" } 'Emergency 540p profile applied.' })
    $potato.Add_Click({ Run-V2Action { Apply-Profile -Profile 'Potato360'; $savedLabel.Text = "App-managed launch settings: $(Get-SavedLaunchOptions)" } 'Potato 360p profile applied.' })
    $balanced.Add_Click({ Run-V2Action { Apply-Profile -Profile 'Balanced'; $savedLabel.Text = "App-managed launch settings: $(Get-SavedLaunchOptions)" } 'Quality + FPS profile applied.' })
    $turbo.Add_Click({ Run-V2Action { Apply-TurboCurrentResolution; $savedLabel.Text = "App-managed launch settings: $(Get-SavedLaunchOptions)" } 'Turbo applied without changing the current resolution.' })
    $playSaved.Add_Click({ Run-V2Action { Launch-Apex -LaunchOptions (Get-SavedLaunchOptions) } 'Starting Apex with the app-managed profile.' })
    $restoreRegular.Add_Click({
        $answer = [System.Windows.Forms.MessageBox]::Show("Restore the earliest pre-helper Apex settings?`r`n`r`nThis restores video, latency, and FOV files and clears app-managed launch commands. Saved custom profiles are kept. Apex must be closed.", 'Restore Regular Apex', 'YesNo', 'Question')
        if ($answer -eq [System.Windows.Forms.DialogResult]::Yes) {
            Run-V2Action { Restore-RegularApex; $savedLabel.Text = 'App-managed launch settings: (none — regular Apex)' } 'Regular Apex settings restored. Custom profiles were kept.'
        }
    })
    $applyCustomProfile.Add_Click({
        Run-V2Action {
            $name = [string]$customProfiles.SelectedItem
            if ($name -eq '(no saved profiles)') { throw 'Save a profile from Resolution + FPS first.' }
            $profile = @(Get-CustomProfiles | Where-Object { [string]$_.Name -eq $name }) | Select-Object -First 1
            if (-not $profile) { throw "Custom profile was not found: $name" }
            Apply-CustomProfile -Profile $profile
            $savedLabel.Text = "App-managed launch settings: $([string]$profile.LaunchOptions)"
        } 'Custom profile applied with its graphics and launcher settings.'
    })
    $deleteCustomProfile.Add_Click({
        $name = [string]$customProfiles.SelectedItem
        if ($name -eq '(no saved profiles)') { Set-V2Status 'There is no custom profile to delete.' $true; return }
        $answer = [System.Windows.Forms.MessageBox]::Show("Delete custom profile '$name'?", 'Delete custom profile', 'YesNo', 'Question')
        if ($answer -eq [System.Windows.Forms.DialogResult]::Yes) {
            Run-V2Action { Remove-CustomProfile -Name $name; Update-CustomProfileList } 'Custom profile deleted.'
        }
    })
    $nativeButton.Add_Click({ $widthBox.Text = [string]$native.Width; $heightBox.Text = [string]$native.Height })
    $res1080.Add_Click({ $widthBox.Text = '1920'; $heightBox.Text = '1080' })
    $res900.Add_Click({ $widthBox.Text = '1600'; $heightBox.Text = '900' })
    $res768.Add_Click({ $widthBox.Text = '640'; $heightBox.Text = '360' })
    $res720.Add_Click({ $widthBox.Text = '1280'; $heightBox.Text = '720' })
    $res540.Add_Click({ $widthBox.Text = '960'; $heightBox.Text = '540' })
    $moreResolutions.Add_Click({ Show-ResolutionPresetPicker })
    $scalingGuide.Add_Click({ Show-ScalingGuide })
    $openHidden.Add_Click({ $tabs.SelectedTab = $expertTab })
    $graphicsCombos[4].Add_SelectedIndexChanged({
        $uiModelScale = switch ([string]$graphicsCombos[4].SelectedItem) { 'Minimum' { '0.25' }; 'Very Low' { '0.35' }; 'Low' { '0.60' }; 'Medium' { '0.80' }; default { '1.00' } }
        $lodScale.SelectedItem = $uiModelScale; $fadeDistanceScale.SelectedItem = $uiModelScale
    })
    $hiddenBest.Add_Click({
        $graphicsCombos[0].SelectedItem = 'None'; $graphicsCombos[1].SelectedItem = 'Very Low'
        $graphicsCombos[2].SelectedItem = '1x'; $graphicsCombos[3].SelectedItem = 'Off'
        $graphicsCombos[4].SelectedItem = 'Minimum'; $graphicsCombos[5].SelectedItem = 'Low'
        $shadowCheck.Checked = $false; $effectsCheck.Checked = $false; $aoCheck.Checked = $false
        $mapDecorCheck.Checked = $false; $decalsCheck.Checked = $false; $ragdollsCheck.Checked = $false; $vsyncCheck.Checked = $false
        $adaptive.SelectedItem = '120'; $renderScale.SelectedItem = '50%'; $lowLatency.SelectedItem = 'Off'
        $fpsCap.SelectedItem = '0 (Unlimited)'; $fpsCounter.SelectedItem = 'Off'; $skipIntro.Checked = $true
        $mipLinearCheck.Checked = $false; $dynamicBudgetCheck.Checked = $true; $backbuffer.SelectedItem = '1'
        $gibsCheck.Checked = $false; $ragdollCollisionCheck.Checked = $false
        $shadowDepth.SelectedItem = '0'; $shadowUpres.SelectedItem = '0'; $maxDynamicShadows.SelectedItem = '0'
        $csmResolution.SelectedItem = '0'; $ssaoDownsampleCheck.Checked = $true
        $lodScale.SelectedItem = '0.25'; $fadeDistanceScale.SelectedItem = '0.25'; $particleFallback.SelectedItem = 'Aggressive'
        $viewFov.SelectedItem = '90'
        $optionsPreview.Text = Get-UiLaunchOptions
        Set-V2Status 'Most FPS loaded with FOV 90. Resolution was not changed; press APPLY ALL CHANGES.'
    })
    $hiddenMedium.Add_Click({
        $graphicsCombos[0].SelectedItem = '3 GB'; $graphicsCombos[1].SelectedItem = 'Low'
        $graphicsCombos[2].SelectedItem = '4x'; $graphicsCombos[3].SelectedItem = 'Off'
        $graphicsCombos[4].SelectedItem = 'Medium'; $graphicsCombos[5].SelectedItem = 'Medium'
        $shadowCheck.Checked = $false; $effectsCheck.Checked = $false; $aoCheck.Checked = $false
        $mapDecorCheck.Checked = $true; $decalsCheck.Checked = $false; $ragdollsCheck.Checked = $false; $vsyncCheck.Checked = $false
        $adaptive.SelectedItem = 'Off'; $renderScale.SelectedItem = '70%'; $lowLatency.SelectedItem = 'On'
        $fpsCap.SelectedItem = '144'; $fpsCounter.SelectedItem = 'Off'; $skipIntro.Checked = $true
        $mipLinearCheck.Checked = $true; $dynamicBudgetCheck.Checked = $true; $backbuffer.SelectedItem = '1'
        $gibsCheck.Checked = $false; $ragdollCollisionCheck.Checked = $false
        $shadowDepth.SelectedItem = '0'; $shadowUpres.SelectedItem = '0'; $maxDynamicShadows.SelectedItem = '0'
        $csmResolution.SelectedItem = '512'; $ssaoDownsampleCheck.Checked = $true
        $lodScale.SelectedItem = '0.60'; $fadeDistanceScale.SelectedItem = '0.70'; $particleFallback.SelectedItem = 'Balanced'
        $viewFov.SelectedItem = '100'
        $optionsPreview.Text = Get-UiLaunchOptions
        Set-V2Status 'Balanced loaded with FOV 100. Resolution was not changed; press APPLY ALL CHANGES.'
    })
    $hiddenQuality.Add_Click({
        $graphicsCombos[0].SelectedItem = '6 GB'; $graphicsCombos[1].SelectedItem = 'High'
        $graphicsCombos[2].SelectedItem = '16x'; $graphicsCombos[3].SelectedItem = 'TSAA'
        $graphicsCombos[4].SelectedItem = 'High'; $graphicsCombos[5].SelectedItem = 'High'
        $shadowCheck.Checked = $true; $effectsCheck.Checked = $true; $aoCheck.Checked = $true
        $mapDecorCheck.Checked = $true; $decalsCheck.Checked = $true; $ragdollsCheck.Checked = $true; $vsyncCheck.Checked = $false
        $adaptive.SelectedItem = 'Off'; $renderScale.SelectedItem = '100%'; $lowLatency.SelectedItem = 'On'
        $fpsCap.SelectedItem = '120'; $fpsCounter.SelectedItem = 'Off'; $skipIntro.Checked = $true
        $mipLinearCheck.Checked = $true; $dynamicBudgetCheck.Checked = $true; $backbuffer.SelectedItem = '2'
        $gibsCheck.Checked = $true; $ragdollCollisionCheck.Checked = $true
        $shadowDepth.SelectedItem = '512'; $shadowUpres.SelectedItem = '2'; $maxDynamicShadows.SelectedItem = '4'
        $csmResolution.SelectedItem = '1024'; $ssaoDownsampleCheck.Checked = $false
        $lodScale.SelectedItem = '1.00'; $fadeDistanceScale.SelectedItem = '1.00'; $particleFallback.SelectedItem = 'Default'
        $viewFov.SelectedItem = '110'
        $optionsPreview.Text = Get-UiLaunchOptions
        Set-V2Status 'Best Picture loaded with FOV 110. Resolution was not changed; press APPLY ALL CHANGES.'
    })
    $explainExpert.Add_Click({ Show-AdvancedExplanation })
    $resetExpert.Add_Click({
        $mipLinearCheck.Checked = $false; $dynamicBudgetCheck.Checked = $true; $backbuffer.SelectedItem = '1'
        $gibsCheck.Checked = $false; $ragdollCollisionCheck.Checked = $false
        $shadowDepth.SelectedItem = '0'; $shadowUpres.SelectedItem = '0'; $maxDynamicShadows.SelectedItem = '0'
        $csmResolution.SelectedItem = '512'; $ssaoDownsampleCheck.Checked = $true
        $lodScale.SelectedItem = '0.25'; $fadeDistanceScale.SelectedItem = '0.25'; $particleFallback.SelectedItem = 'Aggressive'
        $viewFov.SelectedItem = '70'
        Set-V2Status 'Advanced controls reset to absolute max FPS, including narrow FOV 70.'
    })
    $applyHidden.Add_Click({ $applyAdvanced.PerformClick() })
    $topApply.Add_Click({ $applyAdvanced.PerformClick() })
    $topLaunch.Add_Click({ $playSaved.PerformClick() })
    $applyAdvanced.Add_Click({
        Run-V2Action {
            $width = 0; $height = 0
            if (-not [int]::TryParse($widthBox.Text, [ref]$width)) { throw 'Width must be a whole number.' }
            if (-not [int]::TryParse($heightBox.Text, [ref]$height)) { throw 'Height must be a whole number.' }
            if ($aspectMode.SelectedIndex -in @(0,1)) { $windowMode.SelectedItem = 'Fullscreen' }
            $adaptiveTarget = $(if ([string]$adaptive.SelectedItem -eq 'Off') { 0 } else { [int]$adaptive.SelectedItem })
            Apply-AdvancedSettings -Width $width -Height $height -WindowMode ([string]$windowMode.SelectedItem) -TextureBudget ([string]$graphicsCombos[0].SelectedItem) -TextureQuality ([string]$graphicsCombos[1].SelectedItem) -Anisotropic ([string]$graphicsCombos[2].SelectedItem) -AntiAliasing ([string]$graphicsCombos[3].SelectedItem) -ModelDetail ([string]$graphicsCombos[4].SelectedItem) -ParticleDetail ([string]$graphicsCombos[5].SelectedItem) -Shadows $shadowCheck.Checked -Effects $effectsCheck.Checked -AmbientOcclusion $aoCheck.Checked -MapDecorations $mapDecorCheck.Checked -Decals $decalsCheck.Checked -Ragdolls $ragdollsCheck.Checked -VSync $vsyncCheck.Checked -AdaptiveTarget $adaptiveTarget -LowLatency ([string]$lowLatency.SelectedItem) -Gibs $gibsCheck.Checked -RagdollCollision $ragdollCollisionCheck.Checked -LinearMipFiltering $mipLinearCheck.Checked -DynamicTextureBudget $dynamicBudgetCheck.Checked -BackbufferCount ([int]$backbuffer.SelectedItem) -ShadowDepthMin ([int]$shadowDepth.SelectedItem) -ShadowUpresFactor ([int]$shadowUpres.SelectedItem) -MaxDynamicShadows ([int]$maxDynamicShadows.SelectedItem) -CsmResolution ([int]$csmResolution.SelectedItem) -SsaoDownsample $ssaoDownsampleCheck.Checked -LodScale ([string]$lodScale.SelectedItem) -FadeDistanceScale ([string]$fadeDistanceScale.SelectedItem) -ParticleFallback ([string]$particleFallback.SelectedItem) -ViewFov ([string]$viewFov.SelectedItem)
            if ($aspectMode.SelectedIndex -eq 0) {
                $updatedOptions = Set-LetterboxLaunchMode -NoBlackBars $true -Width $width -Height $height
                $noBlackBars.Checked = $true; $optionsPreview.Text = $updatedOptions; $savedLabel.Text = "App-managed launch settings: $updatedOptions"
            } elseif ($aspectMode.SelectedIndex -eq 1) {
                $updatedOptions = Set-LetterboxLaunchMode -NoBlackBars $false
                $noBlackBars.Checked = $false; $optionsPreview.Text = $updatedOptions; $savedLabel.Text = "App-managed launch settings: $(if ($updatedOptions) { $updatedOptions } else { '(none — regular Apex letterboxing)' })"
            }
        } 'Settings applied and backed up. Screen-shape launch commands were updated automatically.'
    })
    $saveCustomProfile.Add_Click({
        $name = [Microsoft.VisualBasic.Interaction]::InputBox('Name this custom graphics + launcher profile:', 'Save custom profile', 'My FPS Profile')
        if ([string]::IsNullOrWhiteSpace($name)) { Set-V2Status 'Profile save canceled.'; return }
        Run-V2Action {
            $profile = Get-UiCustomProfile -Name $name
            Save-CustomProfile -Profile $profile
            Update-CustomProfileList
            $customProfiles.SelectedItem = $profile.Name
        } 'Custom profile saved. It now appears on the Profiles tab.'
    })
    $refreshOptions.Add_Click({ Run-V2Action { $optionsPreview.Text = Get-UiLaunchOptions } 'Launcher preview refreshed.' })
    $noBlackBars.Add_CheckedChanged({
        if ($noBlackBars.Checked) { $aspectMode.SelectedIndex = 0; $windowMode.SelectedItem = 'Fullscreen' }
        elseif ($aspectMode.SelectedIndex -eq 0) { $aspectMode.SelectedIndex = 2 }
        $optionsPreview.Text = Get-UiLaunchOptions
    })
    $uncapLobby.Add_CheckedChanged({ $optionsPreview.Text = Get-UiLaunchOptions })
    $aspectMode.Add_SelectedIndexChanged({
        if ($aspectMode.SelectedIndex -eq 0) { $noBlackBars.Checked = $true; $windowMode.SelectedItem = 'Fullscreen' }
        elseif ($aspectMode.SelectedIndex -eq 1) { $noBlackBars.Checked = $false; $windowMode.SelectedItem = 'Fullscreen' }
        elseif ($noBlackBars.Checked) { $noBlackBars.Checked = $false }
        $optionsPreview.Text = Get-UiLaunchOptions
    })
    $copyOptions.Add_Click({ Run-V2Action { $value = Get-UiLaunchOptions; $optionsPreview.Text = $value; [System.Windows.Forms.Clipboard]::SetText($value) } 'Copied launch options to the clipboard.' })
    $saveOptions.Add_Click({ Run-V2Action { $value = Get-UiLaunchOptions; Save-LaunchOptions -LaunchOptions $value; $savedLabel.Text = "App-managed launch settings: $value" } 'Launcher settings saved as the app default.' })
    $launchOptions.Add_Click({ Run-V2Action { $value = Get-UiLaunchOptions; $optionsPreview.Text = $value; Launch-Apex -LaunchOptions $value } 'Starting Apex with the generated commands.' })
    $restore.Add_Click({ Run-V2Action { Restore-LatestBackup } 'Newest backups restored.' })
    $cache.Add_Click({ Run-V2Action { Clear-ApexPsoCache } 'PSO cache cleared; temporary rebuild stutter is expected.' })
    $inspect.Add_Click({ [System.Windows.Forms.MessageBox]::Show("Video config:`r`n$(Get-VideoConfigPath)`r`n`r`nSettings config:`r`n$(Get-SettingsConfigPath)`r`n`r`nSteam manifest:`r`n$(Get-SteamManifestPath)`r`n`r`nSaved launch commands:`r`n$(Get-LaunchOptionsPath)", 'Apex locations', 'OK', 'Information') | Out-Null })
    $lockConfig.Add_CheckedChanged({
        Run-V2Action {
            Set-ApexConfigLock -Locked $lockConfig.Checked
        } $(if ($lockConfig.Checked) { 'Config locked. Apex cannot overwrite videoconfig.txt.' } else { 'Config unlocked. Apex may update videoconfig.txt normally.' })
    })
    $optionsPreview.Text = Get-UiLaunchOptions
    if ((-not $savedText) -and ($env:APEX_HELPER_GUI_TEST -ne '1')) {
        [System.Windows.Forms.MessageBox]::Show("QUICK START`r`n`r`n1. Close Apex Legends.`r`n2. Click APPLY AUTO - RECOMMENDED.`r`n3. Click PLAY APEX.`r`n`r`nThat is all you need. Resolution + FPS, Extra FPS, and Launch are optional.", 'Welcome - Apex Performance Helper', 'OK', 'Information') | Out-Null
    }
    if ($env:APEX_HELPER_GUI_TEST -eq '1') {
        foreach ($requiredAspect in @('16:9 - Widescreen','16:10 - Widescreen','4:3 - Classic / stretched','5:4 - Classic / stretched','3:2 - Wide classic','21:9 - Ultrawide','32:10 - Super ultrawide','32:9 - Super ultrawide')) {
            if (-not $resolutionCatalog.Contains($requiredAspect)) { throw "GUI resolution test failed: $requiredAspect is missing." }
            if (@($resolutionCatalog[$requiredAspect]).Count -lt 3) { throw "GUI resolution test failed: $requiredAspect needs multiple resolutions." }
        }
        if (($resolutionCatalog['4:3 - Classic / stretched'] -notcontains '1024 x 768') -or ($resolutionCatalog['4:3 - Classic / stretched'] -notcontains '2304 x 1728') -or ($resolutionCatalog['5:4 - Classic / stretched'] -notcontains '1280 x 1024')) { throw 'GUI resolution test failed: common 4:3 or 5:4 resolution is missing.' }
        foreach ($presetResolution in @($resolutionCatalog.Values | ForEach-Object { $_ })) {
            if ([string]$presetResolution -notmatch '^(\d+)\s*x\s*(\d+)$') { throw "GUI resolution test failed: invalid preset $presetResolution" }
            if (([int]$Matches[1] -lt 640) -or ([int]$Matches[1] -gt 7680) -or ([int]$Matches[2] -lt 360) -or ([int]$Matches[2] -gt 4320)) { throw "GUI resolution test failed: out-of-range preset $presetResolution" }
        }
        if ($scalingGuide.Text -ne 'HOW GAME-SIDE STRETCHING WORKS') { throw 'GUI scaling-guide button test failed.' }
        $noBlackBars.Checked = $true
        $generatedStretch = Get-UiLaunchOptions
        if (($generatedStretch -notmatch '\+mat_letterbox_aspect_goal 0') -or ($generatedStretch -notmatch '\+mat_letterbox_aspect_threshold 0') -or ($generatedStretch -notmatch '\+building_cubemaps "1"') -or ($generatedStretch -notmatch '-w \d+ -h \d+ -fullscreen -multiple')) { throw 'GUI no-black-bars launch-option test failed.' }
        if ($env:APEX_HELPER_PRESET_TEST -eq '1') {
            $clickMethod = $hiddenBest.GetType().GetMethod('OnClick', [System.Reflection.BindingFlags]'Instance, NonPublic')
            [void]$clickMethod.Invoke($hiddenBest, @([System.EventArgs]::Empty))
            if (([string]$graphicsCombos[1].SelectedItem -ne 'Very Low') -or ([string]$renderScale.SelectedItem -ne '50%') -or ([string]$csmResolution.SelectedItem -ne '0') -or ([string]$lodScale.SelectedItem -ne '0.25') -or ([string]$particleFallback.SelectedItem -ne 'Aggressive') -or ([string]$viewFov.SelectedItem -ne '90')) { throw 'GUI preset test failed: Best FPS.' }
            [void]$clickMethod.Invoke($hiddenMedium, @([System.EventArgs]::Empty))
            if (([string]$graphicsCombos[0].SelectedItem -ne '3 GB') -or ([string]$graphicsCombos[4].SelectedItem -ne 'Medium') -or ([string]$fpsCap.SelectedItem -ne '144') -or ([string]$fadeDistanceScale.SelectedItem -ne '0.70') -or ([string]$viewFov.SelectedItem -ne '100')) { throw 'GUI preset test failed: Medium.' }
            [void]$clickMethod.Invoke($hiddenQuality, @([System.EventArgs]::Empty))
            if (([string]$graphicsCombos[3].SelectedItem -ne 'TSAA') -or ([string]$renderScale.SelectedItem -ne '100%') -or ([string]$csmResolution.SelectedItem -ne '1024') -or ([string]$lodScale.SelectedItem -ne '1.00') -or ([string]$particleFallback.SelectedItem -ne 'Default') -or ([string]$viewFov.SelectedItem -ne '110')) { throw 'GUI preset test failed: Quality.' }
        }
        $tabs.SelectedTab = switch ($env:APEX_HELPER_GUI_TAB) {
            'Home' { $quickTab }
            'Graphics' { $expertTab }
            'Launch' { $steamTab }
            'Safety' { $toolsTab }
            default { $advancedTab }
        }
        $testTimer = New-Object System.Windows.Forms.Timer
        $testTimer.Interval = 500
        $testTimer.Add_Tick({
            $testTimer.Stop()
            if (-not [string]::IsNullOrWhiteSpace($env:APEX_HELPER_GUI_SCREENSHOT)) {
                $bitmap = New-Object System.Drawing.Bitmap($form.ClientSize.Width, $form.ClientSize.Height)
                try {
                    $form.DrawToBitmap($bitmap, $form.ClientRectangle)
                    $bitmap.Save($env:APEX_HELPER_GUI_SCREENSHOT, [System.Drawing.Imaging.ImageFormat]::Png)
                } finally { $bitmap.Dispose() }
            }
            $form.Close()
        })
        $testTimer.Start()
    }
    [void]$form.ShowDialog()
}

try {
    if ($Mode -eq 'Bridge') { Invoke-RiftlineBridge }
    elseif ($Mode -eq 'WebGui') { Show-WebLauncher }
    elseif ($Mode -eq 'Gui') { Show-LauncherV2 }
    else { Invoke-Mode -SelectedMode $Mode }
    exit 0
} catch {
    if (($Mode -eq 'Gui') -and ($env:APEX_HELPER_GUI_TEST -ne '1')) {
        try {
            Add-Type -AssemblyName System.Windows.Forms
            [System.Windows.Forms.MessageBox]::Show("The app could not start:`r`n`r`n$($_.Exception.Message)`r`n`r`nExtract the ZIP to a normal folder, then double-click START-HERE.cmd again.", 'Apex Performance Helper - startup error', 'OK', 'Error') | Out-Null
        } catch { }
    }
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}
