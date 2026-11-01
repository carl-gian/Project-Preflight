# =============================================================================
#  Audio-Video Preflight  .  Kingdom Hall AV App -- WTLC Edition
#  Version 5.6 - Steward design + auto-update
# =============================================================================
param(
    # Set by the updater when it restarts Preflight after installing a new
    # version: skips the update check once, and lets a broken install roll back.
    [switch]$JustUpdated
)

# The version this file is. Bump it for every GitHub release (the release tag
# must match, e.g. v5.6.0) -- the updater compares the two.
$Script:AppVersion = [version]"5.6.0"

$Script:ScriptRoot = if ($PSScriptRoot) {
    $PSScriptRoot
} else {
    Split-Path $MyInvocation.MyCommand.Path -ErrorAction SilentlyContinue
}

$Script:MediaFolder = Join-Path $Script:ScriptRoot "media"

# =============================================================================
#  CONFIGURATION
# =============================================================================
$Script:Config = @{
    CongregationName    = "West Tagalog Lingayen Congregation"
    TestMode            = $false
    AdminMode           = $false
    BluetoothMode       = $true
    BluetoothInstanceId = "BTHENUM\DEV_4142F4625775\7&1DA13D4F&0&BLUETOOTHDEVICE_4142F4625775"
    BluetoothDeviceName = "WN_AUDIO"
    ObsDynamicSceneMode = $true
    ObsProfile          = "WTLC - PROFILE"
    ObsSceneMidweek     = "WTLC | Midweek"
    ObsSceneWeekend     = "WTLC | Weekend"
    ZoomSelfHostingMode = $false
    EmeetIntegMode      = $false
    EmeetPath           = "C:\Program Files\EMEET STUDIO\bin\64bit\EMEET STUDIO.exe"
    # Position/size EMEET STUDIO is moved to during the "Let's enable the VCAM"
    # step -- large and prominent so the operator can watch the automated
    # clicks land. EMEET is not part of the final meeting layout.
    EmeetVcamRect       = @{ X = 786; Y = 180; W = 1140; H = 619 }
    WebcamName          = "PTZ Camera"
    WebcamInstanceId    = "USB\VID_328F&PID_00C0&MI_00\8&28D0322B&0&0000"
    JwLibraryShortcut   = "JW Library.lnk"
    ObsPath             = "C:\Program Files\obs-studio\bin\64bit\obs64.exe"
    M3Path              = "C:\Program Files\Meeting Media Manager\Meeting Media Manager.exe"
    ZoomPath            = (Join-Path $env:APPDATA "Zoom\bin\Zoom.exe")
    UsbAudioInstanceId  = "USB\VID_0020&PID_0B21&MI_00\6&31E40A88&0&0000"

    ZoomHome = @{ X = 1300; Y = 40; W = 580; H = 640 }

    # Default launch order/position/size/timing per mode. Order/X/Y/W/H/DelayMs
    # are each individually overridable from Documents\Preflight Settings\Layout.conf
    # (or from Settings > Layout) -- a field left out of that file just falls
    # back to the value here.
    LaunchSequenceStandard = @(
        @{ App = "Obs";  Order = 1; X = 803; Y = 0;   W = 1124; H = 1039; DelayMs = 500 }
        @{ App = "Zoom"; Order = 2; X = -11; Y = 0;   W = 823;  H = 388;  DelayMs = 500 }
        @{ App = "M3";   Order = 3; X = -11; Y = 215; W = 821;  H = 824;  DelayMs = 500 }
    )
    # Non-Zoom (admin) meetings only launch M3, so they keep M3's own tile.
    LaunchSequenceNonZoom = @(
        @{ App = "M3";   Order = 1; X = 953; Y = 385; W = 974; H = 654;  DelayMs = 500 }
    )
    M3ProcessNames    = @("Meeting Media Manager", "meeting-media-manager")
    ZoomProcessNames  = @("Zoom")
    ObsProcessNames   = @("obs64")
    EmeetProcessNames = @("EMEET STUDIO", "EMEET_STUDIO", "EMEETStudio")

    UiRefreshMs        = 600
    PollIntervalSec    = 2
    WindowWaitSeconds  = 30
    ZoomActivationWait = 1500
    ZoomFocusSettle    = 800
    ZoomSidebarRender  = 600
    FinalMessageHold   = 1200
    VideoErrorHold     = 4000
    DataFolder         = (Join-Path $env:LOCALAPPDATA "AV-Preflight")

    # Updates: Preflight checks this GitHub repository's latest release on
    # start, installs a newer one, then restarts itself.
    AutoUpdate         = $true
    UpdateRepo         = "carl-gian/Project-Preflight"
    UpdateTimeoutSec   = 6
}

function Get-PreflightModeName {
    return "Standard"
}

function Get-PreflightSequenceDefaults {
    param([string]$ModeName)
    switch ($ModeName) {
        "NonZoom"    { return $Script:Config.LaunchSequenceNonZoom }
        default      { return $Script:Config.LaunchSequenceStandard }
    }
}

function Resolve-LaunchSequence {
    # Merges a mode's default sequence with any per-field overrides loaded
    # from Layout.conf (field-level: a field left out of the file keeps the
    # script default for that field), then sorts by the effective Order.
    param([string]$ModeName)
    $defaults  = Get-PreflightSequenceDefaults -ModeName $ModeName
    $overrides = if ($Script:LayoutOverrides.ContainsKey($ModeName)) { $Script:LayoutOverrides[$ModeName] } else { @{} }

    $merged = foreach ($step in $defaults) {
        $row = @{ App = $step.App; Order = $step.Order; X = $step.X; Y = $step.Y; W = $step.W; H = $step.H; DelayMs = $step.DelayMs }
        if ($overrides.ContainsKey($step.App)) {
            foreach ($field in $overrides[$step.App].Keys) { $row[$field] = $overrides[$step.App][$field] }
        }
        $row
    }
    return @($merged | Sort-Object { $_.Order })
}

function Get-LaunchStep {
    # Convenience for code that needs just one app's resolved position outside
    # the main Start-Launch loop.
    param([string]$ModeName, [string]$AppName)
    return (Resolve-LaunchSequence -ModeName $ModeName) | Where-Object { $_.App -eq $AppName } | Select-Object -First 1
}

# ----- QUESTIONS -------------------------------------------------------------
$Script:ZoomQuestionsHost = @(
    @{ Text = "Have you already started the meeting?"; Sub = "Start the Zoom meeting first, so the computer audio can be shared in it."; Video = "zoom-start-meeting.mp4" }
    @{ Text = "Have you shared computer audio?"; Sub = "Remote participants need this to hear meeting media."; Video = "zoom-share-audio.mp4" }
)
$Script:ZoomQuestionsJoin = @(
    @{ Text = "Have you already started the meeting?"; Sub = "Start the Zoom meeting first, so the computer audio can be shared in it."; Video = "zoom-start-meeting.mp4" }
    @{ Text = "Have you shared computer audio?"; Sub = "Remote participants need this to hear meeting media."; Video = "zoom-share-audio.mp4" }
)
$Script:EquipmentQuestionsRegular = @(
    @{ Text = "Are all cables plugged into the laptop?";                Sub = "Check the photo below to confirm each cable is connected to the correct port.";  Photo = "check-laptop-connections.jpg" }
    @{ Text = "Is the RCA-to-Aux cable connected to the mixer?";        Sub = "Connects Mixer Output to the Laptop Input";                                                        Photo = "check-rca-cable.jpg" }
    @{ Text = "Are the USB Audio Adapter cables on the adapter ports?"; Sub = "Mic Input should be plugged in as shown for Zoom Mic Input";                                            Photo = "check-usb-cables.jpg" }
    @{ Text = "Is the HDMI-to-Ethernet converter set up?";              Sub = "Required for a stable and reliable HDMI display signal to the TVs.";                                     Photo = "check-hdmi-converter.jpg" }
)
$Script:EquipmentQuestionsNonZoom = @(
    @{ Text = "Are the cables plugged into the laptop?"; Sub = "Check the photo below to confirm the AC Power and HDMI cables are connected — no RCA-Aux or USB Audio needed for this setup."; Photo = "check-admin-nonzoom-connections.jpg" }
    @{ Text = "Is the HDMI-to-Ethernet converter set up?"; Sub = "Required for a stable internet connection during the meeting."; Photo = "check-hdmi-converter.jpg" }
)

# Sections: Zoom -> Equipment
$Script:Sections = @(
    @{ Id = "zoom";      Name = "Zoom Setup";      Type = "video"; Questions = $Script:ZoomQuestionsHost }
    @{ Id = "equipment"; Name = "Equipment Check"; Type = "photo"; Questions = $Script:EquipmentQuestionsRegular }
)

# ----- STATE -----------------------------------------------------------------
$Script:State = @{
    SectionIdx       = 0
    QuestionIdx      = 0
    CurrentVideo     = ""
    AllHwReady       = $false
    AutoLaunched     = $false
    ZoomMode         = ""
    Flow             = "Regular"
    NonZoomProgram   = ""
    BluetoothConfirmed = $false
    BluetoothSettingsOpened = $false
    EmeetVcamEnabled    = $false
}

# ----- HARDWARE CACHE --------------------------------------------------------
$Script:HwCache = [hashtable]::Synchronized(@{
    AcPower  = $false
    Internet = $false
    Display  = $false
    Webcam   = $false
    UsbAudio = $false
    Running  = $true
})

# ----- LOGGING ---------------------------------------------------------------
$Script:LogFile = Join-Path $Script:Config.DataFolder "preflight.log"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $line = "[{0}] [{1}] {2}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Level, $Message
    try {
        if (-not (Test-Path $Script:Config.DataFolder)) {
            New-Item -ItemType Directory -Path $Script:Config.DataFolder -Force | Out-Null
        }
        if ((Test-Path $Script:LogFile) -and (Get-Item $Script:LogFile).Length -gt 512000) {
            $old = $Script:LogFile -replace '\.log$', '.old.log'
            Move-Item -Path $Script:LogFile -Destination $old -Force -ErrorAction SilentlyContinue
        }
        Add-Content -Path $Script:LogFile -Value $line -ErrorAction SilentlyContinue
    } catch {}
    Write-Host $line
}

# ----- PREFERENCE FILE (external config) -------------------------------------
# Congregation-editable settings live in a plain-text file in My Documents so
# they can be tweaked in Notepad without touching this script. $Script:Config
# above still holds the in-memory defaults/schema; the file (if present)
# overrides it. Right-hand sides are real PowerShell expressions (so paths like
# `(Join-Path $env:APPDATA "Zoom\bin\Zoom.exe")` work), evaluated with
# Invoke-Expression -- this file is local and only ever edited by the operator
# or through this app's own Settings menu, the same trust level as a PS profile.
$Script:ConfigDir  = Join-Path ([Environment]::GetFolderPath('MyDocuments')) "Preflight Settings"
$Script:ConfigFile = Join-Path $Script:ConfigDir "Preflight.conf"
$Script:SelfPath   = if ($PSCommandPath) { $PSCommandPath } else { $MyInvocation.MyCommand.Path }

function ConvertTo-ConfigValueLiteral {
    param($Value)
    if ($Value -is [bool]) { if ($Value) { '$true' } else { '$false' } }
    elseif ($Value -is [int] -or $Value -is [double]) { $Value.ToString() }
    else { '"' + ($Value.ToString() -replace '"', '`"') + '"' }
}

function Import-PreflightConfig {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return }
    foreach ($raw in (Get-Content -Path $Path -Encoding UTF8)) {
        $line = $raw.Trim()
        if (-not $line -or $line.StartsWith('#')) { continue }
        $eq = $line.IndexOf('=')
        if ($eq -lt 1) { continue }
        $key    = $line.Substring(0, $eq).Trim()
        $rawVal = $line.Substring($eq + 1).Trim()
        try { $Script:Config[$key] = Invoke-Expression $rawVal }
        catch { Write-Log "Preference file: couldn't read '$key' ($($_.Exception.Message))" "WARN" }
    }
}

function Export-PreflightConfig {
    # Writes a brand-new preference file from the current in-memory $Script:Config.
    # Only used once, by the first-run Setup Wizard -- after that,
    # Update-PreflightConfigFile does targeted line edits instead, so any
    # hand-edited or expression-based lines (like ZoomPath) are preserved.
    param([string]$Path)
    $keysInOrder = @(
        'CongregationName','TestMode','AdminMode','BluetoothMode',
        'BluetoothInstanceId','BluetoothDeviceName','ObsDynamicSceneMode','ObsProfile',
        'ObsSceneMidweek','ObsSceneWeekend','ZoomSelfHostingMode',
        'EmeetIntegMode','EmeetPath',
        'WebcamName','WebcamInstanceId',
        'JwLibraryShortcut','ObsPath','M3Path','ZoomPath','UsbAudioInstanceId',
        'AutoUpdate','UpdateRepo'
    )
    $lines = foreach ($k in $keysInOrder) {
        "{0,-20}= {1}" -f $k, (ConvertTo-ConfigValueLiteral $Script:Config[$k])
    }
    $dir = Split-Path $Path -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    Set-Content -Path $Path -Value $lines -Encoding UTF8
    Write-Log "Preference file created: $Path"
}

function Update-PreflightConfigFile {
    # Rewrites only the given keys in the existing preference file line-by-line,
    # leaving every other line untouched. Appends any key not already present.
    param([hashtable]$Updates, [string]$Path = $Script:ConfigFile)
    if (-not (Test-Path $Path)) { Export-PreflightConfig -Path $Path; return }
    $lines     = @(Get-Content -Path $Path -Encoding UTF8)
    $remaining = $Updates.Clone()
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $trimmed = $lines[$i].Trim()
        if (-not $trimmed -or $trimmed.StartsWith('#')) { continue }
        $eq = $trimmed.IndexOf('=')
        if ($eq -lt 1) { continue }
        $key = $trimmed.Substring(0, $eq).Trim()
        if ($remaining.ContainsKey($key)) {
            $lines[$i] = "{0,-20}= {1}" -f $key, (ConvertTo-ConfigValueLiteral $remaining[$key])
            $remaining.Remove($key)
        }
    }
    if ($remaining.Count -gt 0) {
        $lines += foreach ($k in $remaining.Keys) { "{0,-20}= {1}" -f $k, (ConvertTo-ConfigValueLiteral $remaining[$k]) }
    }
    Set-Content -Path $Path -Value $lines -Encoding UTF8
    Write-Log "Preference file updated: $($Updates.Keys -join ', ')"
}

$Script:NeedsInitialSetup = -not (Test-Path $Script:ConfigFile)
if (-not $Script:NeedsInitialSetup) {
    Import-PreflightConfig -Path $Script:ConfigFile
    $Script:LogFile        = Join-Path $Script:Config.DataFolder "preflight.log"
}

# ----- LAYOUT FILE (window position/size/order/timing overrides) -------------
# A second, separate file from Preflight.conf -- a plain Notepad-friendly table,
# one [Mode] section per launch mode, one row per app. Any field left out of a
# row falls back to the script's built-in default for that field (field-level
# merge), so a hand-edit can be as small as one number.
$Script:LayoutFile = Join-Path $Script:ConfigDir "Layout.conf"

# ----- POWERSHELL INTEGRATION (position/resolution capture) ------------------
function Get-WindowPosition {
    # Captures current window positions from running applications
    param([string]$ProcessName)
    
    try {
        $processes = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 }
        if (-not $processes) { return $null }
        
        $proc = $processes[0]  # Take first matching process
        $handle = $proc.MainWindowHandle
        
        if ($handle -eq 0) { return $null }
        
        # Get window rectangle using Windows API
        $rect = New-Object Win32Native+RECT
        if ([Win32Native]::GetWindowRect($handle, [ref]$rect)) {
            return @{
                X = $rect.Left
                Y = $rect.Top  
                W = $rect.Right - $rect.Left
                H = $rect.Bottom - $rect.Top
            }
        }
    } catch {
        Write-Log "Error getting window position for $ProcessName`: $($_.Exception.Message)" "WARN"
    }
    return $null
}

function Get-ScreenResolution {
    # Gets current primary screen resolution
    try {
        $screen = [System.Windows.Forms.Screen]::PrimaryScreen
        return @{
            Width = $screen.Bounds.Width
            Height = $screen.Bounds.Height
            WorkingWidth = $screen.WorkingArea.Width
            WorkingHeight = $screen.WorkingArea.Height
        }
    } catch {
        Write-Log "Error getting screen resolution: $($_.Exception.Message)" "WARN"
        return @{ Width = 1920; Height = 1080; WorkingWidth = 1920; WorkingHeight = 1040 }
    }
}

function Get-AllAppPositions {
    # Captures positions of all known applications
    $positions = @{}
    $processMap = @{
        "Obs" = @("obs64", "obs-studio", "obs")
        "Zoom" = @("Zoom", "CptHost")  
        "M3" = @("Meeting Media Manager", "M3")
    }
    
    foreach ($app in $processMap.Keys) {
        foreach ($processName in $processMap[$app]) {
            $pos = Get-WindowPosition -ProcessName $processName
            if ($pos) {
                $positions[$app] = $pos
                Write-Log "Captured position for $app`: $($pos.X),$($pos.Y) $($pos.W)x$($pos.H)"
                break
            }
        }
    }
    
    return $positions
}

function Import-PreflightLayoutOverrides {
    param([string]$Path)
    $overrides = @{}
    if (-not (Test-Path $Path)) { return $overrides }
    $currentMode = $null
    foreach ($raw in (Get-Content -Path $Path -Encoding UTF8)) {
        $line = $raw.Trim()
        if (-not $line -or $line.StartsWith('#')) { continue }
        if ($line -match '^\[(.+)\]$') {
            $currentMode = $Matches[1].Trim()
            if (-not $overrides.ContainsKey($currentMode)) { $overrides[$currentMode] = @{} }
            continue
        }
        if (-not $currentMode) { continue }
        $tokens = $line -split '\s+'
        if ($tokens.Count -lt 1) { continue }
        $appName = $tokens[0]
        $fields  = @{}
        for ($i = 1; $i -lt $tokens.Count; $i++) {
            if ($tokens[$i] -match '^(App|Order|X|Y|W|H|DelayMs)=(-?\d+)$') {
                $fields[$Matches[1]] = [int]$Matches[2]
            }
        }
        if (-not $overrides[$currentMode].ContainsKey($appName)) { $overrides[$currentMode][$appName] = @{} }
        foreach ($f in $fields.Keys) { $overrides[$currentMode][$appName][$f] = $fields[$f] }
    }
    return $overrides
}

function Save-PreflightLayoutMode {
    # Replaces one [Mode] section in Layout.conf with a fresh, complete set of
    # rows (used when the Settings > Layout editor saves a mode the operator
    # actually touched) -- every other mode's section is left untouched.
    param([string]$ModeName, [array]$Rows, [string]$Path = $Script:LayoutFile)
    $newSection = @("[$ModeName]")
    foreach ($r in ($Rows | Sort-Object Order)) {
        $newSection += "{0,-8}Order={1}  X={2}  Y={3}  W={4}  H={5}  DelayMs={6}" -f `
            $r.App, $r.Order, $r.X, $r.Y, $r.W, $r.H, $r.DelayMs
    }

    $dir = Split-Path $Path -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }

    $existing = if (Test-Path $Path) { @(Get-Content -Path $Path -Encoding UTF8) } else { @() }
    $out = New-Object System.Collections.Generic.List[string]
    $inTargetSection = $false
    $replaced = $false
    foreach ($line in $existing) {
        $trimmed = $line.Trim()
        if ($trimmed -match '^\[(.+)\]$') {
            $isTarget = ($Matches[1].Trim() -eq $ModeName)
            if ($isTarget) {
                $out.AddRange([string[]]$newSection)
                $replaced = $true
            }
            $inTargetSection = $isTarget
            continue
        }
        if (-not $inTargetSection) { $out.Add($line) }
    }
    if (-not $replaced) {
        if ($out.Count -gt 0) { $out.Add("") }
        $out.AddRange([string[]]$newSection)
    }
    Set-Content -Path $Path -Value $out -Encoding UTF8
    Write-Log "Layout file: saved '$ModeName' ($($Rows.Count) apps)."
}

function Remove-PreflightLayoutMode {
    # "Reset to defaults" for one mode -- deletes its section entirely so the
    # script's built-in defaults take over again.
    param([string]$ModeName, [string]$Path = $Script:LayoutFile)
    if (-not (Test-Path $Path)) { return }
    $existing = @(Get-Content -Path $Path -Encoding UTF8)
    $out = New-Object System.Collections.Generic.List[string]
    $inTargetSection = $false
    foreach ($line in $existing) {
        $trimmed = $line.Trim()
        if ($trimmed -match '^\[(.+)\]$') {
            $inTargetSection = ($Matches[1].Trim() -eq $ModeName)
            if ($inTargetSection) { continue }
        }
        if (-not $inTargetSection) { $out.Add($line) }
    }
    Set-Content -Path $Path -Value $out -Encoding UTF8
    Write-Log "Layout file: reset '$ModeName' to script defaults."
}

$Script:LayoutOverrides = Import-PreflightLayoutOverrides -Path $Script:LayoutFile

# ----- UPDATE FILES (shared by the updater and the rollback) ----------------
# Updates live in %LOCALAPPDATA%\AV-Preflight\update: "previous" holds the
# files an update replaced, "skip-version.txt" a release that failed to start.
$Script:UpdateDir = Join-Path $Script:Config.DataFolder "update"

function Copy-PreflightTree {
    # File-by-file copy that merges into $To (folders that already exist are
    # filled in, never nested), so only the files a release ships get replaced.
    param([string]$From, [string]$To)
    $fromFull = (Resolve-Path -LiteralPath $From).Path.TrimEnd('\', '/')
    foreach ($f in (Get-ChildItem -LiteralPath $fromFull -Recurse -File -Force)) {
        $rel  = $f.FullName.Substring($fromFull.Length).TrimStart('\', '/')
        $dest = Join-Path $To $rel
        $dir  = Split-Path $dest -Parent
        if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        Copy-Item -LiteralPath $f.FullName -Destination $dest -Force
    }
}

function Restore-PreviousVersion {
    # Puts back the files the last update replaced and remembers the broken
    # version, so the next start doesn't install it again.
    $prev = Join-Path $Script:UpdateDir "previous"
    if (-not (Test-Path -LiteralPath (Join-Path $prev "Preflight.ps1"))) { return $false }
    try {
        Set-Content -Path (Join-Path $Script:UpdateDir "skip-version.txt") -Value "$($Script:AppVersion)" -Encoding UTF8
        Copy-PreflightTree -From $prev -To $Script:ScriptRoot
        Write-Log "Rolled back to the previous version (v$($Script:AppVersion) failed to start)." "WARN"
        return $true
    } catch {
        Write-Log "Rollback failed: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

function Restart-Preflight {
    param([switch]$JustUpdated)
    $psArgs = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-WindowStyle", "Hidden", "-File", "`"$Script:SelfPath`"")
    if ($JustUpdated) { $psArgs += "-JustUpdated" }
    try {
        Start-Process -FilePath "powershell.exe" -ArgumentList $psArgs -WindowStyle Hidden
        Write-Log "Restarting Preflight$(if ($JustUpdated) { ' after update' })."
    } catch {
        Write-Log "Restart failed: $($_.Exception.Message)" "ERROR"
    }
}

# ----- PRE-FLIGHT CHECK ------------------------------------------------------
if ($Script:Config.TestMode) {
    Write-Log "=== TEST MODE -- pre-flight bypassed ==="
} else {
    if (Get-Process -Name "obs64" -ErrorAction SilentlyContinue) {
        Write-Log "OBS already running. Exiting silently."
        exit 0
    }
}
Write-Log "=== Audio-Video Preflight v$($Script:AppVersion) (WTLC Edition) starting$(if ($JustUpdated) { ' -- just updated' }) ==="

# ----- ASSEMBLIES ------------------------------------------------------------
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ----- WIN32 -----------------------------------------------------------------
if (-not ([System.Management.Automation.PSTypeName]'Win32Native').Type) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public class Win32Native {
    [DllImport("user32.dll")] public static extern bool MoveWindow(IntPtr hWnd, int X, int Y, int W, int H, bool bRepaint);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool AllowSetForegroundWindow(int dwProcessId);
    [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);
    [DllImport("user32.dll")] public static extern void mouse_event(uint dwFlags, uint dx, uint dy, int dwData, uint dwExtraInfo);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
    [StructLayout(LayoutKind.Sequential)]
    public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }
    public const int SW_RESTORE = 9;
    public const int SW_MINIMIZE = 6;
    public const int ASFW_ANY   = -1;
    public static readonly IntPtr HWND_BOTTOM = new IntPtr(1);
    public const uint SWP_NOSIZE     = 0x0001;
    public const uint SWP_NOMOVE     = 0x0002;
    public const uint SWP_NOACTIVATE = 0x0010;
    public const uint MOUSEEVENTF_LEFTDOWN = 0x0002;
    public const uint MOUSEEVENTF_LEFTUP   = 0x0004;
    public const uint MOUSEEVENTF_WHEEL    = 0x0800;
}
'@
}

# ----- BACKGROUND HARDWARE POLLING -------------------------------------------
$Script:HwRunspace   = $null
$Script:HwPowerShell = $null
$Script:HwHandle     = $null

function Start-HardwarePolling {
    if ($Script:Config.TestMode) { return }
    $Script:HwRunspace = [runspacefactory]::CreateRunspace()
    $Script:HwRunspace.ApartmentState = 'MTA'
    $Script:HwRunspace.Open()
    $Script:HwRunspace.SessionStateProxy.SetVariable('Cache',   $Script:HwCache)
    $Script:HwRunspace.SessionStateProxy.SetVariable('UsbId',   $Script:Config.UsbAudioInstanceId)
    $Script:HwRunspace.SessionStateProxy.SetVariable('CamId',   $Script:Config.WebcamInstanceId)
    $Script:HwRunspace.SessionStateProxy.SetVariable('PollSec', $Script:Config.PollIntervalSec)
    $Script:HwPowerShell = [powershell]::Create()
    $Script:HwPowerShell.Runspace = $Script:HwRunspace
    [void]$Script:HwPowerShell.AddScript({
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
        $pollCount = 0
        while ($Cache.Running) {
            try {
                $plStatus = [System.Windows.Forms.SystemInformation]::PowerStatus.PowerLineStatus
                if ($plStatus -eq 'Online') {
                    $Cache.AcPower = $true
                } elseif ($plStatus -eq 'Offline') {
                    $Cache.AcPower = $false
                } else {
                    # PowerLineStatus reported "Unknown" -- common on HP Victus/Omen EC firmware
                    # even while actively charging. Fall back to WMI battery status, which HP's
                    # embedded controller reports more reliably.
                    $batt = Get-CimInstance -ClassName Win32_Battery -ErrorAction Stop | Select-Object -First 1
                    if ($batt) {
                        # BatteryStatus: 2=AC line/on-line, 3=Fully charged, 6=Charging,
                        # 7=Charging+High, 8=Charging+Low, 9=Charging+Critical, 11=Partially charged
                        $Cache.AcPower = $batt.BatteryStatus -in 2,3,6,7,8,9,11
                    } else {
                        # No battery reported at all (desktop-like) -- treat as AC connected
                        $Cache.AcPower = $true
                    }
                }
            } catch { $Cache.AcPower = $false }
            try {
                $hasProfile = [bool](Get-NetConnectionProfile -ErrorAction Stop | Where-Object { $_.IPv4Connectivity -eq 'Internet' })
                if (-not $hasProfile) { $Cache.Internet = $false }
                elseif ($pollCount % 5 -eq 0) {
                    $p = New-Object System.Net.NetworkInformation.Ping
                    $Cache.Internet = ($p.Send("8.8.8.8", 1000).Status.ToString() -eq 'Success')
                    $p.Dispose()
                }
            } catch { $Cache.Internet = $false }
            try { $Cache.Display  = [System.Windows.Forms.Screen]::AllScreens.Count -gt 1 } catch { $Cache.Display  = $false }
            try { $Cache.Webcam   = [bool](Get-PnpDevice -PresentOnly -ErrorAction SilentlyContinue | Where-Object { $_.InstanceId -eq $CamId -and $_.Status -eq 'OK' }) } catch { $Cache.Webcam   = $false }
            try { $Cache.UsbAudio = [bool](Get-PnpDevice -PresentOnly -ErrorAction SilentlyContinue | Where-Object { $_.InstanceId -eq $UsbId -and $_.Status -eq 'OK' }) } catch { $Cache.UsbAudio = $false }
            $pollCount++
            Start-Sleep -Seconds $PollSec
        }
    })
    $Script:HwHandle = $Script:HwPowerShell.BeginInvoke()
    Write-Log "Background hardware polling started."
}

function Stop-HardwarePolling {
    try {
        $Script:HwCache.Running = $false
        if ($Script:HwPowerShell) {
            $Script:HwPowerShell.Stop()
            if ($Script:HwHandle) { try { $Script:HwPowerShell.EndInvoke($Script:HwHandle) } catch {} }
            $Script:HwPowerShell.Dispose()
        }
        if ($Script:HwRunspace) { $Script:HwRunspace.Close(); $Script:HwRunspace.Dispose() }
    } catch {}
}

# ----- HELPERS ---------------------------------------------------------------
function Get-DefaultMeetingType {
    $d = (Get-Date).DayOfWeek
    if ($d -eq 'Saturday' -or $d -eq 'Sunday') { 'Weekend' } else { 'Midweek' }
}
function Open-NetworkSettings { try { Start-Process "ms-settings:network-status" } catch {} }
function Open-DeviceManager   { try { Start-Process "devmgmt.msc"                } catch {} }

