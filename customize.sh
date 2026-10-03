SKIPUNZIP=0

set_perm $MODPATH/service.sh 0 0 0755
set_perm $MODPATH/action.sh 0 0 0755

ui_print "****************************************"
ui_print "*        智能体 Root 指令桥 v3.0        *"
ui_print "*    Universal Agent Root Bridge       *"
ui_print "****************************************"
ui_print "- 专为各类 AI 智能体打造的通用后台执行桥"
ui_print "- 具备 FUSE 存储安全等待保护机制"
ui_print "- 具备全局单例 PID 互斥锁，杜绝 Fork 炸弹"
ui_print "- 严格拦截 reboot/rm -rf 等高危系统指令"
ui_print "- 安装完成，开机自动静默守护"
