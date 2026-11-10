#!/bin/bash
# Mastodon Bird UI - Install to Mastodon Core (with full locale support)
# https://github.com/ronilaukkarinen/mastodon-bird-ui
# Extended for all Mastodon supported languages
#
# This script installs/updates Bird UI files in your Mastodon installation.
# It is idempotent - safe to run multiple times. It will:
#   - Copy/update all Bird UI module files
#   - Ensure entry point SCSS files exist (creates missing ones, preserves existing)
#   - Update themes.yml, preserving other installed themes
#   - Ensure locale entries exist for ALL languages supported by Mastodon
#
# Usage: bash scripts/install-to-mastodon.sh --path /opt/mastodon [--bird-ui-path /path/to/mastodon-bird-ui] [--variations] [--default]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
MASTODON_PATH="${MASTODON_PATH:-}"
BIRD_UI_PATH_ARG="${BIRD_UI_PATH:-}"
ADD_VARIATIONS=""
SET_DEFAULT=""

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -p|--path)
      MASTODON_PATH="$2"
      shift 2
      ;;
    -b|--bird-ui-path|--bird-ui)
      BIRD_UI_PATH_ARG="$2"
      shift 2
      ;;
    -v|--variations)
      ADD_VARIATIONS="y"
      shift
      ;;
    -d|--default)
      SET_DEFAULT="y"
      shift
      ;;
    --no-default)
      SET_DEFAULT="n"
      shift
      ;;
    -h|--help)
      echo "Usage: bash $0 [-p|--path /path/to/mastodon] [-b|--bird-ui-path /path/to/mastodon-bird-ui] [-v|--variations] [-d|--default]"
      echo ""
      echo "This script is idempotent - safe to run repeatedly."
      echo "It ensures Bird UI is correctly installed regardless of prior state."
      echo ""
      echo "Options:"
      echo "  -p, --path          Path to Mastodon installation"
      echo "  -b, --bird-ui-path  Path to Mastodon Bird UI source repository"
      echo "  -v, --variations    Add accessible theme variations (accessible, accessible-plus)"
      echo "  -d, --default       Set Mastodon Bird UI as the server default theme"
      echo "  --no-default        Do not set Mastodon Bird UI as default (selectable theme)"
      echo "  -h, --help          Show this help message"
      exit 0
      ;;
    *)
      echo -e "${RED}Unknown option: $1${NC}"
      exit 1
      ;;
  esac
done

# Check if Mastodon path is provided
if [ -z "$MASTODON_PATH" ]; then
  echo -e "${YELLOW}Mastodon path not specified.${NC}"
  read -p "Enter your Mastodon installation path: " MASTODON_PATH
fi

# Validate Mastodon path
if [ ! -d "$MASTODON_PATH" ]; then
  echo -e "${RED}Error: Directory not found: $MASTODON_PATH${NC}"
  exit 1
fi

# Locate Bird UI source directory
if [ -n "$BIRD_UI_PATH_ARG" ] && [ -d "$BIRD_UI_PATH_ARG/src" ]; then
  SRC_DIR="$BIRD_UI_PATH_ARG/src"
  CHANGELOG_PATH="$BIRD_UI_PATH_ARG/CHANGELOG.md"
elif [ -d "$SCRIPT_DIR/../src" ]; then
  SRC_DIR="$SCRIPT_DIR/../src"
  CHANGELOG_PATH="$SCRIPT_DIR/../CHANGELOG.md"
elif [ -d "$SCRIPT_DIR/src" ]; then
  SRC_DIR="$SCRIPT_DIR/src"
  CHANGELOG_PATH="$SCRIPT_DIR/CHANGELOG.md"
elif [ -d "./src" ]; then
  SRC_DIR="./src"
  CHANGELOG_PATH="./CHANGELOG.md"
else
  echo -e "${RED}Error: Could not locate Mastodon Bird UI src directory. Use --bird-ui-path <path>${NC}"
  exit 1
fi