# =============================================================================
#  XAML
# =============================================================================
$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Audio-Video Preflight"
        WindowStyle="None" ResizeMode="NoResize"
        WindowStartupLocation="Manual" Topmost="True"
        Background="#121A2B" FontFamily="Noto Sans, Segoe UI">

  <Window.Resources>

    <!-- Steward design tokens (dark theme), from kingdom-project-design/tokens/tokens.css.
         Use these keys, never raw colours, in new markup. -->
    <SolidColorBrush x:Key="Page"           Color="#121A2B"/>
    <SolidColorBrush x:Key="Surface"        Color="#1A2338"/>
    <SolidColorBrush x:Key="Line"           Color="#2A3550"/>
    <SolidColorBrush x:Key="Text"           Color="#E8EDF6"/>
    <SolidColorBrush x:Key="TextDim"        Color="#9AA6BE"/>
    <SolidColorBrush x:Key="Brand"          Color="#8FA9D6"/>
    <SolidColorBrush x:Key="BrandStrong"    Color="#B3C6E6"/>
    <SolidColorBrush x:Key="BrandSoft"      Color="#22304D"/>
    <SolidColorBrush x:Key="BrandSoftHover" Color="#2C3D62"/>
    <SolidColorBrush x:Key="OnBrand"        Color="#121A2B"/>
    <SolidColorBrush x:Key="Coral"          Color="#F08A6C"/>
    <SolidColorBrush x:Key="Ok"             Color="#5FC08A"/>
    <SolidColorBrush x:Key="Warn"           Color="#F2B544"/>
    <SolidColorBrush x:Key="Danger"         Color="#FF6B5E"/>

    <!-- Visible focus ring for keyboard users (accessibility.md) -->
    <Style x:Key="FocusRing">
      <Setter Property="Control.Template">
        <Setter.Value>
          <ControlTemplate>
            <Border Margin="-4" CornerRadius="999" BorderBrush="#8FA9D6" BorderThickness="3"/>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <!-- st-btn: pill buttons. One primary per screen, secondary for the rest. -->
    <Style x:Key="StBtn" TargetType="Button">
      <Setter Property="FocusVisualStyle" Value="{StaticResource FocusRing}"/>
      <Setter Property="Background" Value="#1A2338"/>
      <Setter Property="Foreground" Value="#E8EDF6"/>
      <Setter Property="BorderBrush" Value="Transparent"/>
      <Setter Property="BorderThickness" Value="1.5"/>
      <Setter Property="FontSize" Value="16"/>
      <Setter Property="FontWeight" Value="Bold"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="MinHeight" Value="56"/>
      <Setter Property="Padding" Value="32,0"/>
      <Setter Property="RenderTransformOrigin" Value="0.5,0.5"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="bd" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}"
                    BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="999" Padding="{TemplateBinding Padding}">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsEnabled" Value="False"><Setter Property="Opacity" Value="0.45"/></Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
      <Style.Triggers>
        <Trigger Property="IsPressed" Value="True">
          <Setter Property="RenderTransform"><Setter.Value><ScaleTransform ScaleX="0.97" ScaleY="0.97"/></Setter.Value></Setter>
        </Trigger>
      </Style.Triggers>
    </Style>

    <!-- Primary (st-btn primary st-btn main) -->
    <Style x:Key="BtnYes" TargetType="Button" BasedOn="{StaticResource StBtn}">
      <Setter Property="Background" Value="#8FA9D6"/>
      <Setter Property="Foreground" Value="#121A2B"/>
      <Style.Triggers>
        <Trigger Property="IsMouseOver" Value="True"><Setter Property="Background" Value="#B3C6E6"/></Trigger>
      </Style.Triggers>
    </Style>
    <Style x:Key="BtnGreen" TargetType="Button" BasedOn="{StaticResource BtnYes}"/>

    <!-- Danger: only for what can't be undone, or skipping a check -->
    <Style x:Key="BtnRed" TargetType="Button" BasedOn="{StaticResource StBtn}">
      <Setter Property="Background" Value="#FF6B5E"/>
      <Setter Property="Foreground" Value="#121A2B"/>
      <Style.Triggers>
        <Trigger Property="IsMouseOver" Value="True"><Setter Property="Background" Value="#FF8A7F"/></Trigger>
      </Style.Triggers>
    </Style>

    <!-- Secondary (st-btn secondary): page fill, line border, brand border on hover -->
    <Style x:Key="BtnShowHow" TargetType="Button" BasedOn="{StaticResource StBtn}">
      <Setter Property="Background" Value="#121A2B"/>
      <Setter Property="BorderBrush" Value="#2A3550"/>
      <Style.Triggers>
        <Trigger Property="IsMouseOver" Value="True"><Setter Property="BorderBrush" Value="#8FA9D6"/></Trigger>
      </Style.Triggers>
    </Style>

    <!-- Small secondary for the top bar -->
    <Style x:Key="BtnStartOver" TargetType="Button" BasedOn="{StaticResource BtnShowHow}">
      <Setter Property="FontSize" Value="14"/>
      <Setter Property="MinHeight" Value="44"/>
      <Setter Property="Padding" Value="20,0"/>
    </Style>

    <!-- Soft (st-btn soft) -->
    <Style x:Key="BtnGear" TargetType="Button" BasedOn="{StaticResource StBtn}">
      <Setter Property="Background" Value="#22304D"/>
      <Setter Property="Foreground" Value="#B3C6E6"/>
      <Setter Property="FontSize" Value="14"/>
      <Setter Property="MinHeight" Value="44"/>
      <Setter Property="Padding" Value="20,0"/>
      <Style.Triggers>
        <Trigger Property="IsMouseOver" Value="True"><Setter Property="Background" Value="#2C3D62"/></Trigger>
      </Style.Triggers>
    </Style>
    <Style x:Key="BtnHelp" TargetType="Button" BasedOn="{StaticResource BtnGear}"/>

    <!-- Round (st-btn round) -->
    <Style x:Key="BtnClose" TargetType="Button" BasedOn="{StaticResource BtnGear}">
      <Setter Property="FontSize" Value="15"/>
      <Setter Property="Width" Value="44"/>
      <Setter Property="Height" Value="44"/>
      <Setter Property="Padding" Value="0"/>
    </Style>

    <!-- Biggest target on the detection screen: primary, full width -->
    <Style x:Key="BtnLaunch" TargetType="Button" BasedOn="{StaticResource BtnYes}">
      <Setter Property="FontSize" Value="18"/>
      <Setter Property="MinHeight" Value="64"/>
    </Style>

    <!-- Quiet (st-btn quiet) -->
    <Style x:Key="BtnBack" TargetType="Button" BasedOn="{StaticResource StBtn}">
      <Setter Property="Background" Value="Transparent"/>
      <Setter Property="Foreground" Value="#8FA9D6"/>
      <Setter Property="FontSize" Value="14"/>
      <Setter Property="MinHeight" Value="44"/>
      <Setter Property="Padding" Value="12,0"/>
      <Style.Triggers>
        <Trigger Property="IsMouseOver" Value="True"><Setter Property="Background" Value="#22304D"/></Trigger>
      </Style.Triggers>
    </Style>

    <!-- st-seg button: one of 2-4 choices -->
    <Style x:Key="BtnMeetingType" TargetType="RadioButton">
      <Setter Property="FocusVisualStyle" Value="{StaticResource FocusRing}"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="FontSize" Value="16"/>
      <Setter Property="FontWeight" Value="Medium"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="RadioButton">
            <Border x:Name="bd" Background="#121A2B" CornerRadius="999" Padding="36,0" MinHeight="52"
                    BorderBrush="#2A3550" BorderThickness="1.5">
              <TextBlock x:Name="tb" Text="{TemplateBinding Content}"
                         Foreground="#9AA6BE" FontSize="{TemplateBinding FontSize}"
                         FontWeight="{TemplateBinding FontWeight}"
                         HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="bd" Property="BorderBrush" Value="#8FA9D6"/>
                <Setter TargetName="tb" Property="Foreground" Value="#E8EDF6"/>
              </Trigger>
              <Trigger Property="IsChecked" Value="True">
                <Setter TargetName="bd" Property="Background" Value="#8FA9D6"/>
                <Setter TargetName="bd" Property="BorderBrush" Value="#8FA9D6"/>
                <Setter TargetName="tb" Property="Foreground" Value="#121A2B"/>
                <Setter TargetName="tb" Property="FontWeight" Value="Bold"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <!-- Settings side menu item -->
    <Style x:Key="NavItem" TargetType="RadioButton">
      <Setter Property="FocusVisualStyle" Value="{StaticResource FocusRing}"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="FontSize" Value="16"/>
      <Setter Property="Margin" Value="0,0,0,4"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="RadioButton">
            <Border x:Name="bd" Background="Transparent" CornerRadius="10" Padding="16,0" MinHeight="48">
              <TextBlock x:Name="tb" Text="{TemplateBinding Content}" Foreground="#9AA6BE"
                         FontSize="{TemplateBinding FontSize}" FontWeight="Medium" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="tb" Property="Foreground" Value="#E8EDF6"/>
              </Trigger>
              <Trigger Property="IsChecked" Value="True">
                <Setter TargetName="bd" Property="Background" Value="#22304D"/>
                <Setter TargetName="tb" Property="Foreground" Value="#B3C6E6"/>
                <Setter TargetName="tb" Property="FontWeight" Value="Bold"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <!-- st-switch: off is an outlined track, on is filled, and the knob moves (readable without colour) -->
    <Style x:Key="ToggleSwitchStyle" TargetType="CheckBox">
      <Setter Property="FocusVisualStyle" Value="{StaticResource FocusRing}"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="CheckBox">
            <Grid Background="Transparent" Width="56" Height="44">
              <Border x:Name="Track" Width="46" Height="28" CornerRadius="14"
                      Background="#121A2B" BorderBrush="#9AA6BE" BorderThickness="1.5">
                <Border x:Name="Thumb" Width="16" Height="16" CornerRadius="8"
                        Background="#9AA6BE" HorizontalAlignment="Left" Margin="5,0,0,0"/>
              </Border>
            </Grid>
            <ControlTemplate.Triggers>
              <Trigger Property="IsChecked" Value="True">
                <Setter TargetName="Track" Property="Background"  Value="#8FA9D6"/>
                <Setter TargetName="Track" Property="BorderBrush" Value="#8FA9D6"/>
                <Setter TargetName="Thumb" Property="Background"  Value="#121A2B"/>
                <Setter TargetName="Thumb" Property="Width"  Value="20"/>
                <Setter TargetName="Thumb" Property="Height" Value="20"/>
                <Setter TargetName="Thumb" Property="CornerRadius" Value="10"/>
                <Setter TargetName="Thumb" Property="HorizontalAlignment" Value="Right"/>
                <Setter TargetName="Thumb" Property="Margin" Value="0,0,3,0"/>
              </Trigger>
              <Trigger Property="IsEnabled" Value="False"><Setter Property="Opacity" Value="0.45"/></Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <Style x:Key="SettingsTextBox" TargetType="TextBox">
      <Setter Property="Background" Value="#121A2B"/>
      <Setter Property="Foreground" Value="#E8EDF6"/>
      <Setter Property="CaretBrush" Value="#E8EDF6"/>
      <Setter Property="BorderBrush" Value="#2A3550"/>
      <Setter Property="BorderThickness" Value="1.5"/>
      <Setter Property="Padding" Value="14,0"/>
      <Setter Property="MinHeight" Value="48"/>
      <Setter Property="FontSize" Value="16"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="TextBox">
            <Border x:Name="bd" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}"
                    BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="10">
              <ScrollViewer x:Name="PART_ContentHost" Margin="{TemplateBinding Padding}" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsKeyboardFocused" Value="True"><Setter TargetName="bd" Property="BorderBrush" Value="#8FA9D6"/></Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <!-- Small number box for the layout inspector -->
    <Style x:Key="LayoutPillTextBox" TargetType="TextBox" BasedOn="{StaticResource SettingsTextBox}">
      <Setter Property="Padding" Value="8,0"/>
      <Setter Property="MinHeight" Value="44"/>
      <Setter Property="TextAlignment" Value="Center"/>
      <Setter Property="FontWeight" Value="SemiBold"/>
    </Style>

    <Style x:Key="LayoutOrderBtn" TargetType="Button" BasedOn="{StaticResource BtnGear}">
      <Setter Property="Width" Value="44"/>
      <Setter Property="Padding" Value="0"/>
    </Style>

    <!-- Layout editor: an invisible drag surface (move) and the resize grips -->
    <Style x:Key="MoveThumb" TargetType="Thumb">
      <Setter Property="Cursor" Value="SizeAll"/>
      <Setter Property="Template">
        <Setter.Value><ControlTemplate TargetType="Thumb"><Border Background="Transparent"/></ControlTemplate></Setter.Value>
      </Setter>
    </Style>
    <Style x:Key="GripThumb" TargetType="Thumb">
      <Setter Property="Template">
        <Setter.Value><ControlTemplate TargetType="Thumb"><Border Background="Transparent"/></ControlTemplate></Setter.Value>
      </Setter>
    </Style>

  </Window.Resources>

  <Grid>
    <Grid.RowDefinitions>
      <RowDefinition Height="84"/>
      <RowDefinition Height="*"/>
      <RowDefinition Height="56"/>
    </Grid.RowDefinitions>
    <Grid.ColumnDefinitions>
      <ColumnDefinition Width="120"/>
      <ColumnDefinition Width="*"/>
    </Grid.ColumnDefinitions>

    <!-- HEADER -->
    <Border Grid.Row="0" Grid.ColumnSpan="2" Background="#121A2B" BorderBrush="#2A3550" BorderThickness="0,0,0,1">
      <Grid Margin="32,0">
        <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
          <Button x:Name="BtnSettings" Content="⚙ Settings" Style="{StaticResource BtnGear}" Margin="0,0,20,0"/>
          <Button x:Name="BtnStartOver" Content="Start Over" Style="{StaticResource BtnStartOver}"
                  Visibility="Collapsed" Margin="0,0,20,0"/>
          <StackPanel VerticalAlignment="Center">
            <TextBlock x:Name="HeaderTitle" Text="Audio-Video Preflight"
                       Foreground="#E8EDF6" FontSize="22" FontWeight="Black" VerticalAlignment="Center"/>
            <TextBlock x:Name="HeaderVersion" Text="" Foreground="#9AA6BE" FontSize="12"/>
          </StackPanel>
        </StackPanel>
        <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" VerticalAlignment="Center">
          <Border x:Name="MeetingTypeBadge" Visibility="Collapsed"
                  Background="#22304D" CornerRadius="999" Padding="14,6" Margin="0,0,20,0" VerticalAlignment="Center">
            <StackPanel Orientation="Horizontal">
              <Ellipse Width="8" Height="8" Fill="#8FA9D6" Margin="0,0,8,0" VerticalAlignment="Center"/>
              <TextBlock x:Name="MeetingTypeBadgeText" Text="Midweek"
                         Foreground="#B3C6E6" FontSize="14" FontWeight="Bold"/>
            </StackPanel>
          </Border>
          <TextBlock x:Name="ClockText" Text="" Foreground="#E8EDF6" FontSize="20" FontWeight="Bold" VerticalAlignment="Center"/>
        </StackPanel>
      </Grid>
    </Border>

    <Border x:Name="TestModeBanner" Grid.Row="0" Grid.ColumnSpan="2" Background="#F2B544"
            VerticalAlignment="Bottom" Height="26" Visibility="Collapsed">
      <TextBlock Text="Test mode: hardware checks are skipped"
                 Foreground="#121A2B" FontSize="14" FontWeight="Bold"
                 HorizontalAlignment="Center" VerticalAlignment="Center"/>
    </Border>

    <!-- SIDEBAR -->
    <Border Grid.Row="1" Grid.Column="0" Background="#121A2B" BorderBrush="#2A3550" BorderThickness="0,0,1,0">
      <StackPanel x:Name="SubwayTrack"
                  HorizontalAlignment="Center" VerticalAlignment="Top"
                  Margin="0,36,0,0"/>
    </Border>

    <!-- USE CASE SCREEN -->
    <Grid x:Name="ScreenUseCase" Grid.Row="1" Grid.Column="1" Visibility="Collapsed">
      <StackPanel HorizontalAlignment="Center" VerticalAlignment="Center" Width="920">
        <TextBlock Text="What are you setting up today?"
                   Foreground="#E8EDF6" FontSize="35" FontWeight="SemiBold" TextWrapping="Wrap" Margin="0,0,0,10"/>
        <TextBlock Text="Choose how this laptop should be configured for today's meeting."
                   Foreground="#9AA6BE" FontSize="20" TextWrapping="Wrap" Margin="0,0,0,30"/>
        <Border Background="#1A2338" CornerRadius="16" Padding="36,32" Margin="0,0,0,20">
          <Grid>
            <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
            <StackPanel Grid.Column="0" Margin="0,0,24,0">
              <TextBlock Text="Regular Meeting" Foreground="#E8EDF6" FontSize="28" FontWeight="Bold" Margin="0,0,0,12"/>
              <TextBlock Foreground="#9AA6BE" FontSize="18" Margin="0,0,0,4" TextWrapping="Wrap"><Run Text="• Hosts Midweek and Weekend Meetings."/></TextBlock>
              <TextBlock Foreground="#9AA6BE" FontSize="18" Margin="0,0,0,4" TextWrapping="Wrap"><Run Text="• Applies default audio and visual setup."/></TextBlock>
              <TextBlock Foreground="#9AA6BE" FontSize="18" TextWrapping="Wrap"><Run Text="• Configures Zoom, OBS, and Meeting Media Manager."/></TextBlock>
            </StackPanel>
            <Button x:Name="BtnUseCaseRegular" Grid.Column="1" Content="Select" Style="{StaticResource BtnYes}" VerticalAlignment="Center"/>
          </Grid>
        </Border>
        <Border Background="#1A2338" CornerRadius="16" Padding="36,32">
          <Grid>
            <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
            <StackPanel Grid.Column="0" Margin="0,0,24,0">
              <TextBlock Text="Non-Zoom Meeting" Foreground="#E8EDF6" FontSize="28" FontWeight="Bold" Margin="0,0,0,12"/>
              <TextBlock Foreground="#9AA6BE" FontSize="18" Margin="0,0,0,4" TextWrapping="Wrap"><Run Text="• Displays media for PSS, SCE, Pioneer's, and Elders &amp; MS meetings."/></TextBlock>
              <TextBlock Foreground="#9AA6BE" FontSize="18" Margin="0,0,0,4" TextWrapping="Wrap"><Run Text="• Ideal for any gathering that does not require Zoom."/></TextBlock>
              <TextBlock Foreground="#9AA6BE" FontSize="18" TextWrapping="Wrap"><Run Text="• Configures the laptop specifically for local/offline use."/></TextBlock>
            </StackPanel>
            <Button x:Name="BtnUseCaseNonZoom" Grid.Column="1" Content="Select" Style="{StaticResource BtnYes}" VerticalAlignment="Center"/>
          </Grid>
        </Border>
      </StackPanel>
    </Grid>

    <!-- ZOOM CHOICE SCREEN -->
    <Grid x:Name="ScreenZoomChoice" Grid.Row="1" Grid.Column="1" Visibility="Collapsed">
      <StackPanel HorizontalAlignment="Center" VerticalAlignment="Center" Width="920">
        <TextBlock Text="Are you hosting or joining today's meeting?"
                   Foreground="#E8EDF6" FontSize="35" FontWeight="SemiBold" TextWrapping="Wrap" Margin="0,0,0,10"/>
        <TextBlock Text="Choose how this laptop connects to Zoom for today's meeting."
                   Foreground="#9AA6BE" FontSize="20" TextWrapping="Wrap" Margin="0,0,0,30"/>
        <Border Background="#1A2338" CornerRadius="16" Padding="36,32" Margin="0,0,0,20">
          <Grid>
            <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
            <TextBlock Grid.Column="0" Text="I will Host Zoom from this Laptop"
                       Foreground="#E8EDF6" FontSize="28" FontWeight="Bold"
                       VerticalAlignment="Center" TextWrapping="Wrap" Margin="0,0,24,0"/>
            <Button x:Name="BtnZoomModeHost" Grid.Column="1" Content="Select" Style="{StaticResource BtnYes}" VerticalAlignment="Center"/>
          </Grid>
        </Border>
        <Border Background="#1A2338" CornerRadius="16" Padding="36,32">
          <Grid>
            <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
            <StackPanel Grid.Column="0" Margin="0,0,24,0">
              <TextBlock Text="This Laptop will join a Zoom Meeting"
                         Foreground="#E8EDF6" FontSize="28" FontWeight="Bold" Margin="0,0,0,12" TextWrapping="Wrap"/>
              <TextBlock Foreground="#9AA6BE" FontSize="18" Margin="0,0,0,4" TextWrapping="Wrap"><Run Text="• You will join your congregation's Zoom Meeting"/></TextBlock>
              <TextBlock Foreground="#FF6B5E" FontSize="18" TextWrapping="Wrap">
                <Run Text="• " FontWeight="Bold"/>
                <Run Text="This laptop will need to be assigned as HOST or CO-HOST" FontWeight="Bold"/>
              </TextBlock>
            </StackPanel>
            <Button x:Name="BtnZoomModeJoin" Grid.Column="1" Content="Select" Style="{StaticResource BtnYes}" VerticalAlignment="Center"/>
          </Grid>
        </Border>
      </StackPanel>
    </Grid>

    <!-- PROGRAM CHOICE SCREEN -->
    <Grid x:Name="ScreenProgramChoice" Grid.Row="1" Grid.Column="1" Visibility="Collapsed">
      <StackPanel HorizontalAlignment="Center" VerticalAlignment="Center" Width="920">
        <TextBlock Text="Which program will you use?"
                   Foreground="#E8EDF6" FontSize="35" FontWeight="SemiBold" TextWrapping="Wrap" Margin="0,0,0,10"/>
        <TextBlock Text="Preflight will launch only the one program you pick."
                   Foreground="#9AA6BE" FontSize="20" TextWrapping="Wrap" Margin="0,0,0,30"/>
        <Border Background="#1A2338" CornerRadius="16" Padding="36,32" Margin="0,0,0,20">
          <Grid>
            <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
            <TextBlock Grid.Column="0" Text="Meeting Media Manager"
                       Foreground="#E8EDF6" FontSize="28" FontWeight="Bold"
                       VerticalAlignment="Center" TextWrapping="Wrap" Margin="0,0,24,0"/>
            <Button x:Name="BtnProgramM3" Grid.Column="1" Content="Select" Style="{StaticResource BtnYes}" VerticalAlignment="Center"/>
          </Grid>
        </Border>
        <Border Background="#1A2338" CornerRadius="16" Padding="36,32">
          <Grid>
            <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
            <StackPanel Grid.Column="0" Margin="0,0,24,0">
              <TextBlock Text="JW Library" Foreground="#E8EDF6" FontSize="28" FontWeight="Bold" Margin="0,0,0,8" TextWrapping="Wrap"/>
              <TextBlock Foreground="#9AA6BE" FontSize="18" TextWrapping="Wrap"><Run Text="• Microsoft Store app"/></TextBlock>
            </StackPanel>
            <Button x:Name="BtnProgramJwLibrary" Grid.Column="1" Content="Select" Style="{StaticResource BtnYes}" VerticalAlignment="Center"/>
          </Grid>
        </Border>
      </StackPanel>
    </Grid>

    <!-- ZOOM INTRO SCREEN -->
    <Grid x:Name="ScreenZoomIntro" Grid.Row="1" Grid.Column="1" Visibility="Collapsed">
      <StackPanel HorizontalAlignment="Left" VerticalAlignment="Center" Width="640" Margin="80,0,0,0">
        <Border Background="#1A2338" CornerRadius="16" Padding="52,46">
          <StackPanel>
            <TextBlock x:Name="ZoomIntroHeading" Text="First, let's start Zoom"
                       Foreground="#E8EDF6" FontSize="35" FontWeight="SemiBold"
                       TextWrapping="Wrap" Margin="0,0,0,12"/>
            <TextBlock x:Name="ZoomIntroSubtext"
                       Text="• Click Open Zoom below&#10;• Start today's meeting&#10;• Come back here once it has started"
                       Foreground="#9AA6BE" FontSize="20" TextWrapping="Wrap" Margin="0,0,0,34"/>
            <StackPanel Orientation="Horizontal">
              <Button x:Name="BtnOpenZoomIntro" Content="Open Zoom" Style="{StaticResource BtnYes}" Margin="0,0,14,0"/>
              <Button x:Name="BtnZoomIntroContinue" Content="&#9654;   Continue"
                      Style="{StaticResource BtnShowHow}" Visibility="Collapsed"/>
            </StackPanel>
          </StackPanel>
        </Border>
      </StackPanel>
    </Grid>

    <!-- QUESTIONS SCREEN -->
    <Grid x:Name="ScreenQuestion" Grid.Row="1" Grid.Column="1" Visibility="Collapsed">
      <StackPanel HorizontalAlignment="Center" VerticalAlignment="Center">

        <StackPanel Orientation="Horizontal" HorizontalAlignment="Center" Margin="0,0,0,26">
          <Border Background="#22304D" CornerRadius="999" Padding="16,6">
            <TextBlock x:Name="SectionBadgeText" Text="Zoom Setup" Foreground="#B3C6E6" FontSize="17" FontWeight="Bold"/>
          </Border>
          <TextBlock x:Name="QuestionCounter" Text="  —  1 of 2"
                     Foreground="#9AA6BE" FontSize="20" VerticalAlignment="Center"/>
        </StackPanel>

        <StackPanel x:Name="DotsPanel" Orientation="Horizontal"
                    HorizontalAlignment="Center" Margin="0,0,0,34"/>

        <!-- Zoom card -->
        <Border x:Name="QuestionCardZoom" Background="#1A2338" CornerRadius="16" Padding="60,54" Width="780">
          <StackPanel>
            <TextBlock x:Name="QuestionText"
                       Foreground="#E8EDF6" FontSize="35" FontWeight="SemiBold"
                       TextWrapping="Wrap" TextAlignment="Center" Margin="0,0,0,12"/>
            <TextBlock x:Name="QuestionSubtext"
                       Foreground="#9AA6BE" FontSize="20"
                       TextWrapping="Wrap" TextAlignment="Center" Margin="0,0,0,42"/>
            <StackPanel Orientation="Horizontal" HorizontalAlignment="Center">
              <Button x:Name="BtnYes"     Content="&#10003;   Yes"         Style="{StaticResource BtnYes}"     Margin="0,0,14,0"/>
              <Button x:Name="BtnShowHow" Content="&#9654;   Show me how"  Style="{StaticResource BtnShowHow}" Visibility="Collapsed"/>
            </StackPanel>
          </StackPanel>
        </Border>

        <!-- Equipment card -->
        <Border x:Name="QuestionCardEquipment" Background="#1A2338" CornerRadius="16" Visibility="Collapsed">
          <Grid>
            <Grid.ColumnDefinitions>
              <ColumnDefinition Width="540"/>
              <ColumnDefinition Width="Auto"/>
            </Grid.ColumnDefinitions>
            <StackPanel Grid.Column="0" VerticalAlignment="Center" Margin="56,52">
              <TextBlock x:Name="EqQuestionText"
                         Foreground="#E8EDF6" FontSize="35" FontWeight="SemiBold"
                         TextWrapping="Wrap" Margin="0,0,0,12"/>
              <TextBlock x:Name="EqQuestionSubtext"
                         Foreground="#9AA6BE" FontSize="20"
                         TextWrapping="Wrap" Margin="0,0,0,36"/>
              <Button x:Name="BtnYesEq" Content="&#10003;   Yes"
                      Style="{StaticResource BtnYes}" HorizontalAlignment="Left"/>
            </StackPanel>
            <Border Grid.Column="1" Width="560" Height="560" CornerRadius="12"
                    Margin="0,28,28,28" Background="#121A2B" ClipToBounds="True">
              <Image x:Name="EqPhotoImage" Stretch="UniformToFill"/>
            </Border>
          </Grid>
        </Border>

        <TextBlock x:Name="VideoErrorText" Foreground="#FF6B5E" FontSize="18"
                   HorizontalAlignment="Center" Margin="0,14,0,0" Visibility="Collapsed"/>
      </StackPanel>
    </Grid>

    <!-- BLUETOOTH SETUP SCREEN (only shown when BluetoothMode is true) -->
    <Grid x:Name="ScreenBluetoothSetup" Grid.Row="1" Grid.Column="1" Visibility="Collapsed">
      <StackPanel HorizontalAlignment="Center" VerticalAlignment="Center">

        <StackPanel Orientation="Horizontal" HorizontalAlignment="Center" Margin="0,0,0,26">
          <Border Background="#22304D" CornerRadius="999" Padding="16,6">
            <TextBlock Text="Equipment Check" Foreground="#B3C6E6" FontSize="17" FontWeight="Bold"/>
          </Border>
        </StackPanel>

        <!-- Sub-question 1: Mixer Bluetooth on? -->
        <Border x:Name="BtSubQ1Panel" Background="#1A2338" CornerRadius="16">
          <Grid>
            <Grid.ColumnDefinitions>
              <ColumnDefinition Width="540"/>
              <ColumnDefinition Width="Auto"/>
            </Grid.ColumnDefinitions>
            <StackPanel Grid.Column="0" VerticalAlignment="Center" Margin="56,52">
              <TextBlock Text="Is the Mixer's Bluetooth turned on?"
                         Foreground="#E8EDF6" FontSize="35" FontWeight="SemiBold"
                         TextWrapping="Wrap" Margin="0,0,0,12"/>
              <TextBlock Foreground="#9AA6BE" FontSize="20" TextWrapping="Wrap" Margin="0,0,0,36">
                <Run Text="&#8226; Refer to the picture for how to turn on Bluetooth on the mixer"/>
              </TextBlock>
              <Button x:Name="BtnBtSubQ1Yes" Content="&#10003;   Yes"
                      Style="{StaticResource BtnYes}" HorizontalAlignment="Left"/>
            </StackPanel>
            <Border Grid.Column="1" Width="560" Height="560" CornerRadius="12"
                    Margin="0,28,28,28" Background="#121A2B" ClipToBounds="True">
              <Image x:Name="BtMixerPhotoImage" Stretch="UniformToFill"/>
            </Border>
          </Grid>
        </Border>

        <!-- Sub-question 2: Connect laptop + verify -->
        <Border x:Name="BtSubQ2Panel" Background="#1A2338" CornerRadius="16" Visibility="Collapsed">
          <Grid>
            <Grid.ColumnDefinitions>
              <ColumnDefinition Width="540"/>
              <ColumnDefinition Width="Auto"/>
            </Grid.ColumnDefinitions>
            <StackPanel Grid.Column="0" VerticalAlignment="Center" Margin="56,52">
              <TextBlock Text="Check the settings" Foreground="#F08A6C" FontSize="17" FontWeight="Bold" Margin="0,0,0,16"/>
              <TextBlock Text="Are you connected to the Bluetooth?"
                         Foreground="#E8EDF6" FontSize="35" FontWeight="SemiBold"
                         TextWrapping="Wrap" Margin="0,0,0,12"/>
              <TextBlock Foreground="#9AA6BE" FontSize="20" TextWrapping="Wrap" Margin="0,0,0,20">
                <Run Text="&#8226; "/><Run Text="Bluetooth Device Name: " FontWeight="Bold" Foreground="#9AA6BE"/><Run x:Name="BtDeviceNameRun" Text="" FontWeight="Bold" Foreground="#E8EDF6"/>
              </TextBlock>
              <TextBlock x:Name="BtCheckStatusText" Foreground="#FF6B5E" FontSize="17"
                         TextWrapping="Wrap" Margin="0,0,0,20" Visibility="Collapsed"/>
              <StackPanel Orientation="Horizontal" HorizontalAlignment="Left">
                <Button x:Name="BtnBluetoothCheck" Content="&#10003;   Check"
                        Style="{StaticResource BtnYes}" Margin="0,0,14,0"/>
                <Button x:Name="BtnBtNotConnected" Content="Not Connected"
                        Style="{StaticResource BtnShowHow}"/>
              </StackPanel>
            </StackPanel>
            <Border x:Name="BtSettingsAnchor" Grid.Column="1" Width="560" Height="560" CornerRadius="12"
                    Margin="0,28,28,28" Background="#121A2B" ClipToBounds="True">
              <TextBlock Text="Opening Bluetooth Settings..." Foreground="#9AA6BE" FontSize="16"
                         HorizontalAlignment="Center" VerticalAlignment="Center" TextWrapping="Wrap"/>
            </Border>
          </Grid>
        </Border>

        <!-- Sub-question 2 (not connected): reconnect instructions -->
        <Border x:Name="BtInstructionsPanel" Background="#1A2338" CornerRadius="16" Padding="56,52" Width="780" Visibility="Collapsed">
          <StackPanel>
            <TextBlock Text="Let's reconnect the Bluetooth"
                       Foreground="#E8EDF6" FontSize="35" FontWeight="SemiBold"
                       TextWrapping="Wrap" Margin="0,0,0,24"/>
            <TextBlock Foreground="#E8EDF6" FontSize="18" TextWrapping="Wrap" Margin="0,0,0,10">
              <Run Foreground="#8FA9D6" FontWeight="Bold" Text="1.  "/>
              <Run Text="Make sure the mixer's Bluetooth light is blinking red."/>
            </TextBlock>
            <TextBlock Foreground="#E8EDF6" FontSize="18" TextWrapping="Wrap" Margin="0,0,0,10">
              <Run Foreground="#8FA9D6" FontWeight="Bold" Text="2.  "/>
              <Run Text="Click Add Device."/>
            </TextBlock>
            <TextBlock Foreground="#E8EDF6" FontSize="18" TextWrapping="Wrap" Margin="0,0,0,10">
              <Run Foreground="#8FA9D6" FontWeight="Bold" Text="3.  "/>
              <Run Text="Click Bluetooth."/>
            </TextBlock>
            <TextBlock Foreground="#E8EDF6" FontSize="18" TextWrapping="Wrap" Margin="0,0,0,32">
              <Run Foreground="#8FA9D6" FontWeight="Bold" Text="4.  "/>
              <Run Text="Click WN_Audio."/>
            </TextBlock>
            <StackPanel Orientation="Horizontal">
              <Button x:Name="BtnBtSkip" Content="Skip" Style="{StaticResource BtnRed}" Margin="0,0,14,0"/>
              <Button x:Name="BtnBtTryAgain" Content="&#8634;   Let's try again" Style="{StaticResource BtnGreen}"/>
            </StackPanel>
          </StackPanel>
        </Border>

        <!-- Restarting Bluetooth screen -->
        <Border x:Name="BtRestartingPanel" Background="#1A2338" CornerRadius="16" Padding="56,52" Width="780" Visibility="Collapsed">
          <TextBlock Text="Restarting Bluetooth..." Foreground="#E8EDF6" FontSize="30" FontWeight="SemiBold"
                     TextAlignment="Center" TextWrapping="Wrap"/>
        </Border>

      </StackPanel>
    </Grid>

    <!-- EMEET SETUP SCREEN (only shown when EmeetIntegMode is on) -->
    <Grid x:Name="ScreenEmeetSetup" Grid.Row="1" Grid.Column="1" Visibility="Collapsed">
      <!-- Left-aligned and width-constrained on purpose: EMEET STUDIO opens at
           (786,180) sized 1140x619 on a 1080p screen, so this card stays clear
           of that area instead of centering across the whole screen. -->
      <StackPanel HorizontalAlignment="Left" VerticalAlignment="Center" Margin="40,0,0,0" Width="620">

        <StackPanel Orientation="Horizontal" HorizontalAlignment="Left" Margin="0,0,0,26">
          <Border Background="#22304D" CornerRadius="999" Padding="16,6">
            <TextBlock Text="EMEET" Foreground="#B3C6E6" FontSize="17" FontWeight="Bold"/>
          </Border>
        </StackPanel>

        <Border Background="#1A2338" CornerRadius="16" Padding="56,52">
          <StackPanel>
            <TextBlock Text="Let's enable the VCAM"
                       Foreground="#E8EDF6" FontSize="35" FontWeight="SemiBold"
                       TextWrapping="Wrap" Margin="0,0,0,12"/>
            <TextBlock Foreground="#9AA6BE" FontSize="20" TextWrapping="Wrap" Margin="0,0,0,10">
              <Run Text="&#8226; EMEET STUDIO will open on the right side of the screen"/>
            </TextBlock>
            <TextBlock Foreground="#9AA6BE" FontSize="20" TextWrapping="Wrap" Margin="0,0,0,36">
              <Run Text="&#8226; The virtual camera turns on automatically -- just wait for it to finish"/>
            </TextBlock>
            <TextBlock x:Name="EmeetVcamStatusText" Foreground="#8FA9D6" FontSize="18" FontWeight="SemiBold"
                       TextWrapping="Wrap" Margin="0,0,0,24" Visibility="Collapsed"/>
            <Button x:Name="BtnEmeetEnable" Content="&#9889;   Enable"
                    Style="{StaticResource BtnYes}" HorizontalAlignment="Left"/>
          </StackPanel>
        </Border>

      </StackPanel>
    </Grid>

    <!-- VIDEO SCREEN -->
    <Grid x:Name="ScreenVideo" Grid.Row="1" Grid.Column="1" Visibility="Collapsed" Background="#000000">
      <MediaElement x:Name="VideoPlayer" LoadedBehavior="Manual" UnloadedBehavior="Stop"
                    Stretch="Uniform" HorizontalAlignment="Stretch" VerticalAlignment="Stretch"/>
      <Button x:Name="BtnCloseVideo" Content="&#10005;" Style="{StaticResource BtnClose}"
              HorizontalAlignment="Right" VerticalAlignment="Top" Margin="20"/>
    </Grid>

    <!-- CONFIRM SCREEN -->
    <Grid x:Name="ScreenConfirm" Grid.Row="1" Grid.Column="1" Visibility="Collapsed">
      <StackPanel HorizontalAlignment="Center" VerticalAlignment="Center" Width="700">
        <Border Background="#1A2338" CornerRadius="16" Padding="52,46">
          <StackPanel>
            <TextBlock x:Name="ConfirmText"
                       Foreground="#E8EDF6" FontSize="35" FontWeight="SemiBold"
                       TextWrapping="Wrap" TextAlignment="Center" Margin="0,0,0,12"/>
            <TextBlock Text="Now that you've seen how — did you do it?"
                       Foreground="#9AA6BE" FontSize="20" TextAlignment="Center" Margin="0,0,0,42"/>
            <StackPanel Orientation="Horizontal" HorizontalAlignment="Center">
              <Button x:Name="BtnConfirmYes" Content="&#10003;   Yes, I have" Style="{StaticResource BtnYes}"     Margin="0,0,14,0"/>
              <Button x:Name="BtnWatchAgain" Content="&#8634;   Watch again"  Style="{StaticResource BtnShowHow}"/>
            </StackPanel>
          </StackPanel>
        </Border>
      </StackPanel>
    </Grid>

    <!-- DETECTION SCREEN -->
    <Grid x:Name="ScreenDetection" Grid.Row="1" Grid.Column="1" Visibility="Collapsed">
      <ScrollViewer VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled">
        <Grid Margin="40,32,40,40" Width="1230" HorizontalAlignment="Center">
          <Grid.ColumnDefinitions>
            <ColumnDefinition Width="420"/>
            <ColumnDefinition Width="28"/>
            <ColumnDefinition Width="*"/>
          </Grid.ColumnDefinitions>

          <!-- Left panel -->
          <StackPanel Grid.Column="0" VerticalAlignment="Top">
            <Border Background="#22304D" CornerRadius="999" Padding="14,6"
                    Margin="0,0,0,28" HorizontalAlignment="Left">
              <TextBlock Text="Detection" Foreground="#B3C6E6" FontSize="15" FontWeight="Bold"/>
            </Border>
            <StackPanel x:Name="DetSubwayTrack"/>

          </StackPanel>

          <!-- Right panel: hardware cards + action panels -->
          <StackPanel Grid.Column="2">

            <Grid>
              <Grid.ColumnDefinitions>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="14"/>
                <ColumnDefinition Width="*"/>
              </Grid.ColumnDefinitions>
              <Grid.RowDefinitions>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="14"/>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="14"/>
                <RowDefinition Height="Auto"/>
              </Grid.RowDefinitions>

              <!-- AC Power -->
              <Border Grid.Column="0" Grid.Row="0" Background="#1A2338" CornerRadius="12" Padding="22,20">
                <StackPanel>
                  <StackPanel Orientation="Horizontal" Margin="0,0,0,6">
                    <Border x:Name="DetIconAcPower" Width="52" Height="52" CornerRadius="6" Margin="0,0,14,0"/>
                    <TextBlock Text="Charger" Foreground="#E8EDF6" FontSize="20" FontWeight="SemiBold" VerticalAlignment="Center"/>
                  </StackPanel>
                  <TextBlock x:Name="DetStatusAcPower" Text="Checking..." Foreground="#9AA6BE" FontSize="17" Margin="66,0,0,0"/>
                  <StackPanel x:Name="DetHelpAcPower" Visibility="Collapsed" Margin="0,10,0,0">
                    <TextBlock Text="Laptop is on battery. Connect the power adapter." Foreground="#9AA6BE" FontSize="16" TextWrapping="Wrap"/>
                  </StackPanel>
                </StackPanel>
              </Border>

              <!-- Internet -->
              <Border Grid.Column="2" Grid.Row="0" Background="#1A2338" CornerRadius="12" Padding="22,20">
                <StackPanel>
                  <StackPanel Orientation="Horizontal" Margin="0,0,0,6">
                    <Border x:Name="DetIconInternet" Width="52" Height="52" CornerRadius="6" Margin="0,0,14,0"/>
                    <TextBlock Text="Internet" Foreground="#E8EDF6" FontSize="20" FontWeight="SemiBold" VerticalAlignment="Center"/>
                  </StackPanel>
                  <TextBlock x:Name="DetStatusInternet" Text="Checking..." Foreground="#9AA6BE" FontSize="17" Margin="66,0,0,0"/>
                  <StackPanel x:Name="DetHelpInternet" Visibility="Collapsed" Margin="0,10,0,0">
                    <TextBlock Text="No internet detected. Check the Ethernet converter." Foreground="#9AA6BE" FontSize="16" Margin="0,0,0,8"/>
                    <Button x:Name="BtnOpenInternet" Content="Open Network Settings" Style="{StaticResource BtnHelp}" HorizontalAlignment="Left"/>
                  </StackPanel>
                </StackPanel>
              </Border>

              <!-- HDMI Display -->
              <Border Grid.Column="0" Grid.Row="2" Background="#1A2338" CornerRadius="12" Padding="22,20">
                <StackPanel>
                  <StackPanel Orientation="Horizontal" Margin="0,0,0,6">
                    <Border x:Name="DetIconDisplay" Width="52" Height="52" CornerRadius="6" Margin="0,0,14,0"/>
                    <TextBlock Text="HDMI Display" Foreground="#E8EDF6" FontSize="20" FontWeight="SemiBold" VerticalAlignment="Center"/>
                  </StackPanel>
                  <TextBlock x:Name="DetStatusDisplay" Text="Checking..." Foreground="#9AA6BE" FontSize="17" Margin="66,0,0,0"/>
                  <StackPanel x:Name="DetHelpDisplay" Visibility="Collapsed" Margin="0,10,0,0">
                    <TextBlock Text="Extended display not found. Check the HDMI cable." Foreground="#9AA6BE" FontSize="16" TextWrapping="Wrap"/>
                  </StackPanel>
                </StackPanel>
              </Border>

              <!-- Webcam -->
              <Border Grid.Column="2" Grid.Row="2" Background="#1A2338" CornerRadius="12" Padding="22,20">
                <StackPanel>
                  <StackPanel Orientation="Horizontal" Margin="0,0,0,6">
                    <Border x:Name="DetIconWebcam" Width="52" Height="52" CornerRadius="6" Margin="0,0,14,0"/>
                    <TextBlock x:Name="DetLabelWebcam" Text="Webcam" Foreground="#E8EDF6" FontSize="20" FontWeight="SemiBold" VerticalAlignment="Center"/>
                  </StackPanel>
                  <TextBlock x:Name="DetStatusWebcam" Text="Checking..." Foreground="#9AA6BE" FontSize="17" Margin="66,0,0,0"/>
                  <StackPanel x:Name="DetHelpWebcam" Visibility="Collapsed" Margin="0,10,0,0">
                    <TextBlock Text="Webcam not detected. Check the USB connection." Foreground="#9AA6BE" FontSize="16" Margin="0,0,0,8"/>
                    <Button x:Name="BtnOpenWebcam" Content="Open Device Manager" Style="{StaticResource BtnHelp}" HorizontalAlignment="Left"/>
                  </StackPanel>
                </StackPanel>
              </Border>

              <!-- USB Audio -->
              <Border x:Name="DetCardUsbAudio" Grid.Column="0" Grid.Row="4"
                      Background="#1A2338" CornerRadius="12" Padding="22,20">
                <StackPanel>
                  <StackPanel Orientation="Horizontal" Margin="0,0,0,6">
                    <Border x:Name="DetIconUsbAudio" Width="52" Height="52" CornerRadius="6" Margin="0,0,14,0"/>
                    <TextBlock Text="USB Audio Adapter" Foreground="#E8EDF6" FontSize="20" FontWeight="SemiBold" VerticalAlignment="Center"/>
                  </StackPanel>
                  <TextBlock x:Name="DetStatusUsbAudio" Text="Checking..." Foreground="#9AA6BE" FontSize="17" Margin="66,0,0,0"/>
                  <StackPanel x:Name="DetHelpUsbAudio" Visibility="Collapsed" Margin="0,10,0,0">
                    <TextBlock Text="USB Audio Adapter not found. Check the USB cable." Foreground="#9AA6BE" FontSize="16" TextWrapping="Wrap"/>
                  </StackPanel>
                </StackPanel>
              </Border>

            </Grid>

            <!-- Ready Panel -->
            <Border x:Name="DetReadyPanel" Visibility="Collapsed"
                    Background="#1A2338" CornerRadius="16" Padding="52,40" Margin="0,20,0,0">
              <StackPanel>
                <TextBlock Text="All systems ready. Select your meeting type."
                           Foreground="#9AA6BE" FontSize="20" TextAlignment="Center" Margin="0,0,0,24"/>
                <StackPanel Orientation="Horizontal" HorizontalAlignment="Center" Margin="0,0,0,28">
                  <RadioButton x:Name="RadioMidweek" GroupName="MeetingType" Content="Midweek"
                               Style="{StaticResource BtnMeetingType}" Margin="0,0,12,0"/>
                  <RadioButton x:Name="RadioWeekend" GroupName="MeetingType" Content="Weekend"
                               Style="{StaticResource BtnMeetingType}"/>
                </StackPanel>
                <Button x:Name="LaunchButton" Content="Launch Meeting Setup"
                        Style="{StaticResource BtnLaunch}" Visibility="Collapsed"/>
              </StackPanel>
            </Border>

            <Button x:Name="BtnBackToEquipment"
                    Content="&#8592; Back to Equipment Check"
                    Style="{StaticResource BtnBack}"
                    HorizontalAlignment="Center" Margin="0,20,0,0"/>

          </StackPanel>
        </Grid>
      </ScrollViewer>
    </Grid>

    <!-- FOOTER -->
    <Border Grid.Row="2" Grid.ColumnSpan="2" Background="#121A2B" BorderBrush="#2A3550" BorderThickness="0,1,0,0">
      <TextBlock Text="Ctrl+Shift+S  —  Exit without launch"
                 Foreground="#9AA6BE" FontSize="14"
                 HorizontalAlignment="Center" VerticalAlignment="Center"/>
    </Border>

    <!-- SETTING-UP OVERLAY -->
    <Border Grid.Row="0" Grid.RowSpan="3" Grid.ColumnSpan="2" x:Name="SettingUpOverlay"
            Background="#121A2B" Panel.ZIndex="100" Visibility="Collapsed">
      <Border.Triggers>
        <EventTrigger RoutedEvent="FrameworkElement.Loaded">
          <BeginStoryboard>
            <Storyboard RepeatBehavior="Forever" AutoReverse="True">
              <DoubleAnimation Storyboard.TargetName="SpinDot1" Storyboard.TargetProperty="Opacity" From="1.0" To="0.2" Duration="0:0:0.5" BeginTime="0:0:0.0"/>
              <DoubleAnimation Storyboard.TargetName="SpinDot2" Storyboard.TargetProperty="Opacity" From="1.0" To="0.2" Duration="0:0:0.5" BeginTime="0:0:0.15"/>
              <DoubleAnimation Storyboard.TargetName="SpinDot3" Storyboard.TargetProperty="Opacity" From="1.0" To="0.2" Duration="0:0:0.5" BeginTime="0:0:0.3"/>
            </Storyboard>
          </BeginStoryboard>
        </EventTrigger>
      </Border.Triggers>
      <StackPanel HorizontalAlignment="Center" VerticalAlignment="Center">
        <StackPanel Orientation="Horizontal" HorizontalAlignment="Center" Margin="0,0,0,30">
          <Ellipse x:Name="SpinDot1" Width="12" Height="12" Fill="#8FA9D6" Margin="7,0"/>
          <Ellipse x:Name="SpinDot2" Width="12" Height="12" Fill="#8FA9D6" Margin="7,0"/>
          <Ellipse x:Name="SpinDot3" Width="12" Height="12" Fill="#8FA9D6" Margin="7,0"/>
        </StackPanel>
        <TextBlock x:Name="SetupStatusText" Text="Starting services..."
                   Foreground="#E8EDF6" FontSize="32" FontWeight="SemiBold"
                   HorizontalAlignment="Center" Margin="0,0,0,10"/>
        <TextBlock x:Name="SetupStepText" Text=""
                   Foreground="#9AA6BE" FontSize="20" HorizontalAlignment="Center"/>
      </StackPanel>
    </Border>

    <!-- WELCOME OVERLAY -->
    <Border Grid.Row="0" Grid.RowSpan="3" Grid.ColumnSpan="2" x:Name="WelcomeOverlay"
            Background="#121A2B" Panel.ZIndex="200" Visibility="Visible">
      <Border Background="#1A2338" CornerRadius="20" Padding="64,56" Width="820"
              HorizontalAlignment="Center" VerticalAlignment="Center">
        <StackPanel>
          <TextBlock x:Name="WelcomeHeading" Text="Welcome to the Audio-Video Preflight"
                     Foreground="#F08A6C" FontSize="32" FontWeight="Bold"
                     TextWrapping="Wrap" TextAlignment="Center" Margin="0,0,0,10"/>
          <TextBlock Text="This wizard checks and starts everything needed for the meeting — Zoom, OBS, and Meeting Media Manager — step by step."
                     Foreground="#9AA6BE" FontSize="20" TextWrapping="Wrap" TextAlignment="Center" Margin="0,0,0,34"/>
          <StackPanel Orientation="Horizontal" Margin="0,0,0,20">
            <Border Background="#22304D" CornerRadius="18" Width="36" Height="36" Margin="0,0,18,0">
              <TextBlock Text="1" Foreground="#8FA9D6" FontSize="18" FontWeight="Bold" HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <TextBlock Text="Answer each question with Yes. Tap Show me how for a demo video if needed."
                       Foreground="#E8EDF6" FontSize="18" TextWrapping="Wrap" VerticalAlignment="Center" Width="620"/>
          </StackPanel>
          <StackPanel Orientation="Horizontal" Margin="0,0,0,20">
            <Border Background="#22304D" CornerRadius="18" Width="36" Height="36" Margin="0,0,18,0">
              <TextBlock Text="2" Foreground="#8FA9D6" FontSize="18" FontWeight="Bold" HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <TextBlock Text="For Equipment Check, follow the reference photo on the right of each question."
                       Foreground="#E8EDF6" FontSize="18" TextWrapping="Wrap" VerticalAlignment="Center" Width="620"/>
          </StackPanel>
          <StackPanel Orientation="Horizontal" Margin="0,0,0,20">
            <Border Background="#22304D" CornerRadius="18" Width="36" Height="36" Margin="0,0,18,0">
              <TextBlock Text="3" Foreground="#8FA9D6" FontSize="18" FontWeight="Bold" HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <TextBlock Text="Detection checks your hardware automatically. Anything not ready shows a red indicator with instructions."
                       Foreground="#E8EDF6" FontSize="18" TextWrapping="Wrap" VerticalAlignment="Center" Width="620"/>
          </StackPanel>
          <StackPanel Orientation="Horizontal" Margin="0,0,0,34">
            <Border Background="#22304D" CornerRadius="18" Width="36" Height="36" Margin="0,0,18,0">
              <TextBlock Text="4" Foreground="#8FA9D6" FontSize="18" FontWeight="Bold" HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <TextBlock Text="Once ready, choose Midweek or Weekend and press Launch. All programs open and position themselves automatically."
                       Foreground="#E8EDF6" FontSize="18" TextWrapping="Wrap" VerticalAlignment="Center" Width="620"/>
          </StackPanel>
          <TextBlock Text="Tip: Ctrl+Shift+S exits the wizard at any time without launching anything."
                     Foreground="#9AA6BE" FontSize="16" TextAlignment="Center" Margin="0,0,0,30"/>
          <Button x:Name="BtnWelcomeStart" Content="Got it — let's start"
                  Style="{StaticResource BtnYes}" HorizontalAlignment="Center"/>
        </StackPanel>
      </Border>
    </Border>

    <!-- CONFIRM-ACTION OVERLAY -->
    <Border Grid.Row="0" Grid.RowSpan="3" Grid.ColumnSpan="2" x:Name="ConfirmActionOverlay"
            Background="#121A2B" Panel.ZIndex="180" Visibility="Collapsed">
      <Border Background="#1A2338" BorderBrush="#2A3550" BorderThickness="1" CornerRadius="16"
              Padding="52,46" Width="680" HorizontalAlignment="Center" VerticalAlignment="Center">
        <StackPanel>
          <TextBlock x:Name="ConfirmActionHeader"
                     Foreground="#E8EDF6" FontSize="26" FontWeight="SemiBold"
                     TextWrapping="Wrap" Margin="0,0,0,20"/>
          <StackPanel x:Name="ConfirmActionBullets" Margin="0,0,0,34"/>
          <StackPanel Orientation="Horizontal">
            <Button x:Name="BtnConfirmActionYes" Content="&#10003;   Yes, continue"
                    Style="{StaticResource BtnYes}" Margin="0,0,14,0"/>
            <Button x:Name="BtnConfirmActionBack" Content="&#8592;   Go back"
                    Style="{StaticResource BtnShowHow}"/>
          </StackPanel>
        </StackPanel>
      </Border>
    </Border>

    <!-- INITIAL SETUP OVERLAY (first run only) -->
    <Border Grid.Row="0" Grid.RowSpan="3" Grid.ColumnSpan="2" x:Name="SetupOverlay"
            Background="#121A2B" Panel.ZIndex="215" Visibility="Collapsed">
      <ScrollViewer VerticalScrollBarVisibility="Auto" HorizontalAlignment="Center" VerticalAlignment="Center">
        <Border Background="#1A2338" CornerRadius="20" Padding="60,50" Width="820" Margin="0,30">
          <StackPanel>
            <TextBlock Text="Let's set up this laptop"
                       Foreground="#E8EDF6" FontSize="32" FontWeight="SemiBold" TextAlignment="Center" Margin="0,0,0,8"/>
            <TextBlock Text="Just a few questions — you can change any of this later from Settings."
                       Foreground="#9AA6BE" FontSize="18" TextWrapping="Wrap" TextAlignment="Center" Margin="0,0,0,34"/>

            <TextBlock Text="Congregation name" Foreground="#E8EDF6" FontSize="16" FontWeight="SemiBold" Margin="0,0,0,8"/>
            <TextBox x:Name="SetupCongregationName" Style="{StaticResource SettingsTextBox}" Margin="0,0,0,28"/>

            <Grid Margin="0,0,0,24">
              <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
              <StackPanel Grid.Column="0" Margin="0,0,24,0">
                <TextBlock Text="Do you host Zoom on this laptop?" Foreground="#E8EDF6" FontSize="16" FontWeight="SemiBold" TextWrapping="Wrap"/>
                <TextBlock Text="Turn this on if this laptop is always the Zoom host, so the wizard can skip the Host/Join choice." Foreground="#9AA6BE" FontSize="14" TextWrapping="Wrap" Margin="0,4,0,0"/>
              </StackPanel>
              <CheckBox x:Name="SetupZoomHosting" Grid.Column="1" Style="{StaticResource ToggleSwitchStyle}" VerticalAlignment="Center"/>
            </Grid>

            <Grid Margin="0,0,0,14">
              <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
              <StackPanel Grid.Column="0" Margin="0,0,24,0">
                <TextBlock Text="Different OBS scenes for Midweek and Weekend?" Foreground="#E8EDF6" FontSize="16" FontWeight="SemiBold" TextWrapping="Wrap"/>
                <TextBlock Text="Turn this on if your OBS scene collection has separate scenes for each meeting type." Foreground="#9AA6BE" FontSize="14" TextWrapping="Wrap" Margin="0,4,0,0"/>
              </StackPanel>
              <CheckBox x:Name="SetupObsScenes" Grid.Column="1" Style="{StaticResource ToggleSwitchStyle}" VerticalAlignment="Center"/>
            </Grid>
            <StackPanel x:Name="SetupObsSceneNamesPanel" Visibility="Collapsed" Margin="0,10,0,24">
              <TextBlock Text="Weekend scene name" Foreground="#E8EDF6" FontSize="15" Margin="0,0,0,6"/>
              <TextBox x:Name="SetupObsSceneWeekend" Style="{StaticResource SettingsTextBox}" Margin="0,0,0,14"/>
              <TextBlock Text="Midweek scene name" Foreground="#E8EDF6" FontSize="15" Margin="0,0,0,6"/>
              <TextBox x:Name="SetupObsSceneMidweek" Style="{StaticResource SettingsTextBox}"/>
            </StackPanel>

            <Button x:Name="BtnSetupFinish" Content="Finish setup"
                    Style="{StaticResource BtnYes}" HorizontalAlignment="Center"/>
          </StackPanel>
        </Border>
      </ScrollViewer>
    </Border>

    <!-- SETTINGS (side menu + sections, like the Steward desktop settings window) -->
    <Border Grid.Row="0" Grid.RowSpan="3" Grid.ColumnSpan="2" x:Name="SettingsOverlay"
            Background="#121A2B" Panel.ZIndex="210" Visibility="Collapsed">
      <Grid>
        <Grid.ColumnDefinitions>
          <ColumnDefinition Width="260"/>
          <ColumnDefinition Width="*"/>
        </Grid.ColumnDefinitions>

        <!-- Side menu -->
        <Border Grid.Column="0" Background="#121A2B" BorderBrush="#2A3550" BorderThickness="0,0,1,0">
          <StackPanel Margin="20,32,20,0">
            <TextBlock Text="Settings" Foreground="#E8EDF6" FontSize="22" FontWeight="Black" Margin="16,0,0,4"/>
            <TextBlock x:Name="SettingsVersionText" Text="" Foreground="#9AA6BE" FontSize="12" Margin="16,0,0,28"/>
            <RadioButton x:Name="NavGeneral"  GroupName="SettingsNav" Content="General"       Style="{StaticResource NavItem}"/>
            <RadioButton x:Name="NavLayout"   GroupName="SettingsNav" Content="Window layout" Style="{StaticResource NavItem}"/>
            <RadioButton x:Name="NavUpdates"  GroupName="SettingsNav" Content="Updates"       Style="{StaticResource NavItem}"/>
            <RadioButton x:Name="NavAdvanced" GroupName="SettingsNav" Content="Advanced"      Style="{StaticResource NavItem}"/>
          </StackPanel>
        </Border>

        <Grid Grid.Column="1">
          <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
          </Grid.RowDefinitions>

          <!-- Section title -->
          <Grid Grid.Row="0" Margin="48,32,48,20">
            <StackPanel>
              <TextBlock x:Name="SettingsSectionTitle" Text="General" Foreground="#F08A6C" FontSize="28" FontWeight="Bold"/>
              <TextBlock x:Name="SettingsSectionHint" Text="" Foreground="#9AA6BE" FontSize="16" TextWrapping="Wrap" Margin="0,4,0,0"/>
            </StackPanel>
            <Button x:Name="BtnSettingsClose" Content="&#10005;" Style="{StaticResource BtnClose}"
                    HorizontalAlignment="Right" VerticalAlignment="Top" ToolTip="Close settings"/>
          </Grid>

          <ScrollViewer Grid.Row="1" Padding="48,0,48,24" VerticalScrollBarVisibility="Auto">
            <StackPanel>

              <!-- GENERAL -->
              <StackPanel x:Name="SettingsSimplePanel" MaxWidth="820" HorizontalAlignment="Left">
                <Border Background="#1A2338" CornerRadius="14" Padding="24,20" Margin="0,0,0,16">
                  <StackPanel>
                    <TextBlock Text="This congregation" Foreground="#E8EDF6" FontSize="16" FontWeight="Bold" Margin="0,0,0,12"/>
                    <TextBlock Text="Congregation name" Foreground="#9AA6BE" FontSize="14" Margin="0,0,0,6"/>
                    <TextBox x:Name="SetCongregationName" Style="{StaticResource SettingsTextBox}"/>
                  </StackPanel>
                </Border>

                <Border Background="#1A2338" CornerRadius="14" Padding="24,12" Margin="0,0,0,16">
                  <Grid MinHeight="64">
                    <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                    <StackPanel VerticalAlignment="Center" Margin="0,0,24,0">
                      <TextBlock Text="Start Preflight when Windows starts" Foreground="#E8EDF6" FontSize="16"/>
                      <TextBlock Text="Opens Preflight as soon as someone signs in to this laptop" Foreground="#9AA6BE" FontSize="13" TextWrapping="Wrap"/>
                    </StackPanel>
                    <CheckBox x:Name="SetStartWithWindows" Grid.Column="1" Style="{StaticResource ToggleSwitchStyle}" VerticalAlignment="Center"
                              AutomationProperties.Name="Start Preflight when Windows starts"/>
                  </Grid>
                </Border>

                <Border Background="#1A2338" CornerRadius="14" Padding="24,12">
                  <StackPanel>
                    <TextBlock Text="Meeting" Foreground="#E8EDF6" FontSize="16" FontWeight="Bold" Margin="0,8,0,4"/>
                    <Grid MinHeight="64">
                      <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                      <StackPanel VerticalAlignment="Center" Margin="0,0,24,0">
                        <TextBlock Text="This laptop hosts Zoom" Foreground="#E8EDF6" FontSize="16"/>
                        <TextBlock Text="Skips the Host or Join question at the start" Foreground="#9AA6BE" FontSize="13" TextWrapping="Wrap"/>
                      </StackPanel>
                      <CheckBox x:Name="SetZoomHosting" Grid.Column="1" Style="{StaticResource ToggleSwitchStyle}" VerticalAlignment="Center"
                                AutomationProperties.Name="This laptop hosts Zoom"/>
                    </Grid>
                    <Border Height="1" Background="#2A3550"/>
                    <Grid MinHeight="64">
                      <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                      <StackPanel VerticalAlignment="Center" Margin="0,0,24,0">
                        <TextBlock Text="Separate OBS scenes for Midweek and Weekend" Foreground="#E8EDF6" FontSize="16" TextWrapping="Wrap"/>
                        <TextBlock Text="Turn on if your scene collection has one scene for each meeting" Foreground="#9AA6BE" FontSize="13" TextWrapping="Wrap"/>
                      </StackPanel>
                      <CheckBox x:Name="SetObsScenes" Grid.Column="1" Style="{StaticResource ToggleSwitchStyle}" VerticalAlignment="Center"
                                AutomationProperties.Name="Separate OBS scenes for Midweek and Weekend"/>
                    </Grid>
                    <StackPanel x:Name="SetObsSceneNamesPanel" Visibility="Collapsed" Margin="0,4,0,16">
                      <TextBlock Text="Weekend scene name" Foreground="#9AA6BE" FontSize="14" Margin="0,0,0,6"/>
                      <TextBox x:Name="SetObsSceneWeekend" Style="{StaticResource SettingsTextBox}" Margin="0,0,0,14"/>
                      <TextBlock Text="Midweek scene name" Foreground="#9AA6BE" FontSize="14" Margin="0,0,0,6"/>
                      <TextBox x:Name="SetObsSceneMidweek" Style="{StaticResource SettingsTextBox}"/>
                    </StackPanel>
                  </StackPanel>
                </Border>
              </StackPanel>

              <!-- WINDOW LAYOUT -->
              <Grid x:Name="SettingsLayoutPanel" Visibility="Collapsed">
                <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
                <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="24"/><ColumnDefinition Width="340"/></Grid.ColumnDefinitions>

                <!-- Toolbar -->
                <StackPanel Grid.Row="0" Grid.ColumnSpan="3" Orientation="Horizontal" Margin="0,0,0,16">
                  <Border Background="#1A2338" CornerRadius="999" Padding="16,0,6,0" Margin="0,0,12,0">
                    <StackPanel Orientation="Horizontal">
                      <TextBlock Text="Snap" Foreground="#E8EDF6" FontSize="14" FontWeight="Medium" VerticalAlignment="Center" Margin="0,0,4,0"/>
                      <CheckBox x:Name="LayoutSnap" Style="{StaticResource ToggleSwitchStyle}" IsChecked="True"
                                AutomationProperties.Name="Snap to screen edges and other windows"
                                ToolTip="Snap to the screen edges and to other windows. Hold Shift while dragging to place freely."/>
                    </StackPanel>
                  </Border>
                  <Button x:Name="BtnCapturePositions" Content="Copy from open windows" Style="{StaticResource BtnGear}" Margin="0,0,12,0"
                          ToolTip="Read where OBS, Zoom and M3 are on screen right now"/>
                  <Button x:Name="BtnLayoutTryNow" Content="Try it now" Style="{StaticResource BtnGear}" Margin="0,0,12,0"
                          ToolTip="Move the open windows to this layout, without saving"/>
                  <Button x:Name="BtnLayoutResetMode" Content="Reset to defaults" Style="{StaticResource BtnBack}"/>
                </StackPanel>

                <!-- Screen -->
                <Border Grid.Row="1" Grid.Column="0" Background="#0B1120" CornerRadius="14" Padding="14" BorderBrush="#2A3550" BorderThickness="1"
                        VerticalAlignment="Top">
                  <Viewbox Stretch="Uniform">
                    <Canvas x:Name="LayoutCanvas" Width="1920" Height="1080" Background="#121A2B" ClipToBounds="True"/>
                  </Viewbox>
                </Border>

                <!-- Inspector -->
                <Border Grid.Row="1" Grid.Column="2" Background="#1A2338" CornerRadius="14" Padding="24,20" VerticalAlignment="Top">
                  <StackPanel>
                    <TextBlock Text="Selected window" Foreground="#9AA6BE" FontSize="13"/>
                    <TextBlock x:Name="LayoutSelName" Text="Pick a window" Foreground="#E8EDF6" FontSize="22" FontWeight="Bold" Margin="0,0,0,16"/>

                    <Grid x:Name="LayoutFieldsGrid" Margin="0,0,0,16">
                      <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="12"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
                      <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="12"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
                      <TextBlock Grid.Row="0" Grid.Column="0" Text="Left (X)" Foreground="#9AA6BE" FontSize="13" Margin="0,0,0,4"/>
                      <TextBox  Grid.Row="1" Grid.Column="0" x:Name="LayoutX" Style="{StaticResource LayoutPillTextBox}" AutomationProperties.Name="Left position in pixels"/>
                      <TextBlock Grid.Row="0" Grid.Column="2" Text="Top (Y)" Foreground="#9AA6BE" FontSize="13" Margin="0,0,0,4"/>
                      <TextBox  Grid.Row="1" Grid.Column="2" x:Name="LayoutY" Style="{StaticResource LayoutPillTextBox}" AutomationProperties.Name="Top position in pixels"/>
                      <TextBlock Grid.Row="3" Grid.Column="0" Text="Width" Foreground="#9AA6BE" FontSize="13" Margin="0,0,0,4"/>
                      <TextBox  Grid.Row="4" Grid.Column="0" x:Name="LayoutW" Style="{StaticResource LayoutPillTextBox}" AutomationProperties.Name="Width in pixels"/>
                      <TextBlock Grid.Row="3" Grid.Column="2" Text="Height" Foreground="#9AA6BE" FontSize="13" Margin="0,0,0,4"/>
                      <TextBox  Grid.Row="4" Grid.Column="2" x:Name="LayoutH" Style="{StaticResource LayoutPillTextBox}" AutomationProperties.Name="Height in pixels"/>
                    </Grid>

                    <TextBlock Text="Quick place" Foreground="#9AA6BE" FontSize="13" Margin="0,0,0,6"/>
                    <UniformGrid Columns="2" Margin="0,0,0,16">
                      <Button x:Name="BtnLayoutPresetTileLeft"   Content="Left half"   Style="{StaticResource BtnGear}" Margin="0,0,6,8"/>
                      <Button x:Name="BtnLayoutPresetTileRight"  Content="Right half"  Style="{StaticResource BtnGear}" Margin="6,0,0,8"/>
                      <Button x:Name="BtnLayoutPresetCenter"     Content="Centre"      Style="{StaticResource BtnGear}" Margin="0,0,6,0"/>
                      <Button x:Name="BtnLayoutPresetFullscreen" Content="Full screen" Style="{StaticResource BtnGear}" Margin="6,0,0,0"/>
                    </UniformGrid>

                    <Border Height="1" Background="#2A3550" Margin="0,0,0,16"/>

                    <TextBlock Text="Opening order" Foreground="#9AA6BE" FontSize="13" Margin="0,0,0,6"/>
                    <Grid Margin="0,0,0,16">
                      <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                      <TextBlock x:Name="LayoutOrderText" Text="" Foreground="#E8EDF6" FontSize="16" VerticalAlignment="Center"/>
                      <Button x:Name="BtnLayoutEarlier" Grid.Column="1" Content="&#9650;" Style="{StaticResource LayoutOrderBtn}" Margin="0,0,8,0"
                              ToolTip="Open earlier" AutomationProperties.Name="Open earlier"/>
                      <Button x:Name="BtnLayoutLater"   Grid.Column="2" Content="&#9660;" Style="{StaticResource LayoutOrderBtn}"
                              ToolTip="Open later" AutomationProperties.Name="Open later"/>
                    </Grid>

                    <TextBlock Text="Wait after opening (milliseconds)" Foreground="#9AA6BE" FontSize="13" Margin="0,0,0,6"/>
                    <TextBox x:Name="LayoutDelay" Style="{StaticResource LayoutPillTextBox}" AutomationProperties.Name="Wait after opening, in milliseconds"/>
                  </StackPanel>
                </Border>

                <TextBlock Grid.Row="2" Grid.ColumnSpan="3" x:Name="LayoutToolsStatus" Text="" Foreground="#9AA6BE" FontSize="14"
                           TextWrapping="Wrap" Margin="0,14,0,0"/>
              </Grid>

              <!-- UPDATES -->
              <StackPanel x:Name="SettingsUpdatesPanel" Visibility="Collapsed" MaxWidth="820" HorizontalAlignment="Left">
                <Border Background="#1A2338" CornerRadius="14" Padding="24,20" Margin="0,0,0,16">
                  <Grid>
                    <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                    <StackPanel VerticalAlignment="Center" Margin="0,0,24,0">
                      <TextBlock x:Name="UpdVersionText" Text="" Foreground="#E8EDF6" FontSize="20" FontWeight="Bold"/>
                      <TextBlock x:Name="UpdStatusText" Text="" Foreground="#9AA6BE" FontSize="14" TextWrapping="Wrap" Margin="0,4,0,0"/>
                    </StackPanel>
                    <Button x:Name="BtnUpdCheckNow" Grid.Column="1" Content="Check now" Style="{StaticResource BtnYes}" VerticalAlignment="Center"/>
                  </Grid>
                </Border>
                <Border Background="#1A2338" CornerRadius="14" Padding="24,12">
                  <StackPanel>
                    <Grid MinHeight="64">
                      <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                      <StackPanel VerticalAlignment="Center" Margin="0,0,24,0">
                        <TextBlock Text="Check for updates when Preflight starts" Foreground="#E8EDF6" FontSize="16"/>
                        <TextBlock Text="New versions install by themselves, then Preflight restarts" Foreground="#9AA6BE" FontSize="13" TextWrapping="Wrap"/>
                      </StackPanel>
                      <CheckBox x:Name="SetAutoUpdate" Grid.Column="1" Style="{StaticResource ToggleSwitchStyle}" VerticalAlignment="Center"
                                AutomationProperties.Name="Check for updates when Preflight starts"/>
                    </Grid>
                    <Border Height="1" Background="#2A3550"/>
                    <StackPanel Margin="0,14,0,12">
                      <TextBlock Text="Updates come from this GitHub repository" Foreground="#E8EDF6" FontSize="16"/>
                      <TextBlock Text="Written as owner/name" Foreground="#9AA6BE" FontSize="13" Margin="0,0,0,8"/>
                      <TextBox x:Name="SetUpdateRepo" Style="{StaticResource SettingsTextBox}"/>
                    </StackPanel>
                  </StackPanel>
                </Border>
              </StackPanel>

              <!-- ADVANCED (rows built from the preference file) -->
              <Border x:Name="SettingsAdvancedCard" Visibility="Collapsed" Background="#1A2338" CornerRadius="14" Padding="24,8"
                      MaxWidth="820" HorizontalAlignment="Left">
                <StackPanel x:Name="SettingsAdvancedPanel"/>
              </Border>

            </StackPanel>
          </ScrollViewer>

          <!-- Footer actions -->
          <Border Grid.Row="2" BorderBrush="#2A3550" BorderThickness="0,1,0,0" Padding="48,16">
            <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
              <Button x:Name="BtnSettingsCancel" Content="Cancel" Style="{StaticResource BtnShowHow}" Margin="0,0,16,0"/>
              <Button x:Name="BtnSettingsSave" Content="Save" Style="{StaticResource BtnYes}"/>
            </StackPanel>
          </Border>
        </Grid>
      </Grid>
    </Border>

    <!-- RESTART OVERLAY -->
    <Border Grid.Row="0" Grid.RowSpan="3" Grid.ColumnSpan="2" x:Name="RestartOverlay"
            Background="#121A2B" Panel.ZIndex="220" Visibility="Collapsed">
      <Border Background="#1A2338" CornerRadius="20" Padding="60,50" Width="620"
              HorizontalAlignment="Center" VerticalAlignment="Center">
        <StackPanel>
          <TextBlock Text="Settings saved" Foreground="#E8EDF6" FontSize="28" FontWeight="Bold" TextAlignment="Center" Margin="0,0,0,10"/>
          <TextBlock Text="Restart Preflight now so the new settings take effect."
                     Foreground="#9AA6BE" FontSize="18" TextAlignment="Center" TextWrapping="Wrap" Margin="0,0,0,30"/>
          <Button x:Name="BtnRestartNow" Content="Restart now" Style="{StaticResource BtnYes}" HorizontalAlignment="Center" Margin="0,0,0,18"/>
          <Button x:Name="BtnRestartLater" Content="I'll restart later" Style="{StaticResource BtnBack}" HorizontalAlignment="Center"/>
        </StackPanel>
      </Border>
    </Border>


    <!-- UPDATE CHECK (shown first, before the welcome page) -->
    <Border Grid.Row="0" Grid.RowSpan="3" Grid.ColumnSpan="2" x:Name="UpdateOverlay"
            Background="#121A2B" Panel.ZIndex="250" Visibility="Visible">
      <StackPanel HorizontalAlignment="Center" VerticalAlignment="Center" Width="560">
        <!-- st-wait: two slow rings spread out from the art circle -->
        <Grid Width="200" Height="200" HorizontalAlignment="Center" Margin="0,0,0,32">
          <Ellipse x:Name="UpdRing1" Width="120" Height="120" Stroke="#8FA9D6" StrokeThickness="2" Opacity="0" RenderTransformOrigin="0.5,0.5">
            <Ellipse.RenderTransform><ScaleTransform/></Ellipse.RenderTransform>
          </Ellipse>
          <Ellipse x:Name="UpdRing2" Width="120" Height="120" Stroke="#8FA9D6" StrokeThickness="2" Opacity="0" RenderTransformOrigin="0.5,0.5">
            <Ellipse.RenderTransform><ScaleTransform/></Ellipse.RenderTransform>
          </Ellipse>
          <!-- Original art: a sound-desk fader in the "sound, media" duotone -->
          <Ellipse Width="120" Height="120" Fill="#4A1410"/>
          <Canvas Width="120" Height="120">
            <Rectangle Canvas.Left="34" Canvas.Top="30" Width="6" Height="60" RadiusX="3" RadiusY="3" Fill="#D2502F"/>
            <Rectangle Canvas.Left="57" Canvas.Top="30" Width="6" Height="60" RadiusX="3" RadiusY="3" Fill="#D2502F"/>
            <Rectangle Canvas.Left="80" Canvas.Top="30" Width="6" Height="60" RadiusX="3" RadiusY="3" Fill="#D2502F"/>
            <Rectangle Canvas.Left="27" Canvas.Top="62" Width="20" Height="10" RadiusX="3" RadiusY="3" Fill="#F7C9B0"/>
            <Rectangle Canvas.Left="50" Canvas.Top="40" Width="20" Height="10" RadiusX="3" RadiusY="3" Fill="#F7C9B0"/>
            <Rectangle Canvas.Left="73" Canvas.Top="54" Width="20" Height="10" RadiusX="3" RadiusY="3" Fill="#F7C9B0"/>
          </Canvas>
        </Grid>
        <TextBlock x:Name="UpdTitle" Text="Checking for updates" Foreground="#E8EDF6" FontSize="28" FontWeight="Bold"
                   TextAlignment="Center" Margin="0,0,0,8"/>
        <TextBlock x:Name="UpdDetail" Text="This takes a few seconds." Foreground="#9AA6BE" FontSize="16"
                   TextAlignment="Center" TextWrapping="Wrap" Margin="0,0,0,24"/>
        <!-- st-progress -->
        <Border x:Name="UpdProgressTrack" Height="8" CornerRadius="4" Background="#2A3550" Margin="40,0,40,24" Visibility="Hidden">
          <Border x:Name="UpdProgressFill" HorizontalAlignment="Left" Width="0" CornerRadius="4" Background="#8FA9D6"/>
        </Border>
        <Button x:Name="BtnUpdSkip" Content="Skip for now" Style="{StaticResource BtnBack}" HorizontalAlignment="Center"/>
      </StackPanel>
    </Border>

  </Grid>
