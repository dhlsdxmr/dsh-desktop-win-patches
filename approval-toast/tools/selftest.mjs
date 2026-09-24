/**
 * selftest.mjs -- prove the host module is correct WITHOUT booting DSH.
 *
 * Two layers:
 *   1. pure/offline tests with an injected fake `spawn`, asserting the exact
 *      argv, template rendering, throttling, allowlist and that the handler
 *      still delegates with next() (i.e. never decides anything itself);
 *   2. ONE real delivery through the real PowerShell, so the spawn chain is
 *      proven end to end and a toast actually appears on screen.
 *
 * Run: <bundled node> tools/selftest.mjs
 *
 * NOTE on the real delivery: it runs PowerShell with stdio 'inherit'. Under the
 * agent file sandbox a child process with a piped stdio fails with EPERM, so
 * capturing the child's stdout here would break the test for sandbox reasons
 * rather than real ones.
 */
import assert from 'node:assert/strict'
import { spawnSync } from 'node:child_process'
import {
  DEFAULTS,
  SCRIPT,
  apply,
  createNotifier,
  makeLogger,
  powershellPath,
  renderTemplate,
  resolveConfig,
} from '../lib/index.js'

let passed = 0
function check(label, fn) {
  fn()
  passed += 1
  console.log(`  ok   ${label}`)
}

/** Record spawn calls instead of launching anything, and let a test drive the
 * child's own events (the notifier reads its delivery outcome from 'exit'/'error'). */
function fakeSpawn() {
  const calls = []
  const spawn = (command, args, options) => {
    const handlers = new Map()
    const child = {
      on(event, handler) { handlers.set(event, handler); return child },
      unref() {},
      emit(event, ...rest) { const handler = handlers.get(event); if (handler) handler(...rest) },
    }
    calls.push({ command, args, options, child })
    return child
  }
  return { spawn, calls }
}

/** Collect the lines a notifier would write. */
function fakeLogger() {
  const lines = []
  const log = (level, message) => lines.push(`${level}: ${message}`)
  return { log, lines }
}

console.log('--- 1. template rendering ---')
check('fills {tool} and {reason}', () => {
  assert.equal(renderTemplate('{tool} 请求 {reason}', { tool: 'pwsh', reason: '越权' }), 'pwsh 请求 越权')
})
check('unknown placeholder collapses instead of leaking a literal', () => {
  assert.equal(renderTemplate('a{nope}b', {}), 'ab')
})

console.log('--- 2. config resolution ---')
check('defaults apply, onlyTools is coerced to an array', () => {
  const config = resolveConfig({ onlyTools: 'pwsh' })
  assert.deepEqual(config.onlyTools, [])
  assert.equal(config.aumid, DEFAULTS.aumid)
})
check('a non-numeric cooldown falls back to the default', () => {
  assert.equal(resolveConfig({ cooldownMs: 'soon' }).cooldownMs, DEFAULTS.cooldownMs)
})

console.log('--- 3. exact spawn argv ---')
check('argv carries AppId/Title/Body and hides the window', () => {
  const { spawn, calls } = fakeSpawn()
  const notify = createNotifier(resolveConfig({}), { spawn, script: 'S.ps1', powershell: 'PS.exe' })
  assert.equal(notify('pwsh', '需要提权'), true)
  assert.equal(calls.length, 1)
  const call = calls[0]
  assert.equal(call.command, 'PS.exe')
  assert.deepEqual(call.options, { windowsHide: true, stdio: 'ignore' })
  assert.deepEqual(call.args, [
    '-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass',
    '-File', 'S.ps1',
    '-AppId', DEFAULTS.aumid,
    '-Title', '审批请求：pwsh 需要越权执行',
    '-Body', '需要提权',
  ])
  assert.ok(call.args.includes('需要提权'), 'Chinese text must survive as an argv element')
})
check('a missing reason uses the fallback sentence', () => {
  const { spawn, calls } = fakeSpawn()
  createNotifier(resolveConfig({}), { spawn, script: 'S.ps1', powershell: 'PS.exe' })('pwsh', undefined)
  assert.equal(calls[0].args.at(-1), DEFAULTS.fallbackReason)
})

console.log('--- 4. throttling / filtering / off switch ---')
check('repeat toast for the same tool inside the cooldown is suppressed', () => {
  const { spawn, calls } = fakeSpawn()
  const notify = createNotifier(resolveConfig({ cooldownMs: 60_000 }), { spawn, script: 'S.ps1', powershell: 'PS.exe' })
  assert.equal(notify('pwsh', 'a'), true)
  assert.equal(notify('pwsh', 'b'), false)
  assert.equal(notify('fs', 'c'), true, 'a different tool is not throttled')
  assert.equal(calls.length, 2)
})
check('onlyTools acts as an allowlist', () => {
  const { spawn, calls } = fakeSpawn()
  const notify = createNotifier(resolveConfig({ onlyTools: ['pwsh'] }), { spawn, script: 'S.ps1', powershell: 'PS.exe' })
  assert.equal(notify('fs', 'a'), false)
  assert.equal(notify('pwsh', 'a'), true)
  assert.equal(calls.length, 1)
})
check('enabled:false never spawns', () => {
  const { spawn, calls } = fakeSpawn()
  const notify = createNotifier(resolveConfig({ enabled: false }), { spawn, script: 'S.ps1', powershell: 'PS.exe' })
  assert.equal(notify('pwsh', 'a'), false)
  assert.equal(calls.length, 0)
})
check('a throwing spawn cannot escape into the approval flow', () => {
  const notify = createNotifier(resolveConfig({}), {
    spawn: () => { throw new Error('boom') },
    script: 'S.ps1',
    powershell: 'PS.exe',
  })
  assert.equal(notify('pwsh', 'a'), true)
})

