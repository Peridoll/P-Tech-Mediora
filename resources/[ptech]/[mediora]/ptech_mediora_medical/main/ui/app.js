'use strict';
const GetParentResourceName = window.GetParentResourceName || window.parent.GetParentResourceName;
const byId = id => document.getElementById(id);
const app = byId('app');
const chartApp = byId('chart-app');
const preview = typeof GetParentResourceName !== 'function' && new URLSearchParams(location.search).has('preview');
let pending = false;
let uiVersion = 0, chartRequest = 0, chartController;
const text = (id, value) => { byId(id).textContent = value; };
const labels = ['なし', '軽度', '中等度', '高度', '最重度'];
const validLevel = value => Number.isInteger(value) && value >= 0 && value <= 4;
const bodyNames = { head: '頭部', upper_body: '上半身', lower_body: '下半身', left_arm: '左腕', right_arm: '右腕', left_leg: '左脚', right_leg: '右脚' };
const kinds = { shot: '銃創', stabbed: '刺創', beat: '打撲', burned: '火傷' };

function renderInjuries(list, injuries) {
  list.replaceChildren();
  for (const row of injuries) {
    const card = byId('injury-template').content.cloneNode(true);
    card.querySelector('.body-name').textContent = row.body || bodyNames[row.part] || '部位未取得';
    card.querySelector('.kind').textContent = kinds[row.kind] || row.kind || '種類未取得';
    for (const key of ['severity', 'bleed']) {
      const value = row[key];
      card.querySelector('.' + key + '-value').textContent = validLevel(value) ? (key === 'severity' ? labels[value] : value + ' / 4') : '未取得';
      for (let i = 0; i < 4; i++) {
        const segment = document.createElement('i');
        if (validLevel(value) && i < value) segment.className = 'active';
        card.querySelector('.' + key + '-segments').append(segment);
      }
    }
    list.append(card);
  }
}

function cancelChartRequest() {
  chartRequest++;
  chartController?.abort();
  chartController = undefined;
}

function render(data) {
  uiVersion++;
  cancelChartRequest();
  pending = false;
  chartApp.hidden = true;
  app.hidden = false;
  text('patient-title', data.title || '診察記録');
  text('source', data.training ? 'NPC · TRAINING' : 'PLAYER · WASABI');
  text('captured', '取得時刻 ' + new Date().toLocaleTimeString('ja-JP') + ' · ' + (data.training ? '訓練患者のサンプル' : '対象プレイヤーの取得情報'));
  byId('training-note').hidden = !data.training;
  const critical = ['死亡', '瀕死（laststand）'].includes(data.death);
  const unknown = !data.death || data.death.startsWith('不明');
  text('status', critical ? '行動不能' : unknown ? '状態未確認' : '死亡フラグなし');
  byId('status').className = 'status' + (critical ? ' critical' : unknown ? ' unknown' : '');
  text('death', data.death || '不明');
  const injuries = Array.isArray(data.injuries) ? data.injuries : [];
  const known = ['ready', 'empty'].includes(data.mode);
  text('injury-count', known ? injuries.length + ' 部位' : '—');
  const maximum = key => { const values = injuries.map(row => row[key]).filter(validLevel); return values.length ? Math.max(...values) + ' / 4' : '未取得'; };
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
  renderInjuries(byId('injuries'), injuries.slice(0, 40));
  byId('raw').open = false;
  text('raw-text', data.details || 'データなし');
  byId('manage').hidden = !data.canManage;
  byId('open-charts').hidden = !data.canOpenCharts;
  byId('refresh').disabled = !data.canRefresh;
  byId('manage').disabled = false;
  byId('close').focus();
}

async function postNui(endpoint, data, controller = new AbortController()) {
  if (typeof GetParentResourceName !== 'function') throw new Error('NUI unavailable');
  const timeout = setTimeout(() => controller.abort(), 10000);
  try {
    const response = await fetch('https://' + GetParentResourceName() + '/' + endpoint, {
      method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(data), signal: controller.signal,
    });
    if (!response.ok) throw new Error('NUI request failed');
    return await response.json();
  } finally { clearTimeout(timeout); }
}

function chartNotice(message) {
  text('chart-notice', message);
  byId('chart-notice').hidden = !message;
}

function clearChartResults() {
  byId('chart-patient').hidden = true;
  byId('chart-detail').hidden = true;
  byId('chart-list').replaceChildren();
  byId('chart-injuries').replaceChildren();
}

function issuedDate(value) {
  const date = new Date(value);
  return value && !Number.isNaN(date.getTime()) ? date.toLocaleString('ja-JP', { hour12: false }) : '日時未記録';
}

