/* Riftline build 32 — tabs inside long pages so only one section shows at a time.
   Loaded last. Search, Review and the setting guide still reach any setting: going to a
   setting opens its tab first, and the Launch filter searches every tab at once. */
(() => {
'use strict';

const byId = (...ids) => ids.map(id => document.getElementById(id)?.closest('.setting-card, .reticle-designer')).filter(Boolean);
const groupsIn = (page, selector, labelSelector) => $$(selector, page).map(group => ({ label: $(labelSelector, group)?.textContent.trim() || 'Settings', elements: [group] }));

// Each entry returns the tabs for a page: [{ label, elements }].
const LAYOUTS = {
  visuals: () => [
    { label: 'Detail', elements: byId('textureBudget', 'textureQuality', 'anisotropic', 'modelDetail', 'particleDetail') },
    { label: 'Lighting & effects', elements: byId('shadows', 'effects', 'ambientOcclusion', 'mapDecorations', 'decals', 'ragdolls') },
    { label: 'Smoothness & latency', elements: [...byId('vsync', 'lowLatency'), $('[data-segment="aa"]')?.closest('.setting-card')].filter(Boolean) }
  ],
  advanced: page => groupsIn(page, '.advanced-grid > .settings-group', '.group-heading span'),
  launch: () => [
    { label: 'Frame rate', elements: byId('fpsCap', 'lobbyFps', 'fpsCounter', 'refreshRate') },
    { label: 'Input & latency', elements: byId('rawInput', 'noJoy', 'forceNoVsync', 'highPriority') },
    { label: 'Performance', elements: byId('preload', 'multicore', 'threads', 'softParticlesOff') },
    { label: 'Clarity', elements: byId('noMotionBlur', 'noTracers', 'noBloom', 'softenedLocale', 'showPos', 'minimizeAltTab') },
    { label: 'Reticle', elements: byId('reticleColor') },
    { label: 'Startup & expert', elements: byId('skipIntro', 'developerMode', 'execConfig', 'language', 'extraCommands') }
  ],
  overwatch: page => groupsIn(page, '.ow-groups > .ow-group', 'header span'),
  unreal: page => groupsIn(page, '#ueGroups > .ow-group', 'header span')
};
const SHORT = { 'Display and frame rate': 'Display & FPS', 'Graphics quality': 'Graphics', 'Clarity and latency': 'Clarity', 'Distance, detail, physics, and view': 'Distance & view', 'Textures and memory': 'Textures & memory', 'Shadows and AO': 'Shadows & AO' };

const built = {};   // page name -> tabs

function remember(page, index) { try { localStorage.setItem(`riftline.tab.${page}`, String(index)); } catch {} }
function recall(page) { try { return Number(localStorage.getItem(`riftline.tab.${page}`)) || 0; } catch { return 0; } }

function build(name) {
  const page = $(`.page[data-page-panel="${name}"]`);
  if (!page || !LAYOUTS[name]) return;
  const tabs = LAYOUTS[name](page).filter(tab => tab.elements.length);
  $('.subtabs', page)?.remove();
  page.querySelectorAll('[data-tab-index]').forEach(node => { node.classList.remove('tab-hidden'); delete node.dataset.tabIndex; });
  if (tabs.length < 2) { delete built[name]; return; }
  tabs.forEach((tab, index) => tab.elements.forEach(element => { element.dataset.tabIndex = String(index); }));
  const bar = document.createElement('div');
  bar.className = 'subtabs'; bar.setAttribute('role', 'tablist'); bar.setAttribute('aria-label', 'Sections');
  bar.innerHTML = tabs.map((tab, index) => `<button role="tab" data-subtab="${index}" id="tab-${name}-${index}"><span>${escapeHtml(SHORT[tab.label] || tab.label)}</span><b class="subtab-count" hidden></b></button>`).join('');
  // The bar goes right before the first tabbed element so headings and previews stay above it.
  const first = tabs.flatMap(tab => tab.elements).sort((a, b) => (a.compareDocumentPosition(b) & Node.DOCUMENT_POSITION_FOLLOWING ? -1 : 1))[0];
  const anchor = first.closest('.launch-layout, .advanced-grid, .settings-list.two-up, .ow-groups') || first;
  anchor.parentElement.insertBefore(bar, anchor);
  built[name] = { page, tabs, bar };
  select(name, Math.min(recall(name), tabs.length - 1), false);
  updateCounts();
}

function select(name, index, focus) {
  const entry = built[name];
  if (!entry) return;
  entry.page.querySelectorAll('[data-tab-index]').forEach(node => node.classList.toggle('tab-hidden', node.dataset.tabIndex !== String(index)));
  $$('[data-subtab]', entry.bar).forEach(button => {
    const on = button.dataset.subtab === String(index);
    button.classList.toggle('active', on); button.setAttribute('aria-selected', String(on)); button.tabIndex = on ? 0 : -1;
    if (on && focus) button.focus();
  });
  remember(name, index);
}

// Small badges show how many unsaved changes each tab holds.
let countFrame = 0;
function updateCounts() {
  cancelAnimationFrame(countFrame);
  countFrame = requestAnimationFrame(() => {
    const apexChanged = new Set((typeof pendingChanges === 'function' ? pendingChanges() : []).map(change => elementForKey(change.key)).filter(Boolean));
    Object.values(built).forEach(({ tabs, bar }) => tabs.forEach((tab, index) => {
      let count = 0;
      tab.elements.forEach(element => {
        count += $$('.ow-changed', element).length + (element.classList.contains('ow-changed') ? 1 : 0);
        apexChanged.forEach(control => { if (element.contains(control)) count += 1; });
      });
      const badge = $(`[data-subtab="${index}"] .subtab-count`, bar);
      if (badge) { badge.hidden = count === 0; badge.textContent = String(count); }
    }));
  });
}

// Going to a setting (search, Review, guide) opens the tab that holds it.
const originalGoTo = window.goToElement;
window.goToElement = function goToElementInTab(element, ...rest) {
  const holder = element?.closest?.('[data-tab-index]');
  const name = holder?.closest('.page')?.dataset.pagePanel;
  if (holder && built[name]) select(name, Number(holder.dataset.tabIndex), false);
  return originalGoTo(element, ...rest);
};

document.addEventListener('click', event => {
  const button = event.target.closest('[data-subtab]');
  if (button) { const name = button.closest('.page')?.dataset.pagePanel; select(name, Number(button.dataset.subtab), false); return; }
  updateCounts();
});
document.addEventListener('keydown', event => {
  const button = event.target.closest?.('[data-subtab]');
  if (!button || !['ArrowLeft', 'ArrowRight', 'Home', 'End'].includes(event.key)) return;
  event.preventDefault();
  const name = button.closest('.page').dataset.pagePanel, count = built[name].tabs.length, current = Number(button.dataset.subtab);
  const next = event.key === 'Home' ? 0 : event.key === 'End' ? count - 1 : (current + (event.key === 'ArrowRight' ? 1 : -1) + count) % count;
  select(name, next, true);
});
document.addEventListener('change', updateCounts);
document.addEventListener('input', updateCounts);

// The Launch filter looks through every tab while it has text in it.
$('#launchCommandSearch')?.addEventListener('input', event => {
  $('.page[data-page-panel="launch"]')?.classList.toggle('tabs-searching', event.target.value.trim() !== '');
});

['visuals', 'advanced', 'launch', 'overwatch'].forEach(build);
// The Unreal page is drawn per game, so games.js asks for its tabs after each render.
window.riftlineTabs = { build, select, updateCounts };
})();
