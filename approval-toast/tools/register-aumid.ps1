# register-aumid.ps1 -- register a REAL AppUserModelID for DSH (HKCU scope only).
#
# WHY: ToastNotificationManager accepts any AppId string and records it in History,
# but renders NOTHING unless an app with that AppUserModelID is registered. Borrowing
# PowerShell's AUMID renders fine but signs the notification "PowerShell 7 (x64)".
# Registering our own makes the toast read "DeepSeek Harness".
#
# MEASURED (2026-09-24, this machine): the registry key ALONE is sufficient -- a Start
# Menu shortcut carrying the AUMID is NOT required, and no property-store COM work is
# needed. Contains no HKLM writes and no admin requirement. Fully reversible:
#   Remove-Item -Recurse 'HKCU:\SOFTWARE\Classes\AppUserModelId\DeepSeek.Harness.DSH'
param(
  [string]$Aumid = 'DeepSeek.Harness.DSH',
  [string]$DisplayName = 'DeepSeek Harness',
  [string]$IconUri = '',
  [string]$IconBackgroundColor = 'FF1A6CFF'
)
$ErrorActionPreference = 'Stop'

$key = Join-Path 'HKCU:\SOFTWARE\Classes\AppUserModelId' $Aumid
New-Item -Path $key -Force | Out-Null
New-ItemProperty -Path $key -Name DisplayName -Value $DisplayName -PropertyType String -Force | Out-Null
New-ItemProperty -Path $key -Name IconBackgroundColor -Value $IconBackgroundColor -PropertyType String -Force | Out-Null
if ($IconUri -ne '') {
  New-ItemProperty -Path $key -Name IconUri -Value $IconUri -PropertyType String -Force | Out-Null
}

Write-Output '--- registered under HKCU ---'
Write-Output ("key: {0}" -f $key)
Get-ItemProperty -Path $key | Format-List DisplayName,IconUri,IconBackgroundColor
