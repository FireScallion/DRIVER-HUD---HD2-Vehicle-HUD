# DRIVER HUD — HD2 载具 HUD

一个面向 **《绝地潜兵2 / Helldivers 2》** 的轻量级载具状态 HUD Mod。

**当前版本：1.3.4**  
[English README](README.md) · [Nexus Mods](https://www.nexusmods.com/helldivers2/mods/16358) · [GitHub 最新 Release](https://github.com/FireScallion/DRIVER-HUD---HD2-Vehicle-HUD/releases/latest)

## 当前支持载具

### 堡垒坦克

- 车体当前 / 最大生命值与生命条。
- 主炮剩余弹药。
- 同轴机枪剩余弹药。
- 屏幕中心准星。
- 驾驶位与炮手位均可使用。
- 主炮满弹为 31 发（30+1）。

### 机枪 FRV 与补给 FRV

- 车体生命值。
- 四个轮胎分别显示耐久状态。
- 每个轮胎内部使用连续耐久条，不显示单独的轮胎 HP 数字。
- 轮胎完全损毁后切换为轮毂表现。
- 车辆朝前时四轮顺序为 **左前 / 右前 / 左后 / 右后**。
- FRV 车体轮廓、车窗轮廓及车体 HP 数字会随车体状态变色：
  - 高于 75%：白色
  - 75% 及以下：黄色
  - 50% 及以下：红色
- FRV HUD 的屏幕位置与缩放可以通过随包提供的图形配置器调整。

DRIVER HUD 只负责显示游戏已有的载具状态，不修改车辆生命值、伤害、弹药容量或其他玩法数值。

![FRV HUD 预览](docs/frv_ui_preview.png)

## 前置要求

需要单独安装 **Bingus Shared Loader v15 / API 1**。

- Nexus Mods：https://www.nexusmods.com/helldivers2/mods/16292

在 Arsenal 默认优先级规则下，请把 **Bingus Shared Loader 放在 Mod 列表最底部**，确保它最后加载 / 获得最终覆盖优先级。

## 安装

1. 关闭游戏。
2. 禁用或删除所有旧 DRIVER HUD，包括 FRV / Resolver / Probe 测试分支。
3. 将当前 `DRIVER_HUD_1.3.4.zip` 导入 Arsenal，并启用 **Core**。
4. 单独安装并启用 **Bingus Shared Loader v15**。
5. 确认 BSL 的最终优先级正确。
6. 执行 **Purge**，再执行 **Deploy**。
7. 启动游戏。

不要同时启用多个 DRIVER HUD 版本。

## FRV HUD位置修改

普通用户不需要手动编辑 JSON 文件。

1. 将 `DRIVER_HUD_1.3.4.zip` 解压到任意普通文件夹。
2. 双击根目录的 `CONFIGURE_FRV_HUD.cmd`。
3. 调整水平位置、垂直位置和缩放。
4. 点击“应用”。

配置器支持中文和英文。游戏正在运行时，FRV HUD 通常会在约 2 秒内读取新设置，无需 Purge、Deploy 或重启游戏。

实际配置保存在：

```text
%APPDATA%\Arrowhead\Helldivers2\frv_hud_position.json
```

## 其他配置

可选的 `driver_hud.cfg` 可放在：

```text
%APPDATA%\Arrowhead\Helldivers2\driver_hud.cfg
```

默认值：

```text
debug=true
perf=false
offset_y=155
scale=1
alpha=0.76
```

- `offset_y` / `scale` 控制堡垒坦克 HUD。
- FRV 的位置与大小使用独立配置器。
- `alpha` 同时影响两套 HUD。
- 修改 `driver_hud.cfg` 后需要重启游戏。

## 日志与问题反馈

DRIVER HUD 会保留当前与上一次游戏进程的日志：

```text
%APPDATA%\Arrowhead\Helldivers2\driver_hud.log
%APPDATA%\Arrowhead\Helldivers2\driver_hud_previous.log
```

BSL 日志：

```text
%LOCALAPPDATA%\CowboyBingus\Helldivers2\Logs\BingusSharedLoader.log
```

反馈问题时，请尽量说明 DRIVER HUD 版本、游戏版本、车型、座位、房主/客户端状态、是否切换过载具或座位，以及问题发生前的操作顺序。方便的话请私下提供完整日志。

## 从源码构建

仓库内包含可编辑 Lua 源码、构建脚本、发布包模板以及当前使用的 focused tests。

```text
python build.py dist/DRIVER_HUD_1.3.4.zip
```

构建脚本会以 1.2.1 的堡垒坦克稳定版为基础，组合当前 FRV/runtime 模块，生成 `driver_hud.lua`、patch payload，并将 `package/` 打包成可安装 ZIP。

主要目录：

```text
src/native_reader.lua       版本限定的只读原生载具 / Health 读取
src/frv_runtime.lua         FRV 身份、Health、精度与轮胎状态模型
src/frv_ui.lua              FRV HUD 几何与绘制
src/position_config.lua     FRV 位置 / 缩放配置
src/log_session.lua         每个游戏进程的日志轮转
tests/                      focused 离线测试
package/                    发布包模板
```

仓库不包含游戏 DLL、进程转储、第三方加载器或字体文件。

## 开发说明

FRV reader 依赖版本限定的游戏内部结构，并在兼容性检查不通过时停止使用对应的原生读取路径。因此《绝地潜兵2》更新后，即使 HUD 绘制代码没有变化，也可能需要 DRIVER HUD 适配新版本。

## 开源与署名

项目自身拥有权利的源码以 **MIT License** 发布。第三方材质与内容继续遵守其原许可或授权条件，详见 [CREDITS.txt](CREDITS.txt)。

主要前置 / 参考鸣谢：

- **CowboyBingus** — Bingus Shared Loader。
- **DDRK1NG** — HD2 HUD+；项目早期 HUD/bootstrap 研究的重要参考，相关复用内容继续在 `CREDITS.txt` 中单独署名。

Helldivers 2 及其游戏资产、名称、接口与标识符归其各自权利方所有。本项目与 Arrowhead Game Studios 或 Sony Interactive Entertainment 无隶属关系。

## 1.3.4 性能优化

稳定 native 绑定乘车时，所有权枚举约 5 Hz；消除重复坦克绑定读取；单次采样内复用内存区域检查。坦克弹药逻辑和采样频率、FRV 血量频率与绘制保持不变。可选 `perf=true` 需与 `debug=true` 一起开启并重启。

GitHub 下载版附带配置器。Nexus 主文件不含配置器，请从 Optional Files 下载 **FRV HUD Position Configurator 1.0**；配置器不导入 Arsenal。

已通过 33 项离线 LuaJIT 检查，未声称游戏内 FPS 实测结果。详见 `docs/PERFORMANCE_说明.txt` 与 `evidence/performance_validation.txt`。安装 Python 与 `lupa` 后运行：

```sh
python tests/test_performance.py
```
