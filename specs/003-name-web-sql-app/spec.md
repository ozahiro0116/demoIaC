# Feature Specification: Web App + SQL Database on Azure (AVM)

**Feature Branch**: `003-name-web-sql-app`
**Created**: 2026-03-24
**Status**: Draft
**Input**: User description: "ホワイトボードから読み取ったアーキテクチャに基づき、App Service + SQL Database + NSG + Azure Monitor の構成を AVM Bicep で構築する。Private Endpoint・Managed Identity によるセキュア接続、dev/prod 環境分離を含む。"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Web アプリケーション基盤の構築 (Priority: P1)

アプリケーション開発者として、Azure App Service 上に Web アプリケーションをデプロイできる基盤を構築したい。App Service Plan と Web App が適切な設定で稼働し、ユーザーからの HTTP リクエストを受け付けられる状態にする。

**Why this priority**: Web アプリケーションはシステムのフロントエンドであり、ユーザーが最初にアクセスするコンポーネント。これが稼働しなければ他のすべての機能が意味をなさない。

**Independent Test**: App Service を単独でデプロイし、デフォルトページが HTTP 200 で応答すること、Managed Identity が有効であることを確認できる。

**Acceptance Scenarios**:

1. **Given** 空のリソースグループが存在する, **When** App Service のデプロイを実行する, **Then** App Service Plan と Web App が作成され、Web App のデフォルトページが HTTP 200 を返す
2. **Given** Web App がデプロイ済みである, **When** Managed Identity の状態を確認する, **Then** System-assigned Managed Identity が有効化されている
3. **Given** Web App がデプロイ済みである, **When** Application Insights の接続状態を確認する, **Then** Web App のテレメトリが Application Insights に送信されている

---

### User Story 2 - SQL Database のデプロイとセキュア接続 (Priority: P1)

アプリケーション開発者として、Azure SQL Database をデプロイし、Web App から Managed Identity によるパスワードレス認証で安全に接続できる状態にしたい。Private Endpoint を使用して SQL Database への通信をプライベートネットワーク経由に制限する。

**Why this priority**: データストアは Web アプリケーションに次ぐ中核コンポーネント。Managed Identity と Private Endpoint はセキュリティの基本原則として P1 で確保する必要がある。

**Independent Test**: SQL Server + Database を単独デプロイし、Private Endpoint が作成されていること、パブリックネットワークアクセスが無効であることを確認できる。

**Acceptance Scenarios**:

1. **Given** リソースグループが存在する, **When** SQL Server + Database のデプロイを実行する, **Then** Azure SQL Server と SQL Database が作成され、パブリックネットワークアクセスが無効に設定されている
2. **Given** SQL Server がデプロイ済みである, **When** Private Endpoint の状態を確認する, **Then** Private Endpoint が作成され、承認状態が "Approved" になっている
3. **Given** Web App と SQL Database が両方デプロイ済みである, **When** Web App の Managed Identity で SQL Database への接続テストを実行する, **Then** パスワードなしで接続が成功する
4. **Given** SQL Server がデプロイ済みである, **When** Microsoft Entra ID 認証の設定を確認する, **Then** Entra ID 管理者が設定され、Entra ID 認証が有効化されている

---

### User Story 3 - ネットワークセキュリティの確保 (Priority: P2)

セキュリティ管理者として、NSG を使用して App Service と SQL Database 間のトラフィックを制御し、不要なネットワークアクセスを遮断したい。VNet Integration により App Service をプライベートネットワークに参加させる。

**Why this priority**: ネットワーク分離はセキュリティのベストプラクティスとして重要だが、まず Web App と SQL Database の基本的なデプロイが完了していることが前提である。

**Independent Test**: NSG ルールを確認し、SQL Database（ポート 1433）への通信が App Service サブネットからのみ許可されていることを検証できる。

**Acceptance Scenarios**:

1. **Given** VNet が作成されている, **When** NSG の適用状態を確認する, **Then** App Service Integration サブネットと Private Endpoint サブネットに NSG が関連付けられている
2. **Given** NSG が適用されている, **When** NSG ルールを確認する, **Then** Private Endpoint サブネットへのポート 1433 通信が App Service サブネットからのみ許可されている
3. **Given** Web App が VNet Integration で接続されている, **When** SQL Database への通信を行う, **Then** 通信が VNet 内のプライベート経路を通過する

---

### User Story 4 - 監視とログ収集の構成 (Priority: P2)

運用管理者として、Log Analytics Workspace と Application Insights を構成し、すべてのリソースの診断ログとアプリケーションテレメトリを一元収集したい。障害検知や性能分析に活用できる状態にする。

**Why this priority**: 監視はシステムの健全性を維持するために不可欠だが、監視対象のリソースが先に存在している必要がある。

**Independent Test**: Log Analytics Workspace を単独デプロイし、各リソースの診断設定が有効であること、Application Insights がテレメトリを受信していることを確認できる。

**Acceptance Scenarios**:

