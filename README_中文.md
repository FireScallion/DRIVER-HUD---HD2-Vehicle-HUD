# DRIVER HUD — HD2 载具状态 HUD

一个面向 **《绝地潜兵 2 / Helldivers 2》** 的轻量级载具状态 HUD Mod。它的目标很简单：让载具乘员能及时看清车辆状态，同时不把 HUD 本身变成另一种信息噪音。

**当前版本：1.4.3**  
[English README](README.md) · [Nexus Mods](https://www.nexusmods.com/helldivers2/mods/16358) · [GitHub 最新 Release](https://github.com/FireScallion/DRIVER-HUD---HD2-Vehicle-HUD/releases/latest) · [更新日志](CHANGELOG.md)

DRIVER HUD 目前为两种坦克，以及机枪 FRV / 补给 FRV 提供紧凑的载具状态显示，包括车体生命值、武器弹药、装填状态和轮胎状态等信息，并尽量保持接近游戏原本的视觉语言。

本 MOD **只负责显示状态**，不会修改车辆生命值、伤害、弹药容量、装填规则、操控、武器性能或其他玩法数值。

## 当前支持载具

| 载具 | HUD 信息 |
| --- | --- |
| **原版堡垒坦克** | 车体生命值、主炮弹药、同轴机枪弹药、主炮装填提示、中央准星 |
| **加特林 / 导弹坦克** | 车体生命值、300 发当前弹链条、6 格备用弹链、两侧导弹合计余弹、加特林装填提示、中央准星 |
| **机枪 FRV** | 车体生命值、四轮独立耐久显示、轮胎损毁后的轮毂状态 |
| **补给 FRV** | 车体生命值、四轮独立耐久显示、轮胎损毁后的轮毂状态 |

### 原版堡垒坦克

- 车体当前 / 最大生命值与生命条。
- 主炮剩余弹药。
- 同轴机枪剩余弹药。
- 主炮满弹为 **31 发（30 + 1）**。
- 主炮装填提示环放在**武器图标左侧**，不会挤占图标和弹药数字之间的空间。
- 屏幕中央载具准星。
- 支持坦克驾驶位与炮手位 HUD 路径。

### 加特林 / 导弹坦克

- 车体当前 / 最大生命值。
- 加特林当前弹链以 **0～300 条形**显示。
- 当前弹链下方显示 **6 格备用弹链**。
- 两套独立导弹架的剩余弹药合计显示。
- 加特林装填提示环位于**武器组左侧**。
- 屏幕中央载具准星。
- 手动装填遵循实际观察到的游戏状态；单纯“弹药归零”不会让 DRIVER HUD 自己假设已经开始自动装填。
  
### 机枪 FRV 与补给 FRV

- 车体生命值。
- 四个轮胎分别显示耐久状态。
- 每个轮胎内部使用连续耐久条，不额外堆叠四个轮胎 HP 数字。
- 轮胎完全损毁后切换为轮毂表现。
- 如果精确轮胎数据暂时不可用，HUD 会采用保守的降级表现，不凭空制造一个精确数值。
- FRV 车体轮廓与车体 HP 保留现有状态配色：
  - 高于 75%：白色
  - 75% 及以下：黄色
  - 50% 及以下：红色
- FRV HUD 的位置与缩放可以通过游戏外部的简单 TXT 文件实时修改。


## 性能与稳定性

性能是 DRIVER HUD 的核心设计目标之一。

正式运行路径使用有界采样和显示缓存，不会把逆向研究阶段使用过的高频大范围扫描带入正常游戏。新坦克的武器读取共享有限调度，也不会为了让加特林条“每一发都移动一下”而把整套坦克系统提高到 20 Hz 扫描。

坦克静态 HUD 与动态装填环分别缓存，因此装填动画推进时无需每帧重新创建生命条、数字、准星和其他静态元素。

FRV 的 native reader 使用版本限定的内部结构并带有兼容性检查。如果游戏更新后实际布局不再符合当前契约，对应 native 路径会停止使用，而不会继续读取不可信的内存位置。

实现与验证说明见：

- [`docs/PERFORMANCE_说明.txt`](docs/PERFORMANCE_说明.txt)
- [`docs/VALIDATION_1.4.3.md`](docs/VALIDATION_1.4.3.md)

## 前置要求

需要单独安装 **Bingus Shared Loader v15 / API 1**。

- Nexus Mods：https://www.nexusmods.com/helldivers2/mods/16292

在 Arsenal 默认优先级规则下，请把 **Bingus Shared Loader 放在 Mod 列表最底部**，保证它获得最终有效覆盖优先级。

如果启用了 Arsenal 的 **First-Mod Priority**，请按对应的反向排序规则调整，确保 BSL 的最终有效优先级仍然正确。

## 安装

1. 关闭游戏。
2. 禁用或删除所有旧 DRIVER HUD，包括 Resolver / FRV / Tank Probe 测试分支。
3. 将 `DRIVER_HUD_1.4.3.zip` 直接导入 Arsenal，并启用 **Core**。
4. 单独安装并启用 **Bingus Shared Loader v15**。
5. 确认 BSL 的最终有效优先级正确。
6. 执行 **Purge**。
7. 执行 **Deploy**。
8. 启动游戏。

不要同时启用多个 DRIVER HUD 版本或开发探针。

GitHub Release 与 Nexus Main File 可以使用同一个安装 ZIP。

## HUD 统一设置

启动一次游戏后，用记事本打开：

`%APPDATA%\Arrowhead\Helldivers2\driver_hud_settings.txt`

修改并保存，约两秒生效；不用修改 ZIP、重新部署或重启游戏。保留所有设置项；缺项、重复、越界、半写入或格式错误时整份配置不生效，继续使用上次有效设置。UTF-8 和带 BOM 的 UTF-16 均支持。

| 设置 | 默认值 | 含义 |
|---|---:|---|
| tank_offset_y | 155 | 坦克 HUD 参考分辨率距底部位置，45～500 |
| tank_scale | 1 | 坦克 HUD 缩放，0.5～2 |
| frv_x | 0.714 | FRV 中心横向位置，左 0 → 右 1 |
| frv_y | 0.90 | FRV 中心纵向位置，上 0 → 下 1 |
| frv_scale | 1 | FRV HUD 缩放，0.5～2 |
| alpha | 0.76 | 两种 HUD 不透明度，0.1～1 |
| font | new | `new` 几何数字；`old` 原版游戏字体 |
| reload_ring | true | 显示坦克装填提示环 |
| reticle | true | 显示坦克中心瞄准点 |
| weapon_cache | true | 启用经过交叉核对的实验性武器组件读取 |
| debug | true | 记录诊断日志 |
| perf | false | 记录每十秒 Lua CPU 时间与原生读取统计 |

首次创建时迁入旧 `driver_hud.cfg` 与 `frv_hud_position.txt`／`.json` 的有效设置；已有字体偏好保留。之后只编辑统一文件。包内 `driver_hud_settings.example.txt` 仅供参考，不会覆盖 AppData 设置。没有 CMD、PowerShell 或 EXE 配置器；这不代表已经通过 Nexus 扫描。

## 常见问题排查

如果 HUD 完全不显示：

1. 确认只启用了一个 DRIVER HUD 版本。
2. 删除旧的 Tank / FRV / Resolver Probe 测试包。
3. 确认 Bingus Shared Loader v15 已启用。
4. 检查 Arsenal 中 BSL 的最终有效优先级。
5. 再执行一次 Purge 和 Deploy。
6. 打开 `driver_hud.log`，确认开头的版本号确实是你刚刚安装的版本。

游戏更新可能改变内部载具 / 网络结构。如果问题恰好从《绝地潜兵 2》更新后开始，请尽量提供更新后的新日志。

## 日志与问题反馈

DRIVER HUD 会保留当前游戏进程和上一次游戏进程的日志：

```text
%APPDATA%\Arrowhead\Helldivers2\driver_hud.log
%APPDATA%\Arrowhead\Helldivers2\driver_hud_previous.log
```

Bingus Shared Loader 日志：

```text
%LOCALAPPDATA%\CowboyBingus\Helldivers2\Logs\BingusSharedLoader.log
```

反馈问题时，请尽量说明：

- DRIVER HUD 版本与游戏版本
- 载具类型
- 驾驶位 / 炮手位 / 乘员位（如果相关）
- 房主或加入者
- 出问题前是否切换过座位或载具
- 当时是否有多辆载具同时活动
- 问题出现前的操作顺序
- 有帮助时附截图或视频
- 完整 DRIVER HUD 日志；日志较大时建议压缩后提供

## 从源码构建

仓库包含可编辑 Lua 模块、稳定的堡垒坦克基线、构建脚本、发布包模板、focused regression tests，以及当前源码快照对应的验证输出。

构建安装 ZIP：

```text
python build.py dist/DRIVER_HUD_1.4.3.zip
```

构建系统会保留 1.2.1 稳定基线中的原版堡垒坦克核心区块，组合当前 runtime / UI 模块，生成二进制 patch payload，并把 `package/` 打包成可直接导入 Arsenal 的 ZIP。

主要目录：

```text
src/tank_runtime.lua        坦克变体识别、武器状态与装填状态
src/tank_ui.lua             坦克 HUD、弹链/备用弹链显示、装填提示层
src/native_reader.lua       版本限定的只读原生载具 / Health reader
src/frv_runtime.lua         FRV 身份、Health 与轮胎状态模型
src/frv_ui.lua              FRV HUD 几何与绘制
src/hud_numbers.lua         共用几何数字绘制
src/position_config.lua     FRV TXT 配置与旧 JSON 迁移
src/integration_update.lua  运行时整合与状态仲裁
src/log_session.lua         每个游戏进程的日志轮转
baseline/                   原版堡垒坦克稳定基线
package/                    发布包模板
package/CORE/               打包后的 patch / GUI material 资源
tests/                      focused 离线回归测试
evidence/                   当前源码快照的验证输出
```

仓库 / 发布包不分发游戏 DLL、进程转储、heap snapshot、第三方加载器、字体文件或 Windows 图形配置器可执行脚本。

## 开源与署名

项目自身拥有权利的源码以 **MIT License** 发布。第三方资源和内容继续遵守其原许可或授权条件，详见 [`CREDITS.txt`](CREDITS.txt)。

主要前置 / 参考鸣谢：

- **CowboyBingus** — Bingus Shared Loader。
- **DDRK1NG** — HD2 HUD+；项目早期 bootstrap / UI 研究的重要参考，保留的相关复用内容已在 `CREDITS.txt` 中单独署名。

Helldivers 2 及其游戏资产、名称、接口与标识符归其各自权利方所有。本项目与 Arrowhead Game Studios 或 Sony Interactive Entertainment 无隶属关系。
