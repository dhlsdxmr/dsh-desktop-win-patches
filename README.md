# dsh-desktop-win-patches

Local fixes for **DSH Desktop on Windows** that the packaged build still needs. The
two file patches are applied to the *installed* app, so a DSH update wipes them —
`apply-dsh-patches.ps1` puts them back in one command.

**中文说明见下方「中文说明」一节。** This file is bilingual: the English part is a
short orientation, the Chinese part is the full explanation.

---

## What this repository holds

Three local items, one folder each. **Two are file patches; the third is a profile
plugin** — they are restored by different means, so read the "restored by" column
before acting.

| # | Folder | Kind | Symptom (as the user sees it) | Restored by |
|---|---|---|---|---|
| **A** | `header-title-row-clickable/` | file patch — `resources/app/out/preload/index.cjs` | The 「N 个后台任务 / N background jobs」 dropdown in the conversation header does nothing when clicked. Same for the mode selector next to it. | `apply-dsh-patches.ps1` |
| **B** | `explorer-reveal/` | file patch — `…/@deepseek-ai/dsh-native-command/lib/index.js` | 「在文件资源管理器中显示 / Reveal in File Explorer」 on a deliverable card either (B1) opens no window at all, or (B2) opens **This PC** instead of the target folder. | `apply-dsh-patches.ps1` |
| **C** | `approval-toast/` | **DSH profile plugin** (not a file patch) | An approval (escalation) request waiting on you is completely silent while the DSH window is in the background — the panel is only an in-page composer takeover. Adds a Windows OS notification. | `dsh plugin --profile web add` — **a DSH update does not remove it** |

Both file patches were reproduced, diagnosed to root cause with machine-readable
evidence, patched, and confirmed by the user clicking the controls. The plugin was
verified by a 13-assertion self-test, a loader tree dump, and a real on-screen toast.

## Usage

```powershell
# the two FILE patches
.\apply-dsh-patches.ps1 -Check     # report only, change nothing - run this first after a DSH update
.\apply-dsh-patches.ps1            # apply whatever is missing, then verify (node --check on both files)
.\apply-dsh-patches.ps1 -Revert    # undo both, restore upstream behaviour
```

Then **fully quit and restart DSH Desktop** — both patch targets are loaded at process
start (the preload at window creation, the native-command module at Harness boot), so a
page refresh is not enough.

Non-default install location: `.\apply-dsh-patches.ps1 -DshRoot 'E:\Apps\DSH\DSH Desktop'`

Exit codes: `0` = the requested end state holds; `1` = at least one step failed (the
script prints which).

**Patch C is not touched by that script** — see `approval-toast/README.md`:

```powershell
cd approval-toast
powershell -NoProfile -ExecutionPolicy Bypass -File tools\register-aumid.ps1 `
  -IconUri 'D:\DSH\DSH Desktop\DSH Desktop.exe'
$node = 'D:\DSH\DSH Desktop\resources\app\node_modules\node\bin\node.exe'
$bin  = 'D:\DSH\DSH Desktop\resources\app\node_modules\@deepseek-ai\dsh\lib\bin.js'
& $node $bin plugin --profile web add 'link:D:\DSH-program\patch\approval-toast'
```

## Layout

```
apply-dsh-patches.ps1        the tool for the two file patches (apply / -Check / -Revert)

header-title-row-clickable/  patch A
  DSH缺陷报告-后台任务下拉框点不动.md   full report (root cause, phase experiment, evidence)
  preload-index-fix.js                the exact block appended to preload/index.cjs
  evidence/                           probe scripts and screenshots produced during diagnosis

explorer-reveal/             patch B
  DSH缺陷报告-文件资源管理器显示不弹窗.md  full report (both defects, before/after, evidence)
  native-command-fix.md                the four edits, before/after

approval-toast/              patch C — a DSH profile plugin, NOT a file patch
  README.md                            install / config / the ghost-AppUserModelID trap
  package.json, cordis.patch.yml       plugin manifest and its bundle patch
  lib/index.js                         host module: approval/request -> toast, then next()
  assets/toast.ps1                     PowerShell 5.1 + WinRT delivery (no installs needed)
  tools/register-aumid.ps1             one-time AppUserModelID registration (HKCU, reversible)
  tools/selftest.mjs                   13 offline assertions + 1 real delivery
