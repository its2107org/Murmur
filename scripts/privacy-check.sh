#!/bin/bash
# Fails the build if any code that could send data off the iPhone sneaks into Murmur:
# internet requests, web views, analytics or add-on packages.
set -uo pipefail
cd "$(dirname "$0")/.."

PATTERN='URLSession|URLRequest|NWConnection|NWListener|import Network\b|CFNetwork|CFStream|WKWebView|import WebKit|SFSafariViewController|https?://|Firebase|Analytics|Sentry|Crashlytics|Mixpanel|Amplitude|TelemetryDeck|CloudKit|NSUbiquitous|MultipeerConnectivity|GameKit'
hits=$(grep -rnE "$PATTERN" App Keyboard Widget Shared --include='*.swift' || true)
if [ -n "$hits" ]; then
  echo "::error::Murmur must not contain any internet or analytics code. Found:"
  echo "$hits"
  exit 1
fi

if grep -qE '^\s*packages:' project.yml || find . -name 'Package.resolved' -not -path './build/*' | grep -q .; then
  echo "::error::Murmur must not use add-on packages."
  exit 1
fi

echo "Privacy check passed: no internet, analytics or add-on code."