</Window>
'@

# =============================================================================
#  LOAD WINDOW
# =============================================================================
try {
    $Script:window = [Windows.Markup.XamlReader]::Parse($xaml)
} catch {
    Write-Log "XAML parse failed: $($_.Exception.Message)" "ERROR"
    # A version that was just installed and can't even draw its window goes
    # straight back to the one before it.
    if ($JustUpdated -and (Restore-PreviousVersion)) { Restart-Preflight; exit 1 }
    [System.Windows.Forms.MessageBox]::Show(
        "UI failed to load.`n`nError: $($_.Exception.Message)`n`nLog: $Script:LogFile",
        "$($Script:Config.CongregationName) Audio-Video Preflight", 'OK', 'Error') | Out-Null
    exit 1
}

$wa = [System.Windows.SystemParameters]::WorkArea
$Script:window.Left   = $wa.Left;  $Script:window.Top    = $wa.Top
$Script:window.Width  = $wa.Width; $Script:window.Height = $wa.Height

# =============================================================================
#  CONTROL REFERENCES
# =============================================================================
$Script:clockText            = $Script:window.FindName("ClockText")
$Script:meetingTypeBadge     = $Script:window.FindName("MeetingTypeBadge")
$Script:meetingTypeBadgeText = $Script:window.FindName("MeetingTypeBadgeText")
$Script:testModeBanner       = $Script:window.FindName("TestModeBanner")
$Script:subwayTrack          = $Script:window.FindName("SubwayTrack")
$Script:detSubwayTrack       = $Script:window.FindName("DetSubwayTrack")
$Script:headerTitle          = $Script:window.FindName("HeaderTitle")
$Script:btnStartOver         = $Script:window.FindName("BtnStartOver")
$Script:welcomeHeading       = $Script:window.FindName("WelcomeHeading")
$Script:window.Title         = "$($Script:Config.CongregationName) Audio-Video Preflight"
$Script:headerTitle.Text     = "$($Script:Config.CongregationName) Audio-Video Preflight"
$Script:welcomeHeading.Text  = "Welcome to the $($Script:Config.CongregationName) Audio-Video Preflight"

