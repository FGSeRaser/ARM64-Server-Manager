# Build an image (from a Termux Ubuntu)

You need a phone with Termux and a working proot-distro Ubuntu in which your server already runs (e.g. Minecraft via box64).

1. In Termux: `pkg install proot libtalloc`, run `termux-setup-storage` once.
2. Clean Ubuntu: remove everything private/unneeded (other servers, SSH keys, shell history, tokens, `/root/.bash_history`, apt caches). `make-image.sh` lists the sizes in `/root` and asks what to exclude.
3. Put your start scripts in the Ubuntu (`/usr/local/bin`). The scripts in [`image-template/usr-local-bin`](../image-template/usr-local-bin) (`Minecraft-Update`, `Minecraft-Backup`) are examples; copy them with `chmod 755` and LF line endings (`sed -i 's/\r$//' file`).
4. Run (Termux, not inside Ubuntu):
   ```
   bash make-image.sh <distro-name>
   ```
   The result is `~/storage/downloads/bedrock-full.tar.gz`.
5. Test in Termux: `mkdir ~/t && tar -xzf <file> -C ~/t && cd ~/t && sh start.sh`
6. Upload as a **GitHub Release asset** (not into the git repo) and use the asset URL in the app.

The script generates `run.sh`, `start.sh`, `update.sh`, `backup.sh` and `actions.json` in the image. To use another server, edit the generated `start.sh` command in `make-image.sh` (`exec sh "$D/run.sh" /usr/local/bin/Minecraft`).
