(() => {
  const root = document.createElement('section');
  root.id = 'private-billing'; root.hidden = true;
  root.innerHTML = `<article class="pb-card" role="dialog" aria-modal="true" aria-labelledby="pb-title">
    <header class="pb-header"><div class="pb-brand"><span>✚</span><div>MedPay<small>PRIVATE MEDICAL</small></div></div><button type="button" id="pb-close" aria-label="閉じる">×</button></header>
    <nav id="pb-tabs"><button type="button" id="pb-invoice-tab">請求を作成</button><button type="button" id="pb-history-tab">ボーナス履歴</button></nav>
    <section id="pb-invoice"><div class="pb-heading"><span>PRIVATE CARE</span><h1 id="pb-title">個人医療費の請求</h1></div>
      <div class="pb-patient"><span>請求先</span><strong id="pb-patient"></strong></div>
      <form id="pb-form"><label class="pb-amount-label" for="pb-amount">請求金額</label><div class="pb-amount"><span>¥</span><input id="pb-amount" type="number" min="1" step="1" required inputmode="numeric"></div>
      <div class="pb-amount-foot"><span id="pb-formatted"></span><button type="button" id="pb-reset">120万円に戻す</button></div>
      <label class="pb-note-label" for="pb-note">請求内容</label><input id="pb-note" type="text" maxlength="60" value="個人医療費" required>
      <div class="pb-destination"><span>入金先</span><strong id="pb-doctor"></strong></div>
      <div class="pb-bonus"><span>支払い完了後の診療ボーナス</span><strong id="pb-bonus"></strong><small>患者への請求額には含まれません</small></div>
      <button id="pb-send" type="submit">請求を送信 <span>↗</span></button></form></section>
    <section id="pb-history" hidden><div class="pb-heading"><span>MANAGEMENT</span><h1>ボーナス履歴</h1><p>個人医の請求と、支払い後の付与状況</p></div><div id="pb-history-list"></div><div class="pb-pages"><button id="pb-prev" type="button">前へ</button><span id="pb-page"></span><button id="pb-next" type="button">次へ</button></div></section>
    <p id="pb-result" role="status" aria-live="polite"></p><footer>MEDIORA · PRIVATE CARE</footer></article>`;
  document.body.append(root);
  const $ = id => document.getElementById('pb-' + id);
  const yen = n => new Intl.NumberFormat('ja-JP').format(Number(n) || 0) + '円';
  let data, sending = false, sent = false, page = 1, version = 0;
  const post = async (name, body = {}) => {
    const response = await fetch(`https://${GetParentResourceName()}/${name}`, {method:'POST', headers:{'Content-Type':'application/json'},body:JSON.stringify(body)});
    if (!response.ok) throw new Error('通信に失敗しました');
    const result = await response.json();
    if (!result || result.error) throw new Error(result?.error || '結果を確認できません');
    return result;
  };
  function status(text, success = false) { $('result').textContent = text; $('result').classList.toggle('pb-success', success); }
  function tab(history) { $('invoice').hidden = history; $('history').hidden = !history; $('invoice-tab').classList.toggle('active', !history); $('history-tab').classList.toggle('active', history); status(''); }
  async function history(next = 1) {
    tab(true); const request = ++version; $('history-list').textContent = '読み込み中…';
    $('prev').disabled = $('next').disabled = true;
    try {
      const result = await post('privateBillHistory', {page:next});
      if (request !== version || root.hidden) return;
      page = result.page; $('history-list').replaceChildren();
      for (const row of result.rows) {
        const item = document.createElement('article'); item.className = 'pb-log';
        const state = row.bonus_status === 'paid' ? '付与済み' : ['processing','review'].includes(row.bonus_status) ? '要確認' : row.invoice_status === 'paid' ? '付与待ち' : row.invoice_status === 'unpaid' ? '支払い待ち' : '対象外';
        const values = [row.doctor_name + ' → ' + row.patient_name, '請求 ' + yen(row.amount), 'ボーナス ' + yen(row.bonus_amount), state, '請求日時 ' + row.created_at];
        if (row.payment_at) values.push('支払日時 ' + row.payment_at);
        if (row.bonus_at) values.push('付与日時 ' + row.bonus_at);
        for (const value of values) { const line = document.createElement('div'); line.textContent = value; item.append(line); }
        $('history-list').append(item);
      }
      if (!result.rows.length) $('history-list').textContent = '履歴はまだありません';
      $('page').textContent = page + ' ページ'; $('prev').disabled = page <= 1; $('next').disabled = !result.more;
    } catch (error) { if(request===version && !root.hidden) { $('history-list').textContent = ''; status(error.message); } }
  }
  $('form').addEventListener('submit', async event => {
    event.preventDefault(); if (sending || sent) return;
    const amount = Number($('amount').value), note = $('note').value.trim();
    if (!Number.isSafeInteger(amount) || amount < 1 || amount > data.maxAmount || !note) { status('金額と請求内容を確認してください'); return; }
    sending = true; $('send').disabled = true; status('送信中…'); const request = version;
    try { await post('privateBillSend', {amount,note}); if(request !== version || root.hidden)return; sent = true; status('請求を送信しました。ボーナスは支払い完了後に付与されます。', true); $('send').textContent = '送信済み ✓'; }
    catch (error) { if(request === version && !root.hidden)status(error.message); }
    finally { if(request === version) { sending = false; $('send').disabled = sent; } }
  });
  function close() { if (sending) return; post('privateBillClose').catch(() => {}); root.hidden = true; ++version; }
  $('close').onclick = close;
  $('amount').oninput = () => { $('formatted').textContent = yen($('amount').value); };
  $('reset').onclick = () => { $('amount').value = data.defaultAmount; $('amount').oninput(); };
  $('history-tab').onclick = () => { if(!sending)history(); };
  $('invoice-tab').onclick = () => { if(!sending) { ++version; tab(false); } };
  $('prev').onclick = () => history(page - 1); $('next').onclick = () => history(page + 1);
  document.addEventListener('keydown', event => { if(!root.hidden && event.key === 'Escape') { event.preventDefault(); event.stopImmediatePropagation(); close(); } }, true);
  window.addEventListener('message', event => {
    if(event.data.action === 'private-billing:close') { root.hidden = true; ++version; sending = false; return; }
    if(event.data.action !== 'private-billing:open') return;
    ++version; data = event.data.data; sending = sent = false; root.hidden = false;
    $('send').disabled = false; $('send').innerHTML = '請求を送信 <span>↗</span>'; $('tabs').hidden = !data.manager;
    $('invoice-tab').hidden = !!data.historyOnly; $('history-tab').hidden = !data.manager;
    if(data.historyOnly) { history(); return; }
    $('patient').textContent = data.patient; $('doctor').textContent = data.doctor + ' の個人口座';
    $('bonus').textContent = yen(data.bonus); $('amount').max = data.maxAmount; $('amount').value = data.defaultAmount;
    $('note').value = '個人医療費'; $('amount').oninput(); tab(false);
  });
})();
