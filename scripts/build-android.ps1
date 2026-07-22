param(
  [ValidateSet('debug', 'release')]
  [string]$Mode = 'debug'
)

$ErrorActionPreference = 'Stop'
$ProjectRoot = Split-Path -Parent $PSScriptRoot
Push-Location $ProjectRoot
try {
  flutter pub get
  dart format --output=none --set-exit-if-changed lib test
  flutter analyze
  flutter test
  if ($Mode -eq 'release') {
    flutter build apk --release
  } else {
    flutter build apk --debug
  }
} finally {
  Pop-Location
}
