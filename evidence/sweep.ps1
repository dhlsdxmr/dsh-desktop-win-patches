# Sweep WM_NCHITTEST across the top band to map the drag region's real extent.
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class Sweep {
  [DllImport("user32.dll")] public static extern IntPtr SendMessage(IntPtr h, uint msg, IntPtr wp, IntPtr lp);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
  public static int Nc(IntPtr h, int sx, int sy) {
    RECT r; GetWindowRect(h, out r);
    IntPtr lp = (IntPtr)(((sy - r.T) << 16) | ((sx - r.L) & 0xFFFF));
    return (int)SendMessage(h, 0x0084, IntPtr.Zero, lp);
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
$hwnd = [IntPtr]$win.Current.NativeWindowHandle
Write-Output ("pid=" + $win.Current.ProcessId + " hwnd=" + $hwnd)
Write-Output "y sweep at x=806 (button center) and x=600 (blank header area):"
foreach ($y in 4, 10, 16, 20, 26, 30, 34, 36, 38, 40, 44, 46, 50, 56, 60, 70, 90, 120) {
  $a = [Sweep]::Nc($hwnd, 806, $y)
  $b = [Sweep]::Nc($hwnd, 600, $y)
  $na = if ($a -eq 1) { "CLIENT" } elseif ($a -eq 2) { "CAPTION" } else { "$a" }
  $nb = if ($b -eq 1) { "CLIENT" } elseif ($b -eq 2) { "CAPTION" } else { "$b" }
  Write-Output ("  y=" + $y.ToString().PadLeft(3) + "  x=806 -> " + $na + "   x=600 -> " + $nb)
}
Write-Output "x sweep at y=26:"
foreach ($x in 60, 200, 400, 600, 700, 750, 806, 850, 900, 1000, 1200, 1400, 1500, 1600, 1700, 1750, 1780, 1800) {
  $v = [Sweep]::Nc($hwnd, $x, 26)
  $n = if ($v -eq 1) { "CLIENT" } elseif ($v -eq 2) { "CAPTION" } else { "$v" }
  Write-Output ("  x=" + $x.ToString().PadLeft(4) + " -> " + $n)
}
