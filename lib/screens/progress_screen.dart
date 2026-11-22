// ProgressScreen — the Tiến bộ tab. Premium Ivory v2 (cinematic).
//
// Architecture (top to bottom):
//   1. Dark stage hero — full-bleed, atmospheric, period tabs embedded
//   2. Score gauge card — circular arc + 74/100 + delta + coach quote
//   3. Weekly summary band — 4 editorial stats with delta notes
//   4. Score trend chart — line chart with grid + "today" dot
//   5. Body heat map — silhouette + 2×2 area cards
//   6. Ranked exercise insights — top-3 with sparklines (expandable)
//   7. Personal records rail — horizontal PR cards with "MỚI" pulse
//   8. Streak card — weekly mini-summary + milestone hint
//   9. Closer with back-to-top
//
// Sticky pill bar slides in after scroll past the hero (matches Library).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/milestones.dart';
import '../data/progress_mock.dart';
import '../models/exercise_lookup.dart';
import '../models/pain_regions.dart';
import '../services/recommendation/recommendation_service.dart';
import '../services/session_persistence.dart';
import '../services/user_profile_service.dart';
import '../theme/app_colors.dart';
import '../utils/orientation_lock.dart';
import '../widgets/progress/body_heat_map.dart';
import '../widgets/progress/period_tabs.dart';
import '../widgets/progress/exercise_insight_grid.dart';
import '../services/research/research_preferences.dart';
import '../services/streak_tier.dart';
import '../widgets/tk/tk.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({
    super.key,
    required this.bottomPadding,
    this.refreshListenable,
    this.userProfile,
    this.onProfileChanged,
  });

  final double bottomPadding;
  final Listenable? refreshListenable;
  final AppUserProfile? userProfile;
  final ValueChanged<AppUserProfile>? onProfileChanged;

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  final _profileService = UserProfileService();
  final _sessions = SessionPersistence();
  final _recommendations = RecommendationService();
  PeriodTab _period = PeriodTab.program;
  AppUserProfile? _profile;
  bool _loadingProfile = false;
  bool _profileReloadQueued = false;

  /// Real ĐIỂM FORM gauge summary, SCOPED to the active period pill (week /
  /// phase / program). Drives the gauge's average + coach only — the trend
  /// list is no longer rendered from here (the chart reads [_programSummary]).
  /// Null = loading (placeholder); a loaded record with `average == null` =
  /// no sessions in this scope (empty state).
  ({
    int? average,
    FormTrendDirection direction,
    List<int> trend,
    List<DateTime> trendDates,
    String fact,
  })? _formSummary;

  /// Real ĐƯỜNG TIẾN BỘ trajectory, FIXED to whole-program scope (NOT the
  /// period pill). A program week caps at 3 sessions, so a week-scoped trend
  /// sits at/under the 3-session reveal gate and reads thin; the trajectory
  /// only reads over the full span. Loaded once when the plan resolves. Same
  /// record shape as [_formSummary]. Null = loading.
  ({
    int? average,
    FormTrendDirection direction,
    List<int> trend,
    List<DateTime> trendDates,
    String fact,
  })? _programSummary;

  /// Real BÀI TẬP NỔI BẬT ranked insights, FIXED to whole-program scope (same
  /// reasoning as [_programSummary] — week scope is too thin to rank). Loaded
  /// once when the plan resolves, NOT on tab change. Null = loading; empty =
  /// nothing qualified yet (guided empty shown).
  List<RankInsightHeadline>? _insights;

  bool _planResolved = false;

  /// The active plan snapshot, RETAINED (not just its label string) so the
  /// period feeds can scope by program position — the active week, the active
  /// phase's weeks, or the whole plan. Null when there's no active plan.
  PlanSnapshot? _snapshot;

  /// Real TỔNG QUAN TUẦN NÀY weekly summary for the current program week.
  /// Null = loading.
  ({
    int sessions,
    int totalSeconds,
    int? avgForm,
    int? sessionsDelta,
    int? secondsDelta,
    int? avgFormDelta,
  })? _weekly;

  /// Real CỘT MỐC milestones (full catalog with unlock state resolved). Null
  /// = loading. Never empty — locked rungs render as targets to chase.
  List<Milestone>? _milestones;

  /// Active pain self-reports keyed by body_region. Null = loading
  /// (show the silhouette placeholder); empty map = nothing reported yet.
  Map<String, PainMark>? _painReports;

  /// Raw `profiles.gender` for the silhouette. Null/unknown defaults to male.
  String? _gender;

  /// Preview toggle: drive EVERY Progress section from mock data so the full
  /// design is visible without any logged sessions. When true the loaders set
  /// mock state instead of hitting Supabase. False = show only real,
  /// data-derived content (the guided-empty states return below the threshold).
  ///
  /// `final` (not `const`) on purpose: the untaken preview branches must stay
  /// live code, not dead-code-eliminated, so the toggle flips cleanly.
  static final bool _previewWithMock = false;

  @override
  void initState() {
    super.initState();
    unawaited(OrientationLock.portraitOnly());
    _profile = widget.userProfile;
    widget.refreshListenable?.addListener(_handleRefreshNudge);
    // The form + insights + weekly feeds scope by program position, so they're
    // driven from the plan snapshot (loaded here) rather than fired independently.
    unawaited(_loadPlan());
    unawaited(_loadMilestones());
    unawaited(_loadPainReports());
    unawaited(_loadGender());
  }

  @override
  void didUpdateWidget(covariant ProgressScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userProfile != widget.userProfile) {
      _profile = widget.userProfile;
    }
    if (oldWidget.refreshListenable != widget.refreshListenable) {
      oldWidget.refreshListenable?.removeListener(_handleRefreshNudge);
      widget.refreshListenable?.addListener(_handleRefreshNudge);
    }
  }

  @override
  void dispose() {
    widget.refreshListenable?.removeListener(_handleRefreshNudge);
    super.dispose();
  }

  void _handleRefreshNudge() {
    unawaited(_loadProfile());
    unawaited(_loadPlan());
    unawaited(_loadMilestones());
    unawaited(_loadPainReports());
    unawaited(_loadGender());
  }

  /// Loads active pain self-reports into [_painReports]. Maps each row's
  /// source so interpreter-'confirmed' areas read differently from plain
  /// self-reports in the UI.
  Future<void> _loadPainReports() async {
    if (_previewWithMock) {
      await null; // defer past initState before setState
      if (!mounted) return;
      setState(() => _painReports = _mockPainReports);
      return;
    }
    final reports = await _sessions.getActivePainReports();
    if (!mounted) return;
    setState(() {
      _painReports = {
        for (final r in reports)
          r.region: PainMark(
            intensity: r.intensity,
            confirmed: r.source == 'confirmed',
            notes: r.notes,
          ),
      };
    });
  }

  Future<void> _loadGender() async {
    final gender = await _profileService.fetchGender();
    if (!mounted) return;
    setState(() => _gender = gender);
  }

  /// Capture-only: persist a self-report, then refresh the silhouette.
  Future<void> _reportPain(String region, int intensity, String? notes) async {
    await _sessions.reportPainArea(region, intensity, notes: notes);
    await _loadPainReports();
  }

  /// Capture-only: resolve (never delete) a report, then refresh.
  Future<void> _resolvePain(String region) async {
    await _sessions.resolvePainArea(region);
    await _loadPainReports();
  }

  Future<void> _loadProfile() async {
    if (_loadingProfile) {
      _profileReloadQueued = true;
      return;
    }
    _loadingProfile = true;
    try {
      final profile = await _profileService.fetchCurrentProfile();
      if (!mounted || profile == null) return;
      setState(() => _profile = profile);
      widget.onProfileChanged?.call(profile);
    } finally {
      _loadingProfile = false;
      if (_profileReloadQueued && mounted) {
        _profileReloadQueued = false;
        unawaited(_loadProfile());
      }
    }
  }

  /// Loads the active plan snapshot — the SAME source the Plan tab uses
  /// (RecommendationService) — RETAINING it so the period feeds can scope by
  /// program position, then derives the hero label and kicks off the form +
  /// insights feeds. Stays null (guided empty) when there is no active plan.
  Future<void> _loadPlan() async {
    if (_previewWithMock) {
      await null; // defer past initState before setState
      if (!mounted) return;
      setState(() {
        _planResolved = true;
      });
      unawaited(_loadFormSummary(_period));
      unawaited(_loadProgramSummary());
      unawaited(_loadInsights());
      unawaited(_loadWeekly());
      return;
    }
    final snapshot =
        await _recommendations.fetchLatestActivePlanSnapshotForCurrentUser();
    if (!mounted) return;
    setState(() {
      _snapshot = snapshot;
      _planResolved = true;
    });
    // Now that the scope is known, load the feeds. The gauge ([_formSummary])
    // is scoped to the active pill and re-loads on tab change; the trajectory
    // chart ([_programSummary]), insights, and weekly band are FIXED-scope and
    // load here once.
    unawaited(_loadFormSummary(_period));
    unawaited(_loadProgramSummary());
    unawaited(_loadInsights());
    unawaited(_loadWeekly());
  }

  /// Program-position scope for [period] from the retained snapshot:
  ///   week    → the active plan week
  ///   phase   → every week sharing the active week's phaseNumber
  ///   program → null weekNumbers (the whole plan)
  /// Null when there's no active plan to scope to (guided empty shown).
  ({String recommendationId, List<int>? weekNumbers})? _scopeFor(
      PeriodTab period) {
    final snapshot = _snapshot;
    if (snapshot == null || snapshot.plan.weeks.isEmpty) return null;
    final weeks = snapshot.plan.weeks;
    final recId = snapshot.plan.recommendationId;
    // currentWeek falls back to the last week once the plan is complete.
    final currentWeek = snapshot.currentWeek ?? weeks.last;
    return switch (period) {
      PeriodTab.week => (
          recommendationId: recId,
          weekNumbers: [currentWeek.weekNumber],
        ),
      PeriodTab.phase => (
          recommendationId: recId,
          weekNumbers: [
            for (final w in weeks)
              if (w.phaseNumber == currentWeek.phaseNumber) w.weekNumber,
          ],
        ),
      PeriodTab.program => (recommendationId: recId, weekNumbers: null),
    };
  }

  /// Loads the real form summary for [period], scoped to the active plan.
  /// Stale responses (the user switched period before this resolved) are
  /// discarded. No active plan → an empty record (guided empty), never a flash.
  Future<void> _loadFormSummary(PeriodTab period) async {
    if (_previewWithMock) {
      await null; // defer past initState before setState
      if (!mounted || period != _period) return;
      setState(() => _formSummary = _mockFormSummary(period));
      return;
    }
    final scope = _scopeFor(period);
    if (scope == null) {
      if (!mounted || period != _period) return;
      setState(() => _formSummary = const (
            average: null,
            direction: FormTrendDirection.none,
            trend: <int>[],
            trendDates: <DateTime>[],
            fact: '',
          ));
      return;
    }
    final summary = await _sessions.progressFormSummary(
      scope.recommendationId,
      scope.weekNumbers,
    );
    if (!mounted || period != _period) return;
    setState(() => _formSummary = summary);
  }

  /// Loads the FIXED whole-program trajectory into [_programSummary] (drives
  /// the ĐƯỜNG TIẾN BỘ chart). Independent of the period pill — uses the
  /// program scope always. No active plan → an empty record (guided empty).
  Future<void> _loadProgramSummary() async {
    if (_previewWithMock) {
      await null; // defer past initState before setState
      if (!mounted) return;
      setState(() => _programSummary = _mockFormSummary(PeriodTab.program));
      return;
    }
    final scope = _scopeFor(PeriodTab.program);
    if (scope == null) {
      if (!mounted) return;
      setState(() => _programSummary = const (
            average: null,
            direction: FormTrendDirection.none,
            trend: <int>[],
            trendDates: <DateTime>[],
            fact: '',
          ));
      return;
    }
    final summary = await _sessions.progressFormSummary(
      scope.recommendationId,
      scope.weekNumbers, // null = whole program
    );
    if (!mounted) return;
    setState(() => _programSummary = summary);
  }

  /// Loads the FIXED whole-program ranked insights into [_insights]. Independent
  /// of the period pill (week scope is too thin to rank) — uses the program
  /// scope always, loaded once when the plan resolves.
  Future<void> _loadInsights() async {
    // Preview renders mock directly in _buildInsightsSection; skip the fetch.
    if (_previewWithMock) return;
    final scope = _scopeFor(PeriodTab.program);
    if (scope == null) {
      if (!mounted) return;
      setState(() => _insights = const <RankInsightHeadline>[]);
      return;
    }
    final insights = await _sessions.rankedInsights(
      scope.recommendationId,
      scope.weekNumbers, // null = whole program
    );
    if (!mounted) return;
    setState(() => _insights = insights);
  }

  /// Loads the TỔNG QUAN TUẦN NÀY band for the CURRENT program week, scoped to
  /// the retained snapshot (same source as the form/insights feeds). The band
  /// is always the current week (NOT tab-driven). No snapshot / no plan → the
  /// empty record (existing guided empty).
  Future<void> _loadWeekly() async {
    if (_previewWithMock) {
      await null; // defer past initState before setState
      if (!mounted) return;
      setState(() => _weekly = _mockWeekly);
      return;
    }
    final snapshot = _snapshot;
    if (snapshot == null || snapshot.plan.weeks.isEmpty) {
      if (!mounted) return;
      setState(() => _weekly = const (
            sessions: 0,
            totalSeconds: 0,
            avgForm: null,
            sessionsDelta: null,
            secondsDelta: null,
            avgFormDelta: null,
          ));
      return;
    }
    // currentWeek falls back to the last week once the plan is complete.
    final currentWeek = snapshot.currentWeek ?? snapshot.plan.weeks.last;
    final weekly = await _sessions.weeklySummary(
      snapshot.plan.recommendationId,
      currentWeek.weekNumber,
    );
    if (!mounted) return;
    setState(() => _weekly = weekly);
  }

  Future<void> _loadMilestones() async {
    if (_previewWithMock) {
      await null; // defer past initState before setState
      if (!mounted) return;
      setState(() => _milestones = _mockMilestones());
      return;
    }
    final milestones = await _sessions.milestones();
    if (!mounted) return;
    setState(() => _milestones = milestones);
  }

  // ── Mock preview builders (only used while [_previewWithMock] is on) ──

  /// Mock ĐIỂM FORM gauge + trend for [period], built from progress_mock.
  ({
    int? average,
    FormTrendDirection direction,
    List<int> trend,
    List<DateTime> trendDates,
    String fact,
  }) _mockFormSummary(PeriodTab period) {
    final key = switch (period) {
      PeriodTab.week => 'week',
      // Reuse the existing 'month' preview bucket for the renamed phase tab —
      // preview-only mock data, not part of the real program-scoped path.
      PeriodTab.phase => 'month',
      PeriodTab.program => 'program',
    };
    final h = progressMockHeadline[key]!;
    final trend = progressMockScoreTrend[key]!;
    final now = DateTime.now();
    return (
      average: h.average,
      // The gauge no longer renders a direction chip; the program chart owns
      // trajectory. `none` keeps the record shape without implying a chip.
      direction: FormTrendDirection.none,
      trend: trend,
      trendDates: [
        for (var i = 0; i < trend.length; i++)
          now.subtract(Duration(days: (trend.length - 1 - i) * 2)),
      ],
      fact: h.coach,
    );
  }

  /// Mock TỔNG QUAN TUẦN NÀY weekly summary (5 buổi · 2h12' · form 74, +deltas).
  static const ({
    int sessions,
    int totalSeconds,
    int? avgForm,
    int? sessionsDelta,
    int? secondsDelta,
    int? avgFormDelta,
  }) _mockWeekly = (
    sessions: 5,
    totalSeconds: 7920,
    avgForm: 74,
    sessionsDelta: 1,
    secondsDelta: 720,
    avgFormDelta: 3,
  );

  /// Mock CỘT MỐC unlock state — a realistic mix of opened + locked rungs.
  List<Milestone> _mockMilestones() {
    bool unlocked(Milestone m) =>
        (m.category == MilestoneCategory.streak && m.threshold <= 7) ||
        (m.category == MilestoneCategory.sessions && m.threshold <= 10) ||
        (m.category == MilestoneCategory.form && m.threshold <= 80) ||
        (m.category == MilestoneCategory.consistency &&
            m.threshold == kConsistencyWeek);
    return [
      for (final m in milestoneCatalog) unlocked(m) ? m.asUnlocked('22/5') : m,
    ];
  }

  /// Mock CƠ THỂ pain self-reports across a few regions.
  static const Map<String, PainMark> _mockPainReports = {
    'knee': PainMark(intensity: 3),
    'lower_back': PainMark(intensity: 2, confirmed: true),
    'shoulder_neck': PainMark(intensity: 2),
  };

  void _onPeriodChanged(PeriodTab period) {
    if (period == _period) return;
    setState(() {
      _period = period;
      // Only the gauge rescopes. Drop it to the loading placeholder so it
      // re-mounts and re-animates with the new scope's average. The trajectory
      // chart + insights are fixed whole-program, so they stay put (no flash).
      _formSummary = null;
    });
    unawaited(_loadFormSummary(period));
  }

  /// Program-relative eyebrow for [period], derived from the retained plan
  /// snapshot — replaces the old calendar (now − N days) date stamps. Drives
  /// both the hero period stamp and the ĐIỂM FORM gauge eyebrow. Falls back to
  /// neutral copy (no fabricated dates) when there's no active plan.
  ///
  ///   week    → TUẦN {abs} · {PHASE} · TUẦN {inPhase}/{phaseLen}
  ///   phase   → {PHASE} · TUẦN {firstWk}-{lastWk}  (or TUẦN {wk} if single)
  ///   program → TOÀN CHƯƠNG TRÌNH · {totalWeeks} TUẦN
  String _periodEyebrow(PeriodTab period) {
    final snapshot = _snapshot;
    if (snapshot == null || snapshot.plan.weeks.isEmpty) {
      return switch (period) {
        PeriodTab.week => 'TUẦN NÀY',
        PeriodTab.phase => 'GIAI ĐOẠN NÀY',
        PeriodTab.program => 'TOÀN CHƯƠNG TRÌNH',
      };
    }
    final weeks = snapshot.plan.weeks;
    final currentWeek = snapshot.currentWeek ?? weeks.last;
    final phaseName = currentWeek.phaseName.toUpperCase();
    final phaseWeeks = [
      for (final w in weeks)
        if (w.phaseNumber == currentWeek.phaseNumber) w.weekNumber,
    ]..sort();
    final firstWk =
        phaseWeeks.isEmpty ? currentWeek.weekNumber : phaseWeeks.first;
    final lastWk =
        phaseWeeks.isEmpty ? currentWeek.weekNumber : phaseWeeks.last;
    final phaseLen = phaseWeeks.isEmpty ? 1 : phaseWeeks.length;
    final inPhaseIdx = phaseWeeks.indexOf(currentWeek.weekNumber);
    final inPhase = inPhaseIdx < 0 ? 1 : inPhaseIdx + 1;
    return switch (period) {
      PeriodTab.week =>
        'TUẦN ${currentWeek.weekNumber} · $phaseName · TUẦN $inPhase/$phaseLen',
      PeriodTab.phase => firstWk == lastWk
          ? '$phaseName · TUẦN $firstWk'
          : '$phaseName · TUẦN $firstWk-$lastWk',
      PeriodTab.program => 'TOÀN CHƯƠNG TRÌNH · ${weeks.length} TUẦN',
    };
  }

  /// Signed delta string: '+5', '0', '-3'. The minus is carried by the
  /// number itself; only non-negatives get a leading '+'.
  String _signedDelta(int d) => '${d >= 0 ? '+' : ''}$d';

  @override
  Widget build(BuildContext context) {
    final formSummary = _formSummary;
    final programSummary = _programSummary;
    final profile = _profile ?? widget.userProfile;
    final streakWeeks = _previewWithMock
        ? progressMockStreakWeeks
        : (profile?.streakWeeks ?? 0);
    final streakLabel = streakTierLabel(streakWeeks);
    final trend = programSummary?.trend ?? const <int>[];
    final recent = trend.length > 7 ? trend.sublist(trend.length - 7) : trend;
    final firstIndex = trend.length - recent.length;
    final weekly = _weekly;
    final milestones = _milestones;
    final nextMilestone = milestones?.where((m) => !m.unlocked).firstOrNull;
    final unlocked = milestones?.where((m) => m.unlocked).length ?? 0;
    final showMascot = !ResearchPreferences.cachedConfig.isControl;

    return ColoredBox(
      color: Tk.surface,
      child: SafeArea(
        bottom: false,
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.only(bottom: widget.bottomPadding + 20),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Tiến độ',
                      style: Tk.text(28,
                          weight: FontWeight.w900, letterSpacing: -0.4)),
                  const SizedBox(height: 4),
                  Text(
                    !_planResolved
                        ? 'Đang tải…'
                        : _periodEyebrow(_period)
                            .toLowerCase()
                            .replaceFirstMapped(
                                RegExp(r'^.'), (m) => m[0]!.toUpperCase()),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        Tk.text(14, weight: FontWeight.w700, color: Tk.inkSoft),
                  ),
                  const SizedBox(height: 12),
                  TkSegmented(
                    labels: const ['Tuần', 'Giai đoạn', 'Cả lộ trình'],
                    selected: PeriodTab.values.indexOf(_period),
                    onChanged: (i) => _onPeriodChanged(PeriodTab.values[i]),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _MetricCard(
                      icon: Icons.local_fire_department_rounded,
                      iconColor: Tk.orange,
                      eyebrow: 'CHUỖI HIỆN TẠI',
                      eyebrowColor: Tk.orangeInk,
                      value: streakLabel.isEmpty ? '—' : streakLabel,
                      note: streakLabel.isEmpty
                          ? 'Tập một buổi để bắt đầu'
                          : 'Tuần nào cũng có tập',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MetricCard(
                      icon: Icons.track_changes_rounded,
                      iconColor: Tk.primary,
                      eyebrow: 'FORM CHUẨN TB',
                      eyebrowColor: Tk.primaryLip,
                      value: formSummary == null
                          ? '…'
                          : (formSummary.average == null
                              ? '—'
                              : '${formSummary.average}%'),
                      note: formSummary == null
                          ? 'Đang tải'
                          : (formSummary.average == null
                              ? 'Chưa có buổi nào'
                              : formSummary.fact),
                      noteColor: formSummary?.direction == FormTrendDirection.up
                          ? Tk.greenInk
                          : Tk.inkSoft,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: TkCard(
                radius: 18,
                lip: false,
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Text(
                            recent.isEmpty
                                ? 'Điểm form từng buổi'
                                : 'Điểm form ${recent.length} buổi gần nhất',
                            style: Tk.text(15, weight: FontWeight.w900),
                          ),
                        ),
                        Text('Càng cao càng tốt',
                            style: Tk.text(12,
                                weight: FontWeight.w800, color: Tk.inkSoft)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (recent.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        child: Text(
                          programSummary == null
                              ? 'Đang tải…'
                              : 'Tập buổi đầu tiên để thấy điểm form ở đây.',
                          textAlign: TextAlign.center,
                          style: Tk.text(14,
                              weight: FontWeight.w700, color: Tk.inkSoft),
                        ),
                      )
                    else
                      _FormBars(values: recent, firstIndex: firstIndex),
                  ],
                ),
              ),
            ),
            if (weekly != null && weekly.sessions > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: TkCard(
                  radius: 18,
                  lip: false,
                  padding: const EdgeInsets.fromLTRB(4, 12, 4, 12),
                  child: Column(
                    children: [
                      Text('TUẦN NÀY', style: Tk.eyebrow()),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          _MiniStat(
                            value: '${weekly.sessions}',
                            label: 'Buổi tập',
                            delta: weekly.sessionsDelta == null
                                ? null
                                : _signedDelta(weekly.sessionsDelta!),
                          ),
                          _MiniStat(
                              value: _formatDuration(weekly.totalSeconds),
                              label: 'Thời gian'),
                          _MiniStat(
                            value: weekly.avgForm == null
                                ? '—'
                                : '${weekly.avgForm}',
                            label: 'Form TB',
                            delta: weekly.avgFormDelta == null
                                ? null
                                : _signedDelta(weekly.avgFormDelta!),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            if (nextMilestone != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(8, 10, 14, 10),
                  decoration: BoxDecoration(
                      color: const Color(0xFFFFF6EC),
                      borderRadius: BorderRadius.circular(18)),
                  child: Row(
                    children: [
                      if (showMascot)
                        const TkMascot(
                            asset: Tk.mascotTrophy, size: 76, bob: false)
                      else
                        const Padding(
                          padding: EdgeInsets.all(12),
                          child: Icon(Icons.emoji_events_rounded,
                              color: Tk.orange, size: 40),
                        ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('CỘT MỐC TIẾP THEO',
                                style: Tk.text(12,
                                    weight: FontWeight.w900,
                                    color: Tk.orangeInk,
                                    letterSpacing: 1)),
                            const SizedBox(height: 4),
                            Text(nextMilestone.label,
                                style: Tk.text(15,
                                    weight: FontWeight.w800, height: 1.3)),
                            if (unlocked > 0) ...[
                              const SizedBox(height: 4),
                              Text('Đã mở $unlocked cột mốc',
                                  style: Tk.text(12.5,
                                      weight: FontWeight.w700,
                                      color: Tk.inkSoft)),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: TkCard(
                onTap: _openPainSheet,
                radius: 16,
                padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                child: Row(
                  children: [
                    const Icon(Icons.accessibility_new_rounded,
                        color: Tk.red, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        (_painReports?.isNotEmpty ?? false)
                            ? 'Vùng đang đau · ${_painReports!.length} vùng'
                            : 'Ghi vùng đang đau',
                        style: Tk.text(15, weight: FontWeight.w900),
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: Tk.inkMuted),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 10),
              child: Text('BÀI TẬP TIẾN BỘ NHANH', style: Tk.eyebrow()),
            ),
            _buildInsightsSection(),
          ],
        ),
      ),
    );
  }

  void _openPainSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheet) => ConstrainedBox(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.9),
          child: Container(
            decoration: const BoxDecoration(
              color: Tk.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                            color: Tk.line,
                            borderRadius: BorderRadius.circular(3)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text('Vùng đang đau',
                        style: Tk.text(23, weight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text(
                      'Chạm vào vùng đang đau để Vika ghi lại.',
                      style: Tk.text(14.5,
                          weight: FontWeight.w700, color: Tk.inkSoft),
                    ),
                    const SizedBox(height: 12),
                    if (_painReports == null)
                      const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(
                            child:
                                CircularProgressIndicator(color: Tk.primary)),
                      )
                    else
                      BodyPainReporter(
                        reports: _painReports!,
                        gender: _gender == 'female'
                            ? BodyGender.female
                            : BodyGender.male,
                        onReport: (region, intensity, notes) async {
                          await _reportPain(region, intensity, notes);
                          setSheet(() {});
                        },
                        onResolve: (region) async {
                          await _resolvePain(region);
                          setSheet(() {});
                        },
                      ),
                    const SizedBox(height: 12),
                    Text(
                      'Đây là ghi chú của riêng bạn, không phải chẩn đoán. '
                      'Nếu cơn đau dữ dội hoặc kéo dài, bạn nên đi khám bác sĩ nhé.',
                      style: Tk.text(12.5,
                          weight: FontWeight.w600,
                          color: Tk.inkSoft,
                          height: 1.45),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Seconds → "Xh YY'" / "Xh" / "ZZ'" (e.g. 2h12', 13h, 45').
  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    if (minutes < 60) return "$minutes'";
    final hours = minutes ~/ 60;
    final rem = minutes % 60;
    return rem == 0
        ? '${hours}h'
        : "${hours}h${rem.toString().padLeft(2, '0')}'";
  }

  // ── Section builders (real data + progressive reveal / guided empties) ──

  Widget _buildInsightsSection() {
    // Preview: show the mock ranking so the cards are visible during design
    // review. Real path stays below (used once the flag is flipped off).
    if (_previewWithMock) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: ExerciseInsightGrid(insights: progressMockInsights),
      );
    }
    final insights = _insights;
    if (insights == null) {
      return const _SectionEmpty(message: 'Đang xếp hạng bài tập…');
    }
    if (insights.isEmpty) {
      return const _SectionEmpty(
        message: 'Chưa đủ dữ liệu để xếp hạng. Tập thêm vài buổi '
            'rồi quay lại nhé.',
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ExerciseInsightGrid(
        insights: [
          for (var i = 0; i < insights.length; i++)
            _insightToMock(insights[i], i),
        ],
      ),
    );
  }

  /// Maps one ranked headline → the card's `ExerciseInsightMock`. Display name
  /// resolves via the exercise catalog (falls back to the raw id). Form and
  /// fault tiers format their metric / stat differently; the per-session
  /// [RankInsightHeadline.series] drives the bar chart.
  ExerciseInsightMock _insightToMock(RankInsightHeadline h, int index) {
    final idx = (index + 1).toString().padLeft(2, '0');
    final name = lookupExerciseDefinition(h.exerciseId)?.name ?? h.exerciseId;

    if (h.tier == InsightTier.form) {
      final delta = h.toValue - h.fromValue;
      return ExerciseInsightMock(
        idx: idx,
        name: name,
        metric: 'Điểm form',
        directionHint: 'Càng cao càng tốt',
        improvement: 'Form tăng $delta',
        stat: '+$delta',
        lowerIsBetter: false,
        from: '${h.fromValue}',
        to: '${h.toValue}',
        chart: h.series,
      );
    }

    // Pain / generic fault tiers: fault rate as % of reps, falling = better.
    final delta = h.fromValue - h.toValue;
    return ExerciseInsightMock(
      idx: idx,
      name: name,
      metric: h.metricLabel ?? 'Lỗi',
      directionHint: 'Càng thấp càng tốt',
      improvement: 'Lỗi giảm $delta%',
      stat: '−$delta%',
      lowerIsBetter: true,
      from: '${h.fromValue}%',
      to: '${h.toValue}%',
      chart: h.series,
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// GAUGE PLACEHOLDER — muted stand-in shown in the ScoreGaugeCard slot
// while the form summary loads, or when the selected period has no
// sessions yet. Premium Ivory tokens only.
// ═══════════════════════════════════════════════════════════════

// ═══════════════════════════════════════════════════════════════
// PAIN PLACEHOLDER — muted stand-in in the silhouette slot while the
// active pain reports load. Premium Ivory tokens only.
// ═══════════════════════════════════════════════════════════════

// ═══════════════════════════════════════════════════════════════
// WEEKLY BAND PLACEHOLDER — stand-in in the WeeklySummaryBand slot
// while it loads, or a guided empty when no session landed this week.
// ═══════════════════════════════════════════════════════════════

// ═══════════════════════════════════════════════════════════════
// RAIL PLACEHOLDER — muted stand-in in the PR rail slot while the
// records load.
// ═══════════════════════════════════════════════════════════════

// ═══════════════════════════════════════════════════════════════
// SECTION EMPTY — generic guided empty card for a section with no
// data yet. Quiet, never a fabricated number.
// ═══════════════════════════════════════════════════════════════

class _SectionEmpty extends StatelessWidget {
  const _SectionEmpty({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 24),
      decoration: BoxDecoration(
        color: c.bgRaised,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: c.border),
      ),
      alignment: Alignment.center,
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: 'BeVietnamPro',
          fontSize: 13,
          fontWeight: FontWeight.w500,
          fontStyle: FontStyle.italic,
          height: 1.5,
          letterSpacing: -0.1,
          color: c.inkSoft,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// SECTION HEADER — eyebrow + accent bar + rule + meta + intro.
// Mirrors the Library section grammar so the two tabs read as one
// publication.
// ═══════════════════════════════════════════════════════════════

// ═══════════════════════════════════════════════════════════════
// SCROLL-DOWN FAB — "Xuống cuối" pill that slides up from the
// bottom-right while heading down a long page, mirroring Hồ sơ.
// ═══════════════════════════════════════════════════════════════

// ═══════════════════════════════════════════════════════════════
// STICKY PILL BAR — slides in after the user scrolls past the
// stage hero. Carries brand mark + active-period label.
// ═══════════════════════════════════════════════════════════════

// ═══════════════════════════════════════════════════════════════
// CLOSER — editorial sign-off + back-to-top pill.
// ═══════════════════════════════════════════════════════════════

class _BackToTopButton extends StatefulWidget {
  const _BackToTopButton({required this.onTap});
  final VoidCallback onTap;

  @override
  State<_BackToTopButton> createState() => _BackToTopButtonState();
}

class _BackToTopButtonState extends State<_BackToTopButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onTap();
      },
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 0, 6, 0),
          height: 40,
          decoration: BoxDecoration(
            color: c.ink,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Lên đầu',
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  fontStyle: FontStyle.italic,
                  letterSpacing: -0.2,
                  color: c.invInk,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: c.yellow,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.arrow_upward_rounded,
                  size: 14,
                  color: c.yellowInk,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.iconColor,
    required this.eyebrow,
    required this.eyebrowColor,
    required this.value,
    required this.note,
    this.noteColor = Tk.inkSoft,
  });

  final IconData icon;
  final Color iconColor;
  final String eyebrow;
  final Color eyebrowColor;
  final String value;
  final String note;
  final Color noteColor;

  @override
  Widget build(BuildContext context) {
    return TkCard(
      radius: 18,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: iconColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  eyebrow,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Tk.text(11.5,
                      weight: FontWeight.w900,
                      color: eyebrowColor,
                      letterSpacing: 0.6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Tk.text(26, weight: FontWeight.w900, height: 1.15)),
          const SizedBox(height: 2),
          Text(note,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Tk.text(12.5,
                  weight: FontWeight.w800, color: noteColor, height: 1.3)),
        ],
      ),
    );
  }
}

class _FormBars extends StatelessWidget {
  const _FormBars({required this.values, required this.firstIndex});

  final List<int> values;
  final int firstIndex;

  @override
  Widget build(BuildContext context) {
    final lo = values.reduce((a, b) => a < b ? a : b);
    final floor = (lo - 15).clamp(0, 100);
    return SizedBox(
      height: 150,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < values.length; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    '${values[i]}',
                    style: Tk.text(11,
                        weight: FontWeight.w900,
                        color: i == values.length - 1
                            ? Tk.primaryLip
                            : Tk.inkSoft),
                  ),
                  const SizedBox(height: 4),
                  TweenAnimationBuilder<double>(
                    tween: Tween(
                        begin: 0,
                        end: ((values[i] - floor) / (100 - floor))
                            .clamp(0.06, 1.0)),
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeOutCubic,
                    builder: (context, f, _) => Container(
                      height: 100 * f,
                      decoration: BoxDecoration(
                        color: i == values.length - 1
                            ? Tk.primary
                            : Tk.primaryLine,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(8),
                            bottom: Radius.circular(4)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text('B${firstIndex + i + 1}',
                      style: Tk.text(11,
                          weight: FontWeight.w800, color: Tk.inkSoft)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.value, required this.label, this.delta});

  final String value;
  final String label;
  final String? delta;

  @override
  Widget build(BuildContext context) {
    final up = delta != null && !delta!.startsWith('-');
    return Expanded(
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(value, style: Tk.text(20, weight: FontWeight.w900)),
              if (delta != null && delta != '+0') ...[
                const SizedBox(width: 4),
                Text(delta!,
                    style: Tk.text(12,
                        weight: FontWeight.w900,
                        color: up ? Tk.greenInk : Tk.redInk)),
              ],
            ],
          ),
          Text(label,
              style: Tk.text(12, weight: FontWeight.w800, color: Tk.inkSoft)),
        ],
      ),
    );
  }
}
