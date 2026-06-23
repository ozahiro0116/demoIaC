# 障害注入（Chaos）— SQL 送信を NSG で遮断する

「セキュリティ強化のつもりで App Service サブネットの送信規則を締めたら、本番の DB 接続が落ちた」
という、インフラ現場で定番の事故を再現します。**修正は 1 行**で、What-If 差分も明快です。

---

## 何を変えるか

対象ファイル: **`infra/modules/web-sql-network.bicep`**
対象規則: App Service サブネット NSG (`nsg-appsvc-web-sql-dev-eus2`) の送信規則 `AllowSqlOutbound`

`access: 'Allow'` → `access: 'Deny'` に変更します（ポート 1433／宛先=PEサブネット は据え置き）。

### Before（正常）
```bicep
{
  name: 'AllowSqlOutbound'
  properties: {
    priority: 100
    direction: 'Outbound'
    access: 'Allow'          // ← これを Deny にする
    protocol: 'Tcp'
    sourcePortRange: '*'
    destinationPortRange: '1433'
    sourceAddressPrefix: 'VirtualNetwork'
    destinationAddressPrefix: privateEndpointSubnetPrefix
  }
}
```

### After（障害注入後）
```bicep
{
  name: 'AllowSqlOutbound'
  properties: {
    priority: 100
    direction: 'Outbound'
    access: 'Deny'           // ★ Chaos: 1433 送信を遮断（接続障害を誘発）
    protocol: 'Tcp'
    sourcePortRange: '*'
    destinationPortRange: '1433'
    sourceAddressPrefix: 'VirtualNetwork'
    destinationAddressPrefix: privateEndpointSubnetPrefix
  }
}
```

---

## 障害を注入する手順（デモ開始の少し前に実施）

リポジトリ（ozahiro0116/demoIaC）のローカルクローンで実行します。

```powershell
# 1) chaos ブランチを作成
git checkout main
git pull
git checkout -b chaos/lockdown-sql-egress

# 2) infra/modules/web-sql-network.bicep の AllowSqlOutbound を Deny に変更
#    （上記 After のとおり。エディタで access: 'Allow' → 'Deny'）

# 3) コミット（"セキュリティ強化" を装う、リアルなコミットメッセージ）
git add infra/modules/web-sql-network.bicep
git commit -m "security: tighten App Service egress (lock down outbound to private subnets)"

# 4) main に取り込む（=本番に悪い変更が入った状態を作る）
git checkout main
git merge chaos/lockdown-sql-egress
git push origin main
```

push すると `bicep-cd.yml`（push to main / infra/**）が走り、NSG が再デプロイされます。
**数分で App Service → SQL の TCP 1433 が遮断され、`/health` が 503 になり、`HealthCheckStatus` が低下します。**

> デモを「アラート発火済み」の状態から始めたい場合は、開始 10〜15 分前にこの注入を済ませておくと、
> ちょうど Azure Monitor アラートが発火したところから実演できます。

---

## 期待される症状（SRE Agent が観測するもの）

| シグナル | 値 |
| --- | --- |
| App Service `HealthCheckStatus` | 100 → 0（全インスタンス不健全） |
| `/health` HTTP ステータス | 200 → **503** |
| `/health` の error フィールド | `TCP connect to 10.20.2.x:1433 timed out ... (NSG/route blocked?)` |
| Azure Monitor アラート | 「DB接続不可（HealthCheckStatus低下）」が発火 |

DNS は引き続きプライベート IP（10.20.2.x）を返すため、「名前解決は正常／ポート到達が不可」という、
NSG 起因を強く示唆する切り分け情報が `/health` に出ます。

---

## 元に戻す（手動フォールバック）

デモ本番では **SRE Agent が修正 PR を出し、人間がマージ → CD が自動復旧** させます（これが見せ場）。
万一その場で戻したい場合の手動手順は [05-cleanup.md](../docs/05-cleanup.md) を参照。
