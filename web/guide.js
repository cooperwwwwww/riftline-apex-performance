/* Riftline build 28 — setting guide, illustrations, PC Check, load estimate and setup codes.
   Loaded after app.js and uses its helpers ($, $$, api, setControl, getValue, ...). */
(() => {
'use strict';

/* ---------- Guide data ----------
   what  plain-language explanation
   fps   frame-rate cost 0-3, look  how much it changes the picture 0-3
   comp  competitive recommendation, rec  value "Use recommended" sets
   art   illustration, labels  captions for the two illustration panes
   order values from lightest to heaviest (drives the load estimate) */
const GUIDE = {
  width: { title: 'Output resolution', what: 'How many pixels Apex draws each frame. Fewer pixels means less work for your graphics card, so FPS goes up, but the picture gets softer.', fps: 3, look: 3, comp: 'Native resolution if your GPU keeps up; 1440×1080 or 1680×1050 stretched is the classic FPS-for-clarity trade.', art: 'pixels', labels: ['Low resolution', 'High resolution'] },
  aspect: { title: 'Black bars or stretched', what: 'A 4:3 or 16:10 resolution on a 16:9 monitor either shows black bars at the sides or is stretched to fill the screen. Stretched makes enemies look wider but squashes your view horizontally.', fps: 0, look: 2, comp: 'Pure preference. Many players like stretched because targets look wider; it does not change your hitbox or FOV.', art: 'stretch', labels: ['Black bars', 'Stretched'] },
  window: { title: 'Window mode', what: 'Fullscreen gives Apex the monitor to itself, which is normally fastest and has the lowest input lag. Borderless is a window that covers the screen, so Alt+Tab is instant. Windowed is a normal window.', fps: 1, look: 0, comp: 'Fullscreen. Stretched resolutions only work in Fullscreen.', art: 'window', labels: ['Windowed', 'Fullscreen'] },
  adaptiveEnabled: { title: 'Adaptive 3D resolution', what: 'When FPS drops below your target, Apex automatically lowers the 3D render resolution to catch up, then raises it again. The HUD stays sharp.', fps: 0, look: 2, comp: 'Off for a consistent image. Turn it on for weak GPUs where holding FPS matters more than sharpness.', art: 'pixels', labels: ['Off: fixed sharpness', 'On: drops pixels in fights'] },
  adaptiveTarget: { title: 'Adaptive target FPS', what: 'The frame rate Apex tries to hold when Adaptive 3D resolution is on. Set it close to your monitor refresh rate.', fps: 0, look: 1, comp: 'Your monitor refresh rate.', art: 'fps', labels: ['Low target', 'High target'] },
  renderScale: { title: 'Minimum render scale', what: 'The lowest the adaptive system may drop the 3D resolution. 50% can look very blurry; 80–90% stays fairly clear.', fps: 1, look: 2, comp: '70–80%.', art: 'pixels', labels: ['50%', '100%'], order: ['50%', '60%', '70%', '80%', '90%', '100%'] },

  textureBudget: { title: 'Texture streaming budget', what: 'How much graphics memory (VRAM) Apex may use to keep textures loaded. Too high for your card causes stutters and blurry textures popping in; it barely changes FPS otherwise.', fps: 1, look: 2, comp: 'One tier below your VRAM: Medium for 4 GB, High for 6 GB, Very High for 8 GB or more.', art: 'memory', labels: ['Small budget', 'Large budget'], order: ['None', 'Very Low', 'Low', 'Medium', 'High', 'Very High', 'Insane'] },
  textureQuality: { title: 'Texture detail', what: 'Sharpness of surfaces, weapon skins and characters. Uses VRAM more than raw GPU power.', fps: 1, look: 2, comp: 'Low. Higher mostly helps cosmetics.', rec: 'Low', art: 'texture', labels: ['Very Low', 'High'], order: ['Very Low', 'Low', 'High'] },
  anisotropic: { title: 'Texture filtering', what: 'Keeps floors and walls sharp when you look at them at a steep angle. Very cheap on modern GPUs.', fps: 1, look: 1, comp: '4x — almost free and keeps the ground readable.', rec: '4x', art: 'filtering', labels: ['1x', '16x'], order: ['1x', '2x', '4x', '8x', '16x'] },
  aa: { title: 'Anti-aliasing', what: 'TSAA smooths jagged “stair-step” edges by blending frames together. It looks cleaner but slightly blurs distant detail and costs a little FPS.', fps: 1, look: 2, comp: 'Off for the crispest distant targets; TSAA if shimmering edges bother you.', rec: 'Off', art: 'aa', labels: ['Off', 'TSAA'], order: ['Off', 'TSAA'] },
  modelDetail: { title: 'Model detail', what: 'How detailed characters, props and buildings are, and how far away they switch to simpler versions. Higher costs both GPU and CPU.', fps: 2, look: 2, comp: 'Low.', rec: 'Low', art: 'model', labels: ['Low', 'High'], order: ['Minimum', 'Very Low', 'Low', 'Medium', 'High'] },
  particleDetail: { title: 'Particle detail', what: 'Amount of smoke, sparks, debris and explosion effects. High is the biggest FPS drop in heavy fights with grenades and abilities.', fps: 2, look: 2, comp: 'Low — fewer particles also means less visual clutter.', rec: 'Low', art: 'particles', labels: ['Low', 'High'], order: ['Low', 'Medium', 'High'] },
  shadows: { title: 'Sun shadows', what: 'Shadows cast by the sun on buildings, trees and terrain. One of the most expensive settings.', fps: 3, look: 3, comp: 'Off. Big FPS gain, and players in shade become easier to see.', rec: false, art: 'shadow', labels: ['Off', 'On'] },
  effects: { title: 'Fog and light effects', what: 'Volumetric lighting: visible light beams and haze in the air. Looks atmospheric but is expensive and can hide players.', fps: 3, look: 2, comp: 'Off.', rec: false, art: 'fog', labels: ['Off', 'On'] },
  ambientOcclusion: { title: 'Ambient occlusion', what: 'Soft darkening where surfaces meet, like corners and under objects. Adds depth but costs a lot of GPU time.', fps: 3, look: 2, comp: 'Off.', rec: false, art: 'ao', labels: ['Off', 'On'] },
  mapDecorations: { title: 'Map decoration', what: 'Extra small rocks, plants and clutter around the map. More clutter is more to draw and more places for players to blend in.', fps: 1, look: 1, comp: 'Off.', rec: false, art: 'decor', labels: ['Off', 'On'] },
  decals: { title: 'Impact marks', what: 'Bullet holes and scorch marks left on surfaces. Small cost that grows in long fights.', fps: 1, look: 1, comp: 'Off.', rec: false, art: 'decals', labels: ['Off', 'On'] },
  ragdolls: { title: 'Ragdolls', what: 'Knocked and killed bodies use full physics instead of a simple animation. Costs CPU in big fights.', fps: 1, look: 1, comp: 'Off.', rec: false, art: 'ragdoll', labels: ['Off', 'On'] },
  vsync: { title: 'V-Sync', what: 'Locks frames to your monitor refresh to stop screen tearing (a horizontal split in the picture), but adds input lag.', fps: 0, look: 1, comp: 'Off. Use G-Sync/FreeSync with an FPS cap instead if tearing bothers you.', rec: false, art: 'vsync', labels: ['Off: tearing', 'On: extra lag'] },
  lowLatency: { title: 'Input-lag reduction', what: 'NVIDIA Reflex or AMD Anti-Lag keeps the CPU from running ahead of the GPU, so your clicks reach the screen sooner. Boost also keeps GPU clocks high.', fps: 0, look: 0, comp: 'On (or On + Boost on a strong PC).', rec: 'On', art: 'latency', labels: ['Off', 'On'] },

  linearMip: { title: 'Smooth texture transitions', what: 'Blends between texture detail levels instead of switching sharply. Removes faint visible “lines” on the ground at a tiny cost.', fps: 0, look: 1, comp: 'Off.', rec: false, art: 'filtering', labels: ['Off', 'On'] },
  dynamicBudget: { title: 'Dynamic texture budget', what: 'Lets Apex shrink or grow the texture memory budget based on what is free on your graphics card. Helps avoid VRAM stutters.', fps: 0, look: 1, comp: 'On.', rec: true, art: 'memory', labels: ['Fixed', 'Adaptive'] },
  backbuffers: { title: 'Backbuffers', what: 'How many finished frames can queue before they are shown. More frames smooth out spikes but each one adds input lag.', fps: 0, look: 0, comp: '1 for the lowest input lag.', rec: '1', art: 'buffers', labels: ['1 frame', '3 frames'] },
  gibs: { title: 'Combat debris', what: 'Small fragments and debris from explosions and destroyed objects.', fps: 1, look: 1, comp: 'Off.', rec: false, art: 'particles', labels: ['Off', 'On'] },
  shadowDepth: { title: 'Shadow-map minimum', what: 'Smallest resolution used for local shadows (lamps, doors). 0 lets the engine skip them when it can.', fps: 1, look: 1, comp: '0.', rec: '0', art: 'shadow', labels: ['0', '1024'], order: ['0', '128', '256', '512', '1024'] },
  shadowUpres: { title: 'Shadow upscaling', what: 'How much local shadows can be sharpened up close. Higher values make crisper shadow edges at a GPU cost.', fps: 1, look: 1, comp: '0.', rec: '0', art: 'shadow', labels: ['0', '4'], order: ['0', '1', '2', '3', '4'] },
  dynamicShadows: { title: 'Dynamic shadows', what: 'Maximum number of moving shadows (from lights, doors, players) drawn at once.', fps: 2, look: 1, comp: '0.', rec: '0', art: 'shadow', labels: ['0', '8'], order: ['0', '1', '2', '4', '8'] },
  csmResolution: { title: 'Sun-shadow resolution', what: 'Sharpness of sun shadows. Higher numbers give cleaner shadow edges; 0 turns sun shadows off.', fps: 2, look: 2, comp: '0 (off) or 128 if you keep shadows.', rec: '0', art: 'shadow', labels: ['Low', 'High'], order: ['0', '128', '256', '512', '1024'] },
  shadowCoverage: { title: 'Sun-shadow coverage', what: 'How far from you sun shadows are drawn. Wide coverage shades more of the distant map.', fps: 1, look: 1, comp: '1 (near).', rec: '1', art: 'distance', labels: ['Near', 'Wide'], order: ['1', '2'] },
  ssaoQuality: { title: 'Ambient-occlusion quality', what: 'Quality of the corner and contact shading. 0 skips it; 4 gives stronger depth.', fps: 2, look: 2, comp: '0.', rec: '0', art: 'ao', labels: ['0', '4'], order: ['0', '4'] },
  ssaoDownsample: { title: 'Downsample ambient occlusion', what: 'Calculates ambient occlusion at a lower resolution, which is much faster and looks nearly the same.', fps: 1, look: 1, comp: 'On.', rec: true, art: 'pixels', labels: ['Full size', 'Downsampled'], inverse: true },
  lodScale: { title: 'Geometry LOD scale', what: 'Distance at which objects switch to simpler models. Lower values switch sooner, which is faster but makes distant objects look blocky.', fps: 2, look: 2, comp: '0.60–0.80.', art: 'distance', labels: ['0.25', '2.00'], order: ['0.25', '0.35', '0.50', '0.60', '0.70', '0.80', '1.00', '1.50', '2.00'] },
  fadeScale: { title: 'Object fade distance', what: 'How far away small props stay visible before fading out. Lower draws less, but props may pop in.', fps: 1, look: 1, comp: '0.70.', art: 'distance', labels: ['Short', 'Long'], order: ['0.25', '0.35', '0.50', '0.60', '0.70', '0.80', '1.00'] },
  mapDetailLevel: { title: 'Map detail level', what: 'Level 2 keeps extra small rocks and set dressing; level 1 removes them.', fps: 1, look: 1, comp: '1.', rec: '1', art: 'decor', labels: ['1', '2'], order: ['1', '2'] },
  decalLimit: { title: 'Decal limit', what: 'How many bullet holes and marks can stay on screen at once.', fps: 1, look: 1, comp: '64.', rec: '64', art: 'decals', labels: ['64', '256'], order: ['64', '128', '256'] },
  particleFallback: { title: 'Particle fallback', what: 'How aggressively Apex simplifies effects when many are on screen. Aggressive keeps FPS steadier in chaotic fights.', fps: 1, look: 1, comp: 'Balanced or Aggressive.', rec: 'Balanced', art: 'particles', labels: ['Aggressive', 'Default'], order: ['Aggressive', 'Balanced', 'Default'] },
  viewFov: { title: 'Field of view', what: 'How wide your view is, in degrees. Wider shows more around you but makes things in the centre look smaller and draws more of the scene. Apex\'s own menu goes from 70 to 110; Riftline lets you type any value, and Apex may cap one it does not support.', fps: 1, look: 3, comp: '104–110 is the common competitive range.', rec: '104', art: 'fov', labels: ['70', '120'], range: [70, 120] },
  ragdollCollision: { title: 'Ragdoll collision', what: 'Lets ragdoll bodies collide with each other. Pure cosmetic physics.', fps: 1, look: 0, comp: 'Off.', rec: false, art: 'ragdoll', labels: ['Off', 'On'] },

  fpsCap: { title: 'Gameplay FPS cap', what: 'Maximum frames per second during matches. A cap just under your stable FPS gives smoother, more even frame times; 0 means uncapped.', fps: 0, look: 0, comp: 'Your monitor refresh rate, or a few FPS under what your PC holds in fights.', art: 'fps', labels: ['Uncapped: uneven', 'Capped: steady'] },
  lobbyFps: { title: 'Lobby FPS cap', what: 'Frame limit for menus and the lobby. Unlimited (0) makes menus as smooth as your PC allows; a low cap keeps your GPU cool and quiet between matches.', fps: 0, look: 0, comp: 'Unlimited for smooth menus, or 60 to keep the GPU cool.', art: 'fps', labels: ['Uncapped', 'Capped'] },
  fpsCounter: { title: 'FPS counter', what: 'Shows Apex’s own frame-rate readout in a corner of the screen.', fps: 0, look: 0, comp: 'Basic, while you tune settings.', art: 'hud', labels: ['Off', 'On'] },
  skipIntro: { title: 'Skip intro video', what: 'Skips the logo videos when Apex starts, so you reach the menu faster.', fps: 0, look: 0, comp: 'On.', rec: true, art: 'intro', labels: ['Off', 'On'] },
  noJoy: { title: 'Disable controller input', what: 'Turns off controller support. Helps if a plugged-in device (wheel, pad, drawing tablet) makes your aim drift or the HUD flip to controller icons.', fps: 0, look: 0, comp: 'On if you only play with mouse and keyboard.', art: 'mouse', labels: ['Off', 'On'] },
  forceNoVsync: { title: 'Force V-Sync off', what: 'Overrides V-Sync at launch so it can never be turned on by accident.', fps: 0, look: 0, comp: 'On.', rec: true, art: 'vsync', labels: ['V-Sync allowed', 'Forced off'] },
  highPriority: { title: 'High process priority', what: 'Asks Windows to favour Apex over background programs. Can help on CPUs with few cores; usually no change on strong PCs.', fps: 1, look: 0, comp: 'Optional.', art: 'cpu', labels: ['Normal', 'High'] },
  developerMode: { title: 'Developer launch mode', what: 'Starts Apex with developer launch behaviour. Can skip some startup screens; may change after game updates.', fps: 0, look: 0, comp: 'Off unless you know you need it.', art: 'intro', labels: ['Off', 'On'] },
  refreshRate: { title: 'Refresh rate', what: 'Tells Apex which refresh rate to use in fullscreen. Fixes Apex starting at 60 Hz on high-refresh monitors.', fps: 0, look: 1, comp: 'Your monitor’s maximum refresh rate.', art: 'fps', labels: ['60 Hz', 'High Hz'] },
  rawInput: { title: 'Raw mouse input', what: 'Reads your mouse directly, ignoring Windows pointer acceleration, so the same hand movement always turns the same distance.', fps: 0, look: 0, comp: 'On.', rec: true, art: 'mouse', labels: ['Windows input', 'Raw input'] },
  preload: { title: 'Preload map assets', what: 'Loads map content before a match instead of during it. Uses more RAM and takes longer to load, but cuts stutters in the first minutes.', fps: 1, look: 0, comp: 'On if you have 16 GB RAM or more.', art: 'memory', labels: ['Load as needed', 'Preloaded'] },
  multicore: { title: 'Multicore rendering', what: 'Requests multithreaded rendering. Current Apex builds already do this, so it mostly matters if something forced single-threaded mode.', fps: 1, look: 0, comp: 'Optional.', art: 'cpu', labels: ['Single thread', 'Multithreaded'] },
  threads: { title: 'Worker threads', what: 'Number of CPU threads Apex uses for background work. A wrong value can lower FPS.', fps: 1, look: 0, comp: 'Auto.', rec: 'Auto', art: 'cpu', labels: ['Few', 'Many'] },
  softParticlesOff: { title: 'Disable soft particles', what: 'Turns off soft blending where smoke touches surfaces. Small FPS gain in smoke-heavy fights; edges look harder.', fps: 1, look: 1, comp: 'On.', art: 'particles', labels: ['Soft', 'Hard edges'] },
  noMotionBlur: { title: 'Disable motion blur', what: 'Removes the blur when you turn quickly, so the picture stays sharp while flicking.', fps: 0, look: 1, comp: 'On.', rec: true, art: 'motion', labels: ['Blur', 'Sharp'] },
  noTracers: { title: 'Hide your own tracers', what: 'Hides the bullet trails from your own gun so they don’t cover your target.', fps: 0, look: 1, comp: 'On.', art: 'tracers', labels: ['Tracers shown', 'Hidden'] },
  noBloom: { title: 'Disable bloom', what: 'Removes the glow around bright lights and the sky, which can wash out enemies.', fps: 0, look: 1, comp: 'On.', art: 'bloom', labels: ['Bloom', 'No bloom'] },
  softenedLocale: { title: 'Reduced gore mode', what: 'Uses the regional “softened” version: blood is replaced with sparks. Many players find hit effects easier to read.', fps: 0, look: 1, comp: 'Preference.', art: 'particles', labels: ['Normal', 'Softened'] },
  showPos: { title: 'Position and speed readout', what: 'Shows your map position and movement speed. Useful for practising movement tech.', fps: 0, look: 0, comp: 'Off for normal play.', art: 'hud', labels: ['Off', 'On'] },
  minimizeAltTab: { title: 'Minimize on Alt+Tab', what: 'Minimizes Apex when you Alt+Tab out of fullscreen instead of leaving a frozen frame on screen.', fps: 0, look: 0, comp: 'On.', art: 'window', labels: ['Stays on screen', 'Minimizes'] },
  execConfig: { title: 'Run a custom CFG', what: 'Runs your own .cfg file of console commands (binds, settings) from the Apex cfg folder each launch.', fps: 0, look: 0, comp: 'Only if you have your own autoexec.', art: 'hud', labels: ['None', 'autoexec'] },
  language: { title: 'Language override', what: 'Changes the game text language for this launch only. Voice packs still follow Steam’s language setting.', fps: 0, look: 0, comp: 'Leave on System default.', art: 'hud', labels: ['Default', 'Override'] },
  extraCommands: { title: 'Additional commands', what: 'Any other launch commands you want to add. Riftline warns you if one duplicates a command it already generates.', fps: 0, look: 0, comp: '', art: 'hud', labels: ['', ''] },
  customReticle: { title: 'Custom reticle color', what: 'Changes the colour of your crosshair and optic reticles so they stand out against the map.', fps: 0, look: 1, comp: 'A colour that contrasts with the map, like cyan, magenta or bright green.', art: 'reticle', labels: ['Default red', 'Custom'] },
  configLock: { title: 'Lock video config', what: 'Marks Apex’s video settings file read-only so the game can’t overwrite your settings after an update or crash. Riftline unlocks it while applying.', fps: 0, look: 0, comp: 'On once you are happy with your settings.', art: 'lock', labels: ['Unlocked', 'Locked'] },

  // Overwatch 2
  owWindowMode: { title: 'Display mode', what: 'Fullscreen gives Overwatch the monitor to itself, which has the lowest input lag and lets it use your full refresh rate. Borderless windowed makes Alt+Tab instant but can add a little lag.', fps: 1, look: 0, comp: 'Fullscreen.', rec: '0', art: 'window', labels: ['Windowed', 'Fullscreen'] },
  owResolution: { title: 'Fullscreen resolution', what: 'How many pixels Overwatch draws in Fullscreen. Lower is faster but softer. Overwatch does not stretch 4:3, so it shows black bars unless your graphics driver is set to stretch.', fps: 3, look: 3, comp: 'Your native resolution; lower Render Scale in game instead if you need FPS.', art: 'pixels', labels: ['Low resolution', 'Native'] },
  owFullScreenRefresh: { title: 'Fullscreen refresh rate', what: 'The refresh rate Overwatch asks your monitor for in Fullscreen. If it is lower than your monitor supports, you cannot see more frames than this, however high your FPS.', fps: 0, look: 1, comp: 'Your monitor’s highest refresh rate.', art: 'fps', labels: ['60 Hz', 'High Hz'] },
  owFrameRateCap: { title: 'Frame rate cap', what: 'Maximum frames per second. 600 is the game maximum, so it is effectively unlimited. A cap a little under what your PC holds in fights keeps frame times even and the GPU from maxing out, which also lowers input lag.', fps: 0, look: 0, comp: 'A few FPS under your stable FPS, or 3 under your refresh rate with G-Sync/FreeSync (for example 237 on 240 Hz).', art: 'fps', labels: ['Uncapped: uneven', 'Capped: steady'] },
  owGraphicsAPI: { title: 'Graphics API', what: 'Which version of DirectX Overwatch uses. DirectX 12 can be smoother on newer GPUs; DirectX 11 is the long-tested option if you see stutters or crashes.', fps: 1, look: 0, comp: 'Try both; keep the one with steadier frame times on your PC.', art: 'cpu', labels: ['DirectX 11', 'DirectX 12'] },
  owCpuForceSyncEnabled: { title: 'Reduce buffering', what: 'Stops the CPU from preparing extra frames ahead of the GPU, so your clicks reach the screen sooner. Can cost a few FPS on weaker CPUs.', fps: 1, look: 0, comp: 'On.', rec: '1', art: 'buffers', labels: ['Off', 'On'] },
  owTripleBufferingEnabled: { title: 'Triple buffering', what: 'Adds a third frame buffer so V-Sync drops fewer frames. Without V-Sync it only adds input lag.', fps: 0, look: 0, comp: 'Off.', rec: '0', art: 'buffers', labels: ['Off', 'On'] },
  owVerticalSyncEnabled: { title: 'V-Sync', what: 'Locks frames to your monitor refresh to stop tearing, but adds noticeable input lag.', fps: 0, look: 1, comp: 'Off. Use G-Sync/FreeSync with a frame cap instead.', rec: '0', art: 'vsync', labels: ['Off: tearing', 'On: extra lag'] },
  owShowFPSCounter: { title: 'Show FPS', what: 'Shows Overwatch’s performance stats in a corner of the screen.', fps: 0, look: 0, comp: 'On while you tune.', art: 'hud', labels: ['Off', 'On'] },
  owShowIntro: { title: 'Intro cinematic', what: 'Plays or skips the Blizzard intro when Overwatch starts.', fps: 0, look: 0, comp: 'Skip.', rec: '0', art: 'intro', labels: ['Play', 'Skip'] },
  owTextureDetail: { title: 'Texture quality', what: 'Sharpness of surfaces, skins and the map. Mostly uses graphics memory rather than raw GPU power.', fps: 1, look: 2, comp: 'Medium on 4 GB cards, High or Ultra with 8 GB or more.', art: 'texture', labels: ['Low', 'Ultra'] },
  owModelQuality: { title: 'Model detail', what: 'Detail of the map, props and heroes, and how far away they switch to simpler versions. Lower values also remove some visual clutter.', fps: 2, look: 2, comp: 'Low.', rec: '1', art: 'model', labels: ['Low', 'Ultra'] },
  owLightQuality: { title: 'Lighting quality', what: 'Quality of lights and light effects around the map. Higher settings cost a lot in busy team fights.', fps: 2, look: 2, comp: 'Low.', rec: '0', art: 'fog', labels: ['Low', 'Ultra'] },
  owAADetail: { title: 'Anti-aliasing', what: 'Smooths jagged edges. Higher levels blur the image slightly and cost FPS.', fps: 1, look: 2, comp: 'Off or Low.', rec: '0', art: 'aa', labels: ['Off', 'High'] },
  owMaxAnisotropy: { title: 'Texture filtering', what: 'Keeps floors and walls sharp at steep angles. Very cheap on modern GPUs.', fps: 1, look: 1, comp: '4x or 8x.', rec: '4', art: 'filtering', labels: ['1x', '16x'] },
  owDirectionalShadowDetail: { title: 'Sun shadows', what: 'Detail of shadows cast by the sun. One of the most expensive settings. Low is the lowest level Overwatch keeps; it resets anything lower to Medium.', fps: 3, look: 2, comp: 'Low.', rec: '1', art: 'shadow', labels: ['Ultra', 'Low'] },
  owSimpleDirectionalShadows: { title: 'Simple shadows', what: 'Uses a cheaper, blockier style for the shadows that remain.', fps: 1, look: 1, comp: 'On.', rec: '1', art: 'shadow', labels: ['Detailed', 'Simple'] },
  owTranslucentShadowDetail: { title: 'Translucent shadows', what: 'Shadows cast through glass, smoke and effects.', fps: 1, look: 1, comp: 'Off.', rec: '0', art: 'shadow', labels: ['Off', 'On'] },
  owSSAOEnabled: { title: 'Ambient occlusion', what: 'Soft darkening where surfaces meet. Adds depth but costs a lot of GPU time.', fps: 3, look: 2, comp: 'Off.', rec: '0', art: 'ao', labels: ['Off', 'On'] },
  owLocalReflections: { title: 'Local reflections', what: 'Reflections of nearby objects on floors and walls.', fps: 2, look: 1, comp: 'Off.', rec: '0', art: 'bloom', labels: ['On', 'Off'] },
  owSSLRDetailLevel: { title: 'Screen-space reflections', what: 'Reflections on shiny surfaces such as water and polished floors.', fps: 2, look: 1, comp: 'Off.', rec: '0', art: 'bloom', labels: ['On', 'Off'] },
  owRefractionDetail: { title: 'Refraction', what: 'Light bending through glass, water and shields. Can make shield effects busier to look through.', fps: 1, look: 1, comp: 'Off.', rec: '0', art: 'fog', labels: ['Off', 'On'] },
  owDynamicAmbient: { title: 'Dynamic ambient light', what: 'Light that bounces between surfaces and changes with the scene.', fps: 1, look: 1, comp: 'Off.', rec: '0', art: 'ao', labels: ['Off', 'On'] },
  owMasterVolume: { title: 'Master volume', what: 'Overall game volume. Keep it high enough that quiet footsteps are clear, and turn other apps down instead.', fps: 0, look: 0, comp: 'High; lower music instead.', art: 'hud', labels: ['Low', 'High'] },
  owSFXVolume: { title: 'Sound effects', what: 'Footsteps, abilities and gunfire: the sounds that tell you where enemies are.', fps: 0, look: 0, comp: '100%.', rec: '100.000000', art: 'hud', labels: ['Low', 'High'] },
  owMusicVolume: { title: 'Music', what: 'Menu and match music. It can drown out footsteps and ability cues.', fps: 0, look: 0, comp: 'Off (0%).', rec: '0.000000', art: 'hud', labels: ['Off', 'Loud'] },
  owVoiceChatVolume: { title: 'Voice chat', what: 'How loud your teammates are.', fps: 0, look: 0, comp: 'Whatever keeps callouts clear without covering footsteps.', art: 'hud', labels: ['Low', 'High'] },
  owLocalFogDetail: { title: 'Local fog detail', what: 'Fog and haze effects around the map. Low clears the view slightly and saves a little FPS. Overwatch has no Off level; anything below Low is reset to High.', fps: 1, look: 1, comp: 'Low.', rec: '1', art: 'fog', labels: ['High', 'Low'] }
};

const LEVEL = ['None', 'Low', 'Medium', 'High'];

/* ---------- Illustrations ----------
   Each art function draws one 160×110 pane; hi=true is the "higher/on" side. */
const C = { sky: '#152131', ground: '#242d3a', wall: '#3a4556', light: '#e8edf2', mid: '#8f9baa', dim: '#4b5768', red: '#ff4d3d', cyan: '#62b8ff', green: '#55d29a', orange: '#ee8b42' };
const rect = (x, y, w, h, fill, extra = '') => `<rect x="${x}" y="${y}" width="${w}" height="${h}" fill="${fill}" ${extra}/>`;
const scene = (inner) => rect(0, 0, 160, 110, C.sky) + rect(0, 74, 160, 36, C.ground) + inner;
let uid = 0;

const ART = {
  pixels(hi) {
    const n = hi ? 16 : 6, s = 110 / n, out = [];
    for (let y = 0; y < n; y++) for (let x = 0; x < Math.ceil(160 / s); x++) {
      const cx = x * s + s / 2 - 80, cy = y * s + s / 2 - 55, inside = Math.hypot(cx * .85, cy) < 38;
      out.push(rect((x * s).toFixed(1), (y * s).toFixed(1), (s - .6).toFixed(1), (s - .6).toFixed(1), inside ? C.red : (x + y) % 2 ? '#1a2534' : '#1e2a3a'));
    }
    return out.join('');
  },
  stretch(hi) {
    return rect(0, 0, 160, 110, '#05070a') + (hi
      ? rect(0, 0, 160, 110, C.sky) + rect(0, 74, 160, 36, C.ground) + `<ellipse cx="80" cy="55" rx="40" ry="26" fill="none" stroke="${C.red}" stroke-width="3"/>`
      : rect(23, 0, 114, 110, C.sky) + rect(23, 74, 114, 36, C.ground) + `<circle cx="80" cy="55" r="26" fill="none" stroke="${C.red}" stroke-width="3"/>`);
  },
  window(hi) {
    return rect(0, 0, 160, 110, '#0b1017') + (hi
      ? rect(4, 4, 152, 102, C.sky, 'rx="3"') + rect(4, 70, 152, 36, C.ground)
      : rect(0, 96, 160, 14, '#1b2430') + rect(24, 14, 112, 74, '#0f1620', 'rx="4"') + rect(24, 14, 112, 10, C.dim, 'rx="4"') + rect(28, 26, 104, 58, C.sky) + rect(28, 66, 104, 18, C.ground));
  },
  memory(hi) {
    const fill = hi ? 128 : 52;
    const tiles = [0, 1, 2, 3].map(i => rect(14 + i * 34, 16, 28, 28, i * 34 < fill ? C.cyan : C.dim, `rx="4" opacity="${i * 34 < fill ? .9 : .35}"`)).join('');
    return rect(0, 0, 160, 110, '#0f1620') + tiles + `<text x="14" y="66" fill="${C.mid}" font-size="9" font-weight="700">VRAM IN USE</text>` + rect(14, 74, 132, 12, '#1b2430', 'rx="6"') + rect(14, 74, fill, 12, hi ? C.orange : C.green, 'rx="6"');
  },
  texture(hi) {
    const n = hi ? 12 : 4, s = 160 / n, out = [rect(0, 0, 160, 110, '#3b3328')];
    for (let y = 0; y < Math.ceil(110 / s); y++) for (let x = 0; x < n; x++) out.push(rect(x * s, y * s, s, s, (x + y) % 2 ? '#6b5a44' : '#57493a', hi ? '' : 'opacity=".55"'));
    if (hi) for (let i = 0; i < 18; i++) out.push(`<line x1="${(i * 37) % 160}" y1="${(i * 23) % 110}" x2="${(i * 37) % 160 + 9}" y2="${(i * 23) % 110 + 4}" stroke="#2c241b" stroke-width="1.2"/>`);
    return out.join('');
  },
  filtering(hi) {
    const out = [rect(0, 0, 160, 110, C.sky), `<polygon points="0,110 160,110 110,30 50,30" fill="${C.ground}"/>`];
    for (let i = 0; i < 9; i++) {
      const t = i / 8, y = 110 - (80 * (1 - Math.pow(1 - t, 1.8))), xl = 0 + 50 * (110 - y) / 80, xr = 160 - 50 * (110 - y) / 80;
      out.push(`<line x1="${xl.toFixed(1)}" y1="${y.toFixed(1)}" x2="${xr.toFixed(1)}" y2="${y.toFixed(1)}" stroke="${C.light}" stroke-width="1.2" opacity="${hi ? .8 : Math.max(.05, .8 - t * 1.1).toFixed(2)}"/>`);
    }
    for (let i = 0; i <= 8; i++) out.push(`<line x1="${i * 20}" y1="110" x2="${50 + i * 7.5}" y2="30" stroke="${C.light}" stroke-width="1" opacity="${hi ? .7 : .35}"/>`);
    return out.join('');
  },
  aa(hi) {
    if (hi) return rect(0, 0, 160, 110, C.sky) + `<polygon points="0,110 160,20 160,110" fill="${C.wall}"/><line x1="0" y1="110" x2="160" y2="20" stroke="${C.wall}" stroke-width="3" opacity=".5"/>`;
    let d = 'M0,110'; for (let x = 0; x < 160; x += 16) { const y = 110 - (x + 16) * 90 / 160; d += ` L${x},${(y + 5.6).toFixed(1)} L${x + 16},${(y + 5.6).toFixed(1)} L${x + 16},${y.toFixed(1)}`; }
    return rect(0, 0, 160, 110, C.sky) + `<path d="${d} L160,110 Z" fill="${C.wall}"/>`;
  },
  model(hi) {
    const sides = hi ? 28 : 6, pts = [...Array(sides)].map((_, i) => { const a = i / sides * Math.PI * 2; return `${(80 + Math.cos(a) * 34).toFixed(1)},${(52 + Math.sin(a) * 34).toFixed(1)}`; }).join(' ');
    return scene(`<polygon points="${pts}" fill="${C.cyan}" opacity=".85" stroke="${C.light}" stroke-width="1"/><text x="80" y="102" text-anchor="middle" fill="${C.light}" font-size="9" font-weight="700">${hi ? 'smooth model' : 'simple model'}</text>`);
  },
  particles(hi) {
    const n = hi ? 16 : 4, out = [];
    for (let i = 0; i < n; i++) out.push(`<circle cx="${(30 + (i * 53) % 100).toFixed(0)}" cy="${(28 + (i * 31) % 46).toFixed(0)}" r="${8 + (i % 4) * 3}" fill="${i % 5 === 0 ? C.orange : '#9aa6b5'}" opacity="${i % 5 === 0 ? .7 : .32}"/>`);
    return scene(out.join('') + `<rect x="66" y="58" width="10" height="20" fill="${C.red}"/>`);
  },
  shadow(hi) {
    return scene(`<circle cx="138" cy="18" r="9" fill="#ffd27a"/>` + (hi ? `<polygon points="54,78 92,78 70,100 22,100" fill="#0b1118" opacity=".75"/>` : '') + rect(54, 34, 38, 44, C.wall) + rect(62, 44, 8, 10, '#5c6a7e') + rect(76, 44, 8, 10, '#5c6a7e') + `<rect x="${hi ? 30 : 30}" y="62" width="6" height="16" fill="${C.red}"/>`);
  },
  fog(hi) {
    return scene(rect(64, 30, 34, 48, C.wall) + `<rect x="110" y="60" width="6" height="16" fill="${C.red}"/>` + (hi ? `<polygon points="0,0 34,0 140,110 70,110" fill="#ffe6b0" opacity=".16"/><polygon points="40,0 60,0 160,90 160,110" fill="#ffe6b0" opacity=".12"/>${rect(0, 0, 160, 110, '#b9c6d6', 'opacity=".14"')}` : ''));
  },
  ao(hi) {
    const base = `<polygon points="0,0 80,20 80,110 0,110" fill="#4a5568"/><polygon points="80,20 160,0 160,110 80,110" fill="#3b4555"/><polygon points="0,110 80,80 160,110" fill="#2a313d"/>`;
    if (!hi) return base;
    const seam = [...Array(6)].map((_, i) => `<line x1="80" y1="20" x2="80" y2="80" stroke="#0b0f15" stroke-width="${2 + i * 3}" opacity="${(.32 - i * .05).toFixed(2)}"/><line x1="0" y1="110" x2="80" y2="80" stroke="#0b0f15" stroke-width="${2 + i * 3}" opacity="${(.28 - i * .045).toFixed(2)}"/><line x1="80" y1="80" x2="160" y2="110" stroke="#0b0f15" stroke-width="${2 + i * 3}" opacity="${(.28 - i * .045).toFixed(2)}"/>`).join('');
    return base + seam;
  },
  decor(hi) {
    const n = hi ? 11 : 2, out = [];
    for (let i = 0; i < n; i++) { const x = 8 + (i * 47) % 144, y = 80 + (i * 13) % 24, r = 4 + (i % 3) * 3; out.push(`<ellipse cx="${x}" cy="${y}" rx="${r + 2}" ry="${r}" fill="#5b6576"/>`); if (hi && i % 3 === 0) out.push(`<path d="M${x + 6},${y} q4,-14 8,0" fill="#3f6b4a"/>`); }
    return scene(`<rect x="76" y="58" width="7" height="18" fill="${C.red}"/>` + out.join(''));
  },
  decals(hi) {
    const out = [rect(0, 0, 160, 110, '#4a5568'), rect(0, 0, 160, 6, '#3b4555')];
    if (hi) for (let i = 0; i < 14; i++) out.push(`<circle cx="${20 + (i * 41) % 120}" cy="${18 + (i * 29) % 78}" r="3.2" fill="#12161c"/><circle cx="${20 + (i * 41) % 120}" cy="${18 + (i * 29) % 78}" r="6" fill="#12161c" opacity=".25"/>`);
    return out.join('');
  },
  ragdoll(hi) {
    const body = hi
      ? `<g stroke="${C.light}" stroke-width="3" stroke-linecap="round"><line x1="44" y1="86" x2="88" y2="80"/><line x1="88" y1="80" x2="110" y2="92"/><line x1="88" y1="80" x2="112" y2="72"/><line x1="58" y1="84" x2="62" y2="96"/><line x1="58" y1="84" x2="66" y2="70"/></g><circle cx="38" cy="86" r="6" fill="${C.light}"/>`
      : `<g stroke="${C.dim}" stroke-width="3" stroke-dasharray="3 3" stroke-linecap="round"><line x1="80" y1="40" x2="80" y2="68"/><line x1="80" y1="68" x2="72" y2="84"/><line x1="80" y1="68" x2="88" y2="84"/></g><circle cx="80" cy="34" r="6" fill="${C.dim}"/>`;
    return scene(body);
  },
  vsync(hi) {
    return rect(0, 0, 160, 110, C.sky) + (hi
      ? rect(0, 74, 160, 36, C.ground) + rect(60, 26, 12, 48, C.red) + `<text x="80" y="18" text-anchor="middle" fill="${C.orange}" font-size="9" font-weight="700">+1–2 frames of lag</text>`
      : rect(0, 74, 160, 36, C.ground) + rect(60, 26, 12, 24, C.red) + rect(74, 50, 12, 24, C.red) + `<line x1="0" y1="50" x2="160" y2="50" stroke="${C.light}" stroke-width="1" stroke-dasharray="4 3" opacity=".7"/><text x="80" y="18" text-anchor="middle" fill="${C.light}" font-size="9" font-weight="700">tear line</text>`);
  },
  latency(hi) {
    const parts = hi ? [['Input', 24, C.cyan], ['CPU', 26, C.mid], ['GPU', 34, C.purple || '#9b7cff'], ['Show', 18, C.green]] : [['Input', 24, C.cyan], ['CPU', 26, C.mid], ['Queue', 40, C.orange], ['GPU', 34, '#9b7cff'], ['Show', 18, C.green]];
    let x = 6; const out = [rect(0, 0, 160, 110, '#0f1620')];
    parts.forEach(([label, w, color]) => { const ww = w * .9; out.push(rect(x, 40, ww - 2, 22, color, 'rx="3" opacity=".85"') + `<text x="${x + ww / 2 - 1}" y="75" text-anchor="middle" fill="${C.mid}" font-size="7.5">${label}</text>`); x += ww; });
    out.push(`<text x="6" y="26" fill="${C.light}" font-size="9" font-weight="700">click → screen: ${hi ? 'shorter' : 'longer'}</text>`);
    return out.join('');
  },
  fps(hi) {
    let d = 'M6,60'; for (let x = 6; x <= 154; x += 6) { const y = hi ? 56 + Math.sin(x) * 1.5 : 56 + Math.sin(x * .7) * 14 + (x % 30 === 0 ? -16 : 0); d += ` L${x},${y.toFixed(1)}`; }
    return rect(0, 0, 160, 110, '#0f1620') + `<line x1="6" y1="40" x2="154" y2="40" stroke="${C.dim}" stroke-dasharray="3 3"/><path d="${d}" fill="none" stroke="${hi ? C.green : C.orange}" stroke-width="2.2"/><text x="6" y="100" fill="${C.mid}" font-size="9" font-weight="700">frame time ${hi ? 'even' : 'spiky'}</text>`;
  },
  fov(hi) {
    const a = (hi ? 55 : 32) * Math.PI / 180, r = 90, x1 = 80 - Math.sin(a) * r, y1 = 100 - Math.cos(a) * r, x2 = 80 + Math.sin(a) * r;
    return rect(0, 0, 160, 110, '#0f1620') + `<polygon points="80,100 ${x1.toFixed(1)},${y1.toFixed(1)} ${x2.toFixed(1)},${y1.toFixed(1)}" fill="${C.cyan}" opacity=".18" stroke="${C.cyan}"/><circle cx="80" cy="100" r="5" fill="${C.light}"/>` +
      [[28, 40], [132, 46], [80, 22]].map(([x, y]) => `<circle cx="${x}" cy="${y}" r="5" fill="${C.red}" opacity="${hi || x === 80 ? 1 : .3}"/>`).join('');
  },
  distance(hi) {
    const out = [scene('')];
    [[20, 62, 18], [52, 66, 12], [84, 69, 8], [108, 71, 6], [128, 72, 4.5], [144, 73, 3.5]].forEach(([x, y, s], i) => out.push(rect(x, y - s * 1.6, s, s * 1.6, C.wall, `opacity="${hi || i < 2 ? 1 : .25}"`)));
    return out.join('');
  },
  buffers(hi) {
    const n = hi ? 3 : 1, out = [rect(0, 0, 160, 110, '#0f1620')];
    for (let i = 0; i < n; i++) out.push(rect(16 + i * 30, 36, 24, 34, C.cyan, 'rx="3" opacity=".8"'));
    out.push(`<path d="M${24 + n * 30},53 h${60 - n * 10}" stroke="${C.light}" stroke-width="2" marker-end="url(#ra${uid})"/>` + rect(130, 30, 22, 46, C.dim, 'rx="3"'));
    out.push(`<text x="8" y="96" fill="${C.mid}" font-size="9" font-weight="700">${n} frame${n > 1 ? 's' : ''} waiting = ${hi ? 'more' : 'least'} lag</text>`);
    return out.join('');
  },
  cpu(hi) {
    const out = [rect(0, 0, 160, 110, '#0f1620'), rect(36, 16, 88, 78, '#1b2430', 'rx="6"')];
    for (let i = 0; i < 8; i++) out.push(rect(46 + (i % 4) * 18, 28 + Math.floor(i / 4) * 30, 14, 22, (hi || i < 2) ? C.green : C.dim, 'rx="2"'));
    return out.join('');
  },
  intro(hi) {
    const out = [rect(0, 0, 160, 110, '#0f1620')];
    for (let i = 0; i < 4; i++) out.push(rect(10 + i * 37, 34, 32, 40, hi && i < 3 ? '#1b2430' : C.dim, 'rx="2"') + (hi && i < 3 ? `<line x1="${10 + i * 37}" y1="34" x2="${42 + i * 37}" y2="74" stroke="${C.red}" stroke-width="2"/>` : ''));
    out.push(`<text x="8" y="96" fill="${C.mid}" font-size="9" font-weight="700">${hi ? 'straight to menu' : 'logo videos play'}</text>`);
    return out.join('');
  },
  hud(hi) {
    return scene(rect(70, 52, 8, 22, C.red) + (hi ? rect(110, 6, 44, 16, '#000', 'opacity=".55" rx="3"') + `<text x="114" y="18" fill="${C.green}" font-size="9" font-family="Consolas" font-weight="700">240 FPS</text>` : ''));
  },
  mouse(hi) {
    const d = hi ? 'M14,96 L146,20' : 'M14,96 C70,94 110,70 146,20';
    return rect(0, 0, 160, 110, '#0f1620') + `<line x1="14" y1="96" x2="146" y2="96" stroke="${C.dim}"/><line x1="14" y1="96" x2="14" y2="14" stroke="${C.dim}"/><path d="${d}" fill="none" stroke="${hi ? C.green : C.orange}" stroke-width="2.5"/><text x="20" y="22" fill="${C.mid}" font-size="8.5">turn distance</text><text x="96" y="90" fill="${C.mid}" font-size="8.5">hand speed</text>`;
  },
  motion(hi) {
    const target = rect(74, 40, 10, 34, C.red);
    if (!hi) return scene([0, 1, 2, 3, 4].map(i => rect(74 - i * 8, 40, 10, 34, C.red, `opacity="${(.5 - i * .09).toFixed(2)}"`)).join('') + [...Array(6)].map((_, i) => `<line x1="10" y1="${20 + i * 14}" x2="150" y2="${20 + i * 14}" stroke="${C.light}" opacity=".07" stroke-width="5"/>`).join(''));
    return scene(target);
  },
  tracers(hi) {
    return scene(rect(100, 42, 9, 32, C.red) + `<polygon points="40,110 70,92 86,110" fill="#2b3442"/>` + (hi ? '' : [0, 1, 2].map(i => `<line x1="72" y1="96" x2="${102 + i * 3}" y2="${50 + i * 6}" stroke="#ffd27a" stroke-width="${3 - i * .6}" opacity=".85"/>`).join('')));
  },
  bloom(hi) {
    return scene(rect(84, 44, 9, 30, C.red) + `<circle cx="120" cy="24" r="8" fill="#fff6d6"/>` + (hi ? '' : `<circle cx="120" cy="24" r="40" fill="#fff6d6" opacity=".18"/><circle cx="120" cy="24" r="24" fill="#fff6d6" opacity=".25"/>${rect(0, 0, 160, 110, '#fff6d6', 'opacity=".08"')}`));
  },
  reticle(hi) {
    const color = hi ? C.cyan : C.red;
    return scene(`<circle cx="80" cy="55" r="14" fill="none" stroke="${color}" stroke-width="2"/><circle cx="80" cy="55" r="2" fill="${color}"/>` + `<rect x="98" y="48" width="8" height="24" fill="#c24236"/>`);
  },
  lock(hi) {
    return rect(0, 0, 160, 110, '#0f1620') + rect(54, 30, 52, 62, '#1b2430', 'rx="4"') + [0, 1, 2, 3].map(i => rect(62, 42 + i * 11, 36, 4, C.dim, 'rx="2"')).join('') + (hi ? `<rect x="92" y="62" width="26" height="22" rx="3" fill="${C.green}"/><path d="M97,62 v-6 a8,8 0 0 1 16,0 v6" fill="none" stroke="${C.green}" stroke-width="3"/>` : '');
  }
};

function illustration(key, guide) {
  const art = ART[guide.art];
  if (!art) return '';
  uid += 1;
  const [left, right] = guide.labels || ['Lower', 'Higher'];
  const pane = (x, hi, label) => `<g transform="translate(${x},0)"><svg width="160" height="110" viewBox="0 0 160 110" overflow="hidden">${art(hi)}</svg><text x="80" y="126" text-anchor="middle" fill="${hi ? '#ff9a8d' : '#aab4c1'}" font-size="10" font-weight="800" letter-spacing=".06em">${escapeHtml(String(label).toUpperCase())}</text></g>`;
  return `<svg class="guide-art" viewBox="0 0 334 132" role="img" aria-label="Illustration of ${escapeHtml(guide.title)}: ${escapeHtml(left)} compared with ${escapeHtml(right)}"><defs><marker id="ra${uid}" markerWidth="8" markerHeight="8" refX="6" refY="4" orient="auto"><path d="M0,0 L8,4 L0,8 Z" fill="#e8edf2"/></marker></defs>${pane(0, false, left)}${pane(174, true, right)}</svg>`;
}

/* ---------- Locating controls and cards ---------- */
function controlFor(key) { return SEGMENTS.includes(key) ? $(`[data-segment="${key}"]`) : document.getElementById(key); }
function cardFor(key) { return controlFor(key)?.closest('.control-row, .control-grid > label, .setting-card'); }
function currentValue(key) {
  if (SEGMENTS.includes(key)) return selected(key) || '';
  const control = document.getElementById(key);
  if (!control) return '';
  return control.type === 'checkbox' ? control.checked : control.value;
}
function prettyValue(key, value) {
  if (typeof value === 'boolean') return value ? 'On' : 'Off';
  return displayValue(SEGMENTS.includes(key) ? `segment:${key}` : key, value);
}

function dots(level, tone) {
  return `<span class="impact-dots ${tone}" aria-label="${LEVEL[level]}">${[1, 2, 3].map(i => `<i class="${i <= level ? 'on' : ''}"></i>`).join('')}</span>`;
}

/* ---------- Inline explanations and info buttons ---------- */
function decorateCards() {
  Object.entries(GUIDE).forEach(([key, guide]) => {
    const card = cardFor(key);
    // Cards that hold several controls (e.g. Adaptive 3D resolution) get one explanation.
    if (!card || card.querySelector('[data-guide]')) return;
    const heading = card.querySelector('h3, strong, .control-grid > label > span') || card.querySelector('span');
    if (!heading) return;
    // A span, not a <button>: many rows are <label>s, and a button would become the label's target.
    const button = document.createElement('span');
    button.setAttribute('role', 'button'); button.tabIndex = 0; button.className = 'guide-button'; button.dataset.guide = key;
    button.setAttribute('aria-label', `Explain ${guide.title}`); button.title = `What does ${guide.title} do?`;
    button.textContent = '?';
    heading.appendChild(button);
    const inline = document.createElement('div');
    inline.className = 'guide-inline';
    inline.innerHTML = `<p>${escapeHtml(guide.what)}</p><div class="guide-chips"><span>FPS cost ${dots(guide.fps, 'cost')}</span><span>Looks ${dots(guide.look, 'look')}</span>${guide.comp ? `<span class="guide-pick">Pro pick: ${escapeHtml(guide.comp.split(/\.\s|\.$/)[0])}</span>` : ''}</div>`;
    const host = heading.closest('.setting-title > div, .toggle-card > div, .control-row > span, .inline-toggle > span') || heading.parentElement;
    if (host === card && card.matches('.control-grid > label')) heading.insertAdjacentElement('afterend', inline);
    else host.appendChild(inline);
  });
  // The width card covers both width and height.
}

/* ---------- Guide drawer ---------- */
let openKey = '';
function buildDrawer() {
  if ($('#guideDrawer')) return;
  const drawer = document.createElement('div');
  drawer.className = 'guide-drawer'; drawer.id = 'guideDrawer'; drawer.setAttribute('aria-hidden', 'true');
  drawer.innerHTML = '<div class="drawer-scrim" data-close-guide></div><aside role="dialog" aria-modal="true" aria-labelledby="guideTitle"><div class="guide-body" id="guideBody"></div></aside>';
  document.body.appendChild(drawer);
  drawer.addEventListener('click', event => {
    if (event.target.closest('[data-close-guide]')) closeGuide();
    const shot = event.target.closest('[data-guide-shot]');
    if (shot) showShot(shot.dataset.guideShot);
    const use = event.target.closest('[data-guide-use]');
    if (use) useRecommended(openKey);
    const go = event.target.closest('[data-guide-go]');
    if (go) { const key = openKey; closeGuide(); goToElement(cardFor(key)); }
    const tab = event.target.closest('[data-guide-tab]');
    if (tab) switchTab(tab.dataset.guideTab);
  });
  document.addEventListener('keydown', event => { if (event.key === 'Escape' && drawer.classList.contains('open')) closeGuide(); });
}

function shotsFor(key) {
  const entry = previewCatalog[key];
  if (!entry) return [];
  const seen = new Set();
  return Object.entries(entry.values).filter(([, file]) => !seen.has(file) && seen.add(file)).map(([value, file]) => ({ value, file }));
}

function openGuide(key) {
  const guide = GUIDE[key];
  if (!guide) return;
  openKey = key;
  const value = currentValue(key);
  const shots = shotsFor(key);
  const currentShot = previewCatalog[key]?.values[String(value)] || shots[0]?.file;
  const recLabel = guide.rec === undefined ? '' : prettyValue(key, guide.rec);
  const recMatches = guide.rec !== undefined && String(value) === String(guide.rec);
  $('#guideBody').innerHTML = `
    <header class="guide-head"><div><span class="eyebrow">Setting guide</span><h2 id="guideTitle">${escapeHtml(guide.title)}</h2><p>Current value <b>${escapeHtml(prettyValue(key, value) || '—')}</b></p></div><button class="guide-close" data-close-guide aria-label="Close">×</button></header>
    ${shots.length ? `<div class="guide-tabs" role="tablist"><button class="active" data-guide-tab="shot" role="tab">Real Apex capture</button><button data-guide-tab="art" role="tab">How it works</button></div>` : ''}
    <div class="guide-media">
      ${shots.length ? `<figure class="guide-shot" data-pane="shot"><img id="guideShotImage" src="../assets/previews/${currentShot}" alt="${escapeHtml(guide.title)} captured in Apex Legends"><figcaption id="guideShotCaption">${escapeHtml(captionFor(key, currentShot))}</figcaption></figure>
        <div class="guide-shot-picker" data-pane="shot">${shots.map(shot => `<button data-guide-shot="${escapeHtml(shot.file)}" class="${shot.file === currentShot ? 'active' : ''}">${escapeHtml(prettyValue(key, shot.value === 'true' ? true : shot.value === 'false' ? false : shot.value))}</button>`).join('')}</div>` : ''}
      <div class="guide-art-wrap" data-pane="art" ${shots.length ? 'hidden' : ''}>${illustration(key, guide)}</div>
    </div>
    <section class="guide-section"><h3>What it does</h3><p>${escapeHtml(guide.what)}</p></section>
    <div class="guide-meters">
      <div><span>FPS cost</span>${meter(guide.fps, 'cost')}<b>${LEVEL[guide.fps]}</b></div>
      <div><span>Visual change</span>${meter(guide.look, 'look')}<b>${LEVEL[guide.look]}</b></div>
    </div>
    ${guide.comp ? `<section class="guide-section guide-rec"><h3>Competitive pick</h3><p>${escapeHtml(guide.comp)}</p>${guide.rec !== undefined ? `<button class="button ${recMatches ? 'button-dark' : 'button-primary'}" data-guide-use ${recMatches ? 'disabled' : ''}>${recMatches ? `Already set to ${escapeHtml(recLabel)}` : `Use ${escapeHtml(recLabel)}`}</button>` : ''}</section>` : ''}
    <footer class="guide-foot"><button class="text-button" data-guide-go>Show me this setting <span>→</span></button><small>Nothing is written to Apex until you press Apply changes.</small></footer>`;
  const drawer = $('#guideDrawer');
  drawer.classList.add('open'); drawer.setAttribute('aria-hidden', 'false');
  setTimeout(() => $('.guide-close', drawer)?.focus(), 50);
}

function meter(level, tone) { return `<i class="guide-meter ${tone}"><i style="width:${Math.round(level / 3 * 100)}%"></i></i>`; }
function captionFor(key, file) {
  const entry = Object.entries(previewCatalog[key]?.values || {}).find(([, name]) => name === file);
  return entry ? `${GUIDE[key].title}: ${prettyValue(key, entry[0] === 'true' ? true : entry[0] === 'false' ? false : entry[0])} — captured in Apex` : '';
}
function showShot(file) {
  const image = $('#guideShotImage');
  if (!image) return;
  image.src = `../assets/previews/${file}`;
  $('#guideShotCaption').textContent = captionFor(openKey, file);
  $$('[data-guide-shot]').forEach(button => button.classList.toggle('active', button.dataset.guideShot === file));
}
function switchTab(name) {
  $$('[data-guide-tab]').forEach(tab => tab.classList.toggle('active', tab.dataset.guideTab === name));
  $$('#guideBody [data-pane]').forEach(pane => { pane.hidden = pane.dataset.pane !== name; });
}
function closeGuide() {
  const drawer = $('#guideDrawer');
  drawer?.classList.remove('open'); drawer?.setAttribute('aria-hidden', 'true');
  const button = $(`[data-guide="${openKey}"]`);
  button?.focus({ preventScroll: true });
}
function useRecommended(key) {
  const guide = GUIDE[key];
  if (!guide || guide.rec === undefined) return;
  if (SEGMENTS.includes(key)) setSegment(key, guide.rec); else setControl(key, guide.rec);
  const control = document.getElementById(key);
  control?.dispatchEvent(new Event('change', { bubbles: true }));
  if (SEGMENTS.includes(key)) $(`[data-segment="${key}"] [data-value="${CSS.escape(String(guide.rec))}"]`)?.click();
  renderReview();
  refreshLoad();
  showToast(`${guide.title} set to ${prettyValue(key, guide.rec)}`, 'Review and press Apply changes to save it.');
  openGuide(key);
}

/* ---------- Explain mode ---------- */
function setExplain(on) {
  document.body.classList.toggle('explain-on', on);
  const toggle = $('#explainToggle');
  if (toggle) { toggle.setAttribute('aria-pressed', String(on)); toggle.querySelector('b').textContent = on ? 'On' : 'Off'; }
  try { localStorage.setItem('riftline.explain', on ? '1' : '0'); } catch {}
}

/* ---------- Graphics load estimate ---------- */
function costOf(key, guide) {
  const value = currentValue(key);
  if (typeof value === 'boolean') return guide.inverse ? (value ? 0 : 1) : (value ? 1 : 0);
  if (guide.range) { const number = parseFloat(value); if (!Number.isFinite(number)) return null; return Math.max(0, Math.min(1, (number - guide.range[0]) / (guide.range[1] - guide.range[0]))); }
  if (!guide.order) return null;
  const index = guide.order.indexOf(String(value));
  if (index < 0) return null;
  return guide.order.length === 1 ? 0 : index / (guide.order.length - 1);
}
const LOAD_KEYS = ['textureQuality', 'anisotropic', 'aa', 'modelDetail', 'particleDetail', 'shadows', 'effects', 'ambientOcclusion', 'mapDecorations', 'decals', 'ragdolls', 'gibs', 'shadowDepth', 'shadowUpres', 'dynamicShadows', 'csmResolution', 'shadowCoverage', 'ssaoQuality', 'ssaoDownsample', 'lodScale', 'fadeScale', 'mapDetailLevel', 'decalLimit', 'particleFallback', 'ragdollCollision', 'viewFov'];
function graphicsLoad() {
  let total = 0, weight = 0;
  LOAD_KEYS.forEach(key => {
    const guide = GUIDE[key], cost = costOf(key, guide);
    if (cost === null || !guide.fps) return;
    total += cost * guide.fps; weight += guide.fps;
  });
  return weight ? total / weight : 0;
}
function pixelLoad() {
  const width = Number(getValue('width')), height = Number(getValue('height'));
  const native = appState?.native;
  if (!width || !height || !native?.width) return null;
  return (width * height) / (native.width * native.height);
}
let loadFrame = 0;
function refreshLoad() {
  cancelAnimationFrame(loadFrame);
  loadFrame = requestAnimationFrame(() => {
    const box = $('#loadEstimate');
    if (!box) return;
    const graphics = graphicsLoad(), pixels = pixelLoad();
    const label = graphics < .2 ? 'Very light' : graphics < .4 ? 'Light' : graphics < .6 ? 'Balanced' : graphics < .8 ? 'Heavy' : 'Very heavy';
    $('#loadGraphicsBar').style.width = `${Math.max(4, Math.round(graphics * 100))}%`;
    $('#loadGraphicsBar').dataset.level = graphics < .4 ? 'low' : graphics < .7 ? 'mid' : 'high';
    $('#loadGraphicsText').textContent = `${label} · ${Math.round(graphics * 100)}%`;
    if (pixels !== null) {
      $('#loadPixelsBar').style.width = `${Math.max(4, Math.min(100, Math.round(pixels / 1.5 * 100)))}%`;
      $('#loadPixelsBar').dataset.level = pixels < .7 ? 'low' : pixels <= 1.05 ? 'mid' : 'high';
      $('#loadPixelsText').textContent = `${Math.round(pixels * 100)}% of native`;
    }
  });
}

/* ---------- Setup codes ---------- */
const CODE_PREFIX = 'RIFT1-';
function makeSetupCode() {
  const data = {};
  snapshot().forEach((value, key) => { if (!['extraCommands', 'execConfig'].includes(key)) data[key] = value; });
  const json = JSON.stringify({ v: 1, build: 28, s: data });
  return CODE_PREFIX + btoa(unescape(encodeURIComponent(json)));
}
function loadSetupCode(raw) {
  const text = String(raw || '').trim().replace(/\s+/g, '');
  if (!text.startsWith(CODE_PREFIX)) throw new Error('That is not a Riftline setup code. Codes start with RIFT1-.');
  let parsed;
  try { parsed = JSON.parse(decodeURIComponent(escape(atob(text.slice(CODE_PREFIX.length))))); }
  catch { throw new Error('This setup code is damaged or incomplete. Copy the whole code and try again.'); }
  if (!parsed || typeof parsed.s !== 'object') throw new Error('This setup code has no settings in it.');
  let applied = 0;
  Object.entries(parsed.s).forEach(([key, value]) => {
    if (key.startsWith('segment:')) { if ($(`[data-segment="${key.slice(8)}"] [data-value="${CSS.escape(String(value))}"]`)) { setSegment(key.slice(8), value); applied++; } return; }
    if (key === 'reticle') { const [r, g, b] = String(value).split(',').map(part => part.trim()); setControl('reticleRed', r); setControl('reticleGreen', g); setControl('reticleBlue', b); applied++; return; }
    const control = document.getElementById(key);
    if (!control || SKIP_TRACK.has(key) || !control.closest('.workspace')) return;
    setControl(key, value); applied++;
  });
  syncReticleFromRgb(); updateDisplayPreview(); markResolutionValidity?.();
  $('#commandPreview') && ($('#commandPreview').textContent = buildCommand());
  renderReview(); refreshLoad();
  return applied;
}

/* ---------- PC Check ---------- */
let pcCheckLoaded = false;
const STATUS_TEXT = { good: 'Looks good', warn: 'Worth fixing', info: 'For your info' };
async function runPcCheck() {
  const list = $('#pcCheckList');
  if (!list) return;
  list.innerHTML = '<div class="pc-loading"><i></i>Checking your PC… this takes a few seconds.</div>';
  try {
    const result = await api('/api/pc-check', {});
    pcCheckLoaded = true;
    const rank = { warn: 0, info: 1, good: 2 };
    const checks = (result.checks || []).slice().sort((a, b) => (rank[a.status] ?? 3) - (rank[b.status] ?? 3));
    const warn = checks.filter(check => check.status === 'warn').length;
    $('#pcCheckSummary').textContent = warn ? `${warn} thing${warn === 1 ? '' : 's'} worth fixing` : 'Everything checked looks good';
    $('#pcCheckSummary').dataset.state = warn ? 'warn' : 'good';
    list.innerHTML = checks.map(check => `
      <article class="pc-check ${escapeHtml(check.status)}">
        <div class="pc-check-head"><span class="pc-status">${STATUS_TEXT[check.status] || ''}</span><h3>${escapeHtml(check.title)}</h3><strong>${escapeHtml(check.value || '')}</strong></div>
        <p>${escapeHtml(check.detail || '')}</p>
        ${check.fix ? `<p class="pc-fix"><b>How to fix</b>${escapeHtml(check.fix)}</p>` : ''}
        ${check.open ? `<button class="button button-dark" data-open-setting="${escapeHtml(check.open)}">${escapeHtml(check.openLabel || 'Open Windows setting')}</button>` : ''}
      </article>`).join('') || '<div class="pc-loading">No checks could run on this PC.</div>';
  } catch (error) {
    list.innerHTML = `<div class="pc-loading error">PC Check could not run: ${escapeHtml(error.message)}</div>`;
  }
}

/* ---------- Nav icons ---------- */
const ICONS = {
  overview: '<path d="M3 11l9-7 9 7v9a1 1 0 0 1-1 1h-5v-6H9v6H4a1 1 0 0 1-1-1z"/>',
  display: '<rect x="3" y="4" width="18" height="12" rx="2"/><path d="M8 20h8M12 16v4"/>',
  visuals: '<path d="M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7S2 12 2 12z"/><circle cx="12" cy="12" r="3"/>',
  advanced: '<path d="M4 6h10M18 6h2M4 12h4M12 12h8M4 18h12M20 18h0"/><circle cx="16" cy="6" r="2"/><circle cx="10" cy="12" r="2"/><circle cx="18" cy="18" r="2"/>',
  launch: '<path d="M5 19l4-1 9-9a2.8 2.8 0 0 0-4-4l-9 9-1 4z"/><path d="M13 6l5 5"/>',
  pccheck: '<rect x="4" y="4" width="16" height="16" rx="2"/><path d="M9 9h6v6H9zM9 1v3M15 1v3M9 20v3M15 20v3M1 9h3M1 15h3M20 9h3M20 15h3"/>',
  safety: '<path d="M12 3l8 3v6c0 5-3.5 8-8 9-4.5-1-8-4-8-9V6z"/><path d="M9 12l2 2 4-4"/>',
  overwatch: '<circle cx="12" cy="12" r="9"/><path d="M8 9l4 7 4-7M12 3v4"/>',
  settings: '<path d="M4 6h16M4 12h16M4 18h10"/><circle cx="18" cy="18" r="2.5"/>',
  games: '<rect x="2" y="7" width="20" height="11" rx="4"/><path d="M7 11v3M5.5 12.5h3M16 12h.01M18 14h.01"/>'
};
function addNavIcons() {
  $$('.nav-item').forEach(item => {
    const icon = ICONS[item.dataset.page];
    const span = item.querySelector('span');
    if (icon && span && !span.querySelector('svg')) { span.innerHTML = `<svg viewBox="0 0 24 24" aria-hidden="true">${icon}</svg>`; span.classList.add('nav-icon'); }
  });
}

/* ---------- Wiring ---------- */
function bind() {
  document.addEventListener('click', event => {
    const info = event.target.closest('[data-guide]');
    if (info) { event.preventDefault(); event.stopPropagation(); openGuide(info.dataset.guide); return; }
    const open = event.target.closest('[data-open-setting]');
    if (open) {
      api('/api/open-windows-setting', { target: open.dataset.openSetting })
        .then(() => showToast('Opened Windows settings', 'Change it there, then press Run check again.'))
        .catch(error => showToast('Could not open that setting', error.message, 'error'));
    }
    if (event.target.closest('[data-pc-check]')) runPcCheck();
    if (event.target.closest('[data-page="pccheck"]') && !pcCheckLoaded) runPcCheck();
    if (event.target.closest('#explainToggle')) setExplain(!document.body.classList.contains('explain-on'));
    if (event.target.closest('[data-copy-setup]')) {
      const code = makeSetupCode();
      $('#setupCodeBox').value = code;
      copyText(code).then(ok => showToast(ok ? 'Setup code copied' : 'Setup code ready', ok ? 'Paste it to a friend or into Riftline on another PC.' : 'Select the code in the box and copy it.'));
    }
    if (event.target.closest('[data-load-setup]')) {
      try {
        const count = loadSetupCode($('#setupCodeBox').value);
        showToast('Setup code loaded', `${count} settings filled in. Check Review, then Apply changes.`);
        openReview();
      } catch (error) { showToast('Could not load that code', error.message, 'error'); }
    }
    refreshLoad();
  }, true);
  document.addEventListener('keydown', event => {
    const info = event.target.closest?.('[data-guide]');
    if (info && (event.key === 'Enter' || event.key === ' ')) { event.preventDefault(); openGuide(info.dataset.guide); }
  });
  document.addEventListener('input', refreshLoad);
  document.addEventListener('change', refreshLoad);
}

function init() {
  addNavIcons();
  decorateCards();
  buildDrawer();
  bind();
  let explain = true;
  try { explain = localStorage.getItem('riftline.explain') !== '0'; } catch {}
  setExplain(explain);
  refreshLoad();
  // Recalculate once the engine state arrives (resetBaseline runs after every hydrate/apply).
  const originalReset = window.resetBaseline;
  if (typeof originalReset === 'function') {
    window.resetBaseline = function patchedReset(...args) { const result = originalReset.apply(this, args); refreshLoad(); return result; };
  }
}

window.riftlineGuide = { GUIDE, LEVEL, dots, openGuide, refreshLoad, makeSetupCode, loadSetupCode, runPcCheck, decorateCards };
if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', init); else init();
})();
