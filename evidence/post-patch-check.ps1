# Post-restart check: is the header title row still classified as the window caption (drag) area?
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class Hit2 {
  [DllImport("user32.dll")] public static extern IntPtr SendMessage(IntPtr h, uint msg, IntPtr wp, IntPtr lp);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
  public static int NcHitTest(IntPtr h, int sx, int sy) {
    RECT r; GetWindowRect(h, out r);
    IntPtr lp = (IntPtr)(((sy - r.T) << 16) | ((sx - r.L) & 0xFFFF));
    return (int)SendMessage(h, 0x0084, IntPtr.Zero, lp);
  }
  public static string Name(int v) {
    if (v == 0) return "HTNOWHERE"; if (v == 1) return "HTCLIENT(正常可点)"; if (v == 2) return "HTCAPTION(标题栏/拖拽)";
    if (v == 8) return "HTMINBUTTON"; if (v == 9) return "HTMAXBUTTON"; if (v == 20) return "HTCLOSE";
    return "code " + v;
  }
}
"@
$auto = [System.Windows.Automation.AutomationElement]
$root = $auto::RootElement
$cond = New-Object System.Windows.Automation.PropertyCondition($auto::ClassNameProperty, "Chrome_WidgetWin_1")
$dshPids = (Get-Process -Name "DSH Desktop" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Id)
$win = $null
foreach ($c in $root.FindAll([System.Windows.Automation.TreeScope]::Children, $cond)) {
  if ($dshPids -contains $c.Current.ProcessId) {
    try { $r = $c.Current.BoundingRectangle } catch { continue }
    if ($r.Width -gt 500) { $win = $c }
  }
}
if (-not $win) { Write-Output "NO DSH WINDOW"; exit 1 }
$hwnd = [IntPtr]$win.Current.NativeWindowHandle
$tc = [System.Windows.Automation.Condition]::TrueCondition
$t = $null
foreach ($e in $win.FindAll([System.Windows.Automation.TreeScope]::Descendants, $tc)) {
  if ($e.Current.ClassName -eq 'QsffPG_trigger') { $t = $e; break }
}
Write-Output ("DSH pid=" + $win.Current.ProcessId + " hwnd=" + $hwnd)
if ($t) {
  $tr = $t.Current.BoundingRectangle
  Write-Output ("trigger '" + $t.Current.Name + "' rect=" + [int]$tr.X + "," + [int]$tr.Y + " " + [int]$tr.Width + "x" + [int]$tr.Height)
  $xl = [int]$tr.X; $yt = [int]$tr.Y; $xr = [int]$tr.Right; $yb = [int]$tr.Bottom
  $cx = [int](($xl + $xr) / 2); $cy = [int](($yt + $yb) / 2)
  Write-Output ("--- 命中测试（按钮中心 " + $cx + "," + $cy + "）---")
  foreach ($pt in @(@($cx, $cy), @(($xl + 10), ($yt + 6)), @(($xr - 6), $cy), @($cx, 20), @($cx, 46), @(600, 20))) {
    $v = [Hit2]::NcHitTest($hwnd, [int]$pt[0], [int]$pt[1])
    Write-Output ("  screen " + [int]$pt[0] + "," + [int]$pt[1] + " -> " + $v + " " + [Hit2]::Name($v))
  }
} else {
  Write-Output "trigger absent"
}
