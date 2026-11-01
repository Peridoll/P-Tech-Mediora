Medical = {}

-- Wasabi v1は文字列、導入構成によっては数値・trueでdead State Bagを公開する。
-- 判定はEscortと揃え、状態そのものは変更しない。
local function deadState(value)
    return value == 'dead' or value == 2 or value == true
end

local function laststandState(value)
    return value == 'laststand' or value == 1
end

-- Only copy the known observation schema; never accept patient identity or state from the client.
function Medical.report(injuries, success)
    local rows = {}
    if success ~= true or type(injuries) ~= 'table' then return { rows = rows, status = '未取得' } end
    -- 導入版WasabiのBonesが割り当てる7部位。手は腕、足先は脚に含まれる。
    local parts = { 'head', 'upper_body', 'lower_body', 'left_arm', 'right_arm', 'left_leg', 'right_leg' }
    local kinds = { shot = true, stabbed = true, beat = true, burned = true }
    local function level(value)
        if type(value) == 'number' and value == value and value % 1 == 0 and value >= 0 and value <= 4 then return value end
    end
    for _, part in ipairs(parts) do
        local injury = injuries[part]
        if type(injury) == 'table' and type(injury.type) == 'string' and kinds[injury.type] then
            local data = type(injury.data) == 'table' and injury.data or {}
            rows[#rows + 1] = { part = part, kind = injury.type, severity = level(data.level), bleed = level(data.bleed) }
        end
    end
    return { rows = rows, status = next(injuries) == nil and '返却情報なし（健康の保証ではありません）'
        or #rows == 0 and '未対応形式' or 'クライアント観察記録' }
end

function Medical.jobAllowed(name)
    -- Jobs is intentionally an array: { 'ambulance', 'doctor' }.
    -- An empty array means unrestricted use, not an accidental lockout.
    if type(Config.Jobs) ~= 'table' or #Config.Jobs == 0 then return true end
    for _, allowed in ipairs(Config.Jobs) do
        if allowed == name then return true end
    end
    return false
end

function Medical.allowed(data)
    local job = data and data.job
    return job ~= nil and Medical.jobAllowed(job.name)
        and job.onduty == true
end

function Medical.death(state, metadata)
    metadata = metadata or {}
    if deadState(state) or metadata.isdead == true then return '死亡' end
    if laststandState(state) or metadata.inlaststand == true then return '瀕死（laststand）' end
    if state == false or (metadata.isdead == false and metadata.inlaststand == false) then
        return '死亡・瀕死フラグなし'
    end
    return '不明（未取得・想定外の値）'
end

-- The protected export's schema is not assumed. Render a bounded snapshot,
-- including body-part keyed tables, without silently discarding unknown fields.
function Medical.describe(value)
    local lines, seen, count = {}, {}, 0
    local function walk(v, path, depth)
        if count >= 40 then return end
        count = count + 1
        if type(v) ~= 'table' then
            local text = '<' .. type(v) .. '>'
            if type(v) == 'string' or type(v) == 'number' or type(v) == 'boolean' then text = tostring(v) end
            lines[#lines + 1] = path .. ': ' .. tostring(text):sub(1, 160)
            return
        end
        if seen[v] or depth > 3 then lines[#lines + 1] = path .. ': …'; return end
        seen[v] = true
        if next(v) == nil then lines[#lines + 1] = path .. ': {}'; return end
        local keys = {}
        for k in pairs(v) do
            if #keys >= 40 then break end
            keys[#keys + 1] = k
        end
        table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
        for _, k in ipairs(keys) do walk(v[k], path .. '.' .. tostring(k):sub(1, 60), depth + 1) end
    end
    walk(value, 'injuries', 0)
    if count >= 40 then lines[#lines + 1] = '… 表示上限'; end
    return table.concat(lines, '\n')
end