```

`evidence/` sits inside patch A because every probe there was produced for that
defect; the report references it as `evidence/...`, which still resolves.

## Caveats

- Written against **DSH Desktop 0.9.2** (`@deepseek-ai/dsh-*` 0.1.5-rc.2) on Windows
  10/11. A later build may restructure these files; the script reports clearly when a
  pattern it needs is missing instead of guessing.
- Patch B leaves `pathToFileURL` imported but unused — harmless. (It is still used by
  other functions in the same file.)
- Patch A deliberately gives up one thing: the window can no longer be dragged by the
  header title row — dragging stays available on the tab row and on the blank parts of
  the top band. That is the necessary trade for the controls to be clickable.
- `explorer.exe` exiting with code 1 is still treated as success upstream; this patch
  does not change that. It is why the UI can say "requested" while nothing happened
  (see report B §4).
- `evidence/` probe scripts work by window coordinates captured at the time; those move
  with the window, so re-read each control's `BoundingRectangle` before re-running them.

## License

Not chosen yet.

---

# 中文说明

## 这是什么

本仓库收着**本机对 DSH Desktop（Windows 打包版）的三处本地修补**，一处一个子文件夹。
**其中两处是文件补丁，第三处是 profile 插件** —— 恢复方式完全不同，动手前先看那一列。

| # | 子文件夹 | 类型 | 症状 | 怎么恢复 |
|---|---|---|---|---|
| **A** | `header-title-row-clickable/` | 文件补丁 `out/preload/index.cjs` | 会话头部「N 个后台任务」下拉点了没反应，同行的「标准模式」等控件一样点不动 | `apply-dsh-patches.ps1` |
| **B** | `explorer-reveal/` | 文件补丁 `dsh-native-command/lib/index.js` | 交付卡片「在文件资源管理器中显示」不弹窗 / 弹到「此电脑」 | `apply-dsh-patches.ps1` |
| **C** | `approval-toast/` | **profile 插件**（不是文件补丁） | 审批（提权）请求在 DSH 窗口后台时**完全没有提示**——它只是页面内的 composer 接管，没有系统级通知 | `dsh plugin --profile web add`；**DSH 更新不会覆盖它** |

## 为什么需要这个仓库

A 与 B 打在**已安装的程序目录**里，**DSH 一更新就会被覆盖**，所以真正需要的不是
"记录修法"，而是"一条命令打回去"。C 装的是 DSH profile 依赖（在数据目录里），
不受 DSH 更新影响 —— 但它同样怕"忘了装过什么"，所以也归档在这里。

## 缺陷 A：会话头部标题行的控件点了没反应

- **现象**：「N 个后台任务」下拉按钮点了不出菜单，也没有任何报错；同一行的
  「标准模式」等控件一样点不动。
- **根因**：桌面端在窗口顶部铺了一条 36px 的**透明拖拽条**（`-webkit-app-region: drag`）。
  **只要这条带子自己声明 drag，整条带子就被判定为窗口标题栏**，带子里任何后代元素的
  `no-drag` 都不算数 —— 鼠标消息根本不会作为网页事件送达，`onClick` 永不触发。
- **决定性实验**：逐阶段改拖拽条并读系统命中测试（`WM_NCHITTEST`）——
  带子 `drag` → 按钮中心 `HTCAPTION`（点不到）；带子 `no-drag` → `HTCLIENT`（可点）；
  把带子 `display:none` → **仍然是 `HTCAPTION`**（原生 `titleBarOverlay` 仍认领这条带子）。
  **所以正确修法不是"在带子里加 no-drag"，而是"让带子别声称 drag"。**
- **修法**：向 `preload/index.cjs` **末尾追加**一段（见 `preload-index-fix.js`），
  让拖拽条自己 `no-drag`，再给标题行与顶部带内控件逐个打行内 `no-drag`，
  标签行保留 `drag` 以维持窗口拖动。
- **代价**：窗口不再能用标题行拖动（改用标签行或顶部空白区）。带子本是
  `pointer-events:none` 的透明层，**外观零变化**。
- **完整报告**：`header-title-row-clickable/DSH缺陷报告-后台任务下拉框点不动.md`

## 缺陷 B：交付卡片「在文件资源管理器中显示」失效

两个**互相独立**的缺陷，在同一个函数里：

- **B1 不弹窗**：桌面端给所有子进程注入 `windowsHide: true`（= `CREATE_NO_WINDOW`），
  而 Harness 自身还持有一个隐藏控制台 → `explorer.exe` **起来了但没有窗口**
  （进程表里 `MainWindowHandle = 0`，界面却显示"已请求"）。
  **修法**：让运行器接受一个可选的第 4 参数，explorer 调用显式传 `{ windowsHide: false }`。
- **B2 弹到「此电脑」**：把路径**先转成 `file://` 网址**再交给 `explorer.exe /select,`，
  而 `/select,` **只认 Win32 路径** —— 给网址它什么都不选，退化成打开「此电脑」。
  **修法**：直接传纯 Windows 路径（逗号仍按原逻辑转义 `%2C`）。

