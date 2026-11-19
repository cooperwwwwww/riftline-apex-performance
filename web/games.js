/* Riftline build 31 — Unreal Engine games (THE FINALS, Fortnite, Marvel Rivals, ...).
   One page serves every supported Unreal game: the engine reports which ones have a settings
   file on this PC, and each gets a button in the game switcher. Loaded after overwatch.js. */
(() => {
'use strict';

const QUALITY = [['0', 'Low'], ['1', 'Medium'], ['2', 'High'], ['3', 'Epic'], ['4', 'Cinematic']];
const TRUE_FALSE = [['False', 'Off'], ['True', 'On']];
const RESOLUTIONS = ['3840x2160', '3440x1440', '2560x1440', '2560x1080', '1920x1200', '1920x1080', '1680x1050', '1600x900', '1440x1080', '1280x960', '1280x720'];
const CAPS = [['0.000000', 'Unlimited'], ...[360, 300, 240, 237, 200, 165, 162, 144, 141, 120, 60].map(fps => [`${fps}.000000`, `${fps} FPS`])];
const SCALE = [100, 90, 85, 80, 75, 70, 67, 60, 50].map(value => [String(value), `${value}%`]);

// key: the ini key; art/fps/look/comp/rec feed the setting guide (guide.js).
const FIELDS = [
  { group: 'Display and frame rate', key: 'FullscreenMode', title: 'Window mode', desc: 'Fullscreen has the lowest input lag', options: [['0', 'Fullscreen'], ['1', 'Windowed fullscreen'], ['2', 'Windowed']],
    what: 'Fullscreen gives the game the monitor to itself, which has the lowest input lag. Windowed fullscreen (borderless) makes Alt+Tab instant but can add a little lag.', fps: 1, look: 0, comp: 'Fullscreen.', rec: '0', art: 'window', labels: ['Windowed', 'Fullscreen'] },
  { group: 'Display and frame rate', key: 'Resolution', title: 'Resolution', desc: 'Output resolution', options: RESOLUTIONS.map(value => [value, value.replace('x', ' × ')]),
    what: 'How many pixels the game draws. Lower is faster but softer. Use 3D resolution below to drop pixels while keeping the HUD sharp.', fps: 3, look: 3, comp: 'Your native resolution.', art: 'pixels', labels: ['Low', 'Native'] },
  { group: 'Display and frame rate', key: 'FrameRateLimit', title: 'Frame rate limit', desc: 'Unlimited, or a fixed cap', options: CAPS,
    what: 'Maximum frames per second. Unlimited gives the most FPS; a cap a little under what your PC holds keeps frame times steady and the GPU cooler, which can lower input lag.', fps: 0, look: 0, comp: 'Unlimited, or 3 under your refresh rate with G-Sync/FreeSync.', rec: '0.000000', art: 'fps', labels: ['Uncapped', 'Capped'] },
  { group: 'Display and frame rate', key: 'bUseVSync', title: 'V-Sync', desc: 'Stops tearing, adds input lag', options: TRUE_FALSE,
    what: 'Locks frames to your monitor refresh to stop tearing, but adds noticeable input lag.', fps: 0, look: 1, comp: 'Off.', rec: 'False', art: 'vsync', labels: ['Off: tearing', 'On: extra lag'] },
  { group: 'Display and frame rate', key: 'sg.ResolutionQuality', title: '3D resolution', desc: 'Render scale; 100% is native', options: SCALE,
    what: 'Draws the 3D world at a percentage of your resolution and scales it up; the HUD stays sharp. Lower values give big FPS gains but blur the picture. Upscalers like DLSS set this themselves.', fps: 3, look: 3, comp: '100%, or 75–85% on a weak GPU.', rec: '100', art: 'pixels', labels: ['50%', '100%'] },
  { group: 'Display and frame rate', key: 'bUseDynamicResolution', title: 'Dynamic resolution', desc: 'Lowers 3D resolution under load', options: TRUE_FALSE,
    what: 'Automatically lowers the 3D resolution when FPS drops. Keeps FPS up, but the image sharpness keeps changing.', fps: 0, look: 2, comp: 'Off for a consistent image.', rec: 'False', art: 'pixels', labels: ['Off', 'On'] },
  { group: 'Display and frame rate', key: 'bUseD3D12InGame', title: 'DirectX version', desc: 'DirectX 12 or DirectX 11', options: [['True', 'DirectX 12'], ['False', 'DirectX 11']],
    what: 'Which graphics API the game uses. DirectX 12 is needed for DLSS frame generation and ray tracing; DirectX 11 can have fewer shader stutters in some games.', fps: 1, look: 0, comp: 'DirectX 12 unless you get stutters.', art: 'cpu', labels: ['DirectX 11', 'DirectX 12'] },
  { group: 'Graphics quality', key: 'sg.ViewDistanceQuality', title: 'View distance', desc: 'How far detail is drawn', options: QUALITY,
    what: 'How far away objects stay detailed. Lower makes distant buildings and props simpler.', fps: 2, look: 2, comp: 'Medium.', rec: '1', art: 'distance', labels: ['Low', 'Cinematic'] },
  { group: 'Graphics quality', key: 'sg.AntiAliasingQuality', title: 'Anti-aliasing', desc: 'Smooths jagged edges', options: QUALITY,
    what: 'Smooths jagged edges. Higher levels look cleaner but blur fine detail and cost FPS.', fps: 1, look: 2, comp: 'Low.', rec: '0', art: 'aa', labels: ['Low', 'Cinematic'] },
  { group: 'Graphics quality', key: 'sg.ShadowQuality', title: 'Shadows', desc: 'Shadow detail and range', options: QUALITY,
    what: 'Detail and range of shadows. One of the most expensive settings, and lower shadows make enemies in shade easier to see.', fps: 3, look: 2, comp: 'Low.', rec: '0', art: 'shadow', labels: ['Low', 'Cinematic'] },
  { group: 'Graphics quality', key: 'sg.GlobalIlluminationQuality', title: 'Global illumination', desc: 'Bounced light', options: QUALITY,
    what: 'Light bouncing off surfaces. Very expensive at high settings, especially with Lumen or RTXGI.', fps: 3, look: 2, comp: 'Low.', rec: '0', art: 'ao', labels: ['Low', 'Cinematic'] },
  { group: 'Graphics quality', key: 'sg.ReflectionQuality', title: 'Reflections', desc: 'Shiny surfaces and water', options: QUALITY,
    what: 'Quality of reflections on floors, windows and water.', fps: 2, look: 1, comp: 'Low.', rec: '0', art: 'bloom', labels: ['Cinematic', 'Low'] },
  { group: 'Graphics quality', key: 'sg.PostProcessQuality', title: 'Post-processing', desc: 'Bloom, depth of field, blur', options: QUALITY,
    what: 'Screen effects such as bloom, depth of field and motion blur. Lower values give a clearer image.', fps: 1, look: 1, comp: 'Low.', rec: '0', art: 'motion', labels: ['Cinematic', 'Low'] },
  { group: 'Graphics quality', key: 'sg.TextureQuality', title: 'Textures', desc: 'Surface sharpness; uses VRAM', options: QUALITY,
    what: 'Sharpness of surfaces. Mostly uses graphics memory; too high for your card causes stutters.', fps: 1, look: 2, comp: 'High with 8 GB VRAM or more, Medium otherwise.', art: 'texture', labels: ['Low', 'Cinematic'] },
  { group: 'Graphics quality', key: 'sg.EffectsQuality', title: 'Effects', desc: 'Explosions, smoke and sparks', options: QUALITY,
    what: 'Detail of explosions, smoke and particles. Higher costs a lot in big fights and adds clutter.', fps: 2, look: 2, comp: 'Low.', rec: '0', art: 'particles', labels: ['Low', 'Cinematic'] },
  { group: 'Graphics quality', key: 'sg.FoliageQuality', title: 'Foliage', desc: 'Grass and plants', options: QUALITY,
    what: 'Amount and distance of grass and plants. Less foliage is faster and hides fewer players.', fps: 2, look: 1, comp: 'Low.', rec: '0', art: 'decor', labels: ['Low', 'Cinematic'] },
  { group: 'Graphics quality', key: 'sg.ShadingQuality', title: 'Shading', desc: 'Material and lighting detail', options: QUALITY,
    what: 'Detail of materials and how light falls on them.', fps: 1, look: 1, comp: 'Low or Medium.', rec: '0', art: 'model', labels: ['Low', 'Cinematic'] },
  { group: 'Clarity and latency', embark: true, key: 'DLSSFrameGenerationMode', title: 'DLSS frame generation', desc: 'Only Off can be set here', options: [['Off', 'Off']],
    what: 'Inserts generated frames between real ones. The FPS counter goes up, but input lag goes up too, and moving targets can smear.', fps: 0, look: 1, comp: 'Off for competitive play.', rec: 'Off', art: 'latency', labels: ['On', 'Off'] },
  { group: 'Clarity and latency', embark: true, key: 'MotionBlurMode', title: 'Motion blur', desc: 'Only Off can be set here', options: [['Off', 'Off']],
    what: 'Blurs the image when you turn. Off keeps targets sharp while flicking.', fps: 0, look: 1, comp: 'Off.', rec: 'Off', art: 'motion', labels: ['Blur', 'Sharp'] },
  { group: 'Clarity and latency', embark: true, key: 'LensDistortionEnabled', title: 'Lens distortion', desc: 'Curved-lens effect', options: TRUE_FALSE,
    what: 'Bends the edges of the screen like a camera lens. Off keeps lines straight and targets where you expect them.', fps: 0, look: 1, comp: 'Off.', rec: 'False', art: 'fov', labels: ['Off', 'On'] }
];
const PRESETS = {
  fps: { FullscreenMode: '0', bUseVSync: 'False', bUseDynamicResolution: 'False', 'sg.ResolutionQuality': '100', 'sg.ViewDistanceQuality': '1', 'sg.AntiAliasingQuality': '0', 'sg.ShadowQuality': '0', 'sg.GlobalIlluminationQuality': '0', 'sg.ReflectionQuality': '0', 'sg.PostProcessQuality': '0', 'sg.TextureQuality': '2', 'sg.EffectsQuality': '0', 'sg.FoliageQuality': '0', 'sg.ShadingQuality': '0', DLSSFrameGenerationMode: 'Off', MotionBlurMode: 'Off', LensDistortionEnabled: 'False' },
  balanced: { FullscreenMode: '0', bUseVSync: 'False', 'sg.ResolutionQuality': '100', 'sg.ViewDistanceQuality': '2', 'sg.AntiAliasingQuality': '2', 'sg.ShadowQuality': '1', 'sg.GlobalIlluminationQuality': '1', 'sg.ReflectionQuality': '1', 'sg.PostProcessQuality': '1', 'sg.TextureQuality': '2', 'sg.EffectsQuality': '1', 'sg.FoliageQuality': '1', 'sg.ShadingQuality': '2', MotionBlurMode: 'Off' },
  quality: { FullscreenMode: '0', 'sg.ResolutionQuality': '100', 'sg.ViewDistanceQuality': '3', 'sg.AntiAliasingQuality': '3', 'sg.ShadowQuality': '3', 'sg.GlobalIlluminationQuality': '3', 'sg.ReflectionQuality': '3', 'sg.PostProcessQuality': '3', 'sg.TextureQuality': '3', 'sg.EffectsQuality': '3', 'sg.FoliageQuality': '3', 'sg.ShadingQuality': '3' }
};

const idFor = key => `ue-${key.replace(/\./g, '-')}`;
let current = '';      // active Unreal game id
let state = null;
let busy = false;

/* ---------- Rendering ---------- */
function visibleFields() { return FIELDS.filter(field => !field.embark || state?.embark); }

function render() {
  const groups = {};
  visibleFields().forEach(field => { (groups[field.group] ||= []).push(field); });
  $('#ueGroups').innerHTML = Object.entries(groups).map(([group, fields]) => `
    <section class="ow-group"><header><span>${escapeHtml(group)}</span>${group === 'Clarity and latency' ? '<small>Options marked “Only Off” can be switched off here; turn them on in the game menu.</small>' : ''}</header><div class="settings-list two-up">
      ${fields.map(field => `<article class="setting-card ow-card" data-search="${escapeHtml(`${state?.name || ''} ${field.title} ${field.key}`)}"><div class="setting-title"><div><h3>${escapeHtml(field.title)}</h3><p>${escapeHtml(field.desc)}</p><span class="ow-now" data-ue-now="${escapeHtml(field.key)}"></span></div>
        <select id="${idFor(field.key)}" data-ue-key="${escapeHtml(field.key)}"><option value="">Leave as is</option>${field.options.map(([value, label]) => `<option value="${escapeHtml(value)}">${escapeHtml(label)}</option>`).join('')}</select></div></article>`).join('')}
    </div></section>`).join('') + ingameCard();
  // Explanations and ? buttons come from the shared setting guide.
  visibleFields().forEach(field => {
    riftlineGuide.GUIDE[idFor(field.key)] = { title: field.title, what: field.what, fps: field.fps, look: field.look, comp: field.comp, rec: field.rec, art: field.art, labels: field.labels };
  });
  riftlineGuide.decorateCards?.();
}

function ingameCard() {
  const values = state?.values || {};
  const rows = [
    ['NVIDIA Reflex', values.NvReflexMode, 'Enabled + Boost on NVIDIA cards'],
    ['Upscaler', values.ResolutionScalingMethod, 'DLSS Quality on NVIDIA, or off for the sharpest image'],
    ['DLSS mode', values.DLSSMode, 'Quality or Balanced'],
    ['Global illumination (RTXGI)', values.RTXGIQuality, 'Static or the lowest dynamic setting']
  ].filter(([, value]) => value !== undefined);
  if (!rows.length) return '';
  return `<article class="ow-checklist"><h3>Set these in the game menu</h3><p>Riftline shows these but does not change them, because their values differ between game versions.</p><ul>${rows.map(([name, value, pick]) => `<li><strong>${escapeHtml(name)}</strong><b>Now: ${escapeHtml(value)}</b><small>Pick: ${escapeHtml(pick)}</small></li>`).join('')}</ul></article>`;
}

function currentOf(key) {
  const values = state?.values || {};
  if (key === 'Resolution') return values.ResolutionSizeX && values.ResolutionSizeY ? `${values.ResolutionSizeX}x${values.ResolutionSizeY}` : '';
  return values[key] ?? '';
}

function nowLabel(key, control) {
  const value = currentOf(key);
  if (!value) return 'Now: game default';
  const option = [...control.options].find(item => item.value === value);
  return `Now: ${option ? option.textContent : value}`;
}

function fill() {
  $('#ueTitle').textContent = state?.name || 'Game';
  $('#ueEyebrow').textContent = `${state?.name || 'Game'} · Unreal Engine`;
  $('#ueNavName').textContent = state?.name || 'Game';
  $$('[data-ue-key]').forEach(control => {
    const key = control.dataset.ueKey, value = currentOf(key);
    if (value && ![...control.options].some(option => option.value === value)) {
      const option = document.createElement('option');
      option.value = value;
      option.textContent = key === 'FrameRateLimit' ? `${Math.round(Number(value))} FPS` : key === 'sg.ResolutionQuality' ? `${value}%` : value.replace('x', ' × ');
      control.appendChild(option);
    }
    control.value = value; control.dataset.current = value;
    const now = $(`[data-ue-now="${CSS.escape(key)}"]`);
    if (now) now.textContent = nowLabel(key, control);
  });
  const status = $('#ueStatus');
  if (!state?.settingsExists) { status.textContent = 'Settings file not found'; status.dataset.state = 'warn'; }
  else if (state.running) { status.textContent = `${state.name} is running — close it to apply`; status.dataset.state = 'warn'; }
  else { status.textContent = 'Connected'; status.dataset.state = 'good'; }
  $('#uePath').textContent = state?.settingsPath || '—';
  $('#ueBackups').textContent = state?.backups ? `${state.backups} backup${state.backups === 1 ? '' : 's'} saved · Riftline keeps the newest 25` : 'A backup is made before the first change';
  const lock = $('#ueLock');
  lock.checked = Boolean(state?.readOnly); lock.disabled = !state?.settingsExists;
  renderAlerts();
  updateCount();
}

function renderAlerts() {
  const values = state?.values || {};
  const tips = [];
  if (values.DLSSFrameGenerationMode && values.DLSSFrameGenerationMode !== 'Off') tips.push({ text: `DLSS frame generation is on (${values.DLSSFrameGenerationMode}). It raises the FPS counter but adds input lag, which hurts aim in competitive play.`, fix: () => setValue('DLSSFrameGenerationMode', 'Off'), label: 'Turn frame generation off' });
  if (values.bUseVSync === 'True') tips.push({ text: 'V-Sync is on, which adds input lag. Use G-Sync/FreeSync with a frame limit instead.', fix: () => setValue('bUseVSync', 'False'), label: 'Turn V-Sync off' });
  if (values.FullscreenMode && values.FullscreenMode !== '0') tips.push({ text: `The game runs in ${values.FullscreenMode === '1' ? 'windowed fullscreen' : 'a window'}. True fullscreen has the lowest input lag.`, fix: () => setValue('FullscreenMode', '0'), label: 'Use fullscreen' });
  if (state?.readOnly) tips.push({ text: 'The settings file is locked, so changes you make in the game will not be saved. Riftline unlocks it while applying.' });
  const alert = $('#ueAlert');
  alert.hidden = tips.length === 0;
  alert.innerHTML = tips.map((tip, index) => `<div><p>${escapeHtml(tip.text)}</p>${tip.fix ? `<button class="button button-dark" data-ue-fix="${index}">${escapeHtml(tip.label)}</button>` : ''}</div>`).join('');
  alert._fixes = tips.map(tip => tip.fix);
}

function setValue(key, value) {
  const control = document.getElementById(idFor(key));
  if (!control) return;
  if (![...control.options].some(option => option.value === value)) { const option = document.createElement('option'); option.value = value; option.textContent = value; control.appendChild(option); }
  control.value = value;
  updateCount();
}

function changes() {
  const values = {};
  $$('[data-ue-key]').forEach(control => {
    const key = control.dataset.ueKey, value = control.value;
    if (value === '' || value === (control.dataset.current || '')) return;
    if (key === 'Resolution') { const [x, y] = value.split('x'); values.ResolutionSizeX = x; values.ResolutionSizeY = y; }
    else values[key] = value;
  });
  return values;
}

function updateCount() {
  const count = Object.keys(changes()).length;
  const badge = $('#ueCount');
  if (badge) { badge.textContent = String(count); badge.classList.toggle('has-changes', count > 0); }
  $$('[data-ue-key]').forEach(control => control.closest('.setting-card')?.classList.toggle('ow-changed', control.value !== '' && control.value !== (control.dataset.current || '')));
}

/* ---------- Engine calls ---------- */
async function load(id) {
  current = id;
  $('#ueStatus').textContent = 'Checking…';
  try {
    state = await api('/api/ue-state', { id });
    if (current !== id) return;
    render(); fill();
  } catch (error) { showToast('Could not read the game settings', error.message, 'error'); }
}

async function apply() {
  if (busy || !current) return;
  const values = changes();
  if (!Object.keys(values).length) { showToast('Nothing to apply', 'Change a setting first. “Leave as is” keeps the current value.'); return; }
  busy = true;
  try {
    const result = await api('/api/ue-apply', { id: current, values });
    state = result.state; fill();
    showToast(`${state.name} settings saved`, `${result.message} A backup was made first.`);
  } catch (error) { showToast('Settings were not changed', error.message, 'error'); }
  finally { busy = false; }
}

async function restore(which) {
  const original = which === 'original';
  const choice = await askUser({
    title: original ? `Restore your original ${state?.name} settings?` : `Undo the last ${state?.name} change?`,
    body: original ? 'This puts the settings file back exactly as it was before Riftline first changed it. The game must be closed.' : 'This puts back the settings file from just before the most recent change. The game must be closed.',
    confirm: original ? 'Restore original' : 'Undo last change'
  });
  if (choice !== 'confirm') return;
  try { const result = await api('/api/ue-restore', { id: current, which }); state = result.state; fill(); showToast('Settings restored', result.message); }
  catch (error) { showToast('Nothing was restored', error.message, 'error'); }
}

function applyPreset(name) {
  const preset = PRESETS[name];
  Object.entries(preset).forEach(([key, value]) => setValue(key, value));
  showToast(`${name === 'fps' ? 'Most FPS' : name === 'balanced' ? 'Balanced' : 'Best picture'} loaded`, 'Nothing is saved yet. Check the highlighted settings, then press Apply.');
}

/* ---------- Wiring ---------- */
document.addEventListener('click', event => {
  if (!current) return;
  const target = event.target;
  if (target.closest('[data-ue-apply]')) { apply(); return; }
  if (target.closest('[data-ue-launch]')) {
    api('/api/ue-launch', { id: current }).then(() => showToast(`Starting ${state?.name}`, 'The launcher is opening the game.')).catch(error => showToast('Could not start the game', error.message, 'error'));
    return;
  }
  const restoreButton = target.closest('[data-ue-restore]');
  if (restoreButton) { restore(restoreButton.dataset.ueRestore); return; }
  const preset = target.closest('[data-ue-preset]');
  if (preset) { applyPreset(preset.dataset.uePreset); return; }
  const fix = target.closest('[data-ue-fix]');
  if (fix) { $('#ueAlert')._fixes?.[Number(fix.dataset.ueFix)]?.(); showToast('Fix loaded', 'Press Apply to save it.'); }
});
document.addEventListener('change', event => {
  if (event.target.matches?.('[data-ue-key]')) updateCount();
  if (event.target.id === 'ueLock' && current) {
    const locked = event.target.checked;
    api('/api/ue-lock', { id: current, locked }).then(result => { state = result; fill(); showToast(locked ? 'Settings file locked' : 'Settings file unlocked'); })
      .catch(error => { event.target.checked = !locked; showToast('Could not change the lock', error.message, 'error'); });
  }
});
window.addEventListener('focus', () => { if (current && riftlineGames.active === current && !busy && !Object.keys(changes()).length) load(current); });

api('/api/ue-list').then(result => {
  (result.games || []).filter(game => game.detected).forEach(game => {
    riftlineGames.register(game.id, { name: game.name, home: 'unreal', family: 'unreal', onSelect: id => { if (id !== current || !state) load(id); } });
  });
}).catch(() => {});
window.riftlineUnreal = { load, changes };
})();
