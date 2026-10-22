// ARM64 Server Manager
//
// Konvention für Images (tar.gz / tgz / tar):
//   Im Archiv-Root muss eine Datei "start.sh" liegen. Die App startet sie mit
//   /system/bin/sh im entpackten Image-Ordner. Beispiel:
//
//     #!/system/bin/sh
//     cd "$(dirname "$0")/bedrock"
//     export BOX64_LD_LIBRARY_PATH="$PWD/lib64"
//     exec ../box64/box64 ./bedrock_server
//
//   "exec" ist wichtig, damit "Stop" den Server wirklich erreicht.
//
// pubspec.yaml -> dependencies:
//   file_picker: ^13.1.0
//   path_provider: ^2.1.0
//   flutter_foreground_task: ^8.0.0
//
// AndroidManifest.xml (außerhalb von <application>):
//   <uses-permission android:name="android.permission.INTERNET"/>
//   <uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
//   <uses-permission android:name="android.permission.WAKE_LOCK"/>
//   <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
//   <uses-permission android:name="android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS"/>
//   (den <service>-Eintrag bringt das Plugin selbst mit)
//
// android/app/build.gradle: targetSdkVersion 28
//   (ab Android 10 darf eine App mit targetSdk >= 29 keine Dateien aus ihrem
//    Datenordner ausführen)

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:path_provider/path_provider.dart';

void main() => runApp(const ServerManagerApp());

const _bg = Color(0xFF1E1E2E);
const _surface = Color(0xFF313244);
const _surfaceDark = Color(0xFF181825);
const _console = Color(0xFF11111B);
const _border = Color(0xFF45475A);
const _green = Color(0xFFA6E3A1);
const _blue = Color(0xFF89B4FA);
const _orange = Color(0xFFFAB387);
const _red = Color(0xFFF38BA8);
const _grey = Color(0xFF9399B2);

const _defaultBedrockUrl =
    'https://github.com/YOUR-GITHUB-NAME/ARM64-Server-Manager/releases/download/v1.0/bedrock.tar.gz';

class ServerManagerApp extends StatelessWidget {
  const ServerManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ARM64 Server Manager',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: _bg,
        cardColor: _surface,
        primaryColor: _blue,
      ),
      home: const DashboardScreen(),
    );
  }
}

/// Ein Eintrag in der Image-Liste.
class ServerImage {
  String id;
  String name;
  String sourceType; // 'url' oder 'local'
  String source; // URL oder lokaler Dateipfad
  bool installed;

  ServerImage({
    required this.id,
    required this.name,
    required this.sourceType,
    required this.source,
    this.installed = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'sourceType': sourceType,
        'source': source,
        'installed': installed,
      };

  factory ServerImage.fromJson(Map<String, dynamic> j) => ServerImage(
        id: j['id'] as String,
        name: j['name'] as String? ?? 'Server',
        sourceType: j['sourceType'] as String? ?? 'url',
        source: j['source'] as String? ?? '',
        installed: j['installed'] as bool? ?? false,
      );
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool isDe = true;
  bool ready = false;
  int tab = 0;

  late Directory baseDir;
  final List<ServerImage> images = [];

  /// Laufende Prozesse (Image-ID -> Prozess)
  final Map<String, Process> running = {};

  /// Beschäftigte Images (Image-ID -> Fortschritt 0..1, null = unbestimmt)
  final Map<String, double?> busy = {};

  /// Aktionen aus actions.json des Images (Image-ID -> [{label, cmd}])
  final Map<String, List<Map<String, String>>> actions = {};

  /// Images, für die gerade eine Aktion läuft
  final Set<String> taskBusy = {};

  final List<String> logLines = [];
  final ScrollController logScroll = ScrollController();
  final TextEditingController cmdController = TextEditingController();
  String? consoleTarget;
  String shellCwd = '';

  String tr(String de, String en) => isDe ? de : en;

  void refresh() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    init();
  }

  @override
  void dispose() {
    // Laufende Server werden bewusst NICHT beendet: der Foreground-Service
    // hält den App-Prozess am Leben.
    logScroll.dispose();
    cmdController.dispose();
    super.dispose();
  }

  // --------------------------------------------------- Foreground-Service

  bool permsAsked = false;

  /// Meldung vom Datei-Auswählen (wird im Dialog angezeigt)
  String pickMessage = '';

