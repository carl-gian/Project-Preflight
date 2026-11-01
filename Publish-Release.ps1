<#
  Packages a Preflight release for the auto-updater.

  1. Bump $Script:AppVersion near the top of Preflight.ps1 (e.g. 5.6.0 -> 5.6.1).
  2. Run:  pwsh ./Publish-Release.ps1            (builds dist/ only)
     or:   pwsh ./Publish-Release.ps1 -Publish   (also creates the GitHub release with the gh CLI)

  Every laptop running an older version installs it the next time Preflight starts.
  Personal settings (Documents\Preflight Settings) are never in the package.
#>
param(
    [switch]$Publish,
    [string]$Repo = "carl-gian/Project-Preflight",
    [string]$Notes = ""
)
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$dist = Join-Path $root "dist"

# The script must parse, or every laptop would refuse the update anyway.
$errors = $null
[void][System.Management.Automation.Language.Parser]::ParseFile((Join-Path $root "Preflight.ps1"), [ref]$null, [ref]$errors)
if ($errors) { throw "Preflight.ps1 has errors; fix them first: $($errors[0].Extent.StartLineNumber): $($errors[0].Message)" }

$text = Get-Content (Join-Path $root "Preflight.ps1") -Raw
if ($text -notmatch '\$Script:AppVersion\s*=\s*\[version\]"([\d.]+)"') { throw "Couldn't find `$Script:AppVersion in Preflight.ps1." }
$version = $Matches[1]
$tag = "v$version"

# What ships: the script, the launcher and the media folder. Nothing personal.
$files = @("Preflight.ps1", "Preflight.exe")
$files += Get-ChildItem (Join-Path $root "media") -Recurse -File |
          Where-Object { $_.Name -notin @('.DS_Store', 'Thumbs.db', 'desktop.ini') } |
          ForEach-Object { [System.IO.Path]::GetRelativePath($root, $_.FullName) }
foreach ($f in $files) { if (-not (Test-Path (Join-Path $root $f))) { throw "Missing $f" } }

if (Test-Path $dist) { Remove-Item $dist -Recurse -Force }
New-Item -ItemType Directory -Path $dist | Out-Null
$zipPath = Join-Path $dist "Preflight.zip"

Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem
$zip = [System.IO.Compression.ZipFile]::Open($zipPath, 'Create')
try {
    foreach ($f in $files) {
        $entry = $f -replace '\\', '/'
        [void][System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, (Join-Path $root $f), $entry, 'Optimal')
    }
} finally { $zip.Dispose() }

$hash = (Get-FileHash $zipPath -Algorithm SHA256).Hash
Set-Content -Path "$zipPath.sha256" -Value "$hash  Preflight.zip" -NoNewline
Write-Host "Built $tag : $($files.Count) files, $([math]::Round((Get-Item $zipPath).Length / 1MB, 1)) MB"
Write-Host "  $zipPath"
Write-Host "  $zipPath.sha256"

if (-not $Publish) {
    Write-Host ""
    Write-Host "To release it, create a GitHub release on $Repo tagged $tag and attach both files,"
    Write-Host "or run this script again with -Publish (needs the gh CLI, signed in)."
    return
}

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) { throw "The gh CLI isn't installed. Install it, or upload the two files by hand." }
if (-not $Notes) { $Notes = "Preflight $version" }
gh release create $tag $zipPath "$zipPath.sha256" --repo $Repo --title "Preflight $version" --notes $Notes
if ($LASTEXITCODE -ne 0) { throw "gh release create failed." }
Write-Host "Released $tag. Laptops update the next time Preflight starts."
