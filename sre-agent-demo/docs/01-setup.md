# 01. 環境準備（デモ前のセットアップ）

所要: 30〜45 分（インフラの初回デプロイ含む）。**インシデント・ループの「外」**の作業です。

## 前提
- Azure サブスクリプション（Contributor 以上）。`az login` 済み。
- .NET 8 SDK、Azure CLI、git。
- リポジトリ `ozahiro0116/demoIaC` をローカルにクローン済み。
- 既存 CI/CD（`bicep-ci.yml` / `bicep-cd.yml`）が使う OIDC シークレット
  （`AZURE_CLIENT_ID` / `AZURE_TENANT_ID` / `AZURE_SUBSCRIPTION_ID`）が GitHub に設定済み。
  - 未設定なら、フェデレーション資格情報付きのアプリ登録 or `azd` で用意。

## 手順

### 1) インフラを正常な状態でデプロイ
リポジトリの `bicep-cd.yml` が `infra/**` の push で `rg-web-sql-dev-eus2` にデプロイします。
初回は手動で実行しても構いません。

```powershell
az group create -n rg-web-sql-dev-eus2 -l eastus2 --tags environment=dev project=web-sql-app
az deployment group create `
  -g rg-web-sql-dev-eus2 `
  --template-file infra/main-web-sql.bicep `
  --parameters infra/parameters/web-sql-dev.bicepparam `
  --name "deploy-baseline"
```

> `web-sql-dev.bicepparam` の `sqlAdminUpn` / `sqlAdminObjectId` は自分のテナントの値に置き換えてください
> （既定値は別テナントの例です）。

### 2) サンプルアプリを配置（信号源）
本リポジトリの `sre-agent-demo/app` を App Service に配置します。

```powershell
cd sre-agent-demo/app-deploy
./deploy-app.ps1
```
これで App Service の **ヘルスチェックパスが `/health`** に設定され、App Service 自身が定期プローブを開始します。
数分後 `https://app-web-sql-dev-eus2.azurewebsites.net/` が「正常 (Healthy)」になればベースライン完成。

> 補足: `/health` は SQL への **TCP 1433 到達性**のみを見ます（DB ログインはしません）。
> そのため MI への DB ユーザー付与は不要で、NSG 起因の障害を決定論的に再現できます。

### 3) Azure Monitor アラートを作成
```powershell
az deployment group create `
  -g rg-web-sql-dev-eus2 `
  --template-file sre-agent-demo/alerts/healthcheck-alert.bicep `
  --parameters webAppName=app-web-sql-dev-eus2
# もしくは CLI 版: sre-agent-demo/alerts/deploy-alert.ps1
```

### 4) SRE Agent を作成し、リポジトリ／Azure／Azure Monitor／Runbook を接続
→ [02-connect-sre-agent-github.md](02-connect-sre-agent-github.md) へ。

## セットアップ完了チェック
- [ ] `https://app-web-sql-dev-eus2.azurewebsites.net/` が「正常 (Healthy)」
- [ ] `/health` が 200・`resolvedIp` が `10.20.2.x`
- [ ] メトリックアラート `alert-db-connectivity-...` が作成済み（状態: 正常）
- [ ] SRE Agent にリポジトリ・Azure リソース・Azure Monitor・Runbook を接続済み
- [ ] 応答計画を **Review モード** で作成済み
