# Report every child element of the conversation <header>, with class names and anchors,
# so the preload CSS selectors (which depend on header's first child + class tokens) can be checked
# against the real DOM.
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
if (-not $win) { Write-Output "NO WINDOW"; exit 1 }
Write-Output ("window pid=" + $win.Current.ProcessId + " rect=" + [int]$win.Current.BoundingRectangle.X + "," + [int]$win.Current.BoundingRectangle.Y + " " + [int]$win.Current.BoundingRectangle.Width + "x" + [int]$win.Current.BoundingRectangle.Height)

# header group
$header = $null
foreach ($e in $win.FindAll([System.Windows.Automation.TreeScope]::Descendants, $tc)) {
  if ($e.Current.ClassName -eq 'wSkVaW_header') { $header = $e; break }
}
if (-not $header) { Write-Output "no header node"; exit 2 }
Write-Output "-- header children (direct) --"
foreach ($e in $header.FindAll([System.Windows.Automation.TreeScope]::Children, $tc)) {
  $r = $e.Current.BoundingRectangle
  Write-Output ("   [" + $e.Current.ClassName + "] type=" + $e.Current.ControlType.ProgrammaticName + " rect=" + [int]$r.X + "," + [int]$r.Y + " " + [int]$r.Width + "x" + [int]$r.Height)
  foreach ($g in $e.FindAll([System.Windows.Automation.TreeScope]::Children, $tc)) {
    $gr = $g.Current.BoundingRectangle
    Write-Output ("      +- [" + $g.Current.ClassName + "] type=" + $g.Current.ControlType.ProgrammaticName + " name='" + $g.Current.Name + "' rect=" + [int]$gr.X + "," + [int]$gr.Y + " " + [int]$gr.Width + "x" + [int]$gr.Height)
    foreach ($h in $g.FindAll([System.Windows.Automation.TreeScope]::Children, $tc)) {
      $hr = $h.Current.BoundingRectangle
      Write-Output ("         +- [" + $h.Current.ClassName + "] type=" + $h.Current.ControlType.ProgrammaticName + " name='" + $h.Current.Name + "' rect=" + [int]$hr.X + "," + [int]$hr.Y + " " + [int]$hr.Width + "x" + [int]$hr.Height)
    }
  }
}
Write-Output "-- trigger present? --"
$t = $null
foreach ($e in $win.FindAll([System.Windows.Automation.TreeScope]::Descendants, $tc)) {
  if ($e.Current.ClassName -eq 'QsffPG_trigger') { $t = $e; break }
}
if ($t) { Write-Output ("   yes: '" + $t.Current.Name + "' rect=" + [int]$t.Current.BoundingRectangle.X + "," + [int]$t.Current.BoundingRectangle.Y + " " + [int]$t.Current.BoundingRectangle.Width + "x" + [int]$t.Current.BoundingRectangle.Height) } else { Write-Output "   no" }