$Script:screenQuestion       = $Script:window.FindName("ScreenQuestion")
$Script:screenBluetoothSetup = $Script:window.FindName("ScreenBluetoothSetup")
$Script:btSubQ1Panel         = $Script:window.FindName("BtSubQ1Panel")
$Script:btSubQ2Panel         = $Script:window.FindName("BtSubQ2Panel")
$Script:btMixerPhotoImage    = $Script:window.FindName("BtMixerPhotoImage")
$Script:btnBtSubQ1Yes        = $Script:window.FindName("BtnBtSubQ1Yes")
$Script:btDeviceNameRun      = $Script:window.FindName("BtDeviceNameRun")
$Script:btCheckStatusText    = $Script:window.FindName("BtCheckStatusText")
$Script:btnBluetoothCheck    = $Script:window.FindName("BtnBluetoothCheck")
$Script:btnBtNotConnected    = $Script:window.FindName("BtnBtNotConnected")
$Script:btInstructionsPanel  = $Script:window.FindName("BtInstructionsPanel")
$Script:btnBtSkip            = $Script:window.FindName("BtnBtSkip")
$Script:btnBtTryAgain        = $Script:window.FindName("BtnBtTryAgain")
$Script:btRestartingPanel    = $Script:window.FindName("BtRestartingPanel")
$Script:btSettingsAnchor     = $Script:window.FindName("BtSettingsAnchor")
$Script:screenEmeetSetup     = $Script:window.FindName("ScreenEmeetSetup")
$Script:emeetVcamStatusText  = $Script:window.FindName("EmeetVcamStatusText")
$Script:btnEmeetEnable       = $Script:window.FindName("BtnEmeetEnable")
$Script:screenVideo          = $Script:window.FindName("ScreenVideo")
$Script:screenConfirm        = $Script:window.FindName("ScreenConfirm")
$Script:screenDetection      = $Script:window.FindName("ScreenDetection")
$Script:screenUseCase        = $Script:window.FindName("ScreenUseCase")
$Script:btnUseCaseRegular    = $Script:window.FindName("BtnUseCaseRegular")
$Script:btnUseCaseNonZoom    = $Script:window.FindName("BtnUseCaseNonZoom")
$Script:screenZoomChoice     = $Script:window.FindName("ScreenZoomChoice")
$Script:btnZoomModeHost      = $Script:window.FindName("BtnZoomModeHost")
$Script:btnZoomModeJoin      = $Script:window.FindName("BtnZoomModeJoin")
$Script:screenProgramChoice  = $Script:window.FindName("ScreenProgramChoice")
$Script:btnProgramM3         = $Script:window.FindName("BtnProgramM3")
$Script:btnProgramJwLibrary  = $Script:window.FindName("BtnProgramJwLibrary")
$Script:confirmActionOverlay = $Script:window.FindName("ConfirmActionOverlay")
$Script:confirmActionHeader  = $Script:window.FindName("ConfirmActionHeader")
$Script:confirmActionBullets = $Script:window.FindName("ConfirmActionBullets")
$Script:btnConfirmActionYes  = $Script:window.FindName("BtnConfirmActionYes")
$Script:btnConfirmActionBack = $Script:window.FindName("BtnConfirmActionBack")
$Script:screenZoomIntro      = $Script:window.FindName("ScreenZoomIntro")
$Script:zoomIntroHeading     = $Script:window.FindName("ZoomIntroHeading")
$Script:btnOpenZoomIntro     = $Script:window.FindName("BtnOpenZoomIntro")
$Script:btnZoomIntroContinue = $Script:window.FindName("BtnZoomIntroContinue")
$Script:zoomIntroSubtext     = $Script:window.FindName("ZoomIntroSubtext")
$Script:sectionBadgeText     = $Script:window.FindName("SectionBadgeText")
$Script:questionCounter      = $Script:window.FindName("QuestionCounter")
$Script:dotsPanel            = $Script:window.FindName("DotsPanel")
$Script:questionCardZoom     = $Script:window.FindName("QuestionCardZoom")
$Script:questionText         = $Script:window.FindName("QuestionText")
$Script:questionSubtext      = $Script:window.FindName("QuestionSubtext")
$Script:btnYes               = $Script:window.FindName("BtnYes")
$Script:btnShowHow           = $Script:window.FindName("BtnShowHow")
$Script:videoErrorText       = $Script:window.FindName("VideoErrorText")
$Script:questionCardEquip    = $Script:window.FindName("QuestionCardEquipment")
$Script:eqQuestionText       = $Script:window.FindName("EqQuestionText")
$Script:eqQuestionSubtext    = $Script:window.FindName("EqQuestionSubtext")
$Script:btnYesEq             = $Script:window.FindName("BtnYesEq")
$Script:eqPhotoImage         = $Script:window.FindName("EqPhotoImage")
$Script:videoPlayer          = $Script:window.FindName("VideoPlayer")
$Script:btnCloseVideo        = $Script:window.FindName("BtnCloseVideo")
$Script:confirmText          = $Script:window.FindName("ConfirmText")
$Script:btnConfirmYes        = $Script:window.FindName("BtnConfirmYes")
$Script:btnWatchAgain        = $Script:window.FindName("BtnWatchAgain")
$Script:detIconAcPower       = $Script:window.FindName("DetIconAcPower")
$Script:detIconInternet      = $Script:window.FindName("DetIconInternet")
$Script:detIconDisplay       = $Script:window.FindName("DetIconDisplay")
$Script:detIconWebcam        = $Script:window.FindName("DetIconWebcam")
$Script:detIconUsbAudio      = $Script:window.FindName("DetIconUsbAudio")
$Script:detStatusAcPower     = $Script:window.FindName("DetStatusAcPower")
$Script:detStatusInternet    = $Script:window.FindName("DetStatusInternet")
$Script:detStatusDisplay     = $Script:window.FindName("DetStatusDisplay")
$Script:detStatusWebcam      = $Script:window.FindName("DetStatusWebcam")
$Script:detStatusUsbAudio    = $Script:window.FindName("DetStatusUsbAudio")
$Script:detHelpAcPower       = $Script:window.FindName("DetHelpAcPower")
$Script:detHelpInternet      = $Script:window.FindName("DetHelpInternet")
$Script:detHelpDisplay       = $Script:window.FindName("DetHelpDisplay")
$Script:detHelpWebcam        = $Script:window.FindName("DetHelpWebcam")
$Script:detHelpUsbAudio      = $Script:window.FindName("DetHelpUsbAudio")
$Script:detLabelWebcam       = $Script:window.FindName("DetLabelWebcam")
$Script:detCardUsbAudio      = $Script:window.FindName("DetCardUsbAudio")
$Script:btnOpenInternet      = $Script:window.FindName("BtnOpenInternet")
$Script:btnOpenWebcam        = $Script:window.FindName("BtnOpenWebcam")
$Script:detReadyPanel        = $Script:window.FindName("DetReadyPanel")
$Script:radioMidweek         = $Script:window.FindName("RadioMidweek")
$Script:radioWeekend         = $Script:window.FindName("RadioWeekend")
$Script:launchButton         = $Script:window.FindName("LaunchButton")
$Script:btnBackToEquipment   = $Script:window.FindName("BtnBackToEquipment")
$Script:settingUpOverlay     = $Script:window.FindName("SettingUpOverlay")
$Script:setupStatusText      = $Script:window.FindName("SetupStatusText")
$Script:setupStepText        = $Script:window.FindName("SetupStepText")
$Script:welcomeOverlay       = $Script:window.FindName("WelcomeOverlay")
$Script:btnWelcomeStart      = $Script:window.FindName("BtnWelcomeStart")

# Settings / Setup Wizard
$Script:btnSettings          = $Script:window.FindName("BtnSettings")

$Script:setupOverlay              = $Script:window.FindName("SetupOverlay")
$Script:setupCongregationName     = $Script:window.FindName("SetupCongregationName")
$Script:setupZoomHosting          = $Script:window.FindName("SetupZoomHosting")
$Script:setupObsScenes            = $Script:window.FindName("SetupObsScenes")
$Script:setupObsSceneNamesPanel   = $Script:window.FindName("SetupObsSceneNamesPanel")
$Script:setupObsSceneWeekend      = $Script:window.FindName("SetupObsSceneWeekend")
$Script:setupObsSceneMidweek      = $Script:window.FindName("SetupObsSceneMidweek")
$Script:btnSetupFinish            = $Script:window.FindName("BtnSetupFinish")

$Script:settingsOverlay           = $Script:window.FindName("SettingsOverlay")
$Script:btnSettingsClose          = $Script:window.FindName("BtnSettingsClose")
$Script:settingsVersionText       = $Script:window.FindName("SettingsVersionText")
$Script:settingsSectionTitle      = $Script:window.FindName("SettingsSectionTitle")
$Script:settingsSectionHint       = $Script:window.FindName("SettingsSectionHint")
$Script:navGeneral                = $Script:window.FindName("NavGeneral")
$Script:navLayout                 = $Script:window.FindName("NavLayout")
$Script:navUpdates                = $Script:window.FindName("NavUpdates")
$Script:navAdvanced               = $Script:window.FindName("NavAdvanced")
$Script:settingsSimplePanel       = $Script:window.FindName("SettingsSimplePanel")
$Script:setStartWithWindows       = $Script:window.FindName("SetStartWithWindows")
$Script:settingsAdvancedPanel     = $Script:window.FindName("SettingsAdvancedPanel")
$Script:settingsAdvancedCard      = $Script:window.FindName("SettingsAdvancedCard")
$Script:settingsLayoutPanel       = $Script:window.FindName("SettingsLayoutPanel")
$Script:settingsUpdatesPanel      = $Script:window.FindName("SettingsUpdatesPanel")

# Window layout editor
$Script:layoutCanvas              = $Script:window.FindName("LayoutCanvas")
$Script:layoutSnap                = $Script:window.FindName("LayoutSnap")
$Script:layoutSelName             = $Script:window.FindName("LayoutSelName")
$Script:layoutX                   = $Script:window.FindName("LayoutX")
$Script:layoutY                   = $Script:window.FindName("LayoutY")
$Script:layoutW                   = $Script:window.FindName("LayoutW")
$Script:layoutH                   = $Script:window.FindName("LayoutH")
$Script:layoutDelay               = $Script:window.FindName("LayoutDelay")
$Script:layoutOrderText           = $Script:window.FindName("LayoutOrderText")
$Script:btnLayoutEarlier          = $Script:window.FindName("BtnLayoutEarlier")
$Script:btnLayoutLater            = $Script:window.FindName("BtnLayoutLater")
$Script:btnLayoutResetMode        = $Script:window.FindName("BtnLayoutResetMode")
$Script:btnLayoutTryNow           = $Script:window.FindName("BtnLayoutTryNow")
$Script:btnCapturePositions       = $Script:window.FindName("BtnCapturePositions")
$Script:layoutToolsStatus         = $Script:window.FindName("LayoutToolsStatus")
$Script:btnLayoutPresetTileLeft   = $Script:window.FindName("BtnLayoutPresetTileLeft")
$Script:btnLayoutPresetTileRight  = $Script:window.FindName("BtnLayoutPresetTileRight")
$Script:btnLayoutPresetCenter     = $Script:window.FindName("BtnLayoutPresetCenter")
$Script:btnLayoutPresetFullscreen = $Script:window.FindName("BtnLayoutPresetFullscreen")

