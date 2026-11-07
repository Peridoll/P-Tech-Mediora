# タブレット起動修正版 0.2.1

このフォルダー全体が ptech_mediora_core の内容です。
稼働側へは config.lua・fxmanifest.lua・main をまとめて反映してください。
config.lua はリソース直下に置きます。

アイテム名は pmediora_tablet、呼び出し先は ptech_mediora_core.useTablet。
ox_inventory の data/items.lua には install/item_install.lua の項目を統合します。
画像は install/ox_inventory/web/images/pmediora_tablet.png を
ox_inventory/web/images/ に配置します。

Core差し替え後にサーバーコンソールで restart ptech_mediora_core を実行。
アイテム定義も変更した場合、開発サーバーで ox_inventory の再起動も必要です。

F8に次の2行が出ることを確認してください。

    [ptech_mediora_core] Tablet 0.2.1: useTablet registered (item=pmediora_tablet)
    [ptech_mediora_core] Tablet 0.2.1: UI ready

1行目がなければ修正版のクライアント処理が読み込まれていません。
1行目だけならNUIの読み込み・初期化を確認してください。
両方出て使用できない場合は、使用時の通知とF8ログを確認してください。

ゲーム内での起動は未検証です。
