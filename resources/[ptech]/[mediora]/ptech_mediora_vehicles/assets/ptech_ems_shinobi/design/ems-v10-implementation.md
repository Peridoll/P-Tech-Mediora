# 承認済みシノビ案の塗装実装 v10 — 2026-11-14

基準画像: shinobi-design/concepts/shinobi-model-based-ems-concept-v1.png

変更内容:
- 白いタンクを維持し、段差の下にNOVILL EMSロゴを配置。
- ロゴ元画像の透明余白をSVGのviewBoxで除外し、文字とマークを実寸で大きく配置。ロゴ自体の描き直しはしていません。
- フロント側の赤い切り返し、下側の赤い流線と細い黒線、後部の赤い面と淡いドラゴン。
- 赤いボックス表示に白い救命マーク。ボックスの実頂点・UVからX/Yの1ピクセルの物理寸法比が1.0043と分かるため、以前の横2.5倍の引き伸ばしを削除。
- ボックスのmatDiffuseColorを (2,5,5,0) から (1,1,1,0) に変更。画像とは別の緑青への色補正を外しています。固有テクスチャ名は維持。

更新対象はVehicles内の以下2ファイルだけです:
stream/mods/liveries/pems_shinobi_livery_ems.yft
stream/mods/liveries/pems_shinobi_box_ems.yft

リバリー登録、コマンド、車両モデル本体、fxmanifest.lua、qbx_coreは今回変更していません。

ユーザー側で上記を反映後、Vehiclesを再起動し、新しく出した pems_shinobi の運転席で /pemsuv off と /pemslivery を実行してください。クライアント側に旧ストリームが残る場合は再接続してから確認してください。

実際のゲーム内描画は未確認です。ボックスの材質とマーク比率は元データから補正、車体のロゴ・赤ラインはチェック柄の実車画像から配置しています。生成したイラストとゲームモデルの完全一致を保証するものではありません。

バックアップ: backups/shinobi-before-v10-20261114
読み取り形式の参考: https://github.com/dexyfex/CodeWalker/blob/master/CodeWalker.Core/GameFiles/Resources/Drawable.cs
パラメーター名の参考: https://github.com/dexyfex/CodeWalker/blob/master/CodeWalker.Core/GameFiles/MetaTypes/MetaNames.cs

WinSCP・リモートサーバーは操作していません。