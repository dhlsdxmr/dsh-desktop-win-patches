# DSH 缺陷报告：交付卡片的「在文件资源管理器中显示」在 Windows 上失效（不弹窗 / 弹错位置）

- 报告日期：2026-09-23
- 环境：DSH Desktop 0.9.2（Windows 11，Electron 打包版，资源目录 `D:\DSH\DSH Desktop`）
- 涉及包：`@deepseek-ai/dsh-native-command` 0.1.5-rc.2，`@deepseek-ai/dsh-client-ui-deliverables`，`@deepseek-ai/dsh-api-session-controller`
- 状态：**两个独立缺陷，均已打补丁并由用户实测验证 ✅**
  - 缺陷一（不弹窗）：复现成功（4 次点击 → 4 个无窗口进程），根因「隐藏控制台 + CREATE_NO_WINDOW」，补丁后窗口正常弹出
  - 缺陷二（弹到「此电脑」而非目标路径）：根因是 `/select,` 后面传了 `file://` URL，Explorer 不认这种形式，补丁后窗口定位到文件所在目录并选中文件
- 本文件只作留存，尚未提交上游

## 0. 本机已应用的临时补丁（2026-09-23）

按方案 A 直接改了已安装应用里的一个文件（**只影响这台机器，程序更新后会被覆盖**）：

`D:\DSH\DSH Desktop\resources\app\node_modules\@deepseek-ai\dsh-native-command\lib\index.js`

1. 第 17-22 行：运行器支持附加进程选项（修缺陷一）
   ```js
   // 改前
   const runNativeCommand = (command, args, signal) => new Promise((resolve, reject) => {
     execFile(command, [...args], { encoding: "utf8", signal, windowsHide: true }, …);
   // 改后
   const runNativeCommand = (command, args, signal, options = {}) => new Promise((resolve, reject) => {
     execFile(command, [...args], { encoding: "utf8", signal, windowsHide: true, ...options }, …);
   ```
2. 第 235 行：explorer 调用显式要求可见窗口（修缺陷一）
   ```js
   // 改前
   await run("explorer.exe", ["/select,", target], signal);
   // 改后
   await run("explorer.exe", ["/select,", target], signal, { windowsHide: false });
   ```
3. 第 229 行：不再把路径转成 `file://` URL（修缺陷二）
   ```js
   // 改前
   const target = pathToFileURL(windowsPath, { windows: true }).href.replaceAll(",", "%2C");
   // 改后
   const target = windowsPath.replaceAll(",", "%2C");
   ```

**注意**：Harness 是常驻进程，改完必须**完全退出并重新启动 DSH Desktop** 才生效。

**回滚方式**：把上面三处改回"改前"的写法即可，本文件第 0 节就是完整记录。

## 1. 现象

在交付卡片（present 的文件卡片）右侧下拉菜单里点击「**在文件资源管理器中显示**」：

- 界面状态文字变成「已请求在文件资源管理器中显示」，没有任何报错；
- 但屏幕上不会出现任何资源管理器窗口，任务栏、`Alt + Tab` 里也找不到；
- 同一菜单里的「打开所在文件夹」是另一种界面（macOS/Linux 才走 `directory` 分支），Windows 上不出现。

用户可感知的结果就是：**点了没用，而且界面说成功了**。

## 2. 代码路径

1. 客户端：`@deepseek-ai/dsh-client-ui-deliverables`（`lib/client.js`）
   - 菜单项 `reveal` → `POST /api/present.open?sessionId=…&seq=…&index=…&action=reveal`
2. 主机端路由：`@deepseek-ai/dsh-client-ui-deliverables`（`lib/index.js` `handlePresentOpen`）
   - 从会话日志读取 `deliverables/presented` 事件 → `workspaceFiles.stat` 校验 → `sessionController.openWorkspacePath({ path, action: "reveal" })`
3. 会话控制器：`@deepseek-ai/dsh-api-session-controller`（`lib/index.js:3232`）
   - `action === "reveal"` → `this.revealPath(path, signal)`
