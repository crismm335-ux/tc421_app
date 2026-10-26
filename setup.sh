#!/usr/bin/env bash
# Gera as pastas android/ios do Flutter sem mexer no código em lib/ e test/.
set -euo pipefail
cd "$(dirname "$0")"

flutter create --project-name tc421_app --platforms=android,ios --org br.fisionit .
rm -f test/widget_test.dart

# O app só funciona com rede: garante a permissão de internet no Android (release).
MANIFEST=android/app/src/main/AndroidManifest.xml
if ! grep -q 'android.permission.INTERNET' "$MANIFEST"; then
  sed -i 's|android:label="[^"]*"|android:label="AQUA LIGHT"|' "$MANIFEST"
  sed -i 's|<application|<uses-permission android:name="android.permission.INTERNET"/>\n    <application android:usesCleartextTraffic="true"|' "$MANIFEST"
fi

# iOS pede autorização para falar com aparelhos da rede local.
PLIST=ios/Runner/Info.plist
if [ -f "$PLIST" ] && ! grep -q NSLocalNetworkUsageDescription "$PLIST"; then
  perl -0pi -e 's|</dict>\s*</plist>|\t<key>NSLocalNetworkUsageDescription</key>\n\t<string>Para encontrar e controlar a controladora TC421 na sua rede.</string>\n</dict>\n</plist>|' "$PLIST"
fi

flutter pub get
flutter test
echo "Pronto. Conecte o celular e rode: flutter run"
