# Capture the DSH window with BitBlt (no System.Drawing) and write a PNG by hand.
param(
  [Parameter(Mandatory = $true)][string]$Out,
  [int]$X0 = 0, [int]$Y0 = 0, [int]$W = 0, [int]$H = 0
)
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class Cap {
  [DllImport("user32.dll")] public static extern IntPtr GetWindowDC(IntPtr h);
  [DllImport("user32.dll")] public static extern int ReleaseDC(IntPtr h, IntPtr dc);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr dc, uint flags);
  [DllImport("gdi32.dll")] public static extern IntPtr CreateCompatibleDC(IntPtr dc);
  [DllImport("gdi32.dll")] public static extern IntPtr CreateCompatibleBitmap(IntPtr dc, int w, int h);
  [DllImport("gdi32.dll")] public static extern IntPtr SelectObject(IntPtr dc, IntPtr obj);
  [DllImport("gdi32.dll")] public static extern bool DeleteDC(IntPtr dc);
  [DllImport("gdi32.dll")] public static extern bool DeleteObject(IntPtr obj);
  [DllImport("gdi32.dll")] public static extern bool BitBlt(IntPtr dst, int x, int y, int w, int h, IntPtr src, int sx, int sy, int rop);
  [DllImport("gdi32.dll")] public static extern int GetDIBits(IntPtr dc, IntPtr bmp, uint start, uint lines, byte[] bits, ref BITMAPINFO bi, uint usage);
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
  [StructLayout(LayoutKind.Sequential)] public struct BITMAPINFOHEADER {
    public uint biSize; public int biWidth, biHeight; public ushort biPlanes, biBitCount;
    public uint biCompression, biSizeImage; public int biXPelsPerMeter, biYPelsPerMeter; public uint biClrUsed, biClrImportant;
  }
  [StructLayout(LayoutKind.Sequential)] public struct BITMAPINFO { public BITMAPINFOHEADER h; public uint c1, c2, c3; }

  // returns BGRA rows, top-down, of the given sub-rectangle of the window (window-relative coords)
  public static byte[] Grab(IntPtr hwnd, int x, int y, int w, int h, out int outW, out int outH) {
    RECT wr; GetWindowRect(hwnd, out wr);
    int ww = wr.R - wr.L, wh = wr.B - wr.T;
    if (w <= 0) w = ww - x;
    if (h <= 0) h = wh - y;
    outW = w; outH = h;
    IntPtr src = GetWindowDC(hwnd);
    IntPtr mem = CreateCompatibleDC(src);
    IntPtr bmp = CreateCompatibleBitmap(src, ww, wh);
    IntPtr old = SelectObject(mem, bmp);
    bool ok = PrintWindow(hwnd, mem, 2);
    if (!ok) BitBlt(mem, 0, 0, ww, wh, src, 0, 0, 0x00CC0020);
    BITMAPINFO bi = new BITMAPINFO();
    bi.h.biSize = (uint)System.Runtime.InteropServices.Marshal.SizeOf(typeof(BITMAPINFOHEADER));
    bi.h.biWidth = ww; bi.h.biHeight = -wh; bi.h.biPlanes = 1; bi.h.biBitCount = 32; bi.h.biCompression = 0;
    byte[] all = new byte[ww * wh * 4];
    GetDIBits(mem, bmp, 0, (uint)wh, all, ref bi, 0);
    SelectObject(mem, old); DeleteObject(bmp); DeleteDC(mem); ReleaseDC(hwnd, src);
    byte[] part = new byte[w * h * 4];
    for (int row = 0; row < h; row++) Array.Copy(all, ((y + row) * ww + x) * 4, part, row * w * 4, w * 4);
    return part;
  }
}
"@

$script:CrcTable = $null
function Get-Crc32([byte[]]$data) {
  if ($null -eq $script:CrcTable) {
    $t = New-Object 'uint32[]' 256
    for ($n = 0; $n -lt 256; $n++) {
      $c = [uint32]$n
      for ($k = 0; $k -lt 8; $k++) {
        if (($c -band 1) -ne 0) { $c = [uint32](0xEDB88320 -bxor ($c -shr 1)) } else { $c = [uint32]($c -shr 1) }
      }
      $t[$n] = $c
    }
    $script:CrcTable = $t
  }
  $crc = [uint32]4294967295
  foreach ($b in $data) { $crc = [uint32]($script:CrcTable[($crc -bxor $b) -band 0xFF] -bxor ($crc -shr 8)) }
  return [uint32]($crc -bxor [uint32]4294967295)
}

