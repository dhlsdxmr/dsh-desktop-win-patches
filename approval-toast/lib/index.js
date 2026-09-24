/**
 * dsh-approval-toast -- a Windows OS notification when a DSH approval request
 * becomes pending, so the user notices while the DSH window is in the background.
 *
 * WHY THIS EXISTS: DSH's approval panel is an in-page composer takeover. If the
 * DSH window is not in front of you, nothing tells you that a turn is blocked
 * waiting for a decision. DSH Desktop ships no OS-level notification channel
 * (the main process never enables Electron `Notification`, and preload exposes
 * no notification IPC), so this is the plugin-shaped way to get one.
 *
 * HOW IT HOOKS IN: `@deepseek-ai/dsh-user-approval` dispatches every pending
 * decision over the `approval/request` waterfall, scoped to the requesting
 * agent. Scoped events bubble UP the scope chain, and the root context carries
 * no scope tag, so a listener registered here receives every agent's request
 * (`@deepseek-ai/dsh-scope/lib/index.js`, scopeTarget's filter).
 *
 * PASSIVE OBSERVER, DELIBERATELY: the handler raises the toast and then ALWAYS
 * calls `next()`, so the real answerer (the browser approval panel) still owns
 * the decision. Returning an outcome instead would silently auto-approve the
 * escalation -- the one thing this plugin must never do.
 *
 * DELIVERY: Windows PowerShell 5.1 + the WinRT toast API, via assets/toast.ps1.
 * Needs nothing installed (no BurntToast, no PSGallery, nothing written to C:)
 * and no admin rights. PS 7 cannot load the WinRT projections, so the console
 * host is addressed by absolute path rather than through PATH.
 *
 * THE ONE REAL TRAP: the AppId must be a REGISTERED AppUserModelID.
 * ToastNotificationManager happily accepts any string, reports no error, and
 * even records the toast in its History -- while rendering absolutely nothing.
 * Run tools/register-aumid.ps1 once (HKCU scope, reversible) to register ours.
 *
 * ZERO DEPENDENCIES ON PURPOSE: an out-of-tree plugin is loaded from the profile
 * and cannot resolve `@deepseek-ai/*`, so only `node:*` builtins may be imported.
 * @module dsh-approval-toast
 */
import { spawn } from 'node:child_process'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

const HERE = dirname(fileURLToPath(import.meta.url))

/** The notifier script shipped beside this module. */
export const SCRIPT = join(HERE, '..', 'assets', 'toast.ps1')

/**
 * Absolute path to Windows PowerShell 5.1, the only host whose WinRT
 * projections resolve.
 * @returns the console host path under the system root.
 */
export function powershellPath() {
  const root = process.env.SystemRoot ?? 'C:\\Windows'
  return join(root, 'System32', 'WindowsPowerShell', 'v1.0', 'powershell.exe')
}

export const name = 'dsh-approval-toast'

/** The `approval/request` Event needs no service, so nothing is injected. */
export const inject = []

export const DEFAULTS = {
  enabled: true,
  /** MUST be a registered AppUserModelID, or Windows renders nothing at all. */
  aumid: 'DeepSeek.Harness.DSH',
  title: '审批请求：{tool} 需要越权执行',
  body: '{reason}',
  /** Used when the model supplied no `reason` for the escalation. */
  fallbackReason: '模型未提供理由，请回到 DSH 窗口查看详情',
  /** Suppress a repeat toast for the SAME tool within this window (ms). */
  cooldownMs: 2500,
  /** Tool allowlist; empty means every tool. */
  onlyTools: [],
}

/**
 * Fill in the defaults for a raw loader config.
 * @param raw - config as written in the profile patch (untrusted).
 * @returns the effective config.
 */
export function resolveConfig(raw = {}) {
  const config = { ...DEFAULTS, ...raw }
  config.onlyTools = Array.isArray(config.onlyTools) ? config.onlyTools : []
  config.cooldownMs = Number.isFinite(config.cooldownMs) ? config.cooldownMs : DEFAULTS.cooldownMs
  return config
}

/**
 * Substitute `{key}` placeholders. Unknown keys collapse to an empty string so a
 * hand-edited template can never leak a literal `{reason}` into a notification.
 * @param template - template string.
 * @param values - placeholder values.
 * @returns the rendered string.
 */
export function renderTemplate(template, values) {
  return String(template).replace(/\{(\w+)\}/g, (_match, key) => (
    values[key] === undefined || values[key] === null ? '' : String(values[key])
  ))
}

