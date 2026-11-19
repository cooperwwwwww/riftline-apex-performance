RIFTLINE - APEX PERFORMANCE SUITE 35.0
======================================

WHAT THIS IS
------------
This is a reversible settings and launch-profile app for the official PC
version of Apex Legends. It does not inject code, modify installed game files,
automate play, or bypass Easy Anti-Cheat.

The app manages graphics profiles, custom profiles, 3D resolution scaling, FPS
caps, and launch commands. You do not need to edit Steam Properties. Steam still
runs in the background for ownership and official anti-cheat startup.

QUICK START - ONLY THREE STEPS
------------------------------
1. Extract the whole ZIP to a normal folder. Do not run it from inside the ZIP.
2. Close Apex and double-click Riftline.exe. START-HERE.cmd is the fallback.
3. Choose a preset, review it, apply it, then click Launch Apex.

That is all most people need. Display, Visuals, Advanced, Launch, and Safety are
optional. If an action fails, Riftline shows the exact error in the app.

WHAT CHANGED IN 35.0
--------------------
- Fixed Overwatch sun shadows. Overwatch resets a shadow level of 0 to Medium
  when it saves, so the lowest real level is 1 (Low). Sun shadows now offer
  Low, Medium, High and Ultra, and Most FPS uses Low.

WHAT CHANGED IN 34.0
--------------------
- Fixed Overwatch fog. Overwatch stores Local fog detail as 1-3 (Low to High)
  and resets any other value to High, so Riftline's old Off (0) choice made fog
  heavier, not lighter. The setting now offers Low, Medium and High, and Most
  FPS uses Low.
- Confirmed from a file Overwatch itself rewrote: model, lighting,
  anti-aliasing, filtering, ambient occlusion, reflections, refraction and
  dynamic ambient settings written by Riftline are kept by the game.

WHAT CHANGED IN 33.0
--------------------
- Riftline no longer takes FPS from your games. Two hidden progress animations
  kept the window rendering all the time, even behind a borderless game.
  They now only run while visible, and every animation pauses whenever
  Riftline is not the focused window. Idle CPU use dropped about 15 times.
- Overwatch Most FPS now sets the frame cap to 600 (the game maximum) and
  the lowest texture and filtering levels. Resolution is never changed.
- Overwatch warns when the frame cap is below 600, with a one-click fix.
- Unreal games: Most FPS now also uncaps the frame rate and lowers view
  distance and textures, while keeping resolution and 3D resolution at 100%.

WHAT CHANGED IN 32.0
--------------------
- Long pages are split into tabs so only one section shows at a time:
  Visuals (Detail, Lighting & effects, Smoothness & latency), Advanced
  (Textures & memory, Shadows & AO, Distance & view), Launch (Frame rate,
  Input & latency, Performance, Clarity, Reticle, Startup & expert),
  Overwatch 2 (Display & FPS, Input lag, Graphics, Audio, Tools) and the
  Unreal game page (Display & FPS, Graphics, Clarity, Set in game).
- Each tab shows a badge with how many unsaved changes it holds, and Riftline
  remembers the last tab you used on each page.
- Search, Review and the setting guide open the right tab automatically, and
  the Launch filter searches every tab at once. Arrow keys move between tabs.

WHAT CHANGED IN 31.0
--------------------
- Unreal Engine games. One shared editor works with the standard Unreal
  GameUserSettings.ini, so Riftline now supports THE FINALS, ARC Raiders,
  Fortnite, Marvel Rivals, Dead by Daylight, PUBG, Palworld, Satisfactory,
  Deep Rock Galactic, Squad, Ready or Not and Hell Let Loose. Each game appears
  in the game switcher as soon as its settings file exists on this PC.
