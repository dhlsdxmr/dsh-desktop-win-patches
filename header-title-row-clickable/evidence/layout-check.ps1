# Is the injected titlebar CSS actually affecting layout at all?
# The injected sheet says: tabs { padding-right: 180px } -> the tabs box should be ~180px narrower
# than the title row. If it is that narrow, the whole injected sheet is live.
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
$wr = $win.Current.BoundingRectangle
Write-Output ("pid=" + $win.Current.ProcessId + " win=(" + [int]$wr.X + "," + [int]$wr.Y + " " + [int]$wr.Width + "x" + [int]$wr.Height + ")")

function Box($e) {
  $r = $e.Current.BoundingRectangle
  return [pscustomobject]@{ X = [int]$r.X; Y = [int]$r.Y; W = [int]$r.Width; H = [int]$r.Height; R = [int]$r.Right; B = [int]$r.Bottom }
}
$found = @{}
foreach ($e in $win.FindAll([System.Windows.Automation.TreeScope]::Descendants, $tc)) {
  $cn = $e.Current.ClassName
  if ($cn -match 'wSkVaW_(header|titleRow|tabs|headerUtilities|headerCorner|titleCluster|crumbs)$' -or $cn -match 'wSkVaW_(header|titleRow|tabs|headerUtilities|headerCorner|titleCluster|crumbs) ') {
    if (-not $found.ContainsKey($cn)) { $found[$cn] = Box $e }
  }
}
foreach ($k in $found.Keys) {
  $b = $found[$k]
  Write-Output ("  " + $k + " : x=" + $b.X + " y=" + $b.Y + " w=" + $b.W + " h=" + $b.H + " right=" + $b.R)
}
if ($found.ContainsKey('wSkVaW_tabs') -and $found.ContainsKey('wSkVaW_titleRow')) {
  $tr = $found['wSkVaW_titleRow']; $tb = $found['wSkVaW_tabs']
  $dTitle = $tr.R - $tr.X
  $dTabs = $tb.R - $tb.X
  Write-Output ("  width(titleRow)=" + $dTitle + " width(tabs)=" + $dTabs + " diff=" + ($dTitle - $dTabs))
  Write-Output ("  >>> 若 CSS 生效: diff 应约为 180（CSS 像素，屏幕像素约 225）")
}