VERSION="unknown"
if [ -f "$CHANGELOG_PATH" ]; then
  VERSION=$(grep -m1 '^### ' "$CHANGELOG_PATH" | sed 's/### \([^:]*\):.*/\1/' || echo "unknown")
fi

STYLES_PATH="$MASTODON_PATH/app/javascript/styles"
THEMES_FILE="$MASTODON_PATH/config/themes.yml"
BIRD_UI_DEST="$STYLES_PATH/mastodon-bird-ui"

if [ ! -d "$STYLES_PATH" ]; then
  echo -e "${RED}Error: Styles directory not found: $STYLES_PATH${NC}"
  exit 1
fi

if [ ! -f "$THEMES_FILE" ]; then
  echo -e "${RED}Error: themes.yml not found: $THEMES_FILE${NC}"
  exit 1
fi

echo -e "${GREEN}Mastodon Bird UI $VERSION (Full Locale Support)${NC}"
echo ""

# Detect a native favourite animation
NATIVE_FAVOURITES="n"
if [ -f "$MASTODON_PATH/app/javascript/mastodon/components/favourite_star.tsx" ]; then
  NATIVE_FAVOURITES="y"
  echo -e "${YELLOW}Native favourite animation detected; Bird UI will not restyle the favourite button.${NC}"
  echo ""
fi

# Default variations in non-interactive environment if not specified
if [ -z "$ADD_VARIATIONS" ]; then
  if [ -n "$CI" ] || [ ! -t 0 ]; then
    ADD_VARIATIONS="y"
  else
    read -p "Add/update accessible theme variations (accessible, accessible-plus)? [Y/n]: " ADD_VARIATIONS
    ADD_VARIATIONS=${ADD_VARIATIONS:-y}
  fi
fi

# --- Step 1: Copy module files ---
echo -e "${BLUE}[1/4] Updating Bird UI module files...${NC}"

mkdir -p "$BIRD_UI_DEST"
mkdir -p "$BIRD_UI_DEST/components"
mkdir -p "$BIRD_UI_DEST/components/profile"
mkdir -p "$BIRD_UI_DEST/components/profile/icons"
mkdir -p "$BIRD_UI_DEST/layouts"
mkdir -p "$BIRD_UI_DEST/micro-interactions"
mkdir -p "$BIRD_UI_DEST/variables"
mkdir -p "$BIRD_UI_DEST/variants"

copy_if_exists() {
  local src="$1"
  local dest="$2"
  if [ -f "$src" ]; then
    cp "$src" "$dest"
    echo -e "  ${GREEN}Updated:${NC} $(basename "$dest")"
    return 0
  fi
  return 0
}

# Core module files
copy_if_exists "$SRC_DIR/_index.scss" "$BIRD_UI_DEST/_index.scss"

# Variables
for f in "$SRC_DIR/variables/"_*.scss; do
  [ -f "$f" ] && copy_if_exists "$f" "$BIRD_UI_DEST/variables/$(basename "$f")"
done

# Components
for f in "$SRC_DIR/components/"_*.scss; do
  [ -f "$f" ] && copy_if_exists "$f" "$BIRD_UI_DEST/components/$(basename "$f")"
done

# Profile components
for f in "$SRC_DIR/components/profile/"_*.scss; do
  [ -f "$f" ] && copy_if_exists "$f" "$BIRD_UI_DEST/components/profile/$(basename "$f")"
done

# Profile icons
for f in "$SRC_DIR/components/profile/icons/"_*.scss; do
  [ -f "$f" ] && copy_if_exists "$f" "$BIRD_UI_DEST/components/profile/icons/$(basename "$f")"
done

# Layouts
for f in "$SRC_DIR/layouts/"_*.scss; do
  [ -f "$f" ] && copy_if_exists "$f" "$BIRD_UI_DEST/layouts/$(basename "$f")"
done

