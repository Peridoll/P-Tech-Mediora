# 共通サイドバーの接続

CORE 0.2.3は、Luaで保持しているパネルを、NUIの準備完了時と再読み込み時に登録順で再送します。
ブラウザーからの `actionPanelReady` が届く前は、パネルの登録・更新・削除をLua側へ保存します。
NUIが起動する前に外部リソースから登録されても表示内容を失いません。

利用側はmanifestに `ptech_mediora_core` の依存を記載し、クライアントから以下を呼びます。

```lua
exports['ptech_mediora_core']:setActionPanel({
    id = 'rescue',
    title = '緊急離脱',
    icon = 'R',
    state = 'waiting',
    text = '使用可能まで 5:00',
    progress = 0,
    temporaryExpand = true,
})
```

戻り値のtrueはCOREが登録を受理したことを表し、CEFでの描画完了を表すものではありません。
UI準備前に登録した場合は、COREが準備完了後に自動で送ります。利用側は自身の状態変更時に更新し、
利用終了時には `removeActionPanel('rescue')` を呼びます。CORE再起動時は利用側から再登録します。

`temporaryExpand = true` は折りたたみ状態のサイドバーを一時的に開きます。待機から操作可能状態へ
移る間も開いたままにする場合は、どちらにもtrueを指定します。削除すると元の表示状態へ戻ります。

NUIの初回接続に失敗した場合、app.jsは300ms後に再接続します。準備完了時にはF8に以下を出します。

```text
[ptech_mediora_core] action panel READY build=panel-sync-v1 replayed=1
```

replayedは準備完了時に再送したパネル数です。0は登録パネルがなかったことを表します。
旧版で欠けていた準備完了時の再送と、NUIコールバック登録前に初回接続が失敗する場合の再試行を
`ptech_mediora_rescue/dev/tests/test_core_connection.py` で検証しています。実際のCOREのLuaとJSを使用し、
FiveMネイティブとブラウザーDOMはモックに置き換えています。
