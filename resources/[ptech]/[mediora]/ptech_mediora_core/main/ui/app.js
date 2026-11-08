const panel = document.getElementById('action-panel');
const icon = document.getElementById('icon');
const title = document.getElementById('title');
const tabs = document.getElementById('tabs');
const message = document.getElementById('message');
const track = document.getElementById('track');
const fill = document.getElementById('fill');
const switchHint = document.getElementById('switchHint');
const panels = {};
let activeId = null;
let switchKey = 'Z';
let panelHidden = false;
function render() {
    const ids = Object.keys(panels);
    if (ids.length === 0) {
        panel.classList.add('is-hidden');
        activeId = null;
        panelHidden = false;
        return;
    }
    if (panelHidden) {
        panel.classList.add('is-hidden');
        return;
    }
    if (!panels[activeId]) activeId = ids[0];

    const current = panels[activeId];
    panel.className = `action-panel state-${current.state || 'ready'}`;
    panel.style.setProperty('--panel-accent', current.accent || '#55d4bc');
    icon.textContent = current.icon || '•';
    title.textContent = current.title || activeId;
    message.textContent = current.text || '';

    const hasProgress = Number.isFinite(current.progress);
    track.classList.toggle('is-hidden', !hasProgress);
    fill.style.width = `${Math.max(0, Math.min(100, current.progress || 0))}%`;

    tabs.replaceChildren();
    tabs.classList.toggle('is-hidden', ids.length === 0);
    for (const id of ids) {
        const indicator = document.createElement('span');
        const active = id === activeId;
        indicator.className = `indicator${active ? ' is-active' : ''}`;
        indicator.style.setProperty('--indicator-accent', panels[id].accent || '#55d4bc');
        indicator.setAttribute('role', 'img');
        indicator.setAttribute('aria-label', `${panels[id].title || id}${active ? '（選択中）' : ''}`);
        tabs.appendChild(indicator);
    }
    switchHint.textContent = `${switchKey}で切替 / しまう`;
    switchHint.classList.remove('is-hidden');
}

window.addEventListener('message', (event) => {
    const data = event.data || {};
    if (data.action === 'configure') {
        switchKey = data.switchKey || switchKey;
        render();
        return;
    }
    if (data.action === 'setPanel' && typeof data.id === 'string' && data.panel) {
        const isNew = !panels[data.id];
        panels[data.id] = data.panel;
        if (data.switchKey) switchKey = data.switchKey;
        if (isNew) {
            activeId = data.id;
            panelHidden = false;
        } else if (!panelHidden && !panels[activeId]) {
            activeId = data.id;
        }
        render();
        return;
    }
    if (data.action === 'removePanel' && typeof data.id === 'string') {
        delete panels[data.id];
        if (activeId === data.id) activeId = panelHidden ? null : Object.keys(panels)[0] || null;
        render();
        return;
    }
    if (data.action === 'clearPanels') {
        for (const id of Object.keys(panels)) delete panels[id];
        activeId = null;
        panelHidden = false;
        render();
        return;
    }
    if (data.action === 'nextTab') {
        const ids = Object.keys(panels);
        if (ids.length === 0) return;
        if (panelHidden) {
            panelHidden = false;
            activeId = panels[activeId] ? activeId : ids[0];
        } else {
            const index = ids.indexOf(activeId);
            if (index < 0 || index === ids.length - 1) {
                panelHidden = true;
                activeId = null;
            } else {
                activeId = ids[index + 1];
            }
        }
        render();
    }
});
