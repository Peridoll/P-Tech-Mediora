local C=Config.PrivateBilling
local prefix='ptech_mediora_medical:privateBill:'
local ready=false
local sessions,busy={},{}
local function db(method,...)return exports.oxmysql[method](exports.oxmysql,...)end
local function actor(src,manager)
    local p=exports.qbx_core:GetPlayer(src)
    local d=p and p.PlayerData
    local job=d and d.job
    if not job or job.name~=C.Job or (C.RequireDuty and not job.onduty) then return end
    local grade=type(job.grade)=='table'and job.grade.level or job.grade
    if manager and (tonumber(grade)or -1)<C.ManagerGrade then return end
    return d
end
local function name(d)
    local c=d.charinfo or {}
    return ((c.firstname or '')..' '..(c.lastname or '')):match('^%s*(.-)%s*$')
end
local function integer(n)return type(n)=='number'and n==n and n%1==0 end
local function pair(src,target,session)
    local d=actor(src)
    if not d then return nil,'勤務中の個人医のみ利用できます' end
    if not integer(target)or target<=0 or target==src then return nil,'請求先を確認してください' end
    local p=exports.qbx_core:GetPlayer(target)
    local a,b=GetPlayerPed(src),GetPlayerPed(target)
    if not p or a==0 or b==0 then return nil,'相手が見つかりません' end
    if GetPlayerRoutingBucket(src)~=GetPlayerRoutingBucket(target)or #(GetEntityCoords(a)-GetEntityCoords(b))>C.Distance then
        return nil,'請求相手に近づいてください'
    end
    if PrivateMedic.down(Player(src).state,d.metadata,GetEntityHealth(a))then return nil,'行動不能中は利用できません' end
    if Medical.isInPatientsVR and (Medical.isInPatientsVR(src)or Medical.isInPatientsVR(target))then return nil,'VR訓練中は請求できません' end
    if session and (session.doctor~=d.citizenid or session.patient~=p.PlayerData.citizenid)then return nil,'キャラクターが変わりました' end
    return {doctor=d,patient=p.PlayerData}
end
local function available()
    return ready and GetResourceState('okokBilling')=='started' and GetResourceState('qbx_core')=='started'
