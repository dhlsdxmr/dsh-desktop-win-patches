# Sample the probe's current phase together with the OS hit-test, so results line up automatically.
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class Hit7 {
  [DllImport("user32.dll")] public static extern IntPtr SendMessage(IntPtr h, uint msg, IntPtr wp, IntPtr lp);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
  public static int Nc(IntPtr h, int sx, int sy) {
    RECT r; GetWindowRect(h, out r);
    IntPtr lp = (IntPtr)(((sy - r.T) << 16) | ((sx - r.L) & 0xFFFF));
    return (int)SendMessage(h, 0x0084, IntPtr.Zero, lp);
  }
  public static string Name(int v) {
    if (v == 1) return "CLIENT(可点)"; if (v == 2) return "CAPTION(拖拽)"; if (v == 8) return "MINBTN"; if (v == 9) return "MAXBTN"; if (v == 20) return "CLOSE"; return "code " + v;
  }
}
"@
$auto = [System.Windows.Automation.AutomationElement]
$root = $auto::RootElement
$tc = [System.Windows.Automation.Condition]::TrueCondition
$cond = New-Object System.Windows.Automation.PropertyCondition($auto::ClassNameProperty, "Chrome_WidgetWin_1")
$dshPids = (Get-Process -Name "DSH Desktop" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Id)
$win = $null
foreach ($c in $root.FindAll([System.Windows.Automation.TreeScope]::Children, $cond)) {
  if ($dshPids -contains $c.Current.ProcessId) {
    try { $r = $c.Current.BoundingRectangle } catch { continue }
    if ($r.Width -gt 500) { $win = $c }
  }
}
if (-not $win) { Write-Output "NO WINDOW"; exit 1 }
$hwnd = [IntPtr]$win.Current.NativeWindowHandle
Write-Output ("pid=" + $win.Current.ProcessId + " hwnd=" + $hwnd)

# find the trigger once, for its x centre
$trigX = 806
foreach ($e in $win.FindAll([System.Windows.Automation.TreeScope]::Descendants, $tc)) {
  if ($e.Current.ClassName -eq 'QsffPG_trigger') {
    $r = $e.Current.BoundingRectangle
    $trigX = [int](([int]$r.X + [int]$r.Right) / 2)
    break
  }
}
Write-Output ("trigger centre x = " + $trigX)
Write-Output ""
Write-Output ("{0,-6} {1,-46} {2,-10} {3}" -f "t", "phase / strip", "y=20", "y=26")
for ($i = 0; $i -lt 22; $i++) {
  $phase = "?"; $strip = "?"
  foreach ($e in $win.FindAll([System.Windows.Automation.TreeScope]::Descendants, $tc)) {
    $n = $e.Current.Name
    if ($n -match '^DP00 PHASE=') { $phase = $n -replace '^DP00 ', '' }
    if ($n -match '^DP02 strip') { $strip = $n -replace '^DP02 ', '' }
  }
  $v20 = [Hit7]::Name([Hit7]::Nc($hwnd, $trigX, 20))
  $v26 = [Hit7]::Name([Hit7]::Nc($hwnd, $trigX, 26))
  Write-Output ("{0,-6} {1,-46} {2,-10} {3}" -f $i, ($phase + " " + $strip), $v20, $v26)
  Start-Sleep -Milliseconds 2000
}
