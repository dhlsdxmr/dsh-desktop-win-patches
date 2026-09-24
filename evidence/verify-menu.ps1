# Verify the jobs dropdown opens (accessibility-driven, DSH window selected by owning process).
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
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
if (-not $win) { Write-Output "NO DSH WINDOW"; exit 1 }

$t = $null
foreach ($e in $win.FindAll([System.Windows.Automation.TreeScope]::Descendants, $tc)) {
  if ($e.Current.ClassName -eq 'QsffPG_trigger') { $t = $e; break }
}
if (-not $t) { Write-Output "TRIGGER NOT FOUND"; exit 2 }
$tr = $t.Current.BoundingRectangle
Write-Output ("trigger name='" + $t.Current.Name + "' rect=" + [int]$tr.X + "," + [int]$tr.Y + " " + [int]$tr.Width + "x" + [int]$tr.Height)
$ec = $null
$null = $t.TryGetCurrentPattern([System.Windows.Automation.ExpandCollapsePattern]::Pattern, [ref]$ec)
Write-Output ("state before = " + $ec.Current.ExpandCollapseState)

$ec.Expand()
Start-Sleep -Milliseconds 900
$menu = $null
foreach ($e in $win.FindAll([System.Windows.Automation.TreeScope]::Descendants, $tc)) {
  if ($e.Current.ClassName -eq 'QsffPG_menu') { $menu = $e }
}
if ($menu) {
  $mr = $menu.Current.BoundingRectangle
  Write-Output ("menu OPEN name='" + $menu.Current.Name + "' rect=" + [int]$mr.X + "," + [int]$mr.Y + " " + [int]$mr.Width + "x" + [int]$mr.Height)
  foreach ($li in $menu.FindAll([System.Windows.Automation.TreeScope]::Children, $tc)) {
    Write-Output ("  row: " + $li.Current.Name)
  }
} else {
  Write-Output "menu ABSENT"
}

$ec.Collapse()
Start-Sleep -Milliseconds 500
$ec2 = $null
$null = $t.TryGetCurrentPattern([System.Windows.Automation.ExpandCollapsePattern]::Pattern, [ref]$ec2)
Write-Output ("state left as = " + $ec2.Current.ExpandCollapseState)
