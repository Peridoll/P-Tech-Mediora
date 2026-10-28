'use strict';
const resource = window.GetParentResourceName || window.parent.GetParentResourceName;
const $ = id => document.getElementById(id);
const tablet = $('tablet');
const pages = { home: $('home-page'), charts: $('charts-page'), treatment: $('treatment-page') };
let records = [];
let selectedChartId = null;
let selectedPatient = null;
let selectedTreatment = null;
let treatmentSupplies = [];

const partNames = {
  head: '頭部', neck: '首', upper_body: '胸部・腹部', lower_body: '腰部', spine: '背中',
  left_arm: '左腕', right_arm: '右腕', left_leg: '左脚', right_leg: '右脚',
  left_hand: '左手', right_hand: '右手', left_foot: '左足', right_foot: '右足',
};
const kindNames = { shot: '銃創', stabbed: '刺創', beat: '打撲', burned: '熱傷' };
const fallbackSupplies = [
  { label: '医療キット：銃創処置', uiLabel: '医療キット\n銃創', description: '銃創の処置に使用する医療キット。', treatment: 'shot' },
  { label: '医療キット：刺創処置', uiLabel: '医療キット\n刺創', description: '刺創の処置に使用する医療キット。', treatment: 'stabbed' },
  { label: '医療キット：打撲処置', uiLabel: '医療キット\n打撲', description: '打撲の処置に使用する医療キット。', treatment: 'beat' },
  { label: '医療キット：熱傷処置', uiLabel: '医療キット\n熱傷', description: '熱傷の処置に使用する医療キット。', treatment: 'burned' },
];

function post(name, data = {}) {
  if (typeof resource !== 'function') return Promise.resolve({ error: 'NUI resource unavailable' });
  return fetch('https://' + resource() + '/' + name, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(data) })
    .then(response => response.json()).catch(() => ({ error: '通信に失敗しました' }));
}

function showPage(page) {
  Object.entries(pages).forEach(([name, element]) => { element.hidden = name !== page; });
  if (page === 'home' || page === 'charts') post('rememberPage', { page });
}

function notice(message = '') {
  const element = $('chart-notice');
  element.hidden = !message;
  element.textContent = message;
}

function formatTime(value) {
  const date = new Date(value || 0);
  return Number.isNaN(date.getTime()) ? '時刻未取得' : date.toLocaleString('ja-JP', { month: 'numeric', day: 'numeric', hour: '2-digit', minute: '2-digit' });
}

function injuryText(chart) {
  const injuries = Array.isArray(chart.injuries) ? chart.injuries : [];
  return injuries.length ? injuries.length + '件の負傷情報' : '負傷情報なし';
}

function value(number) { return Number.isInteger(number) ? number + '/4' : '未取得'; }
function escapeText(text) { return String(text ?? '').replace(/[&<>'"]/g, char => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', "'": '&#39;', '"': '&quot;' }[char])); }
function partName(part) { return partNames[part] || String(part || '部位未取得'); }
function kindName(kind) { return kindNames[kind] || String(kind || '負傷種別未取得'); }

function setTreatmentSupplies(items) {
  const values = items && typeof items === 'object' ? Object.values(items) : [];
  treatmentSupplies = values.filter(item => item && typeof item === 'object' && item.treatment);
  if (!treatmentSupplies.length) treatmentSupplies = fallbackSupplies;
}

function renderTreatmentSupplies() {
  const list = $('treatment-supply-list');
  list.replaceChildren();
  treatmentSupplies.forEach(supply => {
    const card = document.createElement('article');
    const icon = document.createElement('p');
    const name = document.createElement('strong');
    const detail = document.createElement('span');
    const lines = String(supply.uiLabel || supply.label || '医療キット').split('\n');
    card.className = 'treatment-supply';
    icon.className = 'supply-icon';
    icon.textContent = lines[0] || '医療キット';
    name.textContent = lines.slice(1).join(' ') || kindName(supply.treatment);
    detail.textContent = supply.description || '処置用医療キット';
    card.append(icon, name, detail);
    list.append(card);
  });
}

function renderDetail(chart) {
  selectedChartId = chart.chartId;
  const injuries = Array.isArray(chart.injuries) ? chart.injuries : [];
  const injuryRows = injuries.length ? injuries.map(row => '<li><b>' + escapeText(partName(row.part)) + '</b><span>' + escapeText(kindName(row.kind)) + '　重症度 ' + value(row.severity) + '　出血 ' + value(row.bleed) + '</span></li>').join('') : '<li>負傷情報はありません。</li>';
  const action = injuries.length ? '<button id="open-treatment" class="open-treatment" type="button">治療画面を開く</button>' : '<p class="coming-soon">治療対象となる負傷情報がありません。</p>';
  $('chart-detail').innerHTML = '<p class="detail-label">診察日時</p><h2>' + formatTime(chart.issuedAt) + '</h2><p class="detail-meta">担当: ' + escapeText(chart.examinerName || '未記録') + '　／　' + escapeText(chart.death || '状態未取得') + '</p><p class="detail-label">診察所見</p><p class="detail-status">' + escapeText(chart.observationStatus || '未取得') + '</p><ul class="injuries">' + injuryRows + '</ul>' + action;
  document.querySelectorAll('.chart-row').forEach(row => row.classList.toggle('selected', row.dataset.chartId === selectedChartId));
  const treatment = $('open-treatment');
  if (treatment) treatment.addEventListener('click', () => renderTreatment(chart));
}

