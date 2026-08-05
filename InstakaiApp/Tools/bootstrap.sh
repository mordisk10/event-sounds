#!/usr/bin/env bash
#
# One command to get Instakai open in Xcode on a fresh Mac.
#
#   ./Tools/bootstrap.sh com.yourname
#
# Written for a borrowed machine where time is short: it checks the things that
# actually go wrong, sets your bundle identifier so free provisioning will
# accept it, generates the project and opens it.
#
set -euo pipefail

RED=$'\033[31m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; BOLD=$'\033[1m'; OFF=$'\033[0m'
fail() { echo "${RED}✗${OFF} $*" >&2; exit 1; }
ok()   { echo "${GREEN}✓${OFF} $*"; }
warn() { echo "${YELLOW}!${OFF} $*"; }

cd "$(dirname "$0")/.."

PREFIX="${1:-}"
if [[ -z "$PREFIX" ]]; then
  cat >&2 <<'USAGE'
Kullanım / Usage:

    ./Tools/bootstrap.sh com.<kullaniciadin>

Paket kimliği önekini vermelisin. Ücretsiz imzalama, başkasının kaydettiği bir
kimliği reddeder — varsayılan "com.instakai" büyük ihtimalle alınmıştır.

You must pass a bundle identifier prefix. Free provisioning refuses an
identifier somebody else has registered, and the default is likely taken.
USAGE
  exit 2
fi

if [[ ! "$PREFIX" =~ ^[A-Za-z][A-Za-z0-9-]*(\.[A-Za-z][A-Za-z0-9-]*)+$ ]]; then
  fail "Geçersiz önek: '$PREFIX'. Ters alan adı olmalı, örn. com.ahmet"
fi

# --- Xcode -----------------------------------------------------------------

command -v xcodebuild >/dev/null 2>&1 \
  || fail "Xcode kurulu değil. App Store'dan kurup bir kez açın."

XCODE_VERSION="$(xcodebuild -version 2>/dev/null | head -1 | awk '{print $2}')"
XCODE_MAJOR="${XCODE_VERSION%%.*}"
ok "Xcode $XCODE_VERSION"

# XcodeGen writes pbxproj object version 77, which Xcode 15 and older refuse to
# open. This is the failure that is least obvious from its error message, so
# catch it here rather than letting xcodebuild report it.
if [[ "$XCODE_MAJOR" -lt 16 ]]; then
  fail "Xcode 16 veya üstü gerekiyor (bulunan: $XCODE_VERSION).
   XcodeGen'in ürettiği proje formatını Xcode 15 açamıyor.
   App Store'dan Xcode'u güncelleyin."
fi

if ! xcode-select -p >/dev/null 2>&1; then
  fail "Komut satırı araçları seçili değil: sudo xcode-select -s /Applications/Xcode.app"
fi

# --- XcodeGen ---------------------------------------------------------------

if ! command -v xcodegen >/dev/null 2>&1; then
  command -v brew >/dev/null 2>&1 \
    || fail "XcodeGen yok ve Homebrew de yok. https://brew.sh"
  echo "XcodeGen kuruluyor…"
  brew install xcodegen
fi
ok "XcodeGen $(xcodegen --version 2>/dev/null | awk '{print $NF}')"

# --- Bundle identifier ------------------------------------------------------

APP_ID="${PREFIX}.instakai"
WIDGET_ID="${APP_ID}.widget"

# Rewritten with python3 (present on every Mac) rather than sed: the widget
# identifier has to stay a child of the app's, and getting one sed expression
# to treat the two lines differently is more fragile than it is worth.
python3 - "$APP_ID" "$WIDGET_ID" <<'PY'
import re, sys

app, widget = sys.argv[1], sys.argv[2]
path = "project.yml"
pattern = re.compile(r"^(\s*PRODUCT_BUNDLE_IDENTIFIER:\s*)(\S+)\s*$")

lines = []
for line in open(path, encoding="utf-8"):
    match = pattern.match(line)
    if match:
        value = widget if match.group(2).endswith(".widget") else app
        line = f"{match.group(1)}{value}\n"
    lines.append(line)

open(path, "w", encoding="utf-8").writelines(lines)
PY

ok "Paket kimliği: $APP_ID  (widget: $WIDGET_ID)"

# --- Generate ---------------------------------------------------------------

xcodegen generate >/dev/null
ok "Instakai.xcodeproj üretildi"

cat <<EOF

${BOLD}Sırada Xcode'da yapılacak üç şey:${OFF}

  1. Settings → Accounts → +  → Apple ID'nle giriş yap (ücretsiz hesap yeterli)
  2. Instakai ve InstakaiWidget hedeflerinin ikisinde de
     Signing & Capabilities → Team → Personal Team
  3. Üstteki cihaz seçicisinden iPhone'unu seç → ⌘R

İlk açılışta telefon "Güvenilmeyen Geliştirici" derse:
Ayarlar → Genel → VPN ve Cihaz Yönetimi → Apple ID'n → Güven

Ayrıntı: docs/RUN-ON-DEVICE.md
EOF

open Instakai.xcodeproj
