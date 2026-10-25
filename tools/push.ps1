<#
  Push local Luau sources into the Cook The Trend Studio place (placeId 86879072513404).
  Script text only enters Studio through StudioMCP multi_edit (MCP Luau is sandboxed: it cannot create scripts).
  Each file: delete existing instance at the dot path (via execute_luau), then multi_edit-create it with the full text.

  Usage: .\tools\push.ps1                # push everything in tools\manifest.txt
         .\tools\push.ps1 -Only Recipes   # push entries whose path contains "Recipes"
#>
param([string]$Only)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$studio = '37f16ec6-a1eb-4d99-94d4-8efa465a96f0'
$mcp = Join-Path $PSScriptRoot 'studio-mcp.ps1'
$tmp = Join-Path $root 'build\push'
New-Item -ItemType Directory -Force $tmp | Out-Null

# guard: correct place
$guard = Join-Path $tmp 'guard.luau'
[IO.File]::WriteAllText($guard, 'return tostring(game.PlaceId)')
for ($try = 0; $try -lt 10; $try++) {
  $pid0 = (& $mcp -Tool execute_luau -LuauFile $guard -ArgName code -ExtraArgsJson ('{"datamodel_type":"Edit","studio_id":"' + $studio + '"}')) -join ''
  if ($pid0 -match '86879072513404') { break }
  Start-Sleep 2
}
if ($pid0 -notmatch '86879072513404') { throw "Wrong place connected: $pid0" }

$lines = Get-Content (Join-Path $PSScriptRoot 'manifest.txt') | Where-Object { $_.Trim() -and -not $_.StartsWith('#') }
foreach ($ln in $lines) {
  $parts = $ln -split '\s*\|\s*'
  $file = Join-Path $root $parts[0]; $path = $parts[1]; $class = $parts[2]
  if ($Only -and ($path -notmatch [regex]::Escape($Only))) { continue }
  $code = [IO.File]::ReadAllText($file, [Text.Encoding]::UTF8)
  $segs = $path -split '\.'
  # ensure parent folders exist, remove old instance
  $lua = "local cur = game`n"
  for ($i = 1; $i -lt $segs.Count - 1; $i++) {
    $s = $segs[$i]
    if ($i -eq 1) { $lua += "cur = game:GetService('$s')`n" }
    else { $lua += "do local n = cur:FindFirstChild('$s') if not n then n = Instance.new('Folder') n.Name = '$s' n.Parent = cur end cur = n end`n" }
  }
  $last = $segs[-1]
  $lua += "local old = cur:FindFirstChild('$last') if old then old:Destroy() end return 'ok'"
  $lf = Join-Path $tmp 'prep.luau'; [IO.File]::WriteAllText($lf, $lua)
  $r1 = (& $mcp -Tool execute_luau -LuauFile $lf -ArgName code -ExtraArgsJson ('{"datamodel_type":"Edit","studio_id":"' + $studio + '"}')) -join ''
  $editJson = '[{"old_string":"","new_string":' + (ConvertTo-Json $code -Compress) + '}]'
  $json = '{"file_path":' + (ConvertTo-Json $path) + ',"className":"' + $class + '","datamodel_type":"Edit","studio_id":"' + $studio + '","edits":' + $editJson + '}'
  $af = Join-Path $tmp 'args.json'
  [IO.File]::WriteAllText($af, $json, (New-Object Text.UTF8Encoding($false)))
  $r2 = (& $mcp -Tool multi_edit -ArgsFile $af) -join ' '
  $short = if ($r2.Length -gt 120) { $r2.Substring(0,120) } else { $r2 }
  "{0,-60} prep={1} edit={2}" -f $path, $r1, $short
}
