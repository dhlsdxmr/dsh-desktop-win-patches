#!/usr/bin/env pwsh
# apply-dsh-patches.ps1 -- pure ASCII
#
# Re-apply the two local DSH Desktop (Windows) patches after a DSH update has
# overwritten them. Idempotent: running it twice is safe.
#
#   .\apply-dsh-patches.ps1            detect + apply whatever is missing + verify
#   .\apply-dsh-patches.ps1 -Check     report only, change nothing
#   .\apply-dsh-patches.ps1 -Revert    undo both patches (restore upstream behaviour)
#
# Patch A: append a no-drag fix block to  resources/app/out/preload/index.cjs
# Patch B: four edits in  …/@deepseek-ai/dsh-native-command/lib/index.js
#
# Exit 0 = the requested end state holds.  Exit 1 = something failed (it says what).

[CmdletBinding()]
param(
  [string]$DshRoot = 'D:\DSH\DSH Desktop',
  [switch]$Check,
  [switch]$Revert
)

$ErrorActionPreference = 'Stop'

# --- locate the two patch targets ------------------------------------------
$preloadRel  = 'resources\app\out\preload\index.cjs'
$nativeRel   = 'resources\app\node_modules\@deepseek-ai\dsh-native-command\lib\index.js'
$preloadPath = Join-Path $DshRoot $preloadRel
$nativePath  = Join-Path $DshRoot $nativeRel
$fixBlock    = Join-Path $PSScriptRoot 'src\preload-index-fix.js'

# A node binary is only needed for the node --check verification step.
$nodeCandidates = @(
  (Join-Path $DshRoot 'resources\app\node_modules\node\bin\node.exe'),
  'D:\DSH\DSH Desktop\resources\app\node_modules\node\bin\node.exe',
  'node'
)
$nodeExe = $null
foreach ($c in $nodeCandidates) {
  if ($c -eq 'node') { $nodeExe = 'node'; break }
  if (Test-Path $c) { $nodeExe = $c; break }
}

$MARK_A_BEGIN = '// ==== DSH local fix: keep the conversation-header title row clickable on Windows ===='
$MARK_A_END   = '// ==== end DSH local fix ===='

$problems = New-Object System.Collections.Generic.List[string]
$actions  = New-Object System.Collections.Generic.List[string]

function Note([string]$m) { Write-Host "  $m" }

Write-Host "=== preflight ==="
foreach ($p in @($preloadPath, $nativePath)) {
  if (-not (Test-Path $p)) { throw "patch target not found: $p  (wrong -DshRoot?)" }
  Note ("found " + $p)
}
if (-not $Revert -and -not (Test-Path $fixBlock)) { throw "missing patch source: $fixBlock" }
Note ("node for verification: " + $nodeExe)

# --- helpers ----------------------------------------------------------------
function Get-Text([string]$p) { return [System.IO.File]::ReadAllText($p) }
function Set-Text([string]$p, [string]$t) { [System.IO.File]::WriteAllText($p, $t, (New-Object System.Text.UTF8Encoding($false))) }

function Test-NodeCheck([string]$p) {
  if ($nodeExe -eq $null) { return $null }
  $out = & $nodeExe --check $p 2>&1 | Out-String
  $code = $LASTEXITCODE
  if ($code -ne 0) { Write-Host $out; return $false }
  return $true
}

# ===========================================================================
# Patch A - preload/index.cjs
# ===========================================================================
Write-Host "=== Patch A: preload title-row no-drag ==="

$preloadText = Get-Text $preloadPath
$hasA = $preloadText.Contains($MARK_A_END)

if ($Check) {
  Note ($(if ($hasA) { 'APPLIED' } else { 'MISSING' }))
}
elseif ($Revert) {
  if (-not $hasA) { Note 'not applied - nothing to revert' }
  else {
    $idx = $preloadText.IndexOf($MARK_A_BEGIN)
    if ($idx -lt 0) { throw "found the end marker but not the begin marker in $preloadRel" }
    Set-Text $preloadPath ($preloadText.Substring(0, $idx).TrimEnd() + "`r`n")
    $actions.Add('A: reverted')
    Note 'reverted'
  }
}
else {
  if ($hasA) { Note 'already applied - skipping' }
  else {
    $block = (Get-Text $fixBlock).TrimEnd()
    Set-Text $preloadPath ($preloadText.TrimEnd() + "`r`n`r`n" + $block + "`r`n")
    $actions.Add('A: applied')
    Note 'applied (block appended)'
  }
}

# ===========================================================================
# Patch B - dsh-native-command/lib/index.js
# ===========================================================================
Write-Host "=== Patch B: explorer reveal ==="

