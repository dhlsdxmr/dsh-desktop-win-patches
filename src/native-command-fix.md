# 补丁 B：`dsh-native-command/lib/index.js` 的四处改动

> 对应缺陷报告的「缺陷一（不弹窗）」与「缺陷二（弹到"此电脑"）」，两个独立缺陷、同一个函数。
> 文件：`<DshRoot>\resources\app\node_modules\@deepseek-ai\dsh-native-command\lib\index.js`
> 基线：`@deepseek-ai/dsh-native-command` 0.1.5-rc.2

`apply-dsh-patches.ps1` 用**宽松正则**做这四处替换（能同时匹配上游的单行写法和已改过的多行写法），
并且每处都先检查"是否已经改过"，所以重复执行安全。

---

## B1a — 运行器接受附加进程选项（签名）

```js
// 改前
const runNativeCommand = (command, args, signal) => new Promise((resolve, reject) => {
// 改后
const runNativeCommand = (command, args, signal, options = {}) => new Promise((resolve, reject) => {
```

## B1b — 把附加选项展开进 `execFile`

```js
// 改前（上游单行写法）
execFile(command, [...args], { encoding: "utf8", signal, windowsHide: true }, (error, stdout, stderr) => {
// 改后（本机实际落地形态，多行）
execFile(command, [...args], {
	encoding: "utf8",
	signal,
	windowsHide: true,
	...options
}, (error, stdout, stderr) => {
```

> 关键点：`...options` 必须在 `windowsHide: true` **之后**，这样调用方传的
> `{ windowsHide: false }` 才能覆盖桌面层注入的默认值。
> `resources/windows-hidden-console.mjs` 的注释本身就写了「调用方显式设置 `windowsHide` 时保留其选择」——
> 这里调用方**确实需要一个可见窗口**，属于文档认可的例外。

## B2a — 不再把路径转成 `file://` 网址

```js
// 改前
const target = pathToFileURL(windowsPath, { windows: true }).href.replaceAll(",", "%2C");
// 改后
const target = windowsPath.replaceAll(",", "%2C");
```

> `explorer.exe /select,` 的第二个参数**只认 Win32 路径**。给 `file://` 网址它什么都不选、
> 退化成打开「此电脑」。实测四种写法对照见缺陷报告 §3.5。
>
> 副作用：`pathToFileURL` 在本文件里变成未使用的导入 —— 无害（同文件其他函数仍在用）。

## B2b — explorer 调用显式要求可见窗口

```js
// 改前
await run("explorer.exe", ["/select,", target], signal);
// 改后
await run("explorer.exe", ["/select,", target], signal, { windowsHide: false });
```

---

## 撤销

四处反向替换即可回到上游行为；`apply-dsh-patches.ps1 -Revert` 已实现。

## 不建议顺手改的

`explorer.exe` 的退出码 **1 被上游无条件当成成功**（源码注释称之为 delegated handoff），
导致「失败也报成功」。这是个独立问题，需要同时改错误处理与 UI 文案，
不在本补丁范围内 —— 详见缺陷报告 §4「附带问题」。
