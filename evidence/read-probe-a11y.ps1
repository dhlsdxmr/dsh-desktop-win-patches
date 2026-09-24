# Read the DRAG PROBE sentinel + report lines out of the accessibility tree.
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
$dp = @()
$sent = @()
foreach ($e in $win.FindAll([System.Windows.Automation.TreeScope]::Descendants, $tc)) {
  $n = $e.Current.Name
  if ($n -match '^DP\d\d ') { $dp += $n }
  if ($n -match '^SENTINEL ') { $sent += $n }
}
Write-Output "---- sentinel (" + $sent.Count + ") ----"
$sent | ForEach-Object { Write-Output ("  " + $_) }
Write-Output "---- DP lines (" + $dp.Count + ") ----"
$dp | Sort-Object | ForEach-Object { Write-Output ("  " + $_) }
if ($dp.Count -eq 0 -and $sent.Count -eq 0) { Write-Output "  (nothing found — probe did not run in this document)" }
