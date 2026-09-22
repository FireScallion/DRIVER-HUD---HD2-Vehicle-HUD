# DRIVER HUD — HD2 载具状态 HUD

DRIVER HUD 1.4.1

绝地潜兵 2 载具状态 HUD。需要单独安装 Bingus Shared Loader v15 / API 1。

支持内容
原版堡垒坦克：车体生命值、主炮弹药（30+1）、同轴机枪弹药，以及主炮装填提示环。
加特林／导弹坦克：车体生命值、300 发当前弹链条、下方 6 格备用弹链、两侧导弹架合计余弹，以及加特林装填提示环。加特林在左、导弹在右；原版坦克布局不改。
机枪 FRV／补给 FRV：车体生命值、各轮胎耐久及损毁表现，保留原有配色规则。
本 MOD 只显示游戏状态，不修改生命值、弹药、伤害或装填规则。

安装
1. 关闭游戏，禁用或移除所有旧 DRIVER HUD 和坦克／FRV Probe 测试版。
2. 将 DRIVER_HUD_1.4.1.zip 直接导入 Arsenal，启用 Core。
3. 单独安装并启用 Bingus Shared Loader。Arsenal 默认优先级下把 BSL 放在最底部；启用 First-Mod Priority 时按对应规则调整最终有效优先级。
4. Purge → Deploy → 启动游戏。
不要同时启用多个 DRIVER HUD 或探针。

FRV HUD位置修改
启用本 MOD 启动游戏一次后，按 Win+R，粘贴：
%APPDATA%\Arrowhead\Helldivers2
用记事本打开 frv_hud_position.txt，里面已有中英文说明。
修改 x、y、scale 后保存，约两秒可在游戏内看到效果。
x：0 为最左，1 为最右。y：0 为顶部，1 为底部。两者指 HUD 中心位置。
scale：大小范围 0.5～2.0。默认 x=0.714、y=0.90、scale=1。
保留三个设置项；缺项、越界或格式错误时，继续使用上次有效设置。
实际配置在 AppData，不在 ZIP 内。直接导入 Arsenal 的玩家也能保存设置；无需解压 MOD、修改压缩包、确认 ZIP 内文件更新，也不用重新部署或重启游戏。
首次创建 TXT 时会迁移旧 frv_hud_position.json 的有效数值。之后只编辑 TXT，旧图形工具不再控制此版本。更新 MOD 不会主动覆盖已有 TXT。

其他配置
同一 AppData 目录可放置 driver_hud.cfg；安装 ZIP 中提供模板。
默认：debug=true、offset_y=155、scale=1、alpha=0.76、perf=false、geometry_numbers=true。
offset_y、scale 控制坦克 HUD；alpha 控制两种 HUD 的透明度。
geometry_numbers=false 恢复原来的数字字体。
修改 driver_hud.cfg 后需重启游戏；FRV 位置 TXT 则无需重启。

问题反馈
请说明 MOD／游戏版本、载具、座位、房主或加入者、出问题前的操作，尽量附截图或视频。
当前日志：%APPDATA%\Arrowhead\Helldivers2\driver_hud.log
上次日志：%APPDATA%\Arrowhead\Helldivers2\driver_hud_previous.log
BSL 日志：%LOCALAPPDATA%\CowboyBingus\Helldivers2\Logs\BingusSharedLoader.log
请把完整日志打包后私信。游戏更新后可能需要兼容性修正。

项目代码采用 MIT 许可；第三方署名见 CREDITS.txt。