console.log('--- 5. wiring: root listener that still delegates ---')
const listeners = []
const ctx = { on: (event, handler) => listeners.push({ event, handler }) }
const wiring = fakeSpawn()
apply(ctx, {}, { spawn: wiring.spawn, script: 'S.ps1', powershell: 'PS.exe' })
check('registers exactly one approval/request listener', () => {
  assert.equal(listeners.length, 1)
  assert.equal(listeners[0].event, 'approval/request')
})
const outcome = await listeners[0].handler({ toolName: 'pwsh', reason: '越权' }, () => Promise.resolve('unavailable'))
check('handler delegates: next() outcome is passed through unchanged', () => {
  assert.equal(outcome, 'unavailable', 'a non-delegating handler would auto-decide the escalation')
  assert.equal(wiring.calls.length, 1, 'the toast fired exactly once')
})
const beforeMalformed = wiring.calls.length
// `next()` returns a Promise, so it must be awaited before comparing.
const malformedOutcome = await listeners[0].handler(undefined, () => Promise.resolve('rejected'))
check('handler tolerates a malformed request', () => {
  assert.equal(malformedOutcome, 'rejected')
  assert.equal(wiring.calls.length, beforeMalformed + 1)
})

console.log('--- 6. observability: logger probing + delivery outcomes ---')
check('makeLogger uses ctx.logger when the service exists', () => {
  const seen = []
  const log = makeLogger({ logger: (channel) => ({ info: (m) => seen.push(`${channel}|${m}`) }) })
  log('info', 'hello')
  assert.deepEqual(seen, ['dsh-approval-toast|hello'])
})
check('makeLogger degrades to a no-op when ctx has no logger', () => {
  const log = makeLogger({})
  assert.equal(log('info', 'dropped'), undefined)
})
check('makeLogger survives a ctx whose logger throws', () => {
  const log = makeLogger({ logger: () => { throw new Error('no logger service') } })
  assert.equal(log('info', 'dropped'), undefined)
})
check('an injected log seam wins over the probed logger', () => {
  const seen = []
  const log = makeLogger({ logger: () => ({ info: () => { throw new Error('must not be used') } }) }, { log: (l, m) => seen.push(m) })
  log('info', 'seam')
  assert.deepEqual(seen, ['seam'])
})
check('apply logs a load breadcrumb naming the effective config', () => {
  const seen = fakeLogger()
  apply({ on: () => {} }, { cooldownMs: 1234 }, { spawn: fakeSpawn().spawn, script: 'S.ps1', powershell: 'PS.exe', log: seen.log })
  assert.ok(seen.lines.some((l) => l.startsWith('info: loaded:')), seen.lines.join(' | '))
  assert.ok(seen.lines.some((l) => l.includes('aumid=DeepSeek.Harness.DSH') && l.includes('cooldownMs=1234')))
})
check('a zero exit is logged as delivered', () => {
  const { spawn, calls } = fakeSpawn()
  const seen = fakeLogger()
  createNotifier(resolveConfig({}), { spawn, script: 'S.ps1', powershell: 'PS.exe', log: seen.log })('pwsh', 'x')
  calls[0].child.emit('exit', 0, null)
  assert.ok(seen.lines.includes('info: toast delivered: exit=0 tool=pwsh'), seen.lines.join(' | '))
})
check('a non-zero exit is logged as a DELIVERY FAILURE', () => {
  const { spawn, calls } = fakeSpawn()
  const seen = fakeLogger()
  createNotifier(resolveConfig({}), { spawn, script: 'S.ps1', powershell: 'PS.exe', log: seen.log })('pwsh', 'x')
  calls[0].child.emit('exit', 1, null)
  assert.ok(seen.lines.some((l) => l.startsWith('warn: toast delivery FAILED: exit=1')), seen.lines.join(' | '))
})
check('a spawn error is logged, not swallowed', () => {
  const { spawn, calls } = fakeSpawn()
  const seen = fakeLogger()
  createNotifier(resolveConfig({}), { spawn, script: 'S.ps1', powershell: 'PS.exe', log: seen.log })('pwsh', 'x')
  calls[0].child.emit('error', new Error('spawn ENOENT'))
  assert.ok(seen.lines.some((l) => l.includes('FAILED to start') && l.includes('spawn ENOENT')), seen.lines.join(' | '))
})
check('the request is logged before the outcome', () => {
  const { spawn } = fakeSpawn()
  const seen = fakeLogger()
  createNotifier(resolveConfig({}), { spawn, script: 'S.ps1', powershell: 'PS.exe', log: seen.log })('pwsh', 'x')
  assert.ok(seen.lines[0].startsWith('info: toast requested: tool=pwsh aumid='), seen.lines.join(' | '))
})

console.log(`--- 7. REAL delivery (${passed} offline checks passed) ---`)
const real = spawnSync(
  powershellPath(),
  ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', SCRIPT,
    '-AppId', DEFAULTS.aumid,
    '-Title', '插件自检：dsh-approval-toast',
    '-Body', '如果你看到这条通知，宿主模块的真实 spawn 链路是通的'],
  { stdio: 'inherit' },
)
console.log(`  powershell: ${powershellPath()}`)
console.log(`  script    : ${SCRIPT}`)
console.log(`  exit      : ${real.status}`)
if (real.status !== 0) {
  console.error('  FAIL: the real PowerShell delivery did not exit 0')
  process.exit(1)
}
console.log('  VISUAL CONFIRMATION REQUIRED: exit 0 is not proof the toast rendered.')
