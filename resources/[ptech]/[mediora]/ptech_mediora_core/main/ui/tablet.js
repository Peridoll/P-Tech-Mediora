(() => {
    const element = (id) => document.getElementById(`tablet-${id}`);
    const tablet = document.getElementById('tablet');
    const preview = typeof GetParentResourceName !== 'function';
    const progressThemes = new Set(['mediora', 'blue', 'amber', 'violet', 'peach', 'lime']);
    let progressTheme = 'mediora';
    function applyProgressTheme(theme) {
        progressTheme = progressThemes.has(theme) ? theme : 'mediora';
        document.documentElement.dataset.progressTheme = progressTheme;
        element('progress-theme').value = progressTheme;
    }
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
    let chartRequest = 0;
    let charts = [];
    const chartParts = { head: '頭部', upper_body: '上半身', lower_body: '下半身', left_arm: '左腕', right_arm: '右腕', left_leg: '左脚', right_leg: '右脚' };
    const injuryKinds = { blunt: '打ち身', bruise: '打撲', cut: '切り傷', burn: '火傷', fracture: '骨折', bleeding: '出血', shot: '銃創', stabbed: '刺創', beat: '打撲', burned: '火傷', pin: '通電ピン' };
    const injuryLevels = ['なし', '軽度', '中等度', '高度', '最重度'];

    function clearChartResults() {
        charts = [];
        element('chart-results').hidden = true;
        element('chart-patient').textContent = '';
        element('chart-history').replaceChildren();
        element('chart-condition').textContent = '';
        element('chart-injuries').replaceChildren();
    }
    function resetCharts() {
        chartRequest++;
        clearChartResults();
        element('chart-search').reset();
        element('chart-submit').disabled = false;
        element('chart-status').textContent = '患者のサーバーIDを入力して照会してください。';
    }
    function showChart() {
        const chart = charts[element('chart-history').selectedIndex];
        if (!chart) return;
        element('chart-condition').textContent = [chart.death, chart.observationStatus].filter(Boolean).join(' ／ ') || '状態の記録なし';
        const list = element('chart-injuries');
        list.replaceChildren();
        const injuries = Array.isArray(chart.injuries) ? chart.injuries : [];
        for (const injury of injuries) {
            const item = document.createElement('li');
            const part = injury.body || chartParts[injury.part] || injury.part || '部位不明';
            const kind = injuryKinds[injury.kind] || injury.kind || '種類不明';
            const level = injuryLevels[injury.severity];
            item.textContent = `${part} ／ ${kind}${level ? ` ／ ${level}` : ''}`;
            list.append(item);
        }
        if (!injuries.length) {
            const empty = document.createElement('li');
            empty.textContent = '負傷の記録はありません。';
            list.append(empty);
        }
    }
    async function searchCharts(event) {
        event.preventDefault();
        if (!opened || page !== 'charts' || element('chart-submit').disabled) return;
        const targetId = element('chart-patient-id').valueAsNumber;
        if (!Number.isSafeInteger(targetId) || targetId <= 0) return;
        const version = ++chartRequest;
        clearChartResults();
        element('chart-submit').disabled = true;
        element('chart-status').textContent = '照会しています…';
        try {
            const result = preview ? { error: 'ゲーム内でカルテを確認できます。' } : await post('tabletCharts', { targetId });
            if (version !== chartRequest) return;
            if (result.error || !result.patient) {
                element('chart-status').textContent = result.error || 'カルテを取得できませんでした。';
                return;
            }
            charts = Array.isArray(result.charts) ? result.charts : [];
            const patient = result.patient.name || '氏名未登録';
            if (!charts.length) {
                element('chart-status').textContent = `${patient}のカルテはありません。`;
                return;
            }
            element('chart-patient').textContent = `${patient}（ID ${targetId}）`;
            const history = element('chart-history');
            for (const chart of charts) {
                const option = document.createElement('option');
                const date = new Date(chart.issuedAt);
                const issued = Number.isFinite(date.getTime()) ? date.toLocaleString('ja-JP') : '日時未記録';
                option.textContent = `${issued} ／ 担当 ${chart.examinerName || '未記録'}`;
                history.append(option);
            }
            history.selectedIndex = 0;
            showChart();
            element('chart-status').textContent = `${charts.length}件のカルテ`;
            element('chart-results').hidden = false;
        } catch {
            if (version === chartRequest) element('chart-status').textContent = 'カルテを取得できませんでした。';
        } finally {
            if (version === chartRequest) element('chart-submit').disabled = false;
        }
    }
    let isAdmin = false;
    let operating = false;
    const actionText = { start: ['起動中', '起動完了'], stop: ['停止中', '停止完了'], restart: ['再起動中', '再起動完了'] };
    const states = { started: '稼働中', stopped: '停止中', starting: '起動中', stopping: '停止処理中', missing: '未導入', uninitialized: '未初期化', unknown: '不明' };
    function status(text) {
        element('status').textContent = text;
        element('status').hidden = !text;
    }
    const shopCart = new Map();
    let shopItems = [];
    let shopLimit = 0;
    let shopKey;
    let shopBusy = false;
    const shopStatus = (message) => { element('shop-status').textContent = message; };
    const shopMoney = (amount) => '$' + Number(amount).toLocaleString('ja-JP');
    const shopTotal = () => shopItems.reduce((sum, item) => sum + item.price * (shopCart.get(item.id) || 0), 0);
    const shopQuantity = () => [...shopCart.values()].reduce((sum, count) => sum + count, 0);

    const shopDragType = 'application/x-mediora-shop-item';
    const shopDropzone = element('shop-dropzone');

    function updateShopQuantity(id, count) {
        if (shopBusy || !shopItems.some(item => item.id === id)) return;
        const previous = shopCart.get(id) || 0;
        const max = Math.max(0, shopLimit - shopQuantity() + previous);
        const quantity = Math.min(max, Math.max(0, Math.trunc(count)));
        if (quantity !== previous) {
            if (quantity) shopCart.set(id, quantity);
            else shopCart.delete(id);
            shopKey = undefined;
        }
        renderShop();
    }

    function shopItemImage(id) {
        const image = document.createElement('img');
        image.alt = '';
        image.draggable = false;
        image.src = 'https://cfx-nui-ox_inventory/web/images/' + encodeURIComponent(id) + '.png';
        image.addEventListener('error', () => { image.style.visibility = 'hidden'; });
        return image;
    }

    function renderShop() {
        const catalog = element('shop-items');
        const cart = element('shop-cart');
        catalog.replaceChildren();
        cart.replaceChildren();
        const quantity = shopQuantity();
        for (const item of shopItems) {
            const card = document.createElement('article');
            const canAdd = !shopBusy && quantity < shopLimit;
            card.draggable = canAdd;
            card.addEventListener('dragstart', event => {
                if (!canAdd || !event.dataTransfer) return event.preventDefault();
                event.dataTransfer.effectAllowed = 'copy';
                event.dataTransfer.setData(shopDragType, item.id);
            });
            card.addEventListener('dragend', () => shopDropzone.classList.remove('shop-drag-over'));

            const image = shopItemImage(item.id);
            const detail = document.createElement('div');
            const name = document.createElement('strong');
            name.textContent = item.label;
            const description = document.createElement('p');
            description.textContent = item.description || '';
            detail.className = 'shop-item-detail';
            detail.append(name, description);
            if (item.treatment) {
                const treatment = document.createElement('span');
                treatment.className = 'shop-treatment';
                treatment.textContent = '対応 · ' + item.treatment;
                detail.append(treatment);
            }
            const purchase = document.createElement('div');
            purchase.className = 'shop-item-purchase';
            const price = document.createElement('strong');
            price.textContent = shopMoney(item.price);
            const owned = document.createElement('span');
            owned.className = 'shop-owned';
            owned.textContent = '所持 ' + Number(item.owned ?? 0).toLocaleString('ja-JP') + '個';
            const add = document.createElement('button');
            add.type = 'button';
            add.textContent = '＋';
            add.setAttribute('aria-label', item.label + 'をカートに追加');
            add.disabled = !canAdd;
            add.addEventListener('click', () => updateShopQuantity(item.id, (shopCart.get(item.id) || 0) + 1));
            purchase.append(price, owned, add);
            card.append(image, detail, purchase);
            catalog.append(card);

            const count = shopCart.get(item.id);
            if (!count) continue;
            const row = document.createElement('li');
            const cartDetail = document.createElement('div');
            cartDetail.className = 'shop-cart-detail';
            const cartName = document.createElement('strong');
            cartName.textContent = item.label;
            const unitPrice = document.createElement('span');
            unitPrice.textContent = shopMoney(item.price) + ' / 個';
            const label = document.createElement('label');
            label.textContent = '数量';
            const input = document.createElement('input');
            input.type = 'number';
            input.min = '1';
            input.max = String(Math.max(1, shopLimit - quantity + count));
            input.step = '1';
            input.value = String(count);
            input.disabled = shopBusy;
            input.setAttribute('aria-label', item.label + 'の数量');
            input.addEventListener('change', () => {
                const number = input.valueAsNumber;
                if (Number.isFinite(number)) updateShopQuantity(item.id, Math.max(1, number));
                else input.value = String(count);
            });
            input.addEventListener('keydown', event => {
                if (event.key === 'Enter') input.blur();
            });
            label.append(input);
            cartDetail.append(cartName, unitPrice, label);
            const actions = document.createElement('div');
            actions.className = 'shop-cart-actions';
            const subtotal = document.createElement('strong');
            subtotal.textContent = shopMoney(item.price * count);
            const remove = document.createElement('button');
            remove.type = 'button';
            remove.textContent = '×';
            remove.disabled = shopBusy;
            remove.setAttribute('aria-label', item.label + 'をカートから削除');
            remove.addEventListener('click', () => updateShopQuantity(item.id, 0));
            actions.append(subtotal, remove);
            row.append(shopItemImage(item.id), cartDetail, actions);
            cart.append(row);
        }
        element('shop-empty').hidden = cart.childElementCount > 0;
        element('shop-total').textContent = quantity + '点 · ' + shopMoney(shopTotal());
        element('shop-place').disabled = shopBusy || shopTotal() <= 0 || quantity > shopLimit;
    }

    shopDropzone.addEventListener('dragover', event => {
        if (shopBusy || shopQuantity() >= shopLimit || !event.dataTransfer?.types.includes(shopDragType)) return;
        event.preventDefault();
        event.dataTransfer.dropEffect = 'copy';
        shopDropzone.classList.add('shop-drag-over');
    });
    shopDropzone.addEventListener('dragleave', event => {
        if (!shopDropzone.contains(event.relatedTarget)) shopDropzone.classList.remove('shop-drag-over');
    });
    shopDropzone.addEventListener('drop', event => {
        shopDropzone.classList.remove('shop-drag-over');
        if (!event.dataTransfer?.types.includes(shopDragType)) return;
        event.preventDefault();
        const id = event.dataTransfer.getData(shopDragType);
        updateShopQuantity(id, (shopCart.get(id) || 0) + 1);
    });

    async function loadShop(message = '') {
        const version = request;
        shopStatus(message || '商品を読み込んでいます…');
        try {
            const result = await post('tabletShopCatalog');
            if (!opened || version !== request || page !== 'shop') return;
            if (!result.ok) throw new Error(result.error || 'ストアを開けませんでした。');
            shopItems = Array.isArray(result.items) ? result.items : [];
            shopLimit = result.limit;
            for (const id of shopCart.keys()) {
                if (!shopItems.some(item => item.id === id)) shopCart.delete(id);
            }
            const labels = {
                waiting: 'ピルボックスで受取待ち', handed_over: 'ピルボックスの受取ロッカー',
                refund_due: '返金待ち', refunded: '返金済み', declined: '決済不成立',
                paying: '決済確認中', refunding: '返金確認中', handing_over: '受取準備中',
            };
            const history = element('shop-orders');
            history.replaceChildren();
            const orders = Array.isArray(result.orders) ? result.orders : [];
            if (!orders.length) history.textContent = '注文はまだありません。';
            for (const order of orders) {
                const entry = document.createElement('li');
                const title = document.createElement('strong');
                title.textContent = '#' + order.id + ' · ' + labels[order.status] + ' · ' + shopMoney(order.total);
                const detail = document.createElement('p');
                detail.textContent = order.items.map(item => item.label + ' × ' + item.count).join('、');
                if (order.status === 'waiting') {
                    detail.textContent += ' / 受取期限 ' + new Date(order.expiresAt * 1000).toLocaleString('ja-JP');
                }
                entry.append(title, detail);
                history.append(entry);
            }
            shopStatus(message);
        } catch (error) {
            if (!opened || version !== request || page !== 'shop') return;
            shopItems = [];
            element('shop-orders').replaceChildren();
            shopStatus(error.message || 'ストアを開けませんでした。');
        }
        renderShop();
    }

    element('shop-place').addEventListener('click', async () => {
        if (shopBusy || shopTotal() <= 0 || shopQuantity() > shopLimit) return;
        const version = request;
        shopBusy = true;
        shopKey ||= Array.from(crypto.getRandomValues(new Uint32Array(4)), number => number.toString(16).padStart(8, '0')).join('');
        renderShop();
        try {
            const result = await post('tabletShopPlace', { key: shopKey, cart: Object.fromEntries(shopCart), total: shopTotal() });
            if (!opened || version !== request) return;
            if (!result.ok) throw new Error(result.error || '注文できませんでした。');
            shopCart.clear();
            shopKey = undefined;
            if (page === 'shop') await loadShop('注文 #' + result.id + ' を受け付けました。');
        } catch (error) {
            if (opened && version === request && page === 'shop') await loadShop(error.message || '注文結果を確認できませんでした。');
        } finally {
            shopBusy = false;
            if (opened && page === 'shop') renderShop();
        }
    });

    function selectPage(next) {
        if (!['home', 'charts', 'shop', 'settings', 'resources'].includes(next)) return;
        if (next === 'resources' && !isAdmin) return;
        if (next !== page && (page === 'charts' || next === 'charts')) resetCharts();
        page = next;
        for (const id of ['home', 'charts', 'shop', 'settings', 'resources']) element(id).hidden = id !== page;
        element('admin-link').hidden = !isAdmin || !['settings', 'resources'].includes(page);
        document.querySelectorAll('[data-page]').forEach((button) => {
            const selected = button.dataset.page === page;
            button.classList.toggle('selected', selected);
            button.setAttribute('aria-current', selected ? 'page' : 'false');
        });
        if (page === 'shop') loadShop();
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
                const consoleOnly = resource.consoleOnly || resource.name === 'ptech_mediora_core';
                if (consoleOnly) {
                    const hint = document.createElement('span');
                    hint.textContent = 'サーバーコンソールで管理';
                    controls.append(hint);
                }
                const actions = consoleOnly ? [] : ['start', 'stop', 'restart'];
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
                const errors = { command_permission: 'リソース操作の実行権限が未設定です。サーバー管理者に設定を確認してください。', core_protected: 'Coreはサーバーコンソールで管理してください。', forbidden: '管理者権限がありません。', busy: '別の操作が処理中です。少し待ってから更新してください。', operation_failed: '操作に失敗しました。サーバーログを確認してください。', invalid_state: '状態が変わりました。更新して再度操作してください。' };
                throw new Error(errors[result.error] || '操作できませんでした。権限とアイテムの所持を確認してください。');
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
        resetCharts();
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
        if (data?.action === 'progress:theme') applyProgressTheme(data.theme);
        if (data?.action === 'tablet:open') setVisible(true);
        if (data?.action === 'tablet:close') setVisible(false);
    });
    window.addEventListener('keydown', (event) => {
        if (!opened) return;
        if (event.key === 'Escape') { event.preventDefault(); close(); }
        if (event.key === 'Tab') {
            const buttons = [...tablet.querySelectorAll('button:not(:disabled), input:not(:disabled), select:not(:disabled)')].filter((button) => !button.closest('[hidden]'));
            const first = buttons[0], last = buttons[buttons.length - 1];
            if (event.shiftKey && document.activeElement === first) { event.preventDefault(); last.focus(); }
            else if (!event.shiftKey && document.activeElement === last) { event.preventDefault(); first.focus(); }
        }
    });
    document.querySelectorAll('[data-page]').forEach((button) => button.addEventListener('click', () => selectPage(button.dataset.page)));
    element('refresh').addEventListener('click', () => { status(''); refreshResources(); });
    element('home-button').addEventListener('click', close);
    element('chart-search').addEventListener('submit', searchCharts);
    element('chart-history').addEventListener('change', showChart);
    element('progress-theme').addEventListener('change', async (event) => {
        const select = event.currentTarget;
        const version = request;
        select.disabled = true;
        try {
            const result = preview ? { ok: true, theme: select.value } : await post('tabletProgressTheme', { theme: select.value });
            if (!result.ok) throw new Error('save_failed');
            applyProgressTheme(result.theme);
            if (version === request) element('progress-status').textContent = preview ? 'プレビュー' : '色テーマを保存しました。';
        } catch {
            select.value = progressTheme;
            if (version === request) element('progress-status').textContent = '色テーマを保存できませんでした。';
        } finally {
            select.disabled = false;
        }
    });
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
