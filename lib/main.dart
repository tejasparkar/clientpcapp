// ===== main.dart =====
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:window_manager/window_manager.dart';
import 'screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize window manager for desktop
  await windowManager.ensureInitialized();
  
  WindowOptions windowOptions = const WindowOptions(
    size: Size(1200, 900),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    // Use the normal title bar so native minimize/close buttons are available.
    titleBarStyle: TitleBarStyle.normal,
    // Allow the app to be minimized and run in background; don't force always-on-top.
    alwaysOnTop: false,
  );
  
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
    await windowManager.setResizable(false);
    // Ensure window can be minimized and will remain in taskbar (run in background).
    await windowManager.setMinimizable(true);
    await windowManager.setSkipTaskbar(false);
    // Try to register the app to start on Windows boot by creating a shortcut
    // in the user's Startup folder. This only runs on Windows and will be
    // a no-op on other platforms.
    try {
      await _ensureStartsOnBoot();
    } catch (e) {
      // Log but don't crash startup if registration fails.
      print('Failed to register startup shortcut: $e');
    }
    // Keep app running in background: prevent close and hide on close/minimize
    await windowManager.setPreventClose(true);
    windowManager.addListener(_BackgroundWindowListener());
  });

  runApp(const GamersdenPCClient());
}

/// Create a shortcut in the user's Startup folder so the app starts on boot.
///
/// This is a best-effort helper that uses PowerShell to create a .lnk file
/// pointing at the current executable. In debug/development mode the
/// `Platform.resolvedExecutable` may point to the Flutter tool instead of the
/// packaged exe — for production builds this should point at the packed
/// application executable.
Future<void> _ensureStartsOnBoot() async {
  if (!Platform.isWindows) return;

  final appData = Platform.environment['APPDATA'];
  if (appData == null) return;

  final startupDir = '$appData\\Microsoft\\Windows\\Start Menu\\Programs\\Startup';
  final shortcutPath = '$startupDir\\GamersDenClient.lnk';

  final shortcutFile = File(shortcutPath);
  if (await shortcutFile.exists()) {
    // Already registered
    return;
  }

  // Attempt to find the executable to point the shortcut at.
  String targetPath = Platform.resolvedExecutable;

  // If resolvedExecutable doesn't look like an exe, try the current directory
  // for a matching exe named like the project.
  if (!targetPath.toLowerCase().endsWith('.exe')) {
    final cwd = Directory.current;
    try {
      final exeFiles = cwd.listSync().whereType<File>().where((f) => f.path.toLowerCase().endsWith('.exe'));
      if (exeFiles.isNotEmpty) {
        // Prefer an exe that contains the project folder name
        final projectName = cwd.path.split(Platform.pathSeparator).last.toLowerCase();
        final match = exeFiles.firstWhere((f) => f.path.toLowerCase().contains(projectName), orElse: () => exeFiles.first);
        targetPath = match.path;
      }
    } catch (_) {
      // ignore
    }
  }

  // Fall back: if still not an exe, abort silently.
  if (!targetPath.toLowerCase().endsWith('.exe')) {
    print('Could not determine application exe to register for startup: $targetPath');
    return;
  }

  // PowerShell script to create a shortcut via COM WScript.Shell
  final psScript =
      "\$WshShell = New-Object -ComObject WScript.Shell;"
      "\$Shortcut = \$WshShell.CreateShortcut(\"$shortcutPath\");"
      "\$Shortcut.TargetPath = \"$targetPath\";"
      "\$Shortcut.WorkingDirectory = \"${Directory(targetPath).path}\";"
      "\$Shortcut.Save();";

  // Execute the PowerShell command
  final result = await Process.run(
    'powershell',
    ['-NoProfile', '-NonInteractive', '-Command', psScript],
    runInShell: true,
  );

  if (result.exitCode != 0) {
    throw Exception('PowerShell exited with code ${result.exitCode}: ${result.stderr}');
  }
}

class GamersdenPCClient extends StatelessWidget {
  const GamersdenPCClient({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gamers Den - PC Client',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFF1a1a2e),
        fontFamily: 'Roboto',
      ),
      home: const LoginScreen(),
    );
  }
}

class _BackgroundWindowListener extends WindowListener {
  @override
  void onWindowClose() async {
    // Instead of closing the app, hide the window so the app keeps running
    try {
      await windowManager.hide();
      await windowManager.setSkipTaskbar(true);
    } catch (_) {}
  }

  @override
  void onWindowMinimize() async {
    // Hide when minimized so it continues running in background
    try {
      await windowManager.hide();
      await windowManager.setSkipTaskbar(true);
    } catch (_) {}
  }
}