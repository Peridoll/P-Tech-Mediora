(() => {
    const element = (id) => document.getElementById(`tablet-${id}`);
    const tablet = document.getElementById('tablet');
    const preview = typeof GetParentResourceName !== 'function';
    let opened = false;
    let request = 0;
    let busy = false;
    const number = (value) => Number.isFinite(Number(value)) ? Number(value).toLocaleString('ja-JP') : '—';
    async function post(route) {
        const response = await fetch(`https://${GetParentResourceName()}/${route}`, {
            method: 'POST', headers: { 'Content-Type': 'application/json; charset=UTF-8' }, body: '{}',
            signal: AbortSignal.timeout(15000),
        });
        if (!response.ok) throw new Error('request_failed');
        return response.json();
    }
    function selectPage(page) {
        element('home').hidden = page !== 'home';
        element('profile').hidden = page !== 'profile';
        element('page-title').textContent = page === 'home' ? 'ホーム' : 'マイプロフィール';
        document.querySelectorAll('[data-page]').forEach((button) => {
            const selected = button.dataset.page === page;
            button.classList.toggle('selected', selected);
            button.setAttribute('aria-current', selected ? 'page' : 'false');
        });
    }
    function clearProfile() {
        for (const id of ['balance', 'hours', 'earned', 'name', 'job', 'citizen']) element(id).textContent = '—';
        element('duty').textContent = '取得待ち';
        element('activities').replaceChildren();
    }
    function render(profile) {
        element('balance').textContent = number(profile.points.balance);
        element('earned').textContent = number(profile.points.totalEarned);
        const minutes = Math.floor(Math.max(0, Number(profile.dutySeconds) || 0) / 60);
        element('hours').textContent = `${Math.floor(minutes / 60)}時間 ${minutes % 60}分`;
        element('name').textContent = profile.name || '名前未登録';
        element('job').textContent = profile.job;
        element('citizen').textContent = `市民ID：${profile.citizenid}`;
        element('duty').textContent = profile.onDuty ? '● 勤務中' : '○ 勤務外';
        const activities = element('activities');
        activities.replaceChildren();
        const entries = Object.entries(profile.activities || {}).sort(([a], [b]) => a.localeCompare(b));
        if (!entries.length) activities.textContent = 'まだ業務実績がありません。';
        for (const [key, value] of entries) {
            const row = document.createElement('div');
            const label = document.createElement('dt');
            const total = document.createElement('dd');
            label.textContent = key;
            total.textContent = number(value);
            row.append(label, total);
            activities.append(row);
        }
    }
    async function refresh() {
        if (busy || !opened) return;
        const current = ++request;
        busy = true;
        element('refresh').disabled = true;
        element('status').textContent = 'データを取得しています…';
        try {
            if (preview) {
                clearProfile();
                element('status').textContent = '画面プレビュー：実際のデータはゲーム内で表示されます。';
                return;
            }
            const result = await post('tabletProfile');
            if (current !== request || !opened) return;
            if (!result.ok) throw new Error(result.error);
            render(result.profile);
            element('status').textContent = `最終更新 ${new Date().toLocaleTimeString('ja-JP')}`;
        } catch {
            if (current === request && opened) {
                clearProfile();
                element('status').textContent = 'データを取得できませんでした。少し待って「更新」を押してください。';
            }
        } finally {
            if (current === request) { busy = false; element('refresh').disabled = false; }
        }
    }
    function setVisible(visible) {
        opened = visible;
        tablet.hidden = !visible;
        request++;
        busy = false;
        element('refresh').disabled = false;
        clearProfile();
        if (visible) { selectPage('home'); element('close').focus(); refresh(); }
    }
    async function close() {
        if (!opened) return;
        if (preview) { setVisible(false); return; }
        try { await post('tabletClose'); setVisible(false); }
        catch { element('status').textContent = '閉じられませんでした。Esc または × でもう一度お試しください。'; }
    }
    window.addEventListener('message', ({ data }) => {
        if (data?.action === 'tablet:open') setVisible(true);
        if (data?.action === 'tablet:close') setVisible(false);
    });
    window.addEventListener('keydown', (event) => {
        if (!opened) return;
        if (event.key === 'Escape') { event.preventDefault(); close(); }
        if (event.key === 'Tab') {
            const buttons = [...tablet.querySelectorAll('button:not(:disabled)')];
            const first = buttons[0], last = buttons[buttons.length - 1];
            if (event.shiftKey && document.activeElement === first) { event.preventDefault(); last.focus(); }
            else if (!event.shiftKey && document.activeElement === last) { event.preventDefault(); first.focus(); }
        }
    });
    document.querySelectorAll('[data-page]').forEach((button) => button.addEventListener('click', () => selectPage(button.dataset.page)));
    element('refresh').addEventListener('click', refresh);
    element('close').addEventListener('click', close);
    function tick() { element('clock').textContent = new Date().toLocaleTimeString('ja-JP', { hour: '2-digit', minute: '2-digit' }); }
    tick(); setInterval(tick, 1000);
    if (preview) setVisible(true);
    else post('tabletReady').catch(() => { element('status').textContent = '初期化に失敗しました。Coreを再起動してください。'; });
})();
