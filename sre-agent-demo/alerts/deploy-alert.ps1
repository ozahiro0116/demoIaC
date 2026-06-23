# ============================================================================
# deploy-alert.ps1 — Azure Monitor アラートを CLI でデプロイ（Bicep を使わない版）
#
# App Service の HealthCheckStatus メトリックに対するメトリックアラートを作成する。
# 値が 100 を下回ったら発火 = SQL 到達不可。
# ============================================================================

param(
    [string]$ResourceGroup = "rg-web-sql-dev-eus2",
    [string]$WebAppName    = "app-web-sql-dev-eus2"
)

$ErrorActionPreference = "Stop"

$webAppId = az webapp show -g $ResourceGroup -n $WebAppName --query id -o tsv

Write-Host "==> メトリックアラートを作成（HealthCheckStatus < 100）" -ForegroundColor Cyan
az monitor metrics alert create `
    --name "alert-db-connectivity-$WebAppName" `
    --resource-group $ResourceGroup `
    --scopes $webAppId `
    --description "受発注API: SQL Database への接続(到達性)が失われ、ヘルスチェックが低下しています。" `
    --severity 1 `
    --evaluation-frequency 1m `
    --window-size 5m `
    --condition "avg HealthCheckStatus < 100" `
    --auto-mitigate true `
    --output none

Write-Host "完了。Azure Portal > $WebAppName > アラート で確認できます。" -ForegroundColor Green
Write-Host "※ SRE Agent 側で Azure Monitor をインシデント基盤として接続し、応答計画でこのアラートを対象にしてください。" -ForegroundColor Yellow
