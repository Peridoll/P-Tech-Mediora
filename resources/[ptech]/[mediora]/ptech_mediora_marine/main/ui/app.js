const panel = document.getElementById('flotation');
const icon = document.getElementById('icon');
const title = document.getElementById('title');
const tabs = document.getElementById('tabs');
const message = document.getElementById('message');
const track = document.getElementById('track');
const fill = document.getElementById('fill');
const switchHint = document.getElementById('switchHint');
const panels = {};
let activeId = null;
let switchKey = 'F6';

function render() {
    const ids = Object.keys(panels);
    if (ids.length === 0) {
        panel.classList.add('is-hidden');
        activeId = null;
        return;
    }
    if (!panels[activeId]) activeId = ids[0];

    const current = panels[activeId];
    panel.className = `flotation state-${current.state || 'ready'} kind-${activeId}`;
    icon.textContent = current.icon || (activeId === 'rescue' ? 'R' : '◌');
    title.textContent = current.title || (activeId === 'rescue' ? '緊急離脱' : '緊急浮上装置');
    message.textContent = current.text || '';

    const hasProgress = Number.isFinite(current.progress);
    track.classList.toggle('is-hidden', !hasProgress);
    fill.style.width = `${Math.max(0, Math.min(100, current.progress || 0))}%`;

    tabs.replaceChildren();
    tabs.classList.toggle('is-hidden', ids.length < 2);
    for (const id of ids) {
        const tab = document.createElement('span');
        tab.className = `tab${id === activeId ? ' is-active' : ''}`;
        tab.setAttribute('role', 'tab');
        tab.setAttribute('aria-selected', id === activeId ? 'true' : 'false');
        tab.textContent = panels[id].title || (id === 'rescue' ? 'Rescue' : 'Marine');
        tabs.appendChild(tab);
    }
    switchHint.textContent = ids.length > 1 ? `${switchKey}でタブ切替` : '';
    switchHint.classList.toggle('is-hidden', ids.length < 2);
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
        if (isNew || !panels[activeId]) activeId = data.id;
        render();
        return;
    }
    if (data.action === 'removePanel' && typeof data.id === 'string') {
        delete panels[data.id];
        if (activeId === data.id) activeId = Object.keys(panels)[0] || null;
        render();
        return;
    }
    if (data.action === 'clearPanels') {
        for (const id of Object.keys(panels)) delete panels[id];
        activeId = null;
        render();
        return;
    }
    if (data.action === 'nextTab') {
        const ids = Object.keys(panels);
        if (ids.length < 2) return;
        activeId = ids[(ids.indexOf(activeId) + 1) % ids.length];
        render();
    }
});
