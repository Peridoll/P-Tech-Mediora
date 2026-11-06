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
const bleedLabels = ['なし', '少量', '少量', '多量', '多量'];
const severityLabel = (value, cause) => cause && value === 1 ? '軽傷' : cause && value === 3 ? '重傷' : labels[value];
const validLevel = value => Number.isInteger(value) && value >= 0 && value <= 4;
const bodyNames = { head: '頭部', upper_body: '上半身', lower_body: '下半身', left_arm: '左腕', right_arm: '右腕', left_leg: '左脚', right_leg: '右脚' };
const kinds = { shot: '銃創', stabbed: '刺創', beat: '打撲', burned: '火傷' };

function renderInjuries(list, injuries) {
  list.replaceChildren();
  for (const row of injuries) {
    const card = byId('injury-template').content.cloneNode(true);
    card.querySelector('.body-name').textContent = row.body || bodyNames[row.part] || '-';
    card.querySelector('.kind').textContent = kinds[row.kind] || row.kind || '-';
    for (const key of ['severity', 'bleed']) {
      const value = row[key];
      card.querySelector('.' + key + '-value').textContent = validLevel(value) ? (key === 'severity' ? severityLabel(value, row.cause) : bleedLabels[value]) : '-';
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
  const maximum = key => { const values = injuries.map(row => row[key]).filter(validLevel); return values.length ? (key === 'bleed' ? bleedLabels[Math.max(...values)] : Math.max(...values) + ' / 4') : '-'; };
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

function showTreatment(open) {
  byId('treatment-screen').hidden = !open;
  chartApp.classList.toggle('treatment-mode', open);
  byId('chart-list').inert = open;
  byId('chart-search').hidden = open;
  byId('chart-treat').hidden = open || byId('chart-detail').hidden;
}

function clearChartResults() {
  byId('chart-billing-window').close();
  byId('chart-sidebar-patient').hidden = true;
  showTreatment(false);
  byId('chart-detail').hidden = true;
  byId('chart-treat').hidden = true;
  byId('chart-list').replaceChildren();
  byId('chart-injuries').replaceChildren();
}

function issuedDate(value) {
  const date = new Date(value);
  return value && !Number.isNaN(date.getTime()) ? date.toLocaleString('ja-JP', { hour12: false }) : '日時未記録';
}

const treatmentImages = { bandage: 'bandage', forceps: 'surgicalforceps', needle: 'needleandthread', health: 'firstaidkit', beat: 'icepack', shot: 'bulletextractionkit', stabbed: 'suturekit', burned: 'burncream' };
const treatmentImage = kind => 'https://cfx-nui-ox_inventory/web/images/pmediora_' + treatmentImages[kind] + '.png';

function renderCharts(result, preferredId, openTreatment) {
  const charts = Array.isArray(result.charts) ? result.charts : [];
  text('chart-sidebar-patient', result.patient.name || '氏名未登録');
  byId('chart-sidebar-patient').hidden = false;
  chartNotice(charts.length ? '' : 'この患者のカルテはありません。');
  const choices = [];
  const select = index => {
    const chart = charts[index];
    for (let i = 0; i < choices.length; i++) choices[i].setAttribute('aria-pressed', String(i === index));
    byId('chart-detail').hidden = false;
    byId('chart-treat').hidden = false;
    text('chart-issued', issuedDate(chart.issuedAt));
    text('chart-examiner', chart.examinerName || '未記録');
    text('chart-observation', chart.observationStatus || '取得状態未記録');
    byId('chart-observation').hidden = chart.observationStatus === 'Wasabiの負傷同期記録';
    const treatment = byId('chart-treatment');
    const selectInjury = byId('chart-treatment-injury');
    byId('treatment-screen').hidden = true;
    text('chart-treatment-result', '');
    selectInjury.replaceChildren();
    selectInjury.disabled = false;
    const tools = { bandage: '包帯', forceps: 'ピンセット', needle: '針と糸', health: '医療キット', beat: '冷却パック', shot: '弾丸除去キット', stabbed: '縫合キット', burned: '火傷用クリーム' };
    (chart.injuries || []).forEach((injury, index) => {
      if (!Object.hasOwn(bodyNames, injury.part)) return;
      const id = index + 1;
      const methods = [];
      if (!chart.treated?.[id] && Object.hasOwn(tools, injury.kind)) {
        methods.push(injury.kind);
        if (injury.kind === 'shot') methods.push('forceps');
        if (injury.kind === 'stabbed') methods.push('needle');
      }
      if ((chart.bleeding?.[id] ?? injury.bleed) > 0) methods.push('bandage');
      for (const method of methods) {
        const option = new Option(bodyNames[injury.part] + '／' + tools[method], id + ':' + method);
        option.dataset.part = injury.part;
        option.dataset.kind = method;
        selectInjury.add(option);
      }
    });
    if (Number.isFinite(result.vitals?.health) && result.vitals.health < 100 && !result.vitals.down) {
      const option = new Option('体力／医療キット', 0);
      option.dataset.part = 'health';
      option.dataset.kind = 'health';
      selectInjury.add(option);
    }
    const treat = byId('chart-treat');
    const revive = byId('chart-revive');
    const remaining = (chart.injuries || []).some((injury, index) => Object.hasOwn(bodyNames, injury.part) && (!chart.treated?.[index + 1] || (chart.bleeding?.[index + 1] ?? injury.bleed) > 0));
    const down = ['死亡', '瀕死（laststand）'].includes(chart.death);
    treat.firstElementChild.textContent = !remaining ? '治療済' : '治療';
    treat.classList.toggle('stamped', !remaining);
    treat.disabled = !selectInjury.options.length;
    const unnecessary = !chart.revived && chart.death === '死亡・瀕死フラグなし';
    revive.firstElementChild.textContent = chart.revived ? '蘇生済' : unnecessary ? '不要' : '蘇生';
    revive.classList.toggle('unnecessary', unnecessary);
    revive.classList.toggle('stamped', !!chart.revived || unnecessary);
    revive.disabled = remaining || !down || !!chart.revived;
    byId('chart-revive-result').hidden = true;
    revive.onclick = async () => {
      revive.disabled = true;
      const request = chartRequest;
      let response;
      try {
        response = await postNui('reviveChart', { targetId: result.patient.serverId, chartId: chart.chartId });
      } catch {
        response = { error: '蘇生処理を確認できませんでした' };
      }
      if (response?.started || request !== chartRequest || chartApp.hidden) return;
      if (response?.ok) {
        searchCharts(chart.chartId);
      } else {
        text('chart-revive-result', response?.error || '蘇生に失敗しました');
        byId('chart-revive-result').hidden = false;
        revive.disabled = false;
      }
    };
    const health = byId('chart-health');
    const vitals = byId('chart-vitals');
    health.replaceChildren();
    health.dataset.part = 'health';
    vitals.replaceChildren();
    for (const [key, label] of [['health', '体力'], ['hunger', '空腹'], ['thirst', '水分'], ['stress', 'ストレス']]) {
      const value = result.vitals?.[key];
      const gauge = document.createElement('div');
      gauge.className = 'chart-vital';
      gauge.style.setProperty('--vital', (Number.isFinite(value) ? Math.max(0, Math.min(100, value)) : 0) + '%');
      const reading = document.createElement('b');
      reading.textContent = Number.isFinite(value) ? Math.round(value) : '-';
      const caption = document.createElement('span');
      caption.textContent = label;
      gauge.append(reading, caption);
      (key === 'health' ? health : vitals).append(gauge);
    }
    const toolList = byId('treatment-tools');
    const figure = byId('chart-body-map');
    const treatmentRegions = [...figure.querySelectorAll('[data-part]'), health];
    let hoveredRegion;
    const matching = (part, kind) => Array.from(selectInjury.options)
      .filter(option => option.dataset.part === part && option.dataset.kind === kind);
    const updateMap = () => {
      const options = Array.from(selectInjury.options);
      for (const region of treatmentRegions) {
        const part = region.dataset.part;
        region.classList.toggle('injured', options.some(option => option.dataset.part === part));
        region.classList.toggle('drop-ready', region === hoveredRegion);
      }
      for (const card of toolList.children) {
        card.disabled = !options.some(option => option.dataset.kind === card.dataset.kind);
      }
    };
    toolList.replaceChildren();
    for (const [kind, name] of Object.entries(tools)) {
      if (!Array.from(selectInjury.options).some(option => option.dataset.kind === kind)) continue;
      const card = document.createElement('button');
      card.type = 'button';
      card.className = 'treatment-tool';
      const icon = document.createElement('img');
      icon.alt = '';
      icon.draggable = false;
      icon.src = treatmentImage(kind);
      icon.addEventListener('error', () => { icon.hidden = true; });
      const label = document.createElement('span');
      label.textContent = name;
      card.append(icon, label);
      card.dataset.kind = kind;
      card.addEventListener('pointerdown', start => {
        if (start.button !== 0 || treatment.querySelector('button').disabled) return;
        card.setPointerCapture(start.pointerId);
        let ghost;
        const move = event => {
          if (!ghost && Math.hypot(event.clientX - start.clientX, event.clientY - start.clientY) < 5) return;
          if (!ghost) {
            ghost = document.createElement('div');
            ghost.className = 'treatment-drag-preview';
            for (const child of card.children) ghost.append(child.cloneNode(true));
            ghost.setAttribute('aria-hidden', 'true');
            document.body.append(ghost);
          }
          ghost.style.left = event.clientX + 'px';
          ghost.style.top = event.clientY + 'px';
          const region = document.elementFromPoint(event.clientX, event.clientY)?.closest('[data-part]');
          const nextRegion = region && treatmentRegions.includes(region) && matching(region.dataset.part, kind).length
            ? region : undefined;
          if (nextRegion !== hoveredRegion) {
            hoveredRegion = nextRegion;
            updateMap();
          }
        };
        const finish = event => {
          card.removeEventListener('pointermove', move);
          card.removeEventListener('lostpointercapture', finish);
          card.removeEventListener('pointerup', finish);
          card.removeEventListener('pointercancel', finish);
          if (!ghost) return;
          ghost.remove();
          hoveredRegion = undefined;
          updateMap();
          if (event.type !== 'pointerup' || byId('treatment-screen').hidden) return;
          const region = document.elementFromPoint(event.clientX, event.clientY)?.closest('[data-part]');
          if (!region || !treatmentRegions.includes(region)) return;
          const options = matching(region.dataset.part, kind);
          if (!options.length) return;
          selectInjury.value = options[0].value;
          treatment.requestSubmit();
        };
        card.addEventListener('pointermove', move);
        card.addEventListener('lostpointercapture', finish);
        card.addEventListener('pointerup', finish);
        card.addEventListener('pointercancel', finish);
      });
      toolList.append(card);
    }
    updateMap();
    byId('chart-treat').onclick = () => {
      text('treatment-patient', result.patient.name || '氏名未登録');
      showTreatment(true);
    };
    treatment.onsubmit = async event => {
      event.preventDefault();
      const button = treatment.querySelector('button');
      const option = selectInjury.selectedOptions[0];
      if (!option || button.disabled) return;
      button.disabled = true;
      const version = chartRequest;
      try {
        const response = await postNui('treatChartInjury', {
          targetId: result.patient.serverId, chartId: chart.chartId, index: Number(option.value.split(':')[0]), method: option.dataset.kind,
        });
        if (response?.started || version !== chartRequest || !option.isConnected) return;
        text('chart-treatment-result', response?.ok ? '処置しました。蘇生後にこの傷は戻りません。' : response?.error || '治療に失敗しました。');
        if (response?.ok) {
          option.remove();
          updateMap();
          if (!selectInjury.options.length) {
            selectInjury.disabled = true;
            byId('chart-treat').disabled = true;
          }
        }
      } catch {
        if (version === chartRequest && option.isConnected) text('chart-treatment-result', '治療処理を確認できませんでした。');
      } finally {
        button.disabled = false;
      }
    };
    text('chart-patient-name', result.patient.name || '氏名未登録');
    text('sheet-id', result.patient.serverId);
    const supplyNames = {
      pmediora_firstaidkit: '救急キット', pmediora_bandage: '包帯',
      pmediora_icepack: '冷却パック', pmediora_bulletextractionkit: '摘出キット',
      pmediora_surgicalforceps: 'ピンセット', pmediora_suturekit: '縫合キット',
      pmediora_needleandthread: '針と糸', pmediora_burncream: '火傷クリーム',
    };
    const supplies = byId('chart-supplies-list');
    supplies.replaceChildren();
    const yen = amount => new Intl.NumberFormat('ja-JP', { style: 'currency', currency: 'JPY' }).format(amount);
    const addCharge = (label, count, unit) => {
      const row = supplies.insertRow();
      row.insertCell().textContent = label;
      row.insertCell().textContent = String(count);
      row.insertCell().textContent = yen(unit);
      row.insertCell().textContent = yen(count * unit);
    };
    for (const charge of chart.charges || []) {
      addCharge(supplyNames[charge.item] || charge.item, charge.quantity, charge.unit);
    }
    if (chart.treatmentFee) addCharge('治療対応費', 1, chart.treatmentFee);
    if (chart.reviveFee) addCharge(chart.reviveLabel + '対応費', 1, chart.reviveFee);
    text('chart-supplies-total', yen(chart.totalCharge || 0));
    byId('chart-supplies-table').hidden = !supplies.rows.length;
    byId('chart-supplies-empty').hidden = !!supplies.rows.length;
    const bill = byId('chart-bill');
    bill.firstElementChild.textContent = chart.invoiceId ? '請求済' : '請求';
    bill.classList.toggle('stamped', !!chart.invoiceId);
    const billingWindow = byId('chart-billing-window');
    const category = byId('chart-billing-revive');
    const sendBill = byId('chart-billing-submit');
    const reviveFees = { field: 800000, hospital: 400000, police: 300000, jail: 200000 };
    bill.disabled = !!chart.invoiceId || remaining || (down && !chart.revived) || !(chart.totalCharge > 0 || chart.revived);
    const updateTotal = () => {
      text('chart-billing-total', yen((chart.totalCharge || 0) + (chart.revived ? reviveFees[category.value] || 0 : 0)));
      sendBill.disabled = !!chart.revived && !category.value;
    };
    bill.onclick = () => {
      text('chart-billing-patient', result.patient.name || '氏名未登録');
      byId('chart-billing-revive-field').hidden = !chart.revived;
      byId('chart-bill-result').hidden = true;
      category.value = '';
      category.required = !!chart.revived;
      updateTotal();
      billingWindow.showModal();
    };
    category.onchange = updateTotal;
    byId('chart-billing-form').onsubmit = async event => {
      event.preventDefault();
      if (sendBill.disabled) return;
      sendBill.disabled = true;
      const request = chartRequest;
      try {
        const response = await postNui('billChart', {
          targetId: result.patient.serverId, chartId: chart.chartId, category: category.value,
        });
        if (request !== chartRequest || chartApp.hidden) return;
        if (!response?.ok) throw new Error(response?.error || '請求に失敗しました');
        billingWindow.close();
        searchCharts(chart.chartId);
      } catch (error) {
        if (request !== chartRequest || !billingWindow.open) return;
        text('chart-bill-result', error.message);
        byId('chart-bill-result').hidden = false;
        updateTotal();
      }
    };
    const showSummary = !remaining && supplies.rows.length > 0;
    byId('chart-supplies').hidden = !showSummary;
    byId('chart-findings-heading').hidden = showSummary;
    byId('chart-injuries').closest('table').hidden = showSummary;
    if (showSummary) byId('chart-observation').hidden = true;
    const findings = byId('chart-injuries');
    findings.replaceChildren();
    const injuries = Array.isArray(chart.injuries)
      ? chart.injuries.map((injury, index) => ({
        ...injury, bleed: chart.bleeding?.[index + 1] ?? injury.bleed, woundTreated: !!chart.treated?.[index + 1],
      })).filter(injury => Object.hasOwn(bodyNames, injury.part) && (!injury.woundTreated || injury.bleed > 0)) : [];
    const injuredParts = new Set(injuries.map(injury => injury.part));
    for (const region of byId('chart-body-map').querySelectorAll('[data-part]')) {
      const part = region.dataset.part;
      region.classList.toggle('injured', injuredParts.has(part));
      region.classList.toggle('healed', !injuredParts.has(part) && chart.injuries.some((injury, index) =>
        injury.part === part && chart.treated?.[index + 1]));
    }
    for (const injury of injuries) {
      const row = findings.insertRow();
      row.className = 'injury-card';
      row.insertCell().textContent = injury.body || bodyNames[injury.part];
      row.insertCell().textContent = injury.woundTreated ? '-' : (kinds[injury.kind] || injury.kind || '-');
      const severity = row.insertCell();
      severity.textContent = !injury.woundTreated && validLevel(injury.severity) ? severityLabel(injury.severity, injury.cause) : '-';
      severity.classList.toggle('sheet-alert', validLevel(injury.severity) && injury.severity >= 3);
      const bleed = row.insertCell();
      bleed.textContent = validLevel(injury.bleed) ? bleedLabels[injury.bleed] : '-';
      bleed.classList.toggle('sheet-alert', validLevel(injury.bleed) && injury.bleed > 0);
    }
    if (!injuries.length) {
      const cell = findings.insertRow().insertCell();
      cell.colSpan = 4;
      cell.textContent = '表示できる負傷記録はありません。';
    }
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
    if (openTreatment && preferred >= 0) {
      byId('chart-treat').onclick();
      if (!byId('chart-treatment-injury').options.length) {
        text('chart-treatment-result', '処置できる傷は残っていません。');
      }
    }
  }
}

async function searchCharts(preferredId, openTreatment) {
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
    renderCharts(result, preferredId, openTreatment);
  } catch {
    if (request === chartRequest && !chartApp.hidden) chartNotice('カルテを取得できませんでした。もう一度確認してください。');
  }
}

let tabletTransition;
function animateTablet(closing) {
  if (closing) byId('chart-billing-window').close();
  if (closing && chartApp.hidden) return;
  tabletTransition?.cancel();
  const shutter = byId('tablet-shutter');
  if (!closing) chartApp.hidden = false;
  chartApp.inert = closing;
  if (matchMedia('(prefers-reduced-motion: reduce)').matches) {
    chartApp.hidden = closing;
    return;
  }

  const frames = [
    { clipPath: 'inset(0 0 0 0)', opacity: 1, offset: 0 },
    { clipPath: 'inset(0 0 0 0)', opacity: 1, offset: .17 },
    { clipPath: 'inset(0 0 100% 0)', opacity: 1, offset: 1 },
  ];
  const transition = shutter.animate(frames, {
    duration: closing ? 260 : 380,
    direction: closing ? 'reverse' : 'normal',
    easing: 'cubic-bezier(.25,.65,.25,1)',
    fill: 'both',
  });
  tabletTransition = transition;
  transition.onfinish = () => {
    if (tabletTransition !== transition) return;
    if (closing) chartApp.hidden = true;
    transition.cancel();
    tabletTransition = undefined;
  };
}

function openCharts(data) {
  uiVersion++;
  cancelChartRequest();
  pending = false;
  app.hidden = true;
  animateTablet(false);
  clearChartResults();
  byId('chart-patient-id').value = Number.isSafeInteger(data.targetId) && data.targetId > 0 ? data.targetId : '';
  chartNotice('患者IDを入力してカルテを確認してください。');
  byId('chart-patient-id').focus();
  if (byId('chart-patient-id').value) searchCharts(data.chartId, data.openTreatment);
}

async function action(name) {
  if (pending) return;
  if (preview) {
    if (name === 'close') { app.hidden = true; animateTablet(true); }
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
byId('chart-search').addEventListener('submit', event => { event.preventDefault(); searchCharts(); });
document.addEventListener('keydown', event => { if (event.key === 'Escape' && !byId('chart-billing-window').open && (!app.hidden || !chartApp.hidden)) action('close'); });

window.addEventListener('message', event => {
  const message = event.data || {};
  if (message.action === 'examination:status') byId('examination-status').hidden = message.data?.active !== true;
  if (message.action === 'open' && message.data) render(message.data);
  if (message.action === 'charts:open') openCharts(message.data || {});
  if (message.action === 'close') { uiVersion++; cancelChartRequest(); app.hidden = true; animateTablet(true); pending = false; }
});
const sample = {
  title: '訓練患者 — 負傷：銃創・打撲', death: '死亡・瀕死フラグなし', training: true, mode: 'ready',
  injuries: [{ body: '左腕', kind: '銃創', severity: 2, bleed: 1 }, { body: '上半身', kind: '打撲', severity: 1, bleed: 0 }],
  details: 'injuries.left_arm.type: shot\ninjuries.left_arm.data.level: 2\ninjuries.left_arm.data.bleed: 1', canRefresh: true, canManage: true,
};
if (preview) { document.body.classList.add('preview-background'); render(sample); }

window.addEventListener('message', ({ data }) => {
  if (data?.action !== 'exam-progress') return;
  const panel = byId('exam-progress');
  panel.classList.toggle('revive-progress', data.mode === 'revive');
  const tool = byId('treatment-progress-tool');
  const hasTool = data.mode === 'treatment' && Object.hasOwn(treatmentImages, data.tool);
  panel.classList.toggle('tool-progress', hasTool);
  if (hasTool) {
    tool.hidden = false;
    tool.src = treatmentImage(data.tool);
    tool.dataset.tool = data.tool;
  }
  const fill = byId('exam-fill');
  fill.getAnimations().forEach(animation => animation.cancel());
  panel.hidden = !Number.isFinite(data.duration) || data.duration <= 0;
  if (!panel.hidden) {
    text('exam-progress-label', data.label || '診察結果を入力中');
    panel.style.setProperty('--exam-cycle', (data.duration / 2) + 'ms');
    fill.animate([{ transform: 'scaleX(0)' }, { transform: 'scaleX(1)' }], {
      duration: data.duration, fill: 'forwards',
    });
  }
});
byId('treatment-back').addEventListener('click', () => {
  showTreatment(false);
  byId('chart-treat').focus();
});

byId('treatment-progress-tool').addEventListener('error', () => byId('exam-progress').classList.remove('tool-progress'));

byId('chart-billing-close').addEventListener('click', () => byId('chart-billing-window').close());
