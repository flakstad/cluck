#!/bin/sh

PID="$1"
HEARTBEAT_PATH="$2"
STALL_PATH="$3"
SAMPLE_PATH="$4"
LOG_PATH="$5"
STALE_MS="${6:-5000}"
POLL_MS="${7:-500}"

now_ms() {
  ruby -e 'print((Time.now.to_f * 1000).to_i)'
}

sleep_ms() {
  ruby -e "sleep(${1}.to_f / 1000.0)"
}

heartbeat_at() {
  if [ ! -f "$HEARTBEAT_PATH" ]; then
    echo "0"
    return
  fi
  sed -n 's/.*:at \([0-9][0-9]*\).*/\1/p' "$HEARTBEAT_PATH" | head -n 1
}

write_stall_report() {
  NOW="$1"
  LAST="$2"
  AGE="$3"
  HEARTBEAT_TEXT=""
  LOG_TAIL=""
  PS_LINE=""

  if [ -f "$HEARTBEAT_PATH" ]; then
    HEARTBEAT_TEXT="$(cat "$HEARTBEAT_PATH" 2>/dev/null)"
  fi

  if [ -f "$LOG_PATH" ]; then
    LOG_TAIL="$(tail -n 40 "$LOG_PATH" 2>/dev/null)"
  fi

  PS_LINE="$(ps -o pid=,ppid=,state=,etime=,%cpu=,rss=,command= -p "$PID" 2>/dev/null)"

  {
    printf "{:at %s :pid %s :last-heartbeat %s :age-ms %s :ps %s :heartbeat %s :log-tail %s}\n" \
      "$NOW" \
      "$PID" \
      "$LAST" \
      "$AGE" \
      "$(printf "%s" "$PS_LINE" | ruby -e 'print STDIN.read.dump')" \
      "$(printf "%s" "$HEARTBEAT_TEXT" | ruby -e 'print STDIN.read.dump')" \
      "$(printf "%s" "$LOG_TAIL" | ruby -e 'print STDIN.read.dump')"
  } > "$STALL_PATH"
}

if [ -z "$PID" ] || [ -z "$HEARTBEAT_PATH" ] || [ -z "$STALL_PATH" ] || [ -z "$SAMPLE_PATH" ] || [ -z "$LOG_PATH" ]; then
  exit 2
fi

while kill -0 "$PID" >/dev/null 2>&1
do
  LAST="$(heartbeat_at)"
  NOW="$(now_ms)"
  if [ -n "$LAST" ] && [ "$LAST" -gt 0 ] 2>/dev/null; then
    AGE=$((NOW - LAST))
    if [ "$AGE" -ge "$STALE_MS" ]; then
      write_stall_report "$NOW" "$LAST" "$AGE"
      if [ "${DRAW_WATCHDOG_SKIP_SAMPLE:-0}" != "1" ] && command -v sample >/dev/null 2>&1; then
        sample "$PID" 3 -file "$SAMPLE_PATH" >/dev/null 2>&1 || true
      fi
      exit 0
    fi
  fi
  sleep_ms "$POLL_MS"
done

exit 0
