#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
flutter pub get
flutter analyze
flutter test --concurrency=1
# Release must regenerate plugin registration without test-only dependencies.
flutter build apk --release --no-android-gradle-daemon
CMAKE_BUILD_PARALLEL_LEVEL=1 flutter build linux --release --no-pub
mkdir -p output/agenda-linux
cp build/app/outputs/flutter-apk/app-release.apk output/agenda-contatos.apk
cp -a build/linux/x64/release/bundle/. output/agenda-linux/
cat > output/agenda-linux/iniciar-agenda.sh <<'LAUNCH'
#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
exec ./apk_agenda_bd_local "$@"
LAUNCH
chmod +x output/agenda-linux/iniciar-agenda.sh
tar -czf output/agenda-linux.tar.gz -C output agenda-linux
sha256sum output/agenda-contatos.apk output/agenda-linux.tar.gz > output/SHA256SUMS
