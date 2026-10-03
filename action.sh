#!/system/bin/sh
# 智能体 Root 指令桥 Action v3.0
BRIDGE=/sdcard/Download/rm_bridge
CTRL=$BRIDGE/control
OUT=$BRIDGE/output
LOG=$BRIDGE/log
LOCK=/data/local/tmp/agent_bridge.pid

echo "======================================"
echo "    智能体 Root 指令桥 v3.0 (Agent Bridge)"
echo "======================================"

if [ -f "$LOCK" ]; then
  PID=$(cat "$LOCK" 2>/dev/null)
  if [ -n "$PID" ] && [ -d "/proc/$PID" ]; then
    echo "✓ 桥接守护进程活跃中 (PID: $PID)"
  else
    echo "! 守护进程未启动，正在启动..."
    nohup sh /data/adb/modules/agent_root_bridge/service.sh >/dev/null 2>&1 &
    sleep 1
    NEW_PID=$(cat "$LOCK" 2>/dev/null)
    echo "✓ 已拉起守护进程 (PID: ${NEW_PID:-'后台'})"
  fi
else
  echo "! 正在拉起守护进程..."
  nohup sh /data/adb/modules/agent_root_bridge/service.sh >/dev/null 2>&1 &
  sleep 1
  NEW_PID=$(cat "$LOCK" 2>/dev/null)
  echo "✓ 已拉起守护进程 (PID: ${NEW_PID:-'后台'})"
fi

PENDING=$(ls -1 "$CTRL"/*.sh 2>/dev/null | wc -l)
echo "• 待执行队列: ${PENDING} 个任务"

echo "• 最近执行审计记录:"
LATEST_LOG=$(ls -t "$LOG"/audit_*.log 2>/dev/null | head -1)
if [ -n "$LATEST_LOG" ]; then
  tail -n 5 "$LATEST_LOG" 2>/dev/null
else
  echo "  (暂无今日日志)"
fi
echo "======================================"
