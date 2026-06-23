// ============================================================================
// SRE Agent デモ用 サンプル Web アプリ (.NET 8 / Minimal API)
//
// 目的:
//   App Service から SQL Database (Private Endpoint) への "到達性" を可視化する。
//   /health は DNS 解決 + TCP 1433 接続を行い、結果を JSON で返す。
//
//   - 正常時 : Private DNS が PE のプライベートIP (10.20.2.x) を返し、
//              NSG AllowSqlOutbound により TCP 1433 接続が成功 → 200 Healthy
//   - 障害時 : NSG の送信規則が Deny になると TCP 接続がタイムアウト → 503 Unhealthy
//
//   ※ DB ログイン(認証)は行わない。あくまで "ネットワーク到達性" を見る設計。
//      これにより MI への DB ユーザー付与なしで、決定論的に成否を再現できる。
// ============================================================================

using System.Diagnostics;
using System.Net;
using System.Net.Sockets;

var builder = WebApplication.CreateBuilder(args);
var app = builder.Build();

// 環境変数（App Service のアプリ設定で上書き可能。未設定時は dev 既定値）
string sqlFqdn = Environment.GetEnvironmentVariable("SQL_SERVER_FQDN")
    ?? "sql-web-sql-dev-eus2.database.windows.net";
int sqlPort = int.TryParse(Environment.GetEnvironmentVariable("SQL_PORT"), out var p) ? p : 1433;
int timeoutMs = int.TryParse(Environment.GetEnvironmentVariable("HEALTH_TIMEOUT_MS"), out var t) ? t : 5000;

// ---- ヘルスチェック本体: DNS 解決 + TCP 接続 -------------------------------
async Task<(bool ok, string? ip, long ms, string? error)> CheckSqlReachabilityAsync()
{
    var sw = Stopwatch.StartNew();
    string? resolvedIp = null;
    try
    {
        // 1) DNS 解決（Private DNS が機能していれば 10.20.2.x が返る）
        var addresses = await Dns.GetHostAddressesAsync(sqlFqdn);
        resolvedIp = addresses.FirstOrDefault()?.ToString();
        if (resolvedIp is null)
        {
            return (false, null, sw.ElapsedMilliseconds, "DNS resolution returned no address");
        }

        // 2) TCP 1433 接続（NSG 送信規則が許可していれば成功）
        using var client = new TcpClient();
        var connectTask = client.ConnectAsync(resolvedIp, sqlPort);
        var completed = await Task.WhenAny(connectTask, Task.Delay(timeoutMs));
        if (completed != connectTask || !client.Connected)
        {
            return (false, resolvedIp, sw.ElapsedMilliseconds,
                $"TCP connect to {resolvedIp}:{sqlPort} timed out after {timeoutMs}ms (NSG/route blocked?)");
        }

        return (true, resolvedIp, sw.ElapsedMilliseconds, null);
    }
    catch (Exception ex)
    {
        return (false, resolvedIp, sw.ElapsedMilliseconds, ex.Message);
    }
}

// ---- /health : App Service Health check と Azure Monitor が叩くエンドポイント ----
app.MapGet("/health", async (HttpContext ctx) =>
{
    var (ok, ip, ms, error) = await CheckSqlReachabilityAsync();
    var payload = new
    {
        status = ok ? "Healthy" : "Unhealthy",
        sqlServer = sqlFqdn,
        sqlPort,
        resolvedIp = ip,
        latencyMs = ms,
        error,
        timestamp = DateTimeOffset.UtcNow
    };
    ctx.Response.StatusCode = ok ? StatusCodes.Status200OK : StatusCodes.Status503ServiceUnavailable;
    return Results.Json(payload, statusCode: ctx.Response.StatusCode);
});

// ---- / : 人間が見るステータスページ（デモ画面用） --------------------------
app.MapGet("/", async () =>
{
    var (ok, ip, ms, error) = await CheckSqlReachabilityAsync();
    var color = ok ? "#107c10" : "#d13438";
    var label = ok ? "正常 (Healthy)" : "障害 (Unhealthy)";
    var html = $@"<!DOCTYPE html>
<html lang=""ja""><head><meta charset=""utf-8""><meta http-equiv=""refresh"" content=""5"">
<title>受発注API — 接続状態</title>
<style>
 body{{font-family:'Segoe UI',sans-serif;background:#faf9f8;color:#201f1e;margin:0;padding:40px}}
 .card{{max-width:720px;margin:auto;background:#fff;border-radius:8px;padding:32px;box-shadow:0 2px 8px rgba(0,0,0,.1)}}
 .badge{{display:inline-block;padding:6px 16px;border-radius:16px;color:#fff;font-weight:600;background:{color}}}
 table{{width:100%;border-collapse:collapse;margin-top:24px}} td{{padding:8px;border-bottom:1px solid #edebe9}}
 .k{{color:#605e5c;width:200px}} h1{{font-size:20px}}
</style></head><body><div class=""card"">
 <h1>受発注API（demoIaC / Web App → SQL Database）</h1>
 <p>データベース接続状態：<span class=""badge"">{label}</span></p>
 <table>
  <tr><td class=""k"">SQL Server</td><td>{sqlFqdn}</td></tr>
  <tr><td class=""k"">解決された IP</td><td>{ip ?? "-"}</td></tr>
  <tr><td class=""k"">TCP 1433 応答</td><td>{ms} ms</td></tr>
  <tr><td class=""k"">詳細</td><td>{error ?? "接続成功"}</td></tr>
  <tr><td class=""k"">更新時刻 (UTC)</td><td>{DateTimeOffset.UtcNow:yyyy-MM-dd HH:mm:ss}</td></tr>
 </table>
 <p style=""color:#605e5c;font-size:12px;margin-top:24px"">※ 5秒ごとに自動更新。ヘルスチェックは <code>/health</code>。</p>
</div></body></html>";
    return Results.Content(html, "text/html");
});

app.Run();
