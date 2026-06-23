# 02. SRE Agent の作成と GitHub／Azure 接続

このデモの「接続」をすべて行います。出典は各見出しの公式ドキュメントです。
（UI はプレビューで更新されることがあるため、文言が違う場合は公式手順に従ってください。）

> 重要な前提（公式）: **SRE Agent は人間の承認なしに変更を本番適用しません。**
> PR 作成は **Review もしくは Autonomous モード**が必要です。本デモは **Review** を使います。
> 出典: [Overview](https://learn.microsoft.com/azure/sre-agent/overview) ／
> [Connect source code](https://learn.microsoft.com/azure/sre-agent/connect-source-code)

---

## A. エージェントを作成する
出典: [Create and set up Azure SRE Agent](https://learn.microsoft.com/azure/sre-agent/create-and-set-up)

1. ブラウザで [https://sre.azure.com](https://sre.azure.com) を開き、Azure 資格情報でサインイン
   （`*.azuresre.ai` への到達が必要）。
2. オンボーディング ウィザードで **Basics → Review → Deploy**。
   - サブスクリプション / リソースグループ / リージョンを選択。
   - 前提: サブスクリプションの **Contributor**（ロール割り当て作成には Owner / User Access Administrator）。
3. デプロイ完了後 **「Set up your agent」** を開く。

## B. コードリポジトリを接続（Code Access）
出典: [GitHub connector](https://learn.microsoft.com/azure/sre-agent/github-connector) ／
[Connect source code](https://learn.microsoft.com/azure/sre-agent/connect-source-code)

1. **Quickstart** タブの **Code** カードで **＋** を選択。
2. プラットフォーム **GitHub** を選択 → サインイン方法 **Auth（OAuth）** または **PAT**（`repo` スコープ）。
3. リポジトリ一覧から **`ozahiro0116/demoIaC`** を選び **Add repository**。
   - これで Bicep / IaC をエージェントが解析できる（「Identify IaC files」）。

## C. GitHub コネクタを追加（Issue / PR / Actions 操作）
出典: [GitHub connector](https://learn.microsoft.com/azure/sre-agent/github-connector)

1. **Builder > Connectors > Add connector** で **GitHub** を選ぶ。
2. 認証（OAuth / PAT / BYO GitHub App のいずれか。`github.com` は 3 方式とも可）。
3. これにより、エージェントは **Issue 作成・PR 作成/マージ確認・GitHub Actions の起動と追跡** が可能になる。

> Code Access（B）と GitHub コネクタ（C）は役割が違います。B は「読む」、C は「Issue/PR/Actions を操作する」。両方つなぎます。

## D. Azure リソースへの Reader 権限を付与
出典: [Create and set up（Full setup）](https://learn.microsoft.com/azure/sre-agent/create-and-set-up#set-up-your-agent)

1. セットアップの **Full setup** タブ → **Azure Resources** で、`rg-web-sql-dev-eus2`
   （または当該サブスクリプション）に **Reader** を付与。
   - メトリック・ログ・構成（NSG / Web App / SQL）の調査に必要。

## E. インシデント基盤に Azure Monitor を接続
出典: [Automate incidents](https://learn.microsoft.com/azure/sre-agent/automate-incidents)

1. **Builder > Incident プラットフォーム** で **Azure Monitor** を選択 → **保存**。
2. 状態が「Azure Monitor 接続済み」になることを確認。

## F. Runbook（調査手順書）を登録
出典: [Automate incidents](https://learn.microsoft.com/azure/sre-agent/automate-incidents)（Runbook を読んで計画を立てる挙動）

1. ナレッジ（Knowledge base / Knowledge Files）に
   [03-runbook-sql-connectivity.md](03-runbook-sql-connectivity.md) をアップロード。
   - これによりエージェントは汎用手順ではなく、本デモの切り分け順（NSG → DNS → PE）に従う。

## G. 応答計画を作成（Review モード）
出典: [Automate incidents](https://learn.microsoft.com/azure/sre-agent/automate-incidents)

1. **Builder > インシデント対応計画 > 新しいインシデント対応計画**。
2. **手順1**: 名前（例 `db-connectivity`）＋重大度（すべて or Sev1/2）。必要ならタイトルフィルタ。
3. **手順2**: フィルタ結果のプレビュー → 次へ。
4. **手順3**: 自律レベルで **Review** を選択（各操作で承認を求める＝デモの見せ場）→ **保存**。

---

## 接続完了チェック
- [ ] A: エージェント作成済み
- [ ] B: `ozahiro0116/demoIaC` を Code Access に接続
- [ ] C: GitHub コネクタ（Issue/PR/Actions）を接続
- [ ] D: `rg-web-sql-dev-eus2` に Reader 付与
- [ ] E: Azure Monitor をインシデント基盤に接続
- [ ] F: Runbook を登録
- [ ] G: 応答計画を Review モードで作成

> フル GitHub API（コード横断検索など）が必要なら、GitHub を **MCP サーバー**として
> カスタムエージェントに接続する方法もあります（任意）:
> [Set up MCP connector](https://learn.microsoft.com/azure/sre-agent/mcp-connector)
