#!/data/data/com.termux/files/usr/bin/bash
# Baut aus deinem laufenden Termux-Ubuntu ein KOMPLETTES Image für den
# ARM64 Server Manager (Ubuntu + box64 + Bedrock + proot + Start-Skripte).
#
# Aufruf in Termux:   bash make-image.sh [distro-name]     (Standard: ubuntu)
# Ergebnis:           ~/bedrock-full.tar.gz
set -e

DISTRO="${1:-ubuntu}"
ROOTFS="$PREFIX/var/lib/proot-distro/installed-rootfs/$DISTRO"
OUT="$HOME/image-build"
if [ -d "$HOME/storage/downloads" ]; then
  RESULT="$HOME/storage/downloads/bedrock-full.tar.gz"
else
  RESULT="$HOME/bedrock-full.tar.gz"
  echo "Hinweis: ~/storage/downloads fehlt (einmal 'termux-setup-storage' ausführen)."
  echo "Das Image landet vorerst in ~"
fi

[ -d "$ROOTFS" ] || { echo "Rootfs nicht gefunden: $ROOTFS"; exit 1; }
[ -x "$PREFIX/bin/proot" ] || { echo "proot fehlt (pkg install proot)"; exit 1; }
[ -f "$PREFIX/lib/libtalloc.so.2" ] || { echo "libtalloc.so.2 fehlt (pkg install libtalloc)"; exit 1; }
[ -f "$PREFIX/libexec/proot/loader" ] || { echo "proot-loader fehlt"; exit 1; }

echo "[1/4] Aufräumen im Ubuntu (apt-Cache)..."
proot-distro login "$DISTRO" -- apt-get clean || true

echo "[2/4] Kopiere proot..."
rm -rf "$OUT"
mkdir -p "$OUT/proot/lib" "$OUT/proot/libexec"
cp "$PREFIX/bin/proot" "$OUT/proot/proot"
cp "$PREFIX/lib/libtalloc.so.2" "$OUT/proot/lib/"
cp "$PREFIX/libexec/proot/loader" "$OUT/proot/libexec/loader"
[ -f "$PREFIX/libexec/proot/loader32" ] && cp "$PREFIX/libexec/proot/loader32" "$OUT/proot/libexec/loader32"
chmod 755 "$OUT/proot/proot" "$OUT/proot/libexec/"*

echo "[3/4] Erzeuge Start-Skripte..."

# run.sh: führt einen beliebigen Befehl im Ubuntu (proot) aus
cat > "$OUT/run.sh" <<'EOF'
#!/system/bin/sh
# Aufruf: sh run.sh /usr/local/bin/Minecraft
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
EOF

cat > "$OUT/start.sh" <<'EOF'
#!/system/bin/sh
D="$(cd "$(dirname "$0")" && pwd)"
exec sh "$D/run.sh" /usr/local/bin/Minecraft
EOF

cat > "$OUT/update.sh" <<'EOF'
#!/system/bin/sh
D="$(cd "$(dirname "$0")" && pwd)"
exec sh "$D/run.sh" /usr/local/bin/Minecraft-Update "$@"
EOF

cat > "$OUT/backup.sh" <<'EOF'
#!/system/bin/sh
D="$(cd "$(dirname "$0")" && pwd)"
exec sh "$D/run.sh" /usr/local/bin/Minecraft-Backup
EOF

# Knöpfe, die die App zusätzlich anzeigt
cat > "$OUT/actions.json" <<'EOF'
[
  {"label": "Server-Update", "cmd": "sh update.sh \"$ACTION_INPUT\"", "prompt": "Direkter Download-Link der neuen Bedrock-Server .zip"},
  {"label": "Backup", "cmd": "sh backup.sh"}
]
EOF

chmod 755 "$OUT"/*.sh

echo
echo "Inhalt von /root im Ubuntu (Größe | Name):"
(cd "$ROOTFS/root" && du -sh -- * .[!.]* 2>/dev/null) || true
echo
echo "Was soll NICHT ins Image (z. B. Killing-Floor- oder Steam-Ordner)?"
read -r -p "Namen, Leerzeichen getrennt (Enter = nichts ausschließen): " -a EXCL
EXCLUDE_ARGS=()
for n in "${EXCL[@]}"; do
  EXCLUDE_ARGS+=(--exclude="$DISTRO/root/$n")
done

echo "Mache Ordner im Ubuntu lesbar (sonst bricht tar ab)..."
chmod -R u+rwX "$ROOTFS" 2>/dev/null || true

echo "[4/4] Packe Image (das dauert und braucht viel Platz)..."
tar -czf "$RESULT" \
  "${EXCLUDE_ARGS[@]}" \
  --transform "s,^$DISTRO,rootfs," \
  -C "$OUT" . \
  -C "$(dirname "$ROOTFS")" "$DISTRO"

echo "=================================================="
echo " Fertig: $RESULT"
ls -lh "$RESULT"
echo " Hochladen z. B. als GitHub-Release und die URL in der App eintragen."
echo " Test in Termux:  mkdir ~/t && tar -xzf $RESULT -C ~/t && cd ~/t && sh start.sh"
echo "=================================================="
