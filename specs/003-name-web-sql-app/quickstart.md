# Quickstart: Web App + SQL Database on Azure (AVM)

**Feature**: 003-name-web-sql-app | **Date**: 2026-03-24

## Prerequisites

- Azure CLI 2.67+ with Bicep CLI 0.32+
- Azure サブスクリプション（Contributor ロール以上）
- `Microsoft.Web`、`Microsoft.Sql`、`Microsoft.Network`、`Microsoft.OperationalInsights`、`Microsoft.Insights` リソースプロバイダーが登録済み
- デプロイ者の Entra ID オブジェクト ID（SQL Server 管理者設定用）

```powershell
# Azure CLI & Bicep バージョン確認
az version
az bicep version

# リソースプロバイダー登録確認
az provider show -n Microsoft.Web --query "registrationState"
az provider show -n Microsoft.Sql --query "registrationState"
az provider show -n Microsoft.Network --query "registrationState"
az provider show -n Microsoft.OperationalInsights --query "registrationState"
az provider show -n Microsoft.Insights --query "registrationState"

# デプロイ者の UPN とオブジェクト ID を取得
az ad signed-in-user show --query "{upn:userPrincipalName, objectId:id}" -o table
```

## デプロイ手順

### 1. dev 環境のデプロイ

```powershell
# リソースグループ作成
az group create --name rg-web-sql-dev-eus2 --location eastus2

# web-sql-dev.bicepparam 内の sqlAdminUpn / sqlAdminObjectId を自分の値に更新

# lint チェック
az bicep lint --file infra/main-web-sql.bicep

# バリデーション
az deployment group validate `
  --resource-group rg-web-sql-dev-eus2 `
  --template-file infra/main-web-sql.bicep `
  --parameters infra/parameters/web-sql-dev.bicepparam

# What-If 確認
az deployment group what-if `
  --resource-group rg-web-sql-dev-eus2 `
  --template-file infra/main-web-sql.bicep `
  --parameters infra/parameters/web-sql-dev.bicepparam

# デプロイ実行
az deployment group create `
  --resource-group rg-web-sql-dev-eus2 `
  --template-file infra/main-web-sql.bicep `
  --parameters infra/parameters/web-sql-dev.bicepparam `
  --name web-sql-dev-$(Get-Date -Format 'yyyyMMddHHmm')
```

### 2. prod 環境のデプロイ

```powershell
az group create --name rg-web-sql-prod-eus2 --location eastus2

az deployment group create `
  --resource-group rg-web-sql-prod-eus2 `
  --template-file infra/main-web-sql.bicep `
  --parameters infra/parameters/web-sql-prod.bicepparam `
  --name web-sql-prod-$(Get-Date -Format 'yyyyMMddHHmm')
```

## デプロイ後の手動ステップ

### Managed Identity への SQL 権限付与

Web App の Managed Identity に SQL Database の `db_datareader` / `db_datawriter` ロールを付与する。これは Bicep では直接サポートされないため、SQL コマンドで実行する。

```powershell
# Web App の Managed Identity プリンシパル ID を取得
$principalId = az deployment group show `
  --resource-group rg-web-sql-dev-eus2 `
  --name <deployment-name> `
  --query "properties.outputs.webAppManagedIdentityPrincipalId.value" -o tsv

# SQL Database に接続して権限を付与（sqlcmd または Azure Portal Query Editor）
# ※ Entra ID 管理者として認証済みである必要がある
```

```sql
-- SQL Database で実行
CREATE USER [app-web-sql-dev-eus2] FROM EXTERNAL PROVIDER;
ALTER ROLE db_datareader ADD MEMBER [app-web-sql-dev-eus2];
ALTER ROLE db_datawriter ADD MEMBER [app-web-sql-dev-eus2];
```

## 検証手順

### SC-003: Web App HTTPS アクセス確認

```powershell
# Web App のデフォルトホスト名を取得
$hostname = az deployment group show `
  --resource-group rg-web-sql-dev-eus2 `
  --name <deployment-name> `
  --query "properties.outputs.webAppDefaultHostname.value" -o tsv

# HTTPS アクセステスト
curl -s -o /dev/null -w "%{http_code}" "https://$hostname"
# → 200 が期待値
```

### SC-004: Private Endpoint 経由のみ確認

```powershell
# SQL Server のパブリックネットワークアクセスが無効であることを確認
az sql server show `
  --resource-group rg-web-sql-dev-eus2 `
  --name sql-web-sql-dev-eus2 `
  --query "publicNetworkAccess"
# → "Disabled" が期待値

# Private Endpoint の接続状態を確認
az network private-endpoint show `
  --resource-group rg-web-sql-dev-eus2 `
  --name pep-sql-web-sql-dev-eus2 `
  --query "privateLinkServiceConnections[0].privateLinkServiceConnectionState.status"
# → "Approved" が期待値
```

### SC-005: Managed Identity 接続テスト

```powershell
# Web App の Kudu コンソールまたは SSH から接続テスト
# （権限付与手動ステップ完了後）
az webapp ssh --resource-group rg-web-sql-dev-eus2 --name app-web-sql-dev-eus2
```

### SC-006: 診断ログ確認

```powershell
# Log Analytics で直近のログを確認（デプロイ後 5 分以上待つ）
az monitor log-analytics query `
  --workspace rg-web-sql-dev-eus2/log-web-sql-dev-eus2 `
  --analytics-query "AzureDiagnostics | take 10" `
  --timespan PT1H
```

### SC-007: Application Insights テレメトリ確認

```powershell
# Web App にリクエストを送信後、Azure Portal → Application Insights で確認
curl "https://app-web-sql-dev-eus2.azurewebsites.net"
# → Application Insights のライブメトリクスまたはトランザクション検索でリクエストトレースが表示されること
```

## クリーンアップ

```powershell
# dev 環境のリソースグループごと削除
az group delete --name rg-web-sql-dev-eus2 --yes --no-wait

# prod 環境のリソースグループごと削除
az group delete --name rg-web-sql-prod-eus2 --yes --no-wait
```
