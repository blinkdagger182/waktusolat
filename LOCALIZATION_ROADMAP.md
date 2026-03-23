# Localization Roadmap

This document tracks the work required to make Waktu production-ready for full in-app localization across the currently supported countries.

## Supported Country / Language Targets

- Malaysia (`MY`) -> Malay (`ms`)
- Singapore (`SG`) -> English (`en`)
- Indonesia (`ID`) -> Indonesian (`id`)
- United States (`US`) -> English (`en`)
- Canada (`CA`) -> English (`en`) and French (`fr`)
- United Kingdom (`GB`) -> English (`en`)
- France (`FR`) -> French (`fr`)
- Portugal (`PT`) -> Portuguese (`pt-PT`)
- Russia (`RU`) -> Russian (`ru`)
- Japan (`JP`) -> Japanese (`ja`)
- South Korea (`KR`) -> Korean (`ko`)
- China (`CN`) -> Simplified Chinese (`zh-Hans`)

## Current State

- The app does not yet have a proper localization system.
- Most UI copy is hard-coded in SwiftUI views.
- There is no String Catalog or `Localizable.strings` structure yet.
- Widgets and complications also contain hard-coded English.
- Long-form educational and content-heavy sections are still English-only.

## Goal

Build a maintainable localization system that:

- defaults language from device locale on first install
- lets users pick a preferred language in Waktu Solat setup
- lets users change language later in Settings
- covers the full app, widgets, and important alerts
- remains easy to maintain as new features are added

## Phase 1: Localization Infrastructure

- Add a String Catalog (`Localizable.xcstrings`) to the app target.
- Add a shared localization helper so new strings are not hard-coded in views.
- Define supported in-app language enum and storage model.
- Persist preferred language in app storage.
- Add first-launch language resolution:
  - default from device locale
  - fall back to English if locale is unsupported
- Add app-level override so the chosen language is applied consistently.
- Ensure widgets can read the chosen language from shared storage if needed.

## Phase 2: Language Selection UX

- Add `Preferred Language` section to the Waktu Solat setup modal.
- Preselect language based on device locale on first install.
- Let the user confirm or change language during setup.
- Add `Language` picker in Settings for later changes.
- Show user-facing language names in their own language where appropriate.

## Phase 3: Core UI Migration

- Migrate the highest-traffic screens first:
  - launch screen
  - splash / onboarding
  - Waktu Solat setup
  - home / Azan tab
  - prayer list / countdown
  - settings root
  - notification screens
  - location / unsupported-region alerts
- Migrate repeated labels and section headers first to reduce duplication.
- Replace raw English strings with catalog-backed localized keys.

## Phase 4: Widgets and Complications

- Localize all widget labels:
  - fallback prompts
  - countdown labels
  - next prayer labels
  - footer text
- Localize complication labels.
- Verify app-group language syncing for widgets.

## Phase 5: Country-Aware Defaults

- Keep current supported-country defaults aligned with language defaults.
- Verify the language selected for each supported country:
  - `MY`: Malay
  - `SG`: English
  - `ID`: Indonesian
  - `US`: English
  - `CA`: English/French depending on user or device
  - `GB`: English
  - `FR`: French
  - `PT`: Portuguese
  - `RU`: Russian
  - `JP`: Japanese
  - `KR`: Korean
  - `CN`: Simplified Chinese

## Phase 6: Content-Heavy Screens

- Migrate long-form pages after core UI:
  - credits
  - tools
  - adhkar / duas / Arabic educational content
  - Quran detail surfaces
  - support / paywall / promo copy
- Decide which religious source texts should remain Arabic-only with translated explanations.
- Avoid machine-translating sensitive Islamic educational text without review.

## Phase 7: QA

- Verify first install language defaulting for each supported locale.
- Verify manual language switching in setup and Settings.
- Verify all navigation titles, alerts, sheets, and buttons are localized.
- Verify widgets reflect the selected language.
- Verify text expansion and truncation for:
  - French
  - Russian
  - German-length style layouts if added later
- Verify CJK rendering for:
  - Japanese
  - Korean
  - Simplified Chinese
- Verify no untranslated English strings remain in supported flows.

## Technical Notes

- Prefer String Catalog over scattered `.strings` files for maintainability.
- Keep translation keys stable and semantic.
- Do not localize prayer names incorrectly where canonical religious terms should remain consistent.
- Be careful with mixed-language UI where Arabic and translated text appear together.
- Keep source-backed country wording factual:
  - `officially supported in Waktu`
  - not `official national method` unless there is an actual official authority

## Recommended Rollout Order

1. Infrastructure
2. Setup language picker
3. Core app screens
4. Widgets
5. Content-heavy screens
6. QA and release hardening

## Not In Scope For First Pass

- Full localization of every long-form educational article
- Rewriting religious source content for every language immediately
- Expanding supported countries beyond the current supported list

## Completion Definition

Localization is considered production-ready when:

- all supported core flows are localized
- the app language is user-selectable
- first-install default language works correctly
- widgets reflect the chosen language
- no major supported surface remains hard-coded in English
