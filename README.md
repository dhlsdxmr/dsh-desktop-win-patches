# dsh-desktop-win-patches

Local patches for **DSH Desktop on Windows** that fix two UI defects the packaged
build still ships. They are applied to the *installed* app, so a DSH update wipes
them — `apply-dsh-patches.ps1` puts them back in one command.

**中文说明见下方「中文说明」一节。** This file is bilingual: the English part is a
short orientation, the Chinese part is the full explanation.

---

## What it fixes

| # | Symptom (as the user sees it) | Root cause | Patch target |
|---|---|---|---|
| **A** | The 「N 个后台任务 / N background jobs」 dropdown in the conversation header does nothing when clicked. Same for the mode selector next to it. | The desktop titlebar mounts a transparent 36 px drag strip across the top of the window. While that strip itself declares `-webkit-app-region: drag`, Chromium resolves the whole band as the window caption (`HTCAPTION`), so **no descendant can claim a clickable `no-drag` region** — mouse messages never reach the page. | append a block to `resources/app/out/preload/index.cjs` |
| **B** | 「在文件资源管理器中显示 / Reveal in File Explorer」 on a deliverable card either (B1) opens no window at all, or (B2) opens **This PC** instead of the target folder. | B1: the desktop injects `windowsHide: true` (= `CREATE_NO_WINDOW`) into every child process, and the Harness also owns a hidden console, so `explorer.exe` starts **without creating a window**. B2: the path is converted to a `file://` URL before being handed to `explorer.exe /select,`, which only accepts a **Win32 path**. | 4 edits in `…/@deepseek-ai/dsh-native-command/lib/index.js` |

Both defects were reproduced, diagnosed to root cause with machine-readable
evidence, patched, and confirmed by the user clicking the controls.

## Usage

```powershell
# check only (changes nothing) - run this first after a DSH update
.\apply-dsh-patches.ps1 -Check

# apply whatever is missing, then verify (node --check on both files)
.\apply-dsh-patches.ps1

# undo both patches (restore upstream behaviour)
.\apply-dsh-patches.ps1 -Revert
```

Then **fully quit and restart DSH Desktop** — both patch targets are loaded at
process start (the preload at window creation, the native-command module at
Harness boot), so a page refresh is not enough.

Non-default install location:

```powershell
.\apply-dsh-patches.ps1 -DshRoot 'E:\Apps\DSH\DSH Desktop'
```

Exit codes: `0` = the requested end state holds; `1` = at least one step failed
(the script prints which).

## Layout

```
apply-dsh-patches.ps1        the tool: apply / -Check / -Revert
src/
  preload-index-fix.js       patch A: the exact block appended to preload/index.cjs
  native-command-fix.md      patch B: the four edits, before/after
docs/
  DSH缺陷报告-后台任务下拉框点不动.md      full report for A (root cause, phase experiment, evidence)
  DSH缺陷报告-文件资源管理器显示不弹窗.md  full report for B (both defects, before/after, evidence)
evidence/                    probe scripts and screenshots produced during diagnosis
```

## Caveats

- Written against **DSH Desktop 0.9.2** (`@deepseek-ai/dsh-*` 0.1.5-rc.2) on
  Windows 10/11. A later build may restructure these files; the script reports
  clearly when a pattern it needs is missing instead of guessing.
- Patch B leaves `pathToFileURL` imported but unused — harmless. (It is still
  used by other functions in the same file.)
- Patch A deliberately gives up one thing: the window can no longer be dragged by
  the header title row — dragging stays available on the tab row and on the blank
  parts of the top band. That is the necessary trade for the controls to be
  clickable.
- `explorer.exe` exiting with code 1 is still treated as success upstream; this
  patch does not change that. It is why the UI can say "requested" while nothing
  happened (see report B §4).

## License

Not chosen yet.

---

# 中文说明

## 这是什么

DSH Desktop（Windows 打包版）目前仍带着两个界面缺陷。这个仓库把**本机已验证有效**的
两处补丁做成可重复执行的形式 —— 因为补丁是打在**已安装的程序目录**里的，
**DSH 一更新就会被覆盖**，所以真正需要的不是"记录修法"，而是"一条命令打回去"。

