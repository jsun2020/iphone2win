$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot

$scanRoots = @(
  'app/lib',
  'app/pubspec.yaml',
  'app/pubspec.lock',
  'app/ios',
  'app/macos',
  'app/windows',
  'app/rust/src',
  'core/src',
  'server'
)

$bannedPatterns = @(
  'public\.localsend\.org',
  'stun\.localsend\.org',
  'stun\.l\.google\.com',
  'in_app_purchase',
  'in_app_purchase_storekit',
  'firebase_analytics',
  'firebase_crashlytics',
  'sentry_flutter',
  'crashlytics',
  'google_mobile_ads',
  'appsflyer',
  'mixpanel',
  'posthog'
)

$files = foreach ($scanRoot in $scanRoots) {
  $path = Join-Path $repoRoot $scanRoot
  if (Test-Path -LiteralPath $path -PathType Leaf) {
    Get-Item -LiteralPath $path
  } elseif (Test-Path -LiteralPath $path -PathType Container) {
    Get-ChildItem -LiteralPath $path -Recurse -File |
      Where-Object {
        $_.FullName -notmatch '\\build\\' -and
        $_.FullName -notmatch '\\.dart_tool\\' -and
        $_.FullName -notmatch '\\Flutter\\ephemeral\\'
      }
  }
}

$hits = @()
foreach ($file in $files) {
  foreach ($pattern in $bannedPatterns) {
    $matches = Select-String -LiteralPath $file.FullName -Pattern $pattern -CaseSensitive:$false
    foreach ($match in $matches) {
      $hits += [PSCustomObject]@{
        Path = Resolve-Path -LiteralPath $file.FullName -Relative
        Line = $match.LineNumber
        Pattern = $pattern
        Text = $match.Line.Trim()
      }
    }
  }
}

if ($hits.Count -gt 0) {
  Write-Host 'Privacy audit failed. Banned public-service or proprietary dependency references remain:'
  $hits | Format-Table -AutoSize | Out-String | Write-Host
  exit 1
}

Write-Host 'Privacy audit passed.'
