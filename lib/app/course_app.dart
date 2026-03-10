import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import 'pages/gpa_page.dart';
import 'pages/import_page.dart';
import 'pages/schedule_page.dart';
import 'pages/settings_page.dart';
import 'pages/windows_mini_schedule_page.dart';

class CourseMonitorApp extends StatelessWidget {
  const CourseMonitorApp({super.key, required this.appState});

  final AppState appState;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appState,
      builder: (BuildContext context, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: '\u8bfe\u8868\u7ba1\u5bb6',
          theme: _buildTheme(Brightness.light),
          darkTheme: _buildTheme(Brightness.dark),
          themeMode: appState.settings.themeModeSetting.toThemeMode(),
          home: !appState.initialized
              ? const Scaffold(body: Center(child: CircularProgressIndicator()))
              : (!kIsWeb &&
                    defaultTargetPlatform == TargetPlatform.windows &&
                    appState.windowsMiniMode)
              ? _WindowsMiniRoot(
                  key: const ValueKey<String>('windows-mini'),
                  appState: appState,
                )
              : CourseHomeShell(
                  key: const ValueKey<String>('course-home'),
                  appState: appState,
                ),
        );
      },
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    final bool isDark = brightness == Brightness.dark;
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF2A6C86),
      brightness: brightness,
    );

    final RoundedRectangleBorder controlShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: 'Noto Sans SC',
      fontFamilyFallback: const <String>[
        'PingFang SC',
        'Microsoft YaHei',
        'Helvetica Neue',
        'Arial',
        'sans-serif',
      ],
      scaffoldBackgroundColor: isDark
          ? const Color(0xFF15181F)
          : const Color(0xFFF2F4F7),
      cardTheme: CardThemeData(
        color: isDark ? const Color(0xFF242933) : Colors.white,
        margin: const EdgeInsets.symmetric(vertical: 6),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        centerTitle: false,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF242933) : Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 66,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        indicatorColor: scheme.secondaryContainer.withValues(alpha: 0.8),
        backgroundColor: isDark
            ? const Color(0xE6242933)
            : const Color(0xEFFFFFFF),
        labelTextStyle: const WidgetStatePropertyAll(
          TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          alignment: Alignment.center,
          minimumSize: const WidgetStatePropertyAll(Size(0, 44)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          textStyle: const WidgetStatePropertyAll(
            TextStyle(fontWeight: FontWeight.w600),
          ),
          shape: WidgetStatePropertyAll(controlShape),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(0, 44)),
          shape: WidgetStatePropertyAll(controlShape),
          textStyle: const WidgetStatePropertyAll(
            TextStyle(fontWeight: FontWeight.w600),
          ),
          animationDuration: const Duration(milliseconds: 180),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(0, 44)),
          shape: WidgetStatePropertyAll(controlShape),
          textStyle: const WidgetStatePropertyAll(
            TextStyle(fontWeight: FontWeight.w600),
          ),
          animationDuration: const Duration(milliseconds: 180),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
        },
      ),
    );
  }
}

class CourseHomeShell extends StatefulWidget {
  const CourseHomeShell({super.key, required this.appState});

  final AppState appState;

  @override
  State<CourseHomeShell> createState() => _CourseHomeShellState();
}

class _CourseHomeShellState extends State<CourseHomeShell> {
  int _index = 0;
  String? _lastMessage;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    widget.appState.addListener(_onStateUpdated);
  }

  @override
  void dispose() {
    widget.appState.removeListener(_onStateUpdated);
    _pageController.dispose();
    super.dispose();
  }

  void _onStateUpdated() {
    final String? message = widget.appState.statusMessage;
    if (!mounted || message == null || message == _lastMessage) {
      return;
    }
    _lastMessage = message;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _onDestinationSelected(int value) {
    int currentPage = _index;
    if (_pageController.hasClients) {
      currentPage = (_pageController.page ?? _index.toDouble()).round();
    }
    if (value == _index && value == currentPage) {
      return;
    }
    setState(() => _index = value);
    if (!_pageController.hasClients) {
      return;
    }
    _pageController.animateToPage(
      value,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  bool _isDesktopLayout(BuildContext context) {
    final double width = MediaQuery.sizeOf(context).width;
    if (width >= 900) {
      return true;
    }
    if (kIsWeb) {
      return width >= 900;
    }
    return defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux;
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = <Widget>[
      SchedulePage(appState: widget.appState),
      ImportPage(appState: widget.appState),
      GpaPage(appState: widget.appState),
      SettingsPage(appState: widget.appState),
    ];

    final bool desktop = _isDesktopLayout(context);

    return Scaffold(
      body: Stack(
        children: <Widget>[
          SafeArea(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (int value) => setState(() => _index = value),
              children: pages,
            ),
          ),
          if (widget.appState.busy)
            const ColoredBox(
              color: Color(0x33000000),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
      bottomNavigationBar: desktop
          ? _DesktopNavigationBar(
              index: _index,
              onDestinationSelected: _onDestinationSelected,
            )
          : _MobileFloatingNavigationBar(
              index: _index,
              onDestinationSelected: _onDestinationSelected,
            ),
    );
  }
}

class _WindowsMiniRoot extends StatelessWidget {
  const _WindowsMiniRoot({super.key, required this.appState});

  final AppState appState;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: WindowsMiniSchedulePage(
              appState: appState,
              onExitMiniMode: () =>
                  appState.runWithBusy(appState.launchWindowsMainWindow),
            ),
          ),
          if (appState.busy)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x33000000),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }
}

class _DesktopNavigationBar extends StatelessWidget {
  const _DesktopNavigationBar({
    required this.index,
    required this.onDestinationSelected,
  });

  final int index;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        top: false,
        child: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: onDestinationSelected,
          elevation: 0,
          destinations: _destinations,
        ),
      ),
    );
  }
}

class _MobileFloatingNavigationBar extends StatelessWidget {
  const _MobileFloatingNavigationBar({
    required this.index,
    required this.onDestinationSelected,
  });

  final int index;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xE6242933) : const Color(0xEFFFFFFF),
              border: Border.all(
                color: isDark
                    ? const Color(0x33FFFFFF)
                    : const Color(0x22111827),
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: NavigationBar(
              selectedIndex: index,
              onDestinationSelected: onDestinationSelected,
              destinations: _destinations,
            ),
          ),
        ),
      ),
    );
  }
}

const List<NavigationDestination> _destinations = <NavigationDestination>[
  NavigationDestination(
    icon: Icon(Icons.calendar_month_outlined),
    selectedIcon: Icon(Icons.calendar_month),
    label: '\u8bfe\u8868',
  ),
  NavigationDestination(
    icon: Icon(Icons.file_upload_outlined),
    selectedIcon: Icon(Icons.file_upload),
    label: '\u5bfc\u5165',
  ),
  NavigationDestination(
    icon: Icon(Icons.calculate_outlined),
    selectedIcon: Icon(Icons.calculate),
    label: '\u7ee9\u70b9',
  ),
  NavigationDestination(
    icon: Icon(Icons.tune_outlined),
    selectedIcon: Icon(Icons.tune),
    label: '\u8bbe\u7f6e',
  ),
];