四处改动的前后对照见 `explorer-reveal/native-command-fix.md`，
完整报告见 `explorer-reveal/DSH缺陷报告-文件资源管理器显示不弹窗.md`。

## 缺陷 C：审批请求没有系统提示

- **现象**：DSH 的审批面板是**聊天框里的 composer 接管**。窗口不在你眼前时，
  没有任何东西告诉你「这一轮卡在等你点允许」。
- **为什么不是文件补丁**：桌面壳本身**没有** OS 级通知通道（主进程未启用 Electron
  `Notification`，preload 也没暴露通知 IPC）。想补有两条路：给桌面壳打 IPC 补丁
  （DSH 更新即失效，还要维护），或者**用插件**。选了后者。
- **修法**：宿主插件监听 `approval/request` waterfall（scope 事件向上冒泡，根上下文
  收得到全部 agent 的请求），弹一条 Windows 系统通知后**无条件 `return next()`** ——
  它绝不自己决定审批结果。投递用 PowerShell 5.1 + WinRT，**零安装**。
- **唯一的坑**：`AppId` 必须是**系统里真实注册过的** AppUserModelID。随便写个字符串
  时 `Show()` 不报错、`History` 还会计数，但系统**一个像素都不渲染**（幽灵 AUMID）。
  注册自己的只需一个 HKCU 键，可逆。
- **详见**：`approval-toast/README.md`

## 用法

```powershell
.\apply-dsh-patches.ps1 -Check     # 只检测，不改任何东西（DSH 更新后先跑这个）
.\apply-dsh-patches.ps1            # 缺什么补什么，然后用 node --check 校验
.\apply-dsh-patches.ps1 -Revert    # 撤销 A、B 两处补丁，回到上游行为
```

改完**必须完全退出并重新启动 DSH Desktop**（preload 在窗口创建时加载、
native-command 模块在 Harness 启动时加载，刷新页面不够）。

C 不走这个脚本，装法见 `approval-toast/README.md`。

## 验证

- **缺陷 A**：重启后点「N 个后台任务」，应弹出下拉面板（先确保当前会话有后台任务；
  注意**重启会清空任务登记表**，要"先重启、后起任务"）。
  机器验证：`header-title-row-clickable/evidence/post-patch-check.ps1`
  —— 按钮中心应返回 `1 HTCLIENT`。
- **缺陷 B**：在交付卡片下拉里点「在文件资源管理器中显示」，应出现资源管理器窗口、
  停在文件所在目录且目标文件被选中。
- **缺陷 C**：触发一次审批（如让 agent 申请一次提权），右下角应弹出署名
  `DeepSeek Harness` 的通知。自检：`& $node approval-toast\tools\selftest.mjs`
  （13 条离线断言 + 1 次真实投递；**退出码 0 不等于通知真的显示了，必须人眼看**）。

## 溯源

- 每个子文件夹里的 md 是**该补丁的完整记录**（含复现步骤、被推翻的假设、实测证据表、验证记录）。
- `header-title-row-clickable/evidence/` 是排查期产出的探针脚本与截图
  （含 `menu-open.png`：下拉面板被正常绘制的证据）。那里的脚本按当时窗口坐标工作，
  坐标会随窗口位置变化，复跑前需重新读取控件的 `BoundingRectangle`。