1. **Given** リソースグループが存在する, **When** 監視リソースのデプロイを実行する, **Then** Log Analytics Workspace と Application Insights が作成される
2. **Given** すべてのリソースがデプロイ済みである, **When** 診断設定を確認する, **Then** App Service・SQL Server・NSG すべてのリソースが Log Analytics Workspace にログを送信している
3. **Given** Application Insights が構成済みである, **When** Web App にリクエストを送信する, **Then** Application Insights でリクエストトレースが確認できる

---

### User Story 5 - dev/prod 環境のパラメータ切り替え (Priority: P3)

運用管理者として、同一の IaC コードベースから environment パラメータ（dev または prod）を切り替えるだけで、環境ごとに適切な SKU・スケール設定を持つ環境をデプロイしたい。

**Why this priority**: 環境分離は運用上重要だが、まず単一環境で全コンポーネントが正常に動作することが前提条件である。

**Independent Test**: dev パラメータと prod パラメータでそれぞれデプロイし、リソース名に環境トークンが含まれること、SKU が環境に応じた設定になっていることを比較検証できる。

**Acceptance Scenarios**:

1. **Given** dev 用パラメータファイルが存在する, **When** dev 環境としてデプロイする, **Then** リソース名に "dev" が含まれ、App Service Plan は B1 SKU でデプロイされる
2. **Given** prod 用パラメータファイルが存在する, **When** prod 環境としてデプロイする, **Then** リソース名に "prod" が含まれ、App Service Plan は P1v3 SKU でデプロイされる
3. **Given** dev と prod の両環境がデプロイ済みである, **When** リソース一覧を確認する, **Then** 両環境のリソースが名前で明確に区別されている

---

### Edge Cases

- App Service Plan の SKU が Free/Shared の場合、VNet Integration がサポートされないためデプロイがエラーで失敗し、原因を示すメッセージが表示されること
- Private Endpoint の DNS 解決ができない場合（Private DNS Zone が未構成）、SQL 接続がタイムアウトすること
- SQL Server のパブリックネットワークアクセスが誤って有効化された場合でも、NSG ルールにより外部からの直接接続が遮断されること
- Managed Identity に SQL Database への権限が未付与の場合、接続時に認証エラーが発生し明確なエラーメッセージが表示されること
- dev 環境と prod 環境で同じサブスクリプション・同じリージョンを使用した場合、名前衝突が発生しないこと
- Application Insights の接続文字列が Web App に設定されていない場合、テレメトリが収集されないこと

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: App Service Plan を作成し、dev 環境では B1 (Basic) SKU、prod 環境では P1v3 (Premium V3) SKU を使用すること
- **FR-002**: Web App を App Service Plan 上にデプロイし、System-assigned Managed Identity を有効化すること
- **FR-003**: Web App に VNet Integration を構成し、専用の Integration サブネットに接続すること
- **FR-004**: Azure SQL Server を作成し、Microsoft Entra ID 認証を有効化、SQL 認証を無効化、パブリックネットワークアクセスを無効に設定すること。Entra ID 管理者はデプロイ者の UPN で指定する
- **FR-005**: Azure SQL Database を SQL Server 上に作成し、dev 環境では Basic SKU (5 DTU)、prod 環境では S1 SKU (20 DTU) を使用すること。Elastic Pool は使用しない
- **FR-006**: SQL Server への Private Endpoint を作成し、専用の Private Endpoint サブネットに配置すること
- **FR-007**: Private DNS Zone（privatelink.database.windows.net）を作成し、VNet にリンクして Private Endpoint の名前解決を可能にすること
- **FR-008**: Web App の Managed Identity に SQL Database への接続権限（db_datareader、db_datawriter）を付与可能な状態にすること
- **FR-009**: VNet を作成し、AppServiceSubnet (/24)、PrivateEndpointSubnet (/24)、DefaultSubnet (/24) の 3 つのサブネットを含めること
- **FR-010**: 各サブネットに NSG を関連付け、Private Endpoint サブネットへのポート 1433 通信を App Service サブネットからのみ許可するルールを設定すること
- **FR-011**: Log Analytics Workspace を作成し、データ保持期間を dev: 30 日、prod: 90 日に設定すること
- **FR-012**: Application Insights を Log Analytics Workspace に接続して作成し、Web App に接続文字列を設定すること。サンプリング率は dev: 100%（全収集）、prod: 50% とする
- **FR-013**: すべてのデプロイ済みリソース（App Service、SQL Server、NSG）に対して診断設定を有効にし、Log Analytics Workspace にログを送信すること
- **FR-014**: すべてのデプロイは `environment` パラメータ（`dev` または `prod`）を受け取り、リソース名・SKU・スケール設定に反映すること
- **FR-015**: 環境ごとのパラメータ値はパラメータファイルとして分離し、Bicep モジュール本体にはハードコードしないこと
- **FR-016**: すべての Azure リソースは Azure Verified Modules（AVM）を使用してデプロイすること。AVM モジュールが存在しないリソースのみカスタムモジュールを許容する
- **FR-017**: すべてのリソースは `{resourceType}-web-sql-{env}-{region}` 形式（Azure CAF 準拠略称）で命名すること（例: `app-web-sql-dev-eus2`、`sql-web-sql-prod-eus2`）

