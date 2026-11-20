/* Riftline build 36 — finding and understanding settings.
   - Field of view: type any value, drag the slider, or tap a common one.
   - Search understands everyday words ("crosshair", "blurry", "input lag") and small typos.
   - The All settings page lists every setting with what it does, its FPS cost, its value now,
     and the competitive pick, with buttons to explain it or jump to it. */
(() => {
'use strict';

/* ---------- Field of view ---------- */
const FOV_MIN = 1, FOV_MAX = 179;
function parseFov(text) {
  const clean = String(text || '').trim().replace(/°$/, '').trim();
  if (clean === '') return { empty: true };
  if (!/^\d{1,3}(\.\d{1,2})?$/.test(clean)) return { error: 'Type a number such as 104 or 104.5.' };
  const value = Number(clean);
  if (value < FOV_MIN || value > FOV_MAX) return { error: `Pick a number from ${FOV_MIN} to ${FOV_MAX}.` };
  return { value };
}
function fovScale(value) { return (1 + (value - 70) * 0.01375).toFixed(6); }

function updateFov(fromSlider) {
  const input = document.getElementById('viewFov');
  const slider = document.getElementById('fovSlider');
  const note = document.getElementById('fovNote');
  const pill = document.getElementById('fovPill');
  if (!input || !note) return;
  const parsed = parseFov(input.value);
  input.classList.toggle('invalid', Boolean(parsed.error));
  input.setAttribute('aria-invalid', String(Boolean(parsed.error)));
  if (!fromSlider && parsed.value !== undefined && slider) slider.value = String(Math.max(Number(slider.min), Math.min(Number(slider.max), parsed.value)));
  if (pill) pill.textContent = parsed.value !== undefined ? `${parsed.value}°` : parsed.error ? 'Check value' : 'Keep current';
  $$('[data-fov]').forEach(button => button.classList.toggle('active', button.dataset.fov === (parsed.empty ? '' : String(parsed.value))));
  note.dataset.state = parsed.error ? 'error' : parsed.value !== undefined && (parsed.value < 70 || parsed.value > 110) ? 'warn' : '';
  if (parsed.empty) note.textContent = 'Leave empty to keep the FOV you already set in Apex.';
  else if (parsed.error) note.textContent = parsed.error;
  else {
    const where = parsed.value < 70 ? 'below' : parsed.value > 110 ? 'above' : '';
    note.textContent = `Writes cl_fovScale ${fovScale(parsed.value)}. ` + (where
      ? `This is ${where} Apex's menu range (70–110). Riftline writes it anyway; if this Apex build caps it, this box shows the value Apex kept next time you open Riftline.`
      : 'Inside the range of Apex\'s own menu slider.');
  }
}
function setFov(value, fromSlider) {
  const input = document.getElementById('viewFov');
  if (!input) return;
  input.value = value;
  updateFov(fromSlider);
  input.dispatchEvent(new Event('input', { bubbles: true }));
  input.dispatchEvent(new Event('change', { bubbles: true }));
}
document.addEventListener('input', event => {
  if (event.target.id === 'fovSlider') setFov(event.target.value, true);
  else if (event.target.id === 'viewFov') updateFov(false);
});
document.addEventListener('change', event => { if (event.target.id === 'viewFov') updateFov(false); });
document.addEventListener('click', event => {
  const button = event.target.closest('[data-fov]');
  if (button) { event.preventDefault(); setFov(button.dataset.fov, false); }
});
// Presets, profiles, setup codes and the engine set the box directly, so keep the slider and note in step.
const originalSetControl = window.setControl;
if (typeof originalSetControl === 'function') {
  window.setControl = function setControlWithFov(id, value) {
    const result = originalSetControl(id, id === 'viewFov' && String(value) === 'Keep current' ? '' : value);
    if (id === 'viewFov') updateFov(false);
    return result;
  };
}

/* ---------- Everyday words and typos for search ---------- */
const WORDS = {
  viewFov: 'fov zoom wide narrow view angle peripheral fish eye',
  textureBudget: 'vram memory gpu memory stutter streaming',
  textureQuality: 'blurry sharp textures skins',
  anisotropic: 'blurry ground floor sharp distance filtering af',
  aa: 'jagged edges smooth blurry tsaa antialiasing',
  shadows: 'shadow sun dark',
  effects: 'fog volumetric haze light beams god rays',
  ambientOcclusion: 'ao ssao dark corners',
  vsync: 'tearing sync input lag delay',
  lowLatency: 'reflex anti lag input lag delay latency responsive',
  fpsCap: 'fps limit cap max frames framerate',
  lobbyFps: 'lobby menu fps limit cap',
  fpsCounter: 'show fps counter frame rate overlay',
  rawInput: 'mouse acceleration sensitivity aim',
  reticleColor: 'crosshair reticle colour color sight',
  adaptiveEnabled: 'dynamic resolution render scale upscaling blurry',
  width: 'resolution size pixels 1080p 1440p 4k stretched',
  backbuffers: 'input lag buffering latency',
  noMotionBlur: 'blur motion blurry turning',
  noBloom: 'glow glare bright',
  lodScale: 'pop in draw distance level of detail',
  fadeScale: 'pop in draw distance fade',
  particleDetail: 'smoke explosions sparks',
  ragdolls: 'bodies corpses dead physics'
};
function wordsFor(key, element) {
  let words = WORDS[key] || '';
  if (element?.querySelector('#viewFov')) words += ' ' + WORDS.viewFov;
  if (element?.querySelector('#reticleColor, #reticleRed')) words += ' ' + WORDS.reticleColor;
  if (/^ow|^ue-/.test(key || '')) {
    const id = String(key).replace(/^ow|^ue-/, '').toLowerCase();
    if (/framerate|fps|limit/.test(id)) words += ' ' + WORDS.fpsCap;
    if (/sync/.test(id)) words += ' ' + WORDS.vsync;
    if (/shadow/.test(id)) words += ' ' + WORDS.shadows;
    if (/fog|volumetric/.test(id)) words += ' ' + WORDS.effects;
    if (/texture/.test(id)) words += ' ' + WORDS.textureQuality;
    if (/reflex|latency/.test(id)) words += ' ' + WORDS.lowLatency;
  }
  return words;
}
// Allows one wrong, missing, extra or swapped letter for words of 4+ letters, two for 8+.
function close(a, b, limit) {
  if (Math.abs(a.length - b.length) > limit) return false;
  const row = Array.from({ length: b.length + 1 }, (_, i) => i);
  for (let i = 1; i <= a.length; i++) {
    let previous = row[0], best = row[0] = i;
    for (let j = 1; j <= b.length; j++) {
      const saved = row[j];
      row[j] = Math.min(row[j] + 1, row[j - 1] + 1, previous + (a[i - 1] === b[j - 1] ? 0 : 1));
      previous = saved; best = Math.min(best, row[j]);
    }
    if (best > limit) return false;
  }
  return row[b.length] <= limit;
}
function fuzzy(term, text) {
  if (term.length < 4) return false;
  const limit = term.length >= 8 ? 2 : 1;
  return text.split(/[^a-z0-9_.+]+/).some(word => word.length >= 3 && (close(term, word, limit) || (word.length > term.length && close(term, word.slice(0, term.length), limit))));
}
window.riftlineFind = { wordsFor, fuzzy, parseFov };

/* ---------- All settings page ---------- */
const PAGE_LABEL = { safety: 'Safety', display: 'Display', visuals: 'Visuals', advanced: 'Advanced', launch: 'Launch', overwatch: 'Overwatch 2', unreal: 'Game settings' };
const PAGE_ORDER = ['display', 'visuals', 'advanced', 'launch', 'overwatch', 'unreal', 'safety'];
let showFilter = 'all';

function valueOf(card) {
  const width = card.querySelector('#width'), height = card.querySelector('#height');
  if (width && height) return `${width.value} × ${height.value}`;
  const segment = card.querySelector('[data-segment] .active');
  if (segment) return segment.textContent.trim();
  const control = card.querySelector('select, input:not([type=range]):not([type=search])');
  if (!control) return '';
  if (control.type === 'checkbox') return control.checked ? 'On' : 'Off';
  if (control.tagName === 'SELECT') return control.selectedOptions[0]?.textContent.trim() || control.value;
  if (control.id === 'viewFov') return control.value.trim() ? `${control.value.trim()}°` : 'Keep current';
  return control.value.trim() || (control.placeholder ? `(${control.placeholder})` : '—');
}
function proValue(card, key, guide) {
  if (guide.rec === undefined) return null;
  const control = card.querySelector('select, input:not([type=range]):not([type=search])');
  if (control?.type === 'checkbox') return String(guide.rec) === 'true' || guide.rec === true ? 'On' : 'Off';
  if (control?.tagName === 'SELECT') return [...control.options].find(option => option.value === String(guide.rec))?.textContent.trim() || String(guide.rec);
  const segment = card.querySelector(`[data-segment] [data-value="${CSS.escape(String(guide.rec))}"]`);
  if (segment) return segment.textContent.trim();
  return key === 'viewFov' ? `${guide.rec}°` : String(guide.rec);
}

function collect() {
  const GUIDE = window.riftlineGuide?.GUIDE || {};
  const family = document.body.dataset.family || 'apex';
  const seen = new Set();
  return $$('.workspace [data-guide]').map(button => {
    const key = button.dataset.guide, guide = GUIDE[key];
    const card = button.closest('.control-row, .control-grid > label, .setting-card');
    const page = card?.closest('.page');
    if (!guide || !card || !page || seen.has(card)) return null;
    if (page.dataset.game && page.dataset.game !== family) return null;
    if (page.dataset.pagePanel === 'unreal' && !$('#ueGroups')?.children.length) return null;
    seen.add(card);
    const now = valueOf(card), pro = proValue(card, key, guide);
    const changed = Boolean(card.querySelector('.ow-changed') || card.classList.contains('ow-changed')) ||
      (typeof pendingChanges === 'function' && pendingChanges().some(change => card.contains(typeof elementForKey === 'function' ? elementForKey(change.key) : null)));
    const words = `${guide.title} ${guide.what} ${guide.comp || ''} ${card.textContent} ${wordsFor(key, card)} ${PAGE_LABEL[page.dataset.pagePanel] || ''}`.toLowerCase();
    return { key, guide, card, page: page.dataset.pagePanel, now, pro, changed, words, offPick: pro !== null && pro !== now };
  }).filter(Boolean);
}

function render() {
  const list = $('#allSettingsList');
  if (!list) return;
  const { dots, LEVEL } = window.riftlineGuide || {};
  const query = ($('#settingsFilter')?.value || '').trim().toLowerCase();
  const terms = query.split(/\s+/).filter(Boolean);
  const sort = $('#settingsSort')?.value || 'page';
  let rows = collect().filter(row => terms.every(term => row.words.includes(term) || fuzzy(term, row.words)));
  if (showFilter === 'fps') rows = rows.filter(row => row.guide.fps >= 2);
  if (showFilter === 'changed') rows = rows.filter(row => row.changed);
  if (showFilter === 'offpick') rows = rows.filter(row => row.offPick);
  const pageIndex = row => PAGE_ORDER.indexOf(row.page);
  rows.sort(sort === 'fps' ? (a, b) => b.guide.fps - a.guide.fps || a.guide.title.localeCompare(b.guide.title)
    : sort === 'az' ? (a, b) => a.guide.title.localeCompare(b.guide.title)
    : (a, b) => pageIndex(a) - pageIndex(b));
  list._rows = rows;
  $('#settingsCount').textContent = rows.length ? `${rows.length} setting${rows.length === 1 ? '' : 's'}` : '';
  let lastPage = '';
  list.innerHTML = rows.map((row, index) => {
    const heading = sort === 'page' && row.page !== lastPage ? `<h2 class="all-page-heading">${escapeHtml(PAGE_LABEL[row.page] || row.page)}</h2>` : '';
    lastPage = row.page;
    const level = n => LEVEL ? LEVEL[n] : '';
    return `${heading}<article class="all-row${row.changed ? ' changed' : ''}">
      <div class="all-main"><h3>${escapeHtml(row.guide.title)}${row.changed ? '<em>Changed</em>' : ''}</h3><p>${escapeHtml(row.guide.what)}</p></div>
      <div class="all-facts">
        <span><small>FPS cost</small>${dots ? dots(row.guide.fps, 'cost') : ''}<b>${escapeHtml(level(row.guide.fps))}</b></span>
        <span><small>Now</small><b>${escapeHtml(row.now)}</b></span>
        ${row.pro !== null ? `<span class="${row.offPick ? 'off-pick' : 'on-pick'}"><small>Pro pick</small><b>${escapeHtml(row.pro)}</b></span>` : ''}
      </div>
      <div class="all-actions"><button data-all-go="${index}">Show</button><button data-all-explain="${index}">Explain</button></div>
    </article>`;
  }).join('') || `<div class="all-empty">Nothing matches${query ? ` “${escapeHtml(query)}”` : ''}. Try another word, or choose All.</div>`;
}

let renderFrame = 0;
const queueRender = () => { clearTimeout(renderFrame); renderFrame = setTimeout(render, 16); };
document.addEventListener('input', event => { if (event.target.id === 'settingsFilter') queueRender(); });
document.addEventListener('change', event => { if (event.target.id === 'settingsSort') queueRender(); });
document.addEventListener('click', event => {
  const go = event.target.closest('[data-all-go]');
  const explain = event.target.closest('[data-all-explain]');
  const rows = $('#allSettingsList')?._rows || [];
  if (go) { goToElement(rows[Number(go.dataset.allGo)]?.card); return; }
  if (explain) { window.riftlineGuide?.openGuide(rows[Number(explain.dataset.allExplain)]?.key); return; }
  const chip = event.target.closest('[data-all-show]');
  if (chip) {
    showFilter = chip.dataset.allShow;
    $$('[data-all-show]').forEach(button => button.classList.toggle('active', button === chip));
    queueRender(); return;
  }
  const fromSearch = event.target.closest('[data-all-query]');
  if (fromSearch) {
    const filter = $('#settingsFilter');
    if (filter) filter.value = fromSearch.dataset.allQuery;
    $('#searchResults').hidden = true;
    openPage('settings');
  }
  if (event.target.closest('[data-page="settings"], [data-switch-game]')) setTimeout(queueRender, 30);
});
// Keep the search box focused so its results stay open long enough for the click.
document.addEventListener('mousedown', event => { if (event.target.closest('[data-all-query]')) event.preventDefault(); });
// Values change after the engine loads and after every apply.
const originalReset = window.resetBaseline;
if (typeof originalReset === 'function') {
  window.resetBaseline = function resetAndRender(...args) {
    const result = originalReset.apply(this, args);
    updateFov(false);
    if ($('.page[data-page-panel="settings"]')?.classList.contains('active')) queueRender();
    return result;
  };
}
updateFov(false);
})();