  void initForegroundTask() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'server_manager_running',
        channelName: 'Server Manager',
        channelDescription: 'Hält die Server im Hintergrund am Laufen',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        autoRunOnBoot: false,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  /// Einmalig: Benachrichtigung erlauben + Akku-Optimierung abschalten,
  /// sonst killt Android den Server nach einer Weile.
  Future<void> requestBackgroundPermissions() async {
    if (permsAsked) return;
    permsAsked = true;
    try {
      final notif = await FlutterForegroundTask.checkNotificationPermission();
      if (notif != NotificationPermission.granted) {
        await FlutterForegroundTask.requestNotificationPermission();
      }
      if (!await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
        await FlutterForegroundTask.requestIgnoreBatteryOptimization();
      }
    } catch (e) {
      log('⚠️ ${tr('Berechtigungen', 'Permissions')}: $e');
    }
  }

  /// Service läuft genau dann, wenn mindestens ein Server läuft.
  Future<void> syncService() async {
    try {
      final active = await FlutterForegroundTask.isRunningService;
      if (running.isEmpty) {
        if (active) await FlutterForegroundTask.stopService();
        return;
      }
      final names = running.keys.map((id) => byId(id)?.name ?? id).join(', ');
      final text = '${tr('Läuft', 'Running')}: $names';
      if (active) {
        await FlutterForegroundTask.updateService(
          notificationTitle: 'ARM64 Server Manager',
          notificationText: text,
        );
      } else {
        await FlutterForegroundTask.startService(
          serviceId: 256,
          notificationTitle: 'ARM64 Server Manager',
          notificationText: text,
        );
      }
    } catch (e) {
      log('⚠️ Foreground-Service: $e');
    }
  }

  // ---------------------------------------------------------------- Setup

  Future<void> init() async {
    initForegroundTask();
    baseDir = await getApplicationDocumentsDirectory();
    final cfg = File('${baseDir.path}/config.json');
    if (await cfg.exists()) {
      try {
        final data = jsonDecode(await cfg.readAsString()) as Map<String, dynamic>;
        isDe = data['isDe'] as bool? ?? true;
        for (final e in (data['images'] as List? ?? [])) {
          images.add(ServerImage.fromJson(e as Map<String, dynamic>));
        }
      } catch (_) {
        // kaputte Config ignorieren
      }
    }
    if (images.isEmpty) {
      images.add(ServerImage(
        id: 'bedrock',
        name: 'Minecraft Bedrock',
        sourceType: 'url',
        source: _defaultBedrockUrl,
      ));
    }
    for (final img in images) {
      img.installed = img.installed && Directory(serverPath(img)).existsSync();
      if (img.installed) loadActions(img);
    }
    ready = true;
    log(tr('Bereit. Installiere ein Image und starte es mit einem Klick.',
        'Ready. Install an image and start it with one tap.'));
    refresh();
  }

  String serverPath(ServerImage img) => '${baseDir.path}/servers/${img.id}';

  Future<void> saveConfig() async {
    try {
      await File('${baseDir.path}/config.json').writeAsString(jsonEncode({
        'isDe': isDe,
        'images': images.map((e) => e.toJson()).toList(),
      }));
    } catch (e) {
      log('⚠️ Config konnte nicht gespeichert werden: $e');
    }
  }

  ServerImage? byId(String? id) {
    if (id == null) return null;
    for (final i in images) {
      if (i.id == id) return i;
    }
    return null;
  }

