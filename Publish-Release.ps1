<#
  Builds and (optionally) publishes a Preflight release.

  1. Bump $Script:AppVersion near the top of Preflight.ps1 (e.g. 5.6.1 -> 5.6.2).
  2. Add a "## [5.6.2] - date" section to CHANGELOG.md.
  3. Run:  pwsh ./Publish-Release.ps1            (builds dist/ only)
     or:   pwsh ./Publish-Release.ps1 -Publish   (also creates the GitHub release)

  dist/ gets:
    Preflight.zip, Preflight.zip.sha256   what laptops download when they update themselves
    PreflightSetup.exe                    the installer, for first-time installs (needs makensis)

  -Publish signs in with $env:GH_TOKEN, or else the GitHub sign-in git already has saved.
  The release notes are the version's section of CHANGELOG.md.
  Personal settings (Documents\Preflight Settings) are never in any package.
#>
param(
    [switch]$Publish,
    [string]$Repo = "carl-gian/Project-Preflight"
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

# ----- Update package ----------------------------------------------------------
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
$assets = @($zipPath, "$zipPath.sha256")
Write-Host "Built $tag : $($files.Count) files, $([math]::Round((Get-Item $zipPath).Length / 1MB, 1)) MB"

# ----- Installer ---------------------------------------------------------------
$setupPath = Join-Path $dist "PreflightSetup.exe"
if (Get-Command makensis -ErrorAction SilentlyContinue) {
    # makensis crashes under the plain "C" locale, so give it UTF-8.
    $env:LC_ALL = 'en_US.UTF-8'; $env:LANG = 'en_US.UTF-8'
    Push-Location (Join-Path $root "installer")
    try {
        $out = & makensis -V2 "-DVERSION=$version" "-DOUTFILE=$setupPath" "Preflight.nsi" 2>&1
        if ($LASTEXITCODE -ne 0) { $out | Write-Host; throw "makensis failed." }
    } finally { Pop-Location }
    $assets += $setupPath
    Write-Host "Built installer: $([math]::Round((Get-Item $setupPath).Length / 1MB, 1)) MB"
} else {
    Write-Warning "makensis isn't installed, so there's no installer this time (on a Mac: brew install makensis)."
}
$assets | ForEach-Object { Write-Host "  $_" }

if (-not $Publish) {
    Write-Host ""
    Write-Host "To release it, run this again with -Publish, or create a GitHub release on $Repo"
    Write-Host "tagged $tag and attach the files above."
    return
}

# ----- Publish -----------------------------------------------------------------
$changelog = Get-Content (Join-Path $root "CHANGELOG.md") -Raw
$section = [regex]::Match($changelog, "(?ms)^## \[$([regex]::Escape($version))\][^\n]*\n(.*?)(?=^## \[|\z)")
if (-not $section.Success) { throw "CHANGELOG.md has no '## [$version]' section. Add one first." }
$notes = "**New laptop?** Download **PreflightSetup.exe** below and run it. Laptops that already have Preflight " +
         "update by themselves the next time it starts.`n`n" + $section.Groups[1].Value.Trim() +
         "`n`n---`n``Preflight.zip`` and ``Preflight.zip.sha256`` are what the updater uses. Keep them attached."

$token = $env:GH_TOKEN
if (-not $token) {
    $cred = "protocol=https`nhost=github.com`n`n" | git credential fill 2>$null
    $token = ($cred | Where-Object { $_ -like 'password=*' }) -replace '^password=', ''
}
if (-not $token) { throw "No GitHub sign-in found. Set GH_TOKEN, or sign in to GitHub with git once." }
$headers = @{ Authorization = "Bearer $token"; Accept = 'application/vnd.github+json'; 'User-Agent' = 'preflight-release' }

$exists = $true
try { Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo/releases/tags/$tag" -Headers $headers | Out-Null }
catch { if ($_.Exception.Response.StatusCode.value__ -eq 404) { $exists = $false } else { throw } }
if ($exists) { throw "Release $tag already exists. Bump the version in Preflight.ps1 first." }

$body = @{ tag_name = $tag; target_commitish = 'main'; name = "Preflight $version"; body = $notes
           draft = $false; prerelease = $false; make_latest = 'true' } | ConvertTo-Json
$release = Invoke-RestMethod -Method Post -Uri "https://api.github.com/repos/$Repo/releases" -Headers $headers -Body $body -ContentType 'application/json'
$uploadUrl = $release.upload_url -replace '\{.*$', ''
foreach ($a in $assets) {
    $name = Split-Path $a -Leaf
    $type = switch -Wildcard ($name) { '*.zip' { 'application/zip' } '*.exe' { 'application/vnd.microsoft.portable-executable' } default { 'text/plain' } }
    $up = Invoke-RestMethod -Method Post -Uri "$uploadUrl`?name=$name" -Headers $headers -InFile $a -ContentType $type
    Write-Host "Uploaded $($up.name) ($([math]::Round($up.size / 1KB)) KB)"
}
Write-Host "Released $tag : $($release.html_url)"
Write-Host "Laptops update the next time Preflight starts."
