# DRIVER HUD — HD2 载具 HUD

<img src="mod/icon.png" alt="DRIVER HUD 图标" width="128">

一个为 **HELLDIVERS 2** 制作的轻量载具状态 HUD Mod。

DRIVER HUD 当前正式支持**堡垒坦克**，可在驾驶位与炮手位显示车体血量、主炮弹药、同轴机枪弹药以及屏幕中心准星。未来可能研究 FRV 等其他载具，并优先通过独立测试版验证，稳定后再考虑整合进主版本。

> 当前版本：**1.2.1**

## 功能

- 堡垒坦克车体血量
- 堡垒坦克主炮弹药 —— 满弹 **31 发**
- 堡垒坦克同轴机枪弹药
- 屏幕中心准星
- 驾驶位与炮手位均可使用
- 默认开启诊断日志，方便反馈问题
- 不读取游戏进程内存；当前实现使用 Stingray Lua / Network API，并在运行时验证对象与字段声明

## 依赖

- **Bingus Shared Loader v15（BSL，API 1）** —— 必须单独安装
- **HD2 HUD+** —— 可选，DRIVER HUD 不依赖它

BSL：https://www.nexusmods.com/helldivers2/mods/16292  
HD2 HUD+：https://www.nexusmods.com/helldivers2/mods/15298

## 安装

普通玩家请从仓库的 **Releases** 页面下载可安装 ZIP，不要直接把 GitHub 自动生成的 Source code ZIP 当成 Arsenal 安装包。

使用 Arsenal：

1. 禁用或移除旧版 DRIVER HUD。请勿同时启用多个版本。
2. 导入 DRIVER HUD 发布 ZIP，并启用 **Core**。
3. 导入并启用 Bingus Shared Loader v15。
4. 使用 Arsenal 默认加载优先级时，将 BSL 放在列表最下面，使其最后加载。
5. 执行 **Purge**，再执行 **Deploy**，然后启动游戏。

通常从上到下为：

```text
HD2 HUD+（可选）
DRIVER HUD
Bingus Shared Loader v15
```

如果启用了 **First-Mod Priority**，实际优先级会反转，请相应调整 BSL 的位置。

## 配置

默认配置无需手动修改。如需自定义，将 `mod/driver_hud.cfg` 复制到：

```text
%APPDATA%\Arrowhead\Helldivers2\driver_hud.cfg
```

默认值：

```ini
debug=true
offset_y=155
scale=1
alpha=0.76
```

- `debug`：是否写入诊断日志，默认开启
- `offset_y`：HUD 纵向位置
- `scale`：HUD 缩放比例
- `alpha`：HUD 不透明度

修改配置后请重新启动游戏。

## 问题反馈

如果 HUD 不显示或弹药显示异常，请先检查：

- BSL 是否启用且加载优先级正确
- 是否仍启用了旧版 DRIVER HUD
- 修改 Mod 配置后是否重新执行过 Purge / Deploy

反馈 DRIVER HUD 问题时，请附上：

```text
%APPDATA%\Arrowhead\Helldivers2\driver_hud.log
```

BSL 加载日志：

```text
%LOCALAPPDATA%\CowboyBingus\Helldivers2\Logs\BingusSharedLoader.log
```

同时请说明当时位于驾驶位还是炮手位、是否换过载具、场上是否存在多辆载具，以及问题发生前的操作。

## 仓库结构

```text
mod/                  当前可安装 Mod 文件
  CORE/               Arsenal / HD2 patch 文件
  manifest.json
  driver_hud.cfg
  ...
src/
  driver_hud.lua      当前 patch 中 Lua payload 的可读源码
README.md             英文项目首页
README_zh-CN.md       中文项目首页
CREDITS.md            第三方来源与署名
CONTRIBUTING.md       贡献与 Fork 说明
LICENSE               项目自有源码的 MIT License
```

`src/driver_hud.lua` 是当前 `patch_0` 中 Lua payload 的可读副本。仓库目前**没有提供自动化 patch 构建流程**，因此 `mod/` 下的文件应视为当前正式构建，`src/` 下的 Lua 文件主要用于阅读、研究和修改参考。

## 技术路径概览

DRIVER HUD 当前大致采用以下流程：

```text
本地玩家 / Avatar
        ↓
当前载具识别
        ↓
堡垒坦克 Hull 确认
        ↓
主炮 / 同轴机枪 GameObject 解析
        ↓
Network Type + 字段声明验证
        ↓
定向字段读取 + last-valid 缓存
        ↓
Stingray Screen GUI
```

当前弹药读取路径结合游戏 Network 声明和运行时验证实现，避免高频盲猜字段，也不读取 Helldivers 2 进程内存。

## 支持范围与后续方向

正式版目前支持**堡垒坦克**。未来可能研究 FRV 等其他载具，但实验性功能可能会先保留在独立测试版中，确认稳定后再考虑并入主版本。

不承诺具体功能或载具支持时间。

## 贡献与 Fork

欢迎研究、修改、Fork 或维护自己的衍生版本。详见 [CONTRIBUTING.md](CONTRIBUTING.md)。

维护者可能没有足够时间持续审查或合并外部 Pull Request；如果希望长期扩展某项功能，自行维护 Fork 完全没有问题。

## 署名

第三方来源与致谢见 [CREDITS.md](CREDITS.md)。

## 许可

本仓库中由 DRIVER HUD 项目自行拥有权利的源码采用 [MIT License](LICENSE)。

第三方代码、工具、游戏资产、名称、接口和标识仍遵循各自的许可与权利归属；MIT License 不会重新授权第三方内容。