# Micro-interactions
for f in "$SRC_DIR/micro-interactions/"_*.scss; do
  [ -f "$f" ] || continue
  base=$(basename "$f")
  if [[ "$NATIVE_FAVOURITES" =~ ^[Yy]$ && ( "$base" == "_heart.scss" || "$base" == "_star.scss" ) ]]; then
    if [ -f "$SRC_DIR/micro-interactions/_native-favourites.scss" ]; then
      cp "$SRC_DIR/micro-interactions/_native-favourites.scss" "$BIRD_UI_DEST/micro-interactions/$base"
      echo -e "  ${YELLOW}Native favourites:${NC} $base (Bird UI favourite styling dropped)"
    fi
  else
    copy_if_exists "$f" "$BIRD_UI_DEST/micro-interactions/$base"
  fi
done

# Variants
for f in "$SRC_DIR/variants/"_*.scss; do
  [ -f "$f" ] && copy_if_exists "$f" "$BIRD_UI_DEST/variants/$(basename "$f")"
done

# Create entry point inside module for Custom CSS build compatibility
cat > "$BIRD_UI_DEST/mastodon-bird-ui.scss" << 'EOF'
@use "index";
EOF

echo -e "${GREEN}Module files updated.${NC}"

# --- Step 2: Ensure entry point SCSS files exist ---
echo ""
echo -e "${BLUE}[2/4] Ensuring entry point SCSS files...${NC}"

ensure_entry_point() {
  local file="$1"
  local content="$2"
  local name
  name=$(basename "$file")
  echo "$content" > "$file"
  echo -e "  ${GREEN}Updated:${NC} $name"
}

# Auto bundle - respects data-color-scheme attribute and prefers-color-scheme.
ensure_entry_point "$STYLES_PATH/mastodon-bird-ui-auto.scss" "@use 'application';
@use 'mastodon-bird-ui';
@use 'mastodon-bird-ui/variables/light-mixin' as light;

[data-color-scheme=\"light\"] {
  @include light.tokens;
}

@media (prefers-color-scheme: light) {
  html:not([data-color-scheme]) {
    @include light.tokens;
  }
}"

# Variation entry points
if [[ "$ADD_VARIATIONS" =~ ^[Yy]$ ]]; then
  echo ""
  echo "  Creating variation entry points..."

  ensure_entry_point "$STYLES_PATH/mastodon-bird-ui-accessible.scss" "@use 'application';
@use 'mastodon-bird-ui';
@use 'mastodon-bird-ui/variants/accessible';"

  cat > "$BIRD_UI_DEST/mastodon-bird-ui-accessible.scss" << 'EOF'
@use "index";
@use "variants/accessible";
EOF

  ensure_entry_point "$STYLES_PATH/mastodon-bird-ui-accessible-plus.scss" "@use 'application';
@use 'mastodon-bird-ui';
@use 'mastodon-bird-ui/variants/accessible-plus';"

  cat > "$BIRD_UI_DEST/mastodon-bird-ui-accessible-plus.scss" << 'EOF'
@use "index";
@use "variants/accessible-plus";
EOF
fi

# --- Step 3: Rebuild themes.yml ---
if [ -z "$SET_DEFAULT" ]; then
  if [ -n "$CI" ] || [ ! -t 0 ]; then
    SET_DEFAULT="y"
  else
    read -p "Set Mastodon Bird UI as the server default theme? [Y/n]: " SET_DEFAULT
    SET_DEFAULT=${SET_DEFAULT:-y}
  fi
fi

echo ""
echo -e "${BLUE}[3/4] Rebuilding themes.yml...${NC}"

add_theme_entry() {
  local key="$1"
  local value="$2"
  local scss_file="$MASTODON_PATH/app/javascript/$value"
  if [ -f "$scss_file" ]; then
    echo "${key}: ${value}" >> "$THEMES_FILE"
    echo -e "  ${GREEN}Added:${NC} $key"
  else
    echo -e "  ${YELLOW}Skipped:${NC} $key (${value} not found)"
  fi
}

