#!/system/bin/sh
# Aufruf: sh run.sh /usr/local/bin/Minecraft
# Startet einen Befehl im Ubuntu (proot). Die Parameter sind dem Aufruf
# nachgebaut, den proot-distro 4.38 selbst benutzt.
D="$(cd "$(dirname "$0")" && pwd)"
R="$D/rootfs"

unset LD_PRELOAD
export LD_LIBRARY_PATH="$D/proot/lib"
export PROOT_LOADER="$D/proot/libexec/loader"
export PROOT_TMP_DIR="$D/tmp"
export PROOT_L2S_DIR="$R/.l2s"
mkdir -p "$PROOT_TMP_DIR" "$PROOT_L2S_DIR" "$R/tmp" "$R/root"

BINDS="--bind=/dev --bind=/proc --bind=/sys --bind=/dev/urandom:/dev/random"
BINDS="$BINDS --bind=/proc/self/fd:/dev/fd --bind=/proc/self/fd/0:/dev/stdin"
BINDS="$BINDS --bind=/proc/self/fd/1:/dev/stdout --bind=/proc/self/fd/2:/dev/stderr"
BINDS="$BINDS --bind=$R/tmp:/dev/shm"
# Von proot-distro angelegte Ersatzdateien, falls im Image vorhanden
for f in loadavg stat uptime version vmstat; do
  [ -f "$R/proc/.$f" ] && BINDS="$BINDS --bind=$R/proc/.$f:/proc/$f"
done
[ -f "$R/proc/.sysctl_inotify_max_user_watches" ] && BINDS="$BINDS --bind=$R/proc/.sysctl_inotify_max_user_watches:/proc/sys/fs/inotify/max_user_watches"
[ -f "$R/proc/.sysctl_entry_cap_last_cap" ] && BINDS="$BINDS --bind=$R/proc/.sysctl_entry_cap_last_cap:/proc/sys/kernel/cap_last_cap"
[ -e "$R/sys/.empty" ] && BINDS="$BINDS --bind=$R/sys/.empty:/sys/fs/selinux"

exec "$D/proot/proot" $BINDS \
  -L '--kernel-release=\Linux\localhost\6.17.0-PRoot-Distro\#1 SMP PREEMPT_DYNAMIC Fri, 10 Oct 2025 00:00:00 +0000\aarch64\localdomain\-1\' \
  --sysvipc --link2symlink --kill-on-exit --cwd=/root --rootfs="$R" --change-id=0:0 \
  /usr/bin/env -i HOME=/root USER=root TERM=xterm-256color LANG=C.UTF-8 TMPDIR=/tmp APP_LANG="${APP_LANG:-de}" \
  PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/local/games:/usr/games \
  "$@"