# Updates
$Script:updVersionText            = $Script:window.FindName("UpdVersionText")
$Script:updStatusText             = $Script:window.FindName("UpdStatusText")
$Script:btnUpdCheckNow            = $Script:window.FindName("BtnUpdCheckNow")
$Script:setAutoUpdate             = $Script:window.FindName("SetAutoUpdate")
$Script:setUpdateRepo             = $Script:window.FindName("SetUpdateRepo")
$Script:updateOverlay             = $Script:window.FindName("UpdateOverlay")
$Script:updTitle                  = $Script:window.FindName("UpdTitle")
$Script:updDetail                 = $Script:window.FindName("UpdDetail")
$Script:updProgressTrack          = $Script:window.FindName("UpdProgressTrack")
$Script:updProgressFill           = $Script:window.FindName("UpdProgressFill")
$Script:updRing1                  = $Script:window.FindName("UpdRing1")
$Script:updRing2                  = $Script:window.FindName("UpdRing2")
$Script:btnUpdSkip                = $Script:window.FindName("BtnUpdSkip")
$Script:headerVersion             = $Script:window.FindName("HeaderVersion")
$Script:headerVersion.Text        = "Version $($Script:AppVersion)"

$Script:setCongregationName       = $Script:window.FindName("SetCongregationName")
$Script:setZoomHosting            = $Script:window.FindName("SetZoomHosting")
$Script:setObsScenes              = $Script:window.FindName("SetObsScenes")
$Script:setObsSceneNamesPanel     = $Script:window.FindName("SetObsSceneNamesPanel")
$Script:setObsSceneWeekend        = $Script:window.FindName("SetObsSceneWeekend")
$Script:setObsSceneMidweek        = $Script:window.FindName("SetObsSceneMidweek")
$Script:btnSettingsCancel         = $Script:window.FindName("BtnSettingsCancel")
$Script:btnSettingsSave           = $Script:window.FindName("BtnSettingsSave")

$Script:restartOverlay            = $Script:window.FindName("RestartOverlay")
$Script:btnRestartNow             = $Script:window.FindName("BtnRestartNow")
$Script:btnRestartLater           = $Script:window.FindName("BtnRestartLater")

# ----- BRUSHES ---------------------------------------------------------------
$bc = [System.Windows.Media.BrushConverter]::new()
$Script:brushGreen       = $bc.ConvertFromString("#5FC08A")
$Script:brushRed         = $bc.ConvertFromString("#FF6B5E")
$Script:brushBlue        = $bc.ConvertFromString("#8FA9D6")
$Script:brushPending     = $bc.ConvertFromString("#2A3550")
$Script:brushPendingIcon = $bc.ConvertFromString("#9AA6BE")

# =============================================================================
#  HELPER / UI FUNCTIONS
# =============================================================================

function Show-ConfirmAction {
    param([string]$Header, [string[]]$Bullets, [scriptblock]$OnConfirm, [scriptblock]$OnCancel)
    $Script:confirmActionHeader.Text = $Header
    $Script:confirmActionBullets.Children.Clear()
    foreach ($b in $Bullets) {
        $tb = New-Object System.Windows.Controls.TextBlock
        $tb.Text         = "  $b"
        $tb.Foreground   = $bc.ConvertFromString("#9AA6BE")
        $tb.FontSize     = 16
        $tb.TextWrapping = 'Wrap'
        $tb.Margin       = [System.Windows.Thickness]::new(0,0,0,8)
        [void]$Script:confirmActionBullets.Children.Add($tb)
    }
    $Script:PendingConfirmYes    = $OnConfirm
    $Script:PendingConfirmCancel = $OnCancel
    $Script:confirmActionOverlay.Visibility = 'Visible'
}

$Script:IconsFolder = Join-Path $Script:MediaFolder "icons"

function Build-DetCards {
    $cards = @(
        @{ Key="Charger";     HwKey="AcPower";  Icon=$Script:detIconAcPower;  Status=$Script:detStatusAcPower;  Help=$Script:detHelpAcPower;  Ok="Connected"; Bad="On battery";    IconFile="icon-ac-power.png"     }
        @{ Key="Internet";    HwKey="Internet"; Icon=$Script:detIconInternet; Status=$Script:detStatusInternet; Help=$Script:detHelpInternet; Ok="Online";    Bad="Not reachable"; IconFile="icon-internet.png"     }
        @{ Key="Display";     HwKey="Display";  Icon=$Script:detIconDisplay;  Status=$Script:detStatusDisplay;  Help=$Script:detHelpDisplay;  Ok="Detected";  Bad="Not found";     IconFile="icon-hdmi-display.png" }
        @{ Key="PTZ Camera";  HwKey="Webcam";   Icon=$Script:detIconWebcam;   Status=$Script:detStatusWebcam;   Help=$Script:detHelpWebcam;   Ok="Ready";     Bad="Not detected";  IconFile="icon-camera.png"       }
    )
    if ($Script:State.Flow -eq "NonZoom") {
        $Script:detCardUsbAudio.Visibility = 'Collapsed'
    } else {
        $Script:detCardUsbAudio.Visibility = 'Visible'
        $cards += @{ Key="USB Audio"; HwKey="UsbAudio"; Icon=$Script:detIconUsbAudio; Status=$Script:detStatusUsbAudio; Help=$Script:detHelpUsbAudio; Ok="Ready"; Bad="Not found"; IconFile="icon-usb-audio.png" }
    }
    $Script:DetCards = $cards
}
$Script:detLabelWebcam.Text = $Script:Config.WebcamName
Build-DetCards

function Show-Screen {
    param([string]$Name)
    $Script:screenUseCase.Visibility       = if ($Name -eq "ScreenUseCase")       { 'Visible' } else { 'Collapsed' }
    $Script:screenZoomChoice.Visibility    = if ($Name -eq "ScreenZoomChoice")    { 'Visible' } else { 'Collapsed' }
    $Script:screenZoomIntro.Visibility     = if ($Name -eq "ScreenZoomIntro")     { 'Visible' } else { 'Collapsed' }
    $Script:screenProgramChoice.Visibility = if ($Name -eq "ScreenProgramChoice") { 'Visible' } else { 'Collapsed' }
    $Script:screenQuestion.Visibility      = if ($Name -eq "ScreenQuestion")      { 'Visible' } else { 'Collapsed' }
    $Script:screenBluetoothSetup.Visibility = if ($Name -eq "ScreenBluetoothSetup") { 'Visible' } else { 'Collapsed' }
    $Script:screenEmeetSetup.Visibility     = if ($Name -eq "ScreenEmeetSetup")     { 'Visible' } else { 'Collapsed' }
    $Script:screenVideo.Visibility         = if ($Name -eq "ScreenVideo")         { 'Visible' } else { 'Collapsed' }
    $Script:screenConfirm.Visibility       = if ($Name -eq "ScreenConfirm")       { 'Visible' } else { 'Collapsed' }
    $Script:screenDetection.Visibility     = if ($Name -eq "ScreenDetection")     { 'Visible' } else { 'Collapsed' }
}

function Update-ProgressDots {
    $sec = $Script:Sections[$Script:State.SectionIdx]
    $Script:dotsPanel.Children.Clear()
    for ($i = 0; $i -lt $sec.Questions.Count; $i++) {
        $dot = New-Object System.Windows.Shapes.Ellipse
        $dot.Width             = 10
        $dot.Height            = 10
        $dot.Margin            = [System.Windows.Thickness]::new(7,0,7,0)
        $dot.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
        $dot.Fill = if     ($i -lt  $Script:State.QuestionIdx) { $Script:brushGreen   }
                    elseif ($i -eq  $Script:State.QuestionIdx) { $Script:brushBlue    }
                    else                                        { $Script:brushPending }
        [void]$Script:dotsPanel.Children.Add($dot)
    }
}

function Set-EquipmentPhoto {
    param([hashtable]$Q)
    $Script:eqPhotoImage.Source = $null
    if (-not $Q.ContainsKey('Photo') -or -not $Q.Photo) { return }
    $path = Join-Path $Script:MediaFolder $Q.Photo
    if (-not (Test-Path $path)) { Write-Log "Equipment photo not found: $path" "WARN"; return }
    try {
        $bmp = [System.Windows.Media.Imaging.BitmapImage]::new()
        $bmp.BeginInit()
        $bmp.UriSource   = [Uri]::new($path)
        $bmp.CacheOption = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
        $bmp.EndInit()
        $Script:eqPhotoImage.Source = $bmp
    } catch { Write-Log "Photo load failed ($($Q.Photo)): $($_.Exception.Message)" "WARN" }
}

function Set-DetectionIcons {
    foreach ($card in $Script:DetCards) {
        $path = Join-Path $Script:IconsFolder $card.IconFile
        if (-not (Test-Path $path)) { Write-Log "Icon not found: $path" "WARN"; continue }
        try {
            $bmp = [System.Windows.Media.Imaging.BitmapImage]::new()
            $bmp.BeginInit()
            $bmp.UriSource   = [Uri]::new($path)
            $bmp.CacheOption = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
            $bmp.EndInit()
            $card.Icon.OpacityMask = [System.Windows.Media.ImageBrush]::new($bmp)
            $card.Icon.Background  = $Script:brushPendingIcon
        } catch { Write-Log "Icon load failed ($($card.IconFile)): $($_.Exception.Message)" "WARN" }
    }
}

function Set-IconTint { param($IconImage, $Brush); $IconImage.Background = $Brush }

function Build-SubwayStop {
    param([string]$LabelText, [string]$State, [string]$Initial)
    $stop = New-Object System.Windows.Controls.StackPanel
    $stop.HorizontalAlignment = 'Center'
    $stop.Margin              = [System.Windows.Thickness]::new(0,0,0,4)

    $node = New-Object System.Windows.Controls.Border
    $node.Width               = 42
    $node.Height              = 42
    $node.CornerRadius        = [System.Windows.CornerRadius]::new(21)
    $node.HorizontalAlignment = 'Center'
    $node.BorderThickness     = [System.Windows.Thickness]::new(2)

    $nodeText = New-Object System.Windows.Controls.TextBlock
    $nodeText.HorizontalAlignment = 'Center'
    $nodeText.VerticalAlignment   = 'Center'
    $nodeText.FontSize            = 18
    $nodeText.FontWeight          = 'Bold'

    switch ($State) {
        'done' {
            $node.Background     = $bc.ConvertFromString("#1B2E36")
            $node.BorderBrush    = $Script:brushGreen
            $nodeText.Text       = [char]0x2713
            $nodeText.Foreground = $Script:brushGreen
        }
        'active' {
            $node.Background     = $bc.ConvertFromString("#22304D")
            $node.BorderBrush    = $Script:brushBlue
            $nodeText.Text       = $Initial
            $nodeText.Foreground = $Script:brushBlue
        }
        default {
            $node.Background     = $bc.ConvertFromString("#22304D")
            $node.BorderBrush    = $bc.ConvertFromString("#2A3550")
            $nodeText.Text       = $Initial
            $nodeText.Foreground = $bc.ConvertFromString("#9AA6BE")
        }
    }
    $node.Child = $nodeText

    $label = New-Object System.Windows.Controls.TextBlock
    $label.Text               = $LabelText
    $label.FontSize           = 11
    $label.FontWeight         = 'SemiBold'
    $label.HorizontalAlignment = 'Center'
    $label.TextAlignment      = 'Center'
    $label.Margin             = [System.Windows.Thickness]::new(2,5,2,0)
    $label.Foreground = switch ($State) {
        'done'   { $Script:brushGreen }
        'active' { $Script:brushBlue  }
        default  { $bc.ConvertFromString("#9AA6BE") }
    }

    [void]$stop.Children.Add($node)
    [void]$stop.Children.Add($label)
    return $stop
}

function Build-SubwayLine {
    param([string]$State)
    $line = New-Object System.Windows.Shapes.Rectangle
    $line.Width               = 2
    $line.Height              = 32
    $line.Margin              = [System.Windows.Thickness]::new(0,4,0,4)
    $line.HorizontalAlignment = 'Center'
    $line.Fill = switch ($State) {
        'done'   { $Script:brushGreen }
        'active' { $Script:brushBlue  }
        default  { $bc.ConvertFromString("#2A3550") }
    }
    return $line
}

function Update-MainSubway {
    $Script:subwayTrack.Children.Clear()
    $labels = @{ zoom = @("ZOOM","Z"); equipment = @("EQUIP","E") }

    for ($i = 0; $i -lt $Script:Sections.Count; $i++) {
        $sec   = $Script:Sections[$i]
        $state = if     ($Script:State.SectionIdx -gt $i -or $Script:screenDetection.Visibility -eq 'Visible' -or $Script:screenEmeetSetup.Visibility -eq 'Visible') { 'done'   }
                 elseif (($Script:screenQuestion.Visibility -eq 'Visible' -or $Script:screenBluetoothSetup.Visibility -eq 'Visible') -and $Script:State.SectionIdx -eq $i)  { 'active' }
                 else                                                                                             { 'pending' }
        $lbl = $labels[$sec.Id]
        if (-not $lbl) { $lbl = @($sec.Name.ToUpper(), $sec.Name.Substring(0,1)) }
        [void]$Script:subwayTrack.Children.Add((Build-SubwayStop $lbl[0] $state $lbl[1]))
        [void]$Script:subwayTrack.Children.Add((Build-SubwayLine (if ($state -eq 'done') {'done'} elseif ($state -eq 'active') {'active'} else {'pending'})))
    }

    $detState = if ($Script:screenDetection.Visibility -eq 'Visible' -and $Script:State.AllHwReady) { 'done'   }
                elseif ($Script:screenDetection.Visibility -eq 'Visible')                            { 'active' }
                else                                                                                  { 'pending' }
    [void]$Script:subwayTrack.Children.Add((Build-SubwayStop "DETECT" $detState "D"))
}

function Update-DetectionSubway {
    $Script:detSubwayTrack.Children.Clear()

    for ($i = 0; $i -lt $Script:DetCards.Count; $i++) {
        $card  = $Script:DetCards[$i]
        $state = if     ($card.Status.Text -eq $card.Ok)                                                    { 'done'    }
                 elseif ($card.Status.Text -eq 'Checking...' -or $card.Status.Text -eq 'Checking...') { 'pending' }
                 else                                                                                        { 'fail'    }

        $row             = New-Object System.Windows.Controls.StackPanel
        $row.Orientation = 'Horizontal'
        $row.Margin      = [System.Windows.Thickness]::new(0,0,0,4)

        # 52x52 icon tile
        $iconBorder                   = New-Object System.Windows.Controls.Border
        $iconBorder.Width             = 52
        $iconBorder.Height            = 52
        $iconBorder.CornerRadius      = [System.Windows.CornerRadius]::new(8)
        $iconBorder.VerticalAlignment = 'Center'
        $iconBorder.Margin            = [System.Windows.Thickness]::new(0,0,12,0)

        $iconPath = Join-Path $Script:IconsFolder $card.IconFile
        if (Test-Path $iconPath) {
            try {
                $bmp = [System.Windows.Media.Imaging.BitmapImage]::new()
                $bmp.BeginInit()
                $bmp.UriSource   = [Uri]::new($iconPath)
                $bmp.CacheOption = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
                $bmp.EndInit()
                $iconBorder.OpacityMask = [System.Windows.Media.ImageBrush]::new($bmp)
            } catch {}
        }
        $iconBorder.Background = switch ($state) {
            'done'   { $Script:brushGreen }
            'fail'   { $Script:brushRed   }
            default  { $Script:brushPendingIcon }
        }

        $labelStack                   = New-Object System.Windows.Controls.StackPanel
        $labelStack.VerticalAlignment = 'Center'

        $lbl          = New-Object System.Windows.Controls.TextBlock
        $lbl.Text     = $card.Key
        $lbl.FontSize = 14
        $lbl.FontWeight = 'SemiBold'
        $lbl.Foreground = switch ($state) {
            'done'   { $Script:brushGreen }
            'fail'   { $bc.ConvertFromString("#FF6B5E") }
            default  { $bc.ConvertFromString("#9AA6BE")  }
        }

        $sub          = New-Object System.Windows.Controls.TextBlock
        $sub.Text     = if ($state -eq 'done') { $card.Ok } elseif ($state -eq 'fail') { $card.Bad } else { "Checking..." }
        $sub.FontSize = 12
        $sub.Foreground = switch ($state) {
            'done'   { $bc.ConvertFromString("#5FC08A") }
            'fail'   { $bc.ConvertFromString("#FF6B5E") }
            default  { $bc.ConvertFromString("#9AA6BE")  }
        }

        [void]$labelStack.Children.Add($lbl)
        [void]$labelStack.Children.Add($sub)
        [void]$row.Children.Add($iconBorder)
        [void]$row.Children.Add($labelStack)
        [void]$Script:detSubwayTrack.Children.Add($row)

        if ($i -lt $Script:DetCards.Count - 1) {
            $line                      = New-Object System.Windows.Shapes.Rectangle
            $line.Width                = 2
            $line.Height               = 18
            $line.Margin               = [System.Windows.Thickness]::new(24,2,0,2)
            $line.HorizontalAlignment  = 'Left'
            $line.Fill = switch ($state) {
                'done'  { $Script:brushGreen }
                'fail'  { $Script:brushRed   }
                default { $bc.ConvertFromString("#2A3550") }
            }
            [void]$Script:detSubwayTrack.Children.Add($line)
        }
    }
}

function Set-MeetingTypeBadge {
    param([string]$Type)
    $Script:meetingTypeBadgeText.Text   = "$Type meeting"
    $Script:meetingTypeBadge.Visibility = 'Visible'
}

function Show-CurrentQuestion {
    $sec = $Script:Sections[$Script:State.SectionIdx]
    $q   = $sec.Questions[$Script:State.QuestionIdx]

    $Script:window.Topmost = ($sec.Id -ne 'zoom')

    $Script:sectionBadgeText.Text = $sec.Name
    $Script:questionCounter.Text  = "  —  $($Script:State.QuestionIdx + 1) of $($sec.Questions.Count)"
    Update-ProgressDots

    $Script:questionCardZoom.Visibility  = 'Collapsed'
    $Script:questionCardEquip.Visibility = 'Collapsed'

    if ($sec.Type -eq 'video') {
        $Script:questionText.Text    = $q.Text
        $Script:questionSubtext.Text = $q.Sub
        $hasVid = $q.ContainsKey('Video') -and $q.Video -and (Test-Path (Join-Path $Script:MediaFolder $q.Video))
        $Script:btnShowHow.Visibility       = if ($hasVid) { 'Visible' } else { 'Collapsed' }
        $Script:questionCardZoom.Visibility = 'Visible'
    } else {
        $Script:eqQuestionText.Text    = $q.Text
        $Script:eqQuestionSubtext.Text = $q.Sub
        Set-EquipmentPhoto $q
        $Script:questionCardEquip.Visibility = 'Visible'
    }

    $Script:videoErrorText.Visibility = 'Collapsed'
    Show-Screen "ScreenQuestion"
    Update-MainSubway
    Write-Log "Showing: [$($sec.Name)] Q$($Script:State.QuestionIdx + 1) -- $($q.Text)"
}

function Advance-Question {
    $sec   = $Script:Sections[$Script:State.SectionIdx]
    $nextQ = $Script:State.QuestionIdx + 1
    if ($nextQ -lt $sec.Questions.Count) {
        $Script:State.QuestionIdx = $nextQ
        Show-CurrentQuestion
    } else {
        $nextSec = $Script:State.SectionIdx + 1
        if ($nextSec -lt $Script:Sections.Count) {
            $Script:State.SectionIdx  = $nextSec
            $Script:State.QuestionIdx = 0
            if ($Script:Sections[$nextSec].Id -eq "equipment") {
                Start-EquipmentSection
            } else {
                Show-CurrentQuestion
            }
        } else {
            Write-Log "All sections complete -- moving to Detection."
            if ($Script:State.Flow -eq "NonZoom") {
                Show-Screen "ScreenProgramChoice"
            } elseif ($Script:Config.EmeetIntegMode -and -not $Script:State.EmeetVcamEnabled) {
                Show-EmeetSetupScreen
            } else {
                Show-DetectionScreen
            }
        }
    }
}

function Start-EquipmentSection {
    if ($Script:Config.BluetoothMode -and -not $Script:State.BluetoothConfirmed) {
        Show-BluetoothSetupScreen
    } else {
        Show-Screen "ScreenQuestion"
        Show-CurrentQuestion
    }
}

function Open-MediaVideo {
    $q = $Script:Sections[$Script:State.SectionIdx].Questions[$Script:State.QuestionIdx]
    if (-not $q.ContainsKey('Video')) { return }
    $path = Join-Path $Script:MediaFolder $q.Video
    if (-not (Test-Path $path)) { Write-Log "Video not found: $path" "WARN"; return }
    $Script:State.CurrentVideo = $path
    $Script:videoPlayer.Source = [Uri]::new($path)
    $Script:videoPlayer.Play()
    Show-Screen "ScreenVideo"
    Write-Log "Playing video: $($q.Video)"
}

function Show-DetectionScreen {
    # In case the operator opened Settings mid-flow, close it out so it doesn't
    # sit on top of the Detection screen.
    $Script:settingsOverlay.Visibility      = 'Collapsed'
    Close-BluetoothSettingsWindow
    # The EMEET VCAM step drops Topmost so EMEET STUDIO can appear above us --
    # restore it here regardless of which screen we arrived from.
    $Script:window.Topmost                  = $true

    $Script:State.AllHwReady                = $false
    $Script:detReadyPanel.Visibility        = 'Collapsed'
    $Script:launchButton.Visibility         = 'Collapsed'

    Show-Screen "ScreenDetection"
    Update-MainSubway
    Update-DetectionSubway
    $Script:detectionTimer.Start()
}

function Update-DetectionCard {
    param([bool]$IsOk, $Card)
    if ($IsOk) {
        Set-IconTint $Card.Icon $Script:brushGreen
        $Card.Status.Text       = $Card.Ok
        $Card.Status.Foreground = $Script:brushGreen
        $Card.Help.Visibility   = 'Collapsed'
    } else {
        Set-IconTint $Card.Icon $Script:brushRed
        $Card.Status.Text       = $Card.Bad
        $Card.Status.Foreground = $Script:brushRed
        $Card.Help.Visibility   = 'Visible'
    }
}

