<p align="center"><img src="assets/banner.png" alt="ARM64 Server Manager"></p>

# ARM64 Server Manager

Turn old (even broken-screen) Android phones into game servers. Load a ready-made **image**, tap **Install**, tap **Start**. No Termux, no root, no command line.

🇩🇪 [Deutsche Version](README.de.md)

## Features
- One-tap install of server images from a **local file** or a **GitHub release URL**
- Start / stop with buttons, **interactive console** (send commands to the server or run shell commands)
- **Foreground service** so servers keep running 24/7 with the screen off
- Extra buttons per image (e.g. *Download / Update server*, *Backup*) defined by the image itself
- German / English UI and script output
- Several images side by side

## How it works
An image is a single `.tar.gz` containing a complete Ubuntu userland, [proot](https://proot-me.github.io/) (no root needed), [box64](https://github.com/ptitSeb/box64) (runs x86_64 servers on ARM64) and the server itself. The app unpacks it into its private storage and runs `start.sh`.

## Quick start (users)
1. Install the APK from the [Releases](../../releases) page (allow "install unknown apps" for your browser/file manager).
2. Open the app. When asked, allow **notifications** and **battery: unrestricted** (needed for 24/7).
3. Add an image: tap **Add image** → choose *GitHub / URL* (paste the release link of the image) or *Local* (pick the downloaded `.tar.gz`).
4. Tap **Install**, wait until it finishes (several hundred MB, one time).
5. **Download the server (once):** open https://www.minecraft.net/en-us/download/server/bedrock, accept the EULA and copy the link of **Ubuntu (Linux)** (right-click the button → *Copy link address*; it ends in `.zip`). In the app tap **Download / Update server** and paste the link.
6. Tap **Start**. Join with Minecraft Bedrock via `<phone IP>`, port `19132` (UDP).

> **Ports:** forward UDP `19132` on your router if friends should join from outside your network.

### GrapheneOS / network permission
GrapheneOS has a per-app **Network** switch (Settings → Apps → *ARM64 Server Manager* → Permissions → **Network**). It must be **on**, otherwise the server cannot open any port ("Port may be in use" / `Permission denied`).

### Updating the Minecraft server
Stop the server, tap **Download / Update server**, paste the link of the new *Bedrock server for Linux* `.zip` from minecraft.net. Worlds and `server.properties` are kept.

### Server settings
Tap **Settings** to edit `server.properties` (game mode, difficulty, max players, world name …) with simple switches and fields. The file exists after the first server start. Restart the server afterwards.

### Backups
Stop the server and tap **Backup**. The app packs the worlds into a `.tar.gz` and copies it to **`Download/ARM64-Server-Manager/<image>/`** on your phone, so you can copy it to a PC or cloud easily. If the app is not allowed to write there, grant *Files / Storage* access for the app (Settings → Apps → ARM64 Server Manager → Permissions); until then the copy goes to the app's own folder (`Android/data/<package>/files/backups`, reachable via USB cable on a PC). The 5 newest backups are also kept inside the app.

### Playing with friends over the internet: Tailscale
Instead of opening ports on your router you can use [Tailscale](https://tailscale.com/download) (free for personal use, apps for Android, iOS, Windows, macOS and Linux):
1. Install Tailscale on the **server phone** and sign in. Note its Tailscale address (`100.x.y.z`, shown in the Tailscale app).
2. Let your friends reach it: either invite them to your tailnet, or use [node sharing](https://tailscale.com/kb/1084/sharing) to share only the server phone with their own Tailscale account.
3. Friends install Tailscale on their phone/PC and sign in.
4. In Minecraft Bedrock (Android, iOS, Windows) add a server with the Tailscale address of the server phone and port `19132`.

Notes: Game consoles cannot run Tailscale, and Bedrock on consoles has no free "add server" field, so this works for phone/PC players. On GrapheneOS the per-app **Network** switch must also be on for Tailscale. I have not tested this setup myself yet; if it does not work for you, please open an issue.

## Requirements
- Android 10+ (tested: Pixel 9a / GrapheneOS, Android 17), ARM64 phone, ~3 GB free storage, more RAM is better (not benchmarked yet)
- Phone permanently on power (battery mod or charger)

## Build it yourself
- App: [docs/BUILD-APP.md](docs/BUILD-APP.md)
- Make your own image from a Termux Ubuntu: [docs/BUILD-IMAGE.md](docs/BUILD-IMAGE.md)
- Image format / add more servers: [docs/IMAGE-FORMAT.md](docs/IMAGE-FORMAT.md)
- Problems: [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)

## Legal
This project is **not affiliated with Mojang or Microsoft**. The Minecraft Bedrock Dedicated Server is subject to the Minecraft EULA and Usage Guidelines; the image therefore does **not** contain it: every user downloads it from minecraft.net themselves. Ubuntu, box64 (MIT) and proot (GPL-2.0) have their own licenses; if you distribute proot binaries you must make its source available (https://github.com/proot-me/proot). The app code is MIT licensed, see [LICENSE](LICENSE). Nothing here is legal advice.

## Roadmap
Terraria, Killing Floor (box86) and others; shared base image + small add-on packages per server.