- Unreal settings: window mode, resolution, frame rate limit (Unlimited or a
  cap), V-Sync, 3D resolution, dynamic resolution, DirectX 11/12, and view
  distance, anti-aliasing, shadows, global illumination, reflections,
  post-processing, textures, effects, foliage and shading. THE FINALS and ARC
  Raiders also get DLSS frame generation off, motion blur off and lens
  distortion. Warnings with one-click fixes for frame generation, V-Sync and
  windowed modes. Lock file, Undo last change and Restore original.
- Same safety rules as Overwatch: only listed settings and values, backups
  before every change, no writes while the game runs, other lines untouched.
- Overwatch 2: new Audio group (master, effects, music, voice chat), a Match my
  refresh rate frame cap, 600 FPS labelled as the unlimited maximum, a file
  lock, shader cache clearing, a read-only view of everything in the settings
  file, and a checklist of competitive settings that live in the game menu.
- Apex: the lobby FPS cap now has a clear Unlimited (0) option plus 165, 240 and
  300, and the gameplay cap shows Unlimited (0) and 360.
- The Games page marks every supported game that is installed as Tunable.

WHAT CHANGED IN 30.0
--------------------
- Riftline now supports more than one game. A switcher at the top of the
  sidebar picks Apex Legends or Overwatch 2; each game has its own pages and
  its own Apply and Launch buttons.
- New Overwatch 2 page. It edits Documents\Overwatch\Settings\Settings_v0.ini:
  display mode, fullscreen resolution and refresh rate, frame rate cap,
  DirectX 11/12, reduce buffering, triple buffering, V-Sync, FPS display,
  intro, and texture, model, lighting, anti-aliasing, filtering, shadow,
  ambient occlusion, reflection, refraction and fog settings. Every setting
  has an explanation and a competitive pick.
- Overwatch safety: Riftline only writes the settings on that page, rejects
  any other key or value, refuses to write while Overwatch is running, keeps
  the original file plus the 25 newest backups, and has Undo last change and
  Restore original buttons. Line endings and every other line stay as they are.
- Overwatch warnings: Riftline points out a fullscreen refresh rate lower
  than your monitor's, and triple buffering left on without V-Sync, with a
  one-click fix.
- New Games page listing every installed Steam game, with Launch buttons and
  Tune settings for the games Riftline supports.

WHAT CHANGED IN 29.0
--------------------
- Added 1:1 square resolutions, from 720x720 up to 2160x2160, plus a
  Square 1:1 button that picks the largest square that fills your monitor's
  height (1440x1440 on a 1440p screen).
- The resolution list now has 14 aspect ratios and 93 presets: 1:1, 5:4, 4:3,
  3:2, 16:10, 5:3, 16:9, 17:9, 2:1, 21:9, 24:10, 32:10, 32:9 and 48:9 triple
  monitor. Presets that use your screen's full height are marked.
