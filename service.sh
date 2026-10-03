#!/system/bin/sh
# 智能体 Root 指令桥 Daemon v3.0 (Agent Root Bridge)
# 通用 AI 智能体后台 Root 指令桥接模块

# 1. 严格等待系统引导完成
until [ "$(getprop sys.boot_completed)" = "1" ]; do
  sleep 3
done

# 2. 等待 FUSE 用户存储就绪，杜绝在挂载前抢占 /sdcard
until [ -d "/sdcard/Download" ] && touch "/sdcard/Download/.fuse_probe_$$" 2>/dev/null; do
  sleep 3
done
rm -f "/sdcard/Download/.fuse_probe_$$" 2>/dev/null

BRIDGE=/sdcard/Download/rm_bridge
CTRL=$BRIDGE/control
OUT=$BRIDGE/output
LOG=$BRIDGE/log
LOCK=/data/local/tmp/agent_bridge.pid

# 3. 单例互斥锁（杜绝 Fork 炸弹）
if [ -f "$LOCK" ]; then
  OLD_PID=$(cat "$LOCK" 2>/dev/null)
  if [ -n "$OLD_PID" ] && [ -d "/proc/$OLD_PID" ]; then
    CMD=$(tr '\0' ' ' < "/proc/$OLD_PID/cmdline" 2>/dev/null)
    case "$CMD" in
      *agent_root_bridge*|*service.sh*)
        exit 0
        ;;
    esac
  fi
fi
echo "$$" > "$LOCK"

mkdir -p "$CTRL" "$OUT" "$LOG"
chmod 777 "$CTRL" "$OUT" "$LOG" 2>/dev/null

get_log_file() {
  echo "$LOG/audit_$(date '+%Y%m%d').log"
}

log() {
  cur_log=$(get_log_file)
  echo "[$(date '+%F %T')] $*" >> "$cur_log" 2>>"$cur_log"
  chmod 666 "$cur_log" 2>/dev/null
}

# 高危命令拦截检查（保护手机防硬重启掉临时Root、防误删系统）
is_dangerous() {
  target_file="$1"
  if grep -qiE '(^|[ ;&|])(reboot|poweroff|shutdown)($|[ ;&|])' "$target_file"; then
    echo "REBOOT_BLOCKED: Command contains reboot/poweroff/shutdown"
    return 0
  fi
  if grep -qiE '(sys\.powerctl|ctl\.restart)' "$target_file"; then
    echo "POWERCTL_BLOCKED: Command triggers power control properties"
    return 0
  fi
  if grep -qiE 'svc[[:space:]]+power' "$target_file"; then
    echo "SVC_BLOCKED: Command calls svc power reboot/shutdown"
    return 0
  fi
  if grep -qiE 'rm[[:space:]]+-[a-zA-Z]*r[a-zA-Z]*f[[:space:]]+/(system|data|vendor|apex|metadata|\*|$)' "$target_file"; then
    echo "RM_BLOCKED: Dangerous recursive deletion of system roots"
    return 0
  fi
  if grep -qiE 'dd[[:space:]]+.*of=/dev/block' "$target_file"; then
    echo "DD_BLOCKED: Dangerous direct write to block devices"
    return 0
  fi
  if grep -qiE '(^|[ ;&|])(mkfs|mke2fs|make_f2fs)($|[ ;&|])' "$target_file"; then
    echo "MKFS_BLOCKED: Dangerous filesystem format command"
    return 0
  fi
  return 1
}

clean_output() {
  file_count=$(ls -1 "$OUT" 2>/dev/null | wc -l)
  if [ "$file_count" -gt 80 ]; then
    to_delete=$((file_count - 80))
    ls -1rt "$OUT" 2>/dev/null | head -n "$to_delete" | while read -r old_file; do
      rm -f "$OUT/$old_file" 2>/dev/null
    done
  fi
}

clean_logs() {
  log_count=$(ls -1 "$LOG"/audit_*.log 2>/dev/null | wc -l)
  if [ "$log_count" -gt 3 ]; then
    to_delete=$((log_count - 3))
    ls -1 "$LOG"/audit_*.log 2>/dev/null | sort | head -n "$to_delete" | while read -r old_log; do
      rm -f "$old_log" 2>/dev/null
    done
  fi
}

run_one() {
  f="$1"
  [ -f "$f" ] || return

  id=$(basename "$f" .sh)
  # 毫秒级移出队列，避免重复执行
  work_f="/data/local/tmp/bridge_run_${id}_$$.sh"
  mv -f "$f" "$work_f" 2>/dev/null || return

  o="$OUT/$id.out"
  started=$(date '+%F %T')
  start_s=$(date +%s)
  log "START id=$id"

  block_reason=$(is_dangerous "$work_f")
  if [ $? -eq 0 ]; then
    log "SECURITY_REJECT id=$id reason=$block_reason"
    {
      echo "=== run $id [BLOCKED BY SECURITY POLICY] ==="
      echo "start: $started"
      echo "reason: $block_reason"
      echo "--- exit code: 126 ---"
    } > "$o" 2>&1
    chmod 666 "$o" 2>/dev/null
    rm -f "$work_f"
    return
  fi

  sh -x "$work_f" > "$OUT/$id.stdout" 2> "$OUT/$id.stderr"
  ec=$?
  end_s=$(date +%s)
  took=$((end_s - start_s))
  {
    echo "=== run $id ==="
    echo "start: $started"
    echo "duration: ${took}s"
    echo "--- stdout ---"
    cat "$OUT/$id.stdout" 2>/dev/null
    echo "--- stderr ---"
    cat "$OUT/$id.stderr" 2>/dev/null
    echo "--- exit code: $ec ---"
  } > "$o" 2>&1
  chmod 666 "$o" "$OUT/$id.stdout" "$OUT/$id.stderr" 2>/dev/null

  if [ "$ec" -eq 0 ]; then
    log "DONE  id=$id exit=0 took=${took}s"
  else
    log "FAIL  id=$id exit=$ec took=${took}s stderr_tail: $(tail -3 "$OUT/$id.stderr" 2>/dev/null | tr '\n' ';')"
  fi
  rm -f "$work_f"
}

log "SERVICE start (pid=$$)"

loop_tick=0
while [ true ]; do
  if [ -f "$LOCK" ]; then
    CUR_MASTER=$(cat "$LOCK" 2>/dev/null)
    if [ "$CUR_MASTER" != "$$" ]; then
      log "Master PID superseded by $CUR_MASTER, exiting $$(child)"
      exit 0
    fi
  else
    echo "$$" > "$LOCK"
  fi

  for f in "$CTRL"/*.sh; do
    [ -f "$f" ] || break
    run_one "$f"
  done

  loop_tick=$((loop_tick + 1))
  if [ "$loop_tick" -ge 60 ]; then
    clean_logs
    clean_output
    loop_tick=0
  fi

  sleep 1
done
