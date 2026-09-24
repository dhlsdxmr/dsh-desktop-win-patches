# DSH 缺陷报告：Windows 标题栏拖拽区吞掉鼠标事件，会话头部标题行的控件点不动（后台任务下拉框「点了没用」）

- 报告日期：2026-09-24
- 环境：DSH Desktop 0.9.2（Windows 11，Electron 打包版，资源目录 `D:\DSH\DSH Desktop`），`@deepseek-ai/dsh-*` 均为 0.1.5-rc.2
- 用户可见症状：「N 个后台任务」下拉按钮（chevron）**点了没反应**；同一行的「标准模式」等控件大概率同样点不动
- 状态：**根因已定位并修复，用户实测通过 ✅**（下拉列表正常弹出，见 `evidence/` 与文末验证记录）
- 本文件只作留存，尚未提交上游

---

## 0. 本机已应用的最终补丁（2026-09-24，已验证生效）

只改了已安装应用里的一个文件（**只影响这台机器，程序更新后会被覆盖**）：

`D:\DSH\DSH Desktop\resources\app\out\preload\index.cjs`（文件末尾追加一段，约 60 行）

**修法：让那条 36px 透明拖拽条自己声明 `no-drag`**，这样带子内各元素各自的 `-webkit-app-region` 才生效（标题行可点、拖动交给标签行和空白区）。因为该条子本身是 `pointer-events:none` 的透明覆盖层，这个改动**不改变任何外观**。

核心代码（完整版见文件末尾 `==== DSH local fix` 段）：

```js
function noDrag(el) { el.style.setProperty("-webkit-app-region", "no-drag", "important"); }
function drag(el)   { el.style.setProperty("-webkit-app-region", "drag", "important"); }

function apply() {
  // ① 关键一步：拖拽条自己不再声称 drag（否则整条 36px 带子被判定为窗口标题栏）
  var strip = document.getElementById("dsh-desktop-windows-drag-region");
  if (strip) noDrag(strip);
  // ② 标题行整行 no-drag
  var row = document.querySelector("[class*='titleRow']");
  if (row) { row.setAttribute("data-dsh-no-drag", "header-title-row"); noDrag(row); }
  // ③ 顶部 44px 带内的所有控件逐个 no-drag（用行内样式，避开样式表失效问题）
  var controls = document.querySelectorAll("button, a, input, select, textarea, [role='button']");
  for (var i = 0; i < controls.length; i++) {
    var el2 = controls[i];
    if (strip && (strip === el2 || strip.contains(el2))) continue;
    var r = el2.getBoundingClientRect();
    if (r.height > 0 && r.top < 44 && r.bottom > 0) {
      el2.setAttribute("data-dsh-no-drag", "titlebar-band");
      noDrag(el2);
    }
  }
  // ④ 窗口拖动保留：标签行（对话/轨迹）显式 drag
  var tabs = document.querySelector("[class*='wSkVaW_tabs']");
  if (tabs) drag(tabs);
}
apply();
var runs = 0;
var timer = setInterval(function () { runs++; apply(); if (runs > 150) clearInterval(timer); }, 2000);
```

- 最终文件：大小 **66830** 字节，`SHA256 = C2FBE18963BF5B096BADADE71257B01FD107385FFA22875BC9C60C1DE4493898`
- 校验：`node --check "D:\DSH\DSH Desktop\resources\app\out\preload\index.cjs"` 通过（exit 0）
- 该段**不含任何诊断代码**（排查用的探针已全部删除，见 §8）
- 启动后约 5 分钟内每 2 秒重跑一次 `apply()`，以覆盖头部组件挂载晚于 preload 的情况
- **必须完全退出并重新启动 DSH Desktop 才生效**（preload 在窗口创建时加载）
- **回滚**：删掉文件末尾从 `// ==== DSH local fix:` 到 `// ==== end DSH local fix ====` 的整段即可，其余代码未被改动
- **副作用**：窗口顶部 36px 带子里除标签行与空白区外不再可拖动（标题行本身变成了控件区）。这是可点的必要条件，属有意取舍

### 0.1 三版失败尝试（保留作记录，均已回滚）

| 版本 | 做法 | 结果 |
|---|---|---|
| 第一版 | 给 `[class*="headerActions"]` 加 `no-drag` | ❌ 08:15:47 重启后仍 `HTCAPTION` |
| 第二版 | 再把标题行抬到 `z-index:31` | ❌ 仍 `HTCAPTION` |
| 第三版 | 按类名 token（`[class*="titleRow"]` 等）精确匹配 + 自检探针 | ❌ 仍 `HTCAPTION`（但证明**选择器全部匹配成功**） |