/**
 * Best-effort named logger.
 *
 * `ctx.logger` is a cordis built-in service, and the desktop bridges harness log
 * records into `harness.log`. This plugin injects NOTHING on purpose (an unavailable
 * injected service would stop `apply` from running at all), so the logger is probed
 * defensively: missing or throwing must degrade to a no-op, never to a failed load.
 *
 * WHY THIS EXISTS: without it, "no toast appeared" is indistinguishable from "the
 * plugin was never mounted" -- neither left a trace anywhere. The load breadcrumb
 * and the per-delivery outcome below make that distinction readable in one place.
 * @param ctx - cordis context (may lack the logger service entirely).
 * @param deps - test seam: a `log` function replaces the probed logger entirely.
 * @returns `log(level, message)`; drops everything silently when unusable.
 */
export function makeLogger(ctx, deps = {}) {
  if (typeof deps.log === 'function') return deps.log
  try {
    const named = ctx?.logger?.('dsh-approval-toast')
    if (named !== undefined && named !== null) {
      return (level, message) => {
        try { named[level]?.(message) } catch { /* logging must never throw */ }
      }
    }
  } catch { /* fall through to the no-op below */ }
  return () => {}
}

/**
 * Build the notifier function. Dependencies are injectable so the self-test can
 * assert the exact spawn arguments and the throttling without showing anything.
 * @param config - effective config from {@link resolveConfig}.
 * @param deps - test seams (`spawn`, `script`, `powershell`, `log`).
 * @returns `notify(toolName, reason)` -> whether a toast was launched.
 */
export function createNotifier(config, deps = {}) {
  const run = deps.spawn ?? spawn
  const script = deps.script ?? SCRIPT
  const powershell = deps.powershell ?? powershellPath()
  const log = typeof deps.log === 'function' ? deps.log : () => {}
  let lastTool
  let lastAt = 0

  return function notify(toolName, reason) {
    if (!config.enabled) return false
    if (config.onlyTools.length > 0 && !config.onlyTools.includes(toolName)) return false
    const now = Date.now()
    if (toolName === lastTool && now - lastAt < config.cooldownMs) return false
    lastTool = toolName
    lastAt = now

    const title = renderTemplate(config.title, { tool: toolName })
    const body = renderTemplate(config.body, {
      tool: toolName,
      reason: reason === undefined || reason === null || reason === '' ? config.fallbackReason : reason,
    })

    const args = [
      '-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass',
      '-File', script,
      '-AppId', config.aumid,
      '-Title', title,
      '-Body', body,
    ]
    try {
      // stdio 'ignore': nothing here needs the child's output, and a piped stdio
      // would be one more thing to go wrong on a constrained host. The OUTCOME is
      // read from the exit event instead, which needs no pipe at all.
      const child = run(powershell, args, { windowsHide: true, stdio: 'ignore' })
      if (typeof child?.on === 'function') {
        // A listener also keeps an ENOENT from surfacing as an unhandled event.
        child.on('error', (error) => {
          log('warn', `toast delivery FAILED to start: ${error?.message ?? error} (tool=${toolName})`)
        })
        child.on('exit', (code, signal) => {
          if (code === 0) log('info', `toast delivered: exit=0 tool=${toolName}`)
          else log('warn', `toast delivery FAILED: exit=${code} signal=${signal ?? 'none'} tool=${toolName} -- non-zero means PowerShell could not raise it; check the AppUserModelID is registered, or run assets/toast.ps1 by hand`)
        })
      }
      if (typeof child?.unref === 'function') child.unref()
      log('info', `toast requested: tool=${toolName} aumid=${config.aumid}`)
    } catch (error) {
      // A notification failure must never disturb the approval flow.
      log('warn', `toast spawn threw: ${error?.message ?? error} (tool=${toolName})`)
    }
    return true
  }
}

/**
 * Install the observer on the root context.
 * @param ctx - cordis root context.
 * @param rawConfig - loader config.
 * @param deps - test seams, forwarded to {@link createNotifier}.
 */
export function apply(ctx, rawConfig = {}, deps = {}) {
  const config = resolveConfig(rawConfig)
  const log = makeLogger(ctx, deps)
  // Load breadcrumb: proves the plugin MOUNTED, and prints the effective config.
  // Without it a silent plugin and an unloaded plugin look exactly alike.
  log('info', `loaded: enabled=${config.enabled} aumid=${config.aumid} onlyTools=[${config.onlyTools.join(',')}] cooldownMs=${config.cooldownMs} script=${SCRIPT}`)
  const notify = createNotifier(config, { ...deps, log })
  ctx.on('approval/request', (request, next) => {
    notify(request?.toolName, request?.reason)
    return next()
  })
}