4. 原生命令：`@deepseek-ai/dsh-native-command`（`lib/index.js:208-236`）
   ```js
   const target = pathToFileURL(windowsPath, { windows: true }).href.replaceAll(",", "%2C");
   try {
     await run("explorer.exe", ["/select,", target], signal);
   } catch (error) {
     // Explorer exit 1 is accepted as a delegated handoff, not proof of selection.
     if (!(error instanceof Error) || !("code" in error) || error.code !== 1) throw error;
   }
   ```
5. 运行器（同文件 `lib/index.js:17-36`）：
   ```js
   execFile(command, [...args], { encoding: "utf8", signal, windowsHide: true }, …)
   ```

## 3. 实测证据（本机）

### 3.1 命令本身没问题

用 PowerShell 直接执行同一形态的命令，四种写法**都成功弹出窗口**：

| 写法 | 结果 |
|---|---|
| `explorer.exe /select,file:///D:/...%20...`（与源码一致的 file URL） | 新增 1 个可见窗口 |
| `explorer.exe /select,D:\...\路径预览测试.md`（纯路径） | 新增 1 个可见窗口 |
| `explorer.exe D:\...\插件安装`（只给文件夹） | 新增 1 个可见窗口 |
| `explorer.exe '/select,' D:\...`（参数分开） | 新增 1 个可见窗口 |

窗口数量统计方式：`(Get-Process explorer | ? { $_.MainWindowHandle -ne 0 }).Count`。

### 3.2 从 DSH 按钮触发时：进程有，窗口没有

用户在 23:46:51、23:47:52、23:48:48、23:49:57 各点击一次，进程表里对应多出 4 个 `explorer.exe`：

```
  Id   MainWindowHandle   StartTime
2164                 0    2026/9/23 23:46:51     ← 用户点击产生
24028                0    2026/9/23 23:47:52     ← 用户点击产生
21492                0    2026/9/23 23:48:48     ← 用户点击产生
22932                0    2026/9/23 23:49:57     ← 用户点击产生
```

`MainWindowHandle = 0` = 这些进程**没有创建任何窗口**。也就是说命令发出去了，被系统忽略了。

### 3.3 关键差异：Harness 进程带着一个隐藏控制台

`resources/harness-node-entry.mjs` 在 win32 上会：

1. `createHiddenConsole()`（`resources/windows-hidden-console.mjs`）：`AllocConsole()` 给 Harness 挂一个控制台，再用 `ShowWindow(SW_HIDE)` 藏起来（为修 issue #233 的"黑窗闪烁"）；
2. `enforceWindowsChildProcessHide()`（`resources/windows-child-process-hide.mjs`）：给所有 `spawn/exec/execFile` 补上 `windowsHide: true`（即 `CREATE_NO_WINDOW`）。

也就是说，DSH 启动 explorer 时的组合是：**父进程持有一个被隐藏的控制台 + `CREATE_NO_WINDOW`**。在本机对照测试中，从这个环境启动 explorer 不会产生窗口；而同样的命令在普通 PowerShell 控制台里启动则正常（3.1）。这与"命令正确、执行环境把窗口吃掉"的现象完全吻合。

> 注：本机复现脚本受运行沙箱限制（Node 子进程 `spawn` 报 `EPERM`、`ConstrainedLanguage` 等），未能用独立脚本把 3.3 的对照跑到"同一脚本内 A/B 对比"的程度；3.1 与 3.2 的对照已是实测结果。修复后的验证以实际点击为准（见 §5）。

## 4. 修复建议（二选一）

### 方案 A（推荐，改动最小）：双击 explorer 的启动方式，不再压制窗口

在 `@deepseek-ai/dsh-native-command/lib/index.js` 里，让 `revealNativePath` 的 explorer 调用**显式声明需要窗口**，覆盖桌面层默认注入的 `windowsHide: true`：

