# Send real WM_LBUTTON* messages directly to the app window's content HWND at several y offsets
# inside the jobs trigger, to see which part of the button is actually clickable.
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class Wm {
  [DllImport("user32.dll")] public static extern IntPtr WindowFromPoint(POINT p);
  [DllImport("user32.dll")] public static extern IntPtr SendMessage(IntPtr h, uint msg, IntPtr wp, IntPtr lp);
  [DllImport("user32.dll")] public static extern IntPtr ChildWindowFromPointEx(IntPtr parent, POINT p, uint flags);
  [DllImport("user32.dll")] public static extern int GetWindowThreadProcessId(IntPtr h, out int pid);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetClassNameW(IntPtr h, System.Text.StringBuilder s, int n);
  [StructLayout(LayoutKind.Sequential)] public struct POINT { public int X, Y; }
  public static string ClassOf(IntPtr h) { var sb = new System.Text.StringBuilder(256); GetClassNameW(h, sb, 256); return sb.ToString(); }
  public static void ClickAtScreen(IntPtr target, int sx, int sy) {
    // lParam is client-relative for the target window
    RECT r; GetWindowRect(target, out r);
    int lx = sx - r.L, ly = sy - r.T;
    IntPtr lp = (IntPtr)((ly << 16) | (lx & 0xFFFF));
    PostMessage(target, 0x0200, IntPtr.Zero, lp);              // WM_MOUSEMOVE
    System.Threading.Thread.Sleep(40);
    PostMessage(target, 0x0201, (IntPtr)1, lp);                 // WM_LBUTTONDOWN
    System.Threading.Thread.Sleep(90);
    PostMessage(target, 0x0202, IntPtr.Zero, lp);               // WM_LBUTTONUP
  }
  [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h, uint msg, IntPtr wp, IntPtr lp);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
}
"@
$auto = [System.Windows.Automation.AutomationElement]
$root = $auto::RootElement
$tc = [System.Windows.Automation.Condition]::TrueCondition
$cond = New-Object System.Windows.Automation.PropertyCondition($auto::ClassNameProperty, "Chrome_WidgetWin_1")
$win = $null
foreach ($c in $root.FindAll([System.Windows.Automation.TreeScope]::Children, $cond)) {
  try { $r = $c.Current.BoundingRectangle } catch { continue }
  if ($r.Width -gt 500) { $win = $c }
}
$hwnd = [IntPtr]$win.Current.NativeWindowHandle

function Get-Trigger {
  foreach ($e in $win.FindAll([System.Windows.Automation.TreeScope]::Descendants, $tc)) {
    if ($e.Current.Name -match '个后台任务') { return $e }
  }
  return $null
}
function State($el) {
  $ec = $null
  if ($el.TryGetCurrentPattern([System.Windows.Automation.ExpandCollapsePattern]::Pattern, [ref]$ec)) { return $ec.Current.ExpandCollapseState }
  return 'n/a'
}
function MenuPresent {
  foreach ($e in $win.FindAll([System.Windows.Automation.TreeScope]::Descendants, $tc)) {
    if ($e.Current.ClassName -eq 'QsffPG_menu') { return $true }
  }
  return $false
}

# make sure it starts collapsed
$t = Get-Trigger
$ec = $null; $null = $t.TryGetCurrentPattern([System.Windows.Automation.ExpandCollapsePattern]::Pattern, [ref]$ec)
if ($ec.Current.ExpandCollapseState -eq 'Expanded') { $ec.Collapse(); Start-Sleep -Milliseconds 600 }
Write-Output ("start state = " + (State (Get-Trigger)) + " menuPresent=" + (MenuPresent))

# which hwnd is at the click point, and its class?
foreach ($pt in @(@(775, 26), @(775, 40), @(775, 46))) {
  $p = New-Object Wm+POINT
  $p.X = $pt[0]; $p.Y = $pt[1]
  $h = [Wm]::WindowFromPoint($p)
  $procId = 0
  $null = [Wm]::GetWindowThreadProcessId($h, [ref]$procId)
  Write-Output ("  screen " + $pt[0] + "," + $pt[1] + " -> hwnd=" + $h + " class=" + [Wm]::ClassOf($h) + " pid=" + $procId)
}

# click at the vertical centre then at the bottom edge of the button
foreach ($y in 26, 46) {
  $t = Get-Trigger
  if (-not $t) { Write-Output "trigger gone"; break }
  $r = $t.Current.BoundingRectangle
  $x = [int]($r.X + $r.Width / 2)
  Write-Output ("WM click at screen " + $x + "," + $y + " (button rect y " + [int]$r.Y + ".." + [int]$r.Bottom + ")")
  [Wm]::ClickAtScreen($hwnd, $x, $y)
  Start-Sleep -Milliseconds 1000
  $t2 = Get-Trigger
  Write-Output ("   -> state=" + (State $t2) + " menuPresent=" + (MenuPresent))
}

