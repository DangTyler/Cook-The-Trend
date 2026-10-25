<#
  Minimal stdio MCP client for Roblox's built-in StudioMCP.exe (launched via %LOCALAPPDATA%\Roblox\mcp.bat).
  Used because this Claude Code session has no Roblox MCP registered; every call spawns a short-lived
  StudioMCP process, performs the MCP handshake, invokes one tool, and prints the text result.

  Usage:
    .\studio-mcp.ps1 -List                                   # list tools + schemas
    .\studio-mcp.ps1 -Tool <name> -ArgsJson '{"k":"v"}'      # call a tool with inline JSON args
    .\studio-mcp.ps1 -Tool <name> -ArgsFile args.json        # call a tool with args from a JSON file
    .\studio-mcp.ps1 -Tool run_code -LuauFile script.luau [-ArgName command]   # send a Luau file as one string arg
#>
param(
  [switch]$List,
  [string]$Tool,
  [string]$ArgsJson,
  [string]$ArgsFile,
  [string]$LuauFile,
  [string]$ArgName = 'command',
  [string]$ExtraArgsJson,
  [int]$TimeoutSec = 120,
  [string]$ImageOut,
  [switch]$Raw
)

$ErrorActionPreference = 'Stop'
$exe = Get-ChildItem -Path "$env:LOCALAPPDATA\Roblox\Versions\*\StudioMCP.exe" -ErrorAction SilentlyContinue |
  Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $exe) { throw 'StudioMCP.exe not found under %LOCALAPPDATA%\Roblox\Versions' }

$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = $exe.FullName
$psi.UseShellExecute = $false
$psi.RedirectStandardInput = $true
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError = $true
$psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
$psi.CreateNoWindow = $true
$proc = [System.Diagnostics.Process]::Start($psi)
$utf8 = New-Object System.Text.UTF8Encoding($false)
$stdin = $proc.StandardInput.BaseStream
$errTask = $proc.StandardError.ReadToEndAsync()

function Send-Msg($obj) {
  $json = ($obj | ConvertTo-Json -Depth 50 -Compress) + "`n"
  $bytes = $utf8.GetBytes($json)
  $stdin.Write($bytes, 0, $bytes.Length); $stdin.Flush()
}
function Send-Raw([string]$json) {
  $bytes = $utf8.GetBytes($json + "`n")
  $stdin.Write($bytes, 0, $bytes.Length); $stdin.Flush()
}
$pending = $null
function Read-Response([int]$id) {
  $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSec)
  while ([DateTime]::UtcNow -lt $deadline) {
    if ($null -eq $script:pending) { $script:pending = $proc.StandardOutput.ReadLineAsync() }
    $remaining = [int][Math]::Max(1, ($deadline - [DateTime]::UtcNow).TotalMilliseconds)
    if (-not $script:pending.Wait($remaining)) { break }
    $line = $script:pending.Result; $script:pending = $null
    if ($null -eq $line) { throw "StudioMCP closed stdout. stderr: $($errTask.Result)" }
    if (-not $line.Trim()) { continue }
    try { $msg = $line | ConvertFrom-Json } catch { continue }
    if ($msg.PSObject.Properties.Name -contains 'id' -and $msg.id -eq $id) { return $msg }
  }
  throw "Timed out after $TimeoutSec s waiting for response id $id"
}

try {
  Send-Msg @{ jsonrpc = '2.0'; id = 1; method = 'initialize'; params = @{
      protocolVersion = '2024-11-05'; capabilities = @{}; clientInfo = @{ name = 'rebounder-ps-bridge'; version = '1.0' } } }
  $null = Read-Response 1
  Send-Msg @{ jsonrpc = '2.0'; method = 'notifications/initialized' }

  if ($List) {
    Send-Msg @{ jsonrpc = '2.0'; id = 2; method = 'tools/list'; params = @{} }
    $r = Read-Response 2
    if ($Raw) { $r | ConvertTo-Json -Depth 50 } else {
      foreach ($t in $r.result.tools) {
        "=== $($t.name) ==="
        $t.description
        'schema: ' + ($t.inputSchema | ConvertTo-Json -Depth 20 -Compress)
        ''
      }
    }
    return
  }

  if (-not $Tool) { throw 'Specify -List or -Tool' }
  $argsText = '{}'
  if ($ArgsFile) { $argsText = [System.IO.File]::ReadAllText((Resolve-Path $ArgsFile), [System.Text.Encoding]::UTF8) }
  elseif ($ArgsJson) { $argsText = $ArgsJson }
  elseif ($LuauFile) {
    $code = [System.IO.File]::ReadAllText((Resolve-Path $LuauFile), [System.Text.Encoding]::UTF8)
    $h = @{}; $h[$ArgName] = $code
    if ($ExtraArgsJson) { ($ExtraArgsJson | ConvertFrom-Json).PSObject.Properties | ForEach-Object { $h[$_.Name] = $_.Value } }
    $argsText = $h | ConvertTo-Json -Depth 20 -Compress
  }
  # Build request text directly so argument JSON is passed through untouched.
  $req = '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":' + (ConvertTo-Json $Tool -Compress) + ',"arguments":' + $argsText + '}}'
  Send-Raw $req
  $r = Read-Response 3
  if ($Raw) { $r | ConvertTo-Json -Depth 50; return }
  if ($r.error) { "MCP ERROR: " + ($r.error | ConvertTo-Json -Depth 10 -Compress); exit 2 }
  $n = 0
  foreach ($c in $r.result.content) {
    if ($c.type -eq 'text') { $c.text }
    elseif ($c.type -eq 'image' -and $c.data) {
      $n++
      $ext = if ($c.mimeType -match 'jpeg|jpg') { 'jpg' } else { 'png' }
      if (-not $ImageOut) { $ImageOut = Join-Path $PSScriptRoot "..\captures\capture-$([DateTime]::Now.ToString('yyyyMMdd-HHmmss'))-$n.$ext" }
      elseif ($n -gt 1) { $ImageOut = [System.IO.Path]::ChangeExtension($ImageOut, $null).TrimEnd('.') + "-$n.$ext" }
      $dir = Split-Path -Parent $ImageOut; if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force $dir | Out-Null }
      [System.IO.File]::WriteAllBytes([System.IO.Path]::GetFullPath($ImageOut), [Convert]::FromBase64String($c.data))
      "IMAGE_SAVED: " + [System.IO.Path]::GetFullPath($ImageOut)
    }
    else { "[$($c.type) content]" + ($c | ConvertTo-Json -Depth 5 -Compress) }
  }
  if ($r.result.isError) { exit 3 }
}
finally {
  try { $stdin.Close() } catch {}
  if (-not $proc.WaitForExit(1500)) { try { $proc.Kill() } catch {} }
}
