-- 導入先: ox_inventory/data/items.lua
-- この定義を既存の return { ... } の中へ追加してください。
return {
    ['ptech_mediora_rescue_fins'] = {
        label = '救助用フィン',
        weight = 500,
        stack = false,
        close = true,
        consume = 0,
        description = '装備中、水中で泳ぐ速度が上がる',
        client = { export = 'ptech_mediora_marine.toggleFins' },
    },
}
