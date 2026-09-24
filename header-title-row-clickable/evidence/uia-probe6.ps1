# UIA probe v6: click the trigger like a user (real SendInput), then verify the dropdown state.
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class Inp {
  [StructLayout(LayoutKind.Sequential)] public struct MOUSEINPUT { public int dx, dy; public uint mouseData, dwFlags, time; public IntPtr dwExtraInfo; }
  [StructLayout(LayoutKind.Sequential)] public struct INPUT { public uint type; public MOUSEINPUT mi; }
  [DllImport("user32.dll", SetLastError=true)] public static extern uint SendInput(uint n, INPUT[] inputs, int size);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  public static void Click(int sx, int sy) {
    INPUT[] a = new INPUT[3];
    a[0].type = 0; a[0].mi.dwFlags = 0x8000 | 0x0001; a[0].mi.dx = sx; a[0].mi.dy = sy; // MOVE|ABSOLUTE (virtual screen)
    a[1].type = 0; a[1].mi.dwFlags = 0x0002; // LEFTDOWN
    a[2].type = 0; a[2].mi.dwFlags = 0x0004; // LEFTUP
    // absolute coords must be normalized to 0..65535 over the virtual screen
    int vx = GetSystemMetrics(76), vy = GetSystemMetrics(77), vw = GetSystemMetrics(78), vh = GetSystemMetrics(79);
    a[0].mi.dx = (int)(((sx - vx) * 65535.0) / (vw - 1));
    a[0].mi.dy = (int)(((sy - vy) * 65535.0) / (vh - 1));
    SendInput(3, a, Marshal.SizeOf(typeof(INPUT)));
  }
  [DllImport("user32.dll")] public static extern int GetSystemMetrics(int i);
}
"@
$auto = [System.Windows.Automation.AutomationElement]
$root = $auto::RootElement
$trueCond = [System.Windows.Automation.Condition]::TrueCondition
$cond = New-Object System.Windows.Automation.PropertyCondition($auto::ClassNameProperty, "Chrome_WidgetWin_1")
$win = $null
foreach ($w in $root.FindAll([System.Windows.Automation.TreeScope]::Children, $cond)) {
  try { $r = $w.Current.BoundingRectangle } catch { continue }
  if ($r.Width -gt 500) { $win = $w }
}
function Get-Trigger {
  foreach ($e in $win.FindAll([System.Windows.Automation.TreeScope]::Descendants, $trueCond)) {
    if ($e.Current.Name -match '个后台任务') { return $e }
  }
  return $null
}
function State($el) {
  $ec = $null
  if ($el.TryGetCurrentPattern([System.Windows.Automation.ExpandCollapsePattern]::Pattern, [ref]$ec)) { return $ec.Current.ExpandCollapseState }
  return 'n/a'
}
function MenuInfo {
  foreach ($e in $win.FindAll([System.Windows.Automation.TreeScope]::Descendants, $trueCond)) {
    if ($e.Current.ClassName -eq 'QsffPG_menu') {
      $r = $e.Current.BoundingRectangle
      return ("MENU name='" + $e.Current.Name + "' rect=" + [int]$r.X + "," + [int]$r.Y + " " + [int]$r.Width + "x" + [int]$r.Height + " offscreen=" + $e.Current.IsOffscreen)
    }
  }
  return "MENU: absent"
}

$t = Get-Trigger
Write-Output ("trigger before: '" + $t.Current.Name + "' state=" + (State $t))
Write-Output ("menu before : " + (MenuInfo))

[Inp]::SetForegroundWindow([IntPtr]$win.Current.NativeWindowHandle) | Out-Null
Start-Sleep -Milliseconds 400
$tr = $t.Current.BoundingRectangle
$cx = [int]($tr.X + $tr.Width / 2); $cy = [int]($tr.Y + $tr.Height / 2)
Write-Output ("SendInput click at " + $cx + "," + $cy)
[Inp]::Click($cx, $cy)
Start-Sleep -Milliseconds 1200

$t2 = Get-Trigger
Write-Output ("trigger after click 1: '" + $t2.Current.Name + "' state=" + (State $t2))
Write-Output ("menu after click 1 : " + (MenuInfo))

[Inp]::Click($cx, $cy)
Start-Sleep -Milliseconds 1200
$t3 = Get-Trigger
Write-Output ("trigger after click 2: '" + $t3.Current.Name + "' state=" + (State $t3))
Write-Output ("menu after click 2 : " + (MenuInfo))

# leave it open, then check whether anything outside closes it (mouse move into the message list)
[Inp]::Click($cx, $cy)
Start-Sleep -Milliseconds 1000
Write-Output ("menu after click 3 : " + (MenuInfo))
