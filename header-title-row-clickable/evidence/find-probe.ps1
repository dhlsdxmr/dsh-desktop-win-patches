# Search the a11y tree for any trace of the probe (banner text, sentinel, DP labels).
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
$hits = @()
$all = $win.FindAll([System.Windows.Automation.TreeScope]::Descendants, $tc)
Write-Output ("total a11y nodes = " + $all.Count)
foreach ($e in $all) {
  $n = $e.Current.Name
  $cn = $e.Current.ClassName
  if ($n -match 'DRAGPROBE|SENTINEL|markedTotal|titleRow|layoutSheet|DP\d\d|dsh-probe|dsh-dragprobe') {
    $hits += ($e.Current.ControlType.ProgrammaticName + " class=" + $cn + " name=" + $n.Substring(0, [Math]::Min(160, $n.Length)))
  }
}
if ($hits.Count -eq 0) { Write-Output "no probe traces in the a11y tree" } else { $hits | ForEach-Object { Write-Output ("  " + $_) } }
# also: which elements exist in the top band right now?
Write-Output "---- top-band nodes (name/class) ----"
$n2 = 0
foreach ($e in $all) {
  try { $r = $e.Current.BoundingRectangle } catch { continue }
  if ($r.Width -le 0) { continue }
  if ($r.Y -ge 0 -and $r.Y -lt 40 -and $r.X -gt 300) {
    Write-Output ("  " + $e.Current.ControlType.ProgrammaticName + " class=" + $e.Current.ClassName + " name='" + $e.Current.Name + "' y=" + [int]$r.Y + " h=" + [int]$r.Height)
    $n2++
    if ($n2 -gt 12) { break }
  }
}