function Invoke-ObsStep {
    param($Step, $StepNum, $AppCount)
    Set-SetupStatus "Starting OBS Studio..." "$StepNum of $AppCount  —  OBS"
    if (Test-Path $Script:Config.ObsPath) {
        $obsArgs = if ($Script:Config.ObsDynamicSceneMode) {
            $sc = if ($Script:radioMidweek.IsChecked -eq $true) { $Script:Config.ObsSceneMidweek } else { $Script:Config.ObsSceneWeekend }
            "--collection `"$sc`" --profile `"$($Script:Config.ObsProfile)`" --disable-shutdown-check --startvirtualcam --studio-mode"
        } else {
            "--disable-shutdown-check --startvirtualcam --studio-mode"
        }
        Write-Log "Final OBS arguments: $obsArgs"
        try {
            # Convert argument string to array for proper parsing
            $obsArgsArray = if ($obsArgs.Trim()) { 
                # Split arguments properly, respecting quoted parameters
                [System.Text.RegularExpressions.Regex]::Matches($obsArgs, '(?:[^\s"]+|"[^"]*")+') | ForEach-Object { $_.Value.Trim('"') }
            } else { 
                @() 
            }
            Write-Log "OBS arguments array: [$($obsArgsArray -join '], [')]"
            
            Start-Process -FilePath $Script:Config.ObsPath -ArgumentList $obsArgsArray `
                          -WorkingDirectory (Split-Path $Script:Config.ObsPath)
            Write-Log "Launched OBS with arguments: $($obsArgsArray -join ' ')"
        } catch { Write-Log "OBS launch failed: $($_.Exception.Message)" "ERROR" }
    } else { Write-Log "OBS path not found." "WARN" }
    Set-SetupStatus "Positioning OBS..." "$StepNum of $AppCount  —  OBS"
    Move-AppWindow -ProcessNames $Script:Config.ObsProcessNames -DisplayName "OBS" `
                   -X $Step.X -Y $Step.Y -W $Step.W -H $Step.H
}

function Invoke-ZoomStep {
    param($Step, $StepNum, $AppCount)
    Set-SetupStatus "Opening Participants sidebar in Zoom..." "$StepNum of $AppCount  —  Zoom"
    if (Test-Path $Script:Config.ZoomPath) {
        $zoomVisible = Get-Process -Name "Zoom" -ErrorAction SilentlyContinue |
                       Where-Object { $_.MainWindowHandle -ne 0 -and $_.MainWindowTitle -match "Meeting" }
        if (-not $zoomVisible) {
            Start-Process -FilePath $Script:Config.ZoomPath -ErrorAction SilentlyContinue
            Write-Log "Zoom activation triggered."
            Start-Sleep -Milliseconds $Script:Config.ZoomActivationWait
        }
        $zp = Find-AppMainWindow -ProcessNames $Script:Config.ZoomProcessNames -TimeoutSeconds 20 -TitleContains "Meeting"
        if ($zp) {
            $Script:window.Topmost = $false
            [Win32Native]::AllowSetForegroundWindow([Win32Native]::ASFW_ANY) | Out-Null
            [Win32Native]::SetForegroundWindow($zp.MainWindowHandle) | Out-Null
            Start-Sleep -Milliseconds $Script:Config.ZoomFocusSettle
            [System.Windows.Forms.SendKeys]::SendWait("%u")
            Write-Log "Alt+U sent to Zoom."
            Start-Sleep -Milliseconds $Script:Config.ZoomSidebarRender
        } else { Write-Log "Zoom Meeting window not found." "WARN" }
    } else { Write-Log "Zoom path not found." "WARN" }
    Set-SetupStatus "Positioning Zoom..." "$StepNum of $AppCount  —  Zoom"
    Move-AppWindow -ProcessNames $Script:Config.ZoomProcessNames -DisplayName "Zoom" `
                   -X $Step.X -Y $Step.Y -W $Step.W -H $Step.H -TitleContains "Meeting"
}

function Invoke-M3Step {
    param($Step, $StepNum, $AppCount)
    Set-SetupStatus "Starting Meeting Media Manager..." "$StepNum of $AppCount  —  M3"
    if (Test-Path $Script:Config.M3Path) {
        try { Start-Process -FilePath $Script:Config.M3Path; Write-Log "Launched M3." }
        catch { Write-Log "M3 launch failed: $($_.Exception.Message)" "ERROR" }
    } else { Write-Log "M3 path not found." "WARN" }
    Set-SetupStatus "Positioning Meeting Media Manager..." "$StepNum of $AppCount  —  M3"
    Move-AppWindow -ProcessNames $Script:Config.M3ProcessNames -DisplayName "M3" `
                   -X $Step.X -Y $Step.Y -W $Step.W -H $Step.H
}

function Set-EmeetVcamStatus {
    param([string]$Message)
    $Script:emeetVcamStatusText.Visibility = if ($Message) { 'Visible' } else { 'Collapsed' }
    $Script:emeetVcamStatusText.Text       = $Message
    $Script:window.Dispatcher.Invoke([action]{}, [System.Windows.Threading.DispatcherPriority]::Render)
}

function Send-EmeetAutoClicks {
    # Turns on EMEET STUDIO's virtual camera by replaying the same clicks an
    # operator would make by hand: open the V Cam tab, click Enable Virtual
    # Camera, then nudge the mouse down over the panel so it settles on the
    # right view. Coordinates are absolute screen pixels (1080p, 100% scale) --
    # matching where EMEET STUDIO was just positioned.
    function Send-Click {
        param([int]$X, [int]$Y)
        [System.Windows.Forms.Cursor]::Position = "$X,$Y"
        Start-Sleep -Milliseconds 80
        [Win32Native]::mouse_event([Win32Native]::MOUSEEVENTF_LEFTDOWN, 0, 0, 0, 0)
        Start-Sleep -Milliseconds 60
        [Win32Native]::mouse_event([Win32Native]::MOUSEEVENTF_LEFTUP, 0, 0, 0, 0)
    }

    Set-EmeetVcamStatus "Opening the V Cam tab..."
    Send-Click -X 1401 -Y 561
    Start-Sleep -Milliseconds 500

    Set-EmeetVcamStatus "Turning on the virtual camera..."
    Send-Click -X 1593 -Y 703
    Start-Sleep -Milliseconds 500

    Set-EmeetVcamStatus "Settling the view..."
    [System.Windows.Forms.Cursor]::Position = "1200,600"
    Start-Sleep -Milliseconds 500

    [Win32Native]::mouse_event([Win32Native]::MOUSEEVENTF_WHEEL, 0, 0, -2000, 0)
    Write-Log "EMEET STUDIO virtual-camera click sequence complete."
}

function Show-EmeetSetupScreen {
    $Script:window.Topmost = $false
    Set-EmeetVcamStatus ""
    $Script:btnEmeetEnable.IsEnabled = $true
    $Script:btnEmeetEnable.Content   = "⚡   Enable"
    Show-Screen "ScreenEmeetSetup"
    Update-MainSubway
}

function Enable-EmeetVcam {
    $Script:btnEmeetEnable.IsEnabled = $false
    $Script:window.Topmost = $false

    if (-not (Test-Path $Script:Config.EmeetPath)) {
        Set-EmeetVcamStatus "EMEET STUDIO wasn't found on this laptop -- skipping."
        Write-Log "EMEET STUDIO path not found: $($Script:Config.EmeetPath)" "WARN"
        Start-Sleep -Milliseconds 900
        $Script:State.EmeetVcamEnabled = $true
        Show-DetectionScreen
        return
    }

    $already = Get-Process -Name $Script:Config.EmeetProcessNames -ErrorAction SilentlyContinue |
               Where-Object { $_.MainWindowHandle -ne 0 }
    if ($already) {
        Set-EmeetVcamStatus "EMEET STUDIO is already running..."
        Write-Log "EMEET STUDIO already running for VCAM setup."
    } else {
        Set-EmeetVcamStatus "Opening EMEET STUDIO..."
        try {
            Start-Process -FilePath $Script:Config.EmeetPath `
                          -WorkingDirectory (Split-Path $Script:Config.EmeetPath)
            Write-Log "EMEET STUDIO launched for VCAM setup."
        } catch {
            Set-EmeetVcamStatus "Couldn't open EMEET STUDIO -- continuing without it."
            Write-Log "EMEET STUDIO launch failed: $($_.Exception.Message)" "ERROR"
            Start-Sleep -Milliseconds 900
            $Script:State.EmeetVcamEnabled = $true
            Show-DetectionScreen
            return
        }
    }

    $rect = $Script:Config.EmeetVcamRect
    $proc = Find-AppMainWindow -ProcessNames $Script:Config.EmeetProcessNames -TimeoutSeconds 25
    $vcamOk = $false
    if ($proc) {
        try {
            $landed = $false
            for ($attempt = 1; $attempt -le 2; $attempt++) {
                [Win32Native]::ShowWindow($proc.MainWindowHandle, [Win32Native]::SW_RESTORE) | Out-Null
                Start-Sleep -Milliseconds 300
                [Win32Native]::MoveWindow($proc.MainWindowHandle, $rect.X, $rect.Y, $rect.W, $rect.H, $true) | Out-Null
                [Win32Native]::AllowSetForegroundWindow([Win32Native]::ASFW_ANY) | Out-Null
                [Win32Native]::SetForegroundWindow($proc.MainWindowHandle) | Out-Null
                Start-Sleep -Milliseconds 300

                $winRect = New-Object Win32Native+RECT
                [Win32Native]::GetWindowRect($proc.MainWindowHandle, [ref]$winRect) | Out-Null
                $landed = ([Math]::Abs($winRect.Left - $rect.X) -le 10) -and ([Math]::Abs($winRect.Top - $rect.Y) -le 10) -and
                          ([Math]::Abs(($winRect.Right - $winRect.Left) - $rect.W) -le 20) -and
                          ([Math]::Abs(($winRect.Bottom - $winRect.Top) - $rect.H) -le 20)
                if ($landed) {
                    Write-Log "Positioned EMEET STUDIO for VCAM setup: ($($rect.X),$($rect.Y)) $($rect.W)x$($rect.H)"
                    break
                }
                Write-Log "EMEET STUDIO didn't land at the VCAM rect (attempt $attempt): wanted ($($rect.X),$($rect.Y)) $($rect.W)x$($rect.H), got ($($winRect.Left),$($winRect.Top)) $($winRect.Right - $winRect.Left)x$($winRect.Bottom - $winRect.Top)" "WARN"
            }

            if ($landed) {
                Start-Sleep -Milliseconds 500
                Send-EmeetAutoClicks
                $vcamOk = $true
            } else {
                # The click sequence targets fixed absolute coordinates that
                # only line up with the window at its VCAM rect -- clicking
                # blind at the wrong window position could hit the wrong
                # thing entirely, so skip the automation rather than guess.
                Set-EmeetVcamStatus "Couldn't position EMEET STUDIO -- enable the virtual camera manually, then continue."
                Write-Log "Skipped EMEET click automation -- window never landed at the expected rect." "ERROR"
            }
        } catch {
            Write-Log "EMEET STUDIO VCAM automation failed: $($_.Exception.Message)" "ERROR"
        }
    } else {
        Set-EmeetVcamStatus "Couldn't find the EMEET STUDIO window -- continuing without it."
        Write-Log "EMEET STUDIO window not found for VCAM setup." "WARN"
    }

    if ($vcamOk) {
        Set-EmeetVcamStatus "Virtual camera enabled."
        Start-Sleep -Milliseconds 700
    } else {
        Start-Sleep -Milliseconds 1500
    }
    $Script:State.EmeetVcamEnabled = $true
    Show-DetectionScreen
}

function Update-Detection {
    if ($Script:Config.TestMode) {
        $hw = @{ AcPower=$true; Internet=$true; Display=$true; Webcam=$true; UsbAudio=$true }
    } else {
        $hw = @{
            AcPower  = $Script:HwCache.AcPower
            Internet = $Script:HwCache.Internet
            Display  = $Script:HwCache.Display
            Webcam   = $Script:HwCache.Webcam
            UsbAudio = $Script:HwCache.UsbAudio
        }
    }
    if ($Script:State.Flow -eq "NonZoom") { $hw.Remove("UsbAudio") }

    foreach ($card in $Script:DetCards) { Update-DetectionCard $hw[$card.HwKey] $card }
    Update-DetectionSubway

    $allGreen = -not ($hw.Values -contains $false)

    if ($allGreen -and -not $Script:State.AllHwReady) {
        $Script:State.AllHwReady = $true
        $Script:detectionTimer.Stop()
        Update-MainSubway
        Write-Log "All hardware checks passed."

        if ($Script:State.Flow -eq "NonZoom") {
            Write-Log "Non-Zoom: auto-launching $($Script:State.NonZoomProgram)."
            Invoke-Launch
        } else {
            Show-ReadyPanel
        }
    }
}

function Show-ReadyPanel {
    $Script:detReadyPanel.Visibility = 'Visible'
    $d = Get-DefaultMeetingType
    if ($d -eq 'Midweek') { $Script:radioMidweek.IsChecked = $true }
    else                   { $Script:radioWeekend.IsChecked = $true }
    Set-MeetingTypeBadge $d
    Update-LaunchVisibility
}

function Update-LaunchVisibility {
    if ($Script:State.Flow -eq "NonZoom") { $Script:launchButton.Visibility = 'Collapsed'; return }
    $hasType = ($Script:radioMidweek.IsChecked -eq $true) -or ($Script:radioWeekend.IsChecked -eq $true)
    $Script:launchButton.Visibility = if ($hasType -and $Script:State.AllHwReady) { 'Visible' } else { 'Collapsed' }
}

# =============================================================================
#  SETUP WIZARD & SETTINGS MENU
# =============================================================================

function ConvertTo-Brush {
    param([string]$Hex)
    (New-Object System.Windows.Media.BrushConverter).ConvertFromString($Hex)
}

function Show-InitialSetup {
    $Script:welcomeOverlay.Visibility          = 'Collapsed'
    $Script:setupCongregationName.Text         = $Script:Config.CongregationName
    $Script:setupZoomHosting.IsChecked         = $Script:Config.ZoomSelfHostingMode
    $Script:setupObsScenes.IsChecked           = $Script:Config.ObsDynamicSceneMode
    $Script:setupObsSceneNamesPanel.Visibility = if ($Script:Config.ObsDynamicSceneMode) { 'Visible' } else { 'Collapsed' }
    $Script:setupObsSceneWeekend.Text          = $Script:Config.ObsSceneWeekend
    $Script:setupObsSceneMidweek.Text          = $Script:Config.ObsSceneMidweek
    $Script:setupOverlay.Visibility            = 'Visible'
}

function Start-PreflightFlow {
    # The normal startup pipeline -- runs once a preference file is in place,
    # whether that's because it already existed, or the Setup Wizard just wrote one.
    Show-CurrentQuestion
    $Script:window.Topmost = $true
    Set-DetectionIcons
    Start-HardwarePolling

    $Script:zoomStartTimer          = New-Object System.Windows.Threading.DispatcherTimer
    $Script:zoomStartTimer.Interval = [TimeSpan]::FromMilliseconds(600)
    $Script:zoomStartTimer.Add_Tick({
        $Script:zoomStartTimer.Stop()
        $alreadyUp = Get-Process -Name "Zoom" -ErrorAction SilentlyContinue |
                     Where-Object { $_.MainWindowHandle -ne 0 -and $_.MainWindowTitle.Length -gt 0 }
        if ($alreadyUp) {
            Write-Log "Zoom already visible -- skipping background launch."
        } elseif (Test-Path $Script:Config.ZoomPath) {
            try   { Start-Process -FilePath $Script:Config.ZoomPath; Write-Log "Zoom launched in background." }
            catch { Write-Log "Zoom background launch failed: $($_.Exception.Message)" "WARN" }
        }
    })
    $Script:zoomStartTimer.Start()
}

# Keys never surfaced in the Advanced list -- technical paths/IDs (edit the
# preference file directly to change these), or keys with their own section.
$Script:HiddenConfigKeys = @(
    'AdminMode','TestMode','WebcamInstanceId','UsbAudioInstanceId',
    'JwLibraryShortcut','ObsPath','M3Path','ZoomPath',
    'EmeetIntegMode','EmeetPath',
    'AutoUpdate','UpdateRepo','UpdateTimeoutSec'
)
# Keys already covered by the General section (and Setup Wizard).
$Script:SimpleConfigKeys = @(
    'CongregationName','ZoomSelfHostingMode','ObsDynamicSceneMode',
    'ObsSceneWeekend','ObsSceneMidweek'
)
# Structural/technical values that aren't a single toggle or text field.
$Script:TechnicalConfigKeys = @(
    'UiRefreshMs','PollIntervalSec','WindowWaitSeconds','ZoomActivationWait',
    'ZoomFocusSettle','ZoomSidebarRender','FinalMessageHold','VideoErrorHold',
    'DataFolder','Layout','LayoutStandard','LayoutEmeet',
    'EmeetVcamRect',
    'M3ProcessNames','ZoomProcessNames','ObsProcessNames','EmeetProcessNames'
)
$Script:FriendlyConfigLabels = @{
    BluetoothMode       = "Use Bluetooth mixer link"
    BluetoothInstanceId = "Bluetooth device ID"
    BluetoothDeviceName = "Bluetooth device name"
    ObsProfile          = "OBS profile name"
    WebcamName          = "Camera display name"
}

function Build-AdvancedSettingsPanel {
    # One st-option row per remaining text/toggle preference: words on the
    # left, control on the right, a hairline between rows.
    $Script:settingsAdvancedPanel.Children.Clear()
    $Script:AdvancedControls = @{}

    $keys = $Script:Config.Keys | Where-Object {
        $_ -notin $Script:HiddenConfigKeys -and
        $_ -notin $Script:SimpleConfigKeys -and
        $_ -notin $Script:TechnicalConfigKeys -and
        ($Script:Config[$_] -is [bool] -or $Script:Config[$_] -is [string])
    } | Sort-Object

    $first = $true
    foreach ($key in $keys) {
        $value = $Script:Config[$key]
        $label = if ($Script:FriendlyConfigLabels.ContainsKey($key)) {
            $Script:FriendlyConfigLabels[$key]
        } else {
            ($key -creplace '([a-z])([A-Z])', '$1 $2')
        }

        if (-not $first) {
            $sep = New-Object System.Windows.Controls.Border
            $sep.Height = 1; $sep.Background = ConvertTo-Brush '#2A3550'
            [void]$Script:settingsAdvancedPanel.Children.Add($sep)
        }
        $first = $false

        $row  = New-Object System.Windows.Controls.Grid
        $row.MinHeight = 64
        $col1 = New-Object System.Windows.Controls.ColumnDefinition
        $col1.Width = New-Object System.Windows.GridLength(1, [System.Windows.GridUnitType]::Star)
        $col2 = New-Object System.Windows.Controls.ColumnDefinition
        $col2.Width = [System.Windows.GridLength]::Auto
        [void]$row.ColumnDefinitions.Add($col1)
        [void]$row.ColumnDefinitions.Add($col2)

        $lbl = New-Object System.Windows.Controls.TextBlock
        $lbl.Text              = $label
        $lbl.Foreground        = ConvertTo-Brush '#E8EDF6'
        $lbl.FontSize          = 16
        $lbl.TextWrapping      = 'Wrap'
        $lbl.VerticalAlignment = 'Center'
        $lbl.Margin            = '0,0,24,0'
        [System.Windows.Controls.Grid]::SetColumn($lbl, 0)
        [void]$row.Children.Add($lbl)

        if ($value -is [bool]) {
            $ctrl = New-Object System.Windows.Controls.CheckBox
            $ctrl.Style     = $Script:window.FindResource("ToggleSwitchStyle")
            $ctrl.IsChecked = $value
        } else {
            $ctrl = New-Object System.Windows.Controls.TextBox
            $ctrl.Style  = $Script:window.FindResource("SettingsTextBox")
            $ctrl.Text   = $value
            $ctrl.Width  = 380
            $ctrl.Margin = '0,8,0,8'
        }
        [System.Windows.Automation.AutomationProperties]::SetName($ctrl, $label)
        $ctrl.VerticalAlignment = 'Center'
        [System.Windows.Controls.Grid]::SetColumn($ctrl, 1)
        [void]$row.Children.Add($ctrl)

        [void]$Script:settingsAdvancedPanel.Children.Add($row)
        $Script:AdvancedControls[$key] = $ctrl
    }
}

$Script:SettingsSections = @{
    General  = @{ Title = "General";       Hint = "The basics for this laptop and this congregation." }
    Layout   = @{ Title = "Window layout"; Hint = "Drag a window to move it. Drag an edge or a corner to resize it. Windows snap to the screen edges and to each other; hold Shift to place one freely." }
    Updates  = @{ Title = "Updates";       Hint = "Preflight checks for a new version each time it starts, before the welcome page." }
    Advanced = @{ Title = "Advanced";      Hint = "Rarely needed. Change these only if you know what they do." }
}

function Show-SettingsTab {
    param([string]$Tab)
    $Script:settingsSimplePanel.Visibility  = if ($Tab -eq "General")  { 'Visible' } else { 'Collapsed' }
    $Script:settingsLayoutPanel.Visibility  = if ($Tab -eq "Layout")   { 'Visible' } else { 'Collapsed' }
    $Script:settingsUpdatesPanel.Visibility = if ($Tab -eq "Updates")  { 'Visible' } else { 'Collapsed' }
    $Script:settingsAdvancedCard.Visibility = if ($Tab -eq "Advanced") { 'Visible' } else { 'Collapsed' }

    $Script:settingsSectionTitle.Text = $Script:SettingsSections[$Tab].Title
    $Script:settingsSectionHint.Text  = $Script:SettingsSections[$Tab].Hint

    $nav = @{ General = $Script:navGeneral; Layout = $Script:navLayout; Updates = $Script:navUpdates; Advanced = $Script:navAdvanced }
    if ($nav[$Tab].IsChecked -ne $true) { $nav[$Tab].IsChecked = $true }

    if ($Tab -eq "Layout") { Show-LayoutMode -ModeName (Get-PreflightModeName) }
}

# =============================================================================
#  WINDOW LAYOUT EDITOR
#  A scaled copy of the screen (the Canvas is the real pixel size inside a
#  Viewbox, so every number on it is a real screen pixel). Each app is a tile:
#  one invisible Thumb over the body moves it, eight grips resize it.
# =============================================================================
$Script:LayoutEditorRowsByMode  = @{}
$Script:LayoutEditorCurrentMode = $null
$Script:LayoutAppLabels = @{ Obs = "OBS"; Zoom = "Zoom"; M3 = "Meeting Media Manager" }
$Script:LayoutModeLabels = @{ Standard = "Standard" }
$Script:LayoutTiles     = @{}
$Script:LayoutSelected  = $null
$Script:LayoutSnapPx    = 20     # how close an edge must come before it snaps
$Script:LayoutMinW      = 240
$Script:LayoutMinH      = 160

function Get-LayoutRows {
    return @($Script:LayoutEditorRowsByMode[$Script:LayoutEditorCurrentMode])
}
function Get-LayoutRow {
    param([string]$App)
    return (Get-LayoutRows) | Where-Object { $_.App -eq $App } | Select-Object -First 1
}

function Get-OrdinalText {
    param([int]$N)
    $suffix = switch ($N) { 1 { 'st' } 2 { 'nd' } 3 { 'rd' } default { 'th' } }
    return "$N$suffix"
}

function Show-LayoutMode {
    param([string]$ModeName)
    $Script:LayoutEditorCurrentMode = $ModeName
    if (-not $Script:LayoutEditorRowsByMode.ContainsKey($ModeName)) {
        # Deep-copy so editing doesn't mutate the resolved defaults/overrides directly.
        $Script:LayoutEditorRowsByMode[$ModeName] = @(Resolve-LaunchSequence -ModeName $ModeName | ForEach-Object {
            @{ App = $_.App; Order = $_.Order; X = $_.X; Y = $_.Y; W = $_.W; H = $_.H; DelayMs = $_.DelayMs }
        })
    }
    Build-LayoutCanvas
}

function Build-LayoutCanvas {
    $screen = Get-ScreenResolution
    $Script:LayoutScreen = @{ W = $screen.Width; H = $screen.Height; WorkH = $screen.WorkingHeight }
    $c = $Script:layoutCanvas
    $c.Children.Clear()
    $c.Width  = $Script:LayoutScreen.W
    $c.Height = $Script:LayoutScreen.H
    $Script:LayoutTiles = @{}

    # Taskbar strip, so the operator can see what the bottom edge really is.
    $taskH = $Script:LayoutScreen.H - $Script:LayoutScreen.WorkH
    if ($taskH -gt 0) {
        $bar = New-Object System.Windows.Controls.Border
        $bar.Width = $Script:LayoutScreen.W; $bar.Height = $taskH
        $bar.Background = ConvertTo-Brush '#1A2338'
        $bar.BorderBrush = ConvertTo-Brush '#2A3550'; $bar.BorderThickness = '0,2,0,0'
        $barText = New-Object System.Windows.Controls.TextBlock
        $barText.Text = "Taskbar"; $barText.FontSize = 22; $barText.Foreground = ConvertTo-Brush '#9AA6BE'
        $barText.HorizontalAlignment = 'Center'; $barText.VerticalAlignment = 'Center'
        $bar.Child = $barText
        [System.Windows.Controls.Canvas]::SetTop($bar, $Script:LayoutScreen.WorkH)
        $bar.IsHitTestVisible = $false
        [void]$c.Children.Add($bar)
    }

    foreach ($row in (Get-LayoutRows | Sort-Object Order)) { New-LayoutTile -Row $row }

    # Snap guides: thin coral lines shown while an edge is snapped.
    $Script:LayoutGuideV = New-Object System.Windows.Shapes.Rectangle
    $Script:LayoutGuideV.Width = 4; $Script:LayoutGuideV.Height = $Script:LayoutScreen.H
    $Script:LayoutGuideH = New-Object System.Windows.Shapes.Rectangle
    $Script:LayoutGuideH.Height = 4; $Script:LayoutGuideH.Width = $Script:LayoutScreen.W
    foreach ($g in @($Script:LayoutGuideV, $Script:LayoutGuideH)) {
        $g.Fill = ConvertTo-Brush '#F08A6C'
        $g.Visibility = 'Collapsed'
        $g.IsHitTestVisible = $false
        [System.Windows.Controls.Panel]::SetZIndex($g, 1000)
        [void]$c.Children.Add($g)
    }

    $first = (Get-LayoutRows | Sort-Object Order | Select-Object -First 1)
    $pick = if ($Script:LayoutSelected -and (Get-LayoutRow $Script:LayoutSelected)) { $Script:LayoutSelected } elseif ($first) { $first.App } else { $null }
    Select-LayoutTile -App $pick
}

$Script:LayoutTileXaml = @'
<Grid xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
      xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml">
  <Border x:Name="Body" CornerRadius="14" BorderThickness="4"/>
  <StackPanel Margin="32,26,32,0" IsHitTestVisible="False">
    <StackPanel Orientation="Horizontal">
      <Border x:Name="Badge" Width="60" Height="60" CornerRadius="30">
        <TextBlock x:Name="OrderText" FontSize="30" FontWeight="Bold" HorizontalAlignment="Center" VerticalAlignment="Center"/>
      </Border>
      <TextBlock x:Name="NameText" FontSize="44" FontWeight="Black" Foreground="#E8EDF6" Margin="20,0,0,0"
                 VerticalAlignment="Center" TextTrimming="CharacterEllipsis"/>
    </StackPanel>
    <TextBlock x:Name="SizeText" FontSize="30" Foreground="#9AA6BE" Margin="0,14,0,0"/>
  </StackPanel>
  <Thumb x:Name="Move" Cursor="SizeAll"/>
  <Thumb x:Name="L"  Width="28" HorizontalAlignment="Left"  Cursor="SizeWE"/>
  <Thumb x:Name="R"  Width="28" HorizontalAlignment="Right" Cursor="SizeWE"/>
  <Thumb x:Name="T"  Height="28" VerticalAlignment="Top"    Cursor="SizeNS"/>
  <Thumb x:Name="B"  Height="28" VerticalAlignment="Bottom" Cursor="SizeNS"/>
  <Thumb x:Name="TL" Width="48" Height="48" HorizontalAlignment="Left"  VerticalAlignment="Top"    Cursor="SizeNWSE"/>
  <Thumb x:Name="TR" Width="48" Height="48" HorizontalAlignment="Right" VerticalAlignment="Top"    Cursor="SizeNESW"/>
  <Thumb x:Name="BL" Width="48" Height="48" HorizontalAlignment="Left"  VerticalAlignment="Bottom" Cursor="SizeNESW"/>
  <Thumb x:Name="BR" Width="48" Height="48" HorizontalAlignment="Right" VerticalAlignment="Bottom" Cursor="SizeNWSE"/>
  <!-- Corner grip mark, so resizing is discoverable without hovering -->
  <Path IsHitTestVisible="False" HorizontalAlignment="Right" VerticalAlignment="Bottom" Margin="0,0,14,14"
        Stroke="#9AA6BE" StrokeThickness="4" StrokeStartLineCap="Round" StrokeEndLineCap="Round"
        Data="M 28,4 L 4,28 M 28,16 L 16,28"/>
</Grid>
'@

# Shared handlers: each Thumb carries "App|Kind" in its Tag.
$Script:OnLayoutDragStarted = {
    param($s, $e)
    $app, $kind = $s.Tag -split '\|'
    Select-LayoutTile -App $app
}
$Script:OnLayoutDragDelta = {
    param($s, $e)
    $app, $kind = $s.Tag -split '\|'
    Step-LayoutDrag -App $app -Kind $kind -Dx $e.HorizontalChange -Dy $e.VerticalChange
}
$Script:OnLayoutDragCompleted = {
    param($s, $e)
    $Script:LayoutGuideV.Visibility = 'Collapsed'
    $Script:LayoutGuideH.Visibility = 'Collapsed'
}

function New-LayoutTile {
    param([hashtable]$Row)
    $tile = [Windows.Markup.XamlReader]::Parse($Script:LayoutTileXaml)
    foreach ($kind in @('Move','L','R','T','B','TL','TR','BL','BR')) {
        $t = $tile.FindName($kind)
        $t.Style = $Script:window.FindResource($(if ($kind -eq 'Move') { 'MoveThumb' } else { 'GripThumb' }))
        $t.Tag = "$($Row.App)|$kind"
        $t.Add_DragStarted($Script:OnLayoutDragStarted)
        $t.Add_DragDelta($Script:OnLayoutDragDelta)
        $t.Add_DragCompleted($Script:OnLayoutDragCompleted)
    }
    $tile.FindName('NameText').Text = $Script:LayoutAppLabels[$Row.App]
    [System.Windows.Automation.AutomationProperties]::SetName($tile, "$($Script:LayoutAppLabels[$Row.App]) window")
    $Script:LayoutTiles[$Row.App] = $tile
    [void]$Script:layoutCanvas.Children.Add($tile)
    Update-LayoutTile -App $Row.App
}

function Update-LayoutTile {
    param([string]$App)
    $row  = Get-LayoutRow $App
    $tile = $Script:LayoutTiles[$App]
    if (-not $row -or -not $tile) { return }
    [System.Windows.Controls.Canvas]::SetLeft($tile, $row.X)
    [System.Windows.Controls.Canvas]::SetTop($tile,  $row.Y)
    $tile.Width  = [Math]::Max(1, $row.W)
    $tile.Height = [Math]::Max(1, $row.H)
    $tile.FindName('OrderText').Text = "$($row.Order)"
    $tile.FindName('SizeText').Text  = "$($row.W) $([char]0x00D7) $($row.H)   at $($row.X), $($row.Y)"

    $selected = ($App -eq $Script:LayoutSelected)
    $body  = $tile.FindName('Body')
    $badge = $tile.FindName('Badge')
    # Selection shows by fill, border and z-order together, never colour alone.
    $body.Background  = ConvertTo-Brush $(if ($selected) { '#2C3D62' } else { '#1A2338' })
    $body.BorderBrush = ConvertTo-Brush $(if ($selected) { '#8FA9D6' } else { '#2A3550' })
    $body.BorderThickness = [System.Windows.Thickness]::new($(if ($selected) { 6 } else { 3 }))
    $badge.Background = ConvertTo-Brush $(if ($selected) { '#8FA9D6' } else { '#22304D' })
    $tile.FindName('OrderText').Foreground = ConvertTo-Brush $(if ($selected) { '#121A2B' } else { '#B3C6E6' })
    [System.Windows.Controls.Panel]::SetZIndex($tile, $(if ($selected) { 100 } else { 10 + $row.Order }))
}

function Select-LayoutTile {
    param([string]$App)
    $Script:LayoutSelected = $App
    foreach ($a in @($Script:LayoutTiles.Keys)) { Update-LayoutTile -App $a }
    Update-LayoutInspector
}

function Update-LayoutInspector {
    $row = if ($Script:LayoutSelected) { Get-LayoutRow $Script:LayoutSelected } else { $null }
    $enabled = [bool]$row
    foreach ($ctl in @($Script:layoutX, $Script:layoutY, $Script:layoutW, $Script:layoutH, $Script:layoutDelay,
                       $Script:btnLayoutPresetTileLeft, $Script:btnLayoutPresetTileRight,
                       $Script:btnLayoutPresetCenter, $Script:btnLayoutPresetFullscreen)) { $ctl.IsEnabled = $enabled }
    if (-not $row) {
        $Script:layoutSelName.Text = "Pick a window"
        $Script:layoutOrderText.Text = ""
        $Script:btnLayoutEarlier.IsEnabled = $false
        $Script:btnLayoutLater.IsEnabled   = $false
        return
    }
    $count = (Get-LayoutRows).Count
    $Script:layoutSelName.Text   = $Script:LayoutAppLabels[$row.App]
    $Script:layoutX.Text         = "$($row.X)"
    $Script:layoutY.Text         = "$($row.Y)"
    $Script:layoutW.Text         = "$($row.W)"
    $Script:layoutH.Text         = "$($row.H)"
    $Script:layoutDelay.Text     = "$($row.DelayMs)"
    $Script:layoutOrderText.Text = "Opens $(Get-OrdinalText $row.Order) of $count"
    $Script:btnLayoutEarlier.IsEnabled = ($row.Order -gt 1)
    $Script:btnLayoutLater.IsEnabled   = ($row.Order -lt $count)
}

function Find-LayoutSnap {
    # Returns the nearest snap target for one or two edges on an axis, or $null.
    # $Edges: candidate edge positions of the moving tile; $Targets: lines to snap to.
    param([double[]]$Edges, [double[]]$Targets)
    $best = $null
    foreach ($edge in $Edges) {
        foreach ($t in $Targets) {
            $d = $t - $edge
            if ([Math]::Abs($d) -le $Script:LayoutSnapPx -and (-not $best -or [Math]::Abs($d) -lt [Math]::Abs($best.Shift))) {
                $best = @{ Shift = $d; Line = $t }
            }
        }
    }
    return $best
}

function Get-LayoutSnapTargets {
    param([string]$App)
    $xs = [System.Collections.Generic.List[double]]::new()
    $ys = [System.Collections.Generic.List[double]]::new()
    foreach ($v in @(0, $Script:LayoutScreen.W / 2, $Script:LayoutScreen.W)) { $xs.Add($v) }
    foreach ($v in @(0, $Script:LayoutScreen.WorkH / 2, $Script:LayoutScreen.WorkH)) { $ys.Add($v) }
    foreach ($o in (Get-LayoutRows | Where-Object { $_.App -ne $App })) {
        $xs.Add($o.X); $xs.Add($o.X + $o.W)
        $ys.Add($o.Y); $ys.Add($o.Y + $o.H)
    }
    return @{ X = $xs.ToArray(); Y = $ys.ToArray() }
}

function Step-LayoutDrag {
    # Thumb deltas are measured from the grip's current (already snapped)
    # position, so each step starts from the row's live values.
    param([string]$App, [string]$Kind, [double]$Dx, [double]$Dy)
    $row = Get-LayoutRow $App
    if (-not $row) { return }

    $left = [double]$row.X; $top = [double]$row.Y
    $right = $left + $row.W; $bottom = $top + $row.H
    $moveL = $Kind -in @('Move','L','TL','BL'); $moveR = $Kind -in @('Move','R','TR','BR')
    $moveT = $Kind -in @('Move','T','TL','TR'); $moveB = $Kind -in @('Move','B','BL','BR')

    if ($moveL) { $left   += $Dx }
    if ($moveR) { $right  += $Dx }
    if ($moveT) { $top    += $Dy }
    if ($moveB) { $bottom += $Dy }

    $snapOn = ($Script:layoutSnap.IsChecked -eq $true) -and
              -not ([System.Windows.Input.Keyboard]::Modifiers -band [System.Windows.Input.ModifierKeys]::Shift)
    $guideX = $null; $guideY = $null
    if ($snapOn) {
        $targets = Get-LayoutSnapTargets -App $App
        $xEdges = @(); if ($moveL) { $xEdges += $left }; if ($moveR) { $xEdges += $right }
        $yEdges = @(); if ($moveT) { $yEdges += $top };  if ($moveB) { $yEdges += $bottom }
        $sx = if ($xEdges.Count) { Find-LayoutSnap -Edges $xEdges -Targets $targets.X } else { $null }
        $sy = if ($yEdges.Count) { Find-LayoutSnap -Edges $yEdges -Targets $targets.Y } else { $null }
        if ($sx) {
            if ($Kind -eq 'Move') { $left += $sx.Shift; $right += $sx.Shift }
            elseif ($moveL)       { $left += $sx.Shift }
            else                  { $right += $sx.Shift }
            $guideX = $sx.Line
        }
        if ($sy) {
            if ($Kind -eq 'Move') { $top += $sy.Shift; $bottom += $sy.Shift }
            elseif ($moveT)       { $top += $sy.Shift }
            else                  { $bottom += $sy.Shift }
            $guideY = $sy.Line
        }
    }

    # Keep a usable size and keep the window on the screen. A little negative
    # room is allowed: Windows draws invisible borders around most apps.
    if ($right - $left -lt $Script:LayoutMinW) { if ($moveL -and -not $moveR) { $left = $right - $Script:LayoutMinW } else { $right = $left + $Script:LayoutMinW } }
    if ($bottom - $top -lt $Script:LayoutMinH) { if ($moveT -and -not $moveB) { $top = $bottom - $Script:LayoutMinH } else { $bottom = $top + $Script:LayoutMinH } }
    $minX = -20; $maxX = $Script:LayoutScreen.W + 20; $minY = -20; $maxY = $Script:LayoutScreen.H
    if ($Kind -eq 'Move') {
        $w = $right - $left; $h = $bottom - $top
        $left = [Math]::Min([Math]::Max($left, $minX), $maxX - $w); $right = $left + $w
        $top  = [Math]::Min([Math]::Max($top,  $minY), $maxY - $h); $bottom = $top + $h
    } else {
        $left = [Math]::Max($left, $minX); $right = [Math]::Min($right, $maxX)
        $top  = [Math]::Max($top,  $minY); $bottom = [Math]::Min($bottom, $maxY)
    }

    $row.X = [int][Math]::Round($left);  $row.Y = [int][Math]::Round($top)
    $row.W = [int][Math]::Round($right - $left); $row.H = [int][Math]::Round($bottom - $top)
    Update-LayoutTile -App $App
    Update-LayoutInspector

    if ($null -ne $guideX) { [System.Windows.Controls.Canvas]::SetLeft($Script:LayoutGuideV, $guideX - 2); $Script:LayoutGuideV.Visibility = 'Visible' }
    else { $Script:LayoutGuideV.Visibility = 'Collapsed' }
    if ($null -ne $guideY) { [System.Windows.Controls.Canvas]::SetTop($Script:LayoutGuideH, $guideY - 2); $Script:LayoutGuideH.Visibility = 'Visible' }
    else { $Script:LayoutGuideH.Visibility = 'Collapsed' }
}

function Set-LayoutField {
    # Commits one inspector box (X, Y, W, H or DelayMs) back to the selected row.
    param([string]$Field, [string]$Text)
    $row = if ($Script:LayoutSelected) { Get-LayoutRow $Script:LayoutSelected } else { $null }
    if (-not $row) { return }
    $n = 0
    if (-not [int]::TryParse($Text.Trim(), [ref]$n)) { Update-LayoutInspector; return }
    switch ($Field) {
        'W'       { $n = [Math]::Max($n, $Script:LayoutMinW) }
        'H'       { $n = [Math]::Max($n, $Script:LayoutMinH) }
        'DelayMs' { $n = [Math]::Max($n, 0) }
    }
    $row[$Field] = $n
    Update-LayoutTile -App $row.App
    Update-LayoutInspector
}

function Move-LayoutRow {
    param([string]$App, [int]$Direction)
    $rows = @(Get-LayoutRows | Sort-Object Order)
    $idx  = 0..($rows.Count-1) | Where-Object { $rows[$_].App -eq $App }
    $swapIdx = $idx + $Direction
    if ($swapIdx -lt 0 -or $swapIdx -ge $rows.Count) { return }
    $tmp = $rows[$idx].Order
    $rows[$idx].Order     = $rows[$swapIdx].Order
    $rows[$swapIdx].Order = $tmp
    foreach ($r in $rows) { Update-LayoutTile -App $r.App }
    Update-LayoutInspector
}

function Update-LayoutToolsStatus {
    param([string]$Message, [string]$Color = "#9AA6BE")
    $Script:layoutToolsStatus.Text = $Message
    $Script:layoutToolsStatus.Foreground = ConvertTo-Brush $Color
}

function Invoke-LayoutPreset {
    param([string]$PresetType)
    $row = if ($Script:LayoutSelected) { Get-LayoutRow $Script:LayoutSelected } else { $null }
    if (-not $row) { return }
    $sw = $Script:LayoutScreen.W; $wh = $Script:LayoutScreen.WorkH
    switch ($PresetType) {
        "TileLeft"   { $row.X = 0;                  $row.Y = 0; $row.W = [int]($sw / 2); $row.H = $wh }
        "TileRight"  { $row.X = [int]($sw / 2);     $row.Y = 0; $row.W = [int]($sw / 2); $row.H = $wh }
        "Center"     { $row.W = [int]($sw * 0.7);   $row.H = [int]($wh * 0.7)
                       $row.X = [int](($sw - $row.W) / 2); $row.Y = [int](($wh - $row.H) / 2) }
        "Fullscreen" { $row.X = 0; $row.Y = 0; $row.W = $sw; $row.H = $wh }
    }
    Update-LayoutTile -App $row.App
    Update-LayoutInspector
}

function Invoke-CaptureCurrentPositions {
    try {
        $positions = Get-AllAppPositions
        $updated = 0
        foreach ($row in (Get-LayoutRows)) {
            if ($positions.ContainsKey($row.App)) {
                $pos = $positions[$row.App]
                $row.X = $pos.X; $row.Y = $pos.Y; $row.W = $pos.W; $row.H = $pos.H
                Update-LayoutTile -App $row.App
                $updated++
            }
        }
        Update-LayoutInspector
        if ($updated -gt 0) {
            Update-LayoutToolsStatus "Copied the position of $updated open window$(if ($updated -ne 1) { 's' }). Save to keep it." "#5FC08A"
        } else {
            Update-LayoutToolsStatus "None of these apps are open. Open OBS, Zoom or M3 and place them first." "#F2B544"
        }
    } catch {
        Update-LayoutToolsStatus "Couldn't read the open windows. Try again." "#FF6B5E"
        Write-Log "Position capture error: $($_.Exception.Message)" "ERROR"
    }
}

function Invoke-LayoutTryNow {
    # Moves the apps that are already open to the edited layout (nothing is
    # launched or saved), and steps Preflight out of the way for a few seconds.
    $names = @{ Obs = $Script:Config.ObsProcessNames; Zoom = $Script:Config.ZoomProcessNames; M3 = $Script:Config.M3ProcessNames }
    $moved = 0
    foreach ($row in (Get-LayoutRows | Sort-Object Order)) {
        $proc = Get-Process -Name $names[$row.App] -ErrorAction SilentlyContinue |
                Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
        if (-not $proc) { continue }
        [Win32Native]::ShowWindow($proc.MainWindowHandle, [Win32Native]::SW_RESTORE) | Out-Null
        [Win32Native]::MoveWindow($proc.MainWindowHandle, $row.X, $row.Y, $row.W, $row.H, $true) | Out-Null
        $moved++
    }
    if ($moved -eq 0) {
        Update-LayoutToolsStatus "None of these apps are open, so there's nothing to move." "#F2B544"
        return
    }
    Update-LayoutToolsStatus "Showing the layout for 6 seconds..." "#8FA9D6"
    $Script:window.Topmost = $false
    $Script:window.WindowState = 'Minimized'
    $Script:layoutPeekTimer = New-Object System.Windows.Threading.DispatcherTimer
    $Script:layoutPeekTimer.Interval = [TimeSpan]::FromSeconds(6)
    $Script:layoutPeekTimer.Add_Tick({
        $Script:layoutPeekTimer.Stop()
        $Script:window.WindowState = 'Normal'
        $Script:window.Topmost = $true
        $Script:window.Activate() | Out-Null
        Update-LayoutToolsStatus "That's how it will look. Save to keep it." "#9AA6BE"
    })
    $Script:layoutPeekTimer.Start()
}

function Reset-LayoutToDefaults {
    $mode = $Script:LayoutEditorCurrentMode
    if (-not $mode) { return }
    $Script:LayoutEditorRowsByMode[$mode] = @(Get-PreflightSequenceDefaults -ModeName $mode | ForEach-Object {
        @{ App = $_.App; Order = $_.Order; X = $_.X; Y = $_.Y; W = $_.W; H = $_.H; DelayMs = $_.DelayMs }
    })
    $Script:LayoutResetPending = $true
    Build-LayoutCanvas
    Update-LayoutToolsStatus "Back to the built-in layout. Save to keep it, or Cancel to undo." "#9AA6BE"
}

function Get-StartupShortcutPath {
    return (Join-Path ([Environment]::GetFolderPath('Startup')) "Audio-Video Preflight.lnk")
}

function Set-StartWithWindows {
    # A shortcut in the user's Startup folder -- no admin rights or scheduled
    # task needed, and it shows in Task Manager > Startup apps like any other.
    param([bool]$On)
    $lnk = Get-StartupShortcutPath
    try {
        if (-not $On) {
            if (Test-Path -LiteralPath $lnk) { Remove-Item -LiteralPath $lnk -Force; Write-Log "Removed the Windows startup shortcut." }
            return
        }
        $exe = Join-Path $Script:ScriptRoot "Preflight.exe"
        $shell = New-Object -ComObject WScript.Shell
        $s = $shell.CreateShortcut($lnk)
        if (Test-Path -LiteralPath $exe) {
            $s.TargetPath = $exe
            $s.IconLocation = "$exe,0"
        } else {
            $s.TargetPath = Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe"
            $s.Arguments  = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$Script:SelfPath`""
        }
        $s.WorkingDirectory = $Script:ScriptRoot
        $s.Description = "Audio-Video Preflight"
        $s.Save()
        Write-Log "Windows startup shortcut saved: $lnk"
    } catch {
        Write-Log "Couldn't change the startup shortcut: $($_.Exception.Message)" "WARN"
    }
}

function Show-SettingsMenu {
    $Script:setStartWithWindows.IsChecked    = Test-Path -LiteralPath (Get-StartupShortcutPath)
    $Script:setCongregationName.Text         = $Script:Config.CongregationName
    $Script:setZoomHosting.IsChecked         = $Script:Config.ZoomSelfHostingMode
    $Script:setObsScenes.IsChecked           = $Script:Config.ObsDynamicSceneMode
    $Script:setObsSceneNamesPanel.Visibility = if ($Script:Config.ObsDynamicSceneMode) { 'Visible' } else { 'Collapsed' }
    $Script:setObsSceneWeekend.Text          = $Script:Config.ObsSceneWeekend
    $Script:setObsSceneMidweek.Text          = $Script:Config.ObsSceneMidweek
    $Script:setAutoUpdate.IsChecked          = [bool]$Script:Config.AutoUpdate
    $Script:setUpdateRepo.Text               = $Script:Config.UpdateRepo
    $Script:settingsVersionText.Text         = "Preflight $($Script:AppVersion)"
    $Script:updVersionText.Text              = "Version $($Script:AppVersion)"
    $Script:updStatusText.Text               = $Script:UpdateLastResult

    # Every open starts from what's saved, so Cancel really discards edits.
    $Script:LayoutEditorRowsByMode = @{}
    $Script:LayoutResetPending     = $false
    $Script:LayoutSelected         = $null
    Update-LayoutToolsStatus ""

    Build-AdvancedSettingsPanel
    Show-SettingsTab "General"
    $Script:settingsOverlay.Visibility = 'Visible'
}

# =============================================================================
#  LAUNCH SEQUENCE
# =============================================================================

function Set-SetupStatus {
    param([string]$Message, [string]$Step = "")
    $Script:setupStatusText.Text = $Message
    $Script:setupStepText.Text   = $Step
    $Script:window.Dispatcher.Invoke([action]{}, [System.Windows.Threading.DispatcherPriority]::Render)
    Write-Log "Setup: $Message"
}

function Find-AppMainWindow {
    param([string[]]$ProcessNames, [int]$TimeoutSeconds = 30, [string]$TitleContains = "")
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        foreach ($name in $ProcessNames) {
            $proc = Get-Process -Name $name -ErrorAction SilentlyContinue |
                    Where-Object {
                        $_.MainWindowHandle -ne 0 -and
                        $_.MainWindowTitle.Length -gt 0 -and
                        ($TitleContains -eq "" -or $_.MainWindowTitle -match $TitleContains)
                    } | Select-Object -First 1
            if ($proc) { return $proc }
        }
        Start-Sleep -Milliseconds 500
    }
    return $null
}

function Move-AppWindow {
    param([string[]]$ProcessNames, [string]$DisplayName,
          [int]$X, [int]$Y, [int]$W, [int]$H, [string]$TitleContains = "")
    $proc = Find-AppMainWindow -ProcessNames $ProcessNames `
                               -TimeoutSeconds $Script:Config.WindowWaitSeconds `
                               -TitleContains $TitleContains
    if (-not $proc) { Write-Log "Timed out waiting for $DisplayName" "WARN"; return }

    for ($attempt = 1; $attempt -le 2; $attempt++) {
        try {
            [Win32Native]::ShowWindow($proc.MainWindowHandle, [Win32Native]::SW_RESTORE) | Out-Null
            Start-Sleep -Milliseconds 400
            [Win32Native]::MoveWindow($proc.MainWindowHandle, $X, $Y, $W, $H, $true) | Out-Null
            Start-Sleep -Milliseconds 250

            $rect = New-Object Win32Native+RECT
            [Win32Native]::GetWindowRect($proc.MainWindowHandle, [ref]$rect) | Out-Null
            $gotX = $rect.Left; $gotY = $rect.Top
            $gotW = $rect.Right - $rect.Left; $gotH = $rect.Bottom - $rect.Top
            # Windows often reports a few px of invisible drop-shadow border in
            # GetWindowRect, so allow a small tolerance rather than demanding
            # an exact pixel match.
            $close = ([Math]::Abs($gotX - $X) -le 10) -and ([Math]::Abs($gotY - $Y) -le 10) -and
                     ([Math]::Abs($gotW - $W) -le 20) -and ([Math]::Abs($gotH - $H) -le 20)

            if ($close) {
                Write-Log "Positioned ${DisplayName}: ($X,$Y) ${W}x${H}"
                return
            } else {
                Write-Log "${DisplayName} didn't land where expected (attempt $attempt): wanted ($X,$Y) ${W}x${H}, got ($gotX,$gotY) ${gotW}x${gotH}" "WARN"
                if ($attempt -eq 1) { Start-Sleep -Milliseconds 500 }
            }
        } catch { Write-Log "MoveWindow failed for ${DisplayName}: $($_.Exception.Message)" "ERROR" }
    }
}

function Show-BluetoothSetupScreen {
    # First step of Equipment Check when BluetoothMode is on. Topmost goes off
    # here since the operator needs to interact with the real Windows
    # Bluetooth Settings window, not just this app.
    $Script:window.Topmost = $false
    $Script:btSubQ1Panel.Visibility = 'Visible'
    $Script:btSubQ2Panel.Visibility = 'Collapsed'
    $Script:btInstructionsPanel.Visibility = 'Collapsed'
    $Script:btRestartingPanel.Visibility = 'Collapsed'
    $Script:btCheckStatusText.Visibility = 'Collapsed'

    $photoPath = Join-Path $Script:MediaFolder "check-bluetooth-mixer-enable.jpg"
    if (Test-Path $photoPath) {
        try {
            $bmp = [System.Windows.Media.Imaging.BitmapImage]::new()
            $bmp.BeginInit()
            $bmp.UriSource   = [Uri]::new($photoPath)
            $bmp.CacheOption = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
            $bmp.EndInit()
            $Script:btMixerPhotoImage.Source = $bmp
        } catch { Write-Log "Bluetooth mixer photo load failed: $($_.Exception.Message)" "WARN" }
    } else {
        Write-Log "Bluetooth mixer photo not found: $photoPath" "WARN"
    }

    Show-Screen "ScreenBluetoothSetup"
    Update-MainSubway
    Write-Log "Bluetooth setup: showing mixer sub-question."
}

function Open-BluetoothSettingsPositioned {
    # Launches the Windows Bluetooth Settings page and tries to move it over
    # the reference-photo panel so it visually replaces the picture.
    # NOTE: the Settings app is hosted under different process names across
    # Windows versions (SystemSettings.exe vs ApplicationFrameHost.exe) --
    # this tries both, but hasn't been verified on every build. If it doesn't
    # land in the right spot, preflight.log will show what happened; the
    # operator can still just move/resize the Settings window manually.
    # Drop our own Topmost flag first -- otherwise the preflight window stays
    # pinned above Settings no matter what we do to the Settings window below.
    $Script:window.Topmost = $false

    try {
        Start-Process "ms-settings:bluetooth"
        Write-Log "Launched ms-settings:bluetooth."
        $Script:State.BluetoothSettingsOpened = $true
    } catch {
        Write-Log "Failed to launch Bluetooth settings: $($_.Exception.Message)" "ERROR"
        return
    }

    Start-Sleep -Milliseconds 1200
    $proc = Find-AppMainWindow -ProcessNames @("SystemSettings","ApplicationFrameHost") `
                                -TimeoutSeconds 8 -TitleContains "Settings"
    if (-not $proc) {
        Write-Log "Bluetooth Settings window not found -- could not auto-position it." "WARN"
        return
    }

    try {
        $topLeft = $Script:btSettingsAnchor.PointToScreen([System.Windows.Point]::new(0,0))
        $w = [int]$Script:btSettingsAnchor.ActualWidth
        $h = [int]$Script:btSettingsAnchor.ActualHeight
        [Win32Native]::ShowWindow($proc.MainWindowHandle, [Win32Native]::SW_RESTORE) | Out-Null
        Start-Sleep -Milliseconds 300
        [Win32Native]::MoveWindow($proc.MainWindowHandle, [int]$topLeft.X, [int]$topLeft.Y, $w, $h, $true) | Out-Null
        [Win32Native]::AllowSetForegroundWindow([Win32Native]::ASFW_ANY) | Out-Null
        [Win32Native]::SetForegroundWindow($proc.MainWindowHandle) | Out-Null
        Write-Log "Positioned Bluetooth Settings window over the reference panel and brought it to front."
    } catch {
        Write-Log "Could not position Bluetooth Settings window: $($_.Exception.Message)" "WARN"
    }
}

function Close-BluetoothSettingsWindow {
    # The Bluetooth Settings window is only useful during the Equipment Check
    # Bluetooth step. By the time Detection shows, its job is done -- close it
    # so it doesn't sit open (and potentially overlap) through the rest of the
    # flow. Skipped entirely if we never actually opened it.
    if (-not $Script:State.BluetoothSettingsOpened) { return }
    try {
        $proc = Get-Process -Name @("SystemSettings", "ApplicationFrameHost") -ErrorAction SilentlyContinue |
                Where-Object { $_.MainWindowHandle -ne 0 -and $_.MainWindowTitle -match "Settings" } |
                Select-Object -First 1
        if ($proc) {
            $proc.CloseMainWindow() | Out-Null
            Write-Log "Closed Bluetooth Settings window ahead of Detection screen."
        }
    } catch {
        Write-Log "Could not close Bluetooth Settings window: $($_.Exception.Message)" "WARN"
    }
    $Script:State.BluetoothSettingsOpened = $false
}

function Restart-BluetoothAdapter {
    # Turns the Bluetooth adapter off then on. Requires admin rights and the
    # PnpDevice cmdlets; best-effort like the other hardware calls in this
    # script -- failures are logged, not shown to the operator.
    if ($Script:Config.TestMode) {
        Write-Log "TEST MODE -- Bluetooth adapter restart simulated."
        return
    }
    try {
        $adapters = Get-PnpDevice -Class Bluetooth -PresentOnly -ErrorAction Stop
        foreach ($a in $adapters) { Disable-PnpDevice -InstanceId $a.InstanceId -Confirm:$false -ErrorAction SilentlyContinue }
        Start-Sleep -Milliseconds 500
        foreach ($a in $adapters) { Enable-PnpDevice -InstanceId $a.InstanceId -Confirm:$false -ErrorAction SilentlyContinue }
        Write-Log "Bluetooth adapter restarted (off then on)."
    } catch {
        Write-Log "Bluetooth adapter restart failed: $($_.Exception.Message)" "WARN"
    }
}

$Script:btnBtSubQ1Yes.Add_Click({
    $Script:btSubQ1Panel.Visibility = 'Collapsed'
    $Script:btSubQ2Panel.Visibility = 'Visible'
    $Script:btDeviceNameRun.Text = $Script:Config.BluetoothDeviceName
    Write-Log "Bluetooth setup: mixer confirmed on -- showing connect sub-question."
    Open-BluetoothSettingsPositioned
})

$Script:btnEmeetEnable.Add_Click({ Enable-EmeetVcam })

$Script:btnBluetoothCheck.Add_Click({
    $connected = if ($Script:Config.TestMode) {
        $true
    } else {
        [bool](Get-PnpDevice -PresentOnly -ErrorAction SilentlyContinue |
               Where-Object { $_.InstanceId -eq $Script:Config.BluetoothInstanceId -and $_.Status -eq 'OK' })
    }
    if ($connected) {
        Write-Log "Bluetooth connection confirmed -- continuing Equipment Check."
        $Script:State.BluetoothConfirmed = $true
        $Script:btCheckStatusText.Visibility = 'Collapsed'
        $Script:window.Topmost = $true
        Show-Screen "ScreenQuestion"
        Show-CurrentQuestion
    } else {
        Write-Log "Bluetooth check failed -- device not connected yet." "WARN"
        $Script:btCheckStatusText.Text = "Bluetooth isn't connected yet. Check the settings and try again."
        $Script:btCheckStatusText.Visibility = 'Visible'
    }
})

$Script:btnBtNotConnected.Add_Click({
    $Script:btSubQ2Panel.Visibility        = 'Collapsed'
    $Script:btInstructionsPanel.Visibility = 'Visible'
    Write-Log "Bluetooth setup: operator indicated not connected -- showing reconnect instructions."
})

$Script:btnBtSkip.Add_Click({
    Show-ConfirmAction -Header "Are you sure you don't want to connect to Bluetooth?" -Bullets @(
        "You may not be able to play audio through the sound system."
    ) -OnConfirm {
        Write-Log "Bluetooth setup: operator skipped Bluetooth connection."
        $Script:State.BluetoothConfirmed       = $true
        $Script:btInstructionsPanel.Visibility = 'Collapsed'
        $Script:window.Topmost = $true
        Show-Screen "ScreenQuestion"
        Show-CurrentQuestion
    } -OnCancel {}
})

$Script:btnBtTryAgain.Add_Click({
    $Script:btInstructionsPanel.Visibility = 'Collapsed'
    $Script:btRestartingPanel.Visibility   = 'Visible'
    Write-Log "Bluetooth setup: operator chose to try again -- restarting Bluetooth adapter."
    Restart-BluetoothAdapter
    Open-BluetoothSettingsPositioned
    $Script:btRestartTimer.Start()
})



function Start-Launch {
    Write-Log "=== Launch sequence starting (Flow: $($Script:State.Flow)) ==="

    if ($Script:State.Flow -eq "NonZoom") {
        if ($Script:State.NonZoomProgram -eq "JWLibrary") {
            Set-SetupStatus "Starting JW Library..." "1 of 1  —  JW Library"
            $jwPath = Join-Path $Script:ScriptRoot $Script:Config.JwLibraryShortcut
            if (Test-Path $jwPath) {
                try { Start-Process -FilePath $jwPath; Write-Log "Launched JW Library." }
                catch { Write-Log "JW Library launch failed: $($_.Exception.Message)" "ERROR" }
            } else { Write-Log "JW Library shortcut not found: $jwPath" "ERROR" }
        } else {
            $m3Step = Get-LaunchStep -ModeName "NonZoom" -AppName "M3"
            Invoke-M3Step -Step $m3Step -StepNum 1 -AppCount 1
        }
        Set-SetupStatus "All done — your meeting is ready." "Complete"
        Start-Sleep -Milliseconds $Script:Config.FinalMessageHold
        Write-Log "=== Launch sequence complete (Non-Zoom) ==="
        return
    }

    $modeName = Get-PreflightModeName
    $sequence = Resolve-LaunchSequence -ModeName $modeName
    Write-Log "Launch sequence ($modeName): $(($sequence | ForEach-Object { $_.App }) -join ' -> ')"

    $appCount = $sequence.Count

    $dispatch = @{
        Zoom  = ${function:Invoke-ZoomStep}
        Obs   = ${function:Invoke-ObsStep}
        M3    = ${function:Invoke-M3Step}
    }

    $stepNum = 0
    foreach ($entry in $sequence) {
        $stepNum++
        if ($dispatch.ContainsKey($entry.App)) {
            & $dispatch[$entry.App] $entry $stepNum $appCount
        } else {
            Write-Log "No launch handler for '$($entry.App)' -- skipping." "WARN"
        }
        Start-Sleep -Milliseconds $entry.DelayMs
    }

    Set-SetupStatus "All done — your meeting is ready." "Complete"
    Start-Sleep -Milliseconds $Script:Config.FinalMessageHold
    Write-Log "=== Launch sequence complete ==="
}

# =============================================================================
#  UPDATES
#  On start, before the welcome page: ask GitHub for the latest release of
#  $Config.UpdateRepo. A release tagged vX.Y.Z newer than $AppVersion, with
#  Preflight.zip and Preflight.zip.sha256 attached, is downloaded, checked,
#  installed over this folder, and Preflight restarts on the new version.
#  Anything that goes wrong just means "no update today" -- the meeting
#  never waits on GitHub.
# =============================================================================
$Script:UpdateLastResult = "Not checked yet."
$Script:UpdateState      = $null
$Script:UpdateFlowDone   = $false

$Script:UpdateWorker = {
    $ErrorActionPreference = 'Stop'
    Set-Item -Path function:Copy-PreflightTree -Value ([scriptblock]::Create($CopyTreeFn))
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
        $headers = @{ 'User-Agent' = 'Preflight-Updater'; 'Accept' = 'application/vnd.github+json' }
        $rel = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo/releases/latest" -Headers $headers -TimeoutSec $TimeoutSec -UseBasicParsing

        $remote = $null
        if (-not [version]::TryParse(($rel.tag_name -replace '^[vV]', ''), [ref]$remote)) {
            throw "The latest release tag '$($rel.tag_name)' isn't a version number."
        }
        $skipFile = Join-Path $UpdateDir "skip-version.txt"
        $skip = if (Test-Path $skipFile) { (Get-Content $skipFile -Raw).Trim() } else { "" }
        if ($remote -le $Current -or "$remote" -eq $skip) {
            $State.Phase = 'uptodate'; $State.NewVersion = "$remote"
            return
        }

        $zip = $rel.assets | Where-Object { $_.name -eq 'Preflight.zip' } | Select-Object -First 1
        $sha = $rel.assets | Where-Object { $_.name -eq 'Preflight.zip.sha256' } | Select-Object -First 1
        if (-not $zip -or -not $sha) { throw "Release v$remote is missing Preflight.zip or Preflight.zip.sha256." }

        $State.NewVersion = "$remote"
        $State.Phase = 'downloading'
        if (-not (Test-Path $UpdateDir)) { New-Item -ItemType Directory -Path $UpdateDir -Force | Out-Null }
        $zipPath = Join-Path $UpdateDir "Preflight.zip"

        # Stream the download so the progress bar moves.
        $req = [System.Net.HttpWebRequest]::Create($zip.browser_download_url)
        $req.UserAgent = 'Preflight-Updater'; $req.Timeout = 30000; $req.ReadWriteTimeout = 30000
        $resp = $req.GetResponse()
        try {
            $total = [double]$resp.ContentLength
            $in  = $resp.GetResponseStream()
            $out = [System.IO.File]::Create($zipPath)
            try {
                $buf = New-Object byte[] 65536; $done = 0
                while (($n = $in.Read($buf, 0, $buf.Length)) -gt 0) {
                    if ($State.Cancel) { throw "cancelled" }
                    $out.Write($buf, 0, $n); $done += $n
                    if ($total -gt 0) { $State.Progress = $done / $total }
                }
            } finally { $out.Dispose(); $in.Dispose() }
        } finally { $resp.Close() }

        $wc = New-Object System.Net.WebClient
        $wc.Headers['User-Agent'] = 'Preflight-Updater'
        $expected = (($wc.DownloadString($sha.browser_download_url).Trim()) -split '\s+')[0]
        $actual   = (Get-FileHash -Path $zipPath -Algorithm SHA256).Hash
        if ($actual -ne $expected.ToUpperInvariant()) { throw "The download didn't match its checksum." }

        # From here on the update can't be skipped: it either lands or is undone.
        if ($State.Cancel) { throw "cancelled" }
        $State.Phase = 'installing'
        $staging = Join-Path $UpdateDir "staging"
        if (Test-Path $staging) { Remove-Item $staging -Recurse -Force }
        Expand-Archive -Path $zipPath -DestinationPath $staging -Force
        $root = $staging
        if (-not (Test-Path (Join-Path $root "Preflight.ps1"))) {
            $inner = Get-ChildItem $staging -Directory | Where-Object { Test-Path (Join-Path $_.FullName "Preflight.ps1") } | Select-Object -First 1
            if (-not $inner) { throw "Preflight.zip doesn't contain Preflight.ps1." }
            $root = $inner.FullName
        }

        $parseErrors = $null
        [void][System.Management.Automation.Language.Parser]::ParseFile((Join-Path $root "Preflight.ps1"), [ref]$null, [ref]$parseErrors)
        if ($parseErrors -and $parseErrors.Count -gt 0) { throw "The new version has a script error, so it wasn't installed: $($parseErrors[0].Message)" }

        # Back up exactly the files this release will replace.
        $prev = Join-Path $UpdateDir "previous"
        if (Test-Path $prev) { Remove-Item $prev -Recurse -Force }
        New-Item -ItemType Directory -Path $prev -Force | Out-Null
        $rootFull = (Resolve-Path $root).Path.TrimEnd('\')
        foreach ($f in (Get-ChildItem $rootFull -Recurse -File -Force)) {
            $relPath = $f.FullName.Substring($rootFull.Length).TrimStart('\')
            $cur = Join-Path $AppRoot $relPath
            if (Test-Path -LiteralPath $cur) {
                $dest = Join-Path $prev $relPath
                $dir = Split-Path $dest -Parent
                if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
                Copy-Item -LiteralPath $cur -Destination $dest -Force
            }
        }

        try {
            Copy-PreflightTree -From $root -To $AppRoot
        } catch {
            try { Copy-PreflightTree -From $prev -To $AppRoot } catch {}
            throw "Couldn't write the new files to $AppRoot, so the current version was kept. ($($_.Exception.Message))"
        }

        Remove-Item $staging -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
        $State.Phase = 'installed'
    } catch {
        if ($State.Cancel) { $State.Phase = 'cancelled' }
        else { $State.Phase = 'failed'; $State.Error = $_.Exception.Message }
    }
}

function Start-UpdateWorker {
    $Script:UpdateState = [hashtable]::Synchronized(@{ Phase = 'checking'; Progress = 0.0; NewVersion = ''; Error = ''; Cancel = $false; Started = Get-Date })
    $rs = [runspacefactory]::CreateRunspace()
    $rs.ApartmentState = 'MTA'
    $rs.Open()
    $rs.SessionStateProxy.SetVariable('State',      $Script:UpdateState)
    $rs.SessionStateProxy.SetVariable('Repo',       $Script:Config.UpdateRepo)
    $rs.SessionStateProxy.SetVariable('Current',    $Script:AppVersion)
    $rs.SessionStateProxy.SetVariable('TimeoutSec', [int]$Script:Config.UpdateTimeoutSec)
    $rs.SessionStateProxy.SetVariable('UpdateDir',  $Script:UpdateDir)
    $rs.SessionStateProxy.SetVariable('AppRoot',    $Script:ScriptRoot)
    $rs.SessionStateProxy.SetVariable('CopyTreeFn', ${function:Copy-PreflightTree}.ToString())
    $ps = [powershell]::Create()
    $ps.Runspace = $rs
    [void]$ps.AddScript($Script:UpdateWorker)
    $Script:UpdateRunspace = $rs
    $Script:UpdatePs       = $ps
    [void]$ps.BeginInvoke()
}

function Stop-UpdateWorker {
    # A worker still waiting on the network is told to stop without waiting
    # for it (Dispose would block the UI until the request times out).
    try {
        if ($Script:UpdatePs) {
            if ($Script:UpdatePs.InvocationStateInfo.State -eq 'Running') { [void]$Script:UpdatePs.BeginStop($null, $null) }
            else { $Script:UpdatePs.Dispose(); $Script:UpdateRunspace.Dispose() }
        }
    } catch {}
    $Script:UpdatePs = $null; $Script:UpdateRunspace = $null
}

function Set-UpdateWaitAnimation {
    # st-wait: two rings spread out from the art circle. Off when Windows
    # "Show animations" is off (reduced motion).
    param([bool]$On)
    foreach ($pair in @(@{ Ring = $Script:updRing1; Delay = 0 }, @{ Ring = $Script:updRing2; Delay = 1.2 })) {
        $ring = $pair.Ring
        if ($On -and [System.Windows.SystemParameters]::ClientAreaAnimation) {
            $dur = [System.Windows.Duration]::new([TimeSpan]::FromSeconds(2.4))
            $grow = New-Object System.Windows.Media.Animation.DoubleAnimation(1.0, 1.6, $dur)
            $fade = New-Object System.Windows.Media.Animation.DoubleAnimation(0.6, 0.0, $dur)
            foreach ($a in @($grow, $fade)) {
                $a.RepeatBehavior = [System.Windows.Media.Animation.RepeatBehavior]::Forever
                $a.BeginTime = [TimeSpan]::FromSeconds($pair.Delay)
            }
            $ring.RenderTransform.BeginAnimation([System.Windows.Media.ScaleTransform]::ScaleXProperty, $grow)
            $ring.RenderTransform.BeginAnimation([System.Windows.Media.ScaleTransform]::ScaleYProperty, $grow)
            $ring.BeginAnimation([System.Windows.UIElement]::OpacityProperty, $fade)
        } else {
            $ring.RenderTransform.BeginAnimation([System.Windows.Media.ScaleTransform]::ScaleXProperty, $null)
            $ring.RenderTransform.BeginAnimation([System.Windows.Media.ScaleTransform]::ScaleYProperty, $null)
            $ring.BeginAnimation([System.Windows.UIElement]::OpacityProperty, $null)
            $ring.Opacity = 0
        }
    }
}

function Complete-UpdateCheck {
    # Leaves the update screen and carries on with the normal start.
    if ($Script:UpdateFlowDone) { return }
    $Script:UpdateFlowDone = $true
    if ($Script:updateTimer) { $Script:updateTimer.Stop() }
    Set-UpdateWaitAnimation $false
    $Script:updateOverlay.Visibility = 'Collapsed'
    if ($Script:NeedsInitialSetup) { Show-InitialSetup } else { Start-PreflightFlow }
}

function Start-UpdateCheck {
    # $FromSettings: started by "Check now" -- the startup flow is already
    # running, so an up-to-date result just reports back instead of continuing.
    param([switch]$FromSettings)
    $repoOk = "$($Script:Config.UpdateRepo)" -match '^[\w.-]+/[\w.-]+$'
    if (-not $FromSettings -and ($JustUpdated -or -not $Script:Config.AutoUpdate -or -not $repoOk)) {
        $Script:UpdateLastResult = if ($JustUpdated) { "Updated to version $($Script:AppVersion) just now." }
                                   elseif (-not $repoOk) { "No GitHub repository is set, so updates are off." }
                                   else { "Automatic updates are off." }
        Complete-UpdateCheck
        return
    }
    if (-not $repoOk) { $Script:updStatusText.Text = "Enter the repository as owner/name, then Save."; return }

    $Script:UpdateFromSettings = [bool]$FromSettings
    $Script:UpdateOriginSettings = [bool]$FromSettings
    if ($FromSettings) {
        $Script:btnUpdCheckNow.IsEnabled = $false
        $Script:updStatusText.Text = "Checking..."
    } else {
        $Script:updTitle.Text  = "Checking for updates"
        $Script:updDetail.Text = "This takes a few seconds."
        $Script:updateOverlay.Visibility = 'Visible'
        Set-UpdateWaitAnimation $true
    }
    Write-Log "Update check: $($Script:Config.UpdateRepo), this is v$($Script:AppVersion)."
    Start-UpdateWorker

    $Script:updateTimer = New-Object System.Windows.Threading.DispatcherTimer
    $Script:updateTimer.Interval = [TimeSpan]::FromMilliseconds(150)
    $Script:updateTimer.Add_Tick({ Update-UpdateProgress })
    $Script:updateTimer.Start()
}

function Update-UpdateProgress {
    $st = $Script:UpdateState
    $elapsed = ((Get-Date) - $st.Started).TotalSeconds
    $stamp = Get-Date -Format "h:mm tt"

    # A slow network must never hold up the meeting: give up on the check
    # (not on a download already under way) after the timeout.
    if ($st.Phase -eq 'checking' -and $elapsed -gt ([int]$Script:Config.UpdateTimeoutSec + 2)) {
        $st.Cancel = $true
        $Script:UpdateLastResult = "Couldn't reach GitHub at $stamp. Preflight will try again next time."
        Write-Log "Update check timed out." "WARN"
        Finish-UpdateCheck
        return
    }

    switch ($st.Phase) {
        'downloading' {
            if ($Script:UpdateFromSettings) {
                $Script:settingsOverlay.Visibility = 'Collapsed'
                $Script:updateOverlay.Visibility   = 'Visible'
                Set-UpdateWaitAnimation $true
                $Script:UpdateFromSettings = $false
            }
            $pct = [int]([double]$st.Progress * 100)
            $Script:updTitle.Text  = "Downloading version $($st.NewVersion)"
            $Script:updDetail.Text = "$pct%"
            $Script:updProgressTrack.Visibility = 'Visible'
            $Script:updProgressFill.Width = [Math]::Max(0, $Script:updProgressTrack.ActualWidth * [double]$st.Progress)
        }
        'installing' {
            $Script:updTitle.Text  = "Installing version $($st.NewVersion)"
            $Script:updDetail.Text = "Please keep the laptop on."
            $Script:updProgressFill.Width = $Script:updProgressTrack.ActualWidth
            $Script:btnUpdSkip.Visibility = 'Hidden'
        }
        'installed' {
            $Script:updateTimer.Stop()
            Write-Log "Update installed: v$($Script:AppVersion) -> v$($st.NewVersion)."
            $Script:updTitle.Text  = "Updated to version $($st.NewVersion)"
            $Script:updDetail.Text = "Restarting Preflight..."
            $restart = New-Object System.Windows.Threading.DispatcherTimer
            $restart.Interval = [TimeSpan]::FromMilliseconds(900)
            $restart.Add_Tick({
                param($s, $e)
                $s.Stop()
                Stop-UpdateWorker
                Restart-Preflight -JustUpdated
                $Script:window.Close()
            })
            $restart.Start()
        }
        'uptodate' {
            $Script:UpdateLastResult = "Up to date. Checked at $stamp."
            Write-Log "Update check: up to date (latest release v$($st.NewVersion))."
            Finish-UpdateCheck
        }
        'failed' {
            $Script:UpdateLastResult = "Couldn't update at $stamp. $($st.Error)"
            Write-Log "Update failed: $($st.Error)" "WARN"
            Finish-UpdateCheck
        }
        'cancelled' {
            $Script:UpdateLastResult = "Update skipped at $stamp."
            Finish-UpdateCheck
        }
    }
}

function Finish-UpdateCheck {
    # Up to date, failed or skipped: report it and carry on with this version.
    $Script:updateTimer.Stop()
    Stop-UpdateWorker
    $Script:updProgressTrack.Visibility = 'Hidden'
    $Script:btnUpdCheckNow.IsEnabled = $true
    $Script:updStatusText.Text = $Script:UpdateLastResult
    if ($Script:UpdateFlowDone) {
        # "Check now" from Settings: the startup flow is already running.
        Set-UpdateWaitAnimation $false
        $Script:updateOverlay.Visibility = 'Collapsed'
        if ($Script:UpdateOriginSettings) { $Script:settingsOverlay.Visibility = 'Visible' }
    } else {
        Complete-UpdateCheck
    }
}

$Script:btnUpdSkip.Add_Click({
    if ($Script:UpdateState -and $Script:UpdateState.Phase -in @('checking', 'downloading')) {
        $Script:UpdateState.Cancel = $true
        $Script:UpdateLastResult = "Update skipped at $(Get-Date -Format 'h:mm tt')."
        Write-Log "Operator skipped the update check."
        Finish-UpdateCheck
    } elseif (-not $Script:UpdateState) {
        Complete-UpdateCheck
    }
})

# =============================================================================
#  EVENT WIRING
# =============================================================================

$Script:btnOpenInternet.Add_Click({ Open-NetworkSettings })
$Script:btnOpenWebcam.Add_Click({   Open-DeviceManager   })

function Enter-RegularMeetingFlow {
    $Script:State.Flow = "Regular"
    $Script:Sections = @(
        @{ Id = "zoom";      Name = "Zoom Setup";      Type = "video"; Questions = $Script:ZoomQuestionsHost }
        @{ Id = "equipment"; Name = "Equipment Check"; Type = "photo"; Questions = $Script:EquipmentQuestionsRegular }
    )
    $Script:State.SectionIdx  = 0
    $Script:State.QuestionIdx = 0
    Build-DetCards
    if ($Script:Config.ZoomSelfHostingMode) {
        $Script:State.ZoomMode = "Host"
        Show-Screen "ScreenQuestion"
        Show-CurrentQuestion
    } else {
        Show-Screen "ScreenZoomChoice"
    }
}

function Enter-NonZoomMeetingFlow {
    $Script:State.Flow = "NonZoom"
    $Script:Sections = @(
        @{ Id = "equipment"; Name = "Equipment Check"; Type = "photo"; Questions = $Script:EquipmentQuestionsNonZoom }
    )
    $Script:State.SectionIdx  = 0
    $Script:State.QuestionIdx = 0
    Build-DetCards
    Start-EquipmentSection
}

function Reset-PreflightState {
    Write-Log "=== Start Over -- resetting ==="
    if ($Script:detectionTimer) { $Script:detectionTimer.Stop() }
    if ($Script:videoPlayer)    { $Script:videoPlayer.Stop(); $Script:videoPlayer.Source = $null }

    $Script:State.SectionIdx       = 0
    $Script:State.QuestionIdx      = 0
    $Script:State.CurrentVideo     = ""
    $Script:State.AllHwReady       = $false
    $Script:State.AutoLaunched     = $false
    $Script:State.ZoomMode         = ""
    $Script:State.Flow             = "Regular"
    $Script:State.NonZoomProgram   = ""
    $Script:State.BluetoothConfirmed = $false
    $Script:State.EmeetVcamEnabled    = $false

    $Script:Sections = @(
        @{ Id = "zoom";      Name = "Zoom Setup";      Type = "video"; Questions = $Script:ZoomQuestionsHost }
        @{ Id = "equipment"; Name = "Equipment Check"; Type = "photo"; Questions = $Script:EquipmentQuestionsRegular }
    )
    Build-DetCards

    $Script:detReadyPanel.Visibility        = 'Collapsed'
    $Script:launchButton.Visibility         = 'Collapsed'
    $Script:launchButton.IsEnabled          = $true
    $Script:settingUpOverlay.Visibility     = 'Collapsed'
    $Script:confirmActionOverlay.Visibility = 'Collapsed'
    $Script:btnStartOver.Visibility         = 'Collapsed'
    $Script:window.Topmost = $true

    Show-Screen ""
    $Script:welcomeOverlay.Visibility = 'Visible'
}

$Script:btnStartOver.Add_Click({ Reset-PreflightState })

$Script:btnWelcomeStart.Add_Click({
    $Script:welcomeOverlay.Visibility = 'Collapsed'
    $Script:btnStartOver.Visibility   = 'Visible'
    if ($Script:Config.AdminMode) { Show-Screen "ScreenUseCase" }
    else                          { Enter-RegularMeetingFlow    }
})

$Script:btnUseCaseRegular.Add_Click({
    $bullets = @("Hosts Midweek and Weekend Meetings.", "Applies default audio and visual setup.")
    $bullets += "Configures Zoom, OBS, and Meeting Media Manager."
    Show-ConfirmAction -Header "Set this laptop up for a Regular Meeting?" -Bullets $bullets `
        -OnConfirm { Enter-RegularMeetingFlow } -OnCancel { Show-Screen "ScreenUseCase" }
})

