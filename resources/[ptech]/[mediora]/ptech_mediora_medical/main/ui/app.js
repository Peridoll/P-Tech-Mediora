'use strict';
const GetParentResourceName = window.GetParentResourceName || window.parent.GetParentResourceName;
const byId = id => document.getElementById(id);
const app = byId('app');
const preview = typeof GetParentResourceName !== 'function' && new URLSearchParams(location.search).has('preview');
let pending = false;
const text = (id, value) => { byId(id).textContent = value; };
const labels = ['なし', '軽度', '中等度', '高度', '最重度'];
const validLevel = value => Number.isInteger(value) && value >= 0 && value <= 4;

function render(data) {
  pending = false;
  app.hidden = false;
  text('patient-title', data.title || '診察記録');
  text('source', data.training ? 'NPC · TRAINING' : 'PLAYER · WASABI');
  text('captured', `取得時刻 ${new Date().toLocaleTimeString('ja-JP')} · ${data.training ? '訓練患者のサンプル' : '対象プレイヤーの取得情報'}`);
  byId('training-note').hidden = !data.training;
  const critical = ['死亡', '瀕死（laststand）'].includes(data.death);
  const unknown = !data.death || data.death.startsWith('不明');
  text('status', critical ? '行動不能' : unknown ? '状態未確認' : '死亡フラグなし');
  byId('status').className = `status${critical ? ' critical' : unknown ? ' unknown' : ''}`;
  text('death', data.death || '不明');
  const injuries = Array.isArray(data.injuries) ? data.injuries : [];
  const known = ['ready', 'empty'].includes(data.mode);
  text('injury-count', known ? `${injuries.length} 部位` : '—');
  const maximum = key => { const values = injuries.map(row => row[key]).filter(validLevel); return values.length ? `${Math.max(...values)} / 4` : '未取得'; };
  text('severity', maximum('severity'));
  text('bleed', maximum('bleed'));
  const notice = {
    empty: '返却された負傷情報は空です。負傷がない・健康であるという判定ではありません。',
    unknown: '負傷情報を取得できていません。再診察するか、取得データを確認してください。',
    error: '診察データの取得に失敗しました。対象とWasabiの起動状態を確認してください。',
    unsupported: '取得データの形式に対応していません。下の「取得データを確認」から内容を確認できます。',
  }[data.mode];
  byId('notice').hidden = !notice;
  text('notice', notice || '');
  const list = byId('injuries');
  list.replaceChildren();
  for (const row of injuries.slice(0, 40)) {
    const card = byId('injury-template').content.cloneNode(true);
    card.querySelector('.body-name').textContent = row.body;
    card.querySelector('.kind').textContent = row.kind;
    for (const key of ['severity', 'bleed']) {
      const value = row[key];
      card.querySelector(`.${key}-value`).textContent = validLevel(value) ? (key === 'severity' ? labels[value] : `${value} / 4`) : '未取得';
      for (let i = 0; i < 4; i++) {
        const segment = document.createElement('i');
        if (validLevel(value) && i < value) segment.className = 'active';
        card.querySelector(`.${key}-segments`).append(segment);
      }
    }
    list.append(card);
  }
  byId('raw').open = false;
  text('raw-text', data.details || 'データなし');
  byId('manage').hidden = !data.canManage;
  byId('refresh').disabled = !data.canRefresh;
  byId('manage').disabled = false;
  byId('close').focus();
}

async function action(name) {
  if (pending) return;
  if (preview) {
    if (name === 'close') app.hidden = true;
    if (name === 'refresh') render(sample);
    if (name === 'manage') { sample.death = sample.death === '死亡' ? '死亡・瀕死フラグなし' : '死亡'; render(sample); }
    return;
  }
  if (typeof GetParentResourceName !== 'function') return;
  pending = true;
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 10000);
  try {
    const response = await fetch(`https://${GetParentResourceName()}/action`, {
      method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ action: name }),
      signal: controller.signal,
    });
    if (!response.ok) throw new Error('action failed');
  } catch {
    pending = false;
    byId('notice').hidden = false;
    text('notice', '操作を送信できませんでした。もう一度操作してください。');
  } finally { clearTimeout(timeout); }
}

byId('close').addEventListener('click', () => action('close'));
byId('refresh').addEventListener('click', () => action('refresh'));
byId('manage').addEventListener('click', () => action('manage'));
document.addEventListener('keydown', event => { if (event.key === 'Escape' && !app.hidden) action('close'); });

window.addEventListener('message', event => {
  const message = event.data || {};
  if (message.action === 'open' && message.data) render(message.data);
  if (message.action === 'close') { app.hidden = true; pending = false; }
});
const sample = {
  title: '訓練患者 — 負傷：銃創・打撲', death: '死亡・瀕死フラグなし', training: true, mode: 'ready',
  injuries: [{ body: '左腕', kind: '銃創', severity: 2, bleed: 1 }, { body: '胸部・腹部', kind: '打撲', severity: 1, bleed: 0 }],
  details: 'injuries.left_arm.type: shot\ninjuries.left_arm.data.level: 2\ninjuries.left_arm.data.bleed: 1', canRefresh: true, canManage: true,
};
if (preview) { document.body.classList.add('preview-background'); render(sample); }