# Preserve existing third-party themes (e.g. Tangerine)
PRESERVED_THEMES=""
if [ -f "$THEMES_FILE" ]; then
  while IFS= read -r theme_line; do
    theme_key="${theme_line%%:*}"
    theme_key="${theme_key//[[:space:]]/}"
    [ -z "$theme_key" ] && continue
    case "$theme_key" in
      default|mastodon-dark|mastodon-bird-ui-auto|mastodon-bird-ui-accessible|mastodon-bird-ui-accessible-plus)
        continue ;;
    esac
    theme_value="${theme_line#*:}"
    theme_value="${theme_value//[[:space:]]/}"
    if [ -n "$theme_value" ] && [ -f "$MASTODON_PATH/app/javascript/$theme_value" ]; then
      PRESERVED_THEMES+="${theme_key}: ${theme_value}"$'\n'
      echo -e "  ${GREEN}Preserved:${NC} $theme_key (existing theme)"
    else
      echo -e "  ${YELLOW}Dropped stale:${NC} $theme_key (${theme_value:-no path} not found)"
    fi
  done < "$THEMES_FILE"
fi

# Set default theme entry
if [[ "$SET_DEFAULT" =~ ^[Yy]$ ]]; then
  echo "default: styles/mastodon-bird-ui-auto.scss" > "$THEMES_FILE"
  echo -e "  ${GREEN}Set:${NC} default: styles/mastodon-bird-ui-auto.scss (Bird UI)"
  add_theme_entry "mastodon-dark" "styles/application.scss"
else
  echo "default: styles/application.scss" > "$THEMES_FILE"
  echo -e "  ${GREEN}Set:${NC} default: styles/application.scss"
  add_theme_entry "mastodon-bird-ui-auto" "styles/mastodon-bird-ui-auto.scss"
fi

# Bird UI variations
if [[ "$ADD_VARIATIONS" =~ ^[Yy]$ ]]; then
  add_theme_entry "mastodon-bird-ui-accessible" "styles/mastodon-bird-ui-accessible.scss"
  add_theme_entry "mastodon-bird-ui-accessible-plus" "styles/mastodon-bird-ui-accessible-plus.scss"
fi

# Re-add preserved themes
if [ -n "$PRESERVED_THEMES" ]; then
  printf '%s' "$PRESERVED_THEMES" >> "$THEMES_FILE"
fi

# --- Step 4: Update locale files ---
echo ""
echo -e "${BLUE}[4/4] Updating locale files for all supported languages...${NC}"

