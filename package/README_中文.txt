DRIVER HUD 1.4.3

支持旧型堡垒坦克、加特林／导弹坦克、重机枪 FRV 和补给 FRV 的载具 HUD。需要另行安装 Bingus Shared Loader v15 / API 1。

安装
关闭游戏，停用其他版本的 DRIVER HUD 和载具探针模组。将 DRIVER_HUD_1.4.3.zip 导入 Arsenal，启用 Core，然后执行 Purge、Deploy。沿用正常工作的 BSL 配置与加载顺序，同时只启用一个 DRIVER HUD。

设置
首次启动游戏后，用记事本打开：
%APPDATA%\Arrowhead\Helldivers2\driver_hud_settings.txt

保存后约两秒生效。请保留文件内全部设置项；格式错误、缺项或数值越界时，继续使用上次有效设置。支持 UTF-8 和带 BOM 的 UTF-16。

tank_offset_y = 155  坦克 HUD 距底部偏移，参考分辨率下取值 45–500
tank_scale = 1       坦克 HUD 缩放，0.5–2
frv_x = 0.714        FRV 中心横坐标，从左侧 0 到右侧 1
frv_y = 0.9          FRV 中心纵坐标，从顶部 0 到底部 1
frv_scale = 1        FRV HUD 缩放，0.5–2
alpha = 0.76         透明度，0.1–1
font = new           几何数字字体；改为 old 使用原版游戏字体
reload_ring = true  坦克装填环形条
reticle = true      坦克中心瞄准点
weapon_cache = true 使用经校验的原生武器组件读数
debug = true        记录诊断日志
perf = false        定期记录性能摘要

统一设置文件首次创建时，会迁入已有 driver_hud.cfg、frv_hud_position.txt／.json 中的设置。之后只需修改 driver_hud_settings.txt。包内 example 文件仅供参考，不会覆盖已有设置。

显示说明
初始数据不可用时显示 --。短暂读取失败时保留最近一次有效读数。弹药下方虚线表示近期同步情况尚未确认；装填起点未知时使用虚线环。装填动画按已观测阶段估算进度，弹药数量来自实际读数。暂停和读取间断不会降低环形条亮度。离开或切换载具时清理原载具 HUD。

日志
%APPDATA%\Arrowhead\Helldivers2\driver_hud.log
上一次游戏进程的日志保留为 driver_hud_previous.log。将 debug 改为 false 可关闭诊断消息。

许可
项目自有代码使用 MIT 许可。第三方说明见 LICENSE.txt 和 CREDITS.txt。
