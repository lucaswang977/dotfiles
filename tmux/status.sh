#!/usr/bin/env bash
# tmux status-right 用のシステムモニタ
# 対象: CPU使用率 / メモリ使用率 / CPU温度 / ディスク使用率 / ネットワーク速度 / バッテリー / 通知 (件数)
#
# - 値が正常な項目は表示しない (自動非表示)。しきい値は下の「しきい値」で調整する
# - Linux は /proc と /sys を直接読み、macOS は標準コマンド (iostat / vm_stat / pmset など) を使う
# - 取得できない項目 (macOS の温度、バッテリーの無いPCなど) は表示しない
# - macOS 標準の bash 3.2 でも動くように書く (連想配列や EPOCHREALTIME に依存しない)

case $OSTYPE in
  linux*|darwin*) ;;
  *) exit 0 ;;
esac

# --- しきい値 -----------------------------------------------------------------
# *_WARN 以上で黄色、*_CRIT 以上で赤で表示する。*_WARN 未満 (正常) のときは非表示。
CPU_WARN=60  CPU_CRIT=85      # CPU使用率 (%)
MEM_WARN=70  MEM_CRIT=90      # メモリ使用率 (%)
TEMP_WARN=70 TEMP_CRIT=85     # CPU温度 (°C)
DISK_WARN=80 DISK_CRIT=90     # ディスク使用率 (%)
BAT_WARN=30  BAT_CRIT=15      # バッテリー残量 (%)。この値「以下」で表示する
NET_WARN=1048576              # ネットワーク速度 (bytes/s)。下り・上りのどちらかがこの値以上で表示する
NOTIFY_WARN=1                 # 通知 (件)。この件数以上のときに、赤い点と件数を表示する
# -------------------------------------------------------------------------------

state_dir="${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}"
state="$state_dir/tmux-status-cpu.$UID"
net_state="$state_dir/tmux-status-net.$UID"

isnum() { [[ $1 =~ ^[0-9]+$ ]]; }

# 値としきい値から色を $c に設定する: level <値> <表示しきい値> <危険しきい値>
# $c が空のときは正常なので表示しない
level() {
  if (( $1 >= $3 )); then c=red
  elif (( $1 >= $2 )); then c=yellow
  else c=
  fi
}

# 値が表示しきい値以上のときだけ出力に追加する: show <値> <表示しきい値> <危険しきい値> <表示文字列>
show() {
  isnum "$1" || return 0
  level "$1" "$2" "$3"
  [[ -n $c ]] || return 0
  out+="${out:+ }#[fg=$c]$4"
}

# バイト/秒を読みやすい形式 (B / K / M) にして $h に設定する
human() {
  local n=$1 t
  if (( n >= 1048576 )); then
    t=$((n * 10 / 1048576)); h="$((t / 10)).$((t % 10))M"
  elif (( n >= 1024 )); then
    h="$((n / 1024))K"
  else
    h="${n}B"
  fi
}

# ファイルの1行目を $REPLY に読む (読めなければ空にする)
readf() { REPLY=; { read -r REPLY < "$1"; } 2>/dev/null; }

