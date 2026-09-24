# v7: (a) compare process integrity levels, (b) collapse then re-open with real input to test whether
# synthetic clicks reach the app at all.
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes

function Get-Integrity([int]$procId) {
  try {
    $p = Get-Process -Id $procId -ErrorAction Stop
    $h = $p.Handle
  } catch { return "no-handle" }
  return "handle-ok"
}

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class Tok {
  [DllImport("advapi32.dll", SetLastError=true)] public static extern bool OpenProcessToken(IntPtr p, uint acc, out IntPtr tok);
  [DllImport("advapi32.dll", SetLastError=true)] public static extern bool GetTokenInformation(IntPtr tok, int cls, IntPtr buf, int len, out int ret);
  [DllImport("kernel32.dll")] public static extern IntPtr OpenProcess(int acc, bool inherit, int pid);
  [DllImport("kernel32.dll")] public static extern bool CloseHandle(IntPtr h);
  public static string Level(int pid) {
    IntPtr hp = OpenProcess(0x1000, false, pid); // PROCESS_QUERY_LIMITED_INFORMATION
    if (hp == IntPtr.Zero) return "OpenProcess failed " + Marshal.GetLastWin32Error();
    IntPtr tok;
    if (!OpenProcessToken(hp, 0x0008, out tok)) { CloseHandle(hp); return "OpenProcessToken failed " + Marshal.GetLastWin32Error(); }
    int len; GetTokenInformation(tok, 25, IntPtr.Zero, 0, out len); // TokenIntegrityLevel
    IntPtr buf = Marshal.AllocHGlobal(len);
    string res = "?";
    if (GetTokenInformation(tok, 25, buf, len, out len)) {
      IntPtr sid = Marshal.ReadIntPtr(buf);           // TOKEN_MANDATORY_LABEL.Label.Sid
      byte sub = Marshal.ReadByte(sid, 8 + 8);        // SID revision(1)+count(1)+authority(6) -> first subauth
      int rid = Marshal.ReadInt32(sid, 8 + 8 + 4);    // second subauth
      res = "RID=" + rid;
      if (rid >= 0x4000) res += " (High/System)"; else if (rid >= 0x3000) res += " (Medium)"; else res += " (Low/Untrusted)";
    } else res = "GetTokenInformation failed " + Marshal.GetLastWin32Error();
    Marshal.FreeHGlobal(buf); CloseHandle(tok); CloseHandle(hp);
    return res;
  }
}
"@
$me = $PID
$dsh = (Get-Process -Name "DSH Desktop" | Sort-Object StartTime | Select-Object -First 1).Id
Write-Output ("powershell pid=" + $me + " integrity=" + [Tok]::Level($me))
foreach ($p in Get-Process -Name "DSH Desktop") { Write-Output ("DSH pid=" + $p.Id + " integrity=" + [Tok]::Level($p.Id)) }

$auto = [System.Windows.Automation.AutomationElement]
$root = $auto::RootElement
$trueCond = [System.Windows.Automation.Condition]::TrueCondition
$cond = New-Object System.Windows.Automation.PropertyCondition($auto::ClassNameProperty, "Chrome_WidgetWin_1")
$win = $null
foreach ($w in $root.FindAll([System.Windows.Automation.TreeScope]::Children, $cond)) {
  try { $r = $w.Current.BoundingRectangle } catch { continue }
  if ($r.Width -gt 500) { $win = $w }
}
function Get-Trigger {
  foreach ($e in $win.FindAll([System.Windows.Automation.TreeScope]::Descendants, $trueCond)) {
    if ($e.Current.Name -match '个后台任务') { return $e }
  }
  return $null
}
$t = Get-Trigger
$ec = $null; $null = $t.TryGetCurrentPattern([System.Windows.Automation.ExpandCollapsePattern]::Pattern, [ref]$ec)
Write-Output ("state now = " + $ec.Current.ExpandCollapseState)
if ($ec.Current.ExpandCollapseState -eq 'Expanded') { $ec.Collapse(); Start-Sleep -Milliseconds 800 }
$t = Get-Trigger
$ec = $null; $null = $t.TryGetCurrentPattern([System.Windows.Automation.ExpandCollapsePattern]::Pattern, [ref]$ec)
Write-Output ("state after Collapse() = " + $ec.Current.ExpandCollapseState)

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class Clk {
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
  [DllImport("user32.dll")] public static extern void mouse_event(uint f, uint dx, uint dy, uint d, IntPtr e);
  public static void Click(int x, int y) {
    SetCursorPos(x, y); System.Threading.Thread.Sleep(150);
    mouse_event(0x0002, 0, 0, 0, IntPtr.Zero); System.Threading.Thread.Sleep(70);
    mouse_event(0x0004, 0, 0, 0, IntPtr.Zero);
  }
}
"@
$tr = $t.Current.BoundingRectangle
[Clk]::Click([int]($tr.X + $tr.Width / 2), [int]($tr.Y + $tr.Height / 2))
Start-Sleep -Milliseconds 1200
$t = Get-Trigger
$ec = $null; $null = $t.TryGetCurrentPattern([System.Windows.Automation.ExpandCollapsePattern]::Pattern, [ref]$ec)
Write-Output ("state after REAL mouse click = " + $ec.Current.ExpandCollapseState)
