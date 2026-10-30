// From jejezz/application-release-templates common/ @ conventions-v1.
//
// 새 앱의 시작점. 규약이 요구하는 연결을 한곳에 모았다:
//   창 크기(window_manager) · 추가 라이선스 · 설정 로드 · 라이트/다크 ·
//   언어 해석 · macOS 앱 메뉴 About · 앱 바 [테마 | 언어 | 정보] · 빈 상태.
// 기존 앱에는 통째로 덮어쓰지 말고 필요한 부분만 옮긴다.

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

import 'about/about_dialog.dart';
import 'about/app_menu_bar.dart';
import 'about/extra_licenses.dart';
import 'app_identity.dart';
import 'l10n/app_localizations.dart';
import 'providers/providers.dart';
import 'screens/project_list_screen.dart';
import 'services/app_config.dart';
import 'services/app_paths.dart';
import 'services/json_file_store.dart';
import 'services/project_store.dart';
import 'settings/app_settings.dart';
import 'theme/app_theme.dart';
import 'update/update_scope.dart';
import 'update/update_service.dart';
import 'window/window_placement.dart';

final bool _isDesktop =
    Platform.isMacOS || Platform.isWindows || Platform.isLinux;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerExtraLicenses();

  Future<void> Function()? showWindow;
  if (_isDesktop) {
    await windowManager.ensureInitialized();
    showWindow = await _prepareWindow();
  }

  final settings = await AppSettings.load();
  // 데스크톱이 아니거나 UPDATE_SERVER 가 비어 있으면 null — 업데이트 확인 없음.
  final updates = await UpdateService.create();
  // UpdateScope 는 MaterialApp 위에 둔다 — 정보 창이 이것을 읽어 "업데이트 확인" 단추를 붙인다.

  // 프로젝트 목록과 앱 설정은 앱 데이터 폴더의 JSON 파일에 저장한다 (identity.md §6).
  final dataDir = appDataDirectory(
    fileName: AppIdentity.displayName.replaceAll(' ', ''),
  );
  final projectStore = FileProjectStore(
    JsonFileStore(File('${dataDir.path}/projects.json')),
  );
  final configStore = FileAppConfigStore(
    JsonFileStore(File('${dataDir.path}/app_settings.json')),
  );
  final config = await configStore.load();

  runApp(
    ProviderScope(
      overrides: [
        projectStoreProvider.overrideWithValue(projectStore),
        appConfigStoreProvider.overrideWithValue(configStore),
        appConfigProvider.overrideWith(() => AppConfigNotifier(config)),
      ],
      child: UpdateScope(
        service: updates,
        child: App(settings: settings, updates: updates),
      ),
    ),
  );

  if (showWindow != null) {
    final show = showWindow;
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(show()));
  }
}

/// 다음 프레임이 그려질 때까지 기다린다.
Future<void> _nextFrame() {
  final completer = Completer<void>();
  WidgetsBinding.instance.addPostFrameCallback((_) => completer.complete());
  WidgetsBinding.instance.scheduleFrame();
  return completer.future;
}

/// ui-ux.md §5: 최소 크기는 960×600 이하 (1366×768 노트북).
/// 위치는 WindowPlacement — window-placement.md.
/// 배치가 끝나고 첫 프레임이 그려진 뒤에 show() 를 불러야 깜빡이지 않는다 (§5).
Future<Future<void> Function()> _prepareWindow() async {
  const size = Size(1200, 720);
  WindowPlacement? placement;
  if (WindowPlacement.enabled) {
    placement = WindowPlacement(await SharedPreferences.getInstance(), defaultSize: size);
  }
  final options = WindowOptions(
    size: size,
    minimumSize: const Size(960, 600),
    center: placement == null,
    title: AppIdentity.displayName,
  );
  final placed = Completer<void>();
  await windowManager.waitUntilReadyToShow(options, () async {
    await placement?.placeInitially();
    placed.complete();
  });
  return () async {
    await placed.future;
    await _nextFrame();
    await windowManager.show();
    await windowManager.focus();
    placement?.attach();
  };
}

class App extends StatefulWidget {
  const App({super.key, required this.settings, this.updates});

  final AppSettings settings;
  final UpdateService? updates;

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> with WidgetsBindingObserver {
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.settings.addListener(_syncWindowBrightness);
    _syncWindowBrightness();
    widget.updates?.startAutomaticCheck(_navigatorKey);
  }

  @override
  void dispose() {
    widget.settings.removeListener(_syncWindowBrightness);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // 앱에서 다크를 골라도 OS가 라이트면 제목 표시줄은 밝게 남는다 (theming.md §4).
  @override
  void didChangePlatformBrightness() => _syncWindowBrightness();

  void _syncWindowBrightness() {
    if (!_isDesktop || Platform.isLinux) return;
    final brightness = switch (widget.settings.themeMode) {
      ThemeMode.light => Brightness.light,
      ThemeMode.dark => Brightness.dark,
      ThemeMode.system =>
        WidgetsBinding.instance.platformDispatcher.platformBrightness,
    };
    windowManager.setBrightness(brightness);
  }

  void _showAbout() {
    final context = _navigatorKey.currentContext;
    if (context == null) return;
    final l10n = AppLocalizations.of(context);
    showAppAboutDialog(
      context,
      tagline: l10n.aboutTagline,
      description: l10n.aboutDescription,
      onCheckForUpdates: widget.updates == null
          ? null
          : () => widget.updates!.checkManually(context),
    );
  }

  void _checkForUpdates() {
    final context = _navigatorKey.currentContext;
    if (context != null) widget.updates?.checkManually(context);
  }

  @override
  Widget build(BuildContext context) {
    return AppSettingsScope(
      settings: widget.settings,
      child: ListenableBuilder(
        listenable: widget.settings,
        builder: (context, _) => MaterialApp(
          navigatorKey: _navigatorKey,
          title: AppIdentity.displayName,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(dense: _isDesktop, palette: widget.settings.accentPalette),
          darkTheme: AppTheme.dark(dense: _isDesktop, palette: widget.settings.accentPalette),
          themeMode: widget.settings.themeMode,
          locale: widget.settings.locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          localeResolutionCallback: AppSettings.resolveLocale,
          builder: (context, child) => AppMenuBar(
            onAbout: _showAbout,
            onCheckForUpdates: widget.updates == null ? null : _checkForUpdates,
            child: child!,
          ),
          home: ProjectListScreen(onAbout: _showAbout),
        ),
      ),
    );
  }
}
