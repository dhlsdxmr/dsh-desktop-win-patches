# dsh-approval-toast

审批请求来了，在 Windows 右下角弹一条**系统通知** —— 这样 DSH 窗口在后台时你也能立刻知道有东西在等你批。

> 本目录是 `D:\DSH-program\patch\` 仓库的**第三个条目**，但它**不是文件补丁**：它是 DSH 的
> profile 插件，靠 `dsh plugin --profile web add` 装，**DSH 更新不会覆盖它**，所以
> `apply-dsh-patches.ps1` 不管它。原理与排查记录见 `D:\DSH-program\memory\插件-审批通知.md`。

## 它解决什么

DSH 的审批面板是**聊天框里的 composer 接管**。窗口不在你眼前时，没有任何东西告诉你
「这一轮卡在等你点允许」。DSH Desktop 本身**没有**操作系统级通知通道（主进程没启用
Electron `Notification`，preload 也没暴露通知 IPC），所以只能用插件补。

## 它怎么工作

```
宿主 approval/request waterfall  ←  @deepseek-ai/dsh-user-approval 派发
        │  （scope 沿链向上冒泡；根上下文无 scope tag，故一律收得到）
        ▼
lib/index.js 的监听器（根上下文，零注入）
        │  ① 弹通知（fire and forget）
        │  ② 无条件 return next()   ← 关键：它绝不自己决定
        ▼
浏览器审批面板照常拿到决定权
```

**它是纯观察者。** `approval/request` 是 waterfall，返回值就是审批结果（`allowed-once` 之类）。
这个插件**永远**调 `next()` 把决定权让出去 —— 否则就等于静默自动放行，那是它最不该做的事。
自检里有专门一条断言守这个行为。

投递方式：`assets/toast.ps1`，Windows PowerShell 5.1 + WinRT toast。**零安装**
（不装 BurntToast、不写 C 盘、不需要管理员）。

## 安装

```powershell
# 1) 注册本插件自己的通知身份（HKCU，可逆，不需要管理员）
powershell -NoProfile -ExecutionPolicy Bypass -File tools\register-aumid.ps1 `
  -IconUri 'D:\DSH\DSH Desktop\DSH Desktop.exe'

# 2) 装进 profile
$node = 'D:\DSH\DSH Desktop\resources\app\node_modules\node\bin\node.exe'
$bin  = 'D:\DSH\DSH Desktop\resources\app\node_modules\@deepseek-ai\dsh\lib\bin.js'
& $node $bin plugin --profile web add 'link:D:\DSH-program\patch\approval-toast'

# 3) 完全退出并重启 DSH Desktop —— CLI 直装不会 hot-mount
```

第 1 步不做也能跑，但通知会署名借来的身份而不是 `DeepSeek Harness`。

## 配置

写在 **profile 的** `cordis.patch.yml` 里做 id 定向覆盖（**不要**在插件自己的 patch 里
再插一行 —— 重复 id 会崩 loader）：

```yaml
- id: dsh-approval-toast
  config:
    enabled: true
    onlyTools: ['pwsh']      # 空数组 = 所有工具
    cooldownMs: 2500         # 同一工具在这个窗口内只弹一次
    title: '审批请求：{tool} 需要越权执行'
    body: '{reason}'
```

| 键 | 缺省 | 说明 |
|---|---|---|
| `enabled` | `true` | 总开关 |
| `aumid` | `DeepSeek.Harness.DSH` | **必须是已注册的 AppUserModelID**，见下 |
| `title` / `body` | 见上 | 支持 `{tool}` `{reason}`；未知占位符会清空而不是原样露出 |
| `fallbackReason` | 一句提示 | 模型没写理由时用它 |
| `cooldownMs` | `2500` | 同一工具的重复抑制窗口 |
| `onlyTools` | `[]` | 工具白名单 |

## ⚠️ 唯一致命坑：幽灵 AUMID

`ToastNotificationManager.CreateToastNotifier('<任意字符串>')` **不报错**，`Show()` **不抛异常**，
`History.GetHistory()` 还会把它**计数入库** —— 但系统里没有这个注册身份时，
**屏幕和操作中心一个像素都不渲染**。

所以「调用成功」「历史 +1」**都不是送达证据**，唯一可信的验证是**人眼看屏幕**。

真 AUMID 从哪查（别猜）：

```powershell
powershell -NoProfile -Command "Get-StartApps | Where-Object Name -like '*PowerShell*'"
```

本机实测：`DisplayName` 注册表键**单独**就够，**不需要**开始菜单快捷方式、不需要 property-store COM。

## 自检

```powershell
& 'D:\DSH\DSH Desktop\resources\app\node_modules\node\bin\node.exe' tools\selftest.mjs
```

13 条离线断言（argv 形状、模板、节流、白名单、开关、**必须 delegation**）+ 1 次真实投递。
最后会打印 `VISUAL CONFIRMATION REQUIRED` —— 因为退出码 0 不等于通知真的显示了。

## 排障：没弹通知时先看哪里

插件通过 cordis 内置 logger 往 `harness.log` 打三类行，**「没弹通知」因此可以一眼定位**：

| 日志里看到 | 含义 |
|---|---|
| **完全没有** `loaded:` 行 | 插件**没被加载**（loader 没挂上这一行 / 装完没重启 DSH） |
| `loaded: enabled=... aumid=...` | 插件**挂载成功**，后面列的是生效配置 |
| `toast requested: tool=... aumid=...` | 收到了审批请求，正在起 PowerShell |
| `toast delivered: exit=0 tool=...` | PowerShell 正常退出 → 已交给系统（**仍不等于用户看到了**，见幽灵 AUMID） |
| `toast delivery FAILED: exit=<n>` / `FAILED to start` | 投递失败：多半是 AppUserModelID 没注册，或 PowerShell 起不来 |

日志位置：`<DSH 数据目录>\logs\harness.log`（本机 `D:\DSH-data\dsh-desktop\logs\harness.log`）。

> 设计取舍：logger 是**防御式**获取的 —— 插件 `inject` 为空，**绝不能**因为拿不到 logger 就让 `apply` 抛错（那会变成插件整个不挂载）。拿不到时静默降级为 no-op，此时回到「无迹可查」，但审批流程始终不受影响。

## 卸载

```powershell
& $node $bin plugin --profile web remove dsh-approval-toast    # 然后重启 DSH
Remove-Item -Recurse 'HKCU:\SOFTWARE\Classes\AppUserModelId\DeepSeek.Harness.DSH'
```

## 已知没做的

- **点通知跳回 DSH**：需要 COM activator 或 protocol activation，本期不做。
- **专注助手/全屏时会被压掉**：系统行为；要兜底可另配站内通知（参见 `dsh-memory-evolve` 的铃铛实现）。
- **每次弹窗 cold-start PowerShell 约 300–600ms**：审批场景无所谓。
- **源码位置**：profile 里是指向本目录的 Junction；**本目录被挪走/改名，插件即失效**
  （需重新 `dsh plugin --profile web add 'link:<新路径>'`）。
- **插件必须零依赖**：只能 `import 'node:*'`。profile 的 `node_modules` 里**没有
  `@deepseek-ai`**，引任何 `@deepseek-ai/*` 都会解析失败 —— 所以配置用纯 JS，不引 schemastery。