function renderCharts(result, preferredChartId) {
  records = Array.isArray(result.charts) ? result.charts : [];
  selectedPatient = result.patient || null;
  $('chart-content').hidden = false;
  $('patient-name').textContent = result.patient?.name || '氏名未取得';
  $('patient-id-label').textContent = 'ID ' + (result.patient?.serverId ?? '—');
  const list = $('chart-list');
  list.replaceChildren();
  if (!records.length) {
    list.innerHTML = '<p class="empty-list">この患者のカルテはありません。</p>';
    $('chart-detail').innerHTML = '<p class="empty-detail">診察を行うと、ここにカルテが追加されます。</p>';
    return;
  }
  records.forEach(chart => {
    const row = $('chart-template').content.firstElementChild.cloneNode(true);
    row.dataset.chartId = chart.chartId;
    row.querySelector('.chart-time').textContent = formatTime(chart.issuedAt);
    row.querySelector('.chart-summary').textContent = injuryText(chart);
    row.querySelector('.chart-examiner').textContent = '担当: ' + (chart.examinerName || '未記録');
    row.addEventListener('click', () => renderDetail(chart));
    list.append(row);
  });
  renderDetail(records.find(chart => chart.chartId === preferredChartId) || records[0]);
}

function updateTreatmentSelection(injury) {
  selectedTreatment = injury || null;
  document.querySelectorAll('.treatment-injury').forEach(row => row.classList.toggle('selected', row.dataset.part === selectedTreatment?.part));
  document.querySelectorAll('.body-part').forEach(part => part.classList.toggle('selected', part.dataset.part === selectedTreatment?.part));
  if (!selectedTreatment) {
    $('treatment-selection').innerHTML = '<p class="empty-detail">負傷箇所を選択してください。</p>';
    return;
  }
  $('treatment-selection').innerHTML = '<p class="detail-label">選択中の負傷</p><h2>' + escapeText(partName(selectedTreatment.part)) + '</h2><p class="detail-status">' + escapeText(kindName(selectedTreatment.kind)) + '　／　重症度 ' + value(selectedTreatment.severity) + '　／　出血 ' + value(selectedTreatment.bleed) + '</p><p class="treatment-pending">対応する医療品・必要数・処置時間は、次の実装で設定します。</p>';
}

function renderTreatment(chart) {
  const injuries = Array.isArray(chart?.injuries) ? chart.injuries : [];
  if (!selectedPatient || !injuries.length) return;
  $('treatment-patient-name').textContent = selectedPatient.name || '氏名未取得';
  renderTreatmentSupplies();
  const list = $('treatment-injury-list');
  list.replaceChildren();
  document.querySelectorAll('.body-part').forEach(part => {
    const injury = injuries.find(row => row.part === part.dataset.part);
    part.disabled = !injury;
    part.classList.toggle('injured', Boolean(injury));
    part.classList.remove('selected');
    part.onclick = injury ? () => updateTreatmentSelection(injury) : null;
  });
  injuries.forEach(injury => {
    const row = document.createElement('button');
    row.type = 'button';
    row.className = 'treatment-injury';
    row.dataset.part = injury.part;
    row.innerHTML = '<b>' + escapeText(partName(injury.part)) + '</b><span>' + escapeText(kindName(injury.kind)) + '　重症度 ' + value(injury.severity) + '</span>';
    row.addEventListener('click', () => updateTreatmentSelection(injury));
    list.append(row);
  });
  updateTreatmentSelection(injuries[0]);
  showPage('treatment');
}

async function search(preferredChartId) {
  const targetId = $('patient-id').value.trim();
  if (!/^\d+$/.test(targetId)) { notice('患者IDには数字を入力してください。'); return; }
  notice('カルテを確認しています…');
  $('chart-content').hidden = true;
  const result = await post('getCharts', { targetId });
  if (result.error) { notice(result.error); return; }
  notice('');
  renderCharts(result, preferredChartId);
}

$('open-charts').addEventListener('click', () => showPage('charts'));
$('back-home').addEventListener('click', () => showPage('home'));
$('back-charts').addEventListener('click', () => showPage('charts'));
$('close').addEventListener('click', () => post('close'));
$('chart-search').addEventListener('submit', event => { event.preventDefault(); search(); });
document.addEventListener('keydown', event => { if (event.key === 'Escape' && !tablet.hidden) post('close'); });

window.addEventListener('message', event => {
  const message = event.data || {};
  if (message.action === 'close') { tablet.hidden = true; return; }
  if (message.action !== 'open' || !message.data) return;
  const data = message.data;
  tablet.hidden = false;
  $('title').textContent = data.title || 'EMSManager';
  $('medic-name').textContent = data.medicName || '';
  const path = typeof data.wallpaper === 'string' && /^[a-zA-Z0-9_./-]+$/.test(data.wallpaper) ? data.wallpaper : '';
  $('wallpaper').style.backgroundImage = path ? 'url("' + path + '")' : '';
  setTreatmentSupplies(data.treatmentItems);
  showPage(data.page === 'charts' ? 'charts' : 'home');
  if (data.targetId !== undefined && data.targetId !== null) {
    $('patient-id').value = String(data.targetId);
    search(data.chartId || null);
  }
});
