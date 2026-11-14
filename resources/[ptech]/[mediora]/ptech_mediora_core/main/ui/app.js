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
let minimized = true;
let panelTransition;
let temporaryExpansion;
function restoreTemporaryExpansion(id) {
    if (temporaryExpansion?.id !== id) return;
    minimized = temporaryExpansion.minimized;
    activeId = temporaryExpansion.activeId;
    temporaryExpansion = undefined;
}

let editingPosition = false;
let inventoryPositionEditing = false;
let deathPositionEditing = false;
let positionFinishing = false;
let positionSession;
let panelPosition;
let panelDrag;
const positionEditor = document.getElementById('panel-position-editor');
const positionStatus = document.getElementById('panel-position-status');
const inGame = typeof GetParentResourceName === 'function';

async function panelPost(route, data = {}) {
    const response = await fetch('https://' + GetParentResourceName() + '/' + route, {
        method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(data),
    });
    if (!response.ok) throw new Error('位置を保存できませんでした。');
    return response.json();
}


let boundsTimer;
let lastPanelBounds;
function reportPanelBounds() {
    if (!inGame) return;
    clearTimeout(boundsTimer);
    boundsTimer = setTimeout(() => {
        const rect = panel.getBoundingClientRect();
        const bounds = panel.classList.contains('is-hidden') ? false : {
            left: Math.max(0, rect.left / window.innerWidth),
            top: Math.max(0, rect.top / window.innerHeight),
            right: Math.min(1, rect.right / window.innerWidth),
            bottom: Math.min(1, rect.bottom / window.innerHeight),
        };
        const serialized = JSON.stringify(bounds);
        if (serialized === lastPanelBounds) return;
        lastPanelBounds = serialized;
        panelPost('actionPanelBounds', { bounds }).catch(() => { lastPanelBounds = undefined; });
    }, 50);
}
new ResizeObserver(reportPanelBounds).observe(panel);

function applyPanelPosition() {
    reportPanelBounds();
    if (!panelPosition) {
        panel.style.right = '';
        panel.style.top = '';
        panel.style.bottom = '';
        return;
    }
    const bounds = panel.getBoundingClientRect();
    const right = Math.max(8, Math.min(window.innerWidth - bounds.width - 8, panelPosition.right * window.innerWidth));
    const top = Math.max(8, Math.min(window.innerHeight - bounds.height - 8, panelPosition.top * window.innerHeight));
    panel.style.right = right + 'px';
    panel.style.top = top + 'px';
    panel.style.bottom = 'auto';
}

function clearPanelDrag() {
    if (panelDrag && panel.hasPointerCapture(panelDrag.id)) panel.releasePointerCapture(panelDrag.id);
    panelDrag = undefined;
}

async function finishPanelPosition(save, position = panelPosition || false) {
    if (!editingPosition || positionFinishing) return;
    positionFinishing = true;
    clearPanelDrag();
    const session = positionSession;
    try {
        if (inGame) {
            const result = await panelPost('actionPanelPositionFinish', { session, save, position });
            if (!result.ok) throw new Error('位置を保存できませんでした。');
        } else {
            if (save) panelPosition = position || undefined;
            editingPosition = false;
            positionEditor.hidden = true;
            render();
        }
    } catch (error) {
        if (editingPosition && positionSession === session) {
            positionFinishing = false;
            positionEditor.hidden = false;
            positionStatus.textContent = error.message + ' Escで終了できます。';
        }
    }
}

panel.addEventListener('pointerdown', event => {
    if (!editingPosition || event.button !== 0) return;
    event.preventDefault();
    panelTransition?.cancel();
    panelTransition = undefined;
    const bounds = panel.getBoundingClientRect();
    panelDrag = {
        id: event.pointerId, x: event.clientX, y: event.clientY,
        right: window.innerWidth - bounds.right, top: bounds.top,
    };
    panel.setPointerCapture(event.pointerId);
});
panel.addEventListener('pointermove', event => {
    if (!panelDrag || event.pointerId !== panelDrag.id) return;
    panelPosition = {
        right: Math.max(0, Math.min(1, (panelDrag.right - event.clientX + panelDrag.x) / window.innerWidth)),
        top: Math.max(0, Math.min(1, (panelDrag.top + event.clientY - panelDrag.y) / window.innerHeight)),
    };
    applyPanelPosition();
});
panel.addEventListener('pointerup', event => {
    if (!panelDrag || event.pointerId !== panelDrag.id) return;
    const bounds = panel.getBoundingClientRect();
    panelPosition = {
        right: (window.innerWidth - bounds.right) / window.innerWidth,
        top: bounds.top / window.innerHeight,
    };
    finishPanelPosition(true);
});
panel.addEventListener('pointercancel', () => {
    clearPanelDrag();
    if (inventoryPositionEditing) finishPanelPosition(false);
});
panel.addEventListener('pointerleave', () => {
    if (inventoryPositionEditing && !panelDrag) finishPanelPosition(false);
});
window.addEventListener('resize', applyPanelPosition);
window.addEventListener('keydown', event => {
    if (editingPosition && deathPositionEditing && event.key === 'Tab') {
        event.preventDefault();
        if (!event.repeat) finishPanelPosition(false);
        return;
    }
    if (editingPosition && event.key === 'Escape') {
        event.preventDefault();
        finishPanelPosition(false);
    }
});
document.getElementById('panel-position-reset').addEventListener('click', () => finishPanelPosition(true, false));
document.getElementById('panel-position-cancel').addEventListener('click', () => finishPanelPosition(false));

