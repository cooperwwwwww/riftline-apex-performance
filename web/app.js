const token = document.querySelector('meta[name="riftline-token"]').content;
const $ = (selector, root = document) => root.querySelector(selector);
const $$ = (selector, root = document) => [...root.querySelectorAll(selector)];
let appState = null;
let customProfilesCache = [];
let nativeRequestId = 0;
const nativePending = new Map();
const hasNativeBridge = Boolean(window.chrome?.webview);

/* ---------- Change tracking ----------
   The baseline is a snapshot of every control as it reflects the files Apex is
   using right now. Pending changes are computed by comparing against it, so
   changing a value back removes it from Review automatically. */
const SKIP_TRACK = new Set(['settingsSearch','launchCommandSearch','commandImport','customProfileName','customProfiles','resolutionCatalog','reticleColor','configLock','reticleRed','reticleGreen','reticleBlue']);
const SEGMENTS = ['aspect','window','aa'];
const LABEL_OVERRIDES = {
  width: 'Output width', height: 'Output height', 'segment:aspect': 'Screen shape', 'segment:window': 'Window mode', 'segment:aa': 'Anti-aliasing',
  reticle: 'Reticle color', customReticle: 'Custom reticle color', adaptiveEnabled: 'Adaptive 3D resolution', adaptiveTarget: 'Adaptive target FPS',
  renderScale: 'Minimum render scale', extraCommands: 'Additional launch commands', execConfig: 'Custom CFG file', lodScale: 'Geometry LOD scale',
  refreshRate: 'Refresh rate', dx12: 'DirectX 12 renderer', rawInput: 'Raw mouse input', preload: 'Preload map assets',
  multicore: 'Multicore rendering', threads: 'Worker threads', softParticlesOff: 'Disable soft particles',
  noMotionBlur: 'Disable motion blur', noTracers: 'Hide your own tracers', noBloom: 'Disable bloom', softenedLocale: 'Reduced gore mode',
  showPos: 'Position and speed readout', minimizeAltTab: 'Minimize on Alt+Tab',
  fadeScale: 'Object fade distance', mapDetailLevel: 'Map detail level', decalLimit: 'Decal limit', particleFallback: 'Particle fallback', viewFov: 'Field of view'
};
const PAGE_NAMES = { overview: 'Overview', display: 'Display', visuals: 'Visuals', advanced: 'Advanced', launch: 'Launch', safety: 'Safety' };
let baseline = new Map();
let reviewScheduled = false;
let busy = false;

const previewCatalog = {
  textureBudget: {
    panel: 'visual', title: 'Texture streaming budget', description: 'Shows texture streaming detail at the selected Apex budget tier.',
    values: { 'None':'stream_memory_0.webp', 'Very Low':'stream_memory_160000.webp', 'Low':'stream_memory_160000.webp', 'Medium':'stream_memory_600000.webp', 'High':'stream_memory_1000000.webp', 'Very High':'stream_memory_2000000.webp', 'Insane':'stream_memory_3000000.webp' }
  },
  anisotropic: {
    panel: 'visual', title: 'Texture filtering', description: 'Higher anisotropic filtering keeps grates and ground textures sharper at steep angles.',
    values: { '1x':'mat_forceaniso_0.webp', '2x':'mat_forceaniso_2.webp', '4x':'mat_forceaniso_2.webp', '8x':'mat_forceaniso_8.webp', '16x':'mat_forceaniso_16.webp' }
  },
  aa: {
    panel: 'visual', title: 'Anti-aliasing', description: 'TSAA smooths stair-step edges; Off keeps the raw, sharper edge pattern.',
    values: { 'Off':'mat_antialias_mode_0.webp', 'TSAA':'mat_antialias_mode_12.webp' }
  },
  shadows: {
    panel: 'visual', title: 'Sun shadows', description: 'Directional world shadows add depth beneath trees, structures, and terrain.',
    values: { 'false':'csm_enabled_0.webp', 'true':'csm_enabled_1.webp' }
  },
  effects: {
    panel: 'visual', title: 'Fog and light effects', description: 'Volumetric lighting adds atmospheric haze and visible light bloom.',
    values: { 'false':'volumetric_lighting_0.webp', 'true':'volumetric_lighting_1.webp' }
  },
  ambientOcclusion: {
    panel: 'visual', title: 'Ambient occlusion', description: 'Ambient shading adds contact depth where rocks and surfaces meet.',
    values: { 'false':'ssao_quality_0.webp', 'true':'ssao_quality_4.webp' }
  },
  mapDecorations: {
    panel: 'visual', title: 'Map detail', description: 'Higher map detail adds small environmental rocks and set dressing.',
    values: { 'false':'map_detail_level_1.webp', 'true':'map_detail_level_2.webp' }
  },
  decals: {
    panel: 'visual', title: 'Impact marks', description: 'Model decals create visible bullet holes and impact marks on surfaces.',
    values: { 'false':'r_createmodeldecals_0.webp', 'true':'r_createmodeldecals_1.webp' }
  },
  csmResolution: {
    panel: 'advanced', title: 'Sun-shadow resolution', description: 'Higher cascade resolution produces cleaner, more defined sun shadows.',
    values: { '0':'csm_enabled_0.webp', '128':'csm_cascade_res_128.webp', '256':'csm_cascade_res_128.webp', '512':'csm_cascade_res_512.webp', '1024':'csm_cascade_res_1024.webp' }
  },
  shadowCoverage: {
    panel: 'advanced', title: 'Sun-shadow coverage', description: 'Wide coverage keeps cascaded shadows active across more of the scene.',
    values: { '1':'csm_coverage_1.webp', '2':'csm_coverage_2.webp' }
  },
  ssaoQuality: {
    panel: 'advanced', title: 'Ambient-occlusion quality', description: 'Quality 4 adds stronger contact shading than the disabled setting.',
    values: { '0':'ssao_quality_0.webp', '4':'ssao_quality_4.webp' }
  },
  lodScale: {
    panel: 'advanced', title: 'Geometry LOD scale', description: 'Higher values hold detailed rock geometry farther into the distance.',
    values: { 'Auto':'r_lod_switch_scale_0.6.webp', '0.25':'r_lod_switch_scale_0.6.webp', '0.35':'r_lod_switch_scale_0.6.webp', '0.50':'r_lod_switch_scale_0.6.webp', '0.60':'r_lod_switch_scale_0.6.webp', '0.70':'r_lod_switch_scale_0.8.webp', '0.80':'r_lod_switch_scale_0.8.webp', '1.00':'r_lod_switch_scale_1.0.webp', '1.50':'r_lod_switch_scale_1.5.webp', '2.00':'r_lod_switch_scale_2.0.webp' }
  },
  mapDetailLevel: {
    panel: 'advanced', title: 'Map detail level', description: 'Level 2 keeps additional small rocks and environmental dressing.',
    values: { '1':'map_detail_level_1.webp', '2':'map_detail_level_2.webp' }
  },
  decalLimit: {
    panel: 'advanced', title: 'Decal limit', description: 'Controls how many bullet-hole decals may remain visible at once.',
    values: { '64':'r_decals_64.webp', '128':'r_decals_128.webp', '256':'r_decals_256.webp' }
  }
};

/* ---------- Engine bridge ---------- */
if (hasNativeBridge) {
  window.chrome.webview.addEventListener('message', event => {
    const message = event.data || {};
    if (!message.id || !nativePending.has(message.id)) return;
    const pending = nativePending.get(message.id);
    nativePending.delete(message.id);
    if (message.ok === false) pending.reject(new Error(message.error || 'The native engine could not complete that action.'));
    else pending.resolve(message.data || { ok: true });
  });
}

async function api(path, body) {
  if (hasNativeBridge) {
    if (path === '/api/ping') return { ok: true };
    if (path === '/api/shutdown') {
      window.chrome.webview.postMessage({ kind: 'window', action: 'close' });
      return { ok: true };
    }
    const id = `r${Date.now()}-${++nativeRequestId}`;
    return new Promise((resolve, reject) => {
      nativePending.set(id, { resolve, reject });
      window.chrome.webview.postMessage({ kind: 'api', id, path, body: body || {} });
    });
  }
  const options = { headers: { 'X-Riftline-Token': token } };
  if (body !== undefined) {
    options.method = 'POST';
    options.headers['Content-Type'] = 'application/json';
    options.body = JSON.stringify(body);
  }
  let response;
  try { response = await fetch(path, options); }
  catch {
    // A sleeping window (e.g. while Apex was open) can drop one request; try once more before giving up.
    await new Promise(resolve => setTimeout(resolve, 600));
    try { response = await fetch(path, options); }
    catch { throw new Error('The Riftline engine stopped running. Close this window and open Riftline again.'); }
  }
  const data = await response.json().catch(() => ({}));
  if (!response.ok || data.ok === false) throw new Error(data.error || `Request failed (${response.status})`);
  return data;
}

const ACTION_SELECTOR = '[data-apply],[data-launch],[data-profile],[data-custom-save],[data-custom-apply],[data-custom-delete],[data-action],[data-save-command],[data-discard-all]';

