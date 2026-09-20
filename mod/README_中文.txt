DRIVER HUD 1.2.1 正式版 — 中文说明

功能
在堡垒坦克驾驶位和炮手位显示车体血量、主炮弹药、同轴机枪弹药，
以及屏幕中心准星。主炮满弹为 31 发。
进入坦克后，HUD 会在车辆归属确认完成后显示。

安装前准备
需要单独安装 Bingus Shared Loader v15（BSL，API 1）。
本包不包含 BSL。HD2 HUD+ 为可选 Mod，DRIVER HUD 不依赖它。

安装步骤（Arsenal）
1. 禁用或移除所有旧版 DRIVER HUD，以及此前的测试版、整合版。
   请勿同时启用多个 DRIVER HUD 版本。
2. 在 Mod 管理器中导入 DRIVER_HUD_1.2.1.zip，并启用 Core。
3. 导入并启用 Bingus Shared Loader v15。
4. 使用默认加载优先级时，将 BSL 放在 Mod 列表最下面，最后加载。
   DRIVER HUD 与 HD2 HUD+（如果安装）都放在 BSL 上方。
   示例（从上到下）：
     HD2 HUD+（可选）
     DRIVER HUD 1.2.1
     Bingus Shared Loader v15
   如果开启了 First-Mod Priority（首个 Mod 优先），加载优先级会反转；
   请相应调整 BSL 位置，确保它具有最终生效的覆盖优先级。
5. 执行 Purge，然后 Deploy，再启动游戏。

配置（可选）
默认设置无需手动配置即可使用。
如需调整，将包内 driver_hud.cfg 放到：
  %APPDATA%\Arrowhead\Helldivers2\driver_hud.cfg
已有配置时直接编辑该文件，修改后重新启动游戏。

默认值：
  debug=true
  offset_y=155
  scale=1
  alpha=0.76

debug：是否写入诊断日志，默认开启，方便反馈问题。
offset_y：HUD 的纵向位置。
scale：HUD 缩放比例。
alpha：HUD 不透明度。
日志不会额外显示在游戏画面上。

HUD 未显示或弹药异常
先检查 BSL 是否启用、加载顺序是否正确，以及是否仍启用了旧版 DRIVER HUD。
调整后重新执行 Purge / Deploy。
进入坦克后请稍等片刻，等待车辆识别。

反馈问题时，请提供以下日志，并说明驾驶位或炮手位、是否换过坦克、
场上是否有多辆坦克，以及问题发生前的操作：
  %APPDATA%\Arrowhead\Helldivers2\driver_hud.log

BSL 加载日志：
  %LOCALAPPDATA%\CowboyBingus\Helldivers2\Logs\BingusSharedLoader.log

可以将上述路径复制到 Windows 文件资源管理器地址栏打开。
若没有日志，请检查配置中的 debug 是否为 true，以及 Mod 是否成功加载。

支持范围与署名
当前支持堡垒坦克。其他载具不在本版支持范围内。
第三方来源与署名见 CREDITS.txt。
