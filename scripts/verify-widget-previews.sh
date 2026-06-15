#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="$ROOT_DIR/Al-Adhan.xcodeproj"
SCHEME="iPhone"
BUNDLE_ID="app.riskcreatives.waktu"
DERIVED_DATA="$ROOT_DIR/.build/widget-preview-verification/DerivedData"
SNAPSHOT_DIR="$ROOT_DIR/Snapshots/Widgets"
CURRENT_DIR="$SNAPSHOT_DIR/current"
BASELINE_DIR="$SNAPSHOT_DIR/baseline"
UPDATE_BASELINES=0

if [[ "${1:-}" == "--update-baselines" ]]; then
  UPDATE_BASELINES=1
fi

mkdir -p "$CURRENT_DIR" "$BASELINE_DIR" "$DERIVED_DATA"

if [[ -n "${SIMULATOR_ID:-}" ]]; then
  DEVICE_ID="$SIMULATOR_ID"
else
  DEVICE_ID="$(xcrun simctl list devices available | awk -F '[()]' '/iPhone 16 .*Booted/ {print $2; exit}')"
  if [[ -z "$DEVICE_ID" ]]; then
    DEVICE_ID="$(xcrun simctl list devices available | awk -F '[()]' '/iPhone 17 Pro .*Shutdown|iPhone 16 .*Shutdown/ {print $2; exit}')"
  fi
fi

if [[ -z "${DEVICE_ID:-}" ]]; then
  echo "No available iPhone simulator found. Set SIMULATOR_ID to choose one."
  exit 1
fi

echo "Using simulator $DEVICE_ID"
xcrun simctl boot "$DEVICE_ID" >/dev/null 2>&1 || true
xcrun simctl bootstatus "$DEVICE_ID" -b >/dev/null
xcrun simctl status_bar "$DEVICE_ID" override \
  --time "9:41" \
  --dataNetwork wifi \
  --wifiBars 3 \
  --cellularBars 4 \
  --batteryState charged \
  --batteryLevel 100 >/dev/null 2>&1 || true

echo "Building $SCHEME"
xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration Debug \
  -destination "id=$DEVICE_ID" \
  -derivedDataPath "$DERIVED_DATA" \
  -quiet \
  build

APP_PATH="$DERIVED_DATA/Build/Products/Debug-iphonesimulator/iPhone.app"
if [[ ! -d "$APP_PATH" ]]; then
  echo "Built app not found at $APP_PATH"
  exit 1
fi

xcrun simctl install "$DEVICE_ID" "$APP_PATH"

styles_for_size() {
  case "$1" in
    small)
      echo "simpleCountdown countdown metro neo sketch proNext"
      ;;
    medium)
      echo "countdownMedium prayerTimesCompact prayerTimesGrid minimalist metro neo sketch proIndex"
      ;;
    large)
      echo "countdownLarge prayerTimesLarge metro neo sketch proArc"
      ;;
    *)
      echo ""
      ;;
  esac
}

FAILURES=0