function Write-Png([string]$path, [byte[]]$bgra, [int]$w, [int]$h) {
  $raw = New-Object 'byte[]' ($h * (1 + $w * 4))
  $pos = 0
  for ($row = 0; $row -lt $h; $row++) {
    $raw[$pos] = 0  # filter: none
    $pos++
    $off = $row * $w * 4
    for ($col = 0; $col -lt $w; $col++) {
      $i = $off + $col * 4
      $raw[$pos] = $bgra[$i + 2]; $raw[$pos + 1] = $bgra[$i + 1]; $raw[$pos + 2] = $bgra[$i]; $raw[$pos + 3] = 255
      $pos += 4
    }
  }
  $ms = New-Object System.IO.MemoryStream
  $ms.Write([byte[]](0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A), 0, 8)
  function Chunk([System.IO.MemoryStream]$s, [string]$type, [byte[]]$data) {
    $t = [System.Text.Encoding]::ASCII.GetBytes($type)
    $len = [BitConverter]::GetBytes([uint32]$data.Length)
    [byte[]]$be = @($len[3], $len[2], $len[1], $len[0])
    $s.Write($be, 0, 4); $s.Write($t, 0, 4); $s.Write($data, 0, $data.Length)
    $crc = Get-Crc32 ([byte[]]($t + $data))
    [byte[]]$cb = [BitConverter]::GetBytes($crc)
    [byte[]]$cbe = @($cb[3], $cb[2], $cb[1], $cb[0])
    $s.Write($cbe, 0, 4)
  }
  $ihdr = New-Object System.Collections.Generic.List[byte]
  [byte[]]$wb = [BitConverter]::GetBytes([uint32]$w); $ihdr.AddRange([byte[]]@($wb[3], $wb[2], $wb[1], $wb[0]))
  [byte[]]$hb = [BitConverter]::GetBytes([uint32]$h); $ihdr.AddRange([byte[]]@($hb[3], $hb[2], $hb[1], $hb[0]))
  $ihdr.AddRange([byte[]]@(8, 6, 0, 0, 0))
  Chunk $ms "IHDR" $ihdr.ToArray()
  # IDAT payload: zlib-compress the filtered rows into its own stream, then take the bytes out
  $zms = New-Object System.IO.MemoryStream
  $deflate = New-Object System.IO.Compression.ZLibStream($zms, [System.IO.Compression.CompressionLevel]::Fastest, $true)
  $deflate.Write($raw, 0, $raw.Length)
  $deflate.Dispose()
  $idat = $zms.ToArray()
  $zms.Dispose()
  Chunk $ms "IDAT" $idat
  Chunk $ms "IEND" ([byte[]]@())
  $ms.Dispose()
  [System.IO.File]::WriteAllBytes($path, $ms.ToArray())
}

$auto = [System.Windows.Automation.AutomationElement]
$root = $auto::RootElement
$tc = [System.Windows.Automation.Condition]::TrueCondition
$cond = New-Object System.Windows.Automation.PropertyCondition($auto::ClassNameProperty, "Chrome_WidgetWin_1")
$win = $null
foreach ($cand in $root.FindAll([System.Windows.Automation.TreeScope]::Children, $cond)) {
  try { $r = $cand.Current.BoundingRectangle } catch { continue }
  if ($r.Width -gt 500) { $win = $cand }
}
$hwnd = [IntPtr]$win.Current.NativeWindowHandle
$ow = 0; $oh = 0
$data = [Cap]::Grab($hwnd, $X0, $Y0, $W, $H, [ref]$ow, [ref]$oh)
Write-Output ("captured " + $ow + "x" + $oh + " from window-relative " + $X0 + "," + $Y0)
Write-Png $Out $data $ow $oh
Write-Output ("wrote " + $Out + " (" + (Get-Item $Out).Length + " bytes)")

