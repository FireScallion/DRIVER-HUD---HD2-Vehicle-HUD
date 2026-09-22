# DRIVER HUD 1.3.5 — 新游戏构建适配与数字绘制兼容

## 结论与范围

基线是资料库中的 **1.3.4 GitHub 源码包**。已修改新版 native 布局并生成可安装包；数字增加默认的共用几何材质绘制方案。没有只修改 PE 白名单来放行旧地址，也没有回退到邻近车辆或轮胎数值特征扫描。

本轮验证分三层：用户提供的新模块字节、LuaJIT 合成内存/引擎接口测试、安装载荷与源码重建。**未运行 Windows/HD2；这不是新版本实际入车、联机或曲率画面的实机验收。**

## 1. 输入与已确认的故障

新日志 `driver_hud(20260922-095227).log` 第 1–4 行显示 1.3.4 启动后因 `unsupported game.dll PE identity` 停止 native 读取；第 5–10 行显示原坦克兼容绑定与主炮/同轴读取入口仍可用。问题发生在 FRV 身份和血量读取之前，并非新日志证明了车内没有 Health 数据。

使用的新快照：`game_module_20260922T100015_513694Z.zip`。

- 捕获状态 COMPLETE，74,907,648 字节，missing_bytes=0；实际重算长度及 SHA-256 一致。
- 新磁盘 DLL SHA-256：`73374bd4e38386beb9a23bef480082b67d457ebc77485fbec5f488b4e95e201f`。
- 本次模块快照 SHA-256：`bade709aaec7fb7c7c9b2725d0ccf18c0a84249dc4d6e86c01d89d45723a6382`。
- 新 PE：AMD64，16 节，timestamp=`0x6AA96B14`，SizeOfImage=`0x04770000`，checksum=`0x00F05B12`。

快照 hash 只标识这份证据。它包含加载后的地址相关内容，不被拿来要求所有玩家的内存映像 hash 相同。生产版检查构建 PE 标识与已审查指令。

证据：`../evidence/input_verification_1.3.5.json`、`../evidence/new_module_production_gate.txt`。原始模块及 DLL 不随安装包或源码包分发。

## 2. 这次确实改变了内部成员布局

| 项目 | 旧 R3 / 1.3.4 | 新 R4 / 1.3.5 |
|---|---:|---:|
| Network root RVA | `0x276F0C0` | `0x346BF98` |
| Health root RVA | `0x276C3B8` | `0x3326688` |
| SyncedHealth root RVA | `0x276C9B0` | `0x3326C98` |
| Seater root RVA | `0x276CA88` | `0x3326D78` |
| Network entity 索引表 | `+0xF19A70` | `+0xF1AEB0` |
| Network GOID 索引表 | `+0xF21A88` | `+0xF22EC8` |
| Network 描述记录区 | `+0xF31AD8` | `+0xF32F18` |
| Network Health 配置指针 | `+0xF11738` | `+0xF12B78` |
| Health entity 索引表 | `+0x28` | `+0x1030` |
| Health 描述指针数组 | `+0x40` | `+0x1048` |
| Health runtime 数组 | `+0x50` | `+0x1058` |
| Health override 索引表 | `+0x68` | `+0x1070` |
| Health override 数组 | `+0xA8` | `+0x10B0` |
| Health resource 配置表槽数 | 984 | **1002** |
| Health resource 配置记录起点 | `+0x3D80` | `+0x3EA0` |

这些值来自新版访问器、查表与同实体复制代码，不是将旧地址统一加偏移。Health 正常读取和 proxy 使用的 typed Health 枚举都已迁移，不能只更新其中一条。

确认保留的布局：24 字节 network descriptor；Seater runtime `0x40`、collection 在 `+0`；Health runtime `0x1B8`、body `+0x14`、damage words `+0x20`、zone HP `+0xF8`；38 个有效 zone；单条配置 `0x5650`，zone 起点 `0x208`、stride `0x228`、hash `+96`、max `+232`；SyncedHealth `0xC0` 记录及 16 字节复制字段记录。

新版 q2 应用代码仍独立检查 damage words，并计算 q/3 的比例，不把 q2=0 等同于轮胎终态。本轮没有改变 wheel_model 的精度或轮毂规则。

关键新版入口与摘录：network `0xFD9A40` / `0xFD9BA0`；Health getter `0x921600`；resource settings `0x507430`；override resolver `0x507920`；Seater lookup `0x4A8A00`；entering `0x63A7B0`；Health→SyncedHealth copy `0x6B1DA0`。损伤接收摘录从实际指令边界 `0x925F10` 开始；不把早期搜索窗口起点当作函数入口。

证据：`../evidence/new_build_disassembly/`、`../evidence/disassembly_index.json`。摘录只覆盖相关代码窗口，不代表整模块反编译。

生产门槛从 6 处扩为 **14 处 / 618 字节**，包含新增布局证据。实际新快照通过，实际旧快照被拒绝；逐处损坏和短读反例也被拒绝。没有向用户提供“禁用版本检查”选项。

## 3. HUD 曲率与数字朝向反馈

唯一现场描述是玩家的英文反馈：

> The curvature of the HUD will affect the orientation of the digital display, resulting in errors.

本轮没有取得该玩家的曲率数值、分辨率及故障截图，因此不把推测写成已复现的游戏内部根因。

