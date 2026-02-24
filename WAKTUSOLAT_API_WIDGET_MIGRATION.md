# Waktusolat API + Widget Migration Plan

Last updated: 2026-02-24 (implementation in progress)
Owner: iOS app + widget
Status: Phase 1-3 partially implemented

## Goal
- Replace local prayer-time calculation with `https://api.waktusolat.app/v2/solat/gps/{lat}/{long}`.
- Keep reliable fallback with last successful local cache (`prayersData`).
- Update widget UX to support the countdown-focused style from your screenshot.

## Non-Goals
- No mandatory Supabase dependency for core reliability.
- No full app redesign outside prayer-fetch and widget surfaces.

## Fallback Strategy
1. Primary: Live GPS API call.
2. Fallback A: Last successful local `prayersData` from app group storage.
3. Optional Fallback B: Supabase snapshot only if you decide to add it later.

Notes:
- `previous prayersData` means cached `Prayers` JSON already saved locally.
- This works offline and is lower risk than adding another remote dependency.

## Files In Scope
- `iPhone/Settings/SettingsAdhan.swift`
- `iPhone/Settings/Settings.swift`
- `Widget/PrayersProvider.swift`
- `Widget/CountdownWidget.swift`
- `Widget/LockScreen1Widget.swift`
- `Widget/LockScreen2Widget.swift`
- `Widget/LockScreen3Widget.swift`
- `Widget/LockScreen4Widget.swift`
- `Widget/PrayersWidget.swift`

## Phase 1: Data Layer Migration (App)
- [x] Add a dedicated GPS API fetch path in `SettingsAdhan`.
- [x] Decode payload fields: `zone`, `year`, `month_number`, `prayers[]`.
- [x] Convert API timestamps to `Date` for current day prayer list.
- [x] Preserve existing in-app `Prayer` model so UI does not need broad changes.
- [x] Keep user offsets (fajr/dhuhr/etc) applied after API parsing.
- [x] Preserve travel-mode grouped rows (`Dhuhr/Asr`, `Maghrib/Isha`).
- [x] Keep Friday labeling behavior (`Jumuah` for Dhuhr on Friday).

## Phase 2: Reliability + Cache Behavior
- [x] On successful fetch, overwrite local `prayersData` cache.
- [x] On fetch failure, use last successful local `prayersData` immediately.
- [x] Do not clear old cache when fetch fails.
- [ ] Add explicit telemetry/log messages for:
- API success
- API decode failure
- fallback-to-cache path
- no-cache-available path
- [x] Keep notification scheduling based on resolved prayer list (live or cache).

## Phase 3: Widget Data Flow
- [ ] Keep widget reading from app-group `prayersData` as source of truth.
- [x] Stop widget from requiring fresh network fetch per timeline build.
- [ ] Ensure timeline refresh is based on `nextPrayer.time`.
- [ ] On stale/missing data, show a deterministic fallback UI state.

## Phase 4: Countdown Widget UX (Screenshot-Inspired)
- [x] Add a compact countdown layout with:
- current prayer label (left)
- live timer string (center)
- next prayer label/icon (right)
- [x] Add a progress visual between current and next prayer (curve/line or bar).
- [ ] Map progress as `elapsed / interval(currentPrayerStart -> nextPrayerStart)`.
- [ ] Use existing accent color and maintain text contrast/readability.
- [ ] Ensure lock-screen families remain legible at small sizes.
- [ ] Keep tap target to open app state relevant to countdown view.

## Phase 5: QA Checklist
- [ ] Fresh install with location permission granted.
- [ ] Pull-to-refresh updates app and widget.
- [ ] API unavailable -> app shows cached data, widget remains populated.
- [ ] Day rollover updates next-day prayers correctly.
- [ ] Travel mode toggle still updates grouped prayers.
- [ ] Notification times still match displayed times.
- [ ] Widget timeline updates at prayer boundary.

## Optional: Supabase Fallback (Only If Needed)
- [ ] Define snapshot schema (zone + month + prayers array + version).
- [ ] Add fetch order: API -> local cache -> Supabase.
- [ ] Add staleness rules for Supabase snapshot.
- [ ] Add monitoring to detect drift between API and Supabase data.

Decision note:
- Keep this optional unless there is a proven uptime requirement that local cache cannot satisfy.

## Open Decisions
- [ ] Should widget prioritize exact API times only, or allow local offset customization?
- [ ] Should screenshot-style countdown replace existing `CountdownWidget` layout or be a new widget kind?
- [ ] Should optional Supabase fallback ship in v1 or be postponed?

## Change Log
- 2026-02-24: Initial plan created with actionable checklist for app + widget migration.
- 2026-02-24: Implemented GPS API fetch in `SettingsAdhan`, added month cache in app-group storage, switched `getPrayerTimes` to API data source, and kept cached fallback when API is unavailable.
- 2026-02-24: Redesigned countdown UI in `LockScreen2Widget` and `CountdownWidget` with screenshot-style layout and curve-based progress indicator.