async function withBusy(label, task) {
  if (busy) { showToast('Riftline is still working', 'Wait for the current action to finish.', 'error'); return undefined; }
  busy = true;
  document.body.classList.add('is-busy');
  $('#busyLabel').textContent = label;
  $$(ACTION_SELECTOR).forEach(button => { button.disabled = true; });
  try { return await task(); }
  finally {
    busy = false;
    document.body.classList.remove('is-busy');
    $$(ACTION_SELECTOR).forEach(button => { button.disabled = false; });
  }
}

/* ---------- Feedback ---------- */
function showToast(title, message = '', type = 'success') {
  const toast = document.createElement('div');
  toast.className = `toast ${type}`;
  toast.setAttribute('role', type === 'error' ? 'alert' : 'status');
  toast.innerHTML = `<strong>${escapeHtml(title)}</strong>${message ? `<span>${escapeHtml(message)}</span>` : ''}`;
  $('#toastStack').append(toast);
  setTimeout(() => toast.remove(), type === 'error' ? 6500 : 4200);
}

function escapeHtml(value) {
  return String(value ?? '').replace(/[&<>'"]/g, char => ({ '&':'&amp;', '<':'&lt;', '>':'&gt;', "'":'&#39;', '"':'&quot;' }[char]));
}

/* In-app dialog that replaces window.confirm. Resolves 'confirm', 'alt', or null. */
function askUser({ title, body = '', confirm = 'Continue', alt = '', cancel = 'Cancel', tone = 'primary' }) {
  return new Promise(resolve => {
    const root = $('#modalRoot');
    const previousFocus = document.activeElement;
    root.innerHTML = `<div class="modal-scrim" data-modal-cancel></div>
      <div class="modal-card" role="dialog" aria-modal="true" aria-labelledby="modalTitle">
        <h2 id="modalTitle">${escapeHtml(title)}</h2>
        ${body ? `<p>${escapeHtml(body)}</p>` : ''}
        <div class="modal-actions">
          <button class="button button-dark" data-modal-cancel>${escapeHtml(cancel)}</button>
          ${alt ? `<button class="button button-dark" data-modal-alt>${escapeHtml(alt)}</button>` : ''}
          <button class="button ${tone === 'danger' ? 'button-danger' : 'button-primary'}" data-modal-confirm>${escapeHtml(confirm)}</button>
        </div>
      </div>`;
    root.classList.add('open');
    const finish = value => {
      root.classList.remove('open');
      root.innerHTML = '';
      document.removeEventListener('keydown', onKey, true);
      previousFocus?.focus?.();
      resolve(value);
    };
    const onKey = event => {
      if (event.key === 'Escape') { event.preventDefault(); event.stopPropagation(); finish(null); }
      if (event.key === 'Tab') {
        const focusable = $$('button', root);
        const index = focusable.indexOf(document.activeElement);
        if (event.shiftKey && index <= 0) { event.preventDefault(); focusable.at(-1).focus(); }
        else if (!event.shiftKey && index === focusable.length - 1) { event.preventDefault(); focusable[0].focus(); }
      }
    };
    document.addEventListener('keydown', onKey, true);
    $$('[data-modal-cancel]', root).forEach(node => node.addEventListener('click', () => finish(null)));
    $('[data-modal-alt]', root)?.addEventListener('click', () => finish('alt'));
    $('[data-modal-confirm]', root).addEventListener('click', () => finish('confirm'));
    $('[data-modal-confirm]', root).focus();
  });
}

/* ---------- Controls ---------- */
function openPage(name) {
  $$('.page').forEach(page => page.classList.toggle('active', page.dataset.pagePanel === name));
  $$('.nav-item').forEach(item => item.classList.toggle('active', item.dataset.page === name));
  $('.workspace').scrollTo({ top: 0, behavior: 'smooth' });
}

function selected(segment) {
  return $(`[data-segment="${segment}"] .active`)?.dataset.value;
}

function setSegment(segment, value) {
  const root = $(`[data-segment="${segment}"]`);
  if (!root) return;
  $$('button', root).forEach(button => button.classList.toggle('active', button.dataset.value === String(value)));
  scheduleReview();
}

function setControl(id, value) {
  const control = document.getElementById(id);
  if (!control || value === undefined || value === null) return;
  if (control.type === 'checkbox') { control.checked = Boolean(value); return; }
  const text = String(value);
  if (control.tagName === 'SELECT' && ![...control.options].some(option => option.value === text)) {
    // Keep unusual values that are already in the user's files visible instead of silently replacing them.
    const option = document.createElement('option');
    option.value = text;
    option.textContent = `${text} (current)`;
    control.append(option);
  }
  control.value = text;
}

function getBool(id) { return Boolean(document.getElementById(id)?.checked); }
function getValue(id) { return document.getElementById(id)?.value ?? ''; }

function trackedControls() {
  return $$('.workspace input[id], .workspace select[id], .workspace textarea[id]').filter(control => !SKIP_TRACK.has(control.id));
}

function snapshot() {
  const map = new Map();
  trackedControls().forEach(control => map.set(control.id, control.type === 'checkbox' ? control.checked : control.value));
  SEGMENTS.forEach(segment => map.set(`segment:${segment}`, selected(segment) || ''));
  map.set('reticle', [getValue('reticleRed'), getValue('reticleGreen'), getValue('reticleBlue')].map(clampRgb).join(', '));
  return map;
}

function elementForKey(key) {
  if (key.startsWith('segment:')) return $(`[data-segment="${key.slice(8)}"]`);
  if (key === 'reticle') return $('#reticleRed');
  return document.getElementById(key);
}

function titleOf(element) {
  const node = ['h3', 'h2', 'strong', 'span'].map(selector => element?.querySelector(selector)).find(Boolean);
  return node?.textContent.trim() || '';
}

function labelFor(key) {
  if (LABEL_OVERRIDES[key]) return LABEL_OVERRIDES[key];
  const element = elementForKey(key);
  const card = element?.closest('.control-row, .control-grid > label, .setting-card');
  return titleOf(card) || key.replace(/([A-Z])/g, ' $1').replace(/^./, char => char.toUpperCase());
}

function displayValue(key, value) {
  if (typeof value === 'boolean') return value ? 'On' : 'Off';
  if (key.startsWith('segment:')) return $(`[data-segment="${key.slice(8)}"] [data-value="${CSS.escape(String(value))}"]`)?.textContent.trim() || String(value || '—');
  const element = document.getElementById(key);
  if (element?.tagName === 'SELECT') return [...element.options].find(option => option.value === String(value))?.textContent.trim() || String(value);
  return String(value).trim() === '' ? '—' : String(value);
}

function pendingChanges() {
  const now = snapshot();
  return [...now].filter(([key, value]) => baseline.has(key) && baseline.get(key) !== value)
    .map(([key, value]) => ({ key, from: baseline.get(key), to: value, page: elementForKey(key)?.closest('.page')?.dataset.pagePanel || '' }));
}

function resetBaseline() {
  baseline = snapshot();
  renderReview();
}

function revertKey(key) {
  if (!baseline.has(key)) return;
  const value = baseline.get(key);
  if (key.startsWith('segment:')) setSegment(key.slice(8), value);
  else if (key === 'reticle') {
    const [red, green, blue] = String(value).split(',').map(part => part.trim());
    setControl('reticleRed', red); setControl('reticleGreen', green); setControl('reticleBlue', blue);
  } else setControl(key, value);
  syncReticleFromRgb();
  updateDisplayPreview();
  renderReview();
}

function scheduleReview() {
  if (reviewScheduled) return;
  reviewScheduled = true;
  requestAnimationFrame(() => { reviewScheduled = false; renderReview(); });
}

function renderReview() {
  const changes = pendingChanges();
  $('#reviewCount').textContent = changes.length;
  $('.review-button')?.classList.toggle('has-changes', changes.length > 0);
  const perPage = {};
  changes.forEach(change => { perPage[change.page] = (perPage[change.page] || 0) + 1; });
  $$('.nav-item').forEach(item => {
    let badge = $('.nav-dirty', item);
    const count = perPage[item.dataset.page] || 0;
    if (!badge && count) { badge = document.createElement('b'); badge.className = 'nav-dirty'; item.append(badge); }
    if (badge) { badge.textContent = count; badge.hidden = !count; }
  });
  const summary = $('#reviewSummary');
  if (summary) summary.textContent = changes.length ? `${changes.length} unapplied ${changes.length === 1 ? 'change' : 'changes'} compared with what Apex is using now.` : 'Compared with what Apex is using right now.';
  const list = $('#reviewList');
  if (!changes.length) {
    list.innerHTML = '<div class="empty-review"><strong>No pending changes</strong><span>Everything matches your current Apex files. Adjust any setting and it will appear here.</span></div>';
    return;
  }
  list.innerHTML = changes.map(change => `
    <div class="review-item" data-review-key="${escapeHtml(change.key)}">
      <button class="review-jump" data-review-jump="${escapeHtml(change.key)}" title="Show this setting">
        <span>${escapeHtml(labelFor(change.key))}<em>${escapeHtml(PAGE_NAMES[change.page] || '')}</em></span>
        <strong><s>${escapeHtml(displayValue(change.key, change.from))}</s><i aria-hidden="true">→</i>${escapeHtml(displayValue(change.key, change.to))}</strong>
      </button>
      <button class="review-revert" data-review-revert="${escapeHtml(change.key)}" title="Undo this change" aria-label="Undo ${escapeHtml(labelFor(change.key))}">↺</button>
    </div>`).join('');
}

function goToElement(element) {
  if (!element) return;
  const page = element.closest('.page');
  if (page) openPage(page.dataset.pagePanel);
  const card = element.closest('.control-row, .control-grid > label, .setting-card, .safety-action, .path-card, .profile-card, .reticle-designer') || element;
  setTimeout(() => {
    card.scrollIntoView({ behavior: 'smooth', block: 'center' });
    card.classList.remove('search-flash');
    void card.offsetWidth;
    card.classList.add('search-flash');
    setTimeout(() => card.classList.remove('search-flash'), 1700);
    const focusTarget = card.matches('input,select,textarea,button') ? card : $('select, input:not([type=checkbox]), textarea, button', card);
    focusTarget?.focus({ preventScroll: true });
  }, 90);
}

/* ---------- Hydration from the engine ---------- */
const CURRENT_CONTROL_MAP = {
  width:'width', height:'height', textureBudget:'textureBudget', textureQuality:'textureQuality', anisotropic:'anisotropic', modelDetail:'modelDetail',
  particleDetail:'particleDetail', shadows:'shadows', effects:'effects', ambientOcclusion:'ambientOcclusion', mapDecorations:'mapDecorations', decals:'decals',
  ragdolls:'ragdolls', vsync:'vsync', lowLatency:'lowLatency', gibs:'gibs', ragdollCollision:'ragdollCollision', linearMipFiltering:'linearMip',
  dynamicTextureBudget:'dynamicBudget', backbufferCount:'backbuffers', shadowDepthMin:'shadowDepth', shadowUpresFactor:'shadowUpres',
  maxDynamicShadows:'dynamicShadows', csmResolution:'csmResolution', shadowCoverage:'shadowCoverage', ssaoQuality:'ssaoQuality', ssaoDownsample:'ssaoDownsample',
  lodScale:'lodScale', fadeDistanceScale:'fadeScale', mapDetailLevel:'mapDetailLevel', decalLimit:'decalLimit', particleFallback:'particleFallback', viewFov:'viewFov'
};

function hydrateCurrent(current) {
  if (!current) return;
  Object.entries(CURRENT_CONTROL_MAP).forEach(([key, id]) => { if (current[key] !== undefined && current[key] !== null) setControl(id, current[key]); });
  if (current.windowMode) setSegment('window', current.windowMode);
  if (current.antiAliasing) setSegment('aa', current.antiAliasing);
  const target = Number(current.adaptiveTarget || 0);
  setControl('adaptiveEnabled', target > 0);
  if (target > 0) setControl('adaptiveTarget', target);
}

function hydrateLaunchOptions(launchOptions = '') {
  const text = String(launchOptions || '');
  let remaining = ` ${text} `;
  const take = (pattern, callback) => { remaining = remaining.replace(pattern, (...args) => { callback?.(...args); return ' '; }); };
  setControl('skipIntro', false); setControl('noJoy', false); setControl('forceNoVsync', false);
  setControl('highPriority', false); setControl('developerMode', false);
  setControl('refreshRate', ''); setControl('dx12', false); setControl('rawInput', false); setControl('preload', false);
  setControl('multicore', false); setControl('threads', ''); setControl('softParticlesOff', false);
  Object.keys(TOGGLE_COMMANDS).forEach(id => setControl(id, false));
  setControl('fpsCap', ''); setControl('fpsCounter', 'Off'); setControl('lobbyFps', 'Keep current'); setControl('execConfig', ''); setControl('language', 'System default');
  take(/\s+\+fps_max\s+(\d+)/ig, (_all, value) => setControl('fpsCap', value));
  take(/\s+-novid\b/ig, () => setControl('skipIntro', true));
  take(/\s+\+lobby_max_fps\s+(\d+)/ig, (_all, value) => setControl('lobbyFps', value));
  take(/\s+\+cl_showfps\s+(\d+)/ig, (_all, value) => setControl('fpsCounter', value === '4' ? 'Detailed' : 'Basic'));
  take(/\s+-nojoy\b/ig, () => setControl('noJoy', true));
  take(/\s+-forcenovsync\b/ig, () => setControl('forceNoVsync', true));
  take(/\s+-high\b/ig, () => setControl('highPriority', true));
  take(/\s+-dev\b/ig, () => setControl('developerMode', true));
  take(/\s+-(?:refresh|freq)\s+(\d+)/ig, (_all, value) => setControl('refreshRate', value));
  take(/\s+-eac_launcher_settings\s+SettingsDX12\.json(?=\s)/ig, () => setControl('dx12', true));
  take(/\s+\+m_rawinput\s+1\b/ig, () => setControl('rawInput', true));
  // Preload is one card for both commands; either one alone still reads back as on.
  take(/\s+-preload\b/ig, () => setControl('preload', true));
  take(/\s+\+cl_forcepreload\s+1\b/ig, () => setControl('preload', true));
  take(/\s+\+mat_queue_mode\s+2\b/ig, () => setControl('multicore', true));
  take(/\s+-threads\s+(\d+)/ig, (_all, value) => setControl('threads', value));
  take(/\s+-softparticlesdefaultoff\b/ig, () => setControl('softParticlesOff', true));
  Object.entries(TOGGLE_COMMANDS).forEach(([id, command]) => {
    const [name, value] = command.split(' ');
    take(new RegExp(`\\s+\\${name}\\s+${value}(?=\\s)`, 'ig'), () => setControl(id, true));
  });
  take(/\s+\+exec\s+([A-Za-z0-9_.-]+)/ig, (_all, value) => setControl('execConfig', value));
  take(/\s+-(?:language)\s+([A-Za-z_]+)/ig, (_all, value) => setControl('language', value.toLowerCase()));
  take(/\s+\+miles_language\s+([A-Za-z_]+)/ig, (_all, value) => setControl('language', value.toLowerCase()));
  take(/\s+\+dvs_scale_min\s+([\d.]+)/ig, (_all, value) => {
    const percent = `${Math.round(Number(value) * 100)}%`;
    if ([...$('#renderScale').options].some(option => option.value === percent)) setControl('renderScale', percent);
  });
  const stretched = /\+mat_letterbox_aspect_(?:goal|threshold)\b/i.test(text);
  take(/\s+\+mat_letterbox_aspect_(?:min|goal|threshold|max)\s+[^\s]+/ig);
  take(/\s+\+building_cubemaps\s+(?:"[^"]*"|[^\s]+)/ig);
  take(/\s+-(?:w|h)\s+\d+/ig);
  take(/\s+-multiple\b/ig);
  setSegment('aspect', stretched ? 'stretched' : 'default');
  if (/\s-fullscreen\b/i.test(` ${text}`)) setSegment('window', 'Fullscreen');
  else if (/\s-windowed\b/i.test(` ${text}`) && /\s-noborder\b/i.test(` ${text}`)) setSegment('window', 'Borderless');
  else if (/\s-windowed\b/i.test(` ${text}`)) setSegment('window', 'Windowed');
  take(/\s+-(?:fullscreen|windowed|noborder)\b/ig);
  setControl('extraCommands', remaining.replace(/\s+/g, ' ').trim());
}

function hydrateReticle(reticleColor) {
  const rgb = String(reticleColor || '').match(/(\d{1,3})\s+(\d{1,3})\s+(\d{1,3})/);
  setControl('customReticle', Boolean(rgb));
  if (rgb) { setControl('reticleRed', rgb[1]); setControl('reticleGreen', rgb[2]); setControl('reticleBlue', rgb[3]); }
  syncReticleFromRgb();
}

/* Applies a fresh read of the user's files (returned after every write) and makes it the new baseline. */
function applyLiveState(live) {
  if (!live) return;
  appState = { ...(appState || {}), ...live };
  hydrateCurrent(live.current);
  hydrateLaunchOptions(live.launchOptions || '');
  hydrateReticle(live.reticleColor);
  if (live.customProfiles) refreshCustomProfiles(live.customProfiles);
  if (live.activeProfile) setActiveProfileUI(live.activeProfile);
  setControl('configLock', live.configLocked);
  setConnection(live);
  updateDisplayPreview();
  updateSettingPreview('textureBudget', getValue('textureBudget'));
  updateSettingPreview('csmResolution', getValue('csmResolution'));
  resetBaseline();
}

function setConnection(state) {
  const connection = $('.connection');
  connection.classList.toggle('offline', !state.configExists);
  connection.classList.toggle('warning', Boolean(state.configExists && state.apexRunning));
  $('#connectionText').textContent = !state.configExists ? 'Apex config not found' : state.apexRunning ? 'Apex is running — close it to apply' : 'Apex config connected';
}

function refreshCustomProfiles(profiles = []) {
  customProfilesCache = Array.isArray(profiles) ? profiles : [];
  const select = $('#customProfiles');
  if (!select) return;
  const previous = select.value;
  const names = customProfilesCache.map(profile => profile.Name ?? profile.name).filter(Boolean);
  select.innerHTML = names.length
    ? names.map(name => `<option value="${escapeHtml(name)}">${escapeHtml(name)}</option>`).join('')
    : '<option value="">No saved profiles</option>';
  if (names.includes(previous)) select.value = previous;
}

function setActiveProfileUI(active = { type: '', name: '' }) {
  const normalized = { type: active?.type || '', name: active?.name || '' };
  if (appState) appState.activeProfile = normalized;
  $$('[data-profile]').forEach(button => button.classList.toggle('profile-active', normalized.type === 'built-in' && button.dataset.profile === normalized.name));
  const customSelect = $('#customProfiles');
  if (customSelect) {
    customSelect.classList.toggle('profile-active', normalized.type === 'custom');
    if (normalized.type === 'custom' && [...customSelect.options].some(option => option.value === normalized.name)) customSelect.value = normalized.name;
  }
  const badge = $('#activeProfileBadge');
  if (badge) {
    badge.textContent = normalized.name ? `ACTIVE · ${normalized.name}` : 'NO ACTIVE PROFILE';
    badge.classList.toggle('has-active-profile', Boolean(normalized.name));
  }
}

/* ---------- Previews ---------- */
function updateSettingPreview(controlId, rawValue) {
  const entry = previewCatalog[controlId];
  if (!entry) return;
  const value = String(rawValue);
  const filename = entry.values[value];
  if (!filename) return;
  const prefix = entry.panel === 'visual' ? 'visual' : 'advanced';
  const image = $(`#${prefix}PreviewImage`);
  if (!image) return;
  image.src = `../assets/previews/${filename}`;
  image.alt = `Real Apex Legends comparison for ${entry.title}: ${value}`;
  $(`#${prefix}PreviewTitle`).textContent = entry.title;
  $(`#${prefix}PreviewDescription`).textContent = entry.description;
  $(`#${prefix}PreviewValue`).textContent = value === 'true' ? 'On' : value === 'false' ? 'Off' : value;
  $(`#${prefix}PreviewFile`).textContent = filename.replace(/\.webp$/i, '');
  const panel = $(`#${prefix}Preview`);
  const page = panel?.closest('.page');
  if (page) $$('.preview-active', page).forEach(node => node.classList.remove('preview-active'));
  const control = controlId === 'aa' ? $('[data-segment="aa"]') : document.getElementById(controlId);
  const card = control?.closest('.setting-card, .control-row, .control-grid > label');
  card?.classList.add('preview-active');
}

function configureAspectStage(stage, sourceAspect, nativeAspect, mode) {
  if (!stage) return;
  const content = $('.aspect-content', stage);
  const circle = $('.geometry-circle', stage);
  if (!content || !circle) return;
  if (mode === 'stretch') {
    content.style.width = '100%';
    content.style.height = '100%';
    circle.style.transform = `translate(-50%, -50%) scaleX(${Math.max(.38, Math.min(2.25, nativeAspect / sourceAspect)).toFixed(3)})`;
  } else {
    if (sourceAspect <= nativeAspect) {
      content.style.width = `${(sourceAspect / nativeAspect * 100).toFixed(3)}%`;
      content.style.height = '100%';
    } else {
      content.style.width = '100%';
      content.style.height = `${(nativeAspect / sourceAspect * 100).toFixed(3)}%`;
    }
    circle.style.transform = 'translate(-50%, -50%) scaleX(1)';
  }
}

function clampRgb(value) { return Math.max(0, Math.min(255, Number.parseInt(value, 10) || 0)); }

function syncReticleFromRgb() {
  const red = clampRgb(getValue('reticleRed'));
  const green = clampRgb(getValue('reticleGreen'));
  const blue = clampRgb(getValue('reticleBlue'));
  setControl('reticleRed', red); setControl('reticleGreen', green); setControl('reticleBlue', blue);
  const hex = `#${[red,green,blue].map(value => value.toString(16).padStart(2,'0')).join('')}`;
  setControl('reticleColor', hex);
  $('#reticlePreview')?.style.setProperty('--reticle', hex);
  $('.reticle-designer')?.classList.toggle('reticle-disabled', !getBool('customReticle'));
  scheduleReview();
}

function syncReticleFromHex(hex) {
  const match = String(hex).match(/^#([0-9a-f]{6})$/i);
  if (!match) return;
  const value = match[1];
  setControl('reticleRed', parseInt(value.slice(0,2),16));
  setControl('reticleGreen', parseInt(value.slice(2,4),16));
  setControl('reticleBlue', parseInt(value.slice(4,6),16));
  syncReticleFromRgb();
}

/* ---------- Resolution validation ---------- */
const RESOLUTION_LIMITS = { width: [640, 7680], height: [360, 4320] };

function resolutionValid() {
  return Object.entries(RESOLUTION_LIMITS).every(([id, [min, max]]) => {
    const value = Number(getValue(id));
    return Number.isInteger(value) && value >= min && value <= max;
  });
}

function markResolutionValidity() {
  Object.entries(RESOLUTION_LIMITS).forEach(([id, [min, max]]) => {
    const control = document.getElementById(id);
    const value = Number(control.value);
    const ok = Number.isInteger(value) && value >= min && value <= max;
    control.classList.toggle('invalid', !ok);
    control.setCustomValidity(ok ? '' : `Use a whole number from ${min} to ${max}.`);
    control.title = ok ? '' : `Use a whole number from ${min} to ${max}.`;
  });
}

function clampResolutionField(id) {
  const [min, max] = RESOLUTION_LIMITS[id];
  const control = document.getElementById(id);
  const raw = Number(control.value);
  if (!Number.isFinite(raw) || control.value.trim() === '') { control.value = baseline.get(id) ?? min; }
  else {
    const clamped = Math.max(min, Math.min(max, Math.round(raw)));
    if (clamped !== raw) showToast('Resolution adjusted', `${id === 'width' ? 'Width' : 'Height'} must be ${min}–${max}, so ${raw} became ${clamped}.`, 'error');
    control.value = clamped;
  }
}

/* ---------- Command + display ---------- */
/* Simple on/off console commands: card id -> exact command it adds. */
const TOGGLE_COMMANDS = {
  noMotionBlur: '+cl_motionblur 0',
  noTracers: '+r_drawtracers_firstperson 0',
  noBloom: '+mat_disable_bloom 1',
  softenedLocale: '+cl_is_softened_locale 1',
  showPos: '+cl_showpos 1',
  minimizeAltTab: '+mat_minimize_on_alt_tab 1'
};

const COMMAND_PRESETS = {
  competitive: { fpsCap: '0', lobbyFps: '60', skipIntro: true, forceNoVsync: true, rawInput: true, preload: true, softParticlesOff: false, highPriority: false, multicore: false, threads: '',
    noMotionBlur: true, noTracers: true, noBloom: false, minimizeAltTab: true },
  lowend: { fpsCap: '144', lobbyFps: '30', skipIntro: true, forceNoVsync: true, rawInput: true, preload: true, softParticlesOff: true, highPriority: false, multicore: true, threads: '',
    noMotionBlur: true, noTracers: true, noBloom: true, minimizeAltTab: true },
  streamer: { fpsCap: '144', lobbyFps: '60', skipIntro: true, forceNoVsync: false, rawInput: true, preload: true, softParticlesOff: false, highPriority: false, multicore: false, threads: '',
    noMotionBlur: true, noTracers: false, noBloom: false, minimizeAltTab: false },
  clear: { fpsCap: '', lobbyFps: 'Keep current', fpsCounter: 'Off', skipIntro: false, noJoy: false, forceNoVsync: false, highPriority: false, developerMode: false,
    refreshRate: '', dx12: false, rawInput: false, preload: false, multicore: false, threads: '', softParticlesOff: false, execConfig: '', language: 'System default', extraCommands: '',
    noMotionBlur: false, noTracers: false, noBloom: false, softenedLocale: false, showPos: false, minimizeAltTab: false }
};

function applyCommandPreset(name) {
  const preset = COMMAND_PRESETS[name];
  if (!preset) return;
  Object.entries(preset).forEach(([id, value]) => setControl(id, value));
  if (name !== 'clear' && appState?.native?.refresh) {
    setControl('refreshRate', String(appState.native.refresh));
  }
  updateDisplayPreview();
  scheduleReview();
  showToast(name === 'clear' ? 'Launch commands cleared' : 'Quick set loaded', 'Review the changes, then apply or save them.');
}

/* Reads a pasted launch line into the cards. The current line goes first, so pasted values win;
   window and screen-shape commands already chosen on Display are kept unless the paste sets them. */
function importCommandLine() {
  const input = $('#commandImport');
  const pasted = input.value.replace(/[\r\n\0]+/g, ' ').trim();
  if (!pasted) { input.focus(); return; }
  const before = buildCommand();
  hydrateLaunchOptions(`${before} ${pasted}`);
  // Leave unknown leftovers in Additional commands without repeating them.
  setControl('extraCommands', [...new Set(getValue('extraCommands').split(/\s+(?=[-+])/))].join(' '));
  input.value = '';
  updateDisplayPreview();
  scheduleReview();
  showToast('Launch line imported', before === buildCommand() ? 'Those commands were already set.' : 'Review the changes, then apply or save them.');
}

function buildCommand() {
  const parts = [];
  if (getValue('fpsCap') !== '') parts.push(`+fps_max ${getValue('fpsCap')}`);
  if (getBool('skipIntro')) parts.push('-novid');
  if (getValue('lobbyFps') && getValue('lobbyFps') !== 'Keep current') parts.push(`+lobby_max_fps ${getValue('lobbyFps')}`);
  if (getValue('fpsCounter') === 'Basic') parts.push('+cl_showfps 1');
  if (getValue('fpsCounter') === 'Detailed') parts.push('+cl_showfps 4');
  if (getBool('noJoy')) parts.push('-nojoy');
  if (getBool('forceNoVsync')) parts.push('-forcenovsync');
  if (getBool('highPriority')) parts.push('-high');
  if (getBool('developerMode')) parts.push('-dev');
  if (getValue('refreshRate')) parts.push(`-refresh ${getValue('refreshRate')}`);
  if (getBool('dx12')) parts.push('-eac_launcher_settings SettingsDX12.json');
  if (getBool('rawInput')) parts.push('+m_rawinput 1');
  if (getBool('preload')) parts.push('-preload +cl_forcepreload 1');
  if (getBool('multicore')) parts.push('+mat_queue_mode 2');
  if (getValue('threads')) parts.push(`-threads ${getValue('threads')}`);
  if (getBool('softParticlesOff')) parts.push('-softparticlesdefaultoff');
  Object.entries(TOGGLE_COMMANDS).forEach(([id, command]) => { if (getBool(id)) parts.push(command); });
  const execConfig = getValue('execConfig').trim();
  if (execConfig && /^[A-Za-z0-9_.-]+$/.test(execConfig)) parts.push(`+exec ${execConfig}`);
  if (getValue('language') && getValue('language') !== 'System default') parts.push(`-language ${getValue('language')}`);
  if (selected('aspect') === 'stretched' && resolutionValid()) {
    parts.push(`+mat_letterbox_aspect_goal 0 +mat_letterbox_aspect_threshold 0 +building_cubemaps "1" -w ${getValue('width')} -h ${getValue('height')} -fullscreen -multiple`);
  } else if (selected('window') === 'Fullscreen') {
    parts.push('-fullscreen');
  } else if (selected('window') === 'Borderless') {
    parts.push('-windowed -noborder');
  } else if (selected('window') === 'Windowed') {
    parts.push('-windowed');
  }
  if (getBool('adaptiveEnabled')) parts.push(`+dvs_scale_min ${(parseInt(getValue('renderScale'), 10) / 100).toFixed(2)}`);
  const extra = getValue('extraCommands').replace(/[\r\n\0]+/g, ' ').trim();
  // Flag commands typed into Additional commands that a card above already sets;
  // Apex uses whichever comes last, which is easy to miss.
  const generated = new Set(parts.join(' ').split(/\s+/).filter(token => /^[-+][A-Za-z_]/.test(token)).map(token => token.toLowerCase()));
  const duplicates = [...new Set(extra.split(/\s+/).filter(token => generated.has(token.toLowerCase())))];
  const warning = $('#commandWarning');
  if (warning) {
    warning.hidden = !duplicates.length;
    warning.textContent = duplicates.length ? `Also set in Additional commands: ${duplicates.join(', ')}. The later value wins — remove it from one place.` : '';
  }
  if (extra) parts.push(extra);
  const command = parts.join(' ');
  const preview = $('#commandPreview');
  preview.textContent = command || 'No launch commands — Apex starts with its own defaults.';
  preview.classList.toggle('empty', !command);
  const length = $('#commandLength');
  if (length) { length.textContent = `${command.length} / 1024`; length.classList.toggle('over', command.length > 1024); }
  return command;
}

function updateDisplayPreview() {
  markResolutionValidity();
  const aspectMode = selected('aspect') || 'default';
  const stretched = aspectMode === 'stretched';
  if (stretched && selected('window') !== 'Fullscreen') setSegment('window', 'Fullscreen');
  $('[data-segment="window"]')?.classList.toggle('locked', stretched);
  $$('[data-segment="window"] button').forEach(button => { button.disabled = stretched && button.dataset.value !== 'Fullscreen'; });
  const windowNote = $('#windowNote');
  if (windowNote) windowNote.hidden = !stretched;
  $('#aspectNoticeTitle').textContent = stretched ? 'No black bars' : 'Black bars';
  $('#aspectNoticeText').textContent = stretched
    ? 'Fills the screen in exclusive fullscreen by stretching the image. Riftline changes Apex only—not Windows, your monitor, or GPU settings.'
    : 'Keeps the original shape of a non-native resolution. Riftline changes Apex only—not Windows, your monitor, or GPU settings.';

  const width = Math.max(1, Number(getValue('width')) || 1);
  const height = Math.max(1, Number(getValue('height')) || 1);
  const nativeWidth = appState?.native?.width || width;
  const nativeHeight = appState?.native?.height || height;
  const sourceAspect = width / height;
  const nativeAspect = nativeWidth / nativeHeight;
  const load = Math.round((width * height) / (nativeWidth * nativeHeight) * 100);
  const gcd = (a,b) => b ? gcd(b,a%b) : a;
  const divisor = gcd(width, height);
  const ratio = `${Math.round(width/divisor)}:${Math.round(height/divisor)}`;
  $('#pixelLoad').textContent = `${load}%`;
  $('#detailPixelLoad').textContent = `${load}%`;
  $('#resolutionPill').textContent = `${width} × ${height}`;
  $('#currentTarget').textContent = `${width} × ${height}`;
  const meter = $('#targetMeter');
  if (meter) meter.style.width = `${Math.max(4, Math.min(100, load))}%`;
  const fps = getValue('fpsCap');
  const summary = $('#targetSummary');
  if (summary) summary.textContent = `${load}% of native pixels · ${selected('window') || 'Fullscreen'}${stretched ? ' · no black bars' : ''} · ${fps === '' ? 'game-default FPS cap' : fps === '0' ? 'uncapped FPS' : `${fps} FPS cap`}`;
  $('#aspectLabel').textContent = ratio.length > 8 ? `${(width/height).toFixed(2)}:1` : ratio;
  $('#detailWindow').textContent = selected('window') || 'Fullscreen';
  $('#detailScale').textContent = getBool('adaptiveEnabled') ? getValue('renderScale') : 'Off';
  if ($('#barsLabel')) $('#barsLabel').textContent = stretched ? 'NO BLACK BARS' : 'BLACK BARS';
  configureAspectStage($('#mainAspectStage'), sourceAspect, nativeAspect, stretched ? 'stretch' : 'contain');
  configureAspectStage($('#barsCompareStage'), sourceAspect, nativeAspect, 'contain');
  configureAspectStage($('#stretchCompareStage'), sourceAspect, nativeAspect, 'stretch');
  const geometryChanged = Math.abs(sourceAspect - nativeAspect) > .015;
  const nativeDivisor = gcd(nativeWidth, nativeHeight);
  $('#displayTitle').textContent = geometryChanged ? `${ratio} on ${Math.round(nativeWidth / nativeDivisor)}:${Math.round(nativeHeight / nativeDivisor)}` : (load >= 95 ? 'Native geometry' : `${load}% pixel load`);
  $('#displayDescription').textContent = geometryChanged
    ? (stretched ? 'No-black-bars mode fills the display. The white circle becomes an ellipse to show the exact horizontal geometry change.' : 'Black bars preserve the source geometry. Compare it with the stretched preview to see how no-black-bars mode changes shape.')
    : 'The selected output matches the display shape, so the circle remains circular with or without black bars.';
  buildCommand();
  scheduleReview();
}

function collectSettings() {
  const stretched = selected('aspect') === 'stretched';
  return {
    width: Number(getValue('width')), height: Number(getValue('height')),
    windowMode: stretched ? 'Fullscreen' : (selected('window') || 'Fullscreen'), aspectMode: selected('aspect') || 'default',
    textureBudget: getValue('textureBudget'), textureQuality: getValue('textureQuality'),
    anisotropic: getValue('anisotropic'), antiAliasing: selected('aa') || 'Off',
    modelDetail: getValue('modelDetail'), particleDetail: getValue('particleDetail'),
    shadows: getBool('shadows'), effects: getBool('effects'), ambientOcclusion: getBool('ambientOcclusion'),
    mapDecorations: getBool('mapDecorations'), decals: getBool('decals'), ragdolls: getBool('ragdolls'), vsync: getBool('vsync'),
    adaptiveTarget: getBool('adaptiveEnabled') ? Number(getValue('adaptiveTarget')) : 0,
    renderScaleFloor: Number.parseInt(getValue('renderScale'), 10), lowLatency: getValue('lowLatency'),
    gibs: getBool('gibs'), ragdollCollision: getBool('ragdollCollision'), linearMipFiltering: getBool('linearMip'),
    dynamicTextureBudget: getBool('dynamicBudget'), backbufferCount: Number(getValue('backbuffers')),
    shadowDepthMin: Number(getValue('shadowDepth')), shadowUpresFactor: Number(getValue('shadowUpres')),
    maxDynamicShadows: Number(getValue('dynamicShadows')), csmResolution: Number(getValue('csmResolution')),
    shadowCoverage: Number(getValue('shadowCoverage')), ssaoQuality: Number(getValue('ssaoQuality')), ssaoDownsample: getBool('ssaoDownsample'),
    lodScale: getValue('lodScale'), fadeDistanceScale: getValue('fadeScale'), mapDetailLevel: Number(getValue('mapDetailLevel')), decalLimit: Number(getValue('decalLimit')),
    particleFallback: getValue('particleFallback'), viewFov: getValue('viewFov'),
    customReticle: getBool('customReticle'), reticleRed: clampRgb(getValue('reticleRed')),
    reticleGreen: clampRgb(getValue('reticleGreen')), reticleBlue: clampRgb(getValue('reticleBlue')),
    launchOptions: buildCommand()
  };
}

function validateBeforeWrite() {
  if (!resolutionValid()) {
    showToast('Check the output resolution', 'Width must be 640–7680 and height 360–4320.', 'error');
    goToElement($('#width'));
    return false;
  }
  if (buildCommand().length > 1024) {
    showToast('Launch line is too long', 'Steam accepts up to 1024 characters. Shorten Additional commands.', 'error');
    goToElement($('#extraCommands'));
    return false;
  }
  const exec = getValue('execConfig').trim();
  if (exec && !/^[A-Za-z0-9_.-]+$/.test(exec)) {
    showToast('Check the CFG filename', 'Use only letters, numbers, dots, underscores, and hyphens.', 'error');
    goToElement($('#execConfig'));
    return false;
  }
  return true;
}

function loadPreset(name) {
  const set = (id, value) => setControl(id, value);
  if (name === 'fps') {
    set('textureBudget','None'); set('textureQuality','Very Low'); set('anisotropic','1x'); setSegment('aa','Off');
    set('modelDetail','Minimum'); set('particleDetail','Low'); ['shadows','effects','ambientOcclusion','mapDecorations','decals','ragdolls','vsync','gibs','ragdollCollision','linearMip'].forEach(id => set(id,false));
    set('adaptiveEnabled',true); set('adaptiveTarget','120'); set('renderScale','50%'); set('lowLatency','Off'); set('fpsCap','0');
    set('dynamicBudget',true); set('backbuffers','1'); set('shadowDepth','0'); set('shadowUpres','0'); set('dynamicShadows','0'); set('csmResolution','0'); set('shadowCoverage','1'); set('ssaoQuality','0'); set('ssaoDownsample',true); set('lodScale','0.25'); set('fadeScale','0.25'); set('mapDetailLevel','1'); set('decalLimit','64'); set('particleFallback','Aggressive'); set('viewFov','90');
  } else if (name === 'quality') {
    set('textureBudget','Very High'); set('textureQuality','High'); set('anisotropic','16x'); setSegment('aa','TSAA');
    set('modelDetail','High'); set('particleDetail','High'); ['shadows','effects','ambientOcclusion','mapDecorations','decals','ragdolls','gibs','ragdollCollision','linearMip'].forEach(id => set(id,true));
    set('vsync',false); set('adaptiveEnabled',false); set('renderScale','100%'); set('lowLatency','On'); set('fpsCap','120'); set('dynamicBudget',true); set('backbuffers','2'); set('shadowDepth','512'); set('shadowUpres','2'); set('dynamicShadows','4'); set('csmResolution','1024'); set('shadowCoverage','2'); set('ssaoQuality','4'); set('ssaoDownsample',false); set('lodScale','1.00'); set('fadeScale','1.00'); set('mapDetailLevel','2'); set('decalLimit','256'); set('particleFallback','Default'); set('viewFov','110');
  } else {
    set('textureBudget','Medium'); set('textureQuality','Low'); set('anisotropic','4x'); setSegment('aa','Off');
    set('modelDetail','Medium'); set('particleDetail','Medium'); set('shadows',false); set('effects',false); set('ambientOcclusion',false); set('mapDecorations',true); set('decals',false); set('ragdolls',false); set('vsync',false); set('adaptiveEnabled',false); set('renderScale','70%'); set('lowLatency','On'); set('fpsCap','144'); set('dynamicBudget',true); set('backbuffers','1'); set('csmResolution','512'); set('shadowCoverage','1'); set('ssaoQuality','0'); set('ssaoDownsample',true); set('lodScale','0.60'); set('fadeScale','0.70'); set('mapDetailLevel','1'); set('decalLimit','64'); set('particleFallback','Balanced'); set('viewFov','100');
  }
  updateDisplayPreview();
  updateSettingPreview('textureBudget', getValue('textureBudget'));
  renderReview();
  const count = pendingChanges().length;
  showToast(`${name === 'fps' ? 'Most FPS' : name === 'quality' ? 'Best picture' : 'Balanced'} values loaded`, count ? `${count} ${count === 1 ? 'change is' : 'changes are'} ready to review — nothing is written until you apply.` : 'These values already match your current setup.');
}

/* ---------- Actions ---------- */
async function applyAll() {
  if (!validateBeforeWrite()) return false;
  if (!pendingChanges().length) { showToast('Nothing to apply', 'Every setting already matches your Apex files.'); return true; }
  const result = await withBusy('Backing up and applying…', async () => {
    try {
      const response = await api('/api/apply', collectSettings());
      applyLiveState(response.live);
      closeReview();
      showToast('Settings applied', response.message || 'Backup created and changes saved.');
      return true;
    } catch (error) { showToast('Could not apply settings', error.message, 'error'); return false; }
  });
  return Boolean(result);
}

async function applyProfile(profile) {
  const changes = pendingChanges().length;
  if (changes) {
    const choice = await askUser({ title: 'Replace your unapplied changes?', body: `Applying a profile writes its own values and discards ${changes} unapplied ${changes === 1 ? 'change' : 'changes'}. A backup is made first.`, confirm: 'Apply profile' });
    if (!choice) return;
  }
  await withBusy('Applying profile…', async () => {
    try {
      const result = await api('/api/profile', { profile });
      applyLiveState(result.live);
      setActiveProfileUI(result.activeProfile || { type: 'built-in', name: profile });
      showToast('Profile applied', result.message || `${profile} is ready.`);
    } catch (error) { showToast('Could not apply profile', error.message, 'error'); }
  });
}

async function launchApex() {
  let launchOptions = buildCommand();
  const changes = pendingChanges().length;
  if (changes) {
    const choice = await askUser({ title: `Apply ${changes} ${changes === 1 ? 'change' : 'changes'} before launching?`, body: 'Unapplied changes are not used by Apex until you apply them.', confirm: 'Apply and launch', alt: 'Launch anyway' });
    if (!choice) return;
    if (choice === 'confirm') { if (!(await applyAll())) return; launchOptions = buildCommand(); }
    else launchOptions = appState?.launchOptions || '';
  } else if (!validateBeforeWrite()) return;
  await withBusy('Starting Apex through Steam…', async () => {
    try {
      await api('/api/launch', { launchOptions });
      showToast('Launch request sent', 'Apex is starting through Steam.');
    } catch (error) { showToast('Could not launch Apex', error.message, 'error'); }
  });
}

async function copyText(text) {
  try { await navigator.clipboard.writeText(text); return true; }
  catch {
    const area = document.createElement('textarea');
    area.value = text; area.setAttribute('readonly', ''); area.style.position = 'fixed'; area.style.opacity = '0';
    document.body.append(area); area.select();
    let ok = false;
    try { ok = document.execCommand('copy'); } catch { ok = false; }
    area.remove();
    return ok;
  }
}

function openReview() { renderReview(); $('#reviewDrawer').classList.add('open'); $('#reviewDrawer').setAttribute('aria-hidden','false'); }
function closeReview() { $('#reviewDrawer').classList.remove('open'); $('#reviewDrawer').setAttribute('aria-hidden','true'); }

/* ---------- Search ---------- */
let searchIndex = [];
let searchActive = 0;

function buildSearchIndex() {
  searchIndex = $$('.workspace .setting-card, .workspace .control-row, .workspace .control-grid > label, .workspace .safety-action, .workspace .path-card, .workspace .reticle-designer, .workspace .profile-manager').map(element => {
    const title = titleOf(element);
    const keywords = [title, element.dataset.search, element.dataset.commandSearch, element.querySelector('p, small')?.textContent, element.querySelector('code')?.textContent]
      .filter(Boolean).join(' ').toLowerCase();
    return { element, title, keywords, page: element.closest('.page')?.dataset.pagePanel || '' };
  }).filter(item => item.title);
}

function searchSettings(query) {
  const terms = query.toLowerCase().split(/\s+/).filter(Boolean);
  if (!terms.length) return [];
  return searchIndex.map(item => {
    const title = item.title.toLowerCase();
    if (!terms.every(term => item.keywords.includes(term))) return null;
    const score = (title.startsWith(terms[0]) ? 0 : title.includes(terms[0]) ? 1 : 2) + (item.element.matches('.control-row, .control-grid > label') ? .1 : 0);
    return { ...item, score };
  }).filter(Boolean).sort((a, b) => a.score - b.score).slice(0, 8);
}

function renderSearchResults(results, query) {
  const box = $('#searchResults');
  const input = $('#settingsSearch');
  if (!query) { box.hidden = true; input.setAttribute('aria-expanded', 'false'); return; }
  searchActive = Math.min(searchActive, Math.max(0, results.length - 1));
  box.innerHTML = results.length
    ? results.map((result, index) => `<button role="option" class="${index === searchActive ? 'active' : ''}" aria-selected="${index === searchActive}" data-search-index="${index}"><strong>${escapeHtml(result.title)}</strong><span>${escapeHtml(PAGE_NAMES[result.page] || '')}</span></button>`).join('')
    : `<div class="search-empty">No setting matches “${escapeHtml(query)}”</div>`;
  box.hidden = false;
  input.setAttribute('aria-expanded', 'true');
  box._results = results;
}

function chooseSearchResult(index) {
  const result = $('#searchResults')._results?.[index];
  if (!result) return;
  $('#searchResults').hidden = true;
  $('#settingsSearch').setAttribute('aria-expanded', 'false');
  $('#settingsSearch').value = '';
  goToElement(result.element);
}

/* ---------- Events ---------- */
function bindEvents() {
  $$('[data-page]').forEach(button => button.addEventListener('click', () => openPage(button.dataset.page)));
  $$('[data-segment]').forEach(group => $$('button', group).forEach(button => button.addEventListener('click', () => {
    if (button.disabled) return;
    setSegment(group.dataset.segment, button.dataset.value);
    updateDisplayPreview();
    updateSettingPreview(group.dataset.segment, button.dataset.value);
  })));
  $$('input,select,textarea').forEach(control => {
    if (['settingsSearch','launchCommandSearch','commandImport','customProfileName','customProfiles','configLock'].includes(control.id)) return;
    control.addEventListener('change', () => {
      if (control.id === 'width' || control.id === 'height') clampResolutionField(control.id);
      const previewValue = control.type === 'checkbox' ? control.checked : control.value;
      updateDisplayPreview(); updateSettingPreview(control.id, previewValue);
      if (control.id === 'language' && control.value !== 'System default' && !(appState?.installedVoiceLanguages || []).includes(control.value)) {
        showToast('Safe text-language mode', `Voice audio stays ${appState?.steamLanguage || 'Steam default'} because the ${control.value} voice pack is not installed.`);
      }
    });
    control.addEventListener('focus', () => updateSettingPreview(control.id, control.type === 'checkbox' ? control.checked : control.value));
    if (control.tagName === 'TEXTAREA' || control.type === 'number' || control.id === 'execConfig') control.addEventListener('input', updateDisplayPreview);
  });
  $$('[data-resolution]').forEach(button => button.addEventListener('click', () => {
    const [width,height] = button.dataset.resolution === 'native' ? [appState?.native?.width || 1920, appState?.native?.height || 1080] : button.dataset.resolution.split('x').map(Number);
    setControl('width',width); setControl('height',height); updateDisplayPreview();
  }));
  $('#resolutionCatalog')?.addEventListener('change', event => {
    if (!event.target.value) return;
    const [width, height] = event.target.value.split('x').map(Number);
    setControl('width', width); setControl('height', height);
    event.target.value = '';
    updateDisplayPreview();
  });
  $('#reticleColor')?.addEventListener('input', event => syncReticleFromHex(event.target.value));
  ['reticleRed','reticleGreen','reticleBlue'].forEach(id => {
    $(`#${id}`)?.addEventListener('input', () => { $('#reticlePreview')?.style.setProperty('--reticle', `rgb(${clampRgb(getValue('reticleRed'))},${clampRgb(getValue('reticleGreen'))},${clampRgb(getValue('reticleBlue'))})`); scheduleReview(); });
    $(`#${id}`)?.addEventListener('change', () => syncReticleFromRgb());
  });
  $('#customReticle')?.addEventListener('change', () => syncReticleFromRgb());
  $$('[data-reticle]').forEach(button => button.addEventListener('click', () => {
    setControl('customReticle', true);
    syncReticleFromHex(button.dataset.reticle);
  }));
  $('#launchCommandSearch')?.addEventListener('input', event => {
    const query = event.target.value.trim().toLowerCase();
    let visible = 0;
    $$('.command-card').forEach(card => {
      const hidden = Boolean(query) && !`${card.dataset.commandSearch} ${card.textContent}`.toLowerCase().includes(query);
      card.classList.toggle('command-hidden', hidden);
      if (!hidden) visible++;
    });
    $('#commandFilterEmpty')?.toggleAttribute('hidden', visible > 0);
  });
  $('[data-import-command]')?.addEventListener('click', importCommandLine);
  $('#commandImport')?.addEventListener('keydown', event => { if (event.key === 'Enter') { event.preventDefault(); importCommandLine(); } });
  $$('[data-command-preset]').forEach(button => button.addEventListener('click', () => applyCommandPreset(button.dataset.commandPreset)));
  $('#execConfig')?.addEventListener('input', event => {
    const valid = !event.target.value || /^[A-Za-z0-9_.-]+$/.test(event.target.value);
    event.target.setCustomValidity(valid ? '' : 'Use only letters, numbers, dots, underscores, and hyphens.');
    event.target.classList.toggle('invalid', !valid);
  });
  $$('[data-profile]').forEach(button => button.addEventListener('click', () => applyProfile(button.dataset.profile)));
  $$('[data-load]').forEach(button => button.addEventListener('click', () => loadPreset(button.dataset.load)));
  $$('[data-apply]').forEach(button => button.addEventListener('click', applyAll));
  $$('[data-launch]').forEach(button => button.addEventListener('click', launchApex));
  $$('[data-open-review]').forEach(button => button.addEventListener('click', openReview));
  $$('[data-close-review]').forEach(button => button.addEventListener('click', closeReview));
  $('#reviewList').addEventListener('click', event => {
    const revert = event.target.closest('[data-review-revert]');
    if (revert) { revertKey(revert.dataset.reviewRevert); return; }
    const jump = event.target.closest('[data-review-jump]');
    if (jump) { closeReview(); goToElement(elementForKey(jump.dataset.reviewJump)); }
  });
  $('[data-discard-all]')?.addEventListener('click', async () => {
    const changes = pendingChanges();
    if (!changes.length) { closeReview(); return; }
    const choice = await askUser({ title: `Discard ${changes.length} ${changes.length === 1 ? 'change' : 'changes'}?`, body: 'Every control returns to the value Apex is using now.', confirm: 'Discard', tone: 'danger' });
    if (!choice) return;
    changes.forEach(change => revertKey(change.key));
    showToast('Changes discarded', 'Everything matches your current Apex files again.');
  });
  $('[data-copy-command]').addEventListener('click', async () => {
    const ok = await copyText(buildCommand());
    showToast(ok ? 'Command copied' : 'Could not copy', ok ? 'Paste it into Steam → Apex → Properties → Launch options if you launch outside Riftline.' : 'Select the command text and copy it manually.', ok ? 'success' : 'error');
  });
  $('[data-save-command]').addEventListener('click', async () => {
    if (!validateBeforeWrite()) return;
    await withBusy('Saving launch commands…', async () => {
      try {
        const result = await api('/api/save-launch', { launchOptions: buildCommand() });
        if (appState) appState.launchOptions = result.launchOptions ?? buildCommand();
        // Only the launch line was saved; graphics and display changes stay pending.
        const now = snapshot();
        $$('.launch-layout [id]').forEach(node => { if (now.has(node.id)) baseline.set(node.id, now.get(node.id)); });
        renderReview();
        showToast('Launch commands saved', 'Riftline will use them the next time you launch.');
      } catch (error) { showToast('Could not save', error.message, 'error'); }
    });
  });
  $('[data-custom-save]')?.addEventListener('click', async () => {
    const name = getValue('customProfileName').trim();
    if (!name) { showToast('Name this profile first', 'Use a short name such as Ranked or Streaming.', 'error'); $('#customProfileName').focus(); return; }
    if (/[\\/:*?"<>|]/.test(name)) { showToast('Choose a different name', 'Profile names cannot contain \\ / : * ? " < > |', 'error'); $('#customProfileName').focus(); return; }
    if (!validateBeforeWrite()) return;
    const exists = customProfilesCache.some(profile => String(profile.Name ?? profile.name).toLowerCase() === name.toLowerCase());
    if (exists) {
      const choice = await askUser({ title: `Replace “${name}”?`, body: 'A saved profile with this name already exists. Saving replaces it with the current values.', confirm: 'Replace profile' });
      if (!choice) return;
    }
    await withBusy('Saving profile…', async () => {
      try {
        const result = await api('/api/custom-save', { name, settings: collectSettings() });
        refreshCustomProfiles(result.profiles); $('#customProfiles').value = name;
        setActiveProfileUI(result.activeProfile || appState?.activeProfile);
        $('#customProfileName').value = '';
        showToast('Profile saved', `${name} stores every visible setting. Use Apply to make it active.`);
      } catch(error) { showToast('Could not save profile', error.message, 'error'); }
    });
  });
  $('[data-custom-apply]')?.addEventListener('click', async () => {
    const name = getValue('customProfiles');
    if (!name) { showToast('Choose a saved profile', 'Save your current setup first, then apply it any time.', 'error'); return; }
    const changes = pendingChanges().length;
    if (changes) {
      const choice = await askUser({ title: `Apply “${name}”?`, body: `This replaces ${changes} unapplied ${changes === 1 ? 'change' : 'changes'} with the saved profile. A backup is made first.`, confirm: 'Apply profile' });
      if (!choice) return;
    }
    await withBusy('Applying saved profile…', async () => {
      try {
        const result = await api('/api/custom-apply', { name });
        applyLiveState(result.live);
        setActiveProfileUI(result.activeProfile || { type: 'custom', name });
        showToast('Profile applied', result.message);
      }
      catch(error) { showToast('Could not apply profile', error.message, 'error'); }
    });
  });
  $('[data-custom-delete]')?.addEventListener('click', async () => {
    const name = getValue('customProfiles');
    if (!name) return;
    const choice = await askUser({ title: `Delete “${name}”?`, body: 'The saved profile is removed. Your current Apex settings are not changed.', confirm: 'Delete profile', tone: 'danger' });
    if (!choice) return;
    await withBusy('Deleting profile…', async () => {
      try { const result = await api('/api/custom-delete', { name }); refreshCustomProfiles(result.profiles); setActiveProfileUI(result.activeProfile); showToast('Profile deleted', name); }
      catch(error) { showToast('Could not delete profile', error.message, 'error'); }
    });
  });
  $('#configLock').addEventListener('change', async event => {
    const wanted = event.target.checked;
    const done = await withBusy(wanted ? 'Locking config…' : 'Unlocking config…', async () => {
      try { await api('/api/config-lock',{locked:wanted}); showToast(wanted ? 'Config locked' : 'Config unlocked', wanted ? 'Apex cannot overwrite your video settings until you unlock it.' : 'Apex can save video changes again.'); return true; }
      catch(error){ showToast('Could not change lock',error.message,'error'); return false; }
    });
    if (!done) event.target.checked = !wanted;
  });
  $$('[data-action]').forEach(button => button.addEventListener('click', async () => {
    const prompts = {
      'restore-latest': { title: 'Restore the newest backup?', body: 'Your video, latency, and FOV/reticle files return to how they were before the most recent change.', confirm: 'Restore backup' },
      'restore-regular': { title: 'Return to regular Apex?', body: 'Restores the files from before Riftline was first used and clears Riftline launch commands. Saved profiles are kept.', confirm: 'Restore original files', tone: 'danger' },
      'clear-cache': { title: 'Clear the PSO shader cache?', body: 'Apex rebuilds it on the next launch, so expect some stutter for the first match.', confirm: 'Clear cache', tone: 'danger' }
    };
    const choice = await askUser(prompts[button.dataset.action]);
    if (!choice) return;
    await withBusy('Working…', async () => {
      try {
        const result = await api(`/api/${button.dataset.action}`,{});
        if (result.live) applyLiveState(result.live);
        if (button.dataset.action === 'restore-regular') setActiveProfileUI();
        showToast('Action complete',result.message || 'Finished successfully.');
      } catch(error){ showToast('Action failed',error.message,'error'); }
    });
  }));
  $('[data-shutdown]').addEventListener('click', async () => {
    const changes = pendingChanges().length;
    if (changes) {
      const choice = await askUser({ title: 'Close with unapplied changes?', body: `${changes} ${changes === 1 ? 'change has' : 'changes have'} not been applied and will be lost.`, confirm: 'Close anyway', alt: 'Apply and close', tone: 'danger' });
      if (!choice) return;
      if (choice === 'alt' && !(await applyAll())) return;
    }
    try { await api('/api/shutdown',{}); } finally { window.close(); }
  });
  $$('[data-window]:not([data-shutdown])').forEach(button => button.addEventListener('click', () => {
    if (hasNativeBridge) window.chrome.webview.postMessage({ kind: 'window', action: button.dataset.window });
  }));
  $('[data-drag-region]')?.addEventListener('pointerdown', event => {
    if (!hasNativeBridge || event.button !== 0 || event.target.closest('.top-actions,.preset-strip,input,select,textarea,a,button')) return;
    window.chrome.webview.postMessage({ kind: 'window', action: 'drag' });
  });

  const search = $('#settingsSearch');
  search.addEventListener('input', () => { searchActive = 0; renderSearchResults(searchSettings(search.value.trim()), search.value.trim()); });
  search.addEventListener('keydown', event => {
    const results = $('#searchResults')._results || [];
    if (event.key === 'ArrowDown' || event.key === 'ArrowUp') {
      event.preventDefault();
      if (!results.length) return;
      searchActive = (searchActive + (event.key === 'ArrowDown' ? 1 : -1) + results.length) % results.length;
      renderSearchResults(results, search.value.trim());
    } else if (event.key === 'Enter') { event.preventDefault(); chooseSearchResult(searchActive); }
    else if (event.key === 'Escape') { search.value = ''; renderSearchResults([], ''); search.blur(); }
  });
  search.addEventListener('blur', () => setTimeout(() => { $('#searchResults').hidden = true; search.setAttribute('aria-expanded', 'false'); }, 150));
  search.addEventListener('focus', () => { if (search.value.trim()) renderSearchResults(searchSettings(search.value.trim()), search.value.trim()); });
  $('#searchResults').addEventListener('mousedown', event => {
    const option = event.target.closest('[data-search-index]');
    if (option) { event.preventDefault(); chooseSearchResult(Number(option.dataset.searchIndex)); }
  });

  document.addEventListener('keydown', event => {
    if ($('#modalRoot').classList.contains('open')) return;
    if ((event.ctrlKey || event.metaKey) && event.key.toLowerCase() === 'k') { event.preventDefault(); search.focus(); search.select(); }
    if ((event.ctrlKey || event.metaKey) && event.key.toLowerCase() === 's') { event.preventDefault(); applyAll(); }
    if (event.key === 'Escape') closeReview();
  });
  window.addEventListener('beforeunload', event => { if (!hasNativeBridge && pendingChanges().length) { event.preventDefault(); event.returnValue = ''; } });
}

function hydrate(state) {
  appState = state;
  $('#gpuName').textContent = state.hardware.gpu;
  $('#nativeResolution').textContent = `Native ${state.native.width} × ${state.native.height}${state.native.refresh ? ` · ${state.native.refresh} Hz` : ''}`;
  const refreshStatus = $('#refreshStatus');
  if (refreshStatus) refreshStatus.textContent = state.native.refresh ? `Your monitor reports ${state.native.refresh} Hz` : '';
  $('#recommendedName').textContent = state.hardware.label;
  $('#configPath').textContent = state.configPath;
  $('#configStatus').textContent = state.configExists ? 'Connected' : 'Start Apex once to create this file';
  $('#steamPath').textContent = state.steamPath || 'Steam installation not detected';
  $('#steamStatus').textContent = state.steamPath ? 'Official launcher ready' : 'Use your normal EA / Steam launch route';
  const voiceLanguages = state.installedVoiceLanguages || [];
  const languageStatus = $('#languageStatus');
  if (languageStatus) languageStatus.textContent = `Steam language: ${state.steamLanguage || 'unknown'} · Installed voice: ${voiceLanguages.length ? voiceLanguages.join(', ') : 'none detected'}`;
  if (!state.current) { setControl('width', state.native.width); setControl('height', state.native.height); }
  applyLiveState(state);
  if (state.apexRunning) showToast('Apex is running', 'Close Apex completely before applying changes.', 'error');
}

async function start() {
  bindEvents();
  buildSearchIndex();
  try { hydrate(await api('/api/state')); }
  catch (error) {
    showToast('Riftline could not connect', error.message, 'error');
    $('.connection').classList.add('offline');
    $('#connectionText').textContent = 'Engine connection failed';
    updateDisplayPreview();
    resetBaseline();
  }
  setTimeout(() => $('#loadingScreen').classList.add('hidden'), 280);
  if (!hasNativeBridge) {
    setInterval(() => api('/api/ping').catch(() => {}), 20000);
    // Tell the browser fallback server the window closed. It waits a few seconds so a reload keeps it alive.
    window.addEventListener('pagehide', () => { try { navigator.sendBeacon(`/api/goodbye?token=${encodeURIComponent(token)}`); } catch {} });
  }
  // Returning to Riftline (usually after closing Apex) re-reads the game state, so the
  // "Apex is running" warning clears and any settings Apex saved on exit are picked up.
  window.addEventListener('focus', refreshFromGame);
  document.addEventListener('visibilitychange', () => { if (document.visibilityState === 'visible') refreshFromGame(); });
}

let lastGameRefresh = 0;
async function refreshFromGame() {
  if (busy || Date.now() - lastGameRefresh < 4000) return;
  lastGameRefresh = Date.now();
  try {
    if (!appState) { hydrate(await api('/api/state')); return; }
    const live = await api('/api/live');
    if (busy) return;
    if (pendingChanges().length) setConnection(live);
    else applyLiveState(live);
    appState = { ...appState, apexRunning: live.apexRunning, configExists: live.configExists };
  } catch (error) {
    $('.connection').classList.add('offline');
    $('#connectionText').textContent = 'Engine connection failed';
  }
}

start();
