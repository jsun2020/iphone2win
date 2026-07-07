#!/usr/bin/env sh
set -eu

repo_root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"

patterns='public\.localsend\.org|stun\.localsend\.org|stun\.l\.google\.com|in_app_purchase|in_app_purchase_storekit|firebase_analytics|firebase_crashlytics|sentry_flutter|crashlytics|google_mobile_ads|appsflyer|mixpanel|posthog'

paths='app/lib app/pubspec.yaml app/pubspec.lock app/ios app/macos app/windows app/rust/src core/src server'

cd "$repo_root"

hits="$(find $paths -type f 2>/dev/null | grep -v '/build/' | grep -v '/.dart_tool/' | grep -v '/Flutter/ephemeral/' | xargs grep -Eni "$patterns" || true)"

if [ -n "$hits" ]; then
  printf '%s\n' 'Privacy audit failed. Banned public-service or proprietary dependency references remain:'
  printf '%s\n' "$hits"
  exit 1
fi

printf '%s\n' 'Privacy audit passed.'