# Lookup table for "Accessible" and "Accessible Plus" across all 106 Mastodon supported languages
get_accessible_labels() {
  local lang="$1"
  case "$lang" in
    af) echo "Toeganklik|Toeganklik Plus" ;;
    an) echo "Accesible|Accesible Plus" ;;
    ar) echo "إمكانية الوصول|إمكانية الوصول بلس" ;;
    ast) echo "Accesible|Accesible Plus" ;;
    az) echo "Əlçatan|Əlçatan Plus" ;;
    be) echo "Даступны|Даступны Плюс" ;;
    bg) echo "Достъпен|Достъпен Плюс" ;;
    bn) echo "অভিগম্য|অভিগম্য প্লাস" ;;
    br) echo "Monedus|Monedus Plus" ;;
    bs) echo "Pristupačno|Pristupačno Plus" ;;
    ca) echo "Accessible|Accessible Plus" ;;
    ckb) echo "دەستپێگەیشتوو|دەستپێگەیشتوو پڵەس" ;;
    co) echo "Accessibile|Accessibile Plus" ;;
    cs) echo "Přístupný|Přístupný Plus" ;;
    cy) echo "Hygyrch|Hygyrch Plus" ;;
    da) echo "Tilgængelig|Tilgængelig Plus" ;;
    de) echo "Barrierefrei|Barrierefrei Plus" ;;
    el) echo "Προσβάσιμο|Προσβάσιμο Plus" ;;
    en|en-GB) echo "Accessible|Accessible Plus" ;;
    eo) echo "Alirebla|Alirebla Plus" ;;
    es|es-AR|es-MX) echo "Accesible|Accesible Plus" ;;
    et) echo "Juurdepääsetav|Juurdepääsetav Plus" ;;
    eu) echo "Erabilerraza|Erabilerraza Plus" ;;
    fa) echo "دسترس‌پذیر|دسترس‌پذیر پلاس" ;;
    fi) echo "saavutettava|saavutettava Plus" ;;
    fil) echo "Maa-access|Maa-access Plus" ;;
    fo) echo "Atkomiligt|Atkomiligt Plus" ;;
    fr|fr-CA) echo "Accessible|Accessible Plus" ;;
    fy) echo "Tagonklik|Tagonklik Plus" ;;
    ga) echo "Inrochtana|Inrochtana Plus" ;;
    gd) echo "So-ruigsinneach|So-ruigsinneach Plus" ;;
    gl) echo "Accesible|Accesible Plus" ;;
    he) echo "נגיש|נגיש פלוס" ;;
    hi) echo "सुगम|सुगम प्लस" ;;
    hr) echo "Pristupačno|Pristupačno Plus" ;;
    hu) echo "Akadálymentes|Akadálymentes Plus" ;;
    hy) echo "Մատչելի|Մատչելի Պլյուս" ;;
    ia) echo "Accessibile|Accessibile Plus" ;;
    id) echo "Aksesibel|Aksesibel Plus" ;;
    ie) echo "Accessibil|Accessibil Plus" ;;
    ig) echo "Enwere ike ịnweta|Enwere ike ịnweta Plus" ;;
    io) echo "Acesebla|Acesebla Plus" ;;
    is) echo "Aðgengilegt|Aðgengilegt Plus" ;;
    it) echo "Accessibile|Accessibile Plus" ;;
    ja) echo "アクセシブル|アクセシブル Plus" ;;
    ka) echo "ხელმისაწვდომი|ხელმისაწვდომი პლუსი" ;;
    kab) echo "Ufay|Ufay Plus" ;;
    kk) echo "Қолжетімді|Қолжетімді Плюс" ;;
    kn) echo "ಲಭ್ಯ|ಲಭ್ಯ ಪ್ಲಸ್" ;;
    ko) echo "접근성|접근성 Plus" ;;
    ku) echo "Gihîştinbar|Gihîştinbar Plus" ;;
    kw) echo "Hedhadow|Hedhadow Plus" ;;
    la) echo "Accessibilis|Accessibilis Plus" ;;
    lad) echo "Aksisivle|Aksisivle Plus" ;;
    lt) echo "Pritaikyta|Pritaikyta Plus" ;;
    lv) echo "Pieejams|Pieejams Plus" ;;
    mk) echo "Пристапно|Пристапно Плус" ;;
    ml) echo "ആക്സസിബിൾ|ആക്സസിബിൾ പ്ലസ്" ;;
    mr) echo "प्रवेशयोग्य|प्रवेशयोग्य प्लस" ;;
    ms) echo "Boleh Diakses|Boleh Diakses Plus" ;;
    my) echo "အသုံးပြုနိုင်မှု|အသုံးပြုနိုင်မှု Plus" ;;
    nan-TW) echo "無障礙|無障礙 Plus" ;;
    ne) echo "पहुँचयोग्य|पहुँचयोग्य प्लस" ;;
    nl) echo "Toegankelijk|Toegankelijk Plus" ;;
    nn) echo "Tilgjengeleg|Tilgjengeleg Plus" ;;
    no) echo "Tilgjengelig|Tilgjengelig Plus" ;;
    oc) echo "Accessible|Accessible Plus" ;;
    pa) echo "ਪਹੁੰਚਯੋਗ|ਪਹੁੰਚਯੋਗ ਪਲੱਸ" ;;
    pl) echo "Dostępny|Dostępny Plus" ;;
    pt-BR|pt-PT) echo "Acessível|Acessível Plus" ;;
    ro) echo "Accesibil|Accesibil Plus" ;;
    ru) echo "Специальные возможности|Специальные возможности Плюс" ;;
    ry) echo "Доступный|Доступный Плус" ;;
    sa) echo "सुलभः|सुलभः प्लस" ;;
    sc) echo "Accessìbile|Accessìbile Plus" ;;
    sco) echo "Accessible|Accessible Plus" ;;
    si) echo "ප්‍රවේශ විය හැකි|ප්‍රවේශ විය හැකි Plus" ;;
    sk) echo "Prístupný|Prístupný Plus" ;;
    sl) echo "Dostopno|Dostopno Plus" ;;
    sq) echo "I kapshëm|I kapshëm Plus" ;;
    sr) echo "Приступачно|Приступачно Плус" ;;
    sr-Latn) echo "Pristupačno|Pristupačno Plus" ;;
    sv) echo "Tillgänglig|Tillgänglig Plus" ;;
    szl) echo "Dostympny|Dostympny Plus" ;;
    ta) echo "அணுகக்கூடியது|அணுகக்கூடியது பிளஸ்" ;;
    tai) echo "Accessible|Accessible Plus" ;;
    te) echo "అందుబాటు|అందుబాటు ప్లస్" ;;
    th) echo "การเข้าถึง|การเข้าถึง Plus" ;;
    tlh) echo "ghoSpu'bogh|ghoSpu'bogh Plus" ;;
    tok) echo "pona tawa jan|pona tawa jan sin" ;;
    tr) echo "Erişilebilir|Erişilebilir Plus" ;;
    tt) echo "Уңайлы|Уңайлы Плюс" ;;
    ug) echo "قولايلىق|قولايلىق پىليۇس" ;;
    uk) echo "Доступна|Доступна Плюс" ;;
    ur) echo "قابل رسائی|قابل رسائی پلس" ;;
    uz) echo "Qulay|Qulay Plus" ;;
    vi) echo "Tiếp cận|Tiếp cận Plus" ;;
    zgh) echo "Accessible|Accessible Plus" ;;
    zh-CN) echo "无障碍|无障碍 Plus" ;;
    zh-HK|zh-TW) echo "無障礙|無障礙 Plus" ;;
    *) echo "Accessible|Accessible Plus" ;;
  esac
}

