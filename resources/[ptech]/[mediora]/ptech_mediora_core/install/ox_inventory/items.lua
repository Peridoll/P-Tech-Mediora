-- 【導入先】ox_inventory/data/items.lua の既存 return { ... } 内へ統合する。
-- このファイルは抜粋。ファイル全体で既存 items.lua を上書きしない。
-- pmediora_tablet が登録済みなら同じ項目を編集し、二重登録しない。
-- consume=0 と client.export='ptech_mediora_core.useTablet' を維持する。
-- client.image はCoreの公開GitHub画像URL。web/images への画像配置は不要。
-- 反映はサーバー再起動とクライアント再接続で確認する。

  ['pmediora_tablet'] = {
    label   = '医療端末',
    weight  = 500,
    stack   = false,
    close   = true,
    consume = 0,
    description = '',
    client = {
      image = 'https://raw.githubusercontent.com/Peridoll/P-Tech-Mediora/feature/dev/resources/%5Bptech%5D/%5Bmediora%5D/ptech_mediora_core/install/ox_inventory/images/pmediora_tablet.png',
      export = 'ptech_mediora_core.useTablet',
    },
  },
