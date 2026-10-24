#!/usr/bin/env bash
set -euo pipefail

# Fresh-process, profile-mode measurements. Android animation scales are
# validated, never changed: a non-normal scale invalidates the comparison.
#
# The default is a continuous cold-start stress journey across every screen.
# The fixture APK is installed under com.fariszr.dualmate.perf. Flutter drive
# is kept from performing its source-manifest-based cleanup, which otherwise
# targets the production package despite the Gradle applicationId suffix.
runs="${PERF_RUNS:-3}"
attempts="${PERF_RUN_ATTEMPTS:-3}"
output_root="${PERF_OUTPUT_ROOT:-build/aggressive_cold_navigation}"
serial="${ANDROID_SERIAL:-}"
perf_app_id="com.fariszr.dualmate.perf"

if ! [[ "$runs" =~ ^[1-9][0-9]*$ ]]; then
  echo 'PERF_RUNS must be a positive integer.' >&2
  exit 2
fi
if ! [[ "$attempts" =~ ^[1-9][0-9]*$ ]]; then
  echo 'PERF_RUN_ATTEMPTS must be a positive integer.' >&2
  exit 2
fi
if [[ -z "$serial" ]]; then
  serial="$(adb devices | awk 'NR > 1 && $2 == "device" { print $1; exit }')"
fi
if [[ -z "$serial" ]]; then
  echo 'No connected Android device. Set ANDROID_SERIAL or connect one with adb.' >&2
  exit 2
fi

original_stay_on="$(adb -s "$serial" shell settings get global stay_on_while_plugged_in | tr -d '\r')"
cleanup() {
  adb -s "$serial" shell am force-stop "$perf_app_id" >/dev/null 2>&1 || true
  if [[ "$original_stay_on" == 'null' ]]; then
    adb -s "$serial" shell settings delete global stay_on_while_plugged_in >/dev/null 2>&1 || true
  elif [[ "$original_stay_on" =~ ^[0-9]+$ ]]; then
    adb -s "$serial" shell settings put global stay_on_while_plugged_in "$original_stay_on" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

for setting in window_animation_scale transition_animation_scale animator_duration_scale; do
  value="$(adb -s "$serial" shell settings get global "$setting" | tr -d '\r')"
  # Unset Settings.Global animation scales use Android's normal 1.0 default.
  # In particular Huawei devices can omit animator_duration_scale entirely.
  if [[ "$value" == 'null' ]]; then
    value='1.0'
  fi
  if [[ "$value" != '1' && "$value" != '1.0' ]]; then
    echo "$setting=$value; set it to normal (1.0), then retry." >&2
    exit 2
  fi
done

# Long sequences of Flutter-generated gestures do not reset Android's native
# inactivity timer. Keep a plugged-in device awake for this run and restore its
# exact previous charging policy on exit, including an unset default.
adb -s "$serial" shell svc power stayon true
adb -s "$serial" shell input keyevent KEYCODE_WAKEUP
adb -s "$serial" shell wm dismiss-keyguard

# Each repetition cold-launches the entire journey once. Individual screen
# targets remain opt-in diagnostics; they are not the full stress run.
targets="${PERF_TARGETS:-stress}"

rm -rf "$output_root/runs"
mkdir -p "$output_root/runs"
for target in $targets; do
  for run in $(seq 1 "$runs"); do
    run_id="${target}-$(printf '%02d' "$run")"
    run_directory="$output_root/runs/$run_id"
    mkdir -p "$run_directory"
    succeeded=false
    for attempt in $(seq 1 "$attempts"); do
      adb -s "$serial" shell am force-stop "$perf_app_id"
      rm -f "$run_directory/report.json"
      if PERF_OUTPUT_DIR="$run_directory" PERF_RUN_ID="$run_id" \
        flutter drive --profile --flavor localrelease --no-dds --no-pub --keep-app-running \
          --device-id "$serial" \
          --driver test_driver/cold_navigation_perf_driver.dart \
          --target integration_test/cold_navigation_performance_test.dart \
          --dart-define=PERF_TEST_OFFLINE_FIXTURES=true \
          --dart-define=PERF_TARGET="$target" \
          --dart-define=PERF_PROFILE_MODE="${PERF_PROFILE_MODE:-ranking}" \
          --dart-define=PERF_TIMELINE_READY_CHECK=true; then
        succeeded=true
        break
      fi
      echo "${run_id} attempt ${attempt}/${attempts} failed; retrying fresh." >&2
    done
    if [[ "$succeeded" != true ]]; then
      echo "${run_id} failed after ${attempts} fresh attempts." >&2
      exit 1
    fi
  done
done

python3 scripts/aggregate_cold_navigation_profile.py \
  --input "$output_root/runs" \
  --output "$output_root/summary.json"
