# Troubleshooting

| Symptom | Cause / fix |
|---|---|
| `Port [19132] may be in use` / `socket: Permission denied`, `id` in the console shows no `3003(inet)` | App has no network access. GrapheneOS: Settings → Apps → app → Permissions → **Network** on, then force-stop and reopen. Otherwise check that the APK contains `android.permission.INTERNET`. |
| `Function not implemented` (ENOSYS) from proot | The image's `run.sh` is outdated. Rebuild the image with the current `make-image.sh`. |
| `Error loading needed lib libgcc_s.so.1` (box64) | x86_64 libs missing in the rootfs; copy `/usr/x86_64-linux-gnu`. |
| Scripts fail with `$'\r': command not found` | Windows line endings: `sed -i 's/\r$//' file`. |
| Server stops after screen off | Allow notifications, set battery to *Unrestricted*, keep the foreground notification. |
| Exit 137 after a while | Possibly Android killed child processes (phantom-process limits). Keep the foreground service active; this is an unverified suspicion, not yet seen on the test devices. |
| App crashes (OutOfMemory) when picking a large image | Happened with the `file_selector` package; the app uses `file_picker` which copies the file as a stream. Keep that package. |
| Install over old APK says conflict | APK signed with a different key: uninstall first (this deletes installed images). |
| Update/Backup button says "stop server first" | Stop the server, then run the action. |
| `command not found` for a program that exists in the image (e.g. `unzip`) | proot's `--link2symlink` stores hard links as absolute symlinks into `.l2s`, which break when the rootfs is moved. `make-image.sh` converts them to real files before packing; rebuild the image with the current script. |
