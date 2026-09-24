# Is the third-party "小鲸鱼记账" widget's mask covering the header title row?
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
Write-Output ("pid=" + $win.Current.ProcessId)
$n = 0
foreach ($e in $win.FindAll([System.Windows.Automation.TreeScope]::Descendants, $tc)) {
  $cn = $e.Current.ClassName
  if ($cn -match 'dshwv') {
    $r = $e.Current.BoundingRectangle
    $w = 0; $h = 0
    try { $w = [int]$r.Width; $h = [int]$r.Height } catch { }
    Write-Output ("  " + $e.Current.ControlType.ProgrammaticName + " class=" + $cn + " name='" + $e.Current.Name + "' rect=" + [int]$r.X + "," + [int]$r.Y + " " + $w + "x" + $h + " off=" + $e.Current.IsOffscreen)
    $n++
    if ($n -gt 25) { break }
  }
}
if ($n -eq 0) { Write-Output "  no dshwv nodes found" }
Write-Output "--- trigger for reference ---"
foreach ($e in $win.FindAll([System.Windows.Automation.TreeScope]::Descendants, $tc)) {
  if ($e.Current.ClassName -eq 'QsffPG_trigger') {
    $r = $e.Current.BoundingRectangle
    Write-Output ("  trigger rect=" + [int]$r.X + "," + [int]$r.Y + " " + [int]$r.Width + "x" + [int]$r.Height)
  }
}
