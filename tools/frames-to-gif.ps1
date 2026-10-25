<#
  Encode an existing folder of captured frames into a downscaled, looping animated GIF.
  Usage: .\tools\frames-to-gif.ps1 -Dir captures\frames_225311 -Out captures\gameplay.gif [-Width 640] [-DelayCs 40] [-Step 1]
#>
param([string]$Dir, [string]$Out, [int]$Width = 640, [int]$DelayCs = 40, [int]$Step = 1)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName PresentationCore, WindowsBase, System.Drawing
$root = Split-Path -Parent $PSScriptRoot
$files = Get-ChildItem (Join-Path $root $Dir) -Filter *.jpg | Sort-Object Name
$enc = New-Object System.Windows.Media.Imaging.GifBitmapEncoder
for ($i = 0; $i -lt $files.Count; $i += $Step) {
  $src = [System.Drawing.Image]::FromFile($files[$i].FullName)
  $h = [int]($src.Height * $Width / $src.Width)
  $bmp = New-Object System.Drawing.Bitmap $Width, $h
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.InterpolationMode = 'HighQualityBicubic'
  $g.DrawImage($src, 0, 0, $Width, $h)
  $ms = New-Object System.IO.MemoryStream
  $bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
  $ms.Position = 0
  $frame = [System.Windows.Media.Imaging.BitmapFrame]::Create($ms, 'None', 'OnLoad')
  $enc.Frames.Add($frame)
  $g.Dispose(); $bmp.Dispose(); $src.Dispose()
}
$ms2 = New-Object System.IO.MemoryStream
$enc.Save($ms2)
$bytes = $ms2.ToArray()
$list = New-Object System.Collections.Generic.List[byte]
$i = 0; $headerDone = $false
$gctSize = if ($bytes[10] -band 0x80) { 3 * [math]::Pow(2, ($bytes[10] -band 7) + 1) } else { 0 }
while ($i -lt $bytes.Length) {
  if (-not $headerDone -and $i -eq (13 + $gctSize)) {
    $list.AddRange([byte[]](@(0x21, 0xFF, 0x0B) + [Text.Encoding]::ASCII.GetBytes('NETSCAPE2.0') + @(3, 1, 0, 0, 0)))
    $headerDone = $true
  }
  if ($bytes[$i] -eq 0x21 -and $i + 1 -lt $bytes.Length -and $bytes[$i + 1] -eq 0xF9) {
    $list.AddRange([byte[]]@($bytes[$i], $bytes[$i + 1], $bytes[$i + 2], $bytes[$i + 3], ($DelayCs -band 0xFF), (($DelayCs -shr 8) -band 0xFF)))
    $i += 6
    continue
  }
  $list.Add($bytes[$i]); $i++
}
$outPath = Join-Path $root $Out
[IO.File]::WriteAllBytes($outPath, $list.ToArray())
"GIF: $outPath ($([math]::Ceiling($files.Count / $Step)) frames, $([math]::Round($list.Count/1MB,2)) MB)"
