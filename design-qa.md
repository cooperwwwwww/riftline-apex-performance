# Riftline build 23 — design and functionality QA

## Evidence

- `qa/riftline-v23-overview-live-config.png` — opens on the real config (2560 × 1440, game-default FPS cap)
- `qa/riftline-v23-review-diff.png` — Review drawer with old → new values, page tags, per-item undo, Discard all
- `qa/riftline-v23-search.png` — Ctrl K search listing matches from every page
- `qa/riftline-v23-stretched-fullscreen-lock.png` — No black bars locks Fullscreen and explains why
- `qa/riftline-v23-launch-apply-prompt.png` — Launch with unapplied changes asks first
- Earlier evidence: `qa/riftline-v22-language-safety.png`, `qa/riftline-v21-active-profile.png`

Captured at 1346 × 806, 1× density, in Chromium with a mock WebView2 bridge that
forwards every request to the real `Apex-Performance.ps1 -Mode Bridge` engine
against an isolated Apex config.

## Fixed in build 23

| Issue in build 22 | Fix |
| --- | --- |
| Visuals, Advanced, latency, and FOV controls always opened on placeholder HTML values, so Apply after one change reset every other setting | Engine reads `videoconfig.txt`, `settings.cfg`, and `profile.cfg` into a `current` object; the UI hydrates from it on start and after every write |
| Texture budget wrote 100000–800000, which are not Apex values; previews assumed a third mapping | Apex tiers None / Very Low / Low / Medium / High / Very High / Insane = 0 / 160000 / 300000 / 600000 / 1000000 / 2000000 / 3000000; legacy “1 GB”–“8 GB” labels convert automatically |
| FOV mixed two formulas (90 → 1.285714, 110 → 1.55) | Apex slider math `1 + (FOV − 70) × 0.01375` for every value; legacy values read back as the chosen FOV; 104 and 106 added |
| Ragdoll collision was overwritten to 0 a few lines after being set | Duplicate assignment removed; self-test covers it |
| Steam/Apex only found under `C:\Program Files (x86)\Steam` | Registry + `libraryfolders.vdf` scan across every Steam library; self-test covers a secondary library |
| No black bars could save Borderless/Windowed in videoconfig while the launch line forced `-fullscreen` | Engine and UI both force Fullscreen while No black bars is selected |
| New users got `+fps_max 144` and stretched mode by default | Defaults are Game default (no `+fps_max`) and Black bars; launch options and aspect are hydrated from what was saved |
| Re-applying rounded profile values (LOD 0.45 → 0.50) | Exact LOD / fade values are preserved and accepted by the engine (0.10–2.00 / 0.10–1.00) |
| Review counted a setting as changed even after it was changed back | Review diffs against a baseline snapshot; reverting removes the entry |
| Double-clicking Apply could start two engine writes | All actions run behind a busy lock with a progress bar |
| Browser fallback duplicated every action handler and returned 404 for preview images | Shared `Invoke-RiftlineAction` dispatcher; `/assets/*` served with an extension whitelist and path-traversal guard |
| Backups grew forever and “newest” was chosen by file mtime (Copy-Item preserves the source mtime) | Sorted by timestamped filename; pruned to 40 per type only after the permanent baseline exists |

## Functional checks run

- PowerShell parser: 0 errors.
- `-Mode SelfTest` passed, including new build 23 cases: FOV math and legacy read-back, out-of-range FOV rejection, texture tier mapping, full apply through the shared dispatcher with 27-field live read-back, Ragdoll collision, stretched → Fullscreen, Steam secondary-library detection, and backup pruning that keeps the baseline.
- `node --check web/app.js` passed.
- End-to-end UI run against the real engine: initial hydration matched the fake config exactly; two edits → Review 2; per-item undo → Review 1; Apply → Review 0 with the file re-read; built-in 1080p profile applied over pending changes after confirmation (LOD kept at 0.45); Restore regular Apex returned every control to the original values. No page or console errors (one pre-existing `/arena.png` 404 from `styles.css`, overridden by `extras.css`).
- Browser fallback: token required (403 without), preview asset served as `image/webp`, `../` and `%2f` traversal both 404, unknown action returns a JSON error, shutdown works.

## Not verifiable from this environment

- Windows PowerShell 5.1 and the native WebView2 shell were not run (tests used PowerShell 7.4 on Linux). The engine changes avoid PowerShell 7-only syntax and the UI only calls bridge actions that already existed in build 22, but a quick launch on Windows should confirm everything inside WebView2.
- Real Steam registry keys and a real Apex install were simulated, not read.

final result: passed (pending a Windows smoke test)
