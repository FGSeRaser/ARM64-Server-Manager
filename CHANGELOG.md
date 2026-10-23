# Changelog

## Next (app)
- New *Restore backup* button: restores the world (optionally settings) from a backup .tar.gz into an installed image; old world is moved to before_restore_<time>. Works with existing images.

## Paper image
- New image `paper-full.tar.gz`: Paper + Geyser + Floodgate (Java and Bedrock together), Java 25, NetherNet setup button.

## v1.0.0
- First release: Flutter app with image install (local file or GitHub URL), start/stop, interactive console, foreground service for 24/7 operation, DE/EN UI.
- Image format: Ubuntu rootfs + proot + box64 + start scripts + `actions.json` buttons.
- Minecraft Bedrock image without Mojang's server: *Download / Update server* asks for the minecraft.net link.
- *Backup* exports to Download/ARM64-Server-Manager; *Settings* edits server.properties in-app.
