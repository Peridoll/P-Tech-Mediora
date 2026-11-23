Framework = {}

function Framework.ESX()
    return GetResourceState("es_extended") ~= "missing"
end

-- NOVILL: Qbox（qbx_core）を検出
function Framework.Qbox()
    return GetResourceState("qbx_core") ~= "missing"
end

-- NOVILL: Qbox が入っている場合は QBCore 用の処理を使わない（qb-core ブリッジの二重読み込み防止）
function Framework.QBCore()
    if Framework.Qbox() then return false end
    return GetResourceState("qb-core") ~= "missing"
end

function Framework.Ox()
    return GetResourceState("ox_core") ~= "missing"
end
