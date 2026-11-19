/* Riftline build 31 — game switcher, Overwatch 2 settings page and Games library.
   Loaded after app.js and guide.js and uses their helpers ($, $$, api, askUser, showToast, ...).
   games.js registers the Unreal Engine games it finds through riftlineGames.register. */
(() => {
'use strict';

// family decides which pages show: every page and button carries data-game="<family>".
const GAMES = {
  apex: { name: 'Apex Legends', home: 'overview', family: 'apex' },
  overwatch: { name: 'Overwatch 2', home: 'overwatch', family: 'overwatch' }
};
let activeGame = 'apex';
let owState = null;
let owBusy = false;
// A saved Unreal game is selected once games.js has found and registered it.
let savedGame = 'apex';
try { savedGame = localStorage.getItem('riftline.game') || 'apex'; } catch {}

/* ---------- Game switcher ---------- */
function setGame(game, { openHome = true } = {}) {
  if (!GAMES[game]) game = 'apex';
  activeGame = game;
  const def = GAMES[game];
  document.body.dataset.activeGame = game;
  document.body.dataset.family = def.family;
  $$('[data-switch-game]').forEach(button => {
    const on = button.dataset.switchGame === game;
    button.classList.toggle('active', on); button.setAttribute('aria-checked', String(on));
  });
  try { localStorage.setItem('riftline.game', game); } catch {}
  def.onSelect?.(game);
  if (openHome) originalOpenPage(def.home);
  if (game === 'overwatch' && !owState) loadOverwatch();
}

function register(id, def) {
  if (GAMES[id]) return;
  GAMES[id] = def;
  const button = document.createElement('button');
  button.dataset.switchGame = id; button.setAttribute('role', 'radio'); button.textContent = def.name;
  $('#gameSwitch')?.appendChild(button);
  if (savedGame === id) setGame(id);
}

// Opening a page that belongs to another game (from search, links or the guide) switches game first.
const originalOpenPage = window.openPage;
window.openPage = function openPageForGame(name) {
  const page = $(`.page[data-page-panel="${CSS.escape(name)}"]`);
  const owner = page?.dataset.game;
  if (owner && owner !== GAMES[activeGame]?.family && GAMES[owner]) setGame(owner, { openHome: false });
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
  if (key === 'FrameRateCap' && values.LimitToRefresh === '1' && values.UseCustomFrameRates !== '1') return 'Match refresh rate';
  const value = values[key];
  if (value === undefined) return '';
  const control = $(`#ow${key}`);
  const option = control && [...control.options].find(item => item.value === value);
  if (option) return option.textContent;
  if (key === 'FrameRateCap') return `${value} FPS`;
  if (/Volume$/.test(key)) return `${Math.round(Number(value))}%`;
  if (key === 'FullScreenRefresh') return `${value} Hz`;
  if (/Shadow|SSLR/.test(key)) return value === '0' ? 'Off' : `Level ${value}`;
  return value;
}

function currentOf(key) {
  const values = owState?.values || {};
  if (key === 'Resolution') return values.FullScreenWidth && values.FullScreenHeight ? `${values.FullScreenWidth}x${values.FullScreenHeight}` : '';
  if (key === 'FrameRateCap' && values.LimitToRefresh === '1' && values.UseCustomFrameRates !== '1') return 'refresh';
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
  const lock = $('#owLock');
  if (lock) { lock.checked = Boolean(owState?.readOnly); lock.disabled = !owState?.settingsExists; }
  const cache = $('#owCacheSize');
  if (cache) cache.textContent = owState?.cacheMb ? `Current cache: ${owState.cacheMb} MB.` : 'The cache is empty right now.';
  const raw = $('#owRaw');
  if (raw) raw.innerHTML = (owState?.everything || []).length
    ? `<table><thead><tr><th>Section</th><th>Setting</th><th>Value</th></tr></thead><tbody>${owState.everything.map(row => `<tr class="${row.managed ? 'managed' : ''}"><td>${escapeHtml(row.section)}</td><td>${escapeHtml(row.key)}</td><td>${escapeHtml(row.value)}</td></tr>`).join('')}</tbody></table>`
    : '<p>The file has no settings yet.</p>';
  updateCount();
}

function renderAlert() {
  const alert = $('#owAlert');
  const monitor = Number(owState?.monitorRefresh || 0);
  const refresh = Number(owState?.values?.FullScreenRefresh || 0);
  const tips = [];
  if (!owState?.settingsExists) tips.push({ text: 'Overwatch has not saved a settings file on this PC yet. Start Overwatch, change any graphics setting, close the game, then come back.' });
  if (monitor && refresh && refresh < monitor) tips.push({ text: `Fullscreen refresh rate is ${refresh} Hz, but your monitor runs at ${monitor} Hz. In Fullscreen mode Overwatch would show at most ${refresh} frames a second.`, fix: () => { setOw('FullScreenRefresh', String(monitor)); setOw('WindowMode', '0'); }, fixLabel: `Use ${monitor} Hz fullscreen` });
  const cap = Number(owState?.values?.FrameRateCap || 0);
  const capInUse = owState?.values?.UseCustomFrameRates === '1' || owState?.values?.LimitToRefresh !== '1';
  if (cap && cap < 600 && capInUse) tips.push({ text: `The frame rate cap is ${cap} FPS. If your PC can run faster, this holds it back. 600 is the game's maximum.`, fix: () => setOw('FrameRateCap', '600'), fixLabel: 'Use 600 FPS' });
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
    else if (key === 'FrameRateCap' && value === 'refresh') values.LimitToRefresh = '1';
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
  fps: { WindowMode: '0', FrameRateCap: '600', CpuForceSyncEnabled: '1', TripleBufferingEnabled: '0', VerticalSyncEnabled: '0', ShowIntro: '0', TextureDetail: '1', ModelQuality: '1', LightQuality: '0', AADetail: '0', MaxAnisotropy: '1', DirectionalShadowDetail: '1', SimpleDirectionalShadows: '1', TranslucentShadowDetail: '0', SSAOEnabled: '0', LocalReflections: '0', SSLRDetailLevel: '0', RefractionDetail: '0', DynamicAmbient: '0', LocalFogDetail: '1' },
  balanced: { WindowMode: '0', CpuForceSyncEnabled: '1', TripleBufferingEnabled: '0', VerticalSyncEnabled: '0', ShowIntro: '0', TextureDetail: '3', ModelQuality: '2', LightQuality: '1', AADetail: '1', MaxAnisotropy: '8', SSAOEnabled: '0', LocalReflections: '0', RefractionDetail: '1', DynamicAmbient: '1', LocalFogDetail: '2' },
  quality: { WindowMode: '0', CpuForceSyncEnabled: '0', TripleBufferingEnabled: '0', VerticalSyncEnabled: '0', TextureDetail: '4', ModelQuality: '4', LightQuality: '3', AADetail: '3', MaxAnisotropy: '16', SimpleDirectionalShadows: '0', SSAOEnabled: '1', LocalReflections: '1', RefractionDetail: '1', DynamicAmbient: '1', LocalFogDetail: '3' }
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
      <article class="game-card ${game.tunable && GAMES[game.tunable] ? 'tunable' : ''}">
        <div class="game-art" aria-hidden="true">${escapeHtml(game.name.replace(/[®™]/g, '').split(/\s+/).map(word => word[0]).join('').slice(0, 3).toUpperCase())}</div>
        <div class="game-info"><h3>${escapeHtml(game.name.replace(/[®™]/g, ''))}</h3><p>${game.sizeGb ? `${game.sizeGb} GB on disk` : 'Installed'} · Steam</p>
          <span class="game-badge">${game.tunable && GAMES[game.tunable] ? 'Tunable in Riftline' : 'Launch only'}</span></div>
        <div class="game-actions">${game.tunable && GAMES[game.tunable] ? `<button class="button button-primary" data-tune-game="${escapeHtml(game.tunable)}">Tune settings</button>` : ''}<button class="button button-dark" data-launch-game="${escapeHtml(game.appid)}" data-game-name="${escapeHtml(game.name.replace(/[®™]/g, ''))}">Launch</button></div>
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
  if (target.closest('[data-ow-clear-cache]')) { clearOwCache(); return; }
  const tune = target.closest('[data-tune-game]');
  if (tune) { setGame(tune.dataset.tuneGame); return; }
  const launch = target.closest('[data-launch-game]');
  if (launch) {
    api('/api/launch-game', { appid: launch.dataset.launchGame }).then(() => showToast(`Starting ${launch.dataset.gameName}`, 'Steam is opening the game.')).catch(error => showToast('Could not start that game', error.message, 'error'));
  }
});
document.addEventListener('change', event => {
  if (event.target.matches?.('[data-ow-key]')) updateCount();
  if (event.target.id === 'owLock') {
    const locked = event.target.checked;
    api('/api/ow-lock', { locked }).then(state => { owState = state; fillOverwatch(); showToast(locked ? 'Overwatch settings locked' : 'Overwatch settings unlocked', locked ? 'Overwatch cannot overwrite them now. Riftline unlocks the file while applying.' : 'Overwatch can save in-game changes again.'); })
      .catch(error => { event.target.checked = !locked; showToast('Could not change the lock', error.message, 'error'); });
  }
});

async function clearOwCache() {
  const choice = await askUser({ title: 'Clear the Overwatch shader cache?', body: 'Overwatch rebuilds it the next time it starts, so the first match may stutter for a moment. Overwatch must be closed.', confirm: 'Clear cache' });
  if (choice !== 'confirm') return;
  try { const result = await api('/api/ow-clear-cache', {}); owState = result.state; fillOverwatch(); showToast('Shader cache cleared', result.message); }
  catch (error) { showToast('The cache was not cleared', error.message, 'error'); }
}
window.addEventListener('focus', () => { if (activeGame === 'overwatch' && !owBusy && Object.keys(owChanges()).length === 0) loadOverwatch(); });

setGame(GAMES[savedGame] ? savedGame : 'apex');
window.riftlineGames = { setGame, register, loadOverwatch, owChanges, get active() { return activeGame; } };
})();