  void log(String text) {
    if (!mounted) return;
    setState(() {
      logLines.addAll(text.split('\n'));
      if (logLines.length > 2000) {
        logLines.removeRange(0, logLines.length - 2000);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (logScroll.hasClients) {
        logScroll.jumpTo(logScroll.position.maxScrollExtent);
      }
    });
  }

  // ---------------------------------------------------------- Datei wählen

  Future<String?> pickArchive() async {
    try {
      pickMessage = '';
      // file_picker >= 12: statischer Aufruf, liefert eine einzelne PlatformFile
      final PlatformFile? file = await FilePicker.pickFile(type: FileType.any);
      if (file == null) return null;

      final name = file.name;
      final pickedPath = file.path; // kann null sein, dann wird gestreamt
      final lower = name.toLowerCase();
      if (!(lower.endsWith('.tar.gz') || lower.endsWith('.tgz') || lower.endsWith('.tar'))) {
        pickMessage = tr('⚠️ „$name“ ist keine .tar.gz, .tgz oder .tar Datei.',
            '⚠️ "$name" is not a .tar.gz, .tgz or .tar file.');
        log(pickMessage);
        return null;
      }

      // Datei dauerhaft in den App-Speicher kopieren.
      log(tr('📂 Kopiere Datei in den App-Speicher…', '📂 Copying file into app storage…'));
      final dir = Directory('${baseDir.path}/images');
      await dir.create(recursive: true);
      final dest = '${dir.path}/${DateTime.now().millisecondsSinceEpoch}_$name';
      if (pickedPath != null && File(pickedPath).existsSync()) {
        // Direkter Dateipfad: nativ kopieren (kein RAM nötig)
        await File(pickedPath).copy(dest);
        // Nur temporäre Kopien im Cache löschen, nie die Originaldatei des Nutzers
        if (pickedPath.contains('/cache/')) {
          try {
            await File(pickedPath).delete();
          } catch (_) {}
        }
      } else {
        // Kein Pfad (z. B. content://): in Stücken streamen
        final sink = File(dest).openWrite();
        try {
          await sink.addStream(file.readAsByteStream());
        } finally {
          await sink.close();
        }
      }
      final size = File(dest).existsSync() ? File(dest).lengthSync() : 0;
      if (size == 0) {
        pickMessage = tr('❌ Die Datei konnte nicht kopiert werden (0 Bytes).',
            '❌ The file could not be copied (0 bytes).');
        log(pickMessage);
        return null;
      }
      log('✅ ${tr('Datei übernommen', 'File imported')}: $name (${(size / 1048576).toStringAsFixed(1)} MB)');
      return dest;
    } catch (e) {
      pickMessage = '❌ ${tr('Fehler beim Datei-Picker', 'File picker error')}: $e';
      log(pickMessage);
      return null;
    }
  }

  Future<void> deleteManagedArchive(String path) async {
    if (path.startsWith('${baseDir.path}/images/')) {
      try {
        await File(path).delete();
      } catch (_) {}
    }
  }

  // ------------------------------------------------------------ Installation

  Future<void> download(ServerImage img, String target) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 20);
    try {
      final req = await client.getUrl(Uri.parse(img.source));
      req.followRedirects = true;
      req.maxRedirects = 8;
      final resp = await req.close();
      if (resp.statusCode != 200) {
        throw HttpException('HTTP ${resp.statusCode}');
      }
      final total = resp.contentLength;
      final sink = File(target).openWrite();
      var received = 0;
      var lastPct = -1;
      try {
        await for (final chunk in resp) {
          sink.add(chunk);
          received += chunk.length;
          if (total > 0) {
            final pct = received * 100 ~/ total;
            if (pct != lastPct) {
              lastPct = pct;
              busy[img.id] = received / total;
              refresh();
            }
          }
        }
      } finally {
        await sink.close();
      }
      log('✅ ${tr('Download fertig', 'Download finished')} (${(received / 1048576).toStringAsFixed(1)} MB)');
    } finally {
      client.close();
    }
  }

  /// Entpackt mit dem System-tar von Android (behält Symlinks & Rechte,
  /// braucht kaum RAM – wichtig bei großen Images).
  Future<bool> extractArchive(String archive, String target) async {
    final flag = archive.toLowerCase().endsWith('.tar') ? '-xf' : '-xzf';
    for (final exe in ['/system/bin/tar', 'tar']) {
      try {
        final r = await Process.run(exe, [flag, archive, '-C', target]);
        final err = '${r.stderr}'.trim();
        if (err.isNotEmpty) {
          log(err.length > 1500 ? '${err.substring(0, 1500)}…' : err);
        }
        return r.exitCode == 0;
      } on ProcessException {
        continue;
      }
    }
    log('❌ ${tr('Kein tar auf diesem Gerät gefunden.', 'No tar found on this device.')}');
    return false;
  }

  Future<void> install(ServerImage img) async {
    if (busy.containsKey(img.id) || running.containsKey(img.id)) return;
    busy[img.id] = null;
    refresh();
    log('🚀 ${tr('Installiere', 'Installing')} ${img.name}…');

    String? tempArchive;
    try {
      String archivePath;
      if (img.sourceType == 'local') {
        if (!File(img.source).existsSync()) {
          log('❌ ${tr('Lokale Datei nicht gefunden. Bitte Quelle neu wählen.', 'Local file not found. Please choose the source again.')}');
          return;
        }
        archivePath = img.source;
      } else {
        if (!img.source.startsWith('http')) {
          log('❌ ${tr('Ungültige URL.', 'Invalid URL.')}');
          return;
        }
        log('🌐 ${tr('Lade herunter', 'Downloading')}:\n${img.source}');
        tempArchive = '${baseDir.path}/tmp_${img.id}.tar.gz';
        await download(img, tempArchive);
        archivePath = tempArchive;
      }

      // Bestehende Daten (z. B. Welten) bleiben erhalten: es wird nur drübergeschrieben.
      final dir = Directory(serverPath(img));
      await dir.create(recursive: true);

      busy[img.id] = null;
      refresh();
      log('📦 ${tr('Entpacke… (kann dauern)', 'Extracting… (may take a while)')}');
      final ok = await extractArchive(archivePath, dir.path);

      final startSh = File('${dir.path}/start.sh');
      if (startSh.existsSync()) {
        try {
          await Process.run('/system/bin/chmod', ['755', startSh.path]);
        } catch (_) {}
      }

      if (!ok && !startSh.existsSync()) {
        log('❌ ${tr('Entpacken fehlgeschlagen.', 'Extraction failed.')}');
        return;
      }
      if (!ok) {
        log('⚠️ ${tr('Entpacken mit Warnungen beendet (siehe oben).', 'Extraction finished with warnings (see above).')}');
      }
      if (!startSh.existsSync()) {
        log('⚠️ ${tr('Im Image fehlt start.sh – ohne diese Datei kann der Server nicht gestartet werden.', 'The image has no start.sh – the server cannot be started without it.')}');
      }

      img.installed = true;
      loadActions(img);
      await saveConfig();
      log('🎉 ${tr('Installation abgeschlossen', 'Installation complete')}:\n${dir.path}');
    } catch (e) {
      log('❌ ${tr('Fehler bei der Installation', 'Installation error')}:\n$e');
    } finally {
      if (tempArchive != null) {
        try {
          await File(tempArchive).delete();
        } catch (_) {}
      }
      busy.remove(img.id);
      refresh();
    }
  }

  Future<void> uninstall(ServerImage img) async {
    if (running.containsKey(img.id) || busy.containsKey(img.id)) return;
    busy[img.id] = null;
    refresh();
    try {
      final dir = Directory(serverPath(img));
      if (await dir.exists()) await dir.delete(recursive: true);
      img.installed = false;
      actions.remove(img.id);
      await saveConfig();
      log('🗑️ ${img.name} ${tr('deinstalliert.', 'uninstalled.')}');
    } catch (e) {
      log('❌ $e');
    } finally {
      busy.remove(img.id);
      refresh();
    }
  }

  // --------------------------------------------------------- Start / Stop

  Future<void> startServer(ServerImage img) async {
    if (running.containsKey(img.id) || busy.containsKey(img.id)) return;
    final dir = serverPath(img);
    if (!File('$dir/start.sh').existsSync()) {
      log('❌ ${tr('start.sh fehlt im Image-Ordner.', 'start.sh is missing in the image folder.')}');
      return;
    }
    try {
      await requestBackgroundPermissions();
      await Directory('$dir/tmp').create(recursive: true);
      log('▶️ ${tr('Starte', 'Starting')} ${img.name}…');
      final p = await Process.start(
        '/system/bin/sh',
        ['start.sh'],
        workingDirectory: dir,
        environment: {'HOME': dir, 'TMPDIR': '$dir/tmp', 'SERVER_DIR': dir, 'APP_LANG': isDe ? 'de' : 'en'},
      );
      p.stdin.done.catchError((_) {});
      running[img.id] = p;
      consoleTarget ??= img.id;
      refresh();
      await syncService();

      final prefix = images.length > 1 ? '[${img.name}] ' : '';
      const dec = Utf8Decoder(allowMalformed: true);
      p.stdout
          .transform(dec)
          .transform(const LineSplitter())
          .listen((l) => log('$prefix$l'));
      p.stderr
          .transform(dec)
          .transform(const LineSplitter())
          .listen((l) => log('$prefix$l'));
      p.exitCode.then((code) {
        running.remove(img.id);
        log('⏹️ ${img.name} ${tr('beendet', 'exited')} (Exit $code)');
        refresh();
        syncService();
      });
    } catch (e) {
      log('❌ ${tr('Start fehlgeschlagen', 'Start failed')}: $e');
    }
  }

  void stopServer(ServerImage img) {
    final p = running[img.id];
    if (p == null) return;
    log('⏹️ ${tr('Sende "stop"…', 'Sending "stop"…')}');
    try {
      p.stdin.writeln('stop');
    } catch (_) {}
    Future.delayed(const Duration(seconds: 20), () {
      if (running[img.id] == p) {
        p.kill(ProcessSignal.sigkill);
        log('⚠️ ${tr('Server reagiert nicht – beendet erzwungen.', 'Server not responding – killed.')}');
      }
    });
  }

  void killServer(ServerImage img) {
    final p = running[img.id];
    if (p == null) return;
    p.kill(ProcessSignal.sigkill);
    log('☠️ ${img.name} ${tr('hart beendet.', 'killed.')}');
  }

  // --------------------------------------------------------------- Konsole

  /// Liest actions.json aus dem Image-Ordner, Format:
  /// [{"label": "Backup", "cmd": "sh backup.sh"}]
  void loadActions(ServerImage img) {
    final list = <Map<String, String>>[];
    try {
      final f = File('${serverPath(img)}/actions.json');
      if (f.existsSync()) {
        for (final e in jsonDecode(f.readAsStringSync()) as List) {
          final m = e as Map;
          final l = m['label'];
          final c = m['cmd'];
          final pr = m['prompt'];
          if (l is String && c is String) {
            list.add({'label': l, 'cmd': c, if (pr is String) 'prompt': pr});
          }
        }
      }
    } catch (_) {
      // kaputte actions.json ignorieren
    }
    actions[img.id] = list;
  }

  /// Fragt einen Text ab (z. B. Download-Link). null = abgebrochen.
  Future<String?> askText(String title, String hint) {
    final c = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: c,
          autofocus: true,
          decoration: InputDecoration(hintText: hint),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('Abbrechen', 'Cancel'))),
          TextButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('OK')),
        ],
      ),
    );
  }

  Future<void> runAction(ServerImage img, String label, String cmd, {String? prompt}) async {
    if (taskBusy.contains(img.id) || busy.containsKey(img.id)) return;
    if (running.containsKey(img.id)) {
      log(tr('⚠️ Bitte zuerst den Server stoppen.', '⚠️ Please stop the server first.'));
      return;
    }
    String? input;
    if (prompt != null) {
      input = await askText(label, prompt);
      if (input == null || input.isEmpty) {
        log(tr('Abgebrochen (keine Eingabe).', 'Cancelled (no input).'));
        return;
      }
    }
    final dir = serverPath(img);
    taskBusy.add(img.id);
    refresh();
    log('▶️ $label…');
    try {
      await Directory('$dir/tmp').create(recursive: true);
      final p = await Process.start(
        '/system/bin/sh',
        ['-c', cmd],
        workingDirectory: dir,
        environment: {
          'HOME': dir,
          'TMPDIR': '$dir/tmp',
          'SERVER_DIR': dir,
          'APP_LANG': isDe ? 'de' : 'en',
          if (input != null) 'ACTION_INPUT': input,
        },
      );
      p.stdin.done.catchError((_) {});
      const dec = Utf8Decoder(allowMalformed: true);
      final outF = p.stdout.transform(dec).transform(const LineSplitter()).forEach(log);
      final errF = p.stderr.transform(dec).transform(const LineSplitter()).forEach(log);
      final code = await p.exitCode;
      await Future.wait([outF, errF]);
      log('${code == 0 ? '✅' : '⚠️'} $label ${tr('beendet', 'finished')} (Exit $code)');
    } catch (e) {
      log('❌ $label: $e');
    } finally {
      taskBusy.remove(img.id);
      refresh();
    }
  }

  Future<void> sendCommand(String raw) async {
    final text = raw.trim();
    if (text.isEmpty) return;
    cmdController.clear();
    log('> $text');

    final target = byId(consoleTarget);
    final p = target != null ? running[target.id] : null;
    if (p != null) {
      try {
        p.stdin.writeln(text);
      } catch (e) {
        log('❌ $e');
      }
      return;
    }

    // Kein laufender Server: Befehl als Shell-Kommando ausführen
    final home = (target != null && target.installed) ? serverPath(target) : baseDir.path;
    final cwd = shellCwd.isEmpty ? home : shellCwd;

    if (text == 'cd' || text.startsWith('cd ')) {
      final arg = text.length > 2 ? text.substring(3).trim() : '';
      final path = arg.isEmpty ? home : (arg.startsWith('/') ? arg : '$cwd/$arg');
      final d = Directory(path);
      if (d.existsSync()) {
        shellCwd = d.resolveSymbolicLinksSync();
        log(shellCwd);
      } else {
        log('cd: $arg: ${tr('Ordner nicht gefunden', 'no such directory')}');
      }
      return;
    }

    try {
      final r = await Process.run(
        '/system/bin/sh',
        ['-c', text],
        workingDirectory: cwd,
        environment: {'HOME': home},
      );
      final out = '${r.stdout}${r.stderr}'.trimRight();
      if (out.isNotEmpty) log(out);
    } catch (e) {
      log('❌ $e');
    }
  }

  // ---------------------------------------------------------------- Dialoge

  Future<bool> confirm(String message) async {
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _surface,
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr('Abbrechen', 'Cancel'), style: const TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(tr('OK', 'OK'), style: const TextStyle(color: _red)),
          ),
        ],
      ),
    );
    return res ?? false;
  }

  Future<void> editImage([ServerImage? existing]) async {
    final nameC = TextEditingController(text: existing?.name ?? '');
    final urlC = TextEditingController(
        text: existing != null && existing.sourceType == 'url' ? existing.source : '');
    var type = existing?.sourceType ?? 'url';
    var picking = false;
    pickMessage = '';
    String? localPath =
        existing != null && existing.sourceType == 'local' ? existing.source : null;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) {
          final valid = nameC.text.trim().isNotEmpty &&
              (type == 'url' ? urlC.text.trim().startsWith('http') : localPath != null);
          return AlertDialog(
            backgroundColor: _surface,
            title: Text(existing == null
                ? tr('➕ Image hinzufügen', '➕ Add image')
                : tr('⚙️ Quelle bearbeiten', '⚙️ Edit source')),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameC,
                    onChanged: (_) => setD(() {}),
                    decoration: InputDecoration(
                      labelText: tr('Name', 'Name'),
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SegmentedButton<String>(
                    segments: [
                      const ButtonSegment(
                          value: 'url', label: Text('GitHub / URL'), icon: Icon(Icons.cloud_download)),
                      ButtonSegment(
                          value: 'local',
                          label: Text(tr('Lokal', 'Local')),
                          icon: const Icon(Icons.folder_open)),
                    ],
                    selected: {type},
                    onSelectionChanged: (s) => setD(() => type = s.first),
                  ),
                  const SizedBox(height: 16),
                  if (type == 'url')
                    TextField(
                      controller: urlC,
                      onChanged: (_) => setD(() {}),
                      style: const TextStyle(fontSize: 13),
                      decoration: const InputDecoration(
                        labelText: 'URL (.tar.gz)',
                        hintText: 'https://github.com/.../releases/download/.../server.tar.gz',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    )
                  else ...[
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: _border, foregroundColor: Colors.white),
                      icon: const Icon(Icons.attach_file),
                      label: Text(tr('Datei auswählen', 'Choose file')),
                      onPressed: picking
                          ? null
                          : () async {
                              setD(() => picking = true);
                              final p = await pickArchive();
                              if (!ctx.mounted) return;
                              setD(() {
                                picking = false;
                                if (p != null) localPath = p;
                              });
                            },
                    ),
                    if (picking) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              tr('Kopiere Datei… bei großen Images kann das dauern.',
                                  'Copying file… this can take a while for large images.'),
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (!picking && pickMessage.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(pickMessage, style: const TextStyle(fontSize: 12, color: _red)),
                    ],
                    if (localPath != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        '✔ ${localPath!.split('/').last}',
                        style: const TextStyle(fontSize: 12, color: _green),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(tr('Abbrechen', 'Cancel'), style: const TextStyle(color: Colors.white54)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: _blue),
                onPressed: valid ? () => Navigator.pop(ctx, true) : null,
                child: Text(tr('Speichern', 'Save'), style: const TextStyle(color: Colors.black)),
              ),
            ],
          );
        },
      ),
    );

    if (saved != true) return;
    final name = nameC.text.trim();
    final source = type == 'url' ? urlC.text.trim() : localPath!;

    if (existing == null) {
      images.add(ServerImage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        sourceType: type,
        source: source,
      ));
    } else {
      if (existing.sourceType == 'local' && existing.source != source) {
        await deleteManagedArchive(existing.source);
      }
      existing.name = name;
      existing.sourceType = type;
      existing.source = source;
    }
    await saveConfig();
    refresh();
    log('⚙️ ${tr('Gespeichert', 'Saved')}: $name');
  }

  Future<void> onMenu(String value, ServerImage img) async {
    switch (value) {
      case 'edit':
        await editImage(img);
        break;
      case 'kill':
        killServer(img);
        break;
      case 'uninstall':
        if (await confirm(tr(
            'Alle Dateien von "${img.name}" löschen (auch Welten/Daten)?',
            'Delete all files of "${img.name}" (including worlds/data)?'))) {
          await uninstall(img);
        }
        break;
      case 'remove':
        if (await confirm(tr('Eintrag "${img.name}" samt Dateien entfernen?',
            'Remove "${img.name}" including its files?'))) {
          if (running.containsKey(img.id)) killServer(img);
          await uninstall(img);
          if (img.sourceType == 'local') await deleteManagedArchive(img.source);
          images.remove(img);
          if (consoleTarget == img.id) consoleTarget = null;
          await saveConfig();
          refresh();
        }
        break;
    }
  }

  // ------------------------------------------------------------------- UI

  Widget imageCard(ServerImage img) {
    final isRunning = running.containsKey(img.id);
    final isBusy = busy.containsKey(img.id);
    final status = isRunning
        ? tr('Läuft', 'Running')
        : img.installed
            ? tr('Installiert', 'Installed')
            : tr('Nicht installiert', 'Not installed');
    final statusColor = isRunning ? _green : (img.installed ? _blue : _grey);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(img.name,
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.bold, color: _green)),
                ),
                Chip(
                  label: Text(status, style: const TextStyle(fontSize: 11, color: Colors.black)),
                  backgroundColor: statusColor,
                  visualDensity: VisualDensity.compact,
                ),
                PopupMenuButton<String>(
                  onSelected: (v) => onMenu(v, img),
                  itemBuilder: (_) => [
                    PopupMenuItem(
                        value: 'edit', child: Text(tr('Quelle ändern', 'Change source'))),
                    if (isRunning)
                      PopupMenuItem(
                          value: 'kill', child: Text(tr('Hart beenden', 'Force kill'))),
                    if (img.installed && !isRunning)
                      PopupMenuItem(
                          value: 'uninstall', child: Text(tr('Deinstallieren', 'Uninstall'))),
                    if (!isRunning)
                      PopupMenuItem(
                          value: 'remove', child: Text(tr('Eintrag entfernen', 'Remove entry'))),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${img.sourceType == 'url' ? '🌐' : '📁'} ${img.sourceType == 'url' ? img.source : img.source.split('/').last}',
              style: const TextStyle(fontSize: 11, color: Colors.white54),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (isBusy) ...[
              const SizedBox(height: 10),
              LinearProgressIndicator(value: busy[img.id]),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (!img.installed)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: _orange, foregroundColor: Colors.black),
                    icon: const Icon(Icons.download),
                    label: Text(tr('Installieren', 'Install')),
                    onPressed: isBusy ? null : () => install(img),
                  ),
                if (img.installed && !isRunning)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: _green, foregroundColor: Colors.black),
                    icon: const Icon(Icons.play_arrow),
                    label: Text(tr('Starten', 'Start')),
                    onPressed: (isBusy || taskBusy.contains(img.id)) ? null : () => startServer(img),
                  ),
                if (img.installed && !isRunning)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: _blue, foregroundColor: Colors.black),
                    icon: const Icon(Icons.refresh),
                    label: Text(tr('Image neu laden', 'Reinstall image')),
                    onPressed: (isBusy || taskBusy.contains(img.id)) ? null : () => install(img),
                  ),
                if (img.installed && !isRunning)
                  for (final a in actions[img.id] ?? const <Map<String, String>>[])
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: _orange, foregroundColor: Colors.black),
                      icon: const Icon(Icons.build),
                      label: Text(a['label']!),
                      onPressed: (isBusy || taskBusy.contains(img.id))
                          ? null
                          : () => runAction(img, a['label']!, a['cmd']!, prompt: a['prompt']),
                    ),
                if (isRunning)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: _red, foregroundColor: Colors.black),
                    icon: const Icon(Icons.stop),
                    label: const Text('Stop'),
                    onPressed: () => stopServer(img),
                  ),
                if (img.installed)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: _border, foregroundColor: Colors.white),
                    icon: const Icon(Icons.terminal),
                    label: Text(tr('Konsole', 'Console')),
                    onPressed: () {
                      setState(() {
                        consoleTarget = img.id;
                        shellCwd = '';
                        tab = 1;
                      });
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget serversTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
      children: [
        for (final img in images) imageCard(img),
        if (images.isEmpty)
          Padding(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Text(tr('Noch kein Image. Tippe auf „Image hinzufügen“.',
                  'No image yet. Tap "Add image".')),
            ),
          ),
      ],
    );
  }

  Widget consoleTab() {
    final target = byId(consoleTarget)?.id;
    final targetRunning = target != null && running.containsKey(target);

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButton<String?>(
                  isExpanded: true,
                  value: target,
                  dropdownColor: _surface,
                  underline: const SizedBox(),
                  items: [
                    DropdownMenuItem<String?>(
                        value: null, child: Text(tr('Allgemein (App-Ordner)', 'General (app folder)'))),
                    for (final i in images.where((i) => i.installed))
                      DropdownMenuItem<String?>(
                        value: i.id,
                        child: Text('${running.containsKey(i.id) ? '🟢' : '⚪'} ${i.name}'),
                      ),
                  ],
                  onChanged: (v) => setState(() {
                    consoleTarget = v;
                    shellCwd = '';
                  }),
                ),
              ),
              IconButton(
                tooltip: tr('Konsole leeren', 'Clear console'),
                icon: const Icon(Icons.delete_sweep),
                onPressed: () => setState(() => logLines.clear()),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _console,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _border),
              ),
              child: SelectionArea(
                child: ListView.builder(
                  controller: logScroll,
                  itemCount: logLines.length,
                  itemBuilder: (_, i) => Text(
                    logLines[i],
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: _green),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: cmdController,
                  autocorrect: false,
                  enableSuggestions: false,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
                  onSubmitted: sendCommand,
                  decoration: InputDecoration(
                    hintText: targetRunning
                        ? tr('Befehl an Server (z. B. list, say Hallo)', 'Command to server (e.g. list, say hi)')
                        : tr('Shell-Befehl (z. B. ls, cd bedrock)', 'Shell command (e.g. ls, cd bedrock)'),
                    prefixText: targetRunning ? '» ' : r'$ ',
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                icon: const Icon(Icons.send),
                onPressed: () => sendCommand(cmdController.text),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          Image.asset('assets/logo.png', width: 30, height: 30,
              errorBuilder: (_, __, ___) => const Text('⚙️')),
          const SizedBox(width: 10),
          const Flexible(child: Text('ARM64 Server Manager', overflow: TextOverflow.ellipsis)),
        ]),
        backgroundColor: _surfaceDark,
        actions: [
          TextButton(
            onPressed: () {
              setState(() => isDe = !isDe);
              saveConfig();
            },
            child: Text(isDe ? '🇩🇪 DE' : '🇺🇸 EN', style: const TextStyle(color: Colors.white)),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: !ready
          ? const Center(child: CircularProgressIndicator())
          : IndexedStack(index: tab, children: [serversTab(), consoleTab()]),
      floatingActionButton: (ready && tab == 0)
          ? FloatingActionButton.extended(
              backgroundColor: _blue,
              foregroundColor: Colors.black,
              icon: const Icon(Icons.add),
              label: Text(tr('Image hinzufügen', 'Add image')),
              onPressed: () => editImage(),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        backgroundColor: _surfaceDark,
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.dns), label: tr('Server', 'Servers')),
          NavigationDestination(icon: const Icon(Icons.terminal), label: tr('Konsole', 'Console')),
        ],
      ),
    );
  }
}
