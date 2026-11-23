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
    let openGeneration;
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

    function closeNotifications() {
        element('notifications').hidden = true;
        element('notifications-toggle').setAttribute('aria-expanded', 'false');
    }
    element('notifications-toggle').addEventListener('click', () => {
        const expanded = element('notifications').hidden;
        element('notifications').hidden = !expanded;
        element('notifications-toggle').setAttribute('aria-expanded', String(expanded));
    });
    document.addEventListener('pointerdown', event => {
        if (!event.target.closest('.tablet-topbar')) closeNotifications();
    });
    element('notice-list-toggle').addEventListener('click', () => openNotice());
    element('home-notices-empty').addEventListener('click', () => openNotice());

    let page = 'home';
    let chartRequest = 0;
    let charts = [];
    let chartTargetId;
    let chartPatients = [];
    const patientChoice = patient => patient.name + '（ID ' + patient.id + '）';
    const normalizePatient = value => value.normalize('NFKC').toLowerCase().replace(/\s/g, '');
    const chartParts = { head: '頭部', upper_body: '上半身', lower_body: '下半身', left_arm: '左腕', right_arm: '右腕', left_leg: '左脚', right_leg: '右脚' };
    const injuryKinds = { blunt: '打ち身', bruise: '打撲', cut: '切り傷', burn: '火傷', fracture: '骨折', bleeding: '出血', shot: '銃創', stabbed: '刺創', beat: '打撲', burned: '火傷', pin: '通電ピン' };
    const injuryLevels = ['なし', '軽度', '中等度', '高度', '最重度'];

    function clearChartResults() {
        charts = [];
        chartTargetId = undefined;
        element('chart-results').hidden = true;
        element('chart-patient').textContent = '';
        element('chart-history').replaceChildren();
        element('chart-condition').textContent = '';
        element('chart-injuries').replaceChildren();
    }
    function resetCharts() {
        chartRequest++;
        clearChartResults();
        chartPatients = [];
        element('chart-patients').replaceChildren();
        element('chart-search').reset();
        element('chart-submit').disabled = false;
        element('chart-status').textContent = '患者名またはサーバーIDを入力してください。';
    }
    function showChart() {
        const chart = charts[element('chart-history').selectedIndex];
        if (!chart) return;
        element('chart-condition').textContent = [chart.death, chart.deathCause, chart.observationStatus].filter(Boolean).join(' ／ ') || '状態の記録なし';
        const billing = chart.invoiceId ? '請求済' : '未請求';
        const amount = chart.invoiceTotal;
        element('chart-billing').textContent = billing + (Number.isFinite(amount) ? ' ／ ￥' + amount.toLocaleString('ja-JP') : '');
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
        const query = normalizePatient(element('chart-patient-id').value);
        let targetId = /^\d+$/.test(query) ? Number(query) : undefined;
        if (query && targetId === undefined) {
            const selected = chartPatients.find(patient => normalizePatient(patientChoice(patient)) === query);
            const matches = selected ? [selected] : chartPatients.filter(patient => normalizePatient(patient.name).includes(query));
            if (matches.length > 1) {
                element('chart-status').textContent = '該当する患者が複数います。候補から選んでください。';
                return;
            }
            targetId = matches[0]?.id;
        }
        if (!Number.isSafeInteger(targetId) || targetId <= 0) {
            element('chart-status').textContent = '接続中の患者名またはサーバーIDを入力してください。';
            return;
        }
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
            chartTargetId = targetId;
            element('chart-open').disabled = false;
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
    async function openSelectedChart() {
        const button = element('chart-open');
        const chart = charts[element('chart-history').selectedIndex];
        if (!opened || page !== 'charts' || button.disabled || !chart?.chartId) return;
        button.disabled = true;
        const version = chartRequest;
        try {
            const result = await post('tabletOpenChart', { targetId: chartTargetId, chartId: chart.chartId });
            if (!result.ok) throw new Error(result.error || 'カルテを開けませんでした。');
        } catch (error) {
            if (version === chartRequest) element('chart-status').textContent = error.message || 'カルテを開けませんでした。';
        } finally {
            if (version === chartRequest) button.disabled = false;
        }
    }
    async function openChartPage() {
        selectPage('charts');
        if (preview || !opened) return;
        const version = request;
        try {
            const result = await post('tabletChartPatients');
            if (!opened || page !== 'charts' || version !== request) return;
            if (result.error) throw new Error(result.error);
            chartPatients = Array.isArray(result.patients) ? result.patients : [];
            element('chart-patients').replaceChildren(...chartPatients.map(patient => new Option(patientChoice(patient))));
        } catch (error) {
            if (opened && page === 'charts' && version === request) element('chart-status').textContent = error.message;
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
    if (!preview) console.info('[mediora shop] ui build=20261111-catalog-1');
    const shopCart = new Map();
    let shopItems = [];
    let shopLimit = 0;
    let shopKey;
    let shopBusy = false;
    const shopStatus = (message) => { element('shop-status').textContent = message; };
    const shopMoney = (amount) => '$' + Number(amount).toLocaleString('ja-JP');
    const shopTotal = () => shopItems.reduce((sum, item) => sum + item.price * (shopCart.get(item.id) || 0), 0);
    const shopQuantity = () => [...shopCart.values()].reduce((sum, count) => sum + count, 0);
    const shopList = value => value && typeof value === 'object' ? Object.values(value).filter(entry => entry && typeof entry === 'object') : [];

    let shopDrag;
    const shopDropzone = element('shop-dropzone');

    function updateShopQuantity(id, count) {
        if (shopBusy || !shopItems.some(item => item.id === id && item.available !== false)) return;
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

    function shopItemImage(item) {
        const image = document.createElement('img');
        image.alt = '';
        image.draggable = false;
        const filename = item.image || item.id + '.png';
        const directory = ['pmediora_supplybox.png', 'pmediora_specialbox.png'].includes(filename)
            ? 'ptech_mediora_logistics/install/images/'
            : 'ptech_mediora_medical/install/ox_inventory/images/';
        image.src = filename.startsWith('https://') ? filename
            : 'https://raw.githubusercontent.com/Peridoll/P-Tech-Mediora/refs/heads/feature/dev/resources/%5Bptech%5D/%5Bmediora%5D/' + directory + encodeURIComponent(filename);
        image.addEventListener('error', () => { image.style.visibility = 'hidden'; });
        return image;
    }

    const shopSearch = element('shop-search');

    function filterShopCatalog() {
        const query = shopSearch.value.normalize('NFKC').trim().toLowerCase();
        let count = 0;
        for (const card of element('shop-items').children) {
            card.hidden = !card.dataset.search.includes(query);
            if (!card.hidden) count++;
        }
        element('shop-results').textContent = count + '件';
        element('shop-no-results').hidden = !query || count > 0;
    }

    shopSearch.addEventListener('input', filterShopCatalog);

    function renderShop() {
        if (shopDrag) clearShopDrag();
        const catalog = element('shop-items');
        const cart = element('shop-cart');
        catalog.replaceChildren();
        cart.replaceChildren();
        const quantity = shopQuantity();
        for (const item of shopItems) {
            const card = document.createElement('article');
            card.dataset.search = [item.label, item.description, item.treatment].join(' ').normalize('NFKC').toLowerCase();
            const canAdd = item.available !== false && !shopBusy && quantity < shopLimit;
            card.classList.toggle('shop-draggable', canAdd);
            card.addEventListener('mousedown', event => {
                if (!canAdd || shopBusy || event.button !== 0 || event.target.closest('button')) return;
                event.preventDefault();
                clearShopDrag();
                shopDrag = { x: event.clientX, y: event.clientY, item };
            });

            const image = shopItemImage(item);
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
            owned.dataset.itemId = item.id;
            owned.textContent = '所持 ' + Number(item.owned ?? 0).toLocaleString('ja-JP') + '個';
            const add = document.createElement('button');
            add.type = 'button';
            add.textContent = item.available === false ? '取扱準備中' : '＋ カートに入れる';
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
            row.append(shopItemImage(item), cartDetail, actions);
            cart.append(row);
        }
        element('shop-empty').hidden = cart.childElementCount > 0;
        filterShopCatalog();
        element('shop-count').textContent = quantity + '点';
        element('shop-total').textContent = shopMoney(shopTotal());
        element('shop-place').disabled = shopBusy || shopTotal() <= 0 || quantity > shopLimit;
    }

    function clearShopDrag() {
        shopDrag?.ghost?.remove();
        shopDrag = undefined;
        shopDropzone.classList.remove('shop-drag-over');
    }

    function overShopCart(event) {
        const target = document.elementFromPoint(event.clientX, event.clientY);
        return target !== null && shopDropzone.contains(target);
    }

    document.addEventListener('mousemove', event => {
        if (!shopDrag) return;
        if (!shopDrag.ghost) {
            if (Math.hypot(event.clientX - shopDrag.x, event.clientY - shopDrag.y) < 5) return;
            const ghost = document.createElement('div');
            ghost.className = 'shop-drag-ghost';
            ghost.setAttribute('aria-hidden', 'true');
            ghost.append(shopItemImage(shopDrag.item), document.createTextNode(shopDrag.item.label));
            tablet.append(ghost);
            shopDrag.ghost = ghost;
        }
        shopDrag.ghost.style.left = (event.clientX + 12) + 'px';
        shopDrag.ghost.style.top = (event.clientY + 12) + 'px';
        shopDropzone.classList.toggle('shop-drag-over', overShopCart(event));
    });
    document.addEventListener('mouseup', event => {
        if (!shopDrag) return;
        const id = shopDrag.item.id;
        const moved = Math.hypot(event.clientX - shopDrag.x, event.clientY - shopDrag.y) >= 5;
        const dropped = event.button === 0 && moved && overShopCart(event);
        clearShopDrag();
        if (dropped) updateShopQuantity(id, (shopCart.get(id) || 0) + 1);
    });
    document.addEventListener('mouseleave', clearShopDrag);
    window.addEventListener('blur', clearShopDrag);

    async function loadShop(message = '') {
        const version = request;
        shopStatus(message || '商品を読み込んでいます…');
        try {
            const result = await post('tabletShopCatalog');
            if (!opened || version !== request || page !== 'shop') return;
            if (!result.ok) throw new Error(result.error || 'ストアを開けませんでした。');
            shopItems = shopList(result.items);
            shopLimit = result.limit;
            for (const id of shopCart.keys()) {
                if (!shopItems.some(item => item.id === id && item.available !== false)) shopCart.delete(id);
            }
            const labels = {
                waiting: 'ピルボックスで受取待ち', handed_over: 'ピルボックスの受取ロッカー',
                refund_due: '返金待ち', refunded: '返金済み', declined: '決済不成立',
                paying: '決済確認中', refunding: '返金確認中', handing_over: '受取準備中',
            };
            const history = element('shop-orders');
            history.replaceChildren();
            const orders = shopList(result.orders);
            if (!orders.length) history.textContent = result.historyUnavailable ? '注文履歴を取得できませんでした。' : '注文はまだありません。';
            for (const order of orders) {
                const entry = document.createElement('li');
                const title = document.createElement('strong');
                title.textContent = '#' + order.id + ' · ' + labels[order.status] + ' · ' + shopMoney(order.total);
                const detail = document.createElement('p');
                detail.textContent = shopList(order.items).map(item => item.label + ' × ' + item.count).join('、');
                if (order.status === 'waiting') {
                    detail.textContent += ' / 受取期限 ' + new Date(order.expiresAt * 1000).toLocaleString('ja-JP');
                }
                entry.append(title, detail);
                history.append(entry);
            }
            shopStatus(message || (!shopItems.length ? '販売商品が設定されていません。' : ''));
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
        try {
            if (!shopKey) {
                const words = new Uint32Array(4);
                if (globalThis.crypto?.getRandomValues) globalThis.crypto.getRandomValues(words);
                else for (let i = 0; i < words.length; i++) words[i] = Math.floor(Math.random() * 0x100000000);
                shopKey = Array.from(words, number => number.toString(16).padStart(8, '0')).join('');
            }
            renderShop();
            shopStatus('決済を処理しています…');
            const result = await post('tabletShopPlace', { key: shopKey, cart: Object.fromEntries(shopCart), total: shopTotal() });
            if (!opened || version !== request) return;
            if (!result.ok) {
                if (result.retryWithNewKey === true) shopKey = undefined;
                throw new Error(result.error || '注文できませんでした。');
            }
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


    let announcementRevision = 0;
    let editorRevision = 0;
    let homeCanEdit = false;
    let announcementSaving = false;
    let editingAnnouncementId;
    let announcements = [];
    let activeAnnouncementId;
    let pendingNoticeNew = false;
    function announcementMeta(announcement) {
        return [announcement.author, announcement.updatedAt ? new Date(announcement.updatedAt * 1000).toLocaleString('ja-JP') : ''].filter(Boolean).join(' ／ ');
    }
    function openNotice(id, create = false) {
        selectPage('notices');
        activeAnnouncementId = id;
        pendingNoticeNew = create;
        element('notice-page-heading').focus({ preventScroll: true });
    }
    function resetAnnouncementEditor() {
        resetNoticeDeletion();
        element('notice-editor').hidden = true;
        element('notice-layout').hidden = false;
        element('notice-form').reset();
        element('notice-editor-status').textContent = '';
        editingAnnouncementId = undefined;
    }
    function editAnnouncement(announcement) {
        if (page !== 'notices' || !homeCanEdit || announcementSaving) return;
        editingAnnouncementId = announcement?.id;
        editorRevision = announcementRevision;
        element('notice-editor-title').textContent = announcement ? 'お知らせを編集' : 'お知らせを投稿';
        element('notice-title').value = announcement?.title || '';
        element('notice-body').value = announcement?.body || '';
        element('notice-editor-status').textContent = '';
        element('notice-layout').hidden = true;
        element('notice-editor').hidden = false;
        element('notice-title').focus();
    }
    function renderNoticePage() {
        const list = element('notice-page-list');
        list.replaceChildren();
        const current = announcements.find(item => item.id === activeAnnouncementId) || announcements[0];
        activeAnnouncementId = current?.id;
        for (const announcement of announcements) {
            const row = document.createElement('li');
            const button = document.createElement('button');
            button.type = 'button';
            button.className = 'tablet-notice-list-item';
            button.setAttribute('aria-current', announcement === current ? 'true' : 'false');
            const title = document.createElement('strong');
            title.textContent = announcement.title;
            const meta = document.createElement('small');
            meta.textContent = announcementMeta(announcement);
            button.append(title, meta);
            button.addEventListener('click', () => {
                if (announcementSaving) return;
                activeAnnouncementId = announcement.id;
                resetAnnouncementEditor();
                renderNoticePage();
                element('notice-detail-title').focus({ preventScroll: true });
            });
            row.append(button);
            list.append(row);
        }
        element('notice-page-empty').hidden = !!current;
        element('notice-detail').hidden = !current;
        element('notice-detail-title').textContent = current?.title || '';
        element('notice-detail-body').textContent = current?.body || '';
        element('notice-detail-meta').textContent = current ? announcementMeta(current) : '';
        element('notice-detail-edit').hidden = !homeCanEdit || !current;
        element('notice-detail-delete').hidden = !homeCanEdit || !current;
        element('notice-page-new').hidden = !homeCanEdit;
    }
    let pendingAnnouncementDelete;
    function resetNoticeDeletion() {
        pendingAnnouncementDelete = undefined;
        element('notice-delete-confirm').hidden = true;
        element('notice-delete-text').textContent = '';
    }
    element('notice-detail-delete').addEventListener('click', () => {
        if (!opened || page !== 'notices' || !homeCanEdit || announcementSaving) return;
        const current = announcements.find(item => item.id === activeAnnouncementId);
        if (!current) return;
        pendingAnnouncementDelete = { id: current.id, revision: announcementRevision, version: homeRequest };
        element('notice-delete-text').textContent = '「' + current.title + '」を削除しますか？ 削除したお知らせは元に戻せません。';
        element('notice-delete-confirm').hidden = false;
        element('notice-delete-cancel').focus();
    });
    element('notice-delete-cancel').addEventListener('click', () => {
        if (announcementSaving) return;
        resetNoticeDeletion();
        element('notice-detail-delete').focus();
    });
    element('notice-delete-accept').addEventListener('click', async () => {
        const deletion = pendingAnnouncementDelete;
        if (!opened || page !== 'notices' || !homeCanEdit || announcementSaving || !deletion
            || deletion.version !== homeRequest) return;
        const version = homeRequest;
        announcementSaving = true;
        for (const id of ['notice-delete-accept', 'notice-delete-cancel', 'notice-detail-delete']) element(id).disabled = true;
        element('notice-page-status').textContent = '削除しています…';
        try {
            const result = await post('tabletAnnouncementDelete', { id: deletion.id, revision: deletion.revision });
            if (!opened || page !== 'notices' || version !== homeRequest) return;
            if (!result.ok) throw new Error(result.error || '削除できませんでした。');
            announcements = announcements.filter(item => item.id !== deletion.id);
            activeAnnouncementId = undefined;
            resetNoticeDeletion();
            renderNoticePage();
            await loadHome();
        } catch (error) {
            if (opened && page === 'notices' && version === homeRequest) {
                element('notice-page-status').textContent = error.message || '削除結果を確認できませんでした。更新して確認してください。';
            }
        } finally {
            announcementSaving = false;
            for (const id of ['notice-delete-accept', 'notice-delete-cancel', 'notice-detail-delete']) element(id).disabled = false;
        }
    });
    element('notice-new').addEventListener('click', () => openNotice(undefined, true));
    element('notice-page-new').addEventListener('click', () => editAnnouncement());
    element('notice-detail-edit').addEventListener('click', () => editAnnouncement(announcements.find(item => item.id === activeAnnouncementId)));
    element('notice-cancel').addEventListener('click', () => {
        resetAnnouncementEditor();
        element(homeCanEdit && activeAnnouncementId !== undefined ? 'notice-detail-edit' : 'notice-page-heading').focus();
    });
    function refreshAnnouncements() {
        if (announcementSaving) return;
        pendingNoticeNew = false;
        resetAnnouncementEditor();
        loadHome();
    }
    element('home-refresh').addEventListener('click', refreshAnnouncements);
    element('notice-page-refresh').addEventListener('click', refreshAnnouncements);
    element('notice-form').addEventListener('submit', async event => {
        event.preventDefault();
        if (!opened || page !== 'notices' || !homeCanEdit || announcementSaving) return;
        const version = homeRequest;
        const payload = {
            id: editingAnnouncementId, revision: editorRevision,
            title: element('notice-title').value.trim(), body: element('notice-body').value.trim(),
        };
        announcementSaving = true;
        element('notice-save').disabled = true;
        element('notice-cancel').disabled = true;
        element('notice-editor-status').textContent = '保存しています…';
        try {
            const result = await post('tabletAnnouncementSave', payload);
            if (!opened || page !== 'notices' || version !== homeRequest) return;
            if (!result.ok) throw new Error(result.error || '保存できませんでした。');
            activeAnnouncementId = payload.id;
            resetAnnouncementEditor();
            await loadHome();
        } catch (error) {
            if (opened && page === 'notices' && version === homeRequest) {
                element('notice-editor-status').textContent = error.message || '保存結果を確認できませんでした。更新して確認してください。';
            }
        } finally {
            announcementSaving = false;
            element('notice-save').disabled = false;
            element('notice-cancel').disabled = false;
        }
    });

    let homeRequest = 0;
    function resetHome() {
        homeRequest++;
        homeCanEdit = false;
        announcements = [];
        activeAnnouncementId = undefined;
        pendingNoticeNew = false;
        element('notice-new').hidden = true;
        element('notice-page-new').hidden = true;
        resetAnnouncementEditor();
        element('notice-list-toggle').hidden = true;
        element('home-overview').hidden = true;
        element('home-notices').replaceChildren();
        element('notice-page-list').replaceChildren();
        element('notice-detail').hidden = true;
        element('notice-page-empty').hidden = true;
        element('home-status').textContent = '';
        element('notice-page-status').textContent = '';
    }
    async function loadHome() {
        const version = ++homeRequest;
        const isCurrent = () => opened && ['home', 'notices'].includes(page) && version === homeRequest;
        const notice = element(page === 'notices' ? 'notice-page-status' : 'home-status');
        notice.textContent = 'お知らせを確認しています…';
        try {
            const result = preview ? { ok: true, announcements: [] } : await post('tabletHome');
            if (!isCurrent()) return;
            if (!result.ok) throw new Error(result.error || 'お知らせを取得できませんでした。');
            notice.textContent = '';
            announcementRevision = result.announcementRevision;
            homeCanEdit = result.canEditAnnouncements === true;
            announcements = Array.isArray(result.announcements) ? result.announcements : [];
            element('notice-new').hidden = !homeCanEdit;
            const notices = element('home-notices');
            notices.replaceChildren();
            for (const announcement of announcements.slice(0, 1)) {
                const entry = document.createElement('button');
                entry.type = 'button';
                entry.className = 'tablet-notice-card';
                const title = document.createElement('strong');
                title.className = 'tablet-notice-card-title';
                title.textContent = announcement.title;
                const excerpt = document.createElement('span');
                excerpt.className = 'tablet-notice-card-excerpt';
                const body = String(announcement.body || '');
                excerpt.textContent = body.length > 100 ? body.slice(0, 100) + '…' : body;
                const meta = document.createElement('small');
                meta.className = 'tablet-notice-meta';
                meta.textContent = announcementMeta(announcement);
                const link = document.createElement('span');
                link.className = 'tablet-notice-card-link';
                link.textContent = '詳しく見る →';
                entry.append(title, excerpt, meta, link);
                entry.addEventListener('click', () => openNotice(announcement.id));
                notices.append(entry);
            }
            element('home-notices-empty').textContent = result.announcementError || '掲載中のお知らせはありません。';
            element('home-notices-empty').hidden = notices.childElementCount > 0;
            element('notice-list-toggle').hidden = false;
            element('home-overview').hidden = false;
            element('notice-page-empty').textContent = result.announcementError || '掲載中のお知らせはありません。';
            renderNoticePage();
            if (page === 'notices' && pendingNoticeNew) {
                pendingNoticeNew = false;
                editAnnouncement();
            }
        } catch (error) {
            if (!isCurrent()) return;
            notice.textContent = error.message || 'お知らせを取得できませんでした。';
        }
    }

    let canManagePersonnel = false;
    let personnelRequest = 0;
    let personnelAction;

    function resetPersonnel() {
        personnelRequest++;
        personnelAction = undefined;
        element('personnel-confirm').hidden = true;
        element('personnel-content').hidden = true;
        element('personnel-list').replaceChildren();
        element('personnel-candidate').replaceChildren();
        element('personnel-hire-grade').replaceChildren();
        element('personnel-status').textContent = '';
        element('personnel-refresh').disabled = false;
    }

    const personnelActions = { hire: '採用', grade: '階級変更', dismiss: '解雇' };
    function confirmPersonnel(action, target, level, gradeName) {
        personnelAction = {
            action, id: target.id, source: target.source, currentLevel: target.level, level,
        };
        const description = gradeName ? target.name + ' ／ ' + gradeName : target.name;
        element('personnel-confirm-text').textContent = description + ' の' + personnelActions[action] + 'を実行しますか？';
        element('personnel-confirm').hidden = false;
        element('personnel-cancel').focus();
        element('personnel-confirm').scrollIntoView({ block: 'nearest' });
    }

    function personnelOptions(select, grades, selected) {
        select.replaceChildren();
        for (const grade of grades) {
            const option = document.createElement('option');
            option.value = grade.level;
            option.textContent = grade.name;
            select.append(option);
        }
        if (selected !== undefined) select.value = String(selected);
    }

    function renderPersonnel(result) {
        const grades = Array.isArray(result.grades) ? result.grades : [];
        const members = Array.isArray(result.members) ? result.members : [];
        const candidates = Array.isArray(result.candidates) ? result.candidates : [];
        const list = element('personnel-list');
        element('personnel-empty').hidden = members.length > 0;
        for (const member of members) {
            const row = document.createElement('li');
            const name = document.createElement('strong');
            const summary = document.createElement('small');
            name.textContent = member.name;
            summary.textContent = member.grade + ' ／ ' + member.state;
            row.append(name, summary);
            if (member.editable && grades.length) {
                const actions = document.createElement('div');
                actions.className = 'personnel-actions';
                const select = document.createElement('select');
                select.setAttribute('aria-label', member.name + 'の階級');
                personnelOptions(select, grades, member.level);
                const save = document.createElement('button');
                save.type = 'button';
                save.textContent = '変更';
                save.disabled = true;
                select.addEventListener('change', () => { save.disabled = Number(select.value) === member.level; });
                save.addEventListener('click', () => confirmPersonnel('grade', member, Number(select.value), select.selectedOptions[0].textContent));
                const dismiss = document.createElement('button');
                dismiss.type = 'button';
                dismiss.textContent = '解雇';
                dismiss.className = 'personnel-danger';
                dismiss.addEventListener('click', () => confirmPersonnel('dismiss', member));
                actions.append(select, save, dismiss);
                row.append(actions);
            }
            list.append(row);
        }

        const candidate = element('personnel-candidate');
        const hireGrade = element('personnel-hire-grade');
        const placeholder = document.createElement('option');
        placeholder.value = '';
        placeholder.textContent = candidates.length ? 'オンラインのプレイヤーを選択' : '採用できるプレイヤーがいません';
        candidate.append(placeholder);
        for (const person of candidates) {
            const option = document.createElement('option');
            option.value = person.id;
            option.textContent = person.name + '（ID ' + person.source + '）';
            candidate.append(option);
        }
        personnelOptions(hireGrade, grades);
        const hire = element('personnel-hire');
        hire.disabled = true;
        candidate.onchange = () => { hire.disabled = !candidate.value || !grades.length; };
        hire.onclick = () => {
            const target = candidates.find(person => person.id === candidate.value);
            if (target && hireGrade.selectedOptions.length) {
                confirmPersonnel('hire', target, Number(hireGrade.value), hireGrade.selectedOptions[0].textContent);
            }
        };
        element('personnel-content').hidden = false;
    }

    async function loadPersonnel(message = '') {
        resetPersonnel();
        const version = personnelRequest;
        const notice = element('personnel-status');
        element('personnel-refresh').disabled = true;
        notice.textContent = message || '隊員名簿を読み込んでいます…';
        try {
            const result = await post('tabletPersonnel');
            if (version !== personnelRequest) return;
            if (!result.ok) throw new Error(result.error);
            renderPersonnel(result);
            notice.textContent = message;
        } catch (error) {
            if (version === personnelRequest) notice.textContent = error.message || '隊員名簿を取得できませんでした。';
        } finally {
            if (version === personnelRequest) element('personnel-refresh').disabled = false;
        }
    }

    element('personnel-back').addEventListener('click', () => selectPage('home'));
    element('personnel-refresh').addEventListener('click', () => loadPersonnel());
    element('personnel-cancel').addEventListener('click', () => {
        personnelAction = undefined;
        element('personnel-confirm').hidden = true;
    });
    element('personnel-submit').addEventListener('click', async () => {
        if (!opened || page !== 'personnel' || !personnelAction) return;
        const action = personnelAction;
        resetPersonnel();
        const version = personnelRequest;
        element('personnel-refresh').disabled = true;
        element('personnel-status').textContent = '変更を保存しています…';
        let message;
        try {
            const result = await post('tabletPersonnelAction', action);
            message = result.ok ? personnelActions[action.action] + 'を反映しました。' : result.error;
        } catch {
            message = '変更結果を確認できませんでした。一覧で確認してください。';
        }
        if (version === personnelRequest) loadPersonnel(message);
    });


    const townUrl = 'https://peridoll.github.io/NOVILL-TOWN/';
    const townFrame = element('town-frame');
    const townStatus = element('town-status');
    function resetTown() {
        townFrame.removeAttribute('src');
        townStatus.textContent = '';
    }
    function loadTown() {
        townStatus.textContent = '読み込み中…';
        townFrame.src = townUrl;
    }
    townFrame.addEventListener('load', () => {
        if (opened && page === 'town' && townFrame.getAttribute('src') === townUrl) townStatus.textContent = '';
    });
    element('town-reload').addEventListener('click', loadTown);


    const menuSidebar = document.querySelector('.tablet-sidebar');
    const menuIndicator = element('selection-indicator');
    let menuAnimation;
    function moveMenuIndicator(animate = true) {
        const selected = menuSidebar.querySelector('button.selected');
        if (!opened || !selected || selected.hidden) {
            menuAnimation?.cancel();
            menuAnimation = undefined;
            menuIndicator.hidden = true;
            return;
        }
        const wasVisible = !menuIndicator.hidden;
        menuIndicator.hidden = false;
        menuIndicator.style.height = selected.getBoundingClientRect().height + 'px';
        const sidebarBounds = menuSidebar.getBoundingClientRect();
        const targetY = selected.getBoundingClientRect().top - sidebarBounds.top + menuSidebar.scrollTop;
        const currentY = wasVisible
            ? menuIndicator.getBoundingClientRect().top - sidebarBounds.top + menuSidebar.scrollTop : targetY;
        menuAnimation?.cancel();
        menuAnimation = undefined;
        const transform = y => 'translateX(-50%) translateY(' + y + 'px)';
        menuIndicator.style.transform = transform(targetY);
        if (!animate || !wasVisible || Math.abs(targetY - currentY) < .5 || matchMedia('(prefers-reduced-motion: reduce)').matches) return;
        const direction = Math.sign(targetY - currentY) || 1;
        const effect = menuIndicator.animate([
            { transform: transform(currentY), filter: 'blur(0px)', offset: 0 },
            { transform: transform(currentY - direction * 4), filter: 'blur(.3px)', offset: .12, easing: 'cubic-bezier(.2,.7,.25,1)' },
            { transform: transform(targetY + direction * 11), filter: 'blur(2.4px)', offset: .66, easing: 'cubic-bezier(.45,0,.85,.4)' },
            { transform: transform(targetY - direction * 3), filter: 'blur(.5px)', offset: .86, easing: 'cubic-bezier(.2,.8,.25,1)' },
            { transform: transform(targetY), filter: 'blur(0px)', offset: 1 },
        ], { duration: 390, fill: 'both', easing: 'cubic-bezier(.2,.8,.2,1)' });
        menuAnimation = effect;
        effect.onfinish = () => {
            if (menuAnimation !== effect) return;
            menuAnimation = undefined;
            effect.cancel();
            moveMenuIndicator(false);
        };
    }
    const menuObserver = new ResizeObserver(() => {
        if (!menuAnimation) moveMenuIndicator(false);
    });
    menuObserver.observe(menuSidebar);
    menuObserver.observe(document.querySelector('.tablet-navigation'));
    menuSidebar.addEventListener('scroll', () => {
        if (!menuAnimation) moveMenuIndicator(false);
    });
    window.addEventListener('resize', () => moveMenuIndicator(false));

    let noticeTransition;
    function animateNoticePage(entering = false) {
        noticeTransition?.cancel();
        noticeTransition = undefined;
        if (!entering || !opened || matchMedia('(prefers-reduced-motion: reduce)').matches) return;
        const effect = element('notices').animate([
            { opacity: 0, transform: 'translateY(14px)' },
            { opacity: 1, transform: 'translateY(0)' },
        ], { duration: 300, easing: 'cubic-bezier(.2,.8,.2,1)' });
        noticeTransition = effect;
        effect.onfinish = () => {
            if (noticeTransition !== effect) return;
            noticeTransition = undefined;
            effect.cancel();
        };
    }

    function selectPage(next) {
        if (next !== 'shop' && shopDrag) clearShopDrag();
        if (!['home', 'notices', 'charts', 'incidents', 'expenses', 'shop', 'town', 'personnel', 'settings', 'resources'].includes(next)) return;
        if (next === 'resources' && !isAdmin) return;
        if (next === 'personnel' && !canManagePersonnel) return;
        closeNotifications();
        if (page === 'personnel' && next !== page) resetPersonnel();
        if (page === 'town' && next !== page) resetTown();
        if (next !== page && (page === 'charts' || next === 'charts')) resetCharts();
        if (['home', 'notices'].includes(page) || ['home', 'notices'].includes(next)) resetHome();
        if (next === 'shop' && page !== 'shop') shopSearch.value = '';
        const openingNotices = next === 'notices' && page !== 'notices';
        page = next;
        for (const id of ['home', 'notices', 'charts', 'incidents', 'expenses', 'shop', 'town', 'personnel', 'settings', 'resources']) element(id).hidden = id !== page;
        animateNoticePage(openingNotices);
        element('admin-link').hidden = !isAdmin;
        document.querySelectorAll('.tablet-sidebar [data-page]').forEach((button) => {
            const selected = button.dataset.page === page;
            const parent = (page === 'resources' && button.dataset.page === 'settings')
                || (['town', 'notices'].includes(page) && button.dataset.page === 'home');
            button.classList.toggle('selected', selected || parent);
            button.setAttribute('aria-current', selected ? 'page' : parent ? 'location' : 'false');
        });
        moveMenuIndicator();
        if (page === 'home' || page === 'notices') loadHome();
        if (page === 'town') loadTown();
        if (page === 'shop') loadShop();
        if (page === 'personnel') loadPersonnel();
        if (page === 'resources') refreshResources();
        if (page === 'settings') loadAccess(request);
    }
    const rescueForm = element('rescue-settings');
    const rescueGroups = ['pd', 'other'];
    rescueForm.addEventListener('submit', async event => {
        event.preventDefault();
        const save = element('rescue-save');
        if (!opened || page !== 'settings' || !isAdmin || save.disabled || !rescueForm.reportValidity()) return;
        const version = request;
        const settings = Object.fromEntries(rescueGroups.map(group => [group, {
            enabled: element('rescue-' + group + '-enabled').checked,
            minutes: element('rescue-' + group + '-minutes').valueAsNumber,
        }]));
        save.disabled = true;
        try {
            const result = await post('tabletRescueSave', settings);
            if (opened && request === version) {
                element('rescue-status').textContent = result?.ok ? '保存しました。' : '設定を保存できませんでした。';
                if (result?.error === 'forbidden') rescueForm.hidden = true;
            }
        } catch {
            if (opened && request === version) element('rescue-status').textContent = '設定を保存できませんでした。';
        } finally {
            save.disabled = false;
        }
    });
    async function loadAccess(version) {
        rescueForm.hidden = true;
        try {
            const result = preview ? { ok: true, admin: false } : await post('tabletAccess');
            if (!opened || version !== request) return;
            if (!result.ok) throw new Error(result.error || 'unavailable');
            isAdmin = result.admin === true;
            if (page === 'settings' && isAdmin && result.rescue) {
                for (const group of rescueGroups) {
                    element('rescue-' + group + '-enabled').checked = result.rescue[group].enabled;
                    element('rescue-' + group + '-minutes').value = result.rescue[group].minutes;
                }
                element('rescue-status').textContent = '';
                rescueForm.hidden = false;
            }
            element('profile-name').textContent = result.profile?.name || '—';
            element('profile-role').textContent = result.profile?.role || '—';
            canManagePersonnel = result.personnel === true;
            element('personnel-link').hidden = !canManagePersonnel;
            element('admin-link').hidden = !isAdmin;
        } catch {
            if (opened && version === request) {
                isAdmin = false;
                canManagePersonnel = false;
                element('personnel-link').hidden = true;
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
        if (!visible) clearShopDrag();
        opened = visible;
        if (!visible) moveMenuIndicator(false);
        closeNotifications();
        element('profile-name').textContent = '—';
        element('profile-role').textContent = '—';
        animateTablet(visible);
        const version = ++request;
        resetCharts();
        if (!visible) { animateNoticePage(); resetHome(); resetTown(); }
        busy = false;
        operating = false;
        element('resource-status').dataset.phase = '';
        isAdmin = false;
        canManagePersonnel = false;
        element('personnel-link').hidden = true;
        resetPersonnel();
        element('admin-link').hidden = true;
        element('refresh').disabled = false;
        element('resource-list').replaceChildren();
        status('');
        if (visible) { selectPage('home'); document.querySelector('[data-page="home"]').focus(); loadAccess(version); }
    }
    async function close() {
        if (!opened) return;
        if (preview) { setVisible(false); return; }
        const generation = openGeneration;
        try { await post('tabletClose', { generation }); }
        catch {
            if (opened && openGeneration === generation) {
                status('閉じられませんでした。Esc またはホームボタンでもう一度お試しください。');
            }
        }
    }
    window.addEventListener('message', ({ data, source }) => {
        if (data?.action === 'shop:owned' && typeof data.id === 'string' && Number.isFinite(data.count) && data.count >= 0) {
            const item = shopItems.find(entry => entry.id === data.id);
            if (item) item.owned = data.count;
            for (const label of element('shop-items').querySelectorAll('.shop-owned')) {
                if (label.dataset.itemId === data.id) label.textContent = '所持 ' + data.count.toLocaleString('ja-JP') + '個';
            }
        }
        if (source && source !== window && source !== window.parent) return;
        if (data?.action === 'progress:theme') applyProgressTheme(data.theme);
        if (data?.action === 'tablet:open') {
            openGeneration = data.generation;
            setVisible(true);
            if (!preview) post('tabletOpened', { generation: openGeneration }).catch(console.error);
        }
        if (data?.action === 'tablet:close') setVisible(false);
    });
    window.addEventListener('keydown', (event) => {
        if (!opened) return;
        if (event.key === 'Escape' && !element('notice-delete-confirm').hidden) {
            event.preventDefault();
            if (!announcementSaving) { resetNoticeDeletion(); element('notice-detail-delete').focus(); }
            return;
        }
        if ((event.key === 'ArrowUp' || event.key === 'ArrowDown')
            && !event.altKey && !event.ctrlKey && !event.metaKey && !event.shiftKey
            && !event.isComposing
            && !event.target?.closest?.('input, textarea, select, [contenteditable]:not([contenteditable="false"])')) {
            const menu = [...tablet.querySelectorAll('.tablet-sidebar button[data-page]:not(:disabled)')]
                .filter(button => !button.closest('[hidden]') && button.getClientRects().length > 0);
            if (menu.length) {
                event.preventDefault();
                if (event.repeat) return;
                const current = menu.findIndex(button => button.classList.contains('selected'));
                const direction = event.key === 'ArrowDown' ? 1 : -1;
                const index = current < 0 ? 0 : (current + direction + menu.length) % menu.length;
                const target = menu[index];
                target.focus({ preventScroll: true });
                const bounds = menuSidebar.getBoundingClientRect();
                const targetBounds = target.getBoundingClientRect();
                if (targetBounds.top < bounds.top) {
                    menuSidebar.scrollTop += targetBounds.top - bounds.top;
                } else if (targetBounds.bottom > bounds.bottom) {
                    menuSidebar.scrollTop += targetBounds.bottom - bounds.bottom;
                }
                target.click();
                return;
            }
        }
        if (event.key === 'Escape' && !element('notifications').hidden) {
            event.preventDefault();
            closeNotifications();
            element('notifications-toggle').focus();
            return;
        }
        if (event.key === 'Escape') { event.preventDefault(); close(); }
        if (event.key === 'Tab') {
            const buttons = [...tablet.querySelectorAll('button:not(:disabled), input:not(:disabled), select:not(:disabled)')].filter((button) => !button.closest('[hidden]'));
            const first = buttons[0], last = buttons[buttons.length - 1];
            if (event.shiftKey && document.activeElement === first) { event.preventDefault(); last.focus(); }
            else if (!event.shiftKey && document.activeElement === last) { event.preventDefault(); first.focus(); }
        }
    });
    document.querySelectorAll('[data-page]').forEach((button) => button.addEventListener('click', () => {
        if (button.dataset.page === 'charts') openChartPage();
        else selectPage(button.dataset.page);
    }));
    element('refresh').addEventListener('click', () => { status(''); refreshResources(); });
    element('home-button').addEventListener('click', close);
    element('chart-search').addEventListener('submit', searchCharts);
    element('chart-history').addEventListener('change', showChart);
    element('chart-open').addEventListener('click', openSelectedChart);
    element('move-panel').addEventListener('click', async () => {
        if (preview) {
            setVisible(false);
            window.postMessage({ action: 'panelPosition', editing: true, position: false, session: 0 }, '*');
            return;
        }
        try {
            const result = await post('tabletMoveActionPanel');
            if (!result.ok) throw new Error('位置調整を開始できませんでした。');
        } catch (error) { status(error.message); }
    });
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
