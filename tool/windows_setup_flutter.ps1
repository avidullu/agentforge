[CmdletBinding()]
param(
    [string]$FlutterRoot = "$env:USERPROFILE\flutter"
)

$ErrorActionPreference = "Stop"
$flutter = Join-Path $FlutterRoot "bin\flutter.bat"

if (-not (Test-Path -LiteralPath $flutter)) {
    throw @"
Flutter was not found at '$FlutterRoot'.
Install a verified Flutter 3.44.6+ archive using the official Windows guide,
then rerun this script with -FlutterRoot if the SDK lives elsewhere.
This helper intentionally never deletes or replaces an existing SDK directory.
"@
}

$flutterBin = Join-Path $FlutterRoot "bin"
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
$pathItems = @($userPath -split ';' | Where-Object { $_ })
if ($pathItems -notcontains $flutterBin) {
    [Environment]::SetEnvironmentVariable(
        "Path",
        (@($flutterBin) + $pathItems) -join ';',
        "User"
    )
    Write-Host "Added '$flutterBin' to the start of the user PATH."
}

$env:Path = "$flutterBin;$env:Path"
& $flutter --version
& $flutter config --no-analytics
& $flutter config --enable-web
& $flutter doctor -v