- New Any aspect ratio builder: type a ratio and a height and Riftline works
  out the width (rounded to an even number, within Apex's limits).

WHAT CHANGED IN 28.0
--------------------
- Every setting now explains itself. Explain mode (top bar, on by default)
  shows a plain-language description, FPS cost, visual impact and the
  competitive pick under each setting.
- New setting guide: press the ? next to any setting for a full panel with a
  real Apex capture (where one exists) you can flip between values, an
  illustration of what changes, FPS-cost and visual-change meters, and a
  Use recommended button.
- New PC Check page: reads the Windows settings that most often cost FPS or
  add input lag (refresh rate, driver age, Game Mode, background recording,
  power plan, mouse acceleration, RAM, free space, SSD). It only reads them;
  each fix opens the matching Windows Settings page.
- New setup codes on the Safety page: copy every setting as a RIFT1- code and
  load it on another PC or share it. Loading only fills the settings in; you
  still review and apply.
- New load estimate in the sidebar: a rough graphics-load and pixel-count
  gauge that updates as you change settings.
- Refreshed look: larger, easier-to-read text, new navigation icons, and
  cleaner cards.

WHAT CHANGED IN 27.0
--------------------
- Fixed black bars on stretched resolutions after the October 2026 Apex
  season. Apex removed mat_letterbox_aspect_threshold and now letterboxes any
  screen shape narrower than 1.59 (every 4:3 resolution) by default. Stretched
  mode now sends +mat_letterbox_aspect_min 0 and +mat_no_stretching 0 instead.
- Saved launch commands and profiles from older builds are upgraded
  automatically the next time they are saved or launched.
- Removed the DirectX 12 launch option. Apex now ships only the DX12 game and
  the old anti-cheat settings file it pointed to no longer exists; the flag is
  stripped from saved commands.

WHAT CHANGED IN 26.0
--------------------
- More launch commands: disable motion blur (+cl_motionblur 0), hide your own
  tracers (+r_drawtracers_firstperson 0), disable bloom (+mat_disable_bloom 1),
  reduced gore mode (+cl_is_softened_locale 1), position and speed readout
  (+cl_showpos 1), and minimize on Alt+Tab (+mat_minimize_on_alt_tab 1).
- Paste a launch line: paste any Steam launch line (for example one from a
  guide) and Riftline switches on the matching cards. Commands it does not know
  go to Additional commands.
- Quick sets now include the new visual-clarity commands.

WHAT CHANGED IN 25.0
--------------------
- New launch commands on the Launch page: refresh rate (-refresh), DirectX 12
  renderer, raw mouse input (+m_rawinput 1), preload map assets (-preload
  +cl_forcepreload 1), multicore rendering (+mat_queue_mode 2), worker threads
  (-threads), and disable soft particles (-softparticlesdefaultoff).
- Quick sets: Competitive, Low-end PC, Streamer, and Clear all fill the command
  cards in one click. Nothing is saved until you apply or save.
- Riftline detects your monitor's refresh rate and shows it on Overview and next
  to the refresh-rate command; quick sets use it automatically.
- A warning appears when Additional commands repeats something a card already
  sets, since Apex only uses the later value.

WHAT CHANGED IN 24.0
--------------------
- Fixed "Failed to fetch" after playing: the fallback window's engine stopped
  answering once it had been idle (for example while Apex was open), so every
  button failed after you closed the game. It now stays responsive.
- Fixed Riftline failing to open a second time while an older window was still
  running ("could not open a private localhost port").
- Switching back to Riftline (for example after closing Apex) re-reads the game
  state: the "Apex is running" warning clears and any settings Apex saved on
  exit are picked up, so Apply never overwrites them with stale values.
- Steam/Apex detection retries instead of remembering a failed lookup forever.
- The window now works at every size, from a narrow snapped window up to 4K;
  on narrow windows the page list moves to a strip under the title bar.

WHAT CHANGED IN 23.0
--------------------
Fixes
- Riftline now opens on the settings Apex is actually using. Every Visuals,
  Advanced, Display, latency, FOV, and reticle control is read from your real
  config files. Earlier builds showed placeholder values, so changing one
  setting and clicking Apply could silently reset everything else.
- Texture streaming budget now writes Apex's real tier values (None 0,
  Very Low 160000, Low 300000, Medium 600000, High 1000000, Very High 2000000,
  Insane 3000000). Older builds wrote values such as 300000 for "3 GB".
  Saved profiles that use the old "1 GB" to "8 GB" labels are converted
  automatically.
- FOV now uses the same math as Apex's own slider (90 = 1.275, 104 = 1.4675,
  110 = 1.55). 104 and 106 were added. FOV values written by older builds
  are read back as the value you picked.
- The Ragdoll collision switch now works. It was overwritten every time.
- Steam and Apex are now found on any drive or Steam library folder (read
  from the registry and libraryfolders.vdf). Earlier builds only checked
  C:\Program Files (x86)\Steam, so Launch and the language check failed for
  games installed elsewhere.
- No black bars now always saves Fullscreen in the video config as well as
  the launch line. Fullscreen is locked in the interface while it is selected.
- The default FPS cap is "Game default", which adds no +fps_max. Earlier
  builds quietly added +fps_max 144 for new users.