### Key Entities

- **App Service Plan**: Web App のコンピュート基盤。環境に応じた SKU でスケールを制御する
- **Web App (App Service)**: ユーザーからの HTTP リクエストを受け付けるフロントエンド。Managed Identity を使用して SQL Database に認証する
- **Azure SQL Server**: SQL Database のホスト。Entra ID 認証を有効化し、パブリックアクセスを無効にする
- **Azure SQL Database**: アプリケーションのデータストア。Private Endpoint 経由でのみアクセス可能
- **VNet**: Web App と SQL Database をプライベートネットワークで接続するための仮想ネットワーク。AppServiceSubnet、PrivateEndpointSubnet、DefaultSubnet の 3 サブネットを含む
- **NSG (Network Security Group)**: サブネットレベルのトラフィックフィルタ。SQL Database へのアクセスを App Service からに制限する
- **Private Endpoint**: SQL Database へのプライベート接続ポイント。VNet 内に配置され、パブリック経路を経由しない
- **Private DNS Zone**: Private Endpoint の FQDN をプライベート IP に解決するための DNS ゾーン
- **Log Analytics Workspace**: すべてのリソースの診断ログの集約先
- **Application Insights**: Web App のアプリケーションレベルのパフォーマンス監視とテレメトリ収集

## Assumptions

- **リージョンは `eastus2` をデフォルトとするが、パラメータで変更可能**
- App Service Plan は dev 環境で B1 (Basic)、prod 環境で P1v3 (Premium V3) を使用する
- SQL Database は dev 環境で Basic SKU (5 DTU)、prod 環境で S1 SKU (20 DTU) を使用する。Elastic Pool は使用しない
- VNet のアドレス空間は dev: 10.20.0.0/16、prod: 10.21.0.0/16 とする
- サブネット構成: AppServiceSubnet /24、PrivateEndpointSubnet /24、DefaultSubnet /24 の 3 サブネット
- SQL Server は Managed Identity（パスワードレス）認証のみ使用し、SQL 認証は無効化する
- SQL Server の Entra ID 管理者はデプロイ者の UPN で指定する
- Managed Identity から SQL Database への権限付与（db_datareader/db_datawriter）はデプロイ後の手動ステップまたは別途スクリプトで対応する（Bicep では SQL ロール割り当てが直接サポートされないため）
- Web App はランタイム設定（言語・バージョン）をパラメータで指定可能とするが、デフォルトは .NET 8 とする
- Application Insights はワークスペースベース（Log Analytics 接続型）を使用する
- Application Insights のサンプリング率は dev: 100%（全収集）、prod: 50% とする
- NSG フローログは本フィーチャーのスコープ外とする（001-hub-spoke-network で対応済み）
- Azure DDoS Protection は本フィーチャーのスコープ外とする
- リソース命名規則: `{resourceType}-web-sql-{env}-{region}` 形式（CAF 準拠略称、例: `app-web-sql-dev-eus2`、`sql-web-sql-prod-eus2`）
- Log Analytics Workspace のデータ保持期間は dev: 30 日、prod: 90 日とする

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: dev 環境のフルデプロイが 1 回のコマンド実行で完了し、手動介入なしですべてのリソースが「正常」状態になる
- **SC-002**: prod 環境のフルデプロイが dev と同一コードベースで、パラメータファイルの切り替えのみで完了する
- **SC-003**: Web App のデフォルトページが HTTPS でアクセス可能で、HTTP 200 を返す
- **SC-004**: SQL Database へのすべての通信が Private Endpoint 経由であり、パブリック経路からの接続が拒否される
- **SC-005**: Web App の Managed Identity を使用した SQL Database への接続が、パスワードなしで成功する
- **SC-006**: デプロイ後 5 分以内に、すべてのリソースの診断ログが Log Analytics Workspace に表示される
- **SC-007**: Application Insights で Web App へのリクエストトレースが確認できる
- **SC-008**: AVM モジュール使用率が 90% 以上（AVM が存在するリソース種別すべてで AVM を使用している）

## Clarifications

### Session 2026-03-24

- Q: App Service Plan の SKU は？ → A: dev: B1 (Basic), prod: P1v3 (Premium V3)
- Q: SQL Database の SKU 構成は？ → A: dev: Basic (5 DTU), prod: S1 (20 DTU). Elastic Pool は不要
- Q: VNet のアドレス空間とサブネット設計は？ → A: dev: 10.20.0.0/16, prod: 10.21.0.0/16。サブネット: AppServiceSubnet /24, PrivateEndpointSubnet /24, DefaultSubnet /24
- Q: SQL認証方式は？ → A: Managed Identity（パスワードレス）のみ。SQL認証は無効化。Entra ID管理者はデプロイ者のUPN
- Q: Application Insights のサンプリング設定は？ → A: dev: 100%（全収集）, prod: 50% サンプリング。保持期間: dev=30日, prod=90日
