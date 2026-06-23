# ============================================================================
# deploy-app.ps1 — サンプルアプリを App Service に配置する（デモ準備の一回限り）
#
# 前提:
#   - infra (main-web-sql.bicep) が rg-web-sql-dev-eus2 に既にデプロイ済み
#   - .NET 8 SDK / Azure CLI がインストール済み、az login 済み
#
# このスクリプトは「インシデント・ループの外」のセットアップです。
# 実行後、アプリは常駐し、/health が SQL 到達性を返すようになります。
# ============================================================================

param(
    [string]$ResourceGroup = "rg-web-sql-dev-eus2",
    [string]$WebAppName    = "app-web-sql-dev-eus2",
    [string]$SqlFqdn       = "sql-web-sql-dev-eus2.database.windows.net"
)

$ErrorActionPreference = "Stop"
$appDir = Join-Path $PSScriptRoot "..\app"
$publishDir = Join-Path $env:TEMP "sredemo-publish"
$zipPath = Join-Path $env:TEMP "sredemo.zip"

Write-Host "==> 1) dotnet publish" -ForegroundColor Cyan
if (Test-Path $publishDir) { Remove-Item $publishDir -Recurse -Force }
dotnet publish $appDir -c Release -o $publishDir

Write-Host "==> 2) zip 作成" -ForegroundColor Cyan
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
Compress-Archive -Path (Join-Path $publishDir "*") -DestinationPath $zipPath

Write-Host "==> 3) アプリ設定 (SQL_SERVER_FQDN) を投入" -ForegroundColor Cyan
az webapp config appsettings set `
    --resource-group $ResourceGroup --name $WebAppName `
    --settings SQL_SERVER_FQDN=$SqlFqdn SQL_PORT=1433 HEALTH_TIMEOUT_MS=5000 `
    --output none

Write-Host "==> 4) zip デプロイ" -ForegroundColor Cyan
az webapp deploy `
    --resource-group $ResourceGroup --name $WebAppName `
    --src-path $zipPath --type zip --output none

Write-Host "==> 5) App Service ヘルスチェックを /health に設定" -ForegroundColor Cyan
# App Service 自身が /health を定期プローブし、HealthCheckStatus メトリックを発行する。
# これが Azure Monitor アラートの信号源になる（外部の負荷生成は不要）。
az webapp config set `
    --resource-group $ResourceGroup --name $WebAppName `
    --generic-configurations '{\"healthCheckPath\": \"/health\"}' `
    --output none

$hostName = az webapp show -g $ResourceGroup -n $WebAppName --query defaultHostName -o tsv
Write-Host ""
Write-Host "完了。ブラウザで確認: https://$hostName/" -ForegroundColor Green
Write-Host "ヘルス:               https://$hostName/health" -ForegroundColor Green
Write-Host ""
Write-Host "数分後、App Service の HealthCheckStatus が 100(正常) になればベースライン完成です。" -ForegroundColor Yellow