- Profile values such as LOD 0.45 are kept exactly instead of being rounded
  to the nearest list entry when you apply again.
- GPU auto-detection no longer recommends native resolution for entry-level
  cards (RX 570/580, RX 6400/6500, RTX 3050, RX Vega).
- Backups are sorted by their timestamp and old ones are pruned to the newest
  40 of each type. The original pre-Riftline baseline is never pruned.
- The browser fallback (START-HERE.cmd without Riftline.exe) now shares the
  native app's action engine and serves the preview images.

Interface
- Review now shows each change as "old -> new", with the page it lives on.
  Click a change to jump to it, use the undo arrow to revert one, or Discard
  all. Changing a value back removes it from Review automatically.
- The sidebar shows how many unapplied changes each page has.
- Launch Apex asks whether to apply pending changes first. Closing the window
  with unapplied changes asks before discarding them. Applying a profile over
  unapplied changes asks too.
- Confirmations use Riftline dialogs instead of Windows message boxes.
- A progress bar and status label appear while the engine works, and action
  buttons are disabled so nothing can run twice at the same time.
- Search (Ctrl K) now lists matching settings from every page, including
  Advanced and Launch commands. Use the arrow keys and Enter.
- Ctrl S applies changes.
- Width and height are checked as you type and corrected if out of range.
- The generated launch line shows its length against Steam's 1024 limit.
- The sidebar warns when Apex is running, because changes cannot be applied
  while it is open.

WHAT CHANGED IN 22.0
--------------------
- Fixed a game crash caused by forcing a Miles voice language whose audio pack
  was not installed by Steam.
- Language selection now safely changes interface and subtitles with `-language`.
  Voice audio follows the language files Steam has actually installed.
- Added launch-time protection that automatically removes legacy
  `+miles_language` commands from saved profiles and expert command text; Steam
  now owns voice selection and downloads completely.
- Added an installed-language status line to Launch Studio.

WHAT CHANGED IN 21.0
--------------------
- Named profiles now save and restore the complete Display page, including
  arbitrary width, height, window mode, and black-bars/no-black-bars mode.
- Riftline remembers the last profile you applied across restarts. The active
  profile is visibly marked until you apply another profile or restore regular Apex.
- Language selection now writes both the game-language and Miles voice-language
  launch arguments so installed interface, subtitle, and audio assets switch together.
- Deleted profiles no longer remain active, and restoring regular Apex clears
  the active-profile marker as well as Riftline-managed launch commands.

WHAT CHANGED IN 20.0
--------------------
- Added a Reticle Designer with a Windows color wheel, exact 0-255 RGB fields,
  live in-game preview, quick swatches, safe profile.cfg backup, and saved-profile
  persistence.
- Expanded the FOV control to 70, 80, 90, 100, 110, and custom 120.
- Rebuilt Launch as a searchable command studio. It covers gameplay/lobby caps,
  FPS telemetry, intro, controller, V-Sync, process priority, developer mode,
  CFG execution, language, window mode, adaptive scale, and expert additions.
- Added a plain-language hover explanation to every command card.
- Added all 38 supplied real Apex comparison captures to the native interface.
- Made Visuals and Advanced previews follow the exact control and value being
  focused or changed.
- Added a live aspect-ratio geometry lab for every resolution in the catalog.
- Added side-by-side Black bars and No black bars previews. The white circle
  stays round when geometry is preserved and becomes an ellipse when stretched.
- Exposed the labeled sun-shadow coverage, SSAO quality, map-detail, decal-limit,
  128 shadow-resolution, and 1.50/2.00 LOD controls in the applied config engine.
- Kept the launcher fully local and offline with no localhost dependency.

WHAT CHANGED IN 19.0
--------------------
- Replaced the localhost browser host with a native offline Windows window.
- Relabeled aspect-ratio behavior as Black bars and No black bars.
- Replaced generated arena art with real Apex gameplay captures supplied with
  the project.