# ディスク使用率 (%) を $disk に設定する: disk_usage <パス>
disk_usage() {
  local line
  line=$(df -P "$1" 2>/dev/null | tail -n 1)
  read -r _ _ _ _ disk _ <<< "$line"
  disk=${disk//[%]/}
  isnum "$disk" || disk=
}

# 生の値を集める。設定する変数 (取得できなければ空):
#   cpu mem temp disk   各使用率 (%) / 温度 (°C)
#   dev rx tx           デフォルトルートのIF名と累計バイト数
#   cap mark            バッテリー残量 (%) と充放電の印 (+ / -)
probe_linux() {
  local user nice system idle iowait irq softirq steal total idle_all
  local prev_total prev_idle dt di key val mem_total mem_avail zone hw bat
  local ifc dest flags metric mask best=

  # CPU使用率: /proc/stat の前回値との差分から算出する (sleep 不要)
  read -r _ user nice system idle iowait irq softirq steal _ < /proc/stat
  total=$((user + nice + system + idle + iowait + irq + softirq + steal))
  idle_all=$((idle + iowait))
  cpu=0
  if [[ -r $state ]]; then
    read -r prev_total prev_idle < "$state"
    if isnum "$prev_total" && isnum "$prev_idle"; then
      dt=$((total - prev_total))
      di=$((idle_all - prev_idle))
      (( dt > 0 )) && cpu=$((100 * (dt - di) / dt))
    fi
  fi
  echo "$total $idle_all" > "$state"

  # メモリ使用率: MemAvailable 基準 (キャッシュは使用済みに含めない)
  while read -r key val _; do
    case $key in
      MemTotal:) mem_total=$val ;;
      MemAvailable:) mem_avail=$val ;;
    esac
  done < /proc/meminfo
  if isnum "$mem_total" && isnum "$mem_avail" && (( mem_total > 0 )); then
    mem=$((100 * (mem_total - mem_avail) / mem_total))
  fi

  # CPU温度: thermal_zone (Intel の x86_pkg_temp / ARM の cpu-thermal) を優先し、
  # 無ければ hwmon (Intel: coretemp / AMD: k10temp, zenpower) を使う
  for zone in /sys/class/thermal/thermal_zone*; do
    readf "$zone/type"
    case $REPLY in
      x86_pkg_temp|cpu-thermal|cpu_thermal)
        readf "$zone/temp"
        if isnum "$REPLY"; then temp=$((REPLY / 1000)); break; fi ;;
    esac
  done
  if [[ -z $temp ]]; then
    for hw in /sys/class/hwmon/hwmon*; do
      readf "$hw/name"
      case $REPLY in
        coretemp|k10temp|zenpower|cpu_thermal)
          readf "$hw/temp1_input"
          if isnum "$REPLY"; then temp=$((REPLY / 1000)); break; fi ;;
      esac
    done
  fi

  disk_usage /

  # ネットワーク: デフォルトルートのインターフェースを自動検出する。
  # インターフェース名は環境ごとに違うため固定しない。デフォルトルートが複数ある場合は、
  # カーネルと同じく metric が最小のものを使う
  # (VPN 接続中はそのトンネルになり、切断されると自動で物理NICに切り替わる)
  while read -r ifc dest _ flags _ _ metric mask _; do
    [[ $dest == 00000000 && $mask == 00000000 ]] || continue
    (( 0x$flags & 1 )) || continue   # RTF_UP: 有効なルートのみ
    if [[ -z $dev ]] || (( metric < best )); then
      dev=$ifc best=$metric
    fi
  done < /proc/net/route
  if [[ -n $dev ]]; then
    readf "/sys/class/net/$dev/statistics/rx_bytes"; rx=$REPLY
    readf "/sys/class/net/$dev/statistics/tx_bytes"; tx=$REPLY
  fi

  # バッテリー: 無い環境 (デスクトップ) では何も設定しない
  for bat in /sys/class/power_supply/BAT*; do
    readf "$bat/capacity"
    isnum "$REPLY" || continue
    cap=$REPLY
    readf "$bat/status"
    case $REPLY in
      Charging) mark=+ ;;
      Discharging) mark=- ;;
    esac
    break
  done
}

probe_darwin() {
  # コマンドの出力形式 (小数点など) をロケールに左右されないようにする
  local -x LC_ALL=C
  local batt re vol

  # CPU使用率: iostat の2回目のレポート (約1秒間の平均) の idle 列 (6列目) から求める。
  # ディスクを disk0 に固定するのは、ディスクが複数あると列の位置がずれるため
  cpu=$(iostat -c 2 disk0 2>/dev/null | awk '$6 ~ /^[0-9]+$/ { idle = $6; seen = 1 } END { if (seen) print 100 - idle }')

  # メモリ使用率: (全体 - (free + inactive + speculative)) / 全体。Linux の MemAvailable に相当する考え方
  mem=$(vm_stat 2>/dev/null | awk -v total="$(sysctl -n hw.memsize 2>/dev/null)" '
    /page size of/ { ps = $8 }
    /^Pages free/ { f = $3 }
    /^Pages inactive/ { i = $3 }
    /^Pages speculative/ { s = $3 }
    END { if (total > 0 && ps > 0) printf "%d", 100 * (total - (f + i + s) * ps) / total }')

  # CPU温度: macOS には root 無しで読める標準手段が無いので表示しない

  # ディスク使用率: macOS 10.15 以降は / が読み取り専用のシステムボリュームなので Data ボリュームを見る
  vol=/
  [[ -d /System/Volumes/Data ]] && vol=/System/Volumes/Data
  disk_usage "$vol"

  # ネットワーク: デフォルトルートのIFを調べ、netstat のヘッダから Ibytes / Obytes の列を探す。
  # utun など Address 列が空のIFは列が1つ少ないので、ヘッダとの列数の差だけずらして読む
  dev=$(route -n get default 2>/dev/null | awk '/interface:/ { print $2; exit }')
  if [[ -n $dev ]]; then
    read -r rx tx <<< "$(netstat -ibn -I "$dev" 2>/dev/null | awk '
      NR == 1 { for (i = 1; i <= NF; i++) { if ($i == "Ibytes") ib = i; if ($i == "Obytes") ob = i }; hn = NF }
      NR == 2 && ib && ob { o = hn - NF; print $(ib - o), $(ob - o) }')"
  fi

  # バッテリー: 内蔵バッテリーの無い Mac では何も設定しない。
  # "discharging" は "charging" を含むので先に判定する
  batt=$(pmset -g batt 2>/dev/null)
  if [[ $batt == *InternalBattery* ]]; then
    re='([0-9]+)%'
    [[ $batt =~ $re ]] && cap=${BASH_REMATCH[1]}
    case $batt in
      *discharging*) mark=- ;;
      *"not charging"*) ;;
      *charging*) mark=+ ;;
    esac
  fi
}

