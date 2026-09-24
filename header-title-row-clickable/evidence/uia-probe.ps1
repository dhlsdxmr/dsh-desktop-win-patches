# UIA probe: does the "N 个后台任务" trigger actually open a menu in the live DSH Desktop window?
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes

$auto = [System.Windows.Automation.AutomationElement]
$root = $auto::RootElement

function Find-DshWindow {
  $cond = New-Object System.Windows.Automation.PropertyCondition($auto::NameProperty, "DSH Desktop")
  $w = $root.FindFirst([System.Windows.Automation.TreeScope]::Children, $cond)
  if ($w) { return $w }
  # fall back: any window whose class is Chrome_WidgetWin_1 and name matches
  $cond2 = New-Object System.Windows.Automation.PropertyCondition($auto::ClassNameProperty, "Chrome_WidgetWin_1")
  $all = $root.FindAll([System.Windows.Automation.TreeScope]::Children, $cond2)
  foreach ($c in $all) { if ($c.Current.Name) { return $c } }
  return $null
}

$win = Find-DshWindow
if (-not $win) { Write-Output "NO DSH WINDOW FOUND"; exit 1 }
Write-Output ("WINDOW: name='" + $win.Current.Name + "' class=" + $win.Current.ClassName + " pid=" + $win.Current.ProcessId)
$rect = $win.Current.BoundingRectangle
Write-Output ("RECT: " + $rect.X + "," + $rect.Y + " " + $rect.Width + "x" + $rect.Height)

# enumerate all buttons/descriptions in the window (shallow, subtree)
$trueCond = [System.Windows.Automation.Condition]::TrueCondition
$all = $win.FindAll([System.Windows.Automation.TreeScope]::Descendants, $trueCond)
Write-Output ("ELEMENTS: " + $all.Count)
$target = $null
foreach ($e in $all) {
  $n = $e.Current.Name
  if ($n -and ($n -match '后台任务')) {
    $r = $e.Current.BoundingRectangle
    Write-Output ("CANDIDATE: '" + $n + "' type=" + $e.Current.ControlType.ProgrammaticName + " rect=" + [int]$r.X + "," + [int]$r.Y + " " + [int]$r.Width + "x" + [int]$r.Height + " enabled=" + $e.Current.IsEnabled + " offscreen=" + $e.Current.IsOffscreen)
    if ($e.Current.ControlType.ProgrammaticName -eq 'ControlType.Button' -and -not $target) { $target = $e }
  }
}

if (-not $target) { Write-Output "NO TRIGGER BUTTON"; exit 2 }

# invoke it (UIA InvokePattern = a real programmatic click on the button)
$inv = $null
if ($target.TryGetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern, [ref]$inv)) {
  Write-Output "INVOKING via InvokePattern"
  $inv.Invoke()
} else {
  Write-Output "NO InvokePattern; falling back to mouse click at center"
  $r = $target.Current.BoundingRectangle
  Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class M {
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
  [DllImport("user32.dll")] public static extern void mouse_event(uint f, uint dx, uint dy, uint d, IntPtr e);
  public static void Click(int x, int y) {
    SetCursorPos(x, y);
    System.Threading.Thread.Sleep(60);
    mouse_event(0x0002, 0, 0, 0, IntPtr.Zero);
    System.Threading.Thread.Sleep(40);
    mouse_event(0x0004, 0, 0, 0, IntPtr.Zero);
  }
}
"@
  [M]::Click([int]($r.X + $r.Width / 2), [int]($r.Y + $r.Height / 2))
}
Start-Sleep -Milliseconds 700

# after the click: look for a list/menu element (the plugin renders <ul aria-label="后台任务"> with role=list)
$all2 = $win.FindAll([System.Windows.Automation.TreeScope]::Descendants, $trueCond)
Write-Output ("ELEMENTS AFTER: " + $all2.Count)
$found = 0
foreach ($e in $all2) {
  $ct = $e.Current.ControlType.ProgrammaticName
  $n = $e.Current.Name
  if ($ct -eq 'ControlType.List' -or $ct -eq 'ControlType.Menu' -or ($n -and $n -match '运行中|已完成|已取消|已失败|pwsh|速度|speedtest')) {
    $r = $e.Current.BoundingRectangle
    Write-Output ("AFTER-ELEMENT: type=" + $ct + " name='" + $n + "' rect=" + [int]$r.X + "," + [int]$r.Y + " " + [int]$r.Width + "x" + [int]$r.Height + " offscreen=" + $e.Current.IsOffscreen)
    $found++
  }
}
if ($found -eq 0) { Write-Output "NO MENU ELEMENT AFTER CLICK" }
