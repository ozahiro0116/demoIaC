# 05. 後片付け / 手動フォールバック

## デモ後のリセット（次回のために正常へ戻す）
SRE Agent の PR がマージ済みなら `main` は既に正常です。`chaos/lockdown-sql-egress`
ブランチが残っていれば削除します。

```powershell
git branch -D chaos/lockdown-sql-egress 2>$null
git push origin --delete chaos/lockdown-sql-egress 2>$null
```

## 手動で即時復旧したい場合（デモ中に CD を待てないとき）
NSG 規則を CLI で直接 Allow に戻す（IaC とドリフトするので、後で main を正にそろえること）:

```powershell
az network nsg rule update `
  -g rg-web-sql-dev-eus2 `
  --nsg-name nsg-appsvc-web-sql-dev-eus2 `
  -n AllowSqlOutbound `
  --access Allow
```

## アラートを止める / 削除する
```powershell
az monitor metrics alert delete `
  -g rg-web-sql-dev-eus2 -n alert-db-connectivity-app-web-sql-dev-eus2
```

## 環境ごと削除（課金停止）
```powershell
az group delete -n rg-web-sql-dev-eus2 --yes --no-wait
```
> SRE Agent 本体は別リソースグループです。不要なら sre.azure.com / Portal から別途削除してください。
