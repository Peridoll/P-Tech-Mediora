# P-Tech Mediora

> このREADMEは、P-Tech Medioraリポジトリ内で唯一の正式なMarkdown文書です。
> 実装状況、導入条件、開発方針、試験状況はここを基準に管理します。

**管理上の基準版:** 2026-10-19
**リリース状況:** 開発・検証中。実機合格前のため、本番導入版ではありません。

## 目的

Medioraは、FiveMサーバー向けのP-Tech医療製品群です。各機能は原則として独立したFiveMリソースとして提供し、必要な場合だけ連携します。

リソース名は ptech_mediora_<module> を使用します。共通機能が将来必要になった場合のみ、明示した依存関係を持つ ptech_mediora_core を追加します。

## リポジトリ構成

    resources/[ptech]/[mediora]/  FiveMリソース
    tests/                        静的なソース確認
    README.md                     正式な開発資料

個別リソースのREADMEや docs/ は置きません。仕様や実装状況が変わったときは、このREADMEを更新します。

## ブランチとコミットの運用

- main は確認済みの基準版です。
- develop は次回の統合先です。基準版を作成した直後は main と同じ内容にします。
- 機能ごとの作業は feature/ または fix/ ブランチで行い、統合後は削除します。
- 1つの変更目的につき、コード・設定・README・必要な試験をまとめて1コミットにします。
- ファイルを追加するたびのコミットは行いません。PRに修正コミットが重なった場合は、統合時にSquashして履歴を読みやすく保ちます。

## モジュール一覧と現在の状態

| リソース | 現在の役割 | 状態 |
|---|---|---|
| ptech_mediora_medical | 患者の診察、Wasabi Ambulanceの負傷情報の参照、診断書アイテム発行 | 診察・診断書の初期実装 |
| ptech_mediora_escort | 行動不能者の搬送、車両への移送 | 抽出済みの試作実装 |
| ptech_mediora_patients | 来院NPCとテスト用NPC | クライアントローカルの試作実装 |
| ptech_mediora_procurement | 医療素材の受注・運搬・病院倉庫への納品 | 試作実装。精算はしない |
| ptech_mediora_pharmacy | 医療素材からの個人インベントリ製薬 | 試作実装。病院倉庫とは未連携 |
| ptech_mediora_billing | 医療請求の下書き保存 | 試作実装。決済はしない |
| ptech_mediora_settlement | 調達レシートの確認キュー | 試作実装。送金はしない |

すべてのリソースで、FiveM実機・Qbox・ox系リソース・Wasabi Ambulanceとの結合試験は完了していません。

## Medicalの現行実装

### 実装されている入口

ptech_mediora_medical は、初期設定では勤務中の ambulance JOBが /pmedical を実行したとき、3m以内の最寄りプレイヤーを診察対象にします。

サーバーはJOB、勤務状態、距離、ルーティングバケットを確認します。クライアント側ではWasabi Ambulanceの diagnosePlayer を呼び、結果をNUIまたはox_libのコンテキスト画面に渡します。診察が許可された場合、ptech_diagnosis を ox_inventory に発行します。

この基準版には、未統合だった「患者名をアイテム名に付ける」「担当医の階級を保存する」「インベントリ説明から診療内容を隠す」変更は含めません。

### 未実装

次の機能は、コード内の設定・構想が存在しても実装済みではありません。

- ox_targetや診察アイテムからの診察開始
- 診察アニメーション、進捗表示、途中キャンセル
- 傷別の治療、医療品消費、重症度処理、患者拒否
- 高度検査、除細動器、Wasabiの傷状態への治療反映
- 診断記録、okokBillingへの請求発行、支払い処理
- 病院ショップ、EMS車両トランクショップ

### 現在判明している実機状況

2026-10-17の確認では、診察開始は行われた一方で、診察アニメーションは再生されず、NUIも開きませんでした。

現行ソースにも診察アニメーション処理はありません。NUIの表示処理はありますが、実際にサーバーへ導入されているファイルとこの基準版が一致するか、Wasabiの返却値・NUIコールバック・F8エラーを含めて調査が必要です。

## 依存関係と導入

共通してQbox系環境と ox_lib を利用します。各リソースの依存関係は fxmanifest.lua を正とします。

| リソース | 追加の主な依存先 |
|---|---|
| Medical | qbx_core、wasabi_ambulance、ox_inventory、OneSync |
| Escort | qbx_core、ox_target、OneSync |
| Patients | qbx_core、ox_target、OneSync |
| Procurement | qbx_core、ox_inventory、ox_target、OneSync |
| Pharmacy | qbx_core、ox_inventory、ox_target |
| Billing | qbx_core、oxmysql |
| Settlement | qbx_core、ox_inventory、oxmysql |

Medicalを試験導入する場合は、次を行います。

1. ox_inventory の既存アイテム定義に ptech_diagnosis を追加する。
2. resources/[ptech]/[mediora]/ptech_mediora_medical をサーバーのresourcesへ配置する。
3. 依存リソースの後に ensure ptech_mediora_medical を記述する。
4. 旧 ptech_medical の診察機能を停止し、/pmedicalやイベントが重複しない状態にする。
5. 許可JOB・勤務状態・距離・同一バケットの2人で実機確認する。

BillingとSettlementを試験導入する場合は、それぞれの install.sql を対象データベースへ適用します。ただし、どちらも決済・送金を行う実装ではありません。

## 開発の優先順

1. サーバーへ入っているMedicalとこの基準版の一致を確認する。
2. /pmedicalのNUI表示不具合を再現し、F8・サーバーログ・Wasabi v1の返却値を確認する。
3. ターゲットと診察アイテムの入口、診察アニメーション、キャンセルを実装・実機試験する。
4. Wasabi v1で利用できる傷・治療・蘇生APIを確定する。
5. サーバー側の同時処置ロック、消費、失敗時の復元を設計する。
6. 治療UI、診断記録、請求、ショップを順に実装する。

実機で合格するまで、各機能を「仕様確定」「実装済み」「静的確認済み」「実機合格」に分けて管理します。

## 試験

この基準版では、次の静的確認を実行済みです。

    python -m unittest discover -s tests -p 'test_*.py'
    node --check 'resources/[ptech]/[mediora]/ptech_mediora_medical/web/app.js'
    node --check 'resources/[ptech]/[mediora]/ptech_mediora_procurement/web/app.js'

静的試験は、マニフェストで指定されたファイルの存在、7リソースの独立性、請求・精算モジュールに送金コードがないこと、Markdown文書がこのREADMEだけであることを確認します。FiveM実機での動作保証にはなりません。

## 更新ルール

機能、導入手順、依存関係、実機試験結果を変更したときは、このREADMEも同じコミットで更新します。新しいMarkdown文書を追加する場合は、ここへ統合してから追加の必要性を判断します。