remove_stale_locale_entry() {
  local file="$1"
  local key="$2"
  local lang="$3"

  [ ! -f "$file" ] && return

  if grep -q "^    ${key}:" "$file"; then
    awk -v k="$key" '$0 !~ ("^    " k ":") { print }' "$file" > "$file.tmp" && mv "$file.tmp" "$file"
    echo -e "  ${YELLOW}Removed from $lang:${NC} $key (stale)"
  fi
}

ensure_themes_section() {
  local file="$1"

  [ ! -f "$file" ] && return

  if ! grep -q "^  themes:" "$file"; then
    awk '/^['\''"]?[a-zA-Z0-9_-]+['\''"]?:/ && !done { print; print "  themes:\n    default: Mastodon"; done=1; next } 1' "$file" > "$file.tmp" && mv "$file.tmp" "$file"
  fi
}

add_locale_entry() {
  local file="$1"
  local key="$2"
  local value="$3"
  local lang="$4"

  [ ! -f "$file" ] && return

  if ! grep -q "^    ${key}:" "$file"; then
    if grep -q "^  themes:" "$file"; then
      awk -v k="$key" -v v="$value" '/^  themes:/ && !done { print; print "    " k ": " v; done=1; next } 1' "$file" > "$file.tmp" && mv "$file.tmp" "$file"
      echo -e "  ${GREEN}Added to $lang:${NC} $key"
    fi
  fi
}

STALE_THEME_KEYS="mastodon-dark mastodon-light contrast system mastodon-bird-ui-dark mastodon-bird-ui-light mastodon-bird-ui-contrast mastodon-bird-ui-dark-change-to-stars hide-finnish hide-finnish-change-to-stars hide-translate-links mastodon-bird-ui-light-hide-finnish mastodon-bird-ui-light-hide-finnish-change-to-stars mastodon-bird-ui-light-hide-translate-links mastodon-bird-ui-accessible-hide-finnish"

