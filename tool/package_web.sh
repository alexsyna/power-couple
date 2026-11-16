#!/bin/sh
# Builds the web app for https://powercouple.mindblo.app and zips it for
# upload to cPanel: File Manager -> the subdomain's folder -> Upload ->
# Extract (replacing the old files). Includes .htaccess and .well-known.
set -e
cd "$(dirname "$0")/.."
flutter build web --release --base-href / --dart-define-from-file=config/supabase.json
version=$(grep '^version:' pubspec.yaml | sed 's/version: //; s/+/-build/')

# The host serves .js files with a 10-day browser cache but the page itself
# fresh, so tag the script addresses with the version so an upload takes effect
# right away.
sed -i '' "s|src=\"flutter_bootstrap.js\"|src=\"flutter_bootstrap.js?v=$version\"|" build/web/index.html
sed -i '' "s|\"mainJsPath\":\"main.dart.js\"|\"mainJsPath\":\"main.dart.js?v=$version\"|" build/web/flutter_bootstrap.js
grep -q "flutter_bootstrap.js?v=$version" build/web/index.html
grep -q "main.dart.js?v=$version" build/web/flutter_bootstrap.js

out="build/powercouple-web-$version.zip"
rm -f "$out"
(cd build/web && zip -qr "../$(basename "$out")" . -x '*.DS_Store')
echo "Ready to upload: $out"
