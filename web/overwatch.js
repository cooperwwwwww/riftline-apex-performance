/* Riftline build 30 — game switcher, Overwatch 2 settings page and Games library.
   Loaded after app.js and guide.js and uses their helpers ($, $$, api, askUser, showToast, ...). */
(() => {
'use strict';

const GAMES = { apex: { name: 'Apex Legends', home: 'overview' }, overwatch: { name: 'Overwatch 2', home: 'overwatch' } };
let activeGame = 'apex';
let owState = null;
let owBusy = false;

/* ---------- Game switcher ---------- */
function setGame(game, { openHome = true } = {}) {
  if (!GAMES[game]) game = 'apex';
  activeGame = game;
  document.body.dataset.activeGame = game;
  $$('[data-switch-game]').forEach(button => {
    const on = button.dataset.switchGame === game;
    button.classList.toggle('active', on); button.setAttribute('aria-checked', String(on));
  });
  try { localStorage.setItem('riftline.game', game); } catch {}
  if (openHome) originalOpenPage(GAMES[game].home);
  if (game === 'overwatch' && !owState) loadOverwatch();
}

// Opening a page that belongs to the other game (from search, links or the guide) switches game first.
const originalOpenPage = window.openPage;
window.openPage = function openPageForGame(name) {
  const page = $(`.page[data-page-panel="${CSS.escape(name)}"]`);
  const owner = page?.dataset.game;
  if (owner && owner !== activeGame) setGame(owner, { openHome: false });
  if (name === 'games') loadGames();
  return originalOpenPage(name);
};

/* ---------- Overwatch ---------- */
const OW_LABELS = {
  WindowMode: { 0: 'Fullscreen', 1: 'Borderless', 2: 'Windowed' },
  onoff: { 0: 'Off', 1: 'On' },
  q4: { 1: 'Low', 2: 'Medium', 3: 'High', 4: 'Ultra' },
  light: { 0: 'Low', 1: 'Medium', 2: 'High', 3: 'Ultra' },
  aa: { 0: 'Off', 1: 'Low', 2: 'Medium', 3: 'High' }
};
function owControls() { return $$('[data-ow-key]'); }

function nowLabel(key, values) {
  if (key === 'Resolution') return values.FullScreenWidth && values.FullScreenHeight ? `${values.FullScreenWidth} × ${values.FullScreenHeight}` : '';
  const value = values[key];
  if (value === undefined) return '';
  const control = $(`#ow${key}`);
  const option = control && [...control.options].find(item => item.value === value);
  if (option) return option.textContent;
  if (key === 'FrameRateCap') return `${value} FPS`;
  if (key === 'FullScreenRefresh') return `${value} Hz`;
  if (/Shadow|SSLR/.test(key)) return value === '0' ? 'Off' : `Level ${value}`;
  return value;
}

function currentOf(key) {
  const values = owState?.values || {};
  if (key === 'Resolution') return values.FullScreenWidth && values.FullScreenHeight ? `${values.FullScreenWidth}x${values.FullScreenHeight}` : '';
  return values[key] ?? '';
}

function fillOverwatch() {
  const values = owState?.values || {};
  owControls().forEach(control => {
    const key = control.dataset.owKey;
    const current = currentOf(key);
    if (current && !control.querySelector(`option[value="${CSS.escape(current)}"]`)) {
      // Keep values that are already in the file visible even when they are not in the list.
      const option = document.createElement('option');
      option.value = current; option.textContent = nowLabel(key, values) || current;
      control.appendChild(option);
    }
    control.value = current;
    control.dataset.current = current;
    const now = $(`[data-ow-now="${key}"]`);
    if (now) {
      const label = nowLabel(key, values);
      now.textContent = label ? `Now: ${label}` : 'Now: game default';
    }
  });
  const status = $('#owStatus');
  if (!owState?.settingsExists) { status.textContent = 'Settings file not found'; status.dataset.state = 'warn'; }
  else if (owState.running) { status.textContent = 'Overwatch is running — close it to apply'; status.dataset.state = 'warn'; }
  else { status.textContent = owState.launcher ? `Connected · ${owState.launcher}` : 'Connected'; status.dataset.state = 'good'; }
  $('#owPath').textContent = owState?.settingsPath || '—';
  $('#owBackups').textContent = owState?.backups ? `${owState.backups} backup${owState.backups === 1 ? '' : 's'} saved · Riftline keeps the newest 25` : (owState?.hasOriginal ? 'Original saved' : 'A backup is made before the first change');
  renderAlert();
  updateCount();
}

function renderAlert() {
  const alert = $('#owAlert');
  const monitor = Number(owState?.monitorRefresh || 0);
  const refresh = Number(owState?.values?.FullScreenRefresh || 0);
  const tips = [];
  if (!owState?.settingsExists) tips.push({ text: 'Overwatch has not saved a settings file on this PC yet. Start Overwatch, change any graphics setting, close the game, then come back.' });
  if (monitor && refresh && refresh < monitor) tips.push({ text: `Fullscreen refresh rate is ${refresh} Hz, but your monitor runs at ${monitor} Hz. In Fullscreen mode Overwatch would show at most ${refresh} frames a second.`, fix: () => { setOw('FullScreenRefresh', String(monitor)); setOw('WindowMode', '0'); }, fixLabel: `Use ${monitor} Hz fullscreen` });
  if (owState?.values?.TripleBufferingEnabled === '1' && owState?.values?.VerticalSyncEnabled !== '1') tips.push({ text: 'Triple buffering is on without V-Sync. It only helps with V-Sync and adds input lag otherwise.', fix: () => setOw('TripleBufferingEnabled', '0'), fixLabel: 'Turn triple buffering off' });
  if (owState?.readOnly) tips.push({ text: 'Your settings file is marked read-only. Riftline will unlock it to save and lock it again, so in-game changes will not stick.' });
  alert.hidden = tips.length === 0;
  alert.innerHTML = tips.map((tip, index) => `<div><p>${escapeHtml(tip.text)}</p>${tip.fix ? `<button class="button button-dark" data-ow-fix="${index}">${escapeHtml(tip.fixLabel)}</button>` : ''}</div>`).join('');
  alert._fixes = tips.map(tip => tip.fix);
}

function setOw(key, value) {
  const control = $(`#ow${key}`);
  if (!control) return;
  if (![...control.options].some(option => option.value === value)) {
    const option = document.createElement('option'); option.value = value; option.textContent = value; control.appendChild(option);
  }
  control.value = value;
  updateCount();
}

function owChanges() {
  const values = {};
  owControls().forEach(control => {
    const key = control.dataset.owKey, value = control.value;
    if (value === '' || value === (control.dataset.current || '')) return;
    if (key === 'Resolution') { const [width, height] = value.split('x'); values.FullScreenWidth = width; values.FullScreenHeight = height; }
    else values[key] = value;
  });
  return values;
}

function updateCount() {
  const count = Object.keys(owChanges()).length;
  const badge = $('#owCount');
  if (badge) { badge.textContent = String(count); badge.classList.toggle('has-changes', count > 0); }
  owControls().forEach(control => control.closest('.setting-card')?.classList.toggle('ow-changed', control.value !== '' && control.value !== (control.dataset.current || '')));
}

async function loadOverwatch() {
  try { owState = await api('/api/ow-state'); fillOverwatch(); }
  catch (error) { $('#owStatus').textContent = 'Could not read Overwatch settings'; showToast('Overwatch settings could not be read', error.message, 'error'); }
}

async function applyOverwatch() {
  if (owBusy) return;
  const values = owChanges();
  const count = Object.keys(values).length;
  if (!count) { showToast('Nothing to apply', 'Change a setting first. “Leave as is” keeps the current value.'); return; }
  owBusy = true;
  try {
    const result = await api('/api/ow-apply', { values });
    owState = result.state; fillOverwatch();
    showToast('Overwatch settings saved', `${result.message} A backup was made first. Start Overwatch to use them.`);
  } catch (error) { showToast('Overwatch settings were not changed', error.message, 'error'); }
  finally { owBusy = false; }
}

async function restoreOverwatch(which) {
  const original = which === 'original';
  const choice = await askUser({
    title: original ? 'Restore your original Overwatch settings?' : 'Undo the last Overwatch change?',
    body: original ? 'This puts back the settings file exactly as it was before Riftline first changed it. Overwatch must be closed.' : 'This puts back the settings file from just before the most recent change. Overwatch must be closed.',
    confirm: original ? 'Restore original' : 'Undo last change'
  });
  if (choice !== 'confirm') return;
  try { const result = await api('/api/ow-restore', { which }); owState = result.state; fillOverwatch(); showToast('Overwatch settings restored', result.message); }
  catch (error) { showToast('Nothing was restored', error.message, 'error'); }
}

const OW_PRESETS = {
  fps: { WindowMode: '0', CpuForceSyncEnabled: '1', TripleBufferingEnabled: '0', VerticalSyncEnabled: '0', ShowIntro: '0', TextureDetail: '2', ModelQuality: '1', LightQuality: '0', AADetail: '0', MaxAnisotropy: '4', DirectionalShadowDetail: '0', SimpleDirectionalShadows: '1', TranslucentShadowDetail: '0', SSAOEnabled: '0', LocalReflections: '0', SSLRDetailLevel: '0', RefractionDetail: '0', DynamicAmbient: '0', LocalFogDetail: '0' },
  balanced: { WindowMode: '0', CpuForceSyncEnabled: '1', TripleBufferingEnabled: '0', VerticalSyncEnabled: '0', ShowIntro: '0', TextureDetail: '3', ModelQuality: '2', LightQuality: '1', AADetail: '1', MaxAnisotropy: '8', SSAOEnabled: '0', LocalReflections: '0', RefractionDetail: '1', DynamicAmbient: '1', LocalFogDetail: '1' },
  quality: { WindowMode: '0', CpuForceSyncEnabled: '0', TripleBufferingEnabled: '0', VerticalSyncEnabled: '0', TextureDetail: '4', ModelQuality: '4', LightQuality: '3', AADetail: '3', MaxAnisotropy: '16', SimpleDirectionalShadows: '0', SSAOEnabled: '1', LocalReflections: '1', RefractionDetail: '1', DynamicAmbient: '1', LocalFogDetail: '1' }
};
function applyOwPreset(name) {
  const preset = OW_PRESETS[name];
  if (!preset) return;
  Object.entries(preset).forEach(([key, value]) => setOw(key, value));
  const monitor = Number(owState?.monitorRefresh || 0);
  if (monitor) setOw('FullScreenRefresh', String(monitor));
  updateCount();
  showToast(`${name === 'fps' ? 'Most FPS' : name === 'balanced' ? 'Balanced' : 'Best picture'} loaded`, 'Nothing is saved yet. Check the highlighted settings, then press Apply.');
}

/* ---------- Games library ---------- */
let gamesLoaded = false;
async function loadGames(force = false) {
  if (gamesLoaded && !force) return;
  const grid = $('#gamesGrid');
  grid.innerHTML = '<div class="pc-loading"><i></i>Looking for installed games…</div>';
  try {
    const result = await api('/api/games');
    gamesLoaded = true;
    const games = result.games || [];
    grid.innerHTML = games.length ? games.map(game => `
      <article class="game-card ${game.tunable ? 'tunable' : ''}">
        <div class="game-art" aria-hidden="true">${escapeHtml(game.name.replace(/[®™]/g, '').split(/\s+/).map(word => word[0]).join('').slice(0, 3).toUpperCase())}</div>
        <div class="game-info"><h3>${escapeHtml(game.name.replace(/[®™]/g, ''))}</h3><p>${game.sizeGb ? `${game.sizeGb} GB on disk` : 'Installed'} · Steam</p>
          <span class="game-badge">${game.tunable ? 'Tunable in Riftline' : 'Launch only'}</span></div>
        <div class="game-actions">${game.tunable ? `<button class="button button-primary" data-tune-game="${escapeHtml(game.tunable)}">Tune settings</button>` : ''}<button class="button button-dark" data-launch-game="${escapeHtml(game.appid)}" data-game-name="${escapeHtml(game.name.replace(/[®™]/g, ''))}">Launch</button></div>
      </article>`).join('') : '<div class="pc-loading">No Steam games were found on this PC.</div>';
  } catch (error) { grid.innerHTML = `<div class="pc-loading error">Could not list your games: ${escapeHtml(error.message)}</div>`; }
}

/* ---------- Wiring ---------- */
document.addEventListener('click', event => {
  const target = event.target;
  const switcher = target.closest('[data-switch-game]');
  if (switcher) { setGame(switcher.dataset.switchGame); return; }
  if (target.closest('[data-ow-apply]')) { applyOverwatch(); return; }
  if (target.closest('[data-ow-launch]')) {
    api('/api/ow-launch', {}).then(() => showToast('Starting Overwatch', `Opening it through ${owState?.launcher || 'its launcher'}.`)).catch(error => showToast('Could not start Overwatch', error.message, 'error'));
    return;
  }
  const restore = target.closest('[data-ow-restore]');
  if (restore) { restoreOverwatch(restore.dataset.owRestore); return; }
  const preset = target.closest('[data-ow-preset]');
  if (preset) { applyOwPreset(preset.dataset.owPreset); return; }
  const fix = target.closest('[data-ow-fix]');
  if (fix) { $('#owAlert')._fixes?.[Number(fix.dataset.owFix)]?.(); showToast('Fix loaded', 'Press Apply to save it to Overwatch.'); return; }
  if (target.closest('[data-games-refresh]')) { loadGames(true); return; }
  const tune = target.closest('[data-tune-game]');
  if (tune) { setGame(tune.dataset.tuneGame); return; }
  const launch = target.closest('[data-launch-game]');
  if (launch) {
    api('/api/launch-game', { appid: launch.dataset.launchGame }).then(() => showToast(`Starting ${launch.dataset.gameName}`, 'Steam is opening the game.')).catch(error => showToast('Could not start that game', error.message, 'error'));
  }
});
document.addEventListener('change', event => { if (event.target.matches?.('[data-ow-key]')) updateCount(); });
window.addEventListener('focus', () => { if (activeGame === 'overwatch' && !owBusy && Object.keys(owChanges()).length === 0) loadOverwatch(); });

let saved = 'apex';
try { saved = localStorage.getItem('riftline.game') || 'apex'; } catch {}
setGame(saved);
window.riftlineGames = { setGame, loadOverwatch, owChanges };
})();