源码中可确认的差异是：车体/轮胎/坦克外框使用 `Gui.triangle` 与 `mods/driver_hud/solid`；旧数字使用 `Gui.text` 与 `core/performance_hud/debug`。它们不使用同一绘制材质。新的兼容方案消除这项差异，而不是猜测或反向修改游戏曲率公式。

### 实现

新增 `src/hud_numbers.lua`，以预计算的简单分段字形表达 `0–9`、短横线、斜杠和空格。它与现有外框共用同一 GUI、三角形接口、材质、坐标平面及 layer。FRV body 数字按实际笔画边界居中；坦克仍沿用原有 HP/弹药布局位置。轮胎没有新增数字。

默认 `geometry_numbers=true`；关闭游戏后，在 `%APPDATA%\Arrowhead\Helldivers2\driver_hud.cfg` 设置 `geometry_numbers=false` 并重启，可恢复原游戏字体。旧配置没有此键时采用新默认值。位置配置器和其 JSON 没有改变，也不会修改游戏全局 HUD 曲率设置。

这是一个可直接使用、可以退出的渲染兼容方案。已验证它不依赖文字 API、按边界居中、继承颜色、正确清理以及复用不变图形；**尚未证明它在反馈者的 HD2 曲率设置下完全消除了原现象**。如果游戏还有额外整体曲面变换，仍需实机对照。

新增字形会增加每次重建的三角形数，但稳定帧不会重新生成图形。保留 1.3.4 的 retained GUI 机制；不能用合成接口调用次数声称实际 FPS 不变或性能提升。

## 4. 未改变的安全边界与功能

`src/frv_runtime.lua`、`src/integration_update.lua`、`src/position_config.lua` 相对 1.3.4 字节一致。配置器 PS1 和 CMD 也字节一致。坦克主炮/同轴读取、刷新逻辑、原兼容 resolver、坦克 draw 布局函数逐块一致；**坦克 text helper 有意改变，以便切换几何数字**，不能笼统声称全部坦克绘制代码未改。

Native 侧只修改构建相关的布局常量及指令门槛，没有放宽 owner/roundtrip/zone hash、预算、64-probe、唯一 proxy 或 validate。SyncedHealth 故障隔离、0.3 秒有限短读保留、车体 fallback、四轮独立容错、损毁状态优先均保留。

车体 75% 黄/50% 红、FRV 位置热加载、双语配置器、日志轮转、主炮/同轴弹药算法及其既有采样频率均保留。

证据：`../evidence/unchanged_seams.json`、`../evidence/build_report.json`。

## 5. 分阶段复查

1. **先确认旧基线。** 1.3.4 发布源码缺少完整旧 Lua suite，恢复此前的相关测试。修正测试夹具对 1.3.4 批量读取的适配：配置中间字节需要确实映射、standalone reader 需要 C、模拟适配器需按 sample 重置保护缓存。修正后旧 1.3.4 的 50 组整合、19 组 robustness、11 项适配器测试通过。这些夹具差异不称为游戏 bug。
2. **只做 native 迁移。** 新布局下同套测试通过，生产模块检查匹配新快照。没有同时修改 HUD 行为来掩盖读表错误。
3. **再做数字绘制。** 旧测试中明确检查 Gui.text 字符串的案例改在原字体模式验证；另外加入默认几何模式的独立检查。没有只删除原文本断言。
4. **故障与边界反例。** 所有 14 个指令 guard 单独损坏/短读；旧布局字段填毒值；1002 槽最后槽及 record index 1001、1001→0 wrap；index 1002 拒绝；新 override 路径；多 owner proxy 拒绝；数字/外框共用材质；窄字居中；坦克 HP/弹药不重叠；原字体开关；换车清旧图形；退出立即清除；常用分辨率和缩放。
5. **最终交付复查。** 以最终 build 载荷跑测试；关闭 JIT 重跑新兼容与 robustness 用例；从源码 ZIP 干净解压重建，逐文件比较安装包内容。结果记录在 `../evidence/validation_summary.json` 与 `../evidence/reproducibility.json`。

当前测试组：整合 50/50（其中含旧捕获 98 行数值回放）；robustness 19/19；新版布局与几何 18/18；FFI/Win32 模拟 16/16；性能调度契约 17/17；打包 24/24；日志轮转静态检查 12/12；单轮隔离静态检查 8/8；精确新快照检查 25/25。不同组可能重叠，不应相加宣传为独立实机验证场景。

## 6. 尚未验收与最小下一步

新版输入只含模块，不含运行中车辆实例堆。本次更新证明了读取结构与新版实际代码相符；**没有在新构建中重新观测实际 FRV 配置/Network schema、多人 authority 迁移或原地图生成后座 proxy 场景**。这些缺口不会被旧采集回放自动填平。全部身份/schema 安全门保留，若新实例还有差异，新日志会暴露。

最小实机确认：替换旧 DRIVER HUD 后 Purge → Deploy；正常进入自己的 FRV 驾驶位，再切回坦克检查数字和弹药。方便时以 HUD 曲率关闭/开启对照数字与外框是否一致。出现问题只需当前 `driver_hud.log`；曲率问题另附截图和曲率设置数值。现在不要求重导 DLL、模块或重复打四轮/组织多人。

若读取/保护权限被拒绝，不要关闭保护、提权或修改游戏文件来强行使用本 Mod。
