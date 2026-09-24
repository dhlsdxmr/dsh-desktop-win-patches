# Read the DSH window title, where DRAG PROBE v3 publishes its findings.
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
$auto = [System.Windows.Automation.AutomationElement]
$root = $auto::RootElement
$cond = New-Object System.Windows.Automation.PropertyCondition($auto::ClassNameProperty, "Chrome_WidgetWin_1")
$dshPids = (Get-Process -Name "DSH Desktop" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Id)
$wins = @()
foreach ($c in $root.FindAll([System.Windows.Automation.TreeScope]::Children, $cond)) {
  if ($dshPids -contains $c.Current.ProcessId) {
    try { $r = $c.Current.BoundingRectangle } catch { continue }
    if ($r.Width -gt 500) { $wins += $c }
  }
}
foreach ($w in $wins) {
  $n = $w.Current.Name
  Write-Output ("pid=" + $w.Current.ProcessId + " titleLen=" + ($n | Measure-Object -Character).Characters)
  Write-Output "---- title ----"
  Write-Output $n
  Write-Output "---- end ----"
}
