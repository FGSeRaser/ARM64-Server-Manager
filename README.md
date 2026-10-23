<p align="center"><img src="assets/banner.png" alt="ARM64 Server Manager"></p>

# ARM64 Server Manager

Turn old (even broken-screen) Android phones into game servers. Load a ready-made **image**, tap **Install**, tap **Start**. No Termux, no root, no command line.

🇩🇪 [Deutsche Version](README.de.md)

## Downloads

| | |
|---|---|
| 📱 App (APK) | [**ARM64-Server-Manager.apk**](https://github.com/FGSeRaser/ARM64-Server-Manager/releases/download/v1.1.0/ARM64-Server-Manager-v1.1.0.apk) |
| 🟩 Bedrock image | [**bedrock-full.tar.gz**](https://github.com/FGSeRaser/ARM64-Server-Manager/releases/download/v1.0.0/bedrock-full.tar.gz) |
| ☕ Java + Bedrock (Paper) | [**paper-full.tar.gz**](https://github.com/FGSeRaser/ARM64-Server-Manager/releases/download/v1.0.0/paper-full.tar.gz) |

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
1. [**Download the APK**](https://github.com/FGSeRaser/ARM64-Server-Manager/releases/latest/download/ARM64-Server-Manager.apk) (or get it from the [Releases](../../releases) page) and install it (allow "install unknown apps" for your browser/file manager).
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

### Restoring a backup (e.g. on a new phone)
Install the image on the new phone (and download the server once), stop the server and tap **Restore backup**. Choose your backup `.tar.gz`; the app restores **only the world** (Paper backups optionally also settings and Geyser/Floodgate data). The existing world is not deleted but moved to `before_restore_<time>` inside the server folder. This works with the existing images, no new image needed. For Bedrock, `level-name` in *Settings* must match the world folder name (the app prints it).

## Images
| Image | What it is | Link name |
|---|---|---|
| Minecraft Bedrock | Official Bedrock server via box64 | [**bedrock-full.tar.gz**](https://github.com/FGSeRaser/ARM64-Server-Manager/releases/download/v1.0.0/bedrock-full.tar.gz) |
| Minecraft Java + Bedrock | Paper (Java) + Geyser/Floodgate, native ARM64 Java 25 | [**paper-full.tar.gz**](https://github.com/FGSeRaser/ARM64-Server-Manager/releases/download/v1.0.0/paper-full.tar.gz) |

Click the file name to download the image directly. In the app you can also paste the link when installing. The Mojang server is never part of an image.

> **Both images use port 19132 (UDP)**, so run only one of them at a time on the same phone.

### Paper image (Java + Bedrock together)
1. Install the image, then tap **Download / Update server** and type `latest` (or a version like `1.21.8`). This downloads Paper, Geyser and Floodgate.
2. Tap **Start** once (it stops by itself), tap **Accept EULA** ([Minecraft EULA](https://aka.ms/MinecraftEULA)), tap **Start** again and wait for `Done`; then stop it by typing `stop`.
3. Tap **Bedrock setup (Geyser)**, then **Start**. This lets Bedrock players join without a Java account and enables NetherNet (needed for Bedrock 26.60+).
4. Java players join `<phone IP>:25565`, Bedrock players `<phone IP>` port `19132`.
5. **RAM** sets the Java memory (default `2G`; use `1G`-`1536M` on phones with 4 GB).

Bedrock players have no Java account, so the normal `whitelist add` command cannot find them. The simple solution that works: switch the whitelist off (`whitelist off` in the console, and `white-list=false` under **Settings** to keep it off). Floodgate also has its own whitelist command, which I have not tested. Bedrock players need NetherNet ports: TCP and UDP `19132` plus UDP `19133` (not needed inside Tailscale).

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
