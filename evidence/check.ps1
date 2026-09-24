# One-shot check: did DSH Desktop actually reload the patched preload, and is the title row clickable now?
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class Hit3 {
  [DllImport("user32.dll")] public static extern IntPtr SendMessage(IntPtr h, uint msg, IntPtr wp, IntPtr lp);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
  public static int NcHitTest(IntPtr h, int sx, int sy) {
    RECT r; GetWindowRect(h, out r);
    IntPtr lp = (IntPtr)(((sy - r.T) << 16) | ((sx - r.L) & 0xFFFF));
    return (int)SendMessage(h, 0x0084, IntPtr.Zero, lp);
  }
}
"@

$preload = "D:\DSH\DSH Desktop\resources\app\out\preload\index.cjs"
$patchTime = (Get-Item $preload).LastWriteTime
$hash = (Get-FileHash $preload -Algorithm SHA256).Hash
Write-Output "== 补丁文件 =="
Write-Output ("  写入时间 : " + $patchTime.ToString("HH:mm:ss"))
Write-Output ("  SHA256   : " + $hash)
if ($hash -ne "79DFC53C1ACEE34354C234DCEBEE7E3F276B779A0D42B34531CF743D59F2C728") {
  Write-Output "  !! 哈希与预期不一致，补丁可能被覆盖或改动"
}

$procs = Get-Process -Name "DSH Desktop" -ErrorAction SilentlyContinue | Sort-Object StartTime
$main = $procs | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
if (-not $main) { $main = $procs | Select-Object -First 1 }
Write-Output "== 应用进程 =="
if ($main) {
  Write-Output ("  主窗口 pid=" + $main.Id + " 启动于 " + $main.StartTime.ToString("HH:mm:ss"))
  if ($main.StartTime -lt $patchTime) {
    Write-Output "  !! 应用启动时间早于补丁写入时间 —— 说明【还没重启】，补丁尚未加载"
  } else {
    Write-Output "  OK 应用启动晚于补丁写入时间 —— 补丁已加载"
  }
} else {
  Write-Output "  DSH Desktop 没在运行"
}

$auto = [System.Windows.Automation.AutomationElement]
$root = $auto::RootElement
$cond = New-Object System.Windows.Automation.PropertyCondition($auto::ClassNameProperty, "Chrome_WidgetWin_1")
$dshPids = $procs | Select-Object -ExpandProperty Id
$win = $null
foreach ($c in $root.FindAll([System.Windows.Automation.TreeScope]::Children, $cond)) {
  if ($dshPids -contains $c.Current.ProcessId) {
    try { $r = $c.Current.BoundingRectangle } catch { continue }
    if ($r.Width -gt 500) { $win = $c }
  }
}
if (-not $win) { Write-Output "== 找不到 DSH 窗口 =="; exit 1 }
$hwnd = [IntPtr]$win.Current.NativeWindowHandle
$tc = [System.Windows.Automation.Condition]::TrueCondition
$t = $null
foreach ($e in $win.FindAll([System.Windows.Automation.TreeScope]::Descendants, $tc)) {
  if ($e.Current.ClassName -eq 'QsffPG_trigger') { $t = $e; break }
}
Write-Output "== 命中测试 =="
if (-not $t) {
  Write-Output "  当前会话没有后台任务，所以「N 个后台任务」按钮不存在（左侧探针脚本会给它换个位置测）"
  $x = [int]$win.Current.BoundingRectangle.X + 400
} else {
  $tr = $t.Current.BoundingRectangle
  $x = [int](([int]$tr.X + [int]$tr.Right) / 2)
  Write-Output ("  按钮 '" + $t.Current.Name + "' rect=" + [int]$tr.X + "," + [int]$tr.Y + " " + [int]$tr.Width + "x" + [int]$tr.Height)
}
$v26 = [Hit3]::NcHitTest($hwnd, $x, 26)
$v46 = [Hit3]::NcHitTest($hwnd, $x, 46)
$name26 = if ($v26 -eq 1) { "HTCLIENT(可点)" } elseif ($v26 -eq 2) { "HTCAPTION(拖拽区/点不到)" } else { "code $v26" }
$name46 = if ($v46 -eq 1) { "HTCLIENT(可点)" } elseif ($v46 -eq 2) { "HTCAPTION(拖拽区/点不到)" } else { "code $v46" }
Write-Output ("  标题行 y=26 : " + $v26 + " " + $name26)
Write-Output ("  其下一行 y=46: " + $v46 + " " + $name46)
Write-Output ""
if ($v26 -eq 1) {
  Write-Output "== 结论 : 补丁已生效 ✅  现在可以用鼠标点「N 个后台任务」了 =="
} else {
  Write-Output "== 结论 : 标题行仍是拖拽区 ❌  把上面整段输出发回即可 =="
}
