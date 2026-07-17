$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

Write-Host "=== Flutter Windows setup ==="

$flutterRoot = "C:\Users\avidu\flutter"
$zip = "C:\Users\avidu\Downloads\flutter_windows_stable.zip"
New-Item -ItemType Directory -Force -Path "C:\Users\avidu\Downloads" | Out-Null
New-Item -ItemType Directory -Force -Path "C:\Users\avidu\Projects" | Out-Null

if (-not (Test-Path "$flutterRoot\bin\flutter.bat")) {
  Write-Host "Resolving latest stable Flutter for Windows..."
  $rel = Invoke-RestMethod "https://storage.googleapis.com/flutter_infra_release/releases/releases_windows.json"
  $hash = $rel.current_release.stable
  $item = $rel.releases | Where-Object { $_.hash -eq $hash } | Select-Object -First 1
  if (-not $item) { throw "Could not resolve stable Flutter release" }
  $url = "https://storage.googleapis.com/flutter_infra_release/releases/" + $item.archive
  Write-Host "Downloading $url"
  Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing
  Write-Host "Extracting to C:\Users\avidu\ ..."
  if (Test-Path $flutterRoot) { Remove-Item -Recurse -Force $flutterRoot }
  Expand-Archive -Path $zip -DestinationPath "C:\Users\avidu" -Force
  Write-Host "Extracted."
} else {
  Write-Host "Flutter already present at $flutterRoot"
}

$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($userPath -notlike "*$flutterRoot\bin*") {
  [Environment]::SetEnvironmentVariable("Path", "$userPath;$flutterRoot\bin", "User")
  Write-Host "Added Flutter to user PATH"
}
$env:Path = "$flutterRoot\bin;" + $env:Path

& "$flutterRoot\bin\flutter.bat" --version
& "$flutterRoot\bin\flutter.bat" config --no-analytics
& "$flutterRoot\bin\flutter.bat" config --enable-web
Write-Host "DONE_INSTALL"
