# UIA probe v3: find the background-jobs trigger in the live DSH Desktop window, click it,
# and report whether a job-list popup appeared (and where).
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
$auto = [System.Windows.Automation.AutomationElement]
$root = $auto::RootElement
$trueCond = [System.Windows.Automation.Condition]::TrueCondition
$cond = New-Object System.Windows.Automation.PropertyCondition($auto::ClassNameProperty, "Chrome_WidgetWin_1")
$wins = $root.FindAll([System.Windows.Automation.TreeScope]::Children, $cond)
$win = $null
foreach ($w in $wins) { try { $r = $w.Current.BoundingRectangle } catch { continue }; if ($r.Width -gt 500) { $win = $w } }
if (-not $win) { Write-Output "NO WINDOW"; exit 1 }

function Snapshot($label) {
  $all = $win.FindAll([System.Windows.Automation.TreeScope]::Descendants, $trueCond)
  $rows = @()
  foreach ($e in $all) {
    $ct = $e.Current.ControlType.ProgrammaticName
    $n = $e.Current.Name
    if ($ct -in @('ControlType.List', 'ControlType.ListItem', 'ControlType.Menu', 'ControlType.MenuItem') -or ($n -and $n -match '个后台任务')) {
      $r = $e.Current.BoundingRectangle
      $rows += [pscustomobject]@{ Type = $ct; Name = $n; X = [int]$r.X; Y = [int]$r.Y; W = [int]$r.Width; H = [int]$r.Height; Off = $e.Current.IsOffscreen }
    }
  }
  Write-Output ("--- " + $label + " : " + $rows.Count + " job-related elements ---")
  $rows | ForEach-Object { Write-Output ("  " + $_.Type + " name='" + $_.Name + "' rect=" + $_.X + "," + $_.Y + " " + $_.W + "x" + $_.H + " offscreen=" + $_.Off) }
  return $rows
}

$before = Snapshot "BEFORE"

# locate the trigger
$trigger = $null
foreach ($e in $win.FindAll([System.Windows.Automation.TreeScope]::Descendants, $trueCond)) {
  $n = $e.Current.Name
  if ($n -and $n -match '个后台任务') { $trigger = $e; break }
}
if (-not $trigger) { Write-Output "NO TRIGGER FOUND (header may be scrolled out of the a11y tree)"; exit 2 }
$tr = $trigger.Current.BoundingRectangle
Write-Output ("TRIGGER: '" + $trigger.Current.Name + "' type=" + $trigger.Current.ControlType.ProgrammaticName + " rect=" + [int]$tr.X + "," + [int]$tr.Y + " " + [int]$tr.Width + "x" + [int]$tr.Height + " offscreen=" + $trigger.Current.IsOffscreen)

$inv = $null
if ($trigger.TryGetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern, [ref]$inv)) {
  Write-Output "INVOKE via InvokePattern"
  $inv.Invoke()
} else {
  Write-Output "NO InvokePattern -> mouse click"
  Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class M2 {
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
  [DllImport("user32.dll")] public static extern void mouse_event(uint f, uint dx, uint dy, uint d, IntPtr e);
  public static void Click(int x, int y) {
    SetCursorPos(x, y); System.Threading.Thread.Sleep(80);
    mouse_event(0x0002, 0, 0, 0, IntPtr.Zero); System.Threading.Thread.Sleep(50);
    mouse_event(0x0004, 0, 0, 0, IntPtr.Zero);
  }
}
"@
  [M2]::Click([int]($tr.X + $tr.Width / 2), [int]($tr.Y + $tr.Height / 2))
}
Start-Sleep -Milliseconds 900
$after = Snapshot "AFTER-CLICK"

$trig2 = $null
foreach ($e in $win.FindAll([System.Windows.Automation.TreeScope]::Descendants, $trueCond)) {
  $n = $e.Current.Name
  if ($n -and $n -match '个后台任务') { $trig2 = $e; break }
}
if ($trig2) {
  $exp = $trig2.GetCurrentPropertyValue([System.Windows.Automation.AutomationElement]::ExpandCollapsePatternProperty)
  Write-Output ("TRIGGER-AFTER: name='" + $trig2.Current.Name + "'")
  $ec = $null
  if ($trig2.TryGetCurrentPattern([System.Windows.Automation.ExpandCollapsePattern]::Pattern, [ref]$ec)) {
    Write-Output ("  ExpandCollapse state = " + $ec.Current.ExpandCollapseState)
  } else { Write-Output "  (no ExpandCollapsePattern)" }
}
Write-Output ("new job elements after click: " + $after.Count)
