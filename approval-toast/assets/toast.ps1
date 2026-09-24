# toast.ps1 -- raise a real Windows toast. ASCII-only source on purpose (a non-ASCII
# .ps1 needs a UTF-8 BOM to load in PowerShell 5.1; text arrives as -Title/-Body
# arguments instead, which Windows passes as wide chars regardless of console codepage).
#
# WHY powershell.exe 5.1 and not pwsh 7: the WinRT projections below only resolve in
# 5.1 (PS 7 needs the Microsoft.Windows.SDK.NET assembly).
#
# WHY -AppId matters (the whole point of this file): ToastNotificationManager accepts
# ANY string as an AppId, stores it in History, and renders NOTHING unless an app with
# that AppUserModelID is actually registered. A bogus AppId therefore looks like a
# success (no throw, History count grows) while the user sees nothing at all.
# Default is our own registered AUMID; see tools/register-aumid.ps1.
param(
  [string]$AppId = 'DeepSeek.Harness.DSH',
  [string]$Title = 'DSH approval request',
  [string]$Body  = 'A tool wants to run outside the sandbox.'
)
$ErrorActionPreference = 'Stop'

[void][Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime]
[void][Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime]

$esc = { param($s) [System.Security.SecurityElement]::Escape($s) }
# scenario="reminder" + duration="long" keeps the toast on screen until the user
# deals with it, instead of the default ~5s that is easy to miss.
$template = @"
<toast scenario="reminder" duration="long">
  <visual>
    <binding template="ToastGeneric">
      <text>$(& $esc $Title)</text>
      <text>$(& $esc $Body)</text>
    </binding>
  </visual>
  <audio src="ms-winsoundevent:Notification.Reminder" loop="false" />
</toast>
"@

$xml = New-Object Windows.Data.Xml.Dom.XmlDocument
$xml.LoadXml($template)
$toast = New-Object Windows.UI.Notifications.ToastNotification $xml

$history = [Windows.UI.Notifications.ToastNotificationManager]::History
$before = @($history.GetHistory($AppId)).Count
$notifier = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($AppId)
$notifier.Show($toast)
Start-Sleep -Seconds 1
$after = @($history.GetHistory($AppId))

# History growth is NOT proof of delivery -- only that the platform accepted the
# call. It is reported so a failure can be told apart from a ghost AUMID.
Write-Output ("AppId  : {0}" -f $AppId)
Write-Output ("history: before={0} after={1}" -f $before, $after.Count)
