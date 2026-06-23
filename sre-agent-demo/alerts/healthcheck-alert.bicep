// ============================================================================
// healthcheck-alert.bicep — App Service ヘルスチェック低下アラート
//
// 信号源: App Service 自身が /health を定期プローブして発行する
//         メトリック "HealthCheckStatus"（健全インスタンスの割合 0–100）。
//   - 正常時: 100
//   - SQL 到達不可時: /health が 503 → ヘルスチェック失敗 → 値が低下
//
// このアラートが Azure Monitor で発火し、SRE Agent（インシデント基盤=Azure Monitor）
// がインシデントとして受け取り、自動調査を開始する。
//
// デプロイ:
//   az deployment group create -g rg-web-sql-dev-eus2 \
//     --template-file alerts/healthcheck-alert.bicep \
//     --parameters webAppName=app-web-sql-dev-eus2
// ============================================================================

targetScope = 'resourceGroup'

@description('対象 Web App 名')
param webAppName string = 'app-web-sql-dev-eus2'

@description('しきい値（健全インスタンス割合がこれを下回ると発火）')
param threshold int = 100

@description('アラートの重大度 (0=Critical ... 4=Verbose)')
param severity int = 1

resource webApp 'Microsoft.Web/sites@2023-12-01' existing = {
  name: webAppName
}

resource healthAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'alert-db-connectivity-${webAppName}'
  location: 'global'
  properties: {
    description: '受発注API: SQL Database への接続(到達性)が失われ、ヘルスチェックが低下しています。'
    severity: severity
    enabled: true
    scopes: [
      webApp.id
    ]
    evaluationFrequency: 'PT1M'
    windowSize: 'PT5M'
    targetResourceType: 'Microsoft.Web/sites'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'HealthCheckBelowThreshold'
          metricNamespace: 'Microsoft.Web/sites'
          metricName: 'HealthCheckStatus'
          operator: 'LessThan'
          threshold: threshold
          timeAggregation: 'Average'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
    autoMitigate: true
    // SRE Agent は Azure Monitor 連携でアラートを受け取るため action group は必須ではない。
    // 必要なら actions に action group の resourceId を追加する。
    actions: []
  }
}

output alertId string = healthAlert.id
