# UIA probe v4: diagnose the trigger element's patterns and what a real click does.
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
$auto = [System.Windows.Automation.AutomationElement]
$root = $auto::RootElement
$trueCond = [System.Windows.Automation.Condition]::TrueCondition
$cond = New-Object System.Windows.Automation.PropertyCondition($auto::ClassNameProperty, "Chrome_WidgetWin_1")
$win = $null
foreach ($w in $root.FindAll([System.Windows.Automation.TreeScope]::Children, $cond)) {
  try { $r = $w.Current.BoundingRectangle } catch { continue }
  if ($r.Width -gt 500) { $win = $w }
}
if (-not $win) { Write-Output "NO WINDOW"; exit 1 }

$trigger = $null
foreach ($e in $win.FindAll([System.Windows.Automation.TreeScope]::Descendants, $trueCond)) {
  $n = $e.Current.Name
  if ($n -and $n -match '个后台任务') { $trigger = $e; break }
}
if (-not $trigger) { Write-Output "NO TRIGGER"; exit 2 }
$tr = $trigger.Current.BoundingRectangle
Write-Output ("TRIGGER '" + $trigger.Current.Name + "' rect=" + [int]$tr.X + "," + [int]$tr.Y + " " + [int]$tr.Width + "x" + [int]$tr.Height + " class=" + $trigger.Current.ClassName + " offscreen=" + $trigger.Current.IsOffscreen)

# patterns
$p1 = $null; if ($trigger.TryGetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern, [ref]$p1)) { Write-Output "  pattern OK: InvokePattern" }
$p2 = $null; if ($trigger.TryGetCurrentPattern([System.Windows.Automation.ExpandCollapsePattern]::Pattern, [ref]$p2)) { Write-Output "  pattern OK: ExpandCollapsePattern" }
$p3 = $null; if ($trigger.TryGetCurrentPattern([System.Windows.Automation.LegacyIAccessiblePattern]::Pattern, [ref]$p3)) { Write-Output "  pattern OK: LegacyIAccessiblePattern" }
$p4 = $null; if ($trigger.TryGetCurrentPattern([System.Windows.Automation.TogglePattern]::Pattern, [ref]$p4)) { Write-Output "  pattern OK: TogglePattern" }
$p5 = $null; if ($trigger.TryGetCurrentPattern([System.Windows.Automation.SelectionItemPattern]::Pattern, [ref]$p5)) { Write-Output "  pattern OK: SelectionItemPattern" }
$p6 = $null; if ($trigger.TryGetCurrentPattern([System.Windows.Automation.ScrollItemPattern]::Pattern, [ref]$p6)) { Write-Output "  pattern OK: ScrollItemPattern" }

# element at the trigger center, seen by the app itself (hit test)
$cx = [int]($tr.X + $tr.Width / 2); $cy = [int]($tr.Y + $tr.Height / 2)
$hit = $auto::FromPoint([System.Windows.Point]::new($cx, $cy))
Write-Output ("HITTEST at " + $cx + "," + $cy + " -> " + $hit.Current.ControlType.ProgrammaticName + " name='" + $hit.Current.Name + "' class=" + $hit.Current.ClassName)

# click with mouse and capture before/after element names
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class M3 {
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
  [DllImport("user32.dll")] public static extern void mouse_event(uint f, uint dx, uint dy, uint d, IntPtr e);
  public static void Move(int x, int y) { SetCursorPos(x, y); }
  public static void Down() { mouse_event(0x0002, 0, 0, 0, IntPtr.Zero); }
  public static void Up() { mouse_event(0x0004, 0, 0, 0, IntPtr.Zero); }
  public static void ClickAt(int x, int y) { SetCursorPos(x, y); System.Threading.Thread.Sleep(120); mouse_event(0x0002,0,0,0,IntPtr.Zero); System.Threading.Thread.Sleep(60); mouse_event(0x0004,0,0,0,IntPtr.Zero); }
}
"@
$before = @{}
foreach ($e in $win.FindAll([System.Windows.Automation.TreeScope]::Descendants, $trueCond)) {
  $k = $e.Current.ControlType.ProgrammaticName + "|" + $e.Current.Name
  if ($before.ContainsKey($k)) { $before[$k]++ } else { $before[$k] = 1 }
}
Write-Output ("before elements: " + $before.Count + " total=" + ($before.Values | Measure-Object -Sum).Sum)

[M3]::Move($cx, $cy)
Start-Sleep -Milliseconds 250
[M3]::Down(); Start-Sleep -Milliseconds 90; [M3]::Up()
Start-Sleep -Milliseconds 1200

$after = @{}
foreach ($e in $win.FindAll([System.Windows.Automation.TreeScope]::Descendants, $trueCond)) {
  $k = $e.Current.ControlType.ProgrammaticName + "|" + $e.Current.Name
  if ($after.ContainsKey($k)) { $after[$k]++ } else { $after[$k] = 1 }
}
Write-Output ("after elements: " + $after.Count + " total=" + ($after.Values | Measure-Object -Sum).Sum)
Write-Output "--- appeared ---"
foreach ($k in $after.Keys) { if (-not $before.ContainsKey($k)) { Write-Output ("  + " + $k) } }
Write-Output "--- disappeared ---"
foreach ($k in $before.Keys) { if (-not $after.ContainsKey($k)) { Write-Output ("  - " + $k) } }

# also re-read the trigger name (aria-label changes with state)
foreach ($e in $win.FindAll([System.Windows.Automation.TreeScope]::Descendants, $trueCond)) {
  $n = $e.Current.Name
  if ($n -and $n -match '个后台任务') {
    $r = $e.Current.BoundingRectangle
    Write-Output ("TRIGGER-NOW '" + $n + "' rect=" + [int]$r.X + "," + [int]$r.Y + " " + [int]$r.Width + "x" + [int]$r.Height)
    $ec = $null
    if ($e.TryGetCurrentPattern([System.Windows.Automation.ExpandCollapsePattern]::Pattern, [ref]$ec)) { Write-Output ("  expand state: " + $ec.Current.ExpandCollapseState) }
    break
  }
}