function renderCharts(result, preferredId) {
  const charts = Array.isArray(result.charts) ? result.charts : [];
  byId('chart-patient').hidden = false;
  text('chart-patient-name', result.patient.name || '氏名未登録');
  text('chart-patient-label', '患者ID ' + result.patient.serverId + ' · ' + charts.length + ' 件の診察記録');
  chartNotice(charts.length ? '' : 'この患者のカルテはありません。');
  const choices = [];
  const select = index => {
    const chart = charts[index];
    for (let i = 0; i < choices.length; i++) choices[i].setAttribute('aria-pressed', String(i === index));
    byId('chart-detail').hidden = false;
    text('chart-issued', issuedDate(chart.issuedAt));
    text('chart-examiner', '診察者：' + (chart.examinerName || '未記録'));
    text('chart-death', '診察時の状態：' + (chart.death || '未取得'));
    text('chart-observation', chart.observationStatus || '取得状態未記録');
    renderInjuries(byId('chart-injuries'), Array.isArray(chart.injuries) ? chart.injuries : []);
  };
  charts.forEach((chart, index) => {
    const button = document.createElement('button');
    button.type = 'button';
    button.className = 'chart-choice';
    button.textContent = issuedDate(chart.issuedAt);
    const examiner = document.createElement('span');
    examiner.textContent = '担当：' + (chart.examinerName || '未記録');
    button.append(examiner);
    button.addEventListener('click', () => select(index));
    choices.push(button);
    byId('chart-list').append(button);
  });
  if (charts.length) {
    const preferred = charts.findIndex(chart => chart.chartId === preferredId);
    select(preferred >= 0 ? preferred : 0);
  }
}

async function searchCharts(preferredId) {
  cancelChartRequest();
  const request = chartRequest;
  clearChartResults();
  const targetId = Number(byId('chart-patient-id').value);
  if (!Number.isSafeInteger(targetId) || targetId <= 0) {
    chartNotice('患者IDには正の整数を入力してください。');
    return;
  }
  chartNotice('カルテを取得しています…');
  chartController = new AbortController();
  try {
    const result = await postNui('getCharts', { targetId }, chartController);
    if (request !== chartRequest || chartApp.hidden) return;
    if (!result || result.error || !result.patient) {
      chartNotice(result?.error || 'カルテを取得できませんでした。');
      return;
    }
    renderCharts(result, preferredId);
  } catch {
    if (request === chartRequest && !chartApp.hidden) chartNotice('カルテを取得できませんでした。もう一度確認してください。');
  }
}

function openCharts(data) {
  uiVersion++;
  cancelChartRequest();
  pending = false;
  app.hidden = true;
  chartApp.hidden = false;
  clearChartResults();
  byId('chart-patient-id').value = Number.isSafeInteger(data.targetId) && data.targetId > 0 ? data.targetId : '';
  chartNotice('患者IDを入力してカルテを確認してください。');
  byId('chart-patient-id').focus();
  if (byId('chart-patient-id').value) searchCharts(data.chartId);
}

async function action(name) {
  if (pending) return;
  if (preview) {
    if (name === 'close') { app.hidden = true; chartApp.hidden = true; }
    if (name === 'refresh') render(sample);
    if (name === 'manage') { sample.death = sample.death === '死亡' ? '死亡・瀕死フラグなし' : '死亡'; render(sample); }
    return;
  }
  if (typeof GetParentResourceName !== 'function') return;
  pending = true;
  const version = uiVersion;
  if (name === 'close') cancelChartRequest();
  try {
    const response = await postNui('action', { action: name });
    if (!response?.ok) throw new Error('action rejected');
  } catch {
    if (version !== uiVersion) return;
    if (!chartApp.hidden) chartNotice('操作を送信できませんでした。もう一度操作してください。');
    else if (!app.hidden) {
      byId('notice').hidden = false;
      text('notice', '操作を送信できませんでした。もう一度操作してください。');
    }
  } finally { if (version === uiVersion) pending = false; }
}

byId('close').addEventListener('click', () => action('close'));
byId('refresh').addEventListener('click', () => action('refresh'));
byId('manage').addEventListener('click', () => action('manage'));
byId('open-charts').addEventListener('click', () => action('charts'));
byId('close-charts').addEventListener('click', () => action('close'));
byId('close-charts-bottom').addEventListener('click', () => action('close'));
byId('chart-search').addEventListener('submit', event => { event.preventDefault(); searchCharts(); });
document.addEventListener('keydown', event => { if (event.key === 'Escape' && (!app.hidden || !chartApp.hidden)) action('close'); });

window.addEventListener('message', event => {
  const message = event.data || {};
  if (message.action === 'examination:status') byId('examination-status').hidden = message.data?.active !== true;
  if (message.action === 'open' && message.data) render(message.data);
  if (message.action === 'charts:open') openCharts(message.data || {});
  if (message.action === 'close') { uiVersion++; cancelChartRequest(); app.hidden = true; chartApp.hidden = true; pending = false; }
});
const sample = {
  title: '訓練患者 — 負傷：銃創・打撲', death: '死亡・瀕死フラグなし', training: true, mode: 'ready',
  injuries: [{ body: '左腕', kind: '銃創', severity: 2, bleed: 1 }, { body: '上半身', kind: '打撲', severity: 1, bleed: 0 }],
  details: 'injuries.left_arm.type: shot\ninjuries.left_arm.data.level: 2\ninjuries.left_arm.data.bleed: 1', canRefresh: true, canManage: true,
};
if (preview) { document.body.classList.add('preview-background'); render(sample); }