function render() {
    const wasVisible = !panel.classList.contains('is-hidden');
    const resizing = wasVisible && panel.classList.contains('is-minimized') !== minimized;
    const previous = resizing ? panel.getBoundingClientRect() : null;
    if (resizing || Object.keys(panels).length === 0) {
        panelTransition?.cancel();
        panelTransition = undefined;
    }
    const visiblePanels = editingPosition && Object.keys(panels).length === 0
        ? { position_preview: { title: 'パネルの位置調整', text: 'ドラッグして移動', icon: '•' } }
        : panels;
    const ids = Object.keys(visiblePanels);
    if (ids.length === 0) {
        panel.classList.add('is-hidden');
        reportPanelBounds();
        activeId = null;
        minimized = true;
        return;
    }
    if (!visiblePanels[activeId]) activeId = ids[0];

    const current = visiblePanels[activeId];
    panel.className = `action-panel state-${current.state || 'ready'}${minimized ? ' is-minimized' : ''}${editingPosition ? ' is-positioning' : ''}`;
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
        const active = !minimized && id === activeId;
        indicator.className = `indicator${active ? ' is-active' : ''}`;
        indicator.style.setProperty('--indicator-accent', visiblePanels[id].accent || '#55d4bc');
        indicator.title = visiblePanels[id].title || id;
        indicator.setAttribute('role', 'img');
        indicator.setAttribute('aria-label', `${visiblePanels[id].title || id}${active ? '（選択中）' : ''}`);
        tabs.appendChild(indicator);
    }
    switchHint.textContent = minimized ? `${switchKey}で開く` : `${switchKey}で切替 / 最小化`;
    switchHint.classList.remove('is-hidden');
    applyPanelPosition();
    if (previous && !editingPosition && !matchMedia('(prefers-reduced-motion: reduce)').matches) {
        const currentBounds = panel.getBoundingClientRect();
        const frame = bounds => ({
            width: bounds.width + 'px',
            height: bounds.height + 'px',
            right: (window.innerWidth - bounds.right) + 'px',
        });
        const effect = panel.animate([frame(previous), frame(currentBounds)], {
            duration: 240, easing: 'cubic-bezier(.22,.7,.3,1)', fill: 'both',
        });
        panelTransition = effect;
        effect.onfinish = () => {
            if (panelTransition !== effect) return;
            panelTransition = undefined;
            effect.cancel();
        };
    }
}

window.addEventListener('message', (event) => {
    const data = event.data || {};
    if (data.action === 'panelPosition') {
        clearPanelDrag();
        panelTransition?.cancel();
        panelTransition = undefined;
        panelPosition = data.position || undefined;
        editingPosition = data.editing === true;
        inventoryPositionEditing = editingPosition && data.inventory === true;
        deathPositionEditing = editingPosition && data.death === true;
        positionFinishing = false;
        positionSession = data.session;
        positionEditor.hidden = !editingPosition || inventoryPositionEditing;
        positionStatus.textContent = deathPositionEditing
            ? 'ドラッグして移動・離して保存 ／ Tab・Escで閉じる'
            : 'ドラッグして移動・離して保存 ／ Escでキャンセル';
        render();
        if (editingPosition && inGame) {
            panelPost('actionPanelEditing', { session: positionSession }).catch(() => finishPanelPosition(false));
        }
        return;
    }
    if (data.action === 'configure') {
        switchKey = data.switchKey || switchKey;
        render();
        return;
    }
    if (data.action === 'setPanel' && typeof data.id === 'string' && data.panel) {
        const isNew = !panels[data.id];
        const wasExpanding = panels[data.id]?.temporaryExpand === true;
        if (!data.panel.temporaryExpand) restoreTemporaryExpansion(data.id);
        if (isNew && data.panel.startMinimized && !data.panel.temporaryExpand && !editingPosition) minimized = true;
        if (data.panel.temporaryExpand && !wasExpanding && minimized && !editingPosition) {
            temporaryExpansion = { id: data.id, minimized, activeId };
            minimized = false;
            activeId = data.id;
        }
        panels[data.id] = data.panel;
        if (data.switchKey) switchKey = data.switchKey;
        if (isNew) {
            activeId = data.id;
        } else if (!minimized && !panels[activeId]) {
            activeId = data.id;
        }
        render();
        return;
    }
    if (data.action === 'removePanel' && typeof data.id === 'string') {
        restoreTemporaryExpansion(data.id);
        delete panels[data.id];
        if (activeId === data.id) activeId = minimized ? null : Object.keys(panels)[0] || null;
        render();
        return;
    }
    if (data.action === 'clearPanels') {
        temporaryExpansion = undefined;
        for (const id of Object.keys(panels)) delete panels[id];
        activeId = null;
        minimized = true;
        render();
        return;
    }
    if (data.action === 'nextTab') {
        if (editingPosition) return;
        temporaryExpansion = undefined;
        const ids = Object.keys(panels);
        if (ids.length === 0) return;
        if (minimized) {
            minimized = false;
            activeId = panels[activeId] ? activeId : ids[0];
        } else {
            const index = ids.indexOf(activeId);
            if (index < 0 || index === ids.length - 1) {
                minimized = true;
                activeId = null;
            } else {
                activeId = ids[index + 1];
            }
        }
        render();
    }
});

if (inGame) panelPost('actionPanelReady').catch(console.error);
