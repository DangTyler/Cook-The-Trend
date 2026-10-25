<#
  Grab a sequence of Studio viewport frames via StudioMCP screen_capture and encode an animated GIF (WPF encoder).
  Usage: .\tools\capture-gif.ps1 -Frames 40 -Out captures\ramen.gif [-DelayCs 30]
#>
param([int]$Frames = 30, [string]$Out = 'captures\gameplay.gif', [int]$DelayCs = 35)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$mcp = Join-Path $PSScriptRoot 'studio-mcp.ps1'
$dir = Join-Path $root ('captures\frames_' + [DateTime]::Now.ToString('HHmmss'))
New-Item -ItemType Directory -Force $dir | Out-Null
for ($i = 0; $i -lt $Frames; $i++) {
  $img = Join-Path $dir ('f{0:D3}.jpg' -f $i)
  $null = & $mcp -Tool screen_capture -ArgsJson ('{"capture_id":"Gif_' + $i + '","studio_id":"37f16ec6-a1eb-4d99-94d4-8efa465a96f0"}') -ImageOut $img
}
Add-Type -AssemblyName PresentationCore, WindowsBase
$enc = New-Object System.Windows.Media.Imaging.GifBitmapEncoder
$files = Get-ChildItem $dir -Filter *.jpg | Sort-Object Name
foreach ($f in $files) {
  $bmp = New-Object System.Windows.Media.Imaging.BitmapImage
  $bmp.BeginInit(); $bmp.UriSource = New-Object Uri($f.FullName); $bmp.CacheOption = 'OnLoad'; $bmp.EndInit()
  $enc.Frames.Add([System.Windows.Media.Imaging.BitmapFrame]::Create($bmp))
}
$outPath = Join-Path $root $Out
$ms = New-Object System.IO.MemoryStream
$enc.Save($ms)
$bytes = $ms.ToArray()
# patch: add NETSCAPE loop extension + per-frame delay (WPF writes neither)
$list = New-Object System.Collections.Generic.List[byte]
$i = 0
$headerDone = $false
while ($i -lt $bytes.Length) {
  if (-not $headerDone -and $i -eq 13 + 3 * [math]::Pow(2, ($bytes[10] -band 7) + 1) * [int](($bytes[10] -band 0x80) -ne 0)) {
    $ext = [byte[]](@(0x21, 0xFF, 0x0B) + [Text.Encoding]::ASCII.GetBytes('NETSCAPE2.0') + @(3, 1, 0, 0, 0))
    $list.AddRange($ext)
    $headerDone = $true
  }
  if ($bytes[$i] -eq 0x21 -and $i + 1 -lt $bytes.Length -and $bytes[$i + 1] -eq 0xF9) {
    # graphic control extension: 21 F9 04 flags delayLo delayHi transp 00
    $gce = [byte[]]@($bytes[$i], $bytes[$i + 1], $bytes[$i + 2], $bytes[$i + 3], ($DelayCs -band 0xFF), (($DelayCs -shr 8) -band 0xFF))
    $list.AddRange($gce)
    $i += 6
    continue
  }
  $list.Add($bytes[$i]); $i++
}
[IO.File]::WriteAllBytes($outPath, $list.ToArray())
"GIF: $outPath ($($files.Count) frames, $([math]::Round($list.Count/1MB,2)) MB) frames in $dir"
