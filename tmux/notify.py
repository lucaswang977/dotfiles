#!/usr/bin/env -S python3 -I
"""デスクトップ通知 (GNOME など) のうち、まだ閉じられていないものの件数を、tmux のステータスバー用にファイルへ書き出す。

使い方:
  tmux-notify           通知を監視して件数を数える (tmux.conf の run-shell から起動される)
  tmux-notify --clear   件数を 0 に戻す (いま開いている通知は、読んだものとして数えなくなる)

仕組み:
- 通知は D-Bus の org.freedesktop.Notifications.Notify の呼び出し。セッションバスを busctl で監視して読み取る
  (コピーを見るだけで、通知そのものは消費せず、GNOME の表示も変わらない)
- 通知には id が付く。Notify の返事で id を知り、「開いている通知の id の集まり」を持って、その大きさを件数にする。
  通知を中継するサービスがあって同じ呼び出しが2回見えても、返ってくる id は同じなので1件になる。
  通知の更新 (replaces_id) も同じ id なので、件数は増えない
- GNOME が通知のクリックや閉じる操作 (ActionInvoked / NotificationClosed) を知らせてきたら、その id を集まりから外す。
  なので、通知をクリックしたり消したりすると、件数が減る。バナーが時間で消えただけでは、通知は残るので減らない
- 通知の内容 (送信者や本文) は、表示も保存もしない。ファイルに書くのは件数だけ
- 常駐サービスにはしない: tmux の run-shell から起動されたときは、その tmux サーバーが終了すると、
  自分も自動で終了する。tmux の外から手動で起動したときだけ、ログアウトまで動き続ける
- 数えるのは org.freedesktop.Notifications 経由の通知 (Chrome や Slack など)。GTK アプリや Flatpak アプリが
  使う org.gtk.Notifications 経由の通知は数えない。監視を始める前からあった通知も数えない
- 監視は Linux 専用。busctl や D-Bus のセッションバスが無い環境では、何もせずに終了する
- デバッグ: TMUX_NOTIFY_DEBUG=1 を付けて起動すると、件数の変化を標準エラーに出す
"""
import fcntl
import json
import os
import shutil
import signal
import subprocess
import sys
import threading
import time

IGNORE_APPS = ()         # 数えたくないアプリ名 (例: ("Spotify",))
MAX_PENDING = 256        # 返事待ちの Notify を覚えておく最大数 (返事が来ないまま溜まらないように)
BUS_NAME = "org.freedesktop.Notifications"
DEBUG = bool(os.environ.get("TMUX_NOTIFY_DEBUG"))

UID = os.getuid()
STATE_DIR = os.environ.get("XDG_RUNTIME_DIR") or os.environ.get("TMPDIR") or "/tmp"
COUNT_FILE = f"{STATE_DIR}/tmux-status-notify.{UID}"      # status.sh が読む。件数だけが入る
LOCK_FILE = f"{STATE_DIR}/tmux-notify.lock.{UID}"         # 多重起動の防止用。動いているプロセスの PID も入る


def write_count(count):
    tmp = f"{COUNT_FILE}.tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        f.write(f"{count}\n")
    os.replace(tmp, COUNT_FILE)     # 途中の状態を読まれないよう、一時ファイルを置き換える


def refresh_tmux():
    """次の定期更新を待たずに、ステータスバーをすぐ更新させる (失敗しても無視する)。"""
    if not shutil.which("tmux"):
        return
    try:
        names = subprocess.run(["tmux", "list-clients", "-F", "#{client_name}"],
                               capture_output=True, text=True, timeout=2).stdout.split()
        for name in names:
            subprocess.run(["tmux", "refresh-client", "-S", "-t", name],
                           capture_output=True, timeout=2)
    except (OSError, subprocess.SubprocessError):
        pass


class Tracker:
    """開いている通知の id を覚えて、件数の変化をファイルに反映する。"""

    def __init__(self):
        self.pending = {}       # (呼び出し元, cookie) -> True。Notify を見たあと、返事 (= id) を待っているもの
        self.open = set()       # いま開いている通知の id
        self.written = None     # 最後に書いた件数

    def publish(self, force=False):
        count = len(self.open)
        if count == self.written and not force:
            return
        self.written = count
        write_count(count)
        if DEBUG:
            print(f"notify: count={count}", file=sys.stderr, flush=True)
        refresh_tmux()

    def clear(self, *_):
        self.open.clear()
        self.publish(force=True)

    def handle(self, line):
        """busctl が出力した1メッセージ (JSON) を処理する。"""
        try:
            msg = json.loads(line)
        except ValueError:
            return
        if not isinstance(msg, dict):
            return
        kind, member = msg.get("type"), msg.get("member")
        payload = msg.get("payload")
        data = payload.get("data") if isinstance(payload, dict) else None

        if kind == "method_call" and member == "Notify":
            try:
                app, _replaces, _icon, summary, body = data[:5]
            except (TypeError, ValueError):
                return
            if app in IGNORE_APPS or not (summary or body):
                return
            self.pending[(msg.get("sender"), msg.get("cookie"))] = True
            while len(self.pending) > MAX_PENDING:
                self.pending.pop(next(iter(self.pending)))

        elif kind == "method_return":
            # Notify の返事は、呼び出し元 (destination) と cookie (reply_cookie) で見分ける。
            # 同じ通知の返事は2つ (中継サービス経由) 来るが、id が同じなので集合では1つになる
            if self.pending.pop((msg.get("destination"), msg.get("reply_cookie")), None):
                if isinstance(data, list) and data and isinstance(data[0], int):
                    self.open.add(data[0])
                    self.publish()

        elif kind == "signal" and msg.get("interface") == BUS_NAME \
                and member in ("NotificationClosed", "ActionInvoked"):
            # クリック (ActionInvoked)、消去・アプリによる取り消し (NotificationClosed) のどちらでも外す
            if isinstance(data, list) and data and data[0] in self.open:
                self.open.discard(data[0])
                self.publish()