compare_snapshot() {
  local current="$1"
  local baseline="$2"

  if [[ ! -f "$baseline" ]]; then
    echo "MISSING baseline $(basename "$baseline")"
    return 2
  fi

  if cmp -s "$current" "$baseline"; then
    echo "PASS $(basename "$current")"
    return 0
  fi

  if python3 - "$current" "$baseline" <<'PY'
import struct
import sys
import zlib

current, baseline = sys.argv[1], sys.argv[2]

def paeth(a, b, c):
    p = a + b - c
    pa = abs(p - a)
    pb = abs(p - b)
    pc = abs(p - c)
    if pa <= pb and pa <= pc:
        return a
    if pb <= pc:
        return b
    return c

def read_png(path):
    with open(path, "rb") as f:
        data = f.read()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError("not a png")

    pos = 8
    width = height = bit_depth = color_type = None
    payload = bytearray()
    while pos < len(data):
        length = struct.unpack(">I", data[pos:pos + 4])[0]
        chunk_type = data[pos + 4:pos + 8]
        chunk = data[pos + 8:pos + 8 + length]
        pos += 12 + length
        if chunk_type == b"IHDR":
            width, height, bit_depth, color_type, _, _, _ = struct.unpack(">IIBBBBB", chunk)
        elif chunk_type == b"IDAT":
            payload.extend(chunk)
        elif chunk_type == b"IEND":
            break

    if bit_depth != 8 or color_type not in (2, 6):
        raise ValueError(f"unsupported png format bit_depth={bit_depth} color_type={color_type}")

    channels = 4 if color_type == 6 else 3
    stride = width * channels
    raw = zlib.decompress(bytes(payload))
    rows = []
    prev = [0] * stride
    i = 0
    for _ in range(height):
        filt = raw[i]
        i += 1
        scan = list(raw[i:i + stride])
        i += stride
        out = [0] * stride
        for x, value in enumerate(scan):
            left = out[x - channels] if x >= channels else 0
            up = prev[x]
            up_left = prev[x - channels] if x >= channels else 0
            if filt == 0:
                out[x] = value
            elif filt == 1:
                out[x] = (value + left) & 255
            elif filt == 2:
                out[x] = (value + up) & 255
            elif filt == 3:
                out[x] = (value + ((left + up) // 2)) & 255
            elif filt == 4:
                out[x] = (value + paeth(left, up, up_left)) & 255
            else:
                raise ValueError(f"unsupported filter {filt}")
        rows.extend(out)
        prev = out
    return width, height, channels, rows

w1, h1, c1, a = read_png(current)
w2, h2, c2, b = read_png(baseline)
if (w1, h1, c1) != (w2, h2, c2):
    print(f"size mismatch {w1}x{h1}x{c1} != {w2}x{h2}x{c2}")
    sys.exit(1)

total = len(a)
diff_sum = 0
changed = 0
max_delta = 0
for x, y in zip(a, b):
    d = abs(x - y)
    diff_sum += d
    max_delta = max(max_delta, d)
    if d > 3:
        changed += 1

mean_delta = diff_sum / max(total, 1)
changed_ratio = changed / max(total, 1)

if mean_delta <= 0.35 and changed_ratio <= 0.002 and max_delta <= 160:
    print(f"PASS fuzzy mean={mean_delta:.4f} changed={changed_ratio:.5f} max={max_delta}")
    sys.exit(0)

print(f"DIFF mean={mean_delta:.4f} changed={changed_ratio:.5f} max={max_delta}")
sys.exit(1)
PY
  then
    return 0
  fi

  echo "DIFF $(basename "$current")"
  return 1
}

is_verification_screenshot() {
  local image="$1"

  python3 - "$image" <<'PY'
import struct
import sys
import zlib

path = sys.argv[1]

def paeth(a, b, c):
    p = a + b - c
    pa = abs(p - a)
    pb = abs(p - b)
    pc = abs(p - c)
    if pa <= pb and pa <= pc:
        return a
    if pb <= pc:
        return b
    return c

def read_png(path):
    with open(path, "rb") as f:
        data = f.read()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError("not a png")

    pos = 8
    width = height = bit_depth = color_type = None
    payload = bytearray()
    while pos < len(data):
        length = struct.unpack(">I", data[pos:pos + 4])[0]
        chunk_type = data[pos + 4:pos + 8]
        chunk = data[pos + 8:pos + 8 + length]
        pos += 12 + length
        if chunk_type == b"IHDR":
            width, height, bit_depth, color_type, _, _, _ = struct.unpack(">IIBBBBB", chunk)
        elif chunk_type == b"IDAT":
            payload.extend(chunk)
        elif chunk_type == b"IEND":
            break

    if bit_depth != 8 or color_type not in (2, 6):
        raise ValueError(f"unsupported png format bit_depth={bit_depth} color_type={color_type}")

    channels = 4 if color_type == 6 else 3
    stride = width * channels
    raw = zlib.decompress(bytes(payload))
    rows = []
    prev = [0] * stride
    i = 0
    for _ in range(height):
        filt = raw[i]
        i += 1
        scan = list(raw[i:i + stride])
        i += stride
        out = [0] * stride
        for x, value in enumerate(scan):
            left = out[x - channels] if x >= channels else 0
            up = prev[x]
            up_left = prev[x - channels] if x >= channels else 0
            if filt == 0:
                out[x] = value
            elif filt == 1:
                out[x] = (value + left) & 255
            elif filt == 2:
                out[x] = (value + up) & 255
            elif filt == 3:
                out[x] = (value + ((left + up) // 2)) & 255
            elif filt == 4:
                out[x] = (value + paeth(left, up, up_left)) & 255
            else:
                raise ValueError(f"unsupported filter {filt}")
        rows.append(out)
        prev = out
    return width, height, channels, rows

width, height, channels, rows = read_png(path)
x0 = int(width * 0.14)
x1 = int(width * 0.86)
y0 = int(height * 0.32)
y1 = int(height * 0.43)
dark_pixels = 0

for y in range(y0, y1):
    row = rows[y]
    for x in range(x0, x1):
        i = x * channels
        r, g, b = row[i], row[i + 1], row[i + 2]
        if r < 90 and g < 90 and b < 90:
            dark_pixels += 1

sys.exit(0 if dark_pixels > 700 else 1)
PY
}

capture_verified_screenshot() {
  local destination="$1"
  local attempt=1

  while [[ "$attempt" -le 8 ]]; do
    xcrun simctl io "$DEVICE_ID" screenshot "$destination" >/dev/null
    if is_verification_screenshot "$destination"; then
      return 0
    fi
    sleep 0.5
    attempt=$((attempt + 1))
  done

  echo "Verification screen did not settle for $(basename "$destination")"
  return 1
}

for size in small medium large; do
  for style in $(styles_for_size "$size"); do
    name="${size}-${style}.png"
    current="$CURRENT_DIR/$name"
    baseline="$BASELINE_DIR/$name"

    xcrun simctl terminate "$DEVICE_ID" "$BUNDLE_ID" >/dev/null 2>&1 || true
    xcrun simctl launch "$DEVICE_ID" "$BUNDLE_ID" \
      --verify-widget-previews \
      --widget-preview-size "$size" \
      --widget-preview-style "$style" >/dev/null
    sleep 2.0
    capture_verified_screenshot "$current"

    if [[ "$UPDATE_BASELINES" == "1" ]]; then
      cp "$current" "$baseline"
      echo "UPDATED $name"
      continue
    fi

    set +e
    compare_snapshot "$current" "$baseline"
    result=$?
    set -e
    if [[ "$result" != "0" ]]; then
      FAILURES=$((FAILURES + 1))
    fi
  done
done

xcrun simctl terminate "$DEVICE_ID" "$BUNDLE_ID" >/dev/null 2>&1 || true

if [[ "$UPDATE_BASELINES" == "1" ]]; then
  echo "Baselines updated in $BASELINE_DIR"
  exit 0
fi

if [[ "$FAILURES" != "0" ]]; then
  echo "$FAILURES widget preview snapshot(s) missing or changed."
  echo "Inspect $CURRENT_DIR, then run scripts/verify-widget-previews.sh --update-baselines if the changes are intentional."
  exit 1
fi

echo "All widget preview snapshots match baselines."
