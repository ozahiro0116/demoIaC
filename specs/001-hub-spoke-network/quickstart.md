# Quickstart: Hub-Spoke Network Infrastructure

**Feature**: 001-hub-spoke-network | **Date**: 2026-03-24

## Prerequisites

- Azure CLI 2.67+ with Bicep CLI 0.32+
- Azure サブスクリプション（Contributor ロール以上）
- `Microsoft.Network` および `Microsoft.OperationalInsights` リソースプロバイダーが登録済み

```powershell
# Azure CLI & Bicep バージョン確認
az version
az bicep version

# リソースプロバイダー登録確認
az provider show -n Microsoft.Network --query "registrationState"
az provider show -n Microsoft.OperationalInsights --query "registrationState"
```

## デプロイ手順

### 1. dev 環境のデプロイ

```powershell
# リソースグループ作成
az group create --name rg-hub-spoke-dev-eus2 --location eastus2

# lint チェック
az bicep lint --file infra/main.bicep

# バリデーション
az deployment group validate \
  --resource-group rg-hub-spoke-dev-eus2 \
  --template-file infra/main.bicep \
  --parameters infra/parameters/dev.bicepparam

# What-If 確認
az deployment group what-if \
  --resource-group rg-hub-spoke-dev-eus2 \
  --template-file infra/main.bicep \
  --parameters infra/parameters/dev.bicepparam

# デプロイ実行
az deployment group create \
  --resource-group rg-hub-spoke-dev-eus2 \
  --template-file infra/main.bicep \
  --parameters infra/parameters/dev.bicepparam \
  --name hub-spoke-dev-$(Get-Date -Format 'yyyyMMddHHmm')
```

### 2. prod 環境のデプロイ

```powershell
az group create --name rg-hub-spoke-prod-eus2 --location eastus2

az deployment group create \
  --resource-group rg-hub-spoke-prod-eus2 \
  --template-file infra/main.bicep \
  --parameters infra/parameters/prod.bicepparam \
  --name hub-spoke-prod-$(Get-Date -Format 'yyyyMMddHHmm')
```

## 検証手順

### SC-003: Firewall ルーティング確認

```powershell
# Spoke サブネットの effective routes を確認
az network nic show-effective-route-table \
  --resource-group rg-hub-spoke-dev-eus2 \
  --nic-name <spoke-vm-nic-name> \
  --output table
# → 0.0.0.0/0 の nextHop が Firewall Private IP であること
```

### SC-004: 診断ログ確認

```powershell
# Log Analytics で直近のログを確認
az monitor log-analytics query \
  --workspace log-hub-spoke-dev-eus2 \
  --analytics-query "AzureDiagnostics | where TimeGenerated > ago(5m) | summarize count() by ResourceType" \
  --output table
```

### SC-005: NSG Flow Log 確認

```powershell
az monitor log-analytics query \
  --workspace log-hub-spoke-dev-eus2 \
  --analytics-query "AzureNetworkAnalytics_CL | where TimeGenerated > ago(1h) | take 10" \
  --output table
```

### SC-006: Bastion 接続確認

Azure Portal → Bastion → Connect → Spoke VM の Private IP を指定 → ブラウザ SSH/RDP

## クリーンアップ

```powershell
# dev 環境削除
az group delete --name rg-hub-spoke-dev-eus2 --yes --no-wait

# prod 環境削除
az group delete --name rg-hub-spoke-prod-eus2 --yes --no-wait
```