end
CreateThread(function()
    local ok,err=pcall(function()
        db('query_async',[[CREATE TABLE IF NOT EXISTS pmediora_private_billing (
            id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
            request_token VARCHAR(80) NOT NULL UNIQUE,
            invoice_id INT NOT NULL UNIQUE,
            doctor_id VARCHAR(64) NOT NULL, doctor_name VARCHAR(128) NOT NULL,
            patient_id VARCHAR(64) NOT NULL, patient_name VARCHAR(128) NOT NULL,
            amount INT NOT NULL, bonus_amount INT NOT NULL,
            bonus_status VARCHAR(20) NOT NULL DEFAULT 'waiting',
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            payment_at DATETIME NULL, bonus_at DATETIME NULL,
            INDEX bonus_queue (bonus_status), INDEX doctor_history (doctor_id,id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
        -- No automatic retry of a claimed payout after interruption: it may already
        -- have reached Qbox. Retain it for the manager's review to avoid double pay.
        ready=true
    end)
    if not ok then print('[Private Billing] database init failed: '..tostring(err))end
end)
lib.callback.register(prefix..'open',function(src,target)
    if not available()then return {error='請求システムの準備ができていません'}end
    local data,err=pair(src,target)
    if not data then return {error=err}end
    if busy[src]then return {error='請求を送信中です'}end
    local token=db('scalar_async','SELECT UUID()')
    -- The database call may yield; validate identity and distance again.
    local again,reason=pair(src,target,{doctor=data.doctor.citizenid,patient=data.patient.citizenid})
    if not again then return {error=reason}end
    sessions[src]={token=token,target=target,doctor=again.doctor.citizenid,patient=again.patient.citizenid,expires=GetGameTimer()+300000}
    return {token=token,patient=name(again.patient),doctor=name(again.doctor),defaultAmount=C.DefaultAmount,maxAmount=C.MaxAmount,
        bonus=C.Bonus,manager=actor(src,true)~=nil}
end)
lib.callback.register(prefix..'send',function(src,token,amount,note)
    if not available()then return {error='請求システムを利用できません'}end
    local s=sessions[src]
    if not s or type(token)~='string'or token~=s.token or GetGameTimer()>s.expires then return {error='請求画面を開き直してください'}end
    if busy[src]then return {error='送信中です'}end
    if not integer(amount)or amount<1 or amount>C.MaxAmount then return {error='金額は1円以上の整数で入力してください'}end
    if type(note)~='string'or #note>180 or not note:find('%S')or note:find('%c')then return {error='請求内容を短い一行で入力してください'}end
    local data,err=pair(src,s.target,s)
    if not data then return {error=err}end
    busy[src]=true
    local ok,result=pcall(function()
        local existing=db('single_async','SELECT invoice_id FROM pmediora_private_billing WHERE request_token = ?',{token})
        if existing then return {ok=true,invoice=existing.invoice_id}end
        local again,reason=pair(src,s.target,s)
        if not again then return {error=reason}end
        -- Both rows commit together. Repeated requests share the same unique token.
        local committed=db('transaction_async',{
            {query=[[INSERT INTO okokbilling
              (ref_id,fees_amount,receiver_identifier,receiver_name,author_identifier,author_name,
               society,society_name,item,invoice_value,status,notes,sent_date,limit_pay_date)
              VALUES(CONCAT('OK',UPPER(LEFT(UUID(),8))),0,?,?,?,?,'','','個人医療費',?,'unpaid',?,CURRENT_TIMESTAMP(),DATE_ADD(CURRENT_DATE,INTERVAL 7 DAY))]],
             values={s.patient,name(again.patient),s.doctor,name(again.doctor),amount,note}},
            {query=[[INSERT INTO pmediora_private_billing
              (request_token,invoice_id,doctor_id,doctor_name,patient_id,patient_name,amount,bonus_amount)
              VALUES(?,LAST_INSERT_ID(),?,?,?,?,?,?)]],
             values={token,s.doctor,name(again.doctor),s.patient,name(again.patient),amount,C.Bonus}}
        })
        if not committed then return {error='請求を保存できませんでした'}end
        local row=db('single_async','SELECT invoice_id FROM pmediora_private_billing WHERE request_token = ?',{token})
        local patient=exports.qbx_core:GetPlayer(s.target)
        if patient and patient.PlayerData.citizenid==s.patient then
            TriggerClientEvent('ox_lib:notify',s.target,{title='個人医療費の請求',description=('請求が届きました（%s円）'):format(amount),type='inform'})
        end
        return {ok=true,invoice=row and row.invoice_id}
    end)
    busy[src]=nil
    if not ok then print('[Private Billing] send failed: '..tostring(result));return {error='請求の送信結果を確認できません。同じ画面から再試行してください'}end
    return result
end)
lib.callback.register(prefix..'history',function(src,page)
    local d=actor(src,true)
    if not d then return {error='個人医の代表のみ確認できます'}end
    if not ready then return {error='履歴を準備中です'}end
    page=integer(page)and math.max(1,math.min(page,100000))or 1
    local rows=db('query_async',[[SELECT p.id,p.doctor_name,p.patient_name,p.amount,p.bonus_amount,p.bonus_status,
        CAST(p.created_at AS CHAR) created_at,CAST(p.payment_at AS CHAR) payment_at,CAST(p.bonus_at AS CHAR) bonus_at,
        b.status invoice_status FROM pmediora_private_billing p LEFT JOIN okokbilling b ON b.id=p.invoice_id
        ORDER BY p.id DESC LIMIT 31 OFFSET ?]],{(page-1)*30})or {}
    -- Access must still be valid after the query returns.
    local current=actor(src,true)
    if not current or current.citizenid~=d.citizenid then return {error='閲覧権限が変わりました'}end
    local more=#rows>30;if more then table.remove(rows)end
    return {ok=true,rows=rows,page=page,more=more}
end)
local function settle()
    if not available()then return end
    local rows=db('query_async',[[SELECT p.id,p.doctor_id,p.bonus_amount FROM pmediora_private_billing p
        JOIN okokbilling b ON b.id=p.invoice_id AND b.author_identifier=p.doctor_id
        AND b.receiver_identifier=p.patient_id AND b.invoice_value=p.amount
        WHERE p.bonus_status='waiting' AND b.status='paid' ORDER BY p.id LIMIT 50]])or {}
    for _,row in ipairs(rows)do
        -- Persistent compare-and-set prevents concurrent workers or restarts
        -- from issuing the same bonus twice.
        local claimed=db('update_async',[[UPDATE pmediora_private_billing p JOIN okokbilling b ON b.id=p.invoice_id
            SET p.bonus_status='processing',p.payment_at=b.paid_date
            WHERE p.id=? AND p.bonus_status='waiting' AND b.status='paid'
            AND b.author_identifier=p.doctor_id AND b.receiver_identifier=p.patient_id AND b.invoice_value=p.amount]],{row.id})
        if claimed==1 then
            local ok,paid=pcall(function()
                return exports.qbx_core:AddMoney(row.doctor_id,'bank',row.bonus_amount,'private-medic-bonus:'..row.id)
            end)
            if ok and paid==true then
                local player=exports.qbx_core:GetPlayerByCitizenId(row.doctor_id)
                if player then exports.qbx_core:Save(player.PlayerData.source)end
                db('update_async',"UPDATE pmediora_private_billing SET bonus_status='paid',bonus_at=CURRENT_TIMESTAMP() WHERE id=? AND bonus_status='processing'",{row.id})
            else
                db('update_async',"UPDATE pmediora_private_billing SET bonus_status='review' WHERE id=? AND bonus_status='processing'",{row.id})
                print('[Private Billing] bonus requires review, ledger='..row.id..' result='..tostring(paid))
            end
        end
    end
end
CreateThread(function()
    while true do
        Wait(C.PaymentPollMs)
        local ok,err=pcall(settle)
        if not ok then print('[Private Billing] settlement failed: '..tostring(err))end
    end
end)
AddEventHandler('playerDropped',function()sessions[source]=nil end)
-- Test seam is server-local, not a network event or a public money export.
MedicalPrivateBilling={settle=settle}
