# Feature Specification: Hub-Spoke Network Infrastructure

**Feature Branch**: `001-hub-spoke-network`
**Created**: 2026-03-24
**Status**: Draft
**Input**: User description: "Hub-Spoke ネットワーク基盤を AVM Bicep モジュールで構築したい。Hub VNet にファイアウォールと Bastion を配置し、Spoke VNet にはワークロード用サブネットを作成する。NSG・診断設定・フローログを全リソースに適用し、dev/prod 環境をパラメータで切り替え可能にする。"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Hub VNet の構築とセキュリティ集約 (Priority: P1)

クラウドインフラ管理者として、Hub VNet を作成し、Azure Firewall と Azure Bastion を配置することで、すべての Spoke VNet からのトラフィックを集中管理できる状態にしたい。これにより、ネットワーク全体のセキュリティポリシーを一箇所で統制できるようになる。

**Why this priority**: Hub VNet はネットワーク基盤の中核であり、Spoke VNet が接続する先として必ず先に存在していなければならない。ファイアウォールと Bastion はセキュリティ上の必須コンポーネントである。

**Independent Test**: Hub VNet を単独でデプロイし、ファイアウォールと Bastion にそれぞれサブネットが割り当てられ、NSG と診断設定が有効であることを確認できる。

**Acceptance Scenarios**:

1. **Given** 空のリソースグループが存在する, **When** Hub VNet のデプロイを実行する, **Then** Hub VNet が作成され、AzureFirewallSubnet・AzureBastionSubnet・管理用サブネットの 3 つのサブネットが含まれている
2. **Given** Hub VNet がデプロイ済みである, **When** Azure Firewall のデプロイを実行する, **Then** ファイアウォールが AzureFirewallSubnet に配置され、パブリック IP が割り当てられている
3. **Given** Hub VNet がデプロイ済みである, **When** Azure Bastion のデプロイを実行する, **Then** Bastion が AzureBastionSubnet に配置され、Spoke VNet 内の VM にブラウザ経由で接続可能になる
4. **Given** Hub VNet のすべてのリソースがデプロイ済みである, **When** 診断設定を確認する, **Then** すべてのリソースが Log Analytics Workspace にログを送信している

---

### User Story 2 - Spoke VNet の構築と Hub への接続 (Priority: P2)

ワークロード担当者として、Spoke VNet を作成してワークロード用サブネットを配置し、Hub VNet と VNet Peering で接続したい。これにより、ワークロードが Hub のファイアウォール経由でインターネットや他の Spoke と通信できるようになる。

**Why this priority**: Spoke VNet は実際のワークロードが稼働する場所であり、Hub VNet が存在した上で構築される。Peering 設定により Hub-Spoke トポロジが完成する。

**Independent Test**: Spoke VNet を単独デプロイし、ワークロード用サブネットに NSG が付与されていること、Hub VNet との Peering が確立していることを確認できる。

**Acceptance Scenarios**:

1. **Given** Hub VNet がデプロイ済みである, **When** Spoke VNet のデプロイを実行する, **Then** Spoke VNet が作成され、ワークロード用サブネットが少なくとも 1 つ含まれている
2. **Given** Hub VNet と Spoke VNet が存在する, **When** VNet Peering を構成する, **Then** Hub → Spoke および Spoke → Hub の双方向 Peering が確立され、接続状態が "Connected" になる
3. **Given** Spoke VNet のサブネットにリソースが配置されている, **When** インターネット宛のトラフィックを送信する, **Then** トラフィックが Hub VNet の Azure Firewall 経由でルーティングされる

---

### User Story 3 - NSG・診断設定・フローログの全面適用 (Priority: P2)

セキュリティ管理者として、すべてのサブネット（ゲートウェイサブネットを除く）に NSG を適用し、全リソースに診断設定を有効化し、NSG フローログを収集したい。これにより、ネットワーク通信の可視化と監査が可能になる。

**Why this priority**: 憲法原則 III（Security by Default）に基づく必須要件。ネットワーク基盤のセキュリティ監視は Hub/Spoke の構造と並行して構築される。

**Independent Test**: 任意のサブネットに対して NSG が関連付けられていること、診断設定が Log Analytics に接続されていること、フローログが有効であることを個別に検証できる。

**Acceptance Scenarios**:

1. **Given** VNet 内にサブネットが作成されている, **When** NSG の適用状態を確認する, **Then** AzureFirewallSubnet と GatewaySubnet を除く全サブネットに NSG が関連付けられている
2. **Given** NSG がサブネットに適用されている, **When** NSG フローログ設定を確認する, **Then** すべての NSG でフローログが有効であり、Log Analytics Workspace に送信されている
3. **Given** Azure Firewall と Bastion がデプロイ済みである, **When** 診断設定を確認する, **Then** それぞれのリソースの診断ログが Log Analytics Workspace に記録されている