def server_pid():
    """tmux の run-shell から起動されたとき、その tmux サーバーの PID を返す ($TMUX は "ソケット,PID,セッション")。"""
    try:
        return int(os.environ["TMUX"].split(",")[1])
    except (KeyError, IndexError, ValueError):
        return None


def acquire_lock(timeout=3.0):
    """多重起動を防ぐロックを取り、自分の PID を書く。取れなければ None。

    tmux を再起動した直後は、前の tmux のリスナーがまだ終了処理中のことがあるので、少しだけ待つ。
    (設定の再読み込みで起動した重複分も、ここで待ったあとに何もせず終わる)
    ロックを取る前にファイルを書き換えない (動いているリスナーの PID を消さないため)。
    """
    lock = os.fdopen(os.open(LOCK_FILE, os.O_RDWR | os.O_CREAT, 0o600), "r+")
    deadline = time.monotonic() + timeout
    while True:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            lock.truncate(0)
            lock.write(str(os.getpid()))
            lock.flush()
            return lock
        except OSError:
            if time.monotonic() >= deadline:
                return None
            time.sleep(0.25)


def find_bus():
    """D-Bus のセッションバスを探す。環境変数が無いとき (tmux 経由など) は標準の場所を見る。"""
    if os.environ.get("DBUS_SESSION_BUS_ADDRESS"):
        return True
    for base in (os.environ.get("XDG_RUNTIME_DIR"), f"/run/user/{UID}"):
        if base and os.path.exists(f"{base}/bus"):
            os.environ["DBUS_SESSION_BUS_ADDRESS"] = f"unix:path={base}/bus"
            return True
    return False


def listen():
    if not sys.platform.startswith("linux") or not shutil.which("busctl") or not find_bus():
        return
    lock = acquire_lock()
    if lock is None:
        return      # すでに別のプロセスが動いている

    tracker = Tracker()
    tracker.publish(force=True)     # 前回の件数が残っていても、起動時は 0 から数え直す

    child = []
    def terminate_children():
        for p in child:
            p.terminate()
    def stop(*_):
        terminate_children()
        sys.exit(0)
    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGHUP, stop)
    signal.signal(signal.SIGUSR1, tracker.clear)       # --clear からの合図

    # tmux から起動されたときは、その tmux サーバーが終了したら、自分も終了する (常駐させない)
    pid = server_pid()
    if pid:
        def watch():
            while True:
                time.sleep(1)
                try:
                    os.kill(pid, 0)
                except ProcessLookupError:
                    terminate_children()
                    os._exit(0)
                except PermissionError:
                    pass
        threading.Thread(target=watch, daemon=True).start()

    quick_failures = 0
    while True:
        started = time.monotonic()
        # 通知サービスとのやり取りに加えて、クリックや閉じる操作の信号を見る。
        # この信号は、中継サービスではなく GNOME Shell 本体が全体に送るので、--match で別に指定する
        proc = subprocess.Popen(
            ["busctl", "--user", "monitor", "--json=short",
             "--match", f"type='signal',interface='{BUS_NAME}'", BUS_NAME],
            stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
            text=True, encoding="utf-8", errors="replace")
        child[:] = [proc]
        for line in proc.stdout:
            tracker.handle(line)
        proc.wait()
        # バスが切れたら少し待ってやり直す。接続してすぐ終了することが続くなら (セッションが
        # 終わった、バスに繋げない、など)、あきらめて終了する
        quick_failures = quick_failures + 1 if time.monotonic() - started < 3 else 0
        if quick_failures >= 5:
            return
        time.sleep(5)


def clear():
    """件数を 0 にする。動いているリスナーには合図を送って、覚えている id も空にさせる。"""
    write_count(0)
    try:
        with open(LOCK_FILE) as f:
            pid = int(f.read().strip())
        with open(f"/proc/{pid}/cmdline", "rb") as f:
            if b"notify" in f.read():       # PID が別のプロセスに使い回されていないか確かめる
                os.kill(pid, signal.SIGUSR1)
    except (OSError, ValueError):
        pass
    refresh_tmux()


def main():
    os.umask(0o077)
    if sys.argv[1:] == ["--clear"]:
        clear()
    elif len(sys.argv) == 1:
        listen()
    else:
        print(__doc__, file=sys.stderr)
        sys.exit(2)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        pass
