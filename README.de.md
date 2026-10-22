<p align="center"><img src="assets/banner.png" alt="ARM64 Server Manager"></p>

# ARM64 Server Manager

Mach aus alten (auch defekten) Android-Handys Spieleserver. Fertiges **Image** laden, **Installieren**, **Starten**. Kein Termux, kein Root, keine Kommandozeile.

🇬🇧 [English version](README.md)

## Funktionen
- Images per Klick installieren: aus einer **lokalen Datei** oder einer **GitHub-Release-URL**
- Start/Stop per Knopf, **interaktive Konsole** (Befehle an den Server oder Shell-Befehle)
- **Vordergrunddienst**, damit Server 24/7 auch bei ausgeschaltetem Display laufen
- Zusätzliche Knöpfe pro Image (z. B. *Server-Update*, *Backup*), vom Image selbst definiert
- Deutsche / englische Oberfläche und Skript-Ausgaben
- Mehrere Images nebeneinander

## So funktioniert es
Ein Image ist eine `.tar.gz` mit komplettem Ubuntu, [proot](https://proot-me.github.io/) (ohne Root), [box64](https://github.com/ptitSeb/box64) (führt x86_64-Server auf ARM64 aus) und dem Server. Die App entpackt es in ihren privaten Speicher und startet `start.sh`.

## Schnellstart (Nutzer)
1. APK von der [Releases](../../releases)-Seite installieren („Unbekannte Apps installieren“ für Browser/Dateimanager erlauben).
2. App öffnen. **Benachrichtigungen** erlauben und Akku auf **Unbeschränkt** stellen (nötig für 24/7).
3. **Image hinzufügen** → *GitHub / URL* (Release-Link des Images einfügen) oder *Lokal* (heruntergeladene `.tar.gz` wählen).
4. **Installieren** tippen und warten (mehrere hundert MB, nur einmal).
5. **Starten** tippen. In Minecraft Bedrock mit `<Handy-IP>`, Port `19132` (UDP) beitreten.

> **Ports:** Für Mitspieler von außen UDP `19132` im Router freigeben.

### GrapheneOS / Netzwerkberechtigung
GrapheneOS hat pro App einen **Netzwerk**-Schalter (Einstellungen → Apps → *ARM64 Server Manager* → Berechtigungen → **Netzwerk**). Er muss **an** sein, sonst kann der Server keinen Port öffnen („Port may be in use“ / `Permission denied`).

### Minecraft-Server updaten
Server stoppen, **Server-Update** tippen, den direkten Download-Link der neuen *Bedrock-Server für Linux* `.zip` von minecraft.net einfügen. Welten und `server.properties` bleiben erhalten.

### Backups
**Backup** legt eine `.tar.gz` der Welten im privaten App-Speicher ab (`servers/<image>/rootfs/root/backups`).

## Voraussetzungen
- Android 10+ (getestet: Pixel 9a / GrapheneOS, Android 17), ARM64-Handy, ca. 3 GB freier Speicher, mehr RAM ist besser (noch nicht gemessen)
- Handy dauerhaft am Strom (Akku-Mod oder Ladegerät)

## Selbst bauen
- App: [docs/BUILD-APP.md](docs/BUILD-APP.md)
- Eigenes Image aus einem Termux-Ubuntu: [docs/BUILD-IMAGE.md](docs/BUILD-IMAGE.md)
- Image-Format / weitere Server: [docs/IMAGE-FORMAT.md](docs/IMAGE-FORMAT.md)
- Probleme: [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)

## Rechtliches
Dieses Projekt steht in **keiner Verbindung zu Mojang oder Microsoft**. Für den Minecraft Bedrock Dedicated Server gelten EULA und Nutzungsrichtlinien.

## Roadmap
Terraria, Killing Floor (box86) u. a.; gemeinsames Basis-Image + kleine Add-ons je Server.