## 两个缺陷

### 缺陷 A：会话头部标题行的控件点了没反应

- **现象**：「N 个后台任务」下拉按钮点了不出菜单，也没有任何报错；同一行的
  「标准模式」等控件一样点不动。
- **根因**：桌面端在窗口顶部铺了一条 36px 的**透明拖拽条**（`-webkit-app-region: drag`）。
  **只要这条带子自己声明 drag，整条带子就被判定为窗口标题栏**，带子里任何后代元素的
  `no-drag` 都不算数 —— 鼠标消息根本不会作为网页事件送达，`onClick` 永不触发。
- **决定性实验**：逐阶段改拖拽条并读系统命中测试（`WM_NCHITTEST`）——
  带子 `drag` → 按钮中心 `HTCAPTION`（点不到）；带子 `no-drag` → `HTCLIENT`（可点）；
  把带子 `display:none` → **仍然是 `HTCAPTION`**（原生 `titleBarOverlay` 仍认领这条带子）。
  **所以正确修法不是"在带子里加 no-drag"，而是"让带子别声称 drag"。**
- **修法**：向 `preload/index.cjs` **末尾追加**一段（见 `src/preload-index-fix.js`），
  让拖拽条自己 `no-drag`，再给标题行与顶部带内控件逐个打行内 `no-drag`，
  标签行保留 `drag` 以维持窗口拖动。
- **代价**：窗口不再能用标题行拖动（改用标签行或顶部空白区）。带子本是
  `pointer-events:none` 的透明层，**外观零变化**。

### 缺陷 B：交付卡片「在文件资源管理器中显示」失效

两个**互相独立**的缺陷，在同一个函数里：

- **B1 不弹窗**：桌面端给所有子进程注入 `windowsHide: true`（= `CREATE_NO_WINDOW`），
  而 Harness 自身还持有一个隐藏控制台 → `explorer.exe` **起来了但没有窗口**
  （进程表里 `MainWindowHandle = 0`，界面却显示"已请求"）。
  **修法**：让运行器接受一个可选的第 4 参数，explorer 调用显式传 `{ windowsHide: false }`。
- **B2 弹到「此电脑」**：把路径**先转成 `file://` 网址**再交给 `explorer.exe /select,`，
  而 `/select,` **只认 Win32 路径** —— 给网址它什么都不选，退化成打开「此电脑」。
  **修法**：直接传纯 Windows 路径（逗号仍按原逻辑转义 `%2C`）。

四处改动的前后对照见 `src/native-command-fix.md`。

## 用法

```powershell
.\apply-dsh-patches.ps1 -Check     # 只检测，不改任何东西（DSH 更新后先跑这个）
.\apply-dsh-patches.ps1            # 缺什么补什么，然后用 node --check 校验
.\apply-dsh-patches.ps1 -Revert    # 撤销两处补丁，回到上游行为
```

改完**必须完全退出并重新启动 DSH Desktop**（preload 在窗口创建时加载、
native-command 模块在 Harness 启动时加载，刷新页面不够）。

## 验证

- 缺陷 A：重启后点「N 个后台任务」，应弹出下拉面板（先确保当前会话有后台任务；
  注意**重启会清空任务登记表**，要"先重启、后起任务"）。
  机器验证：`evidence\post-patch-check.ps1` —— 按钮中心应返回 `1 HTCLIENT`。
- 缺陷 B：在交付卡片下拉里点「在文件资源管理器中显示」，应出现资源管理器窗口、
  停在文件所在目录且目标文件被选中。

## 溯源

- `docs/` 是两份完整缺陷报告（含复现步骤、被推翻的假设、实测证据表、验证记录）。
- `evidence/` 是排查期产出的探针脚本与截图（含 `menu-open.png`：下拉面板被正常绘制的证据）。
- **注意**：`evidence/` 里的探针脚本按当时窗口坐标工作，坐标会随窗口位置变化，
  复跑前需重新读取控件的 `BoundingRectangle`。