- Added native minimize, maximize, close, resize, and title-bar movement.
- Added CREATE-DESKTOP-SHORTCUT.cmd and a proper Riftline desktop icon.
- Kept every profile, advanced setting, backup, safety action, and launch tool.

WHAT CHANGED IN 18.0
--------------------
- Rebuilt the interface as the Riftline desktop-style control center.
- Added a silent Riftline.exe launcher with a branded Windows icon.
- Added live search, review-before-apply, responsive previews, and animations.
- Added the full grouped resolution catalog to the new interface.
- Added complete named-profile save, apply, and delete controls.
- Preserved all original presets, advanced controls, backups, restore actions,
  config locking, shader-cache cleanup, launch commands, and safety limits.
- The local engine binds only to 127.0.0.1 and uses a private session token.

WHAT CHANGED IN 17.0
-------------------
- Fixed START-HERE.cmd failing silently on Windows PowerShell 5.1. The main
  script is now packaged as UTF-8 with a BOM so Windows reads punctuation and
  quoted text correctly.
- Added an explicit STA launch mode for the Windows Forms interface.
- START-HERE now reports when the main script is missing instead of doing nothing.
- No-black-bars mode is now explicitly game-side. It changes Apex's video config
  and launch commands only; it does not change the Windows desktop resolution,
  monitor menu, or NVIDIA/AMD/Intel control-panel settings.
- Removed the GPU-settings button and driver-setup requirement from the scaling
  help window.
- Apex still launches with the chosen in-game width/height and -fullscreen. The
  display mode may switch temporarily while Apex is open, then returns afterward.
- Rebuilt the interface around plain tasks: Start Here, Resolution + FPS,
  Extra FPS, Launch, and Undo + Help.
- Resolution + FPS now follows three visible steps: choose resolution,
  choose screen shape, then choose picture quality and Apply These Settings.
- Game-side stretched — no black bars automatically forces Fullscreen and saves:
  +mat_letterbox_aspect_min 0 +mat_letterbox_aspect_goal 0 +mat_no_stretching 0
  +building_cubemaps "1" -w WIDTH -h HEIGHT -fullscreen -multiple
- WIDTH and HEIGHT always come from the resolution selected in the app. You do
  not need to paste launch commands into Steam.
- Game default — keep black bars removes all helper-managed stretch arguments.
- Added 2304x1728 and 2560x1920 to the 4:3 resolution list.
- Reworded technical labels and made Apply the clear primary action.
- Added grouped resolution and aspect-ratio choices to Resolution + FPS.
- The new picker groups common 16:9, 16:10, 4:3, 5:4, 3:2, 21:9, 32:10,
  and 32:9 resolutions instead of crowding the main window with buttons.
- Includes common competitive/classic options such as 640x480, 800x600,
  1024x768, 1280x960, 1280x1024, and 1440x1080.
- Includes ultrawide and super-ultrawide choices up to 7680x2160.
- Every aspect-ratio group contains at least three resolutions; 5:4 now includes
  640x512, 800x640, 960x768, 1280x1024, 1600x1280, and 2560x2048.
- The picker can set Fullscreen automatically. Game-side stretched removes Apex
  letterboxing without requiring Windows, monitor, or GPU-panel changes.
- Added RESTORE REGULAR APEX on the Easy Setup page.
- The app preserves a permanent pre-helper baseline for videoconfig.txt,
  settings.cfg, and profile.cfg. Existing users are migrated from their oldest
  helper backups so the baseline is not taken from a recently optimized setup.
- Restore Regular Apex returns video, latency, and FOV settings to that original
  baseline and clears app-managed launch commands. Saved custom profiles remain.
- This is different from Restore Newest Backup, which only undoes recent changes.
- Scanned all 10,617 files in the installed 83.5 GB Apex build, including every
  packed RPAK/STARPAK byte, for saved video keys and performance cvar names.
- The scan found 46 persisted setting.* keys. The app already controlled every
  performance-related key except FOV; gamma and sound volume do not affect FPS.