```js
// runner 增加一个可选的第 4 个参数：附加的进程选项
const runNativeCommand = (command, args, signal, options = {}) =>
  new Promise((resolve, reject) => {
    execFile(command, [...args], { encoding: "utf8", signal, windowsHide: true, ...options }, cb);
  });

// revealNativePath 内
await run("explorer.exe", ["/select,", target], signal, { windowsHide: false });
```

理由：`windows-hidden-console.mjs` 的注释明确写了"调用方显式设置 windowsHide 时保留其选择"，而这里调用方**确实需要一个可见窗口**，属于文档中认可的例外。

### 方案 B（更彻底，但链路更长）：改走 Electron 的 `shell.showItemInFolder`

Electron 的 `shell.showItemInFolder(path)` 是官方推荐的"在资源管理器中显示文件"接口，由主进程直接调用系统 Shell，绕开子进程控制台问题；`resources/app/out/main/index.js` 里已经在用（如 `harness:show-log`、`harness:open-in-finder`）。

问题在于**没有从 Harness 子进程回到 Electron 主进程的调用通道** —— Harness 是脱离主进程运行的独立 Node 进程（`detached: true`）。要做这条链路，需要新增一条 IPC（例如 Harness 端 `process.send` 或本地回环路由 → 主进程 → `shell.showItemInFolder`），改动面较大。建议先落方案 A，方案 B 作为后续架构改进。

### 附带问题（同一处，建议一并修）

`explorer.exe` 的退出码 **1 被无条件当作成功**（源码注释称其为"delegated handoff"），加上 UI 侧只要 HTTP 2xx 就显示「已请求在文件管理器中显示」，导致**失败也报成功**。至少应把非 0 退出码与 stderr 记入日志，便于下次定位。

## 3.5 缺陷二：窗口弹出来了，但停在「此电脑」而不是目标路径

修好缺陷一之后，窗口能弹了，但**每次都在「此电脑」**，与目标文件无关。原因在同一个函数里：

```js
const target = pathToFileURL(windowsPath, { windows: true }).href.replaceAll(",", "%2C");
await run("explorer.exe", ["/select,", target], signal);
```

`explorer.exe /select,` 的第二个参数是 **Win32 路径**。实测（Windows 11，DSH Desktop 所在机器）：

| 命令 | 结果 |
|---|---|
| `explorer.exe /select,<local-workdir>\zzz-ascii-test.md` | 打开 `插件安装`，文件选中 ✅ |
| `explorer.exe /select,file:///<local-workdir>/.../zzz-ascii-test.md` | 打开 **此电脑** ❌ |
| `explorer.exe /select,<local-workdir>\路径预览测试.md`（含中文） | 打开 `插件安装` ✅ |
| `explorer.exe /select,file:///<local-workdir>/%E6%8F%92...`（含中文，URL） | 打开 **此电脑** ❌ |

规律很干净：**给 URL 就退化成「此电脑」，给路径就正确**。修复即把该行改为传纯路径（逗号仍按原逻辑转义）。

## 5. 修复后的验证方式

1. 在交付卡片下拉里点「在文件资源管理器中显示」；
2. 期望：出现一个资源管理器窗口，停在文件所在目录，且目标文件为选中状态；
3. 若仍无窗口，检查进程表里新出现的 `explorer.exe` 是否 `MainWindowHandle = 0`（= 仍未修复）。

## 6. 相关文件清单

- `resources/app/node_modules/@deepseek-ai/dsh-native-command/lib/index.js`（方案 A 改动点：`runNativeCommand`、`revealNativePath`）
- `resources/windows-child-process-hide.mjs`（`windowsHide` 默认注入）
- `resources/windows-hidden-console.mjs`（隐藏控制台）
- `resources/harness-node-entry.mjs`（串起以上两者）
- `resources/app/node_modules/@deepseek-ai/dsh-client-ui-deliverables/lib/index.js`（路由与 422/500 判定）
- `resources/app/node_modules/@deepseek-ai/dsh-client-ui-deliverables/lib/client.js`（菜单与状态文案）