---

### User Story 4 - dev/prod 環境のパラメータ切り替え (Priority: P3)

運用管理者として、同一の IaC コードベースから environment パラメータ（dev または prod）を切り替えるだけで、環境ごとに適切な SKU・スケール・冗長設定を持つネットワーク基盤をデプロイしたい。

**Why this priority**: 環境分離は運用上重要だが、まずは単一環境で Hub-Spoke が動作することが前提条件である。

**Independent Test**: dev パラメータと prod パラメータでそれぞれデプロイし、リソース名に環境トークンが含まれること、SKU が環境に応じた設定になっていることを比較検証できる。

**Acceptance Scenarios**:

1. **Given** dev 用パラメータファイルが存在する, **When** dev 環境としてデプロイする, **Then** リソース名に "dev" が含まれ、ファイアウォールは Standard SKU、Bastion は Standard SKU でデプロイされる
2. **Given** prod 用パラメータファイルが存在する, **When** prod 環境としてデプロイする, **Then** リソース名に "prod" が含まれ、ファイアウォールは Premium SKU、Bastion は Standard SKU でデプロイされる
3. **Given** dev 環境と prod 環境の両方がデプロイ済みである, **When** リソース一覧を確認する, **Then** 両環境のリソースが名前・リソースグループで明確に区別されている

---

### Edge Cases

- Hub VNet のアドレス空間と Spoke VNet のアドレス空間が重複した場合、デプロイがエラーで失敗し、原因を示すメッセージが表示されること
- Azure Firewall Subnet のサイズが /26 未満の場合、バリデーション段階で拒否されること
- Spoke VNet 数が増えた場合でも（将来的に複数 Spoke に拡張）、Peering 設定が一貫した方法で追加できること
- Log Analytics Workspace が存在しない状態でデプロイを実行した場合、依存関係により Workspace が先に作成されること
- dev 環境と prod 環境で同じサブスクリプション・同じリージョンを使用した場合、名前衝突が発生しないこと

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Hub VNet を作成し、AzureFirewallSubnet（/26 以上）、AzureBastionSubnet（/26 以上）、管理用サブネットの 3 つのサブネットを含めること
- **FR-002**: Azure Firewall を Hub VNet の AzureFirewallSubnet にデプロイし、パブリック IP アドレスを割り当てること
- **FR-003**: Azure Bastion を Hub VNet の AzureBastionSubnet にデプロイすること
- **FR-004**: Spoke VNet を作成し、ワークロード用サブネットを少なくとも 1 つ含めること
- **FR-005**: Hub VNet と Spoke VNet の間に双方向 VNet Peering を構成すること
- **FR-006**: Spoke VNet からのインターネット向けトラフィックを Hub の Azure Firewall 経由でルーティングするためのルートテーブル（UDR）を構成すること
- **FR-007**: AzureFirewallSubnet と GatewaySubnet を除くすべてのサブネットに NSG を関連付けること
- **FR-008**: すべてのデプロイ済みリソース（VNet、Firewall、Bastion、NSG）に対して診断設定を有効にし、Log Analytics Workspace にログを送信すること
- **FR-009**: すべての NSG に対してフローログを有効にし、Log Analytics Workspace に送信すること
- **FR-010**: Log Analytics Workspace を共有リソースとしてデプロイし、データ保持期間を dev: 30 日、prod: 90 日に設定すること
- **FR-011**: すべてのデプロイは `environment` パラメータ（`dev` または `prod`）を受け取り、リソース名・SKU・スケール設定に反映すること
- **FR-012**: 環境ごとのパラメータ値はパラメータファイルとして分離し、Bicep モジュール本体にはハードコードしないこと
- **FR-013**: すべての Azure リソースは Azure Verified Modules（AVM）を使用してデプロイすること。AVM モジュールが存在しないリソースのみカスタムモジュールを許容する
- **FR-014**: Azure Firewall にデフォルト deny-all ネットワークルールを設定し、SC-003 検証用の最小限 allow ルール（HTTP/HTTPS アウトバウンド）を含めること。詳細なアプリケーションルール体系は別フィーチャーで定義する
- **FR-015**: すべてのリソースは `{resourceType}-hub-spoke-{env}-{region}` 形式（Azure CAF 準拠略称）で命名すること（例: `vnet-hub-spoke-dev-eus2`）

### Key Entities