- Added a backed-up Advanced FOV control: Keep Current, 70, 90, 100, or 110.
  Lower FOV renders a narrower view and may help GPU-limited FPS slightly.
- Best FPS now selects FOV 90, Medium selects 100, and Quality selects 110.
  RESET TO MAX FPS selects narrow FOV 70. Custom profiles save the choice.
- Restore now restores profile.cfg/FOV backups along with video and latency.
- Added separate Geometry LOD and Object/Effect Fade Distance controls. Lower
  values switch distant scenery to cheaper detail or fade minor detail sooner.
- Added Particle Fallback modes. Aggressive uses the current engine-supported
  fallback values to select cheaper particle variants sooner under load.
- Best FPS now uses 0.25 LOD/fade distance and Aggressive particle fallback;
  Medium uses moderate distance values; Quality keeps full distance/detail.
- Built-in performance profiles now also set the engine's supported particle
  fallback pair instead of leaving it to hardware auto-configuration.
- Extra Map Dressing still lowers the supported map-detail and set-dressing
  values, but the app deliberately does not force-disable grass, smoke, player
  effects, or other visibility-related rendering.
- Fixed Custom Profiles so every saved profile appears as a separate dropdown
  item instead of being combined into one object. Existing nested profile files
  are flattened automatically the next time they are loaded.
- Added WHAT DOES THIS DO? and hover instructions to Extra FPS. The
  explanation covers what every control changes, the fastest choice, and its
  image-quality, memory, latency, or physics tradeoff.
- Added MOST FPS, BALANCED, and BEST PICTURE presets at the top of Extra FPS.
- Each preset updates Resolution + FPS, hidden engine controls, adaptive
  3D resolution, low-latency mode, and the app-managed FPS cap together.
- Advanced presets never change the selected output width, height, or window
  mode. Review the loaded values, then press APPLY ALL CHANGES.
- The interface now has numbered tabs, a three-step quick-start message, clearer
  Apply/Play buttons, first-run help, and visible error instructions.
- Every built-in profile now uses more aggressive non-resolution optimization.
- Existing output resolutions were not changed.
- Competitive and 1080p use very-low textures, lower draw distance, bilinear
  filtering, low texture budgets, and all expensive effects disabled.
- Quality + FPS now disables shadows and map decoration while preserving a
  somewhat clearer texture tier.
- Weak-PC profiles use adaptive internal 3D resolution.
- New TURBO - KEEP CURRENT RESOLUTION profile applies the lowest graphics while
  preserving the exact current width and height.
- Built-in profiles disable RGB/chroma integration.
- Raw-FPS profiles disable low-latency/Boost modes that can trade a small amount
  of maximum FPS for lower input latency. Competitive keeps Reflex + Boost.
- Extra FPS exposes every safe hidden video value used by the profiles.
- Every hidden value is saved inside named custom profiles.
- Resolution + FPS links directly to MORE FPS CONTROLS.
- Extra FPS has its own APPLY ALL CHANGES button.

RESEARCH BASIS
--------------
EA's current PC guide recommends fullscreen, V-Sync off, adaptive resolution
off unless FPS drops frequently, no anti-aliasing, low/medium texture budget,
bilinear filtering, ambient occlusion off, low shadows, volumetric lighting off,
low model/effects detail, and low/disabled impact marks and ragdolls.

The installed Apex executable was also inspected. All 44 video keys used by the
helper are recognized by this build. The engine contains dvs_scale_min with a
0.5 default, so version 5 exposes a safe 50%-100% adaptive 3D-render floor.

Official references:
https://help.ea.com/en/articles/apex-legends/best-settings-pc/
https://www.ea.com/games/apex-legends/about/pc-system-requirements
https://www.nvidia.com/en-us/geforce/news/rtx-30-series-community-qa/

BUILT-IN PROFILES
-----------------
AUTO
Detects the graphics adapter and chooses a sensible profile.