真正的根因见 §2.3，判定实验见 §3.5。

---

## 1. 现象

会话头部标题行右侧的「N 个后台任务」是个真实 `<button>`（class `QsffPG_trigger`），但鼠标点击它：

- 没有下拉菜单出现；
- 也没有报错、没有视觉反馈（悬停只是文字颜色变化）；
- 与其并排的「标准模式」等头部控件同样无法点击。

**关键否认项**：这不是后台任务列表插件（`@deepseek-ai/dsh-client-ui-jobs`）的渲染问题 —— 菜单本身完全正常（见 §3.1）。

## 2. 根因

DSH Desktop 在 Windows 上启用无边框 + `titleBarOverlay`，由预加载脚本注入一条 36px 高的「拖拽条」：

- `resources/app/out/preload/index.cjs:274` → `--dsh-titlebar-safe-inset-top: 36px;`
- `index.cjs:232` → `DRAG_REGION_ID = "dsh-desktop-windows-drag-region"`，该 div 覆盖窗口顶部 36px，`-webkit-app-region: drag`
- 同一段样式把 `headerUtilities` / `headerCorner` 挪到 `top:38px` 以躲开拖拽条，但**没有处理标题行里的 `headerActions` 槽**
- 宽泛的 `no-drag` 兜底只覆盖 `button / a / input / select / textarea / [role=button] / [role=tab] / [role=menuitem] / [data-dsh-no-drag]`，而该按钮**没有写 `role="button"`**（只有 `aria-expanded`），因此没被豁免

结果：按钮盒是 y=8..44，中心 y=26，**整个可点区域都落在拖拽条内**。在 Windows 上位于 `-webkit-app-region: drag` 元素的命中测试被 Chromium 当成窗口标题栏，鼠标消息根本不会作为网页事件送达，`onClick` 永远不触发。

### 2.2 一路上被推翻的四个假设（重要：避免重走弯路）

| # | 假设 | 怎么被推翻的 |
|---|---|---|
| 1 | 插件没绑点击 / 菜单有渲染 bug | 用无障碍 `ExpandCollapsePattern` 驱动同一按钮，菜单正常弹出并正确渲染（§3.1） |
| 2 | 按钮没有 `role="button"` 所以不在 `no-drag` 白名单里 | 手工给按钮加 `no-drag`（行内、`!important`）后仍 `HTCAPTION` |
| 3 | 选择器没匹配上（`div:first-child` 假设） | 探针实测 `sel '[class*="titleRow"]' -> region=no-drag z=31 firstChildOfHeader=true`，**匹配完全成功**却仍无效（§3.4） |
| 4 | 注入的样式表整体失效 / 属性名应为 `app-region` | 探针实测 `layoutSheet rules=17`、`titleRow z=31` 生效；侧栏按钮计算值也是 `no-drag` → 样式表和 `-webkit-app-region` 都正常 |

### 2.3 真正的原因（阶段实验判定，§3.5）

**只要那条 36px 拖拽条自己是 `-webkit-app-region: drag`，整条带子就被判定为窗口标题栏，带内任何后代的 `no-drag` 一律不算数。**

这是 Electron/Chromium 对 `titleBarOverlay` + 自定义 drag 层的优先级行为：drag 区域一旦由上层声明，其覆盖范围内的 no-drag 都要让位；反过来，**把这条带子本身改成 `no-drag`，带内元素的 `no-drag` 立刻生效**（实验 P1：按钮中心从 `HTCAPTION` → `HTCLIENT`）。

因此正确修法不是"在带子里加 no-drag"，而是"**让带子别声称 drag**"。带子本身是 `pointer-events:none` 的透明覆盖层，改它不影响外观、不影响布局，只是把"这一带算标题栏"这件事取消掉。

## 3. 实测证据

### 3.1 菜单本身是好的（用无障碍接口驱动同一按钮）

用 UI Automation 的 `ExpandCollapsePattern`（绕过鼠标）驱动**同一个按钮**：

- 驱动前：`state = Collapsed`，`QsffPG_menu` 不存在
- 驱动后：`state = Expanded`，`QsffPG_menu rect=712,50 421x50`，行内容正确
  （`pwsh | Write-Output "probe j… | exit code: 0 | 2分0秒`），面板完整显示在按钮正下方，未被遮挡
- 见截图：`evidence/menu-open.png`（`PrintWindow` 抓的窗口真实像素）

### 3.2 系统级命中测试：点的地方是标题栏，不是按钮

对运行中的窗口发 `WM_NCHITTEST`（客户端坐标换算为屏幕坐标）：