# Update all supported locales in Mastodon
for locale_file in "$MASTODON_PATH/config/locales"/*.yml; do
  [ ! -f "$locale_file" ] && continue
  filename=$(basename "$locale_file")

  # Skip component-specific locale files
  case "$filename" in
    activerecord.*|devise.*|doorkeeper.*|simple_form.*)
      continue
      ;;
  esac

  base_lang="${filename%.yml}"

  ensure_themes_section "$locale_file"

  for stale_key in $STALE_THEME_KEYS; do
    remove_stale_locale_entry "$locale_file" "$stale_key" "$filename"
  done

  # Set the 'default' locale label based on whether Bird UI is the default theme
  if [[ "$SET_DEFAULT" =~ ^[Yy]$ ]]; then
    # Grab original default name specifically under 'themes:' (e.g. Mastodon or ماستدون)
    orig_name=$(awk '/^  themes:/{flag=1; next} flag && /^    default:/{sub(/^    default:[ ]*/, ""); print; exit} flag && /^  [^ ]/{flag=0}' "$locale_file" | tr -d '\042\047')
    orig_name="${orig_name:-Mastodon}"
    if [ "$orig_name" = "Mastodon Bird UI" ]; then
      existing_dark=$(awk '/^  themes:/{flag=1; next} flag && /^    mastodon-dark:/{sub(/^    mastodon-dark:[ ]*/, ""); print; exit} flag && /^  [^ ]/{flag=0}' "$locale_file" | tr -d '\042\047')
      orig_name="${existing_dark:-Mastodon}"
    fi

    awk '
      /^  themes:/ { in_themes=1; print; next }
      in_themes && /^    default:/ { print "    default: Mastodon Bird UI"; next }
      in_themes && /^  [^ ]/ { in_themes=0 }
      { print }
    ' "$locale_file" > "$locale_file.tmp" && mv "$locale_file.tmp" "$locale_file"
    add_locale_entry "$locale_file" "mastodon-dark" "$orig_name" "$filename"
  else
    awk '
      /^  themes:/ { in_themes=1; print; next }
      in_themes && /^    default: Mastodon Bird UI/ { print "    default: Mastodon"; next }
      in_themes && /^  [^ ]/ { in_themes=0 }
      { print }
    ' "$locale_file" > "$locale_file.tmp" && mv "$locale_file.tmp" "$locale_file"
    add_locale_entry "$locale_file" "mastodon-bird-ui-auto" "Mastodon Bird UI" "$filename"
  fi

  # Variation locale entries with native translation for every supported language
  if [[ "$ADD_VARIATIONS" =~ ^[Yy]$ ]]; then
    IFS="|" read -r acc_label acc_plus_label <<< "$(get_accessible_labels "$base_lang")"
    add_locale_entry "$locale_file" "mastodon-bird-ui-accessible" "Mastodon Bird UI ($acc_label)" "$filename"
    add_locale_entry "$locale_file" "mastodon-bird-ui-accessible-plus" "Mastodon Bird UI ($acc_plus_label)" "$filename"
  fi
done

# --- Fix ownership and permissions ---
echo ""
echo "Fixing file ownership and permissions..."
chmod -R a+r "$BIRD_UI_DEST"
find "$BIRD_UI_DEST" -type d -exec chmod a+rx {} \;
if id mastodon >/dev/null 2>&1; then
  chown -R mastodon:mastodon "$BIRD_UI_DEST" 2>/dev/null || true
  chown mastodon:mastodon "$STYLES_PATH"/mastodon-bird-ui-*.scss 2>/dev/null || true
  chown mastodon:mastodon "$STYLES_PATH"/hide-*.scss 2>/dev/null || true
  chown mastodon:mastodon "$THEMES_FILE" 2>/dev/null || true
fi

echo ""
echo -e "${GREEN}Done!${NC}"
echo ""
echo "themes.yml contents:"
cat "$THEMES_FILE"
echo ""
