# Image format

```
image.tar.gz
├── proot/            proot binary, lib/libtalloc.so.2, libexec/loader (+loader32)
├── rootfs/           Ubuntu userland (+ box64, server files)
├── run.sh            runs any command inside the rootfs via proot
├── start.sh          started by the app's Start button
├── update.sh, backup.sh   optional helpers
└── actions.json      extra buttons
```
The app extracts the archive to `<app files>/servers/<id>/`, runs `chmod 755 start.sh` and executes `sh start.sh` with stdin/stdout connected to the console. Typing `stop` is sent to stdin; after 20 s without exit the process is killed.

## actions.json
```json
[
  {"label": "Settings", "edit": "rootfs/root/minecraft-server/server.properties"},
  {"label": "Backup", "cmd": "sh backup.sh", "export": "rootfs/root/backups"},
  {"label": "Download / Update server", "cmd": "sh update.sh \"$ACTION_INPUT\"",
   "prompt": "Direct download link of the new server .zip"}
]
```
- `export` (optional): relative folder (inside the image folder). After the command succeeds the app copies new files from it to `Download/ARM64-Server-Manager/<image>/` (fallback: app storage).
- `edit` (instead of `cmd`): relative path of a `key=value` file; the app opens a form editor (switches, dropdowns, text fields) and keeps comments.
- `prompt` (optional): the app shows a dialog; the text is available as `$ACTION_INPUT`.
- `$APP_LANG` (`de`/`en`) is passed to scripts so they can localize their output (`run.sh` forwards it into the rootfs).
- Actions are only available while the server is stopped.

## Rules for images
- Required: `start.sh`; the `proot/` folder layout above.
- Do not include private data (keys, history, personal worlds) or other people's non-redistributable files.
- Planned: shared base image + small add-ons (see roadmap).
