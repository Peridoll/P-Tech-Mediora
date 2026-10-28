'use strict';
const resource = window.GetParentResourceName || window.parent.GetParentResourceName;
const $ = id => document.getElementById(id);
const tablet = $('tablet');
const pages = { home: $('home-page'), charts: $('charts-page'), treatment: $('treatment-page') };
let records = [];
let selectedChartId = null;
let selectedPatient = null;
let selectedTreatment = null;
let selectedTreatmentIndex;
let treatmentSupplies = [];
let suppliesAvailable = false;
let activeTreatmentChart = null;
let selectedPart = null;
let chartRequest = 0;
let supplyRequest = 0;
let activePage = 'home';
let patientViewRequest = 0;

const partNames = {
  head: '頭部', upper_body: '上半身', lower_body: '下半身',
  left_arm: '左腕', right_arm: '右腕', left_leg: '左脚', right_leg: '右脚',
};
const kindNames = { shot: '銃創', stabbed: '刺創', beat: '打撲', burned: '熱傷' };
const validLevel = number => Number.isInteger(number) && number >= 0 && number <= 4;
const severityName = number => validLevel(number) ? (number <= 1 ? '軽度' : number === 2 ? '中度' : '重度') : '未取得';

function post(name, data = {}) {
  if (typeof resource !== 'function') return Promise.resolve({ error: 'NUI resource unavailable' });
  return fetch('https://' + resource() + '/' + name, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(data) })
    .then(response => response.json()).catch(() => ({ error: '通信に失敗しました' }));
}

function showPage(page) {
  if (activePage === 'treatment' && page !== 'treatment') {
    patientViewRequest++;
    post('setPatientView', { active: false });
  }
  activePage = page;
  Object.entries(pages).forEach(([name, element]) => { element.hidden = name !== page; });
  tablet.classList.toggle('treatment-mode', page === 'treatment');
  if (page === 'home' || page === 'charts') post('rememberPage', { page });
}

function patientViewStatus(result = {}) {
  $('patient-view').classList.toggle('is-live', result.active === true);
  $('patient-view-status').textContent = result.message || (result.error ? '患者の視点を取得できません。' : 'カルテのみ表示しています。');
}

async function openPatientView() {
  const request = ++patientViewRequest;
  patientViewStatus({ message: '患者を確認しています…' });
  const result = await post('setPatientView', { active: true });
  if (request !== patientViewRequest || tablet.hidden || activePage !== 'treatment') return;
  patientViewStatus(result);
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
  treatmentSupplies = values.filter(item => item && typeof item === 'object' && item.treatment && Number.isInteger(item.count) && item.count > 0);
}

function renderTreatmentSupplies() {
  const list = $('treatment-supply-list');
  list.replaceChildren();
  treatmentSupplies.forEach(supply => {
    const card = document.createElement('article');
    const icon = document.createElement('p');
    const name = document.createElement('strong');
    const detail = document.createElement('span');
    const count = document.createElement('b');
    const lines = String(supply.uiLabel || supply.label || '医療キット').split('\n');
    card.className = 'treatment-supply';
    icon.className = 'supply-icon';
    icon.textContent = lines[0] || '医療キット';
    name.textContent = lines.slice(1).join(' ') || kindName(supply.treatment);
    detail.textContent = supply.description || '処置用医療キット';
    count.className = 'supply-count';
    count.textContent = '×' + supply.count;
    card.dataset.item = supply.name;
    card.append(icon, name, detail, count);
    list.append(card);
  });
  if (!treatmentSupplies.length) {
    const empty = document.createElement('p');
    empty.className = 'empty-detail';
    empty.textContent = '対応する医療品を所持していません。';
    list.append(empty);
  }
}

