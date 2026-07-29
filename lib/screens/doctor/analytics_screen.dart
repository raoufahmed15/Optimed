// lib/screens/doctor/analytics_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/database.dart';
import '../../core/constants.dart';
import '../../core/language_provider.dart';
import '../../widgets/stat_card.dart';

const Color kOptiBlue = Color(0xFF0070BB);

class AnalyticsScreen extends StatefulWidget {
  final Map<String, dynamic> stats;
  const AnalyticsScreen({super.key, required this.stats});

  @override
  State<AnalyticsScreen> createState() => AnalyticsScreenState();
}

class AnalyticsScreenState extends State<AnalyticsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // ── Clinic Analytics ──────────────────────────────────────────────────────
  DateTimeRange? _selectedDateRange;
  Map<String, double> _filteredEarnings = {'total': 0.0, 'average': 0.0};
  List<Map<String, dynamic>> _dynamicTypeStats = [];
  bool _isFiltering = false;

  // ── Nurse Stats ───────────────────────────────────────────────────────────
  DateTimeRange? _nurseSelectedDateRange;
  List<Map<String, dynamic>> _nurseStats = [];
  bool _isLoadingNurseStats = false;

  get _l => LanguageProvider.of(context).l;

  static int _safeInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v.trim()) ?? 0;
    return 0;
  }

  static double _safeDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.trim()) ?? 0.0;
    return 0.0;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    final now = DateTime.now();
    _selectedDateRange = DateTimeRange(
      start: DateTime(now.year, now.month, 1),
      end: now,
    );
    _nurseSelectedDateRange = DateTimeRange(
      start: DateTime(now.year, now.month, 1),
      end: now,
    );

    _refreshStats();
    _loadNurseStats();

    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        if (_tabController.index == 1) _loadNurseStats();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant AnalyticsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.stats != oldWidget.stats) _refreshStats();
  }

  void refreshAll() {
    _refreshStats();
    _loadNurseStats();
  }

  // ════════════════════════════════════════════════════════════════════════════
  //  Clinic Analytics
  // ════════════════════════════════════════════════════════════════════════════
  Future<void> _refreshStats() async {
    if (_selectedDateRange != null) {
      await _calculateEarningsForRange(_selectedDateRange!);
    }
  }

  Future<void> _calculateEarningsForRange(DateTimeRange range) async {
    if (!mounted) return;
    setState(() => _isFiltering = true);
    try {
      final startDate = DateFormat('yyyy-MM-dd').format(range.start);
      final endDate = DateFormat('yyyy-MM-dd').format(range.end);

      final totalRes = await DatabaseService.execute(
        '''SELECT SUM(CAST(fee AS DECIMAL(10,2))) as total 
           FROM patients 
           WHERE date >= :start AND date <= :end 
           AND status IN ('completed', 'archived')''',
        {'start': startDate, 'end': endDate},
      );
      final rawTotal = totalRes.rows.isNotEmpty
          ? totalRes.rows.first.assoc()['total']
          : null;
      final double total = _safeDouble(rawTotal);

      final typeRes = await DatabaseService.execute(
        '''SELECT visit_type, COUNT(*) as count 
           FROM patients 
           WHERE date >= :start AND date <= :end 
           AND status IN ('completed', 'archived')
           GROUP BY visit_type''',
        {'start': startDate, 'end': endDate},
      );

      final int days = range.end.difference(range.start).inDays + 1;

      if (mounted) {
        setState(() {
          _filteredEarnings = {
            'total': total,
            'average': total / (days > 0 ? days : 1),
          };
          _dynamicTypeStats = typeRes.rows.map((row) {
            final assoc = row.assoc();
            return <String, dynamic>{
              'visit_type': assoc['visit_type'] ?? '',
              'count': _safeInt(assoc['count']),
            };
          }).toList();
        });
      }
    } catch (e) {
      debugPrint("Error calculating stats: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${_l.errorLabel}: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isFiltering = false);
    }
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: _selectedDateRange,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
              primary: kOptiBlue,
              onPrimary: Colors.white,
              onSurface: Colors.black),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _selectedDateRange = picked);
      _calculateEarningsForRange(picked);
    }
  }

  int _getTotalCount() =>
      _dynamicTypeStats.fold(0, (sum, item) => sum + _safeInt(item['count']));

  // ════════════════════════════════════════════════════════════════════════════
  //  Nurse Stats
  // ════════════════════════════════════════════════════════════════════════════
  Future<void> _loadNurseStats() async {
    if (!mounted) return;
    setState(() => _isLoadingNurseStats = true);

    try {
      final range = _nurseSelectedDateRange!;
      final startDate = DateFormat('yyyy-MM-dd').format(range.start);
      final endDate = DateFormat('yyyy-MM-dd').format(range.end);

      // ── Query 1: totals per nurse ─────────────────────────────────────
      final result = await DatabaseService.execute(
        """
        SELECT
          nurse_username,
          MAX(nurse)                                       AS nurse_display_name,
          COUNT(*)                                         AS total_sent,
          SUM(
           CASE WHEN status = 'completed'
                 THEN 1 ELSE 0 END
          )                                                AS total_completed,
          SUM(
            CASE WHEN status = 'archived'
                 THEN 1 ELSE 0 END
          )                                                AS total_deleted,
          COALESCE(
            SUM(
              CASE WHEN status = 'completed'
                   THEN CAST(fee AS DECIMAL(10,2))
                   ELSE 0 END
            ), 0
          )                                                AS total_earnings
        FROM patients
        WHERE
          nurse_username IS NOT NULL
          AND nurse_username != ''
          AND nurse_username != 'غير معروف'
          AND nurse != 'غير معروف'
          AND date >= :start
          AND date <= :end
        GROUP BY nurse_username
        ORDER BY total_completed DESC
        """,
        {'start': startDate, 'end': endDate},
      );

      // ── Query 2: breakdown by visit_type per nurse ────────────────────
      final breakdownResult = await DatabaseService.execute(
        """
        SELECT
          nurse_username,
          COALESCE(visit_type, 'Other') AS visit_type,
          COUNT(*)                      AS count,
          COALESCE(
            SUM(
              CASE WHEN status IN ('completed','archived')
                   THEN CAST(fee AS DECIMAL(10,2))
                   ELSE 0 END
            ), 0
          )                             AS earnings
        FROM patients
        WHERE
          nurse_username IS NOT NULL
          AND nurse_username != ''
          AND nurse_username != 'غير معروف'
          AND nurse != 'غير معروف'
          AND date >= :start
          AND date <= :end
        GROUP BY nurse_username, visit_type
        ORDER BY nurse_username, count DESC
        """,
        {'start': startDate, 'end': endDate},
      );

      // ── Group breakdown by nurse_username ─────────────────────────────
      final Map<String, List<Map<String, dynamic>>> breakdownByNurse = {};
      for (final row in breakdownResult.rows) {
        final a = row.assoc();
        final username = a['nurse_username']?.toString() ?? '';
        breakdownByNurse.putIfAbsent(username, () => []);
        breakdownByNurse[username]!.add({
          'visit_type': a['visit_type']?.toString() ?? 'Other',
          'count': _safeInt(a['count']),
          'earnings': _safeDouble(a['earnings']),
        });
      }

      // ── Merge ─────────────────────────────────────────────────────────
      final List<Map<String, dynamic>> stats = result.rows.map((row) {
        final a = row.assoc();
        final username = a['nurse_username']?.toString() ?? '';
        final displayName = a['nurse_display_name']?.toString() ?? username;

        return <String, dynamic>{
          'username': username,
          'name': displayName.isNotEmpty ? displayName : username,
          'total_sent': _safeInt(a['total_sent']),
          'total_completed': _safeInt(a['total_completed']),
          'total_deleted': _safeInt(a['total_deleted']),
          'total_earnings': _safeDouble(a['total_earnings']),
          'breakdown': breakdownByNurse[username] ?? [],
        };
      }).toList();

      if (mounted) setState(() => _nurseStats = stats);
    } catch (e) {
      debugPrint('❌ Error loading nurse stats: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_l.nurseLoadError}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingNurseStats = false);
    }
  }

  Future<void> _selectNurseDateRange(BuildContext context) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: _nurseSelectedDateRange,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
              primary: kOptiBlue,
              onPrimary: Colors.white,
              onSurface: Colors.black),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _nurseSelectedDateRange = picked);
      _loadNurseStats();
    }
  }

  // ════════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final l = _l;
    return Column(
      children: [
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabController,
            indicatorColor: kOptiBlue,
            labelColor: kOptiBlue,
            unselectedLabelColor: Colors.grey,
            tabs: [
              Tab(
                  icon: const Icon(Icons.bar_chart_rounded),
                  text: l.tabClinicStats),
              Tab(
                  icon: const Icon(Icons.people_alt_outlined),
                  text: l.tabNursePerf),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildClinicTab(l),
              _buildNurseTab(l),
            ],
          ),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  //  TAB 1 — إحصائيات العيادة
  // ════════════════════════════════════════════════════════════════════════════
  Widget _buildClinicTab(l) {
    return RefreshIndicator(
      onRefresh: _refreshStats,
      color: kOptiBlue,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildDateSelector(l),
            const SizedBox(height: 20),
            _buildDynamicEarningsCard(l),
            const SizedBox(height: 24),
            _buildSectionTitle(l.statsForPeriod),
            Row(
              children: [
                Expanded(
                  child: StatCard(
                    title: l.totalPatients,
                    value: '${_getTotalCount()}',
                    unit: l.cases,
                    icon: Icons.people_outline,
                    color: kOptiBlue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatCard(
                    title: l.dailyAverage,
                    value:
                        '${_filteredEarnings['average']?.toStringAsFixed(0)}',
                    unit: 'EGP',
                    icon: Icons.account_balance_wallet_outlined,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildSectionTitle(l.serviceDistrib),
            _buildDynamicServiceAnalysis(l),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  //  TAB 2 — أداء الممرضات
  // ════════════════════════════════════════════════════════════════════════════
  Widget _buildNurseTab(l) {
    return RefreshIndicator(
      onRefresh: _loadNurseStats,
      color: kOptiBlue,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Date picker ───────────────────────────────────────────────
            InkWell(
              onTap: () => _selectNurseDateRange(context),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: kOptiBlue.withOpacity(0.1)),
                  boxShadow: [
                    BoxShadow(color: kOptiBlue.withOpacity(0.05), blurRadius: 5)
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.date_range_rounded, color: kOptiBlue),
                    const SizedBox(width: 15),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l.nursePeriodLabel,
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey)),
                        Text(
                          "${DateFormat('dd/MM').format(_nurseSelectedDateRange!.start)}"
                          "  →  "
                          "${DateFormat('dd/MM/yyyy').format(_nurseSelectedDateRange!.end)}",
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, color: kOptiBlue),
                        ),
                      ],
                    ),
                    const Spacer(),
                    const Icon(Icons.swap_horiz, color: kOptiBlue),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ── Info note ─────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.amber, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l.nurseCompletedNote,
                      style:
                          const TextStyle(fontSize: 12, color: Colors.black87),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Summary row ───────────────────────────────────────────────
            if (!_isLoadingNurseStats && _nurseStats.isNotEmpty) ...[
              _buildNurseSummaryRow(l),
              const SizedBox(height: 20),
            ],

            // ── Content ───────────────────────────────────────────────────
            if (_isLoadingNurseStats)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(color: kOptiBlue),
                ),
              )
            else if (_nurseStats.isEmpty)
              Container(
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15)),
                child: Center(
                  child: Column(
                    children: [
                      const Icon(Icons.people_outline,
                          size: 48, color: Colors.grey),
                      const SizedBox(height: 12),
                      Text(
                        l.noNurseData,
                        style: const TextStyle(
                            color: Colors.grey, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l.noNurseDataHint,
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              )
            else
              ..._nurseStats
                  .asMap()
                  .entries
                  .map((entry) => _buildNurseCard(entry.value, entry.key, l)),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildNurseSummaryRow(l) {
    final totalSent =
        _nurseStats.fold(0, (s, n) => s + _safeInt(n['total_sent']));
    final totalCompleted =
        _nurseStats.fold(0, (s, n) => s + _safeInt(n['total_completed']));
    final totalDeleted =
        _nurseStats.fold(0, (s, n) => s + _safeInt(n['total_deleted']));
    final totalEarnings =
        _nurseStats.fold(0.0, (s, n) => s + _safeDouble(n['total_earnings']));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: _summaryBox(
              icon: Icons.send_rounded,
              color: Colors.blue,
              label: l.nurseSummaryTotal,
              value: '$totalSent',
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _summaryBox(
              icon: Icons.check_circle_outline,
              color: Colors.green,
              label: l.nurseSummaryCompleted,
              value: '$totalCompleted',
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _summaryBox(
              icon: Icons.delete_forever,
              color: Colors.red,
              label: l.nurseSummaryDeleted,
              value: '$totalDeleted',
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _summaryBox(
              icon: Icons.account_balance_wallet_outlined,
              color: Colors.orange,
              label: l.nurseSummaryEarnings,
              value: totalEarnings.toStringAsFixed(0),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryBox(
      {required IconData icon,
      required Color color,
      required String label,
      required String value}) {
    return Container(
      constraints: const BoxConstraints(minHeight: 85),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildNurseCard(Map<String, dynamic> nurse, int rank, l) {
    final name = nurse['name']?.toString() ?? '';
    final username = nurse['username']?.toString() ?? '';
    final totalSent = _safeInt(nurse['total_sent']);
    final totalCompleted = _safeInt(nurse['total_completed']);
    final totalEarnings = _safeDouble(nurse['total_earnings']);
    final breakdown =
        (nurse['breakdown'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    final completionPct =
        totalSent > 0 ? (totalCompleted / totalSent * 100) : 0.0;
    final completionStr = completionPct.toStringAsFixed(0);

    final rankColors = [
      const Color(0xFFFFD700),
      const Color(0xFFC0C0C0),
      const Color(0xFFCD7F32)
    ];
    final rankColor = rank < 3 ? rankColors[rank] : kOptiBlue.withOpacity(0.6);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 3))
        ],
      ),
      child: Column(
        children: [
          // ── Header ───────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: rankColor.withOpacity(0.12),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration:
                      BoxDecoration(color: rankColor, shape: BoxShape.circle),
                  child: Center(
                      child: Text('${rank + 1}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15))),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name.isNotEmpty ? name : username,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('@$username',
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                  ),
                  child: Text('${totalEarnings.toStringAsFixed(0)} EGP',
                      style: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 13)),
                ),
              ],
            ),
          ),

          // ── Body ─────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Sent / Completed / Deleted chips
                Row(
                  children: [
                    _statChip(
                        icon: Icons.send,
                        color: kOptiBlue,
                        label: l.nurseSentLabel,
                        value: '$totalSent'),
                    const SizedBox(width: 10),
                    _statChip(
                        icon: Icons.check_circle,
                        color: Colors.green,
                        label: l.nurseCompletedLabel,
                        value: '$totalCompleted'),
                    const SizedBox(width: 10),
                    _statChip(
                        icon: Icons.delete_forever,
                        color: Colors.red,
                        label: l.nurseDeletedLabel,
                        value: '${_safeInt(nurse['total_deleted'])}'),
                  ],
                ),
                const SizedBox(height: 12),

                // Completion rate bar
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(l.nurseCompletionRate,
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey)),
                        Text('$completionStr%',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color:
                                    _completionColor(completionPct.toInt()))),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: totalSent > 0 ? totalCompleted / totalSent : 0.0,
                        color: _completionColor(completionPct.toInt()),
                        backgroundColor: Colors.grey.withOpacity(0.15),
                        minHeight: 8,
                      ),
                    ),
                  ],
                ),

                // ── Visit Type Breakdown ──────────────────────────────────
                if (breakdown.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  ...breakdown.map((item) {
                    final type = item['visit_type'].toString();
                    final count = _safeInt(item['count']);
                    final earnings = _safeDouble(item['earnings']);
                    final pct = totalSent > 0 ? count / totalSent : 0.0;
                    final color = _getColorForType(type);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                        color: color, shape: BoxShape.circle),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(type,
                                      style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600)),
                                  const SizedBox(width: 6),
                                  Text('($count)',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600)),
                                ],
                              ),
                              Text(
                                '${earnings.toStringAsFixed(0)} EGP',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: color),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: pct,
                              color: color,
                              backgroundColor: color.withOpacity(0.1),
                              minHeight: 6,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _completionColor(int pct) {
    if (pct >= 80) return Colors.green;
    if (pct >= 50) return Colors.orange;
    return Colors.red;
  }

  Widget _statChip(
      {required IconData icon,
      required Color color,
      required String label,
      required String value}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
            color: color.withOpacity(0.07),
            borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: color)),
                Text(label,
                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDynamicServiceAnalysis(l) {
    if (_dynamicTypeStats.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(15)),
        child: Center(
            child: Text(l.noRecordsFound,
                style: const TextStyle(
                    color: Colors.grey, fontWeight: FontWeight.bold))),
      );
    }
    final int total = _getTotalCount();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)
        ],
      ),
      child: Column(
        children: _dynamicTypeStats.map((data) {
          final String title = (data['visit_type'] ?? 'Other').toString();
          final int dataCount = _safeInt(data['count']);
          final double percent = total > 0 ? dataCount / total : 0.0;
          return _serviceRow(
              title, dataCount, percent, _getColorForType(title), l);
        }).toList(),
      ),
    );
  }

  Color _getColorForType(String title) {
    if (title.contains("كشف") || title.contains("Examination"))
      return kOptiBlue;
    if (title.contains("استشارة") || title.contains("Follow-up"))
      return Colors.teal;
    return Colors.orange;
  }

  Widget _buildDateSelector(l) {
    return InkWell(
      onTap: () => _selectDateRange(context),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: kOptiBlue.withOpacity(0.1)),
          boxShadow: [
            BoxShadow(color: kOptiBlue.withOpacity(0.05), blurRadius: 5)
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.date_range_rounded, color: kOptiBlue),
            const SizedBox(width: 15),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.displayedPeriod,
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
                Text(
                  "${DateFormat('dd/MM').format(_selectedDateRange!.start)}  ${l.toWord}  ${DateFormat('dd/MM/yyyy').format(_selectedDateRange!.end)}",
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: kOptiBlue),
                ),
              ],
            ),
            const Spacer(),
            const Icon(Icons.swap_horiz, color: kOptiBlue),
          ],
        ),
      ),
    );
  }

  Widget _buildDynamicEarningsCard(l) {
    return Container(
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [kOptiBlue, Color(0xFF004E82)],
        ),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
              color: kOptiBlue.withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 8))
        ],
      ),
      child: Column(
        children: [
          Text(l.totalEarnings,
              style: const TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 12),
          _isFiltering
              ? const SizedBox(
                  height: 40,
                  child: CircularProgressIndicator(color: Colors.white))
              : FittedBox(
                  child: Text(
                    "${_filteredEarnings['total']?.toStringAsFixed(0)} EGP",
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 38,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _serviceRow(String title, int count, double percent, Color color, l) {
    final int pct = (percent * 100).toInt();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15)),
              Text(l.casesCount(count, pct),
                  style: TextStyle(
                      color: color, fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
                value: percent,
                color: color,
                backgroundColor: color.withOpacity(0.1),
                minHeight: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15, top: 10, right: 5),
      child: Text(title,
          style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Colors.black87)),
    );
  }
}
