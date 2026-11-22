// MainShell — top-level scaffold for the main app tabs. Premium Ivory v2.
//
// Five equal tabs in the bottom nav, all backed by real screens in an
// IndexedStack so each tab keeps its scroll state:
//   0 Trang chủ  → DashboardHomeScreen
//   1 Lộ trình   → PlanScreen
//   2 Khám phá   → LibraryScreen   (was a sheet overlay; now a real page)
//   3 Tiến bộ    → ProgressScreen
//   4 Hồ sơ      → ProfileScreen
//
// The prior floating-FAB sheet (ExerciseBrowser) is gone — the
// IvoryBottomNav uses five equal tabs, and Library is a regular page.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/exercise_definition.dart';
import '../models/kept_exercises.dart';
import '../services/analytics_service.dart';
import '../services/recommendation/recommendation_service.dart';
import '../services/research/research_preferences.dart';
import '../services/user_program_service.dart';
import '../services/user_profile_service.dart';
import '../services/workout_reminders.dart';
import '../theme/app_colors.dart';
import '../theme/responsive.dart';
import '../utils/orientation_lock.dart';
import '../widgets/ivory/bottom_nav.dart';
import 'dashboard_home_screen.dart';
import 'exercise/exercise_launch_args.dart';
import 'library_screen.dart';
import 'nutrition/nutrition_screen.dart';
import 'plan_screen.dart';
import 'profile_screen.dart';
import 'progress_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

enum _Tab { home, plan, library, nutrition, progress, profile }

class _MainShellState extends State<MainShell>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  late final List<_Tab> _tabs = [
    for (final t in _Tab.values)
      if (t != _Tab.nutrition || !ResearchPreferences.cachedConfig.isControl) t,
  ];
  late final AnimationController _tabFade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
    value: 1,
  );
  final ValueNotifier<int> _planRefreshNudge = ValueNotifier<int>(0);
  final ValueNotifier<int> _progressRefreshNudge = ValueNotifier<int>(0);
  UserProgramData? _program;
  AppUserProfile? _profile;
  final RecommendationService _recommendations = RecommendationService();

  @override
  void initState() {
    super.initState();
    unawaited(OrientationLock.portraitOnly());
    unawaited(WorkoutReminders.askPermissionOnce());
    _loadProgram();
    _loadProfile();
  }

  Future<void> _loadProgram() async {
    final program = await UserProgramService.loadAssignedProgram();
    if (!mounted) return;
    setState(() => _program = program);
  }

  Future<void> _loadProfile() async {
    final profile = await UserProfileService().fetchCurrentProfile();
    if (!mounted) return;
    setState(() => _profile = profile);
  }

  void _handleProfileChanged(AppUserProfile profile) {
    setState(() => _profile = profile);
  }

  void _handleTabTap(int idx) {
    if (idx == _currentIndex) return;
    setState(() => _currentIndex = idx);
    _tabFade.forward(from: 0);
    final tab = _tabs[idx];
    if (tab == _Tab.plan) {
      _planRefreshNudge.value++;
    } else if (tab == _Tab.progress) {
      _progressRefreshNudge.value++;
    } else if (tab == _Tab.profile) {
      // Hồ sơ is where settings (incl. the analytics consent toggle) live.
      // No-op without consent.
      unawaited(AnalyticsService.instance.capture('settings_opened'));
    }
  }

  void _openExerciseFromLibrary(ExerciseDefinition definition) {
    if (!isKeptExercise(definition.id)) return;
    unawaited(_openExerciseFromLibraryWithCatalog(definition));
  }

  Future<void> _openExerciseFromLibraryWithCatalog(
    ExerciseDefinition definition,
  ) async {
    final catalogInfoById =
        await _recommendations.fetchLaunchCatalogInfoForExerciseIds(
      [definition.id],
    );
    if (!mounted) return;
    Navigator.of(context).pushNamed(
      '/exercise',
      arguments: ExerciseLaunchArgs(
        definition: definition,
        catalogExerciseId: definition.id,
        catalogInfo: catalogInfoById[definition.id],
      ),
    );
  }

  @override
  void dispose() {
    _tabFade.dispose();
    _planRefreshNudge.dispose();
    _progressRefreshNudge.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    final r = Responsive.of(context);
    final mediaQuery = MediaQuery.of(context);
    final bottomInset = mediaQuery.padding.bottom;
    final isDark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    // Slim pill capsule (~58pt) + tighter margin above the home indicator.
    final navCapsule = r.w(68);
    final contentBottomPadding = navCapsule + bottomInset + r.w(4);

    final screens = <_Tab, Widget>{
      _Tab.home: DashboardHomeScreen(
        bottomPadding: contentBottomPadding,
        // Library is its own tab now — Home's "browse" callback just
        // switches to the Library tab.
        onOpenBrowser: () => _handleTabTap(_tabs.indexOf(_Tab.library)),
        program: _program,
        userProfile: _profile,
        onProfileChanged: _handleProfileChanged,
      ),
      _Tab.plan: PlanScreen(
        bottomPadding: contentBottomPadding,
        program: _program,
        userProfile: _profile,
        refreshListenable: _planRefreshNudge,
        onProfileChanged: _handleProfileChanged,
      ),
      _Tab.library: LibraryScreen(
        bottomPadding: contentBottomPadding,
        onSelectExercise: _openExerciseFromLibrary,
        userProfile: _profile,
      ),
      _Tab.nutrition: NutritionScreen(bottomPadding: contentBottomPadding),
      _Tab.progress: ProgressScreen(
        bottomPadding: contentBottomPadding,
        refreshListenable: _progressRefreshNudge,
        userProfile: _profile,
        onProfileChanged: _handleProfileChanged,
      ),
      _Tab.profile: ProfileScreen(
        bottomPadding: contentBottomPadding,
        userProfile: _profile,
        onProfileChanged: _handleProfileChanged,
      ),
    };

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      ),
      child: Scaffold(
        extendBody: true,
        backgroundColor: c.bg,
        body: SafeArea(
          bottom: false,
          child: AnimatedBuilder(
            animation: _tabFade,
            builder: (context, child) {
              final t = Curves.easeOutCubic.transform(_tabFade.value);
              return Opacity(
                opacity: t,
                child: Transform.translate(
                  offset: Offset(0, (1 - t) * 10),
                  child: child,
                ),
              );
            },
            child: IndexedStack(
              index: _currentIndex,
              children: [for (final t in _tabs) screens[t]!],
            ),
          ),
        ),
        bottomNavigationBar: IvoryBottomNav(
          currentIndex: _currentIndex,
          bottomInset: bottomInset,
          onTap: _handleTabTap,
          showNutrition: _tabs.contains(_Tab.nutrition),
        ),
      ),
    );
  }
}
