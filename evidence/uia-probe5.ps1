# UIA probe v5: drive the ExpandCollapsePattern and inspect the resulting popup.
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

function Get-Trigger {
  foreach ($e in $win.FindAll([System.Windows.Automation.TreeScope]::Descendants, $trueCond)) {
    $n = $e.Current.Name
    if ($n -and $n -match '个后台任务') { return $e }
  }
  return $null
}

$t = Get-Trigger
if (-not $t) { Write-Output "NO TRIGGER"; exit 2 }
$tr = $t.Current.BoundingRectangle
Write-Output ("TRIGGER '" + $t.Current.Name + "' rect=" + [int]$tr.X + "," + [int]$tr.Y + " " + [int]$tr.Width + "x" + [int]$tr.Height)
$ec = $null
$null = $t.TryGetCurrentPattern([System.Windows.Automation.ExpandCollapsePattern]::Pattern, [ref]$ec)
Write-Output ("  state before = " + $ec.Current.ExpandCollapseState)

Write-Output "EXPAND()"
$ec.Expand()
Start-Sleep -Milliseconds 1500

$t2 = Get-Trigger
if ($t2) {
  $ec2 = $null
  $null = $t2.TryGetCurrentPattern([System.Windows.Automation.ExpandCollapsePattern]::Pattern, [ref]$ec2)
  $r2 = $t2.Current.BoundingRectangle
  Write-Output ("  trigger now '" + $t2.Current.Name + "' rect=" + [int]$r2.X + "," + [int]$r2.Y + " state after = " + $ec2.Current.ExpandCollapseState)
}

Write-Output "--- job-list-ish elements (rows carry kind/status/duration) ---"
$i = 0
foreach ($e in $win.FindAll([System.Windows.Automation.TreeScope]::Descendants, $trueCond)) {
  $ct = $e.Current.ControlType.ProgrammaticName
  $n = $e.Current.Name
  $cls = $e.Current.ClassName
  if ($cls -match 'QsffPG_' -or ($n -and $n -match '运行中|已完成|已取消|已失败|后台任务|秒$|秒 |分')) {
    $r = $e.Current.BoundingRectangle
    Write-Output ("  " + $ct + " name='" + $n + "' class=" + $cls + " rect=" + [int]$r.X + "," + [int]$r.Y + " " + [int]$r.Width + "x" + [int]$r.Height + " offscreen=" + $e.Current.IsOffscreen)
    $i++
  }
}
Write-Output ("matches: " + $i)

Write-Output "--- hit test under the trigger (where a bottom-anchored menu would be) ---"
foreach ($y in 50, 70, 90, 120, 160, 200) {
  $hit = $auto::FromPoint([System.Windows.Point]::new(760, $y))
  Write-Output ("  y=" + $y + " -> " + $hit.Current.ControlType.ProgrammaticName + " name='" + $hit.Current.Name + "' class=" + $hit.Current.ClassName)
}
