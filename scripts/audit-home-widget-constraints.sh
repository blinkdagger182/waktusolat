#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

HOME_WIDGET_FILES=(
  "Widget/ConfigurableHomeWidget.swift"
  "Widget/SimpleWidget.swift"
  "Widget/CountdownWidget.swift"
  "Widget/Prayers2Widget.swift"
  "Widget/PrayersWidget.swift"
  "Widget/MetroWidget.swift"
  "Widget/NeoWidget.swift"
  "Widget/MinimalistWaktuWidget.swift"
  "Widget/ProWidgets.swift"
)

FAILURES=0

check_absent() {
  local label="$1"
  local pattern="$2"
  shift 2
  local output

  if output="$(rg -n "$pattern" "$@" 2>/dev/null | grep -v "home-widget-audit: allow-live-timer-lock-screen")"; then
    echo "FAIL $label"
    echo "$output"
    FAILURES=$((FAILURES + 1))
  else
    echo "PASS $label"
  fi
}

cd "$ROOT_DIR"

check_absent "Home widgets must not use live WidgetKit timer text" "style: \\.timer" "${HOME_WIDGET_FILES[@]}"
check_absent "Home widgets must not use TimelineView for live ticking" "TimelineView\\(" "${HOME_WIDGET_FILES[@]}"
check_absent "Home widget render code must not read wall-clock Date()" "let now = Date\\(\\)|= Date\\(\\)" "${HOME_WIDGET_FILES[@]}"
check_absent "Prayer provider must not build one-minute Home Screen timelines" "minuteInterval|maxDenseTimelineEntries|addingTimeInterval\\(60\\)|addingTimeInterval\\(step\\)" "Widget/PrayersProvider.swift"

if [[ "$FAILURES" -gt 0 ]]; then
  echo "Home widget constraint audit failed with $FAILURES issue(s)."
  exit 1
fi

echo "Home widget constraint audit passed."
