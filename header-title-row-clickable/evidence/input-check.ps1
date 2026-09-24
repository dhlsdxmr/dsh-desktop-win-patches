# Is synthetic input actually reaching the DSH window? Verify cursor position + foreground window.
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class Probe {
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] public static extern int GetWindowThreadProcessId(IntPtr h, out int pid);
  [DllImport("user32.dll")] public static extern bool GetCursorPos(out POINT p);
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
  [DllImport("user32.dll")] public static extern void mouse_event(uint f, uint dx, uint dy, uint d, IntPtr e);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowTextW(IntPtr h, System.Text.StringBuilder s, int n);
  [StructLayout(LayoutKind.Sequential)] public struct POINT { public int X, Y; }
  public static string Fg() {
    IntPtr h = GetForegroundWindow(); int pid; GetWindowThreadProcessId(h, out pid);
    var sb = new System.Text.StringBuilder(256); GetWindowTextW(h, sb, 256);
    return "hwnd=" + h + " pid=" + pid + " title='" + sb + "'";
  }
  public static string Cursor() { POINT p; GetCursorPos(out p); return p.X + "," + p.Y; }
}
"@
Write-Output ("foreground: " + [Probe]::Fg())
Write-Output ("cursor now: " + [Probe]::Cursor())
[Probe]::SetCursorPos(806, 26) | Out-Null
Start-Sleep -Milliseconds 300
Write-Output ("cursor after SetCursorPos(806,26): " + [Probe]::Cursor())
Write-Output ("foreground after: " + [Probe]::Fg())
# click and leave the pointer over the trigger
[Probe]::mouse_event(0x0002, 0, 0, 0, [IntPtr]::Zero); Start-Sleep -Milliseconds 60
[Probe]::mouse_event(0x0004, 0, 0, 0, [IntPtr]::Zero)
Start-Sleep -Milliseconds 500
Write-Output ("cursor after click: " + [Probe]::Cursor())
Write-Output ("foreground after click: " + [Probe]::Fg())