TURBO - KEEP CURRENT RESOLUTION
Preserves the current output width/height while applying Potato-level textures,
lighting, shadows, geometry, particles, map decoration, decals, and ragdolls.
It enables a 120 FPS adaptive target with a 50% internal 3D-render floor and
uses uncapped rendering. This is the main no-resolution-change FPS profile.

COMPETITIVE NATIVE
Keeps native output resolution, uses a 2 GB texture budget, very-low textures,
minimum filtering, reduced geometry distance, all expensive effects disabled,
Reflex + Boost, and uncapped FPS.

SMOOTH 1080P
Keeps its existing 1920x1080 output, uses the same aggressive effects/texture
reductions, enables low latency without Boost, and caps at 144 FPS.

RAW MAX FPS 720P
Keeps 1280x720, uses no texture-streaming budget, extremely low geometry and
effects, adaptive 3D resolution down to 50%, and uncapped FPS.

EMERGENCY 540P
Keeps 960x540, uses minimum graphics, adaptive 3D resolution down to 50%, and a
45 FPS cap for very weak hardware.

POTATO 360P
Keeps 640x360, uses the minimum graphics and adaptive 3D resolution down to 50%,
with a 30 FPS cap. This is the lowest-quality built-in profile.

QUALITY + FPS
Keeps native output resolution, uses a 3 GB texture budget and slightly clearer
textures/filtering, but still disables shadows, ambient occlusion, volumetrics,
map dressing, decals, and ragdolls. Uses a 120 FPS cap.

3D RESOLUTION
-------------
Output resolution controls the final display and HUD dimensions. Adaptive 3D
resolution changes only the internally rendered game world when the GPU misses
the selected FPS target.

On Resolution + FPS:
1. Set Adaptive-resolution target to 60-240.
2. Set Minimum 3D render scale from 50%-100%.
3. Apply settings, then save or launch the profile.

50% permits the largest GPU-side FPS recovery and the blurriest scene. 100%
prevents the internal renderer from dropping below full scale. This cannot fix a
CPU bottleneck, and it does nothing while Adaptive Resolution is Off.

RESOLUTION + FPS
----------------
You can control output resolution, internal adaptive 3D resolution, window mode,
texture budget/resolution/filtering, anti-aliasing, model/draw distance, particle
detail, shadows, volumetric light/fog, ambient occlusion, map decoration, decals,
ragdolls, V-Sync, and NVIDIA/AMD low latency.

MORE RESOLUTIONS + ASPECT RATIOS opens grouped presets for:
- 16:9: 640x360 through 3840x2160.
- 16:10: 960x600 through 2560x1600.
- 4:3: 640x480 through 2560x1920, including 2304x1728.
- 5:4: 640x512 through 2560x2048, including 1280x1024.
- 3:2: 960x640 through 2880x1920.
- 21:9, 32:10, and 32:9 ultrawide formats.

The helper writes the selected width and height. Stretched mode automatically
uses Fullscreen and passes the Apex letterbox commands, selected width/height,
-fullscreen, and -multiple when the app starts Apex. Apex or Windows may reject
a resolution the connected display does not support.

Screen shape is directly visible on Resolution + FPS. Game-side stretched — no
black bars saves the complete Apex command set with the selected resolution and
forces Fullscreen. Game default — keep black bars removes those helper-managed
commands. No Windows desktop-resolution or monitor-setting change is required.

SAVE AS PROFILE stores the graphics setup together with its 3D scale, FPS cap,
and app-managed launch commands. Custom profiles are stored in:
%LOCALAPPDATA%\ApexPerformanceHelper\custom-profiles.json