# Each edit is (detect, from, to). Detect is tested against the CURRENT text;
# if it already matches, the edit is skipped. `from`/`to` are regex pairs.
$edits = @(
  @{
    Name = 'B1a signature: runner accepts extra process options'
    Done = [regex]'(?s)runNativeCommand\s*=\s*\(command,\s*args,\s*signal,\s*options\s*=\s*\{\s*\}\)'
    From = '(?s)(runNativeCommand\s*=\s*\(command,\s*args,\s*signal)(\)\s*=>)'
    To   = '$1, options = {}$2'
  },
  @{
    Name = 'B1b spread the options into execFile'
    Done = [regex]'(?s)execFile\(command,\s*\[\.\.\.args\],\s*\{[^}]*?\.\.\.options'
    From = '(?s)(execFile\(command,\s*\[\.\.\.args\],\s*\{[^}]*?windowsHide:\s*true)(\s*\})'
    To   = '$1, ...options$2'
  },
  @{
    Name = 'B2a use a Win32 path, not a file:// URL'
    Done = [regex]'const target = windowsPath\.replaceAll'
    From = '(?s)const target = pathToFileURL\(windowsPath,\s*\{\s*windows:\s*true\s*\}\)\.href\.replaceAll'
    To   = 'const target = windowsPath.replaceAll'
  },
  @{
    Name = 'B2b explorer call asks for a visible window'
    Done = [regex]'(?s)run\("explorer\.exe",\s*\["/select,",\s*target\],\s*signal,\s*\{\s*windowsHide:\s*false\s*\}\)'
    From = '(?s)(run\("explorer\.exe",\s*\["/select,",\s*target\],\s*signal)\)'
    To   = '$1, { windowsHide: false })'
  }
)

$nativeText = Get-Text $nativePath
$bApply = @()
foreach ($e in $edits) {
  $done = $e.Done.IsMatch($nativeText)
  if ($Check) {
    Note ("{0} -> {1}" -f $e.Name, $(if ($done) { 'APPLIED' } else { 'MISSING' }))
  }
  elseif ($Revert) {
    if (-not $done) { Note ("{0} -> not applied" -f $e.Name) }
    else { $bApply += $e; Note ("{0} -> will revert" -f $e.Name) }
  }
  else {
    if ($done) { Note ("{0} -> already applied" -f $e.Name) }
    else { $bApply += $e; Note ("{0} -> will apply" -f $e.Name) }
  }
}

if (-not $Check -and $bApply.Count -gt 0) {
  $work = $nativeText
  $failed = @()
  foreach ($e in $bApply) {
    if ($Revert) {
      # Reverse direction: swap From/To is not always expressible, so revert is
      # handled by the explicit inverse table below.
      switch -Regex ($e.Name) {
        'B1a' { $work = $work -replace '(?s)(runNativeCommand\s*=\s*\(command,\s*args,\s*signal),\s*options\s*=\s*\{\s*(\}\)\s*=>)', '$1$2' }
        'B1b' { $work = $work -replace '(?s)(windowsHide:\s*true),\s*\.\.\.options', '$1' }
        'B2a' { $work = $work -replace 'const target = windowsPath\.replaceAll', 'const target = pathToFileURL(windowsPath, { windows: true }).href.replaceAll' }
        'B2b' { $work = $work -replace '(?s)(run\("explorer\.exe",\s*\["/select,",\s*target\],\s*signal),\s*\{\s*windowsHide:\s*false\s*\}\)', '$1)' }
      }
    }
    else {
      $new = [regex]::Replace($work, $e.From, $e.To, [System.Text.RegularExpressions.RegexOptions]::None)
      if ($new -eq $work) { $failed += $e.Name } else { $work = $new }
    }
  }
  if ($failed.Count -gt 0) {
    $problems.Add('patch B pattern(s) not found: ' + ($failed -join '; '))
    Note ('!! could not match: ' + ($failed -join '; '))
  }
  else {
    Set-Text $nativePath $work
    $actions.Add($(if ($Revert) { 'B: reverted' } else { 'B: applied' }))
    Note ($(if ($Revert) { 'reverted' } else { 'applied' }))
  }
}

# ===========================================================================
# verify
# ===========================================================================
Write-Host "=== verify ==="
if (-not $Check) {
  foreach ($p in @($preloadPath, $nativePath)) {
    $ok = Test-NodeCheck $p
    $name = Split-Path $p -Leaf
    if ($ok -eq $false) { $problems.Add("node --check FAILED on $name"); Note ("$name -> node --check FAILED") }
    elseif ($ok -eq $true) { Note ("$name -> node --check OK") }
    else { Note ("$name -> node --check skipped (no node)") }
  }
}

if ($actions.Count -gt 0) { Write-Host ("actions: " + ($actions -join ', ')) }

# Final state read-back
$finalPreload = Get-Text $preloadPath
$finalNative  = Get-Text $nativePath
$aOn = $finalPreload.Contains($MARK_A_END)
$bOn = $true
foreach ($e in $edits) { if (-not $e.Done.IsMatch($finalNative)) { $bOn = $false } }

Write-Host ("state: patch A = {0}, patch B = {1}" -f $(if ($aOn) { 'APPLIED' } else { 'OFF' }), $(if ($bOn) { 'APPLIED' } else { 'OFF' }))

if ($Revert) {
  if ($aOn -or $bOn) { $problems.Add('revert did not fully take effect') }
} else {
  if (-not $aOn) { $problems.Add('patch A is not applied') }
  if (-not $bOn) { $problems.Add('patch B is not fully applied') }
}

Write-Host ''
if ($problems.Count -gt 0) {
  Write-Host 'RESULT: NOT OK'
  $problems | ForEach-Object { Write-Host ("  - " + $_) }
  exit 1
}

if ($Check) { Write-Host 'RESULT: OK (check only, nothing was changed)' }
else {
  Write-Host 'RESULT: OK'
  Write-Host 'Next: FULLY QUIT and restart DSH Desktop (a page refresh is not enough).'
}
exit 0
