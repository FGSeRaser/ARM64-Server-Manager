<p align="center"><img src="assets/banner.png" alt="ARM64 Server Manager"></p>

# ARM64 Server Manager

Turn old (even broken-screen) Android phones into game servers. Load a ready-made **image**, tap **Install**, tap **Start**. No Termux, no root, no command line.

🇩🇪 [Deutsche Version](README.de.md)

## Features
- One-tap install of server images from a **local file** or a **GitHub release URL**
- Start / stop with buttons, **interactive console** (send commands to the server or run shell commands)
- **Foreground service** so servers keep running 24/7 with the screen off
- Extra buttons per image (e.g. *Server-Update*, *Backup*) defined by the image itself
- German / English UI and script output
- Several images side by side

## How it works
An image is a single `.tar.gz` containing a complete Ubuntu userland, [proot](https://proot-me.github.io/) (no root needed), [box64](https://github.com/ptitSeb/box64) (runs x86_64 servers on ARM64) and the server itself. The app unpacks it into its private storage and runs `start.sh`.

## Quick start (users)
1. Install the APK from the [Releases](../../releases) page (allow "install unknown apps" for your browser/file manager).
2. Open the app. When asked, allow **notifications** and **battery: unrestricted** (needed for 24/7).
3. Add an image: tap **Add image** → choose *GitHub / URL* (paste the release link of the image) or *Local* (pick the downloaded `.tar.gz`).
4. Tap **Install**, wait until it finishes (several hundred MB, one time).
5. Tap **Start**. Join with Minecraft Bedrock via `<phone IP>`, port `19132` (UDP).

> **Ports:** forward UDP `19132` on your router if friends should join from outside your network.

### GrapheneOS / network permission
GrapheneOS has a per-app **Network** switch (Settings → Apps → *ARM64 Server Manager* → Permissions → **Network**). It must be **on**, otherwise the server cannot open any port ("Port may be in use" / `Permission denied`).

### Updating the Minecraft server
Stop the server, tap **Server-Update**, paste the direct download link of the new *Bedrock server for Linux* `.zip` from minecraft.net. Worlds and `server.properties` are kept.

### Backups
**Backup** stores a `.tar.gz` of the worlds in the app's private storage (`servers/<image>/rootfs/root/backups`).

## Requirements
- Android 10+ (tested: Pixel 9a / GrapheneOS, Android 17), ARM64 phone, ~3 GB free storage, more RAM is better (not benchmarked yet)
- Phone permanently on power (battery mod or charger)

## Build it yourself
- App: [docs/BUILD-APP.md](docs/BUILD-APP.md)
- Make your own image from a Termux Ubuntu: [docs/BUILD-IMAGE.md](docs/BUILD-IMAGE.md)
- Image format / add more servers: [docs/IMAGE-FORMAT.md](docs/IMAGE-FORMAT.md)
- Problems: [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)

## Legal
This project is **not affiliated with Mojang or Microsoft**. The Minecraft Bedrock Dedicated Server is subject to the Minecraft EULA and Usage Guidelines; check whether you may redistribute it before putting it into a public image. Ubuntu, box64 (MIT) and proot (GPL-2.0) have their own licenses; if you distribute proot binaries you must make its source available (https://github.com/proot-me/proot). The app code is MIT licensed, see [LICENSE](LICENSE). Nothing here is legal advice.

## Roadmap
Terraria, Killing Floor (box86) and others; shared base image + small add-on packages per server.
