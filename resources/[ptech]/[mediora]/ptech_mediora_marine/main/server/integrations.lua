-- 外部の搬送リソースから呼べる、サーバー側の稼働状態照会。
-- 呼び出し例: exports.ptech_mediora_marine:getExternalTransportResourceState('resource_name')
exports('getExternalTransportResourceState', function(resourceName)
    if type(resourceName) ~= 'string' or resourceName == '' then return nil end
    return GetResourceState(resourceName)
end)