$Script:btnUseCaseNonZoom.Add_Click({
    Show-ConfirmAction -Header "Set this laptop up for a Non-Zoom Meeting?" -Bullets @(
        "Displays media for PSS, SCE, Pioneer's, and Elders and MS meetings."
        "Ideal for any gathering that does not require Zoom."
        "Configures the laptop specifically for local/offline use."
    ) -OnConfirm { Enter-NonZoomMeetingFlow } -OnCancel { Show-Screen "ScreenUseCase" }
})

$Script:btnConfirmActionYes.Add_Click({
    $Script:confirmActionOverlay.Visibility = 'Collapsed'
    if ($Script:PendingConfirmYes) { & $Script:PendingConfirmYes }
})
$Script:btnConfirmActionBack.Add_Click({
    $Script:confirmActionOverlay.Visibility = 'Collapsed'
    if ($Script:PendingConfirmCancel) { & $Script:PendingConfirmCancel }
})

$Script:btnProgramM3.Add_Click({
    Show-ConfirmAction -Header "Use Meeting Media Manager for today?" -Bullets @(
        "Meeting Media Manager will be the only program preflight launches."
    ) -OnConfirm { $Script:State.NonZoomProgram = "M3"; Show-DetectionScreen } `
      -OnCancel  { Show-Screen "ScreenProgramChoice" }
})

$Script:btnProgramJwLibrary.Add_Click({
    Show-ConfirmAction -Header "Use JW Library for today?" -Bullets @(
        "JW Library will be the only program preflight launches."
    ) -OnConfirm { $Script:State.NonZoomProgram = "JWLibrary"; Show-DetectionScreen } `
      -OnCancel  { Show-Screen "ScreenProgramChoice" }
})

