const panel = document.getElementById('panel');
let state = null, pending = false;
const el = id => document.getElementById(id);
function render(data) {
  state = data;
  el('orders').textContent = `${data.orderCount} / ${data.maxOrders}`;
  el('cargo').textContent = `所持物資：${data.cargoCount}個`;
  el('receipts').textContent = `所持領収書：${data.receiptCount}枚`;
  el('terms').textContent = `1個納品で製薬基材 × ${data.materialCount}、精算予定額 $${data.receiptAmount.toLocaleString()} の領収書を発行`;
  const m = data.mission;
  el('stage').textContent = data.blocked ? '処理停止：管理者へ連絡' : m ? '仕入れ先へ向かう' : data.cargoCount > 0 ? '物資を病院へ納品できます' : '受注していません';
  el('destination').textContent = m ? data.supplierLabel : '病院の同じポイントで受注・納品できます。';
  for(const b of document.querySelectorAll('[data-action]')) b.disabled = pending;
  el('start').disabled = pending || data.blocked || data.orderCount >= data.maxOrders;
  el('cancel').disabled = pending || data.blocked || !m;

}
async function request(route, data={}) {
  const response = await fetch(`https://${(window.GetParentResourceName || window.parent.GetParentResourceName)()}/logistics_${route}`,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(data)});
  return response.json();
}
async function close() {
  panel.hidden = true;
  try { await request('close'); } catch(e) { el('error').textContent='画面の終了に失敗しました。'; }
}
el('close').addEventListener('click',close);
document.addEventListener('keydown',e=>{if(e.key==='Escape'&&!panel.hidden) close();});
for (const b of document.querySelectorAll('[data-action]')) b.addEventListener('click',async()=>{
  if(pending) return;
  pending=true; if(state) render(state); el('error').textContent='';
  try { const result=await request('action',{action:b.dataset.action}); if(!result.ok) el('error').textContent=result.message||'処理に失敗しました。'; if(result.orderCount !== undefined) state=result; }
  catch(e){el('error').textContent='通信に失敗しました。閉じて再度開いてください。';}
  finally{pending=false; if(state) render(state);}
});
window.addEventListener('message',event=>{
  const m=event.data;
  if(m.action==='open'){panel.hidden=false;el('close').focus();}
  if(m.action==='close') panel.hidden=true;
  if(m.action==='state') render(m.data);
});
