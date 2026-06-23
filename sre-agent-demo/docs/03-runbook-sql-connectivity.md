# Runbook: Web App → SQL Database 接続障害（HealthCheckStatus 低下）

> このファイルは Azure SRE Agent の **ナレッジ（Runbook）** として登録します。
> エージェントはアラート発火時にこの手順に沿って調査・修正します。
> 登録方法は [docs/02-connect-sre-agent-github.md](../docs/02-connect-sre-agent-github.md) を参照。

## 対象アラート
- 名称: `alert-db-connectivity-app-web-sql-dev-eus2`
- 種別: App Service メトリック `HealthCheckStatus` が 100 未満
- 意味: Web App が `/health` で SQL Database への到達性確認に失敗している

## 対象システム（demoIaC / web-sql-dev）
- Web App: `app-web-sql-dev-eus2`（Windows / .NET 8 / VNet 統合 / システム割当 MI）
- SQL: `sql-web-sql-dev-eus2.database.windows.net`（publicNetworkAccess=Disabled、**Private Endpoint 経由のみ**）
- VNet: `vnet-web-sql-dev-eus2`
  - App Service サブネット NSG: `nsg-appsvc-web-sql-dev-eus2`
  - Private Endpoint サブネット NSG: `nsg-pe-web-sql-dev-eus2`
- IaC リポジトリ: `ozahiro0116/demoIaC`（Bicep）。ネットワーク定義は `infra/modules/web-sql-network.bicep`

## 調査手順（この順に確認すること）

1. **症状の確認**
   - `app-web-sql-dev-eus2` の `/health` 応答と本文を確認する。
   - `resolvedIp` が `10.20.2.x`（Private Endpoint のプライベート IP）なら **DNS は正常**。
   - `error` に `TCP connect to 10.20.2.x:1433 timed out` があれば **ポート到達性の問題**（DNS ではない）。

2. **最近の変更（デプロイ）を相関分析**
   - `infra/**` への直近のコミット／PR を確認する。
   - ネットワーク（NSG / ルート / Private Endpoint / Private DNS）に関わる変更を最優先で疑う。

3. **NSG 送信規則の確認（最有力）**
   - `infra/modules/web-sql-network.bicep` の `nsgAppSvc` を読む。
   - 送信規則 `AllowSqlOutbound`（宛先 1433 / 宛先=PEサブネット）の `access` を確認する。
   - `access: 'Deny'` になっていれば、それが **根本原因**。本来 `Allow` であるべき。

4. **依存チェーンの裏取り（早合点しないこと）**
   - SQL 側 `publicNetworkAccess`（Disabled が正）、Private Endpoint、Private DNS Zone link が
     正しいことも確認し、NSG 以外に同時障害がないことを確認する。
   - 「この NSG を Allow に戻せば本当に直るか？」を自問してから結論する。

## 是正アクション（Review モード=各操作で承認を求める）

1. 修正ブランチ `fix/restore-sql-egress` を作成。
2. `infra/modules/web-sql-network.bicep` の `AllowSqlOutbound` を `access: 'Deny'` → `'Allow'` に戻す（**1 行**）。
3. コミットしてプッシュ。追跡用の GitHub Issue を起票。
4. **Pull Request を作成**（base: `main`）。
   - PR 作成で CI（`bicep-ci.yml`）が走り、What-If 差分が PR に自動コメントされる。
   - What-If に「NSG セキュリティ規則 access: Deny → Allow」の差分が出ることを確認する。
5. 人間がレビュー＆承認し、**マージ**（ヒューマン・イン・ザ・ループ）。
6. マージ後、`bicep-cd.yml` が `main` への push を検知して **自動再デプロイ**。

## 検証（修復確認）
- `HealthCheckStatus` が 100 に回復し、アラートが自動解決（autoMitigate）すること。
- `/health` が 200 / `status: Healthy` を返すこと。

## 修復サマリに含める項目
- アラート / 即時影響 / 恒久対策（PR リンク）/ 根本原因（ファイル・行）/ 現在の正常性 / 追跡（Issue 番号）/ 次のステップ

## 禁止・注意
- **人間の承認なしに本番へ変更を適用しない**（Review モード前提）。
- 単一の「それらしい原因」で止めない。NSG・DNS・PE・publicNetworkAccess を順に列挙して裏取りする。