| 屏幕坐标 | 返回值 | 含义 |
|---|---|---|
| 700,20 | `2 HTCAPTION` | 拖拽条 |
| **775,26**（按钮中心，按钮=712,8 127x36） | **`2 HTCAPTION`** | **拖拽条 → 点不到** |
| 900,20 | `2 HTCAPTION` | 拖拽条 |
| 1400,20 | `8 HTMINBUTTON` | 窗口按钮区 |
| 775,46（按钮下沿以下） | `1 HTCLIENT` | 正常 |
| 775,60 | `1 HTCLIENT` | 正常 |
| 775,200 | `1 HTCLIENT` | 正常 |

边界恰好是 36px，与 `--dsh-titlebar-safe-inset-top: 36px` 完全吻合。

### 3.3 与用户截图一致

用户截图里按钮所在行 y≈8-44，正是拖拽条覆盖范围；`标准模式` 与 `后台任务` 同处该行，所以一起失效。

### 3.4 无法完成的验证

本机 harness 沙箱下，`SendInput` / `mouse_event` / `PostMessage(WM_LBUTTON*)` 三种注入方式均无法让该窗口产生网页点击（合成输入被环境丢弃），因此「修复后真实点击生效」这一条只能由用户手工点击确认（见 §5）。

## 3.5 判定实验：逐阶段改拖拽条，观察系统命中测试（决定性证据）

让探针每 2.5 秒切换一个阶段，外部脚本同时读"当前阶段 + `WM_NCHITTEST`"，两边自动对齐：

| 阶段 | 拖拽条状态 | y=20 / y=26 命中 |
|---|---|---|
| **P0 基线** | h=36, `region=drag` | **CAPTION** ❌ |
| **P1** | h=36, **`region=no-drag`** | **CLIENT** ✅ |
| **P2** | h=0（height:0 + visibility:hidden） | CLIENT ✅ |
| **P3** | `display:none`（从布局移除） | **CAPTION** ❌ |

结论：
- P1 与 P0 只差一个属性 → **拖拽条的 `drag` 声明就是唯一真凶**（§2.3）；
- P3 回到 CAPTION 很反直觉，但正好说明：`display:none` 时 Electron 的原生 `titleBarOverlay` 仍然认领这条带子；**只有把带子显式标成 `no-drag` 才能在上面开洞**。这也解释了为什么"把带子隐藏掉"不是可行替代方案。

脚本：`evidence/phase-sample.ps1`（采样）、`evidence/patch7.ps1`（阶段实验版探针，已回滚）。

## 4. 修复建议

### 方案 A（本机已用，已验证 ✅）

**让拖拽条自己声明 `no-drag`**，再给标题行/顶部带内的控件逐个打行内 `no-drag`（完整代码见 §0）：

```js
var strip = document.getElementById("dsh-desktop-windows-drag-region");
if (strip) strip.style.setProperty("-webkit-app-region", "no-drag", "important");
```

优点：不动插件、不动布局、不改窗口选项；标题行所有头部控件一起恢复可点；因为带子本来是 `pointer-events:none` 的透明层，外观零变化。
代价：窗口拖动只剩标签行（`对话/轨迹`）和最右侧空白区。
注意：**必须用行内样式（或 JS 直接设置）**—— 本机实测发现通过 `<style>` 注入的选择器规则在这条带子上不可靠（见 §2.2 假设 3/4 与 §8）。

### 方案 B（建议上游采纳）

1. **首选**：桌面端在安装拖拽条时，就让这条带子**不要覆盖会话头部标题行**（例如只在侧栏上方与标签行上方铺 drag），从根本上避免"标题栏吃掉控件"；
2. 若必须全宽覆盖：让带子自身 `no-drag`，由带内元素各自声明 `drag`/`no-drag`（即本机这次的修法）；
3. 让 `@deepseek-ai/dsh-client-ui-jobs` 的触发按钮带上 `role="button"`，使它自动落入既有的 `no-drag` 白名单（对其它同类插件同样有益：`header.actions` 槽不是"插件的错"，但语义属性不该成为能不能点的隐含前提）。

## 5. 修复后的验证方式

1. 完全退出 DSH Desktop 并重新启动；
2. 让当前会话至少有一个后台任务，使「N 个后台任务」出现；
3. 用鼠标点它：期望**弹出圆角下拉面板**，列出任务 `kind / label / 状态 / 耗时`，chevron 旋转 180°；
4. 再点空白处应关闭面板；按 Esc 也应关闭并把焦点还给按钮；
5. 同时确认同一行的「标准模式」等控件也能点了。

**不依赖鼠标的机器验证**（改完 preload、重启后即可跑，用来判断补丁到底有没有生效）：

```powershell
# 按钮中心应返回 1 HTCLIENT；若仍是 2 HTCAPTION，说明补丁没生效
& "evidence\post-patch-check.ps1"
```