$Script:btnZoomModeHost.Add_Click({
    $Script:State.ZoomMode = "Host"
    $Script:Sections[0].Questions = $Script:ZoomQuestionsHost
    $Script:zoomIntroHeading.Text = "First, let's start Zoom"
    $Script:zoomIntroSubtext.Text = "• Click Open Zoom below`n• Start today's meeting`n• Come back here once it has started"
    Show-Screen "ScreenZoomIntro"
})

$Script:btnZoomModeJoin.Add_Click({
    $Script:State.ZoomMode = "Join"
    $Script:Sections[0].Questions = $Script:ZoomQuestionsJoin
    $Script:zoomIntroHeading.Text = "First, let's join Zoom"
    $Script:zoomIntroSubtext.Text = "• Click Open Zoom below`n• Join today's meeting`n• Come back here once you've joined"
    Show-Screen "ScreenZoomIntro"
})

$Script:btnOpenZoomIntro.Add_Click({
    $Script:btnOpenZoomIntro.IsEnabled = $false
    $Script:zoomIntroSubtext.Text = "Opening Zoom..."
    $Script:window.Topmost = $false
    try {
        $already = Get-Process -Name "Zoom" -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 }
        if (-not $already -and (Test-Path $Script:Config.ZoomPath)) {
            Start-Process -FilePath $Script:Config.ZoomPath -ErrorAction SilentlyContinue
            Write-Log "Zoom launched from intro screen."
            Start-Sleep -Milliseconds $Script:Config.ZoomActivationWait
        }
        $zp = Find-AppMainWindow -ProcessNames $Script:Config.ZoomProcessNames -TimeoutSeconds 20
        if ($zp) {
            [Win32Native]::AllowSetForegroundWindow([Win32Native]::ASFW_ANY) | Out-Null
            [Win32Native]::SetForegroundWindow($zp.MainWindowHandle) | Out-Null
            Start-Sleep -Milliseconds $Script:Config.ZoomFocusSettle
            $zh = $Script:Config.ZoomHome
            Move-AppWindow -ProcessNames $Script:Config.ZoomProcessNames -DisplayName "Zoom (home)" `
                           -X $zh.X -Y $zh.Y -W $zh.W -H $zh.H
            $Script:zoomIntroSubtext.Text = if ($Script:State.ZoomMode -eq "Join") {
                "• Join today's meeting from the Zoom window`n• Come back here once you've joined"
            } else {
                "• Start today's meeting from the Zoom window`n• Come back here once it has started"
            }
            $Script:btnZoomIntroContinue.Visibility = 'Visible'
        } else {
            Write-Log "Zoom window not found from intro screen." "WARN"
            $Script:zoomIntroSubtext.Text = "Couldn't find Zoom. Open it manually, then continue."
            $Script:btnZoomIntroContinue.Visibility = 'Visible'
        }
    } finally { $Script:btnOpenZoomIntro.IsEnabled = $true }
})

$Script:btnZoomIntroContinue.Add_Click({
    Show-Screen "ScreenQuestion"
    Show-CurrentQuestion
})

$Script:btnYes.Add_Click({    Advance-Question })
$Script:btnYesEq.Add_Click({  Advance-Question })
$Script:btnShowHow.Add_Click({ Open-MediaVideo })

$Script:btnCloseVideo.Add_Click({
    $Script:videoPlayer.Stop()
    $Script:videoPlayer.Source = $null
    Show-Screen "ScreenQuestion"
    Write-Log "Video closed."
})

$Script:videoPlayer.Add_MediaEnded({
    $Script:videoPlayer.Stop()
    $Script:confirmText.Text = $Script:Sections[$Script:State.SectionIdx].Questions[$Script:State.QuestionIdx].Text
    Show-Screen "ScreenConfirm"
    Write-Log "Video ended -- confirm screen."
})

$Script:videoPlayer.Add_MediaFailed({
    param($s, $e)
    $Script:videoPlayer.Source = $null
    Write-Log "MediaFailed: $($e.ErrorException.Message)" "ERROR"
    Show-Screen "ScreenQuestion"
    $Script:videoErrorText.Text       = "Video could not be played — check the file in the media folder."
    $Script:videoErrorText.Visibility = 'Visible'
    $errTimer = New-Object System.Windows.Threading.DispatcherTimer
    $errTimer.Interval = [TimeSpan]::FromMilliseconds($Script:Config.VideoErrorHold)
    $errTimer.Add_Tick({ $errTimer.Stop(); $Script:videoErrorText.Visibility = 'Collapsed' })
    $errTimer.Start()
})

$Script:btnConfirmYes.Add_Click({ Advance-Question })
$Script:btnWatchAgain.Add_Click({
    if ($Script:State.CurrentVideo -and (Test-Path $Script:State.CurrentVideo)) {
        $Script:videoPlayer.Source = [Uri]::new($Script:State.CurrentVideo)
        $Script:videoPlayer.Play()
        Show-Screen "ScreenVideo"
        Write-Log "Replaying video."
    }
})

$Script:radioMidweek.Add_Checked({ Set-MeetingTypeBadge "Midweek"; Update-LaunchVisibility })
$Script:radioWeekend.Add_Checked({ Set-MeetingTypeBadge "Weekend"; Update-LaunchVisibility })

$Script:btnBackToEquipment.Add_Click({
    $Script:detectionTimer.Stop()
    $Script:State.SectionIdx  = $Script:Sections.Count - 1
    $Script:State.QuestionIdx = 0
    $Script:State.AllHwReady  = $false
    Show-CurrentQuestion
    Write-Log "Operator returned to Equipment Check."
})

# ----- Setup Wizard buttons ---------------------------------------------------
$Script:setupObsScenes.Add_Click({
    $Script:setupObsSceneNamesPanel.Visibility = if ($Script:setupObsScenes.IsChecked -eq $true) { 'Visible' } else { 'Collapsed' }
})

$Script:btnSetupFinish.Add_Click({
    $Script:Config.CongregationName    = $Script:setupCongregationName.Text.Trim()
    $Script:Config.ZoomSelfHostingMode = [bool]$Script:setupZoomHosting.IsChecked
    $Script:Config.ObsDynamicSceneMode = [bool]$Script:setupObsScenes.IsChecked
    if ($Script:Config.ObsDynamicSceneMode) {
        $Script:Config.ObsSceneWeekend = $Script:setupObsSceneWeekend.Text.Trim()
        $Script:Config.ObsSceneMidweek = $Script:setupObsSceneMidweek.Text.Trim()
    }

    Export-PreflightConfig -Path $Script:ConfigFile
    $Script:NeedsInitialSetup = $false
    Write-Log "Initial setup complete."

    $Script:setupOverlay.Visibility   = 'Collapsed'
    $Script:welcomeOverlay.Visibility = 'Visible'
    Start-PreflightFlow
})

# ----- Settings Menu buttons --------------------------------------------------
$Script:btnSettings.Add_Click({ Show-SettingsMenu })
$Script:btnSettingsClose.Add_Click({ $Script:settingsOverlay.Visibility = 'Collapsed' })
$Script:btnSettingsCancel.Add_Click({ $Script:settingsOverlay.Visibility = 'Collapsed' })
$Script:navGeneral.Add_Checked({  Show-SettingsTab "General" })
$Script:navLayout.Add_Checked({   Show-SettingsTab "Layout" })
$Script:navUpdates.Add_Checked({  Show-SettingsTab "Updates" })
$Script:navAdvanced.Add_Checked({ Show-SettingsTab "Advanced" })

# Window layout editor
$Script:btnLayoutResetMode.Add_Click({ Reset-LayoutToDefaults })
$Script:btnCapturePositions.Add_Click({ Invoke-CaptureCurrentPositions })
$Script:btnLayoutTryNow.Add_Click({ Invoke-LayoutTryNow })
$Script:btnLayoutPresetTileLeft.Add_Click({   Invoke-LayoutPreset "TileLeft" })
$Script:btnLayoutPresetTileRight.Add_Click({  Invoke-LayoutPreset "TileRight" })
$Script:btnLayoutPresetCenter.Add_Click({     Invoke-LayoutPreset "Center" })
$Script:btnLayoutPresetFullscreen.Add_Click({ Invoke-LayoutPreset "Fullscreen" })
$Script:btnLayoutEarlier.Add_Click({ if ($Script:LayoutSelected) { Move-LayoutRow -App $Script:LayoutSelected -Direction -1 } })
$Script:btnLayoutLater.Add_Click({   if ($Script:LayoutSelected) { Move-LayoutRow -App $Script:LayoutSelected -Direction 1 } })

# Inspector boxes commit on Enter or when focus leaves; the field name rides in Tag.
$Script:OnLayoutFieldLostFocus = { param($s, $e) Set-LayoutField -Field $s.Tag -Text $s.Text }
$Script:OnLayoutFieldKeyDown   = {
    param($s, $e)
    if ($e.Key -eq [System.Windows.Input.Key]::Enter) { Set-LayoutField -Field $s.Tag -Text $s.Text; $s.SelectAll() }
}
foreach ($pair in @(
    @{ Box = $Script:layoutX; Field = 'X' }, @{ Box = $Script:layoutY; Field = 'Y' }
    @{ Box = $Script:layoutW; Field = 'W' }, @{ Box = $Script:layoutH; Field = 'H' }
    @{ Box = $Script:layoutDelay; Field = 'DelayMs' }
)) {
    $pair.Box.Tag = $pair.Field
    $pair.Box.Add_LostFocus($Script:OnLayoutFieldLostFocus)
    $pair.Box.Add_KeyDown($Script:OnLayoutFieldKeyDown)
}

# Updates
$Script:btnUpdCheckNow.Add_Click({ Start-UpdateCheck -FromSettings })

$Script:setObsScenes.Add_Click({
    $Script:setObsSceneNamesPanel.Visibility = if ($Script:setObsScenes.IsChecked -eq $true) { 'Visible' } else { 'Collapsed' }
})

$Script:btnSettingsSave.Add_Click({
    # Commit an inspector box the operator is still typing in.
    $focused = [System.Windows.Input.Keyboard]::FocusedElement
    if ($focused -is [System.Windows.Controls.TextBox] -and $focused.Tag -in @('X','Y','W','H','DelayMs')) {
        Set-LayoutField -Field $focused.Tag -Text $focused.Text
    }

    $repo = $Script:setUpdateRepo.Text.Trim()
    if ($repo -and $repo -notmatch '^[\w.-]+/[\w.-]+$') {
        Show-SettingsTab "Updates"
        $Script:updStatusText.Text = "Write the repository as owner/name, for example carl-gian/Project-Preflight."
        return
    }

    $updates = @{
        CongregationName    = $Script:setCongregationName.Text.Trim()
        ZoomSelfHostingMode = [bool]$Script:setZoomHosting.IsChecked
        ObsDynamicSceneMode = [bool]$Script:setObsScenes.IsChecked
        ObsSceneWeekend     = $Script:setObsSceneWeekend.Text.Trim()
        ObsSceneMidweek     = $Script:setObsSceneMidweek.Text.Trim()
        AutoUpdate          = [bool]$Script:setAutoUpdate.IsChecked
        UpdateRepo          = $repo
    }
    foreach ($key in $Script:AdvancedControls.Keys) {
        $ctrl = $Script:AdvancedControls[$key]
        $updates[$key] = if ($ctrl -is [System.Windows.Controls.CheckBox]) { [bool]$ctrl.IsChecked } else { $ctrl.Text.Trim() }
    }

    foreach ($key in $updates.Keys) { $Script:Config[$key] = $updates[$key] }
    Set-StartWithWindows ([bool]$Script:setStartWithWindows.IsChecked)

    # Save the layout only if the editor was opened this time.
    foreach ($modeName in @($Script:LayoutEditorRowsByMode.Keys)) {
        try {
            Save-PreflightLayoutMode -ModeName $modeName -Rows $Script:LayoutEditorRowsByMode[$modeName]
        } catch {
            Write-Log "Error saving layout for $modeName`: $($_.Exception.Message)" "WARN"
        }
    }
    $Script:LayoutOverrides = Import-PreflightLayoutOverrides -Path $Script:LayoutFile

    $Script:settingsOverlay.Visibility   = 'Collapsed'
    Set-SetupStatus "Saving your settings..." ""
    $Script:settingUpOverlay.Visibility  = 'Visible'
    Start-Sleep -Milliseconds 700

    if ($Script:NeedsInitialSetup) {
        Export-PreflightConfig -Path $Script:ConfigFile
        $Script:NeedsInitialSetup = $false
    } else {
        Update-PreflightConfigFile -Updates $updates -Path $Script:ConfigFile
    }

    $Script:settingUpOverlay.Visibility = 'Collapsed'
    $Script:restartOverlay.Visibility   = 'Visible'
})

$Script:btnRestartNow.Add_Click({
    Write-Log "Restarting Preflight to apply new settings."
    Restart-Preflight
    $Script:window.Close()
})

$Script:btnRestartLater.Add_Click({
    $Script:restartOverlay.Visibility = 'Collapsed'
})

function Invoke-Launch {
    $Script:launchButton.IsEnabled = $false
    $Script:detectionTimer.Stop()
    $Script:settingUpOverlay.Visibility = 'Visible'
    $Script:window.Dispatcher.Invoke([action]{}, [System.Windows.Threading.DispatcherPriority]::Render)
    try { Start-Launch } catch { Write-Log "Launch error: $($_.Exception.Message)" "ERROR" }
    $Script:window.Close()
}

$Script:launchButton.Add_Click({ Invoke-Launch })

$Script:window.Add_KeyDown({
    param($s, $e)
    if ($e.Key -eq [System.Windows.Input.Key]::S) {
        $mods = [System.Windows.Input.Keyboard]::Modifiers
        $cs   = [System.Windows.Input.ModifierKeys]::Control -bor [System.Windows.Input.ModifierKeys]::Shift
        if (($mods -band $cs) -eq $cs) {
            Write-Log "Admin escape (Ctrl+Shift+S)."
            $Script:window.Close()
        }
    }
})

# ----- TIMERS ----------------------------------------------------------------
$Script:detectionTimer          = New-Object System.Windows.Threading.DispatcherTimer
$Script:detectionTimer.Interval = [TimeSpan]::FromMilliseconds($Script:Config.UiRefreshMs)
$Script:detectionTimer.Add_Tick({ Update-Detection })

$Script:clockTimer          = New-Object System.Windows.Threading.DispatcherTimer
$Script:clockTimer.Interval = [TimeSpan]::FromSeconds(1)
$Script:clockTimer.Add_Tick({ $Script:clockText.Text = (Get-Date -Format "h:mm tt") })

$Script:btRestartTimer          = New-Object System.Windows.Threading.DispatcherTimer
$Script:btRestartTimer.Interval = [TimeSpan]::FromSeconds(5)
$Script:btRestartTimer.Add_Tick({
    $Script:btRestartTimer.Stop()
    $Script:btRestartingPanel.Visibility = 'Collapsed'
    $Script:btSubQ2Panel.Visibility      = 'Visible'
    $Script:btCheckStatusText.Visibility = 'Collapsed'
    Write-Log "Bluetooth setup: restart complete -- back to connect sub-question."
})

$Script:window.Add_Closed({
    Stop-HardwarePolling
    if ($Script:detectionTimer) { $Script:detectionTimer.Stop() }
    if ($Script:clockTimer)     { $Script:clockTimer.Stop() }
    if ($Script:btRestartTimer) { $Script:btRestartTimer.Stop() }
    Write-Log "=== Audio-Video Preflight closed ==="
})

$Script:window.Add_ContentRendered({
    if ($Script:Config.TestMode) { $Script:testModeBanner.Visibility = 'Visible' }
    $Script:clockText.Text = (Get-Date -Format "h:mm tt")
    $Script:clockTimer.Start()

    # The update check runs first; it then opens the setup wizard or the
    # welcome page (Complete-UpdateCheck).
    Start-UpdateCheck
})

# =============================================================================
#  START
# =============================================================================
[void]$Script:window.ShowDialog()