DRIVER HUD 1.3.4 — 坦克与 FRV HUD

功能
• 堡垒坦克：显示车体血量、主炮弹药、同轴机枪弹药与中心准星。
  主炮满弹为 31 发（30+1）。支持驾驶位与炮手位。
• 机枪 FRV、补给 FRV：显示车体血量数字与四个轮胎的内部连续耐久条。
  不显示单个轮胎的血量数字。四轮按车辆朝前时的左前、右前、左后、右后排列。
• FRV 车体轮廓、车窗轮廓及车体血量数字：高于 75% 为白色，≤75% 为黄色，≤50% 为红色。
• FRV HUD 的屏幕位置与缩放可通过随包附带的图形配置器调整。

安装（Arsenal）
1. 禁用或删除所有旧 DRIVER HUD，包括各类 FRV / Resolver / Probe 测试分支。
   同时启用多个版本会冲突，不要叠加安装。
2. 导入 DRIVER_HUD_1.3.4.zip，并启用 Core。
3. 单独安装并启用 Bingus Shared Loader v15（BSL，API 1）。本包不包含 BSL。
4. 默认加载优先级下，将 BSL 放在列表最下方并最后加载。
   若启用了 First-Mod Priority，请反向调整，确保 BSL 获得最终覆盖优先级。
5. Purge，然后 Deploy，再启动游戏。

FRV HUD位置修改
不需要手动打开或编辑 JSON 文件。

1. 将 DRIVER_HUD_1.3.4.zip 解压到任意普通文件夹。
2. 双击根目录的 CONFIGURE_FRV_HUD.cmd。
3. 在弹出的窗口中调整：
   • 水平位置
   • 垂直位置
   • 缩放
   也可以使用“向左 / 向右 / 向上 / 向下”按钮进行小步移动。
4. 点击“应用”。正在运行的 HUD 约 2 秒后会读取新设置，无需 Purge、Deploy 或重启游戏。
5. “恢复默认”会把窗口中的参数恢复为默认值；再点击“应用”即可保存。

配置器会根据 Windows 语言自动显示中文或英文，也可以在窗口右上角手动切换语言。
无需管理员权限，也不需要 VS Code、Python 或额外软件。
实际配置保存在：
  %APPDATA%\Arrowhead\Helldivers2\frv_hud_position.json
一般用户无需直接编辑这个文件。

其他配置
旧 driver_hud.cfg 仍可放在：
  %APPDATA%\Arrowhead\Helldivers2\driver_hud.cfg
默认 debug=true、offset_y=155、scale=1、alpha=0.76。
offset_y/scale 控制坦克 HUD；FRV 的位置与大小使用独立配置器；alpha 影响两套 HUD。
driver_hud.cfg 修改后重启游戏。

问题反馈
日志：
  %APPDATA%\Arrowhead\Helldivers2\driver_hud.log            当前游戏进程
  %APPDATA%\Arrowhead\Helldivers2\driver_hud_previous.log   上一次游戏进程
每次新启动 helldivers2.exe 时只轮转一次；同一游戏进程内 Mod/Lua 重载继续追加当前日志。
若问题发生在刚刚结束的上一局，请同时提交 driver_hud_previous.log。

BSL 日志：
  %LOCALAPPDATA%\CowboyBingus\Helldivers2\Logs\BingusSharedLoader.log

请说明游戏版本、车型、座位、房主/客户端、是否换过车，以及问题发生前的操作顺序。
保持 debug=true 方便排查。日志请私下提交。

开源与署名
项目自有代码沿用 MIT License；第三方材质及内容保留其原许可条件。
Source repository: https://github.com/FireScallion/DRIVER-HUD---HD2-Vehicle-HUD
第三方来源与鸣谢见 CREDITS.txt。本包不包含游戏 DLL、转储、第三方加载器或字体文件。

性能统计默认 perf=false；需要诊断时与 debug=true 一起开启并重启。详见 PERFORMANCE_说明.txt。