预期输出（补丁生效时）：

```
  screen <按钮中心> -> 1 HTCLIENT(正常可点)
```

历史上只加 no-drag 时，这里始终是 `2 HTCAPTION(标题栏/拖拽)` —— 那正是"点了没用"的机器可读形式。

**最终验证记录（2026-09-24）**：

- 修复版重启后 `post-patch-check.ps1` 输出：按钮中心与整条带子 6 个采样点**全部 `1 HTCLIENT`**；
- 探针自报：`strip region="no-drag" h=36`、`titleRow region="no-drag" z=31`、`trigger region="no-drag"`、`elementFromPoint=SPAN.QsffPG_count`（按钮内部节点，说明它已是最上层可点元素）；
- **用户实测：鼠标点击弹出后台任务列表 ✅**（3 个任务，`pwsh` / 命令摘要 / `运行中` / 耗时，chevron 翻转）。

## 6. 相关文件清单

- `resources/app/out/preload/index.cjs`（**改动点**：文件末尾追加 `DSH local fix` 段）
- `resources/app/node_modules/@deepseek-ai/dsh-client-ui-jobs/lib/client.js`（触发按钮 `QsffPG_trigger` + `QsffPG_menu`，本身正常）
- `resources/app/node_modules/@deepseek-ai/dsh-client-ui-conversation/lib/client.js`（`headerActions` / `headerUtilities` / `headerCorner` 槽的 JSX 与 CSS）
- `resources/app/node_modules/@deepseek-ai/dsh-client-ui-primitives/lib/index.js`（`useDismissOnOutsidePointer`，按下拉菜单的外部点击关闭行为）

## 7. 排查用脚本（保留可复跑）

| 脚本 | 用途 |
|---|---|
| `evidence/post-patch-check.ps1` | **最常用**：一键判断补丁是否生效（补丁写入时间 vs 应用启动时间 + 命中测试） |
| `evidence/check.ps1` | 上面那支的早期版本（含结论判定） |
| `evidence/phase-sample.ps1` | **决定性实验**：把探针阶段与 `WM_NCHITTEST` 自动对齐打表 |
| `evidence/nchittest.ps1` / `evidence/sweep.ps1` | 量拖拽区边界（y=0..34 全宽 CAPTION，y≥36 CLIENT） |
| `evidence/read-probe-a11y.ps1` / `evidence/find-probe.ps1` | 从无障碍树读回页面内探针的结果（不依赖截图） |
| `evidence/uia-probe5.ps1` | 用 `ExpandCollapsePattern` 打开下拉、枚举菜单行 |
| `evidence/grab.ps1` | 免 `System.Drawing` 的窗口抓图（BitBlt + 手写 PNG 编码） |
| `evidence/menu-open.png` | 下拉面板被正常绘制的截图证据 |
| `evidence/patch8-final.ps1` | 生成最终补丁（含根因注释），**程序更新覆盖后可直接重跑** |

> 复跑提示：这些脚本按当前会话的窗口坐标工作，坐标会随窗口位置/尺寸变化，需重新读取按钮的 `BoundingRectangle` 后再用。

## 8. 排查过程留下的三个"坑"（写给未来的自己）

1. **合成输入在本机不可用**：`SendInput` / `mouse_event` / `PostMessage(WM_LBUTTON*)` 都无法让该窗口产生网页点击（沙箱环境丢弃），所以"点不动"只能靠 `WM_NCHITTEST` 这种系统层证据 + 无障碍接口驱动来间接验证。
2. **不能假设"注入的 `<style>` 一定生效"**：中途一度以为整张表失效（依据：`tabs { padding-right:180px }` 没体现），但后来探针实测 `layoutSheet rules=17`、`titleRow z=31` 生效，说明表是活的 —— 之前的"没体现"是测量方式（拿祖先盒宽度推断 padding）不可靠。**判定样式是否生效，必须直接读 `getComputedStyle`，不要靠几何反推。**
3. **`document.title` 不能当对外通道**：主进程把窗口标题固定成空串（`window.on("page-title-updated", e => { e.preventDefault(); window.setTitle("") })`），所以探针改 `document.title` 读不到。可用的回读通道是：**页面内可见文本/带 `aria-label` 的元素（会被 UIA 暴露）**、截图、以及 `%TEMP%` 文件（需 `require('node:fs')` 可用，本机 preload 沙箱里不一定可用）。
4. **重启会清空后台任务**：harness 后端随 DSH Desktop 一起重启，`jobsBySession` 登记表随之清空。验证"下拉里有没有任务"必须**先重启、后起任务**，顺序反了会误判成"任务丢了"。