- **Hub VNet**: ネットワーク基盤の中心。ファイアウォール、Bastion、管理用サブネットを収容する。アドレス空間は環境ごとに異なる（例: dev=10.0.0.0/16, prod=10.1.0.0/16）
- **Spoke VNet**: ワークロードが稼働する VNet。Hub VNet に Peering で接続される。将来的に複数の Spoke を追加可能
- **Azure Firewall**: Hub VNet に配置される集中型ファイアウォール。すべての Spoke からのアウトバウンドトラフィックを検査・制御する
- **Azure Bastion**: Hub VNet に配置されるセキュアリモートアクセスサービス。Standard SKU + IP-based connection で Spoke VNet 内の VM にパブリック IP なしで安全に接続できる
- **NSG (Network Security Group)**: サブネットレベルのトラフィックフィルタ。許可/拒否ルールでネットワークアクセスを制御する
- **Log Analytics Workspace**: すべてのリソースの診断ログおよび NSG フローログの集約先
- **Route Table (UDR)**: Spoke サブネットのデフォルトルートを Azure Firewall に向けるカスタムルーティング設定

## Clarifications

### Session 2026-03-24

- Q: Hub-Spoke 接続のトポロジパターンは VNet Peering（UDR 手動ルーティング）と Virtual WAN（自動ルーティング）のどちらを採用するか？ → A: VNet Peering のみ（UDR による手動ルーティング）
- Q: Azure Firewall に deny-all ベースラインと SC-003 検証用の最小 allow ルールを含めるか？ → A: deny-all ベースライン + テスト用 allow ルール（HTTP/HTTPS outbound）を含める
- Q: dev 環境の Bastion SKU（Basic）では Spoke VM への IP-based 接続が不可。dev でも SC-006 を検証可能にするか？ → A: dev も Standard SKU に統一し、全環境で Spoke VM 接続を検証可能にする
- Q: Log Analytics Workspace のデータ保持期間（retention）は？ → A: dev: 30 日、prod: 90 日
- Q: リソース命名規則のパターンは？ → A: `{resourceType}-hub-spoke-{env}-{region}` 形式（CAF 準拠略称、例: `vnet-hub-spoke-dev-eus2`）

## Assumptions

- **トポロジパターン: VNet Peering + UDR を採用する**（Virtual WAN は本フィーチャーのスコープ外。AVM 学習目的でルーティング制御を明示的に構成する）
- リージョンは `eastus2` をデフォルトとするが、パラメータで変更可能
- 初期構成では Spoke VNet は 1 つとし、将来の追加に対応しやすい構造にする
- Azure Firewall は dev 環境で Standard SKU、prod 環境で Premium SKU を使用する
- Azure Bastion は dev・prod ともに Standard SKU を使用する（Spoke VNet 内 VM への IP-based 接続に Standard が必須のため）
- Hub VNet のアドレス空間は dev: 10.0.0.0/16、prod: 10.1.0.0/16 とする
- Spoke VNet のアドレス空間は dev: 10.10.0.0/16、prod: 10.11.0.0/16 とする
- VPN Gateway、ExpressRoute Gateway、および Virtual WAN は本フィーチャーのスコープ外とする
- Azure Firewall は deny-all ベースライン + テスト用最小 allow ルール（HTTP/HTTPS outbound）を本フィーチャーで構成する。詳細なアプリケーションルール体系は別フィーチャーで対応する
- Log Analytics Workspace のデータ保持期間は dev: 30 日、prod: 90 日とする
- リソース命名規則: `{resourceType}-hub-spoke-{env}-{region}` 形式（Azure CAF 準拠略称、例: `vnet-hub-spoke-dev-eus2`, `fw-hub-spoke-prod-eus2`）

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: dev 環境のフルデプロイが 1 回のコマンド実行で完了し、手動介入なしですべてのリソースが「正常」状態になる
- **SC-002**: prod 環境のフルデプロイが dev と同一コードベースで、パラメータファイルの切り替えのみで完了する
- **SC-003**: Spoke VNet 内のサブネットから送信されたインターネット向けトラフィックが、100% Azure Firewall を経由してルーティングされる
- **SC-004**: デプロイ後 5 分以内に、すべてのリソースの診断ログが Log Analytics Workspace に表示される
- **SC-005**: すべての NSG フローログが有効であり、Log Analytics で過去 1 時間分のトラフィックデータをクエリできる
- **SC-006**: Bastion 経由で Spoke VNet 内の VM にブラウザ上からセキュアに接続できる
- **SC-007**: AVM モジュール使用率が 90% 以上（AVM が存在するリソース種別すべてで AVM を使用している）
