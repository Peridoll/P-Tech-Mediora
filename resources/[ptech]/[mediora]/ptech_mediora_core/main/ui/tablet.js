(() => {
    const element = (id) => document.getElementById(`tablet-${id}`);
    const tablet = document.getElementById('tablet');
    const preview = typeof GetParentResourceName !== 'function';
    let opened = false;
    let request = 0;
    let busy = false;
    let transition;
    function animateTablet(visible) {
        transition?.cancel();
        tablet.hidden = false;
        tablet.inert = !visible;
        if (matchMedia('(prefers-reduced-motion: reduce)').matches) {
            tablet.hidden = !visible;
            return;
        }
        const effect = element('shutter').animate([
            { clipPath: 'inset(0 0 0 0)', opacity: 1, offset: 0 },
            { clipPath: 'inset(0 0 0 0)', opacity: 1, offset: .17 },
            { clipPath: 'inset(0 0 100% 0)', opacity: 1, offset: 1 },
        ], { duration: visible ? 380 : 260, direction: visible ? 'normal' : 'reverse', easing: 'cubic-bezier(.25,.65,.25,1)', fill: 'both' });
        transition = effect;
        effect.onfinish = () => {
            if (transition !== effect) return;
            tablet.hidden = !visible;
            effect.cancel();
            transition = undefined;
        };
    }
    async function post(route, data = {}) {
        const controller = new AbortController();
        const timeout = setTimeout(() => controller.abort(), 15000);
        try {
            const response = await fetch(`https://${GetParentResourceName()}/${route}`, {
                method: 'POST', headers: { 'Content-Type': 'application/json; charset=UTF-8' }, body: JSON.stringify(data),
                signal: controller.signal,
            });
            if (!response.ok) throw new Error('request_failed');
            return await response.json();
        } finally { clearTimeout(timeout); }
    }
    let page = 'home';
    let isAdmin = false;
    let operating = false;
    const actionText = { start: ['起動中', '起動完了'], stop: ['停止中', '停止完了'], restart: ['再起動中', '再起動完了'] };
    const states = { started: '稼働中', stopped: '停止中', starting: '起動中', stopping: '停止処理中', missing: '未導入', uninitialized: '未初期化', unknown: '不明' };
    function status(text) {
        element('status').textContent = text;
        element('status').hidden = !text;
    }
    function selectPage(next) {
        if (!['home', 'settings', 'resources'].includes(next)) return;
        if (next === 'resources' && !isAdmin) return;
        page = next;
        for (const id of ['home', 'settings', 'resources']) element(id).hidden = id !== page;
        element('admin-link').hidden = !isAdmin || !['settings', 'resources'].includes(page);
        document.querySelectorAll('[data-page]').forEach((button) => {
            const selected = button.dataset.page === page;
            button.classList.toggle('selected', selected);
            button.setAttribute('aria-current', selected ? 'page' : 'false');
        });
        if (page === 'resources') refreshResources();
        if (page === 'settings') loadAccess(request);
    }
    async function loadAccess(version) {
        try {
            const result = preview ? { ok: true, admin: false } : await post('tabletAccess');
            if (!opened || version !== request) return;
            if (!result.ok) throw new Error(result.error || 'unavailable');
            isAdmin = result.ok === true && result.admin === true;
            element('admin-link').hidden = !isAdmin || !['settings', 'resources'].includes(page);
        } catch {
            if (opened && version === request) {
                isAdmin = false;
                element('admin-link').hidden = true;
                status('管理者権限を確認できませんでした。タブレットを開き直してください。');
            }
        }
    }
    async function refreshResources() {
        if (!opened || !isAdmin || busy) return;
        const version = request;
        busy = true;
        element('refresh').disabled = true;
        if (!operating) element('resource-status').textContent = 'リソース情報を取得しています…';
        element('resource-list').replaceChildren();
        try {
            const result = await post('tabletResources');
            if (!opened || request !== version) return;
            if (!result.ok) {
                if (result.error === 'forbidden') { isAdmin = false; selectPage('settings'); }
                throw new Error(result.error);
            }
            for (const resource of result.resources) {
                const row = document.createElement('li');
                const name = document.createElement('strong');
                const state = document.createElement('span');
                name.textContent = resource.name;
                state.textContent = states[resource.state] || states.unknown;
                row.dataset.state = resource.state;
                row.dataset.operation = resource.operation?.phase || '';
                const details = document.createElement('div');
                details.className = 'tablet-resource-details';
                details.append(name, state);
                if (resource.operation) {
                    const operation = resource.operation;
                    const progress = document.createElement('small');
                    progress.className = `tablet-operation ${operation.phase}`;
                    const labels = actionText[operation.action] || ['処理中', '処理完了'];
                    const time = Number.isFinite(operation.time) ? new Date(operation.time * 1000).toLocaleTimeString('ja-JP') : '';
                    progress.textContent = `${operation.phase === 'pending' ? labels[0] : operation.phase === 'complete' ? labels[1] : '操作失敗'} ${time}`;
                    details.append(progress);
                }
                const controls = document.createElement('div');
                controls.className = 'tablet-resource-controls';
                const actions = resource.name === 'ptech_mediora_core' ? ['restart'] : ['start', 'stop', 'restart'];
                for (const action of actions) {
                    const button = document.createElement('button');
                    const icon = document.createElement('b');
                    icon.textContent = { start: '▶', stop: '■', restart: '↻' }[action];
                    const label = document.createElement('span');
                    label.textContent = { start: '起動', stop: '停止', restart: '再起動' }[action];
                    button.append(icon, label);
                    button.setAttribute('aria-label', `${resource.name} を${label.textContent}`);
                    button.dataset.action = action;
                    button.disabled = operating || resource.operation?.phase === 'pending' || (action === 'start' ? resource.state !== 'stopped' : resource.state !== 'started');
                    button.addEventListener('click', () => operate(resource.name, action));
                    controls.append(button);
                }
                row.append(details, controls);
                element('resource-list').append(row);
            }
            if (!operating) element('resource-status').textContent = result.resources.length ? '稼働状況の一覧' : '対象のリソースがありません。';
        } catch {
            if (opened && version === request) status('リソース情報を取得できませんでした。権限・アイテムの所持を確認してください。');
        } finally {
            if (version === request) { busy = false; element('refresh').disabled = false; }
        }
    }
    async function operate(name, action) {
        if (operating || !opened || !isAdmin) return;
        const version = request;
        operating = true;
        status('');
        for (const button of element('resource-list').querySelectorAll('button')) button.disabled = true;
        element('refresh').disabled = true;
        element('resource-status').dataset.phase = 'pending';
        element('resource-status').textContent = `${name}：${actionText[action][0]}…`;
        for (const row of element('resource-list').children) {
            if (row.querySelector('strong')?.textContent === name) row.dataset.operation = 'pending';
        }
        try {
            const result = await post('tabletResourceAction', { name, action });
            if (!opened || request !== version) return;
            if (!result.ok) {
                const errors = { command_permission: 'リソース操作の実行権限が未設定です。サーバー管理者に設定を確認してください。', restart_permission: 'Coreの再起動権限が未設定です。server.cfgに command.restart の許可を追加してください。', core_protected: 'Coreは再起動のみ操作できます。', forbidden: '管理者権限がありません。', busy: '別の操作が処理中です。少し待ってから更新してください。', operation_failed: '操作に失敗しました。サーバーログを確認してください。', invalid_state: '状態が変わりました。更新して再度操作してください。' };
                throw new Error(errors[result.error] || '操作できませんでした。権限とアイテムの所持を確認してください。');
            }
            if (result.restartingCore) {
                element('resource-status').textContent = 'Coreを再起動します。タブレットが閉じた後、アイテムを使用して開き直してください。';
                return;
            }
            operating = false;
            await refreshResources();
            if (opened && request === version) {
                element('resource-status').dataset.phase = 'complete';
                element('resource-status').textContent = `${name}：${actionText[action][1]}`;
            }
        } catch (error) {
            if (opened && request === version) {
                operating = false;
                await refreshResources();
                element('resource-status').dataset.phase = 'failed';
                element('resource-status').textContent = `${name}：操作失敗・結果未確認`;
                status(error.message);
            }
        } finally {
            if (request === version) { operating = false; element('refresh').disabled = false; }
        }
    }
    function setVisible(visible) {
        opened = visible;
        animateTablet(visible);
        const version = ++request;
        busy = false;
        operating = false;
        element('resource-status').dataset.phase = '';
        isAdmin = false;
        element('admin-link').hidden = true;
        element('refresh').disabled = false;
        element('resource-list').replaceChildren();
        status('');
        if (visible) { selectPage('home'); document.querySelector('[data-page="home"]').focus(); loadAccess(version); }
    }
    async function close() {
        if (!opened) return;
        if (preview) { setVisible(false); return; }
        try { await post('tabletClose'); setVisible(false); }
        catch { status('閉じられませんでした。Esc またはホームボタンでもう一度お試しください。'); }
    }
    window.addEventListener('message', ({ data }) => {
        if (data?.action === 'tablet:open') setVisible(true);
        if (data?.action === 'tablet:close') setVisible(false);
    });
    window.addEventListener('keydown', (event) => {
        if (!opened) return;
        if (event.key === 'Escape') { event.preventDefault(); close(); }
        if (event.key === 'Tab') {
            const buttons = [...tablet.querySelectorAll('button:not(:disabled)')].filter((button) => !button.closest('[hidden]'));
            const first = buttons[0], last = buttons[buttons.length - 1];
            if (event.shiftKey && document.activeElement === first) { event.preventDefault(); last.focus(); }
            else if (!event.shiftKey && document.activeElement === last) { event.preventDefault(); first.focus(); }
        }
    });
    document.querySelectorAll('[data-page]').forEach((button) => button.addEventListener('click', () => selectPage(button.dataset.page)));
    element('refresh').addEventListener('click', () => { status(''); refreshResources(); });
    element('home-button').addEventListener('click', close);
    if (preview) setVisible(true);
    else {
        let attempts = 0;
        const initialize = () => post('tabletReady').catch(() => {
            if (++attempts < 5) setTimeout(initialize, 1000);
            else status('初期化に失敗しました。Coreを再起動してください。');
        });
        initialize();
    }
})();