cpu= mem= temp= disk= dev= rx= tx= cap= mark=
case $OSTYPE in
  linux*) probe_linux ;;
  darwin*) probe_darwin ;;
esac

out=
show "$cpu" "$CPU_WARN" "$CPU_CRIT" "CPU ${cpu}%"
show "$mem" "$MEM_WARN" "$MEM_CRIT" "MEM ${mem}%"
show "$temp" "$TEMP_WARN" "$TEMP_CRIT" "TMP ${temp}°C"
show "$disk" "$DISK_WARN" "$DISK_CRIT" "DSK ${disk}%"

# ネットワーク速度: 前回値との差分から算出する
now=${EPOCHREALTIME//[.,]/}   # マイクロ秒 (ロケールの小数点が , でも動くようにする)
isnum "$now" || now=$(( $(date +%s) * 1000000 ))   # bash 5 未満 (macOS 標準の 3.2 など) は秒単位
isnum "$rx" || rx=0
isnum "$tx" || tx=0
rx_rate=0 tx_rate=0
if [[ -r $net_state ]]; then
  read -r prev_now prev_rx prev_tx prev_dev < "$net_state"
  # デフォルトルートのIFが変わった場合 (Wi-Fi⇔有線、VPN の接続/切断など) は
  # カウンタが別物なので、そのサンプルは 0 として扱い、次回から計測する
  if isnum "$prev_now" && isnum "$prev_rx" && isnum "$prev_tx" && [[ $dev == "$prev_dev" ]]; then
    dt=$((now - prev_now))
    if (( dt > 0 )); then
      drx=$((rx - prev_rx))
      dtx=$((tx - prev_tx))
      # 同じIFでもカウンタが戻った場合 (再接続など) は 0 として扱う
      (( drx < 0 )) && drx=0
      (( dtx < 0 )) && dtx=0
      rx_rate=$((drx * 1000000 / dt))
      tx_rate=$((dtx * 1000000 / dt))
    fi
  fi
fi
echo "$now $rx $tx $dev" > "$net_state"

if (( rx_rate >= NET_WARN || tx_rate >= NET_WARN )); then
  human "$rx_rate"; down=$h
  human "$tx_rate"; up=$h
  out+="${out:+ }#[fg=white]↓${down} ↑${up}"
fi

# バッテリーは残量が少ないほど危険なので、100 からの減少量で判定する
isnum "$cap" && show $((100 - cap)) $((100 - BAT_WARN)) $((100 - BAT_CRIT)) "BAT ${cap}%${mark}"

# 通知: tmux-notify (別プロセス。tmux/notify.py) が数えた、まだ閉じられていない通知の件数を、赤い点と件数にして先頭に表示する
# 通知の内容は表示も保存もしない (件数だけ)。通知をクリックしたり消したりすると減り、
# tmux.conf の Prefix + N かバッジのクリックで、まとめて 0 に戻せる
# range=user|notify は、バッジをクリックしたと tmux.conf 側で判別するための目印 (見た目は変わらない)
notify_file="$state_dir/tmux-status-notify.$UID"
if [[ -r $notify_file ]]; then
  read -r notify_count < "$notify_file"
  if isnum "$notify_count" && (( notify_count >= NOTIFY_WARN && notify_count > 0 )); then
    (( notify_count > 99 )) && notify_count="99+"
    out="#[range=user|notify]#[fg=colour196]● ${notify_count}#[norange]${out:+ }$out"
  fi
fi

# 何も表示しないときは空を返す (末尾の空白は、続く日時との区切り)
[[ -n $out ]] && printf '%s #[default]' "$out"
exit 0
