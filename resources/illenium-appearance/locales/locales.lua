Locales = {}

-- NOVILL: 既定の言語を日本語に変更（server.cfg の setr illenium-appearance:locale で上書き可）
function GetLocaleLang()
    local lang = GetConvar("illenium-appearance:locale", "ja")
    if not Locales[lang] then
        lang = Locales["ja"] and "ja" or "en"
    end
    return lang
end

function _L(key)
    local value = Locales[GetLocaleLang()]
    for k in key:gmatch("[^.]+") do
        value = value[k]
        if not value then
            print("Missing locale for: " .. key)
            return ""
        end
    end
    return value
end