EXTRA FPS SETTINGS
------------------
Extra FPS exposes the remaining safe hidden values used by the
profiles, with an explanation beside each:
- Linear mip filtering: Off is rougher and cheapest; On smooths transitions.
- Dynamic texture budgeting: On lets Apex adapt streaming memory.
- Backbuffers: 1 minimizes memory/latency; 2-3 can help V-Sync smoothness.
- Gib fragments: Off removes small debris fragments.
- Ragdoll self-collision: Off reduces physics work.
- Shadow-map minimum allocation: 0, 128, 256, 512, or 1024.
- Shadow upscaling factor: 0-4.
- Maximum dynamic shadows: 0, 1, 2, 4, or 8.
- Cascaded-shadow-map resolution: 0, 256, 512, or 1024.
- Ambient-occlusion downsampling: On reduces AO cost when AO is enabled.
- Geometry LOD switch scale: 0.25 changes distant geometry to cheap models
  earliest; 1.00 keeps detailed geometry farther away.
- Object/effect fade-distance scale: 0.25 fades minor scenery sooner; 1.00 keeps
  it farther away.
- Particle fallback: Aggressive selects cheaper particle variants sooner under
  load; Balanced and Default preserve progressively more effect detail.
- Field of view: 70 is narrowest and may be fastest; Riftline offers explicit
  values through 120. Values beyond the normal Apex menu may be clamped by a
  current or future game build. Lower FOV reduces peripheral vision and changes
  aiming feel.
- Custom reticle: the color wheel and RGB fields write Apex's profile-level
  `reticle_color` value after backing up profile.cfg.

LOAD LOWEST VALUES returns these controls to the aggressive defaults.
APPLY ALL CHANGES applies Resolution + FPS and Extra FPS together.
Save As Profile includes all hidden settings automatically.

The app does not expose fullbright, disabled lightmaps, disabled fog/smoke,
hidden-player-effects, particle removal, developer/debug, networking, or
anti-cheat-related engine commands. Those can damage gameplay visibility,
stability, or competitive integrity even though their names exist in the binary.

Grass/foliage removal is intentionally not included. It can remove intended
visual cover and create an unfair visibility difference. Use Extra Map Dressing
Off plus low LOD/fade-distance values for the safe supported alternative.

LAUNCH COMMAND STUDIO
---------------------
The searchable launcher can set +fps_max, +lobby_max_fps, +cl_showfps, -novid,
-nojoy, -forcenovsync, -high, -dev, +exec, -language, fullscreen/window modes,
and the verified +dvs_scale_min control. Hover any command card for a description
and tradeoff. It launches through the official route:
steam.exe -applaunch 1172470 [profile commands]

The expert field accepts additional commands the user already trusts, with line
break and null-character blocking. Riftline deliberately excludes one-click
visibility-removal, networking, anti-cheat, forced thread-count, and obsolete
renderer tweaks; these can be unsafe, ignored, or harmful to fair play.

HOW TO GET THE MOST FPS
-----------------------
1. Use TURBO to keep the current output resolution but minimize everything else.
2. If GPU use stays near 95-100%, enable an adaptive target and a 50% 3D floor.
3. If GPU use is low while FPS is low, the CPU is likely the limit; lower models,
   particles, map decoration, decals, and ragdolls.
4. Keep texture budget below available VRAM. None or Very Low can help memory-starved PCs
   but may increase texture pop-in and traversal stutter.
5. Use fullscreen and V-Sync off for the least overhead and latency.
6. Cap FPS at a number the PC can hold consistently for smoother frame pacing.

BACKUPS AND RESTORE
-------------------
RESTORE NEWEST BACKUP restores the latest video, low-latency, and FOV backups from:
%LOCALAPPDATA%\ApexPerformanceHelper\Backups

RESTORE REGULAR APEX restores the permanent earliest pre-helper baseline from:
%LOCALAPPDATA%\ApexPerformanceHelper\Regular-Apex-Baseline

It also clears the app-managed launch-command file. It does not delete named
custom profiles, game saves, account data, keybinds, or installed game files.

IMPORTANT
---------
- Close Apex before applying or restoring settings.
- FPS gains depend on CPU, GPU, temperature, drivers, map, and game version.
- The app never changes Windows power plans, drivers, registry, networking,
  input binds, or installed game files.
