#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$PROJECT_DIR/../.." && pwd)"
EDITOR_DIR="$PROJECT_DIR/.editor"
EDITOR_REPO="https://github.com/FZR-forks/app-store-screenshots.git"
EDITOR_REVISION="640f888c6e116a3e9adfc4d45a4897123b397650"
TEMPLATE_SUBDIR="skills/app-store-screenshots/template"

rm -rf "$EDITOR_DIR"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

git clone --quiet "$EDITOR_REPO" "$TMP_DIR/editor-source"
git -C "$TMP_DIR/editor-source" checkout --quiet "$EDITOR_REVISION"
cp -R "$TMP_DIR/editor-source/$TEMPLATE_SUBDIR/." "$EDITOR_DIR"

rm -f "$EDITOR_DIR/app-store-screenshots.json"
ln -s ../app-store-screenshots.json "$EDITOR_DIR/app-store-screenshots.json"

mkdir -p \
  "$EDITOR_DIR/public/screenshots/android/phone/de" \
  "$EDITOR_DIR/public/screenshots/android/tablet/de" \
  "$EDITOR_DIR/public/screenshots/android/tablet/en" \
  "$EDITOR_DIR/public/widgets"

cp "$REPO_ROOT/screenshots/phone-light-schedule.png" "$EDITOR_DIR/public/screenshots/android/phone/de/01.png"
cp "$REPO_ROOT/screenshots/phone-light-reminder-setup.png" "$EDITOR_DIR/public/screenshots/android/phone/de/02.png"
cp "$REPO_ROOT/screenshots/phone-light-dualis.png" "$EDITOR_DIR/public/screenshots/android/phone/de/03.png"
cp "$REPO_ROOT/screenshots/phone-light-canteen.png" "$EDITOR_DIR/public/screenshots/android/phone/de/04.png"
cp "$REPO_ROOT/screenshots/phone-light-dates.png" "$EDITOR_DIR/public/screenshots/android/phone/de/05.png"

TABLET_SOURCES=(
  "tablet-light-schedule.jpg"
  "tablet-light-reminder-setup.jpg"
  "tablet-light-dualis.jpg"
  "tablet-light-canteen.jpg"
  "tablet-light-dates.jpg"
)
for locale in de en; do
  for i in "${!TABLET_SOURCES[@]}"; do
    n=$(printf '%02d' "$((i + 1))")
    cp "$REPO_ROOT/screenshots/${TABLET_SOURCES[$i]}" "$EDITOR_DIR/public/screenshots/android/tablet/$locale/$n.jpg"
  done
done

cp "$REPO_ROOT/icons/dualmate_icon_v1_refined_playstore_512.png" "$EDITOR_DIR/public/app-icon.png"
cp "$PROJECT_DIR/assets/widgets/schedule_now.png" "$EDITOR_DIR/public/widgets/schedule_now.png"
cp "$PROJECT_DIR/assets/widgets/canteen_today.png" "$EDITOR_DIR/public/widgets/canteen_today.png"

(
  cd "$EDITOR_DIR"
  bun install
)

printf 'Editor prepared at %s\n' "$EDITOR_DIR"
printf 'Run: cd %q && bun dev --hostname 0.0.0.0 --port 3000\n' "$EDITOR_DIR"