async function refreshSupplies() {
  const ticket = ++supplyRequest;
  $('supply-notice').textContent = '所持数を確認しています…';
  const result = await post('getTreatmentSupplies');
  if (ticket !== supplyRequest || tablet.hidden) return;
  suppliesAvailable = !result.error;
  setTreatmentSupplies(result.items);
  renderTreatmentSupplies();
  $('supply-notice').textContent = result.error || '所持している医療品の合計数です。';
  if (result.error) $('treatment-supply-list').replaceChildren();
  if (selectedTreatment) updateTreatmentSelection(selectedTreatment, selectedTreatmentIndex);
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
  selectedChartId = null;
  activeTreatmentChart = null;
  selectedPart = null;
  selectedTreatment = null;
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

function updateTreatmentSelection(injury, index) {
  selectedTreatment = injury || null;
  selectedTreatmentIndex = index;
  selectedPart = injury?.part || null;
  $('treatment-part-name').textContent = injury ? partName(injury.part) + 'の詳細' : '負傷を選択';
  document.querySelectorAll('.body-part').forEach(button => {
    const selected = button.dataset.part === selectedPart;
    button.classList.toggle('selected', selected);
    button.setAttribute('aria-pressed', String(selected));
  });
  document.querySelectorAll('.treatment-injury').forEach(row => {
    const selected = Number(row.dataset.index) === index;
    row.classList.toggle('selected', selected);
    row.setAttribute('aria-pressed', String(selected));
  });
  if (!selectedTreatment) {
    $('treatment-selection').innerHTML = '<p class="empty-detail">負傷箇所を選択してください。</p>';
    return;
  }
  const supply = treatmentSupplies.filter(item => item.treatment === injury.kind);
  const count = suppliesAvailable ? supply.reduce((sum, item) => sum + item.count, 0) : '未取得';
  $('treatment-selection').innerHTML = '<h2>' + escapeText(partName(injury.part)) + ' · ' + escapeText(kindName(injury.kind)) + '</h2><p class="detail-status">' + (injury.treated === true ? '治療完了' : severityName(injury.severity) + '（' + value(injury.severity) + '）') + '／出血 ' + value(injury.bleed) + '</p><p class="detail-meta">対応する医療品の所持数：' + count + '</p><p class="treatment-pending">処置操作は準備中です。</p>';
}

function selectTreatmentPart(part) {
  const injuries = Array.isArray(activeTreatmentChart?.injuries) ? activeTreatmentChart.injuries : [];
  const rows = injuries.map((injury, index) => ({ injury, index })).filter(row => row.injury.part === part);
  const first = rows.find(row => row.injury.treated !== true) || rows[0];
  updateTreatmentSelection(first?.injury, first?.index);
  $('treatment-injury-list').querySelector('.selected')?.scrollIntoView({ block: 'nearest' });
}

function renderTreatmentInjuries(injuries) {
  const list = $('treatment-injury-list');
  list.replaceChildren();
  $('wound-summary').textContent = '未治療 ' + injuries.filter(injury => injury.treated !== true).length + '件 ／ 全 ' + injuries.length + '件';
  injuries.forEach((injury, index) => {
    const row = document.createElement('button');
    row.type = 'button';
    row.className = 'treatment-injury';
    row.dataset.index = index;
    row.dataset.part = injury.part;
    row.dataset.status = partStatus([injury]);
    row.innerHTML = '<b>' + escapeText(partName(injury.part)) + '</b><span class="wound-state">' + (injury.treated === true ? '治療完了' : severityName(injury.severity)) + '</span><span class="wound-kind">' + escapeText(kindName(injury.kind)) + '</span><span class="wound-bleed">出血 ' + value(injury.bleed) + '</span>';
    row.addEventListener('click', () => updateTreatmentSelection(injury, index));
    list.append(row);
  });
  if (!injuries.length) list.innerHTML = '<p class="empty-detail">このカルテに負傷情報はありません。</p>';
}

function partStatus(injuries) {
  if (!injuries.length) return 'unrelated';
  const untreated = injuries.filter(injury => injury.treated !== true);
  if (!untreated.length) return 'treated';
  const levels = untreated.map(injury => injury.severity).filter(validLevel);
  if (!levels.length) return 'unknown';
  const maximum = Math.max(...levels);
  return maximum <= 1 ? 'mild' : maximum === 2 ? 'moderate' : 'severe';
}

function renderTreatmentChart(chart) {
  activeTreatmentChart = chart;
  selectedChartId = chart.chartId;
  const injuries = Array.isArray(chart.injuries) ? chart.injuries : [];
  $('treatment-chart-meta').textContent = formatTime(chart.issuedAt) + ' ／ 担当 ' + (chart.examinerName || '未記録') + '\n' + (chart.death || '状態未取得') + '\n' + (chart.observationStatus || '');
  document.querySelectorAll('#treatment-chart-list .chart-row').forEach(row => {
    const selected = row.dataset.chartId === chart.chartId;
    row.classList.toggle('selected', selected);
    row.setAttribute('aria-pressed', String(selected));
  });
  document.querySelectorAll('.body-part').forEach(part => {
    const rows = injuries.filter(row => row.part === part.dataset.part);
    part.disabled = !rows.length;
    const untreated = rows.filter(row => row.treated !== true);
    part.dataset.status = untreated.length ? 'injured' : 'unrelated';
    part.title = partName(part.dataset.part) + '：' + (untreated.length ? '未治療 ' + untreated.length + '件' : rows.length ? '治療完了' : '今回の対象外');
    part.setAttribute('aria-label', part.title);
    part.onclick = () => selectTreatmentPart(part.dataset.part);
  });
  renderTreatmentInjuries(injuries);
  selectTreatmentPart(injuries.some(injury => injury.part === selectedPart) ? selectedPart : injuries[0]?.part || null);
  // Keep the tablet's chart detail in sync when returning from treatment.
  renderDetail(chart);
}

function renderTreatment(chart) {
  if (!selectedPatient || !chart) return;
  $('treatment-patient-name').textContent = selectedPatient.name || '氏名未取得';
  $('body-patient-name').textContent = selectedPatient.name || '氏名未取得';
  $('view-patient-name').textContent = selectedPatient.name || '氏名未取得';
  $('view-patient-id').textContent = '患者ID ' + (selectedPatient.serverId ?? '—');
  $('treatment-patient-id').textContent = '患者ID ' + (selectedPatient.serverId ?? '—');
  const list = $('treatment-chart-list');
  list.replaceChildren();
  records.forEach(record => {
    const row = $('chart-template').content.firstElementChild.cloneNode(true);
    row.dataset.chartId = record.chartId;
    row.querySelector('.chart-time').textContent = formatTime(record.issuedAt);
    row.querySelector('.chart-summary').textContent = injuryText(record);
    row.querySelector('.chart-examiner').textContent = '担当: ' + (record.examinerName || '未記録');
    row.addEventListener('click', () => renderTreatmentChart(record));
    list.append(row);
  });
  renderTreatmentSupplies();
  renderTreatmentChart(chart);
  showPage('treatment');
  openPatientView();
  refreshSupplies();
}

async function search(preferredChartId) {
  const request = ++chartRequest;
  const targetId = $('patient-id').value.trim();
  if (!/^\d+$/.test(targetId)) { notice('患者IDには数字を入力してください。'); return; }
  notice('カルテを確認しています…');
  $('chart-content').hidden = true;
  const result = await post('getCharts', { targetId });
  if (request !== chartRequest || tablet.hidden) return;
  if (result.error) { notice(result.error); return; }
  notice('');
  renderCharts(result, preferredChartId);
}

$('open-charts').addEventListener('click', () => showPage('charts'));
$('back-home').addEventListener('click', () => showPage('home'));
$('back-charts').addEventListener('click', () => showPage('charts'));
$('refresh-supplies').addEventListener('click', refreshSupplies);
$('close').addEventListener('click', () => post('close'));
$('chart-search').addEventListener('submit', event => { event.preventDefault(); search(); });
document.addEventListener('keydown', event => { if (event.key === 'Escape' && !tablet.hidden) post('close'); });

window.addEventListener('message', event => {
  const message = event.data || {};
  if (message.action === 'close') { tablet.hidden = true; chartRequest++; supplyRequest++; patientViewRequest++; return; }
  if (message.action === 'patientView:status') {
    if (!tablet.hidden && activePage === 'treatment') { patientViewRequest++; patientViewStatus(message.data); }
    return;
  }
  if (message.action === 'treatment:supplies') {
    supplyRequest++;
    suppliesAvailable = !message.data?.error;
    setTreatmentSupplies(message.data?.items);
    renderTreatmentSupplies();
    $('supply-notice').textContent = message.data?.error || '所持している医療品の合計数です。';
    if (message.data?.error) $('treatment-supply-list').replaceChildren();
    if (selectedTreatment) updateTreatmentSelection(selectedTreatment, selectedTreatmentIndex);
    return;
  }
  if (message.action !== 'open' || !message.data) return;
  const data = message.data;
  chartRequest++;
  supplyRequest++;
  tablet.hidden = false;
  $('title').textContent = data.title || 'EMSManager';
  $('medic-name').textContent = data.medicName || '';
  const path = typeof data.wallpaper === 'string' && /^[a-zA-Z0-9_./-]+$/.test(data.wallpaper) ? data.wallpaper : '';
  $('wallpaper').style.backgroundImage = path ? 'url("' + path + '")' : '';
  setTreatmentSupplies(data.treatmentItems);
  suppliesAvailable = false;
  showPage(data.page === 'charts' ? 'charts' : 'home');
  if (data.targetId !== undefined && data.targetId !== null) {
    $('patient-id').value = String(data.targetId);
    search(data.chartId || null);
  }
});
