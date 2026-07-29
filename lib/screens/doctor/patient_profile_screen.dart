// lib/screens/dashboard/patient_profile_screen.dart
// ✅ UPDATED: عرض amount_paid, remaining, credit, visit_date في كل كشف

import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/database.dart';
import '../../core/custom_fields_db.dart';
import 'custom_fields_widget.dart';

const Color kOptiBlue = Color(0xFF0070BB);
const Color kAccent = Color(0xFF00A8E8);

class PatientProfileScreen extends StatefulWidget {
  final String patientName;
  final String? patientPhone;
  final int doctorId;

  const PatientProfileScreen({
    super.key,
    required this.patientName,
    this.patientPhone,
    this.doctorId = 0,
  });

  @override
  State<PatientProfileScreen> createState() => _PatientProfileScreenState();
}

class _PatientProfileScreenState extends State<PatientProfileScreen> {
  List<Map<String, dynamic>> _visits = [];
  bool _isLoading = true;

  Timer? _pollingTimer;
  String _lastSnapshot = '';

  // ══════════════════════════════════════════════════════════════════════════
  //  POLLING
  // ══════════════════════════════════════════════════════════════════════════
  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer =
        Timer.periodic(const Duration(seconds: 10), (_) => _pollForChanges());
    debugPrint('🔄 Profile polling started');
  }

  void _stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _lastSnapshot = '';
    debugPrint('⏹️ Profile polling stopped');
  }

  Future<void> _pollForChanges() async {
    if (!mounted) return;
    try {
      final results = await DatabaseService.getAllVisits(
          widget.patientName, widget.patientPhone);
      final newSnapshot = results.map((r) => r.toString()).join('|');
      if (newSnapshot != _lastSnapshot && _lastSnapshot.isNotEmpty) {
        debugPrint('🔔 Profile: changes detected — refreshing');
        _lastSnapshot = newSnapshot;
        if (mounted) {
          setState(() => _visits =
              results.map((r) => Map<String, dynamic>.from(r)).toList());
          _showUpdateBanner();
        }
      } else {
        _lastSnapshot = newSnapshot;
      }
    } catch (_) {}
  }

  void _showUpdateBanner() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(children: [
          Icon(Icons.sync_rounded, color: Colors.white, size: 16),
          SizedBox(width: 8),
          Text('تم تحديث البيانات', style: TextStyle(fontSize: 13)),
        ]),
        backgroundColor: Colors.blueGrey.shade600,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  LIFECYCLE
  // ══════════════════════════════════════════════════════════════════════════
  @override
  void initState() {
    super.initState();
    _loadPatientHistory();
  }

  @override
  void dispose() {
    _stopPolling();
    super.dispose();
  }

  Future<void> _loadPatientHistory() async {
    try {
      final results = await DatabaseService.getAllVisits(
          widget.patientName, widget.patientPhone);
      if (mounted) {
        final newSnapshot = results.map((r) => r.toString()).join('|');
        _lastSnapshot = newSnapshot;
        setState(() {
          _visits = results.map((r) => Map<String, dynamic>.from(r)).toList();
          _isLoading = false;
        });
        _startPolling();
      }
    } catch (e) {
      debugPrint('_loadPatientHistory error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  VISIT TYPE HELPERS
  // ══════════════════════════════════════════════════════════════════════════
  Future<List<Map<String, dynamic>>> _fetchVisitTypes() async {
    try {
      final raw = await DatabaseService.getSetting('visit_types_list');
      if (raw != null && raw.isNotEmpty) {
        return (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      }
    } catch (e) {
      debugPrint('[_fetchVisitTypes] error: $e');
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> _refreshVisitTypesFromServer() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final doctorIp = prefs.getString('doctor_ip') ?? '127.0.0.1';
      final response = await http
          .get(Uri.parse('http://$doctorIp:8080/visit-types'))
          .timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as List;
        final types = decoded.cast<Map<String, dynamic>>();
        if (types.isNotEmpty) {
          await DatabaseService.updateSetting(
              'visit_types_list', response.body);
        }
        return types;
      }
    } catch (e) {
      debugPrint('[_refreshVisitTypesFromServer] error: $e');
    }
    return await _fetchVisitTypes();
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  EDIT VISIT DIALOG  ✅ UPDATED — يشمل amount_paid
  // ══════════════════════════════════════════════════════════════════════════
  void _openEditVisitDialog(Map<String, dynamic> visit) async {
    final List<Map<String, dynamic>> types =
        await _refreshVisitTypesFromServer();
    if (!mounted) return;

    final diagnosisCtrl = TextEditingController(text: visit['diagnosis'] ?? '');
    final treatmentCtrl = TextEditingController(text: visit['treatment'] ?? '');
    final notesCtrl = TextEditingController(text: visit['notes'] ?? '');
    final dateCtrl =
        TextEditingController(text: visit['date']?.toString() ?? '');
    final amountPaidCtrl = TextEditingController(
        text: _safeDouble(visit['amount_paid']) > 0
            ? _safeDouble(visit['amount_paid']).toStringAsFixed(0)
            : '');

    final String currentVisitType = visit['visit_type']?.toString() ?? 'كشف';
    final dynamic currentFee = visit['fee'] ?? 0.0;
    final bool hasTypes = types.isNotEmpty;
    final bool currentTypeExists =
        types.any((t) => t['name'].toString() == currentVisitType);

    final List<Map<String, dynamic>> effectiveTypes = hasTypes
        ? (currentTypeExists
            ? List<Map<String, dynamic>>.from(types)
            : [
                {'name': currentVisitType, 'price': currentFee},
                ...types,
              ])
        : <Map<String, dynamic>>[
            {'name': currentVisitType, 'price': currentFee},
          ];

    Map<String, dynamic> selectedType;
    try {
      selectedType = effectiveTypes
          .firstWhere((t) => t['name'].toString() == currentVisitType);
    } catch (_) {
      selectedType = effectiveTypes.first;
    }

    final feeCtrl =
        TextEditingController(text: selectedType['price'].toString());

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) {
          // حساب حالة الدفع live
          final fee = _safeDouble(selectedType['price']);
          final paid = double.tryParse(amountPaidCtrl.text.trim()) ?? 0.0;
          final diff = paid - fee;
          final remaining = diff < 0 ? diff.abs() : 0.0;
          final credit = diff > 0 ? diff : 0.0;
          final isPaidFull = diff == 0.0 && fee > 0;

          return Dialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Header ────────────────────────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: const BoxDecoration(
                    color: kOptiBlue,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          const Icon(Icons.edit_note,
                              color: Colors.white, size: 22),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text('تعديل الكشف',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold)),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                                color: Colors.amber.shade600,
                                borderRadius: BorderRadius.circular(8)),
                            child: const Row(children: [
                              Icon(Icons.admin_panel_settings,
                                  color: Colors.white, size: 13),
                              SizedBox(width: 4),
                              Text('دكتور فقط',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold)),
                            ]),
                          ),
                        ]),
                        const SizedBox(height: 6),
                        Text(
                          '${visit['name'] ?? ''}  •  ${visit['date'] ?? ''}',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 12),
                        ),
                      ]),
                ),

                // ── Body ─────────────────────────────────────────────────
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // تاريخ الكشف
                          _dlgLabel('📅 تاريخ الكشف'),
                          const SizedBox(height: 6),
                          GestureDetector(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: ctx,
                                initialDate: DateTime.tryParse(dateCtrl.text) ??
                                    DateTime.now(),
                                firstDate: DateTime(2000),
                                lastDate: DateTime.now(),
                                builder: (c, child) => Theme(
                                  data: Theme.of(c).copyWith(
                                      colorScheme: const ColorScheme.light(
                                          primary: kOptiBlue)),
                                  child: child!,
                                ),
                              );
                              if (picked != null) {
                                setDlg(() => dateCtrl.text =
                                    '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}');
                              }
                            },
                            child: AbsorbPointer(
                                child: _dlgField(
                                    dateCtrl, 'التاريخ', Icons.calendar_today)),
                          ),
                          const SizedBox(height: 14),

                          // نوع الكشف والسعر
                          _dlgLabel('🏥 نوع الكشف والسعر'),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<Map<String, dynamic>>(
                            value: selectedType,
                            isExpanded: true,
                            decoration: _dlgDecoration(
                                'نوع الكشف', Icons.medical_services),
                            items: effectiveTypes
                                .map((t) => DropdownMenuItem(
                                      value: t,
                                      child: Text(
                                          '${t['name']}  —  ${t['price']} EGP',
                                          overflow: TextOverflow.ellipsis),
                                    ))
                                .toList(),
                            onChanged: hasTypes
                                ? (v) => setDlg(() {
                                      selectedType = v!;
                                      feeCtrl.text = v['price'].toString();
                                    })
                                : null,
                          ),
                          const SizedBox(height: 10),
                          _dlgField(
                              feeCtrl, 'السعر (EGP)', Icons.payments_rounded,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              readOnly: true,
                              fillColor: Colors.grey.shade100,
                              helperText:
                                  'السعر بيتحدد أوتوماتيك من نوع الكشف'),
                          const SizedBox(height: 14),

                          // ✅ NEW — المبلغ المدفوع مع حساب تلقائي
                          _dlgLabel('💰 الدفع'),
                          const SizedBox(height: 6),
                          Row(children: [
                            Expanded(
                              child: TextField(
                                controller: amountPaidCtrl,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                onChanged: (_) => setDlg(() {}),
                                decoration: InputDecoration(
                                  labelText: 'المبلغ المدفوع (EGP)',
                                  prefixIcon: const Icon(
                                      Icons.payments_outlined,
                                      color: kOptiBlue,
                                      size: 18),
                                  suffixIcon: TextButton(
                                    onPressed: () {
                                      amountPaidCtrl.text =
                                          _safeDouble(selectedType['price'])
                                              .toStringAsFixed(0);
                                      setDlg(() {});
                                    },
                                    child: const Text('كامل',
                                        style: TextStyle(
                                            fontSize: 11, color: kOptiBlue)),
                                  ),
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                  focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                          color: kOptiBlue, width: 2)),
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 12),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            // بطاقة حالة الدفع
                            Container(
                              width: 110,
                              height: 56,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              decoration: BoxDecoration(
                                color: isPaidFull
                                    ? Colors.green.shade50
                                    : credit > 0
                                        ? Colors.blue.shade50
                                        : remaining > 0
                                            ? Colors.orange.shade50
                                            : Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isPaidFull
                                      ? Colors.green.shade300
                                      : credit > 0
                                          ? Colors.blue.shade300
                                          : remaining > 0
                                              ? Colors.orange.shade300
                                              : Colors.grey.shade200,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isPaidFull
                                        ? 'مدفوع كامل ✅'
                                        : credit > 0
                                            ? 'رصيد: ${credit.toStringAsFixed(0)}'
                                            : remaining > 0
                                                ? 'باقي: ${remaining.toStringAsFixed(0)}'
                                                : '--',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: isPaidFull
                                          ? Colors.green.shade700
                                          : credit > 0
                                              ? kOptiBlue
                                              : Colors.orange.shade800,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ]),
                          const SizedBox(height: 14),

                          // التشخيص
                          _dlgLabel('🩺 التشخيص'),
                          const SizedBox(height: 6),
                          _dlgField(
                              diagnosisCtrl, 'التشخيص', Icons.local_hospital,
                              maxLines: 4),
                          const SizedBox(height: 14),

                          // خطة العلاج
                          _dlgLabel('💊 خطة العلاج / الأدوية'),
                          const SizedBox(height: 6),
                          _dlgField(treatmentCtrl, 'خطة العلاج والأدوية',
                              Icons.medication,
                              maxLines: 4),
                          const SizedBox(height: 14),

                          // ملاحظات
                          _dlgLabel('📝 ملاحظات'),
                          const SizedBox(height: 6),
                          _dlgField(notesCtrl, 'ملاحظات إضافية', Icons.notes,
                              maxLines: 3),
                        ]),
                  ),
                ),

                // ── Actions ───────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                  child: Row(children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.grey,
                          side: BorderSide(color: Colors.grey.shade300),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('إلغاء'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kOptiBlue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.save_rounded, size: 18),
                        label: const Text('حفظ التعديلات',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: () async {
                          final newType = selectedType['name'].toString();
                          final newFee = _safeDouble(selectedType['price']);
                          final newPaid =
                              double.tryParse(amountPaidCtrl.text.trim()) ??
                                  0.0;
                          final newDiff = newPaid - newFee;
                          final newRemain = newDiff < 0 ? newDiff.abs() : 0.0;
                          final newCredit = newDiff > 0 ? newDiff : 0.0;

                          Navigator.pop(ctx);
                          await _saveFullVisitEdit(visit, {
                            'date': dateCtrl.text.trim(),
                            'visit_type': newType,
                            'fee': newFee,
                            'amount_paid': newPaid, // ✅ NEW
                            'remaining': newRemain, // ✅ NEW
                            'credit': newCredit, // ✅ NEW
                            'diagnosis': diagnosisCtrl.text.trim(),
                            'treatment': treatmentCtrl.text.trim(),
                            'notes': notesCtrl.text.trim(),
                          });
                        },
                      ),
                    ),
                  ]),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ✅ UPDATED — يحفظ amount_paid, remaining, credit
  Future<void> _saveFullVisitEdit(
    Map<String, dynamic> visit,
    Map<String, dynamic> updates,
  ) async {
    try {
      final conn = await DatabaseService.database;
      final id = visit['id'];

      await conn.execute(
        '''UPDATE patients SET
          date        = :date,
          visit_type  = :visit_type,
          fee         = :fee,
          amount_paid = :amount_paid,
          remaining   = :remaining,
          credit      = :credit,
          diagnosis   = :diagnosis,
          treatment   = :treatment,
          notes       = :notes
        WHERE id = :id''',
        {
          'date': updates['date'],
          'visit_type': updates['visit_type'],
          'fee': updates['fee'],
          'amount_paid': updates['amount_paid'], // ✅ NEW
          'remaining': updates['remaining'], // ✅ NEW
          'credit': updates['credit'], // ✅ NEW
          'diagnosis': updates['diagnosis'],
          'treatment': updates['treatment'],
          'notes': updates['notes'],
          'id': id,
        },
      );

      await _loadPatientHistory();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ تم حفظ تعديلات الكشف'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('خطأ: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  HELPERS
  // ══════════════════════════════════════════════════════════════════════════
  static double _safeDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString().trim()) ?? 0.0;
  }

  Widget _dlgLabel(String text) => Text(text,
      style: const TextStyle(
          fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blueGrey));

  InputDecoration _dlgDecoration(String label, IconData icon,
      {Color? fillColor, String? helperText}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: kOptiBlue, size: 18),
      filled: fillColor != null,
      fillColor: fillColor,
      helperText: helperText,
      helperStyle: TextStyle(fontSize: 10, color: Colors.grey.shade500),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kOptiBlue, width: 2)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }

  Widget _dlgField(TextEditingController ctrl, String label, IconData icon,
      {int maxLines = 1,
      TextInputType keyboardType = TextInputType.text,
      bool readOnly = false,
      Color? fillColor,
      String? helperText}) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      keyboardType: keyboardType,
      readOnly: readOnly,
      decoration: _dlgDecoration(label, icon,
          fillColor: fillColor, helperText: helperText),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  COMPUTED PROPERTIES
  // ══════════════════════════════════════════════════════════════════════════
  Map<String, dynamic> get _patientInfo {
    if (_visits.isEmpty) return {};
    final sorted = List<Map<String, dynamic>>.from(_visits)
      ..sort((a, b) {
        final da =
            DateTime.tryParse(a['date']?.toString() ?? '') ?? DateTime(2000);
        final db =
            DateTime.tryParse(b['date']?.toString() ?? '') ?? DateTime(2000);
        return db.compareTo(da);
      });
    return sorted.first;
  }

  int get _totalVisits => _visits.length;
  int get _completedVisits =>
      _visits.where((v) => v['status']?.toString() == 'completed').length;

  // ══════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F6FC),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: kOptiBlue))
          : CustomScrollView(slivers: [
              _buildSliverAppBar(),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildStatsRow(),
                      const SizedBox(height: 16),
                      _buildFinancialSummary(), // ✅ NEW — ملخص مالي كامل
                      const SizedBox(height: 20),
                      _buildPersonalInfoCard(),
                      const SizedBox(height: 20),
                      _buildVisitsTimeline(),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
            ]),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  SLIVER APP BAR
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildSliverAppBar() {
    final info = _patientInfo;
    final isFemale = (info['gender'] ?? '') == 'female' ||
        (info['gender'] ?? '') == 'Female' ||
        (info['gender'] ?? '') == 'أنثى';

    return SliverAppBar(
      expandedHeight: 220,
      pinned: true,
      backgroundColor: kOptiBlue,
      foregroundColor: Colors.white,
      actions: [
        if (_pollingTimer != null)
          const Padding(
            padding: EdgeInsets.only(right: 6),
            child: SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white54),
            ),
          ),
        IconButton(
          icon: const Icon(Icons.refresh_rounded, size: 20),
          onPressed: () async {
            _stopPolling();
            setState(() => _isLoading = true);
            await _loadPatientHistory();
          },
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [kOptiBlue, kAccent],
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                CircleAvatar(
                  radius: 45,
                  backgroundColor: Colors.white.withOpacity(0.2),
                  child: CircleAvatar(
                    radius: 42,
                    backgroundColor: Colors.white,
                    child: Icon(isFemale ? Icons.face_2 : Icons.face,
                        size: 48, color: kOptiBlue),
                  ),
                ),
                const SizedBox(height: 12),
                Text(widget.patientName,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  '${_patientInfo['phone'] ?? 'لا يوجد هاتف'} • ${_patientInfo['age'] ?? '?'} سنة',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.85), fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ),
      title: Text(widget.patientName),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  STATS ROW
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildStatsRow() {
    final sortedVisits = List<Map<String, dynamic>>.from(_visits)
      ..sort((a, b) {
        final da =
            DateTime.tryParse(a['date']?.toString() ?? '') ?? DateTime(2000);
        final db =
            DateTime.tryParse(b['date']?.toString() ?? '') ?? DateTime(2000);
        return db.compareTo(da);
      });

    final lastDate = sortedVisits.isNotEmpty
        ? (sortedVisits.first['date'] ?? '--').toString()
        : '--';
    final lastDateShort =
        lastDate.length >= 10 ? lastDate.substring(0, 10) : lastDate;

    return Row(children: [
      _statCard(
          Icons.history_rounded, 'إجمالي الزيارات', '$_totalVisits', kOptiBlue),
      const SizedBox(width: 12),
      _statCard(Icons.check_circle_rounded, 'زيارات مكتملة',
          '$_completedVisits', Colors.green),
      const SizedBox(width: 12),
      _statCard(Icons.calendar_today_rounded, 'آخر زيارة', lastDateShort,
          Colors.orange),
    ]);
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  ✅ NEW — FINANCIAL SUMMARY بطاقة ملخص مالي كامل
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildFinancialSummary() {
    double totalFee = 0;
    double totalPaid = 0;
    double totalRemaining = 0;
    double totalCredit = 0;

    for (final v in _visits) {
      totalFee += _safeDouble(v['fee']);
      totalPaid += _safeDouble(v['amount_paid']);
      totalRemaining += _safeDouble(v['remaining']);
      totalCredit += _safeDouble(v['credit']);
    }

    if (totalFee == 0) return const SizedBox.shrink();

    final isPaidFull = totalRemaining == 0;
    final color = isPaidFull ? Colors.green : Colors.orange;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.shade200),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 3))
        ],
      ),
      child: Column(children: [
        Row(children: [
          Icon(Icons.account_balance_wallet_rounded,
              color: color.shade700, size: 20),
          const SizedBox(width: 8),
          Text(
            'الملخص المالي',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: color.shade800),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color:
                  isPaidFull ? Colors.green.shade100 : Colors.orange.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              isPaidFull ? '✅ لا يوجد متأخرات' : '⚠️ يوجد متأخرات',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isPaidFull
                      ? Colors.green.shade800
                      : Colors.orange.shade800),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          _financialItem('إجمالي الكشوفات', totalFee, Colors.black87),
          _financialDivider(),
          _financialItem('مدفوع', totalPaid, Colors.green.shade700),
          _financialDivider(),
          _financialItem('الباقي', totalRemaining, Colors.red.shade600,
              bold: !isPaidFull),
          if (totalCredit > 0) ...[
            _financialDivider(),
            _financialItem('رصيد للمريض', totalCredit, kOptiBlue),
          ],
        ]),
      ]),
    );
  }

  Widget _financialItem(String label, double value, Color color,
      {bool bold = false}) {
    return Expanded(
      child: Column(children: [
        Text(
          '${value.toStringAsFixed(0)} ج',
          style: TextStyle(
              fontSize: 15,
              fontWeight: bold ? FontWeight.bold : FontWeight.w600,
              color: color),
        ),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(fontSize: 10, color: Colors.grey),
            textAlign: TextAlign.center),
      ]),
    );
  }

  Widget _financialDivider() => Container(
      width: 1,
      height: 30,
      color: Colors.grey.shade200,
      margin: const EdgeInsets.symmetric(horizontal: 4));

  Widget _statCard(IconData icon, String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 3))
          ],
        ),
        child: Column(children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 16, color: color)),
          const SizedBox(height: 2),
          Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 10, color: Colors.grey)),
        ]),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  PERSONAL INFO CARD
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildPersonalInfoCard() {
    final info = _patientInfo;
    final gender = (info['gender'] ?? '').toString();
    final genderLabel =
        (gender == 'female' || gender == 'Female' || gender == 'أنثى')
            ? 'أنثى'
            : 'ذكر';

    return _sectionCard(
      title: 'البيانات الشخصية',
      icon: Icons.person_rounded,
      child: Column(children: [
        _infoRow(Icons.wc, 'الجنس', genderLabel),
        _divider(),
        _infoRow(Icons.cake, 'العمر', '${info['age'] ?? '--'} سنة'),
        _divider(),
        _infoRow(Icons.phone, 'الهاتف', info['phone'] ?? 'غير مسجل'),
        _divider(),
        _infoRow(Icons.priority_high, 'الأولوية', info['priority'] ?? 'Normal'),
        _divider(),
        _infoRow(Icons.local_hospital, 'القسم', info['department'] ?? '--'),
      ]),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  VISITS TIMELINE
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildVisitsTimeline() {
    final allVisits = List<Map<String, dynamic>>.from(_visits)
      ..sort((a, b) {
        final da =
            DateTime.tryParse(a['date']?.toString() ?? '') ?? DateTime(2000);
        final db =
            DateTime.tryParse(b['date']?.toString() ?? '') ?? DateTime(2000);
        return db.compareTo(da);
      });

    return _sectionCard(
      title: 'التاريخ المرضي الكامل',
      icon: Icons.timeline_rounded,
      child: allVisits.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(20),
              child: Center(
                child: Text('لا توجد زيارات بعد',
                    style: TextStyle(color: Colors.grey)),
              ),
            )
          : ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: allVisits.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final visit = allVisits[index];
                return _visitCard(visit, index, allVisits.length);
              },
            ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  ✅ UPDATED VISIT CARD — يعرض التاريخ + بيانات الدفع
  // ══════════════════════════════════════════════════════════════════════════
  Widget _visitCard(Map<String, dynamic> visit, int index, int total) {
    final isFirst = index == 0;
    final status = (visit['status'] ?? '').toString();
    final isWaiting = status == 'waiting' || status == 'in_progress';
    final isImported = (visit['import_source'] ?? '') == 'nurse_manual' ||
        (visit['nurse'] ?? '') == 'مستورد';

    // ✅ بيانات الدفع
    final double fee = _safeDouble(visit['fee']);
    final double amountPaid = _safeDouble(visit['amount_paid']);
    double remaining = _safeDouble(visit['remaining']);
    final double credit = _safeDouble(visit['credit']);

    // تصحيح تلقائي لو remaining غلط
    if (remaining == 0 && amountPaid < fee && fee > 0) {
      remaining = fee - amountPaid;
    }

    final bool hasFee = fee > 0;
    final bool isPaidFull = remaining == 0;

    // ✅ تاريخ الزيارة الفعلية
    final String? visitDate = visit['visit_date']?.toString();
    final bool hasDifferentVisitDate = visitDate != null &&
        visitDate.isNotEmpty &&
        visitDate != visit['date']?.toString();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // خط الزمن
        Column(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isFirst ? kOptiBlue : Colors.grey.shade300,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text('${total - index}',
                  style: TextStyle(
                      color: isFirst ? Colors.white : Colors.grey.shade600,
                      fontWeight: FontWeight.bold,
                      fontSize: 13)),
            ),
          ),
          if (index < total - 1)
            Container(
              width: 2,
              height: hasFee ? 160 : 120,
              color: Colors.grey.shade200,
              margin: const EdgeInsets.symmetric(vertical: 4),
            ),
        ]),
        const SizedBox(width: 12),

        // بطاقة الكشف
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color:
                  isFirst ? kOptiBlue.withOpacity(0.04) : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color:
                    isFirst ? kOptiBlue.withOpacity(0.2) : Colors.grey.shade200,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── الصف الأول: التاريخ + الحالة + نوع الكشف + تعديل ──────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // التاريخ
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Icon(Icons.calendar_today,
                                size: 13,
                                color: isFirst ? kOptiBlue : Colors.grey),
                            const SizedBox(width: 5),
                            Text(
                              visit['date'] ?? '--',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: isFirst ? kOptiBlue : Colors.grey,
                                  fontWeight: FontWeight.w600),
                            ),
                          ]),
                          // ✅ تاريخ الزيارة الفعلية لو مختلف
                          if (hasDifferentVisitDate) ...[
                            const SizedBox(height: 2),
                            Row(children: [
                              Icon(Icons.event_available,
                                  size: 11, color: Colors.blue.shade400),
                              const SizedBox(width: 3),
                              Text(
                                'زيارة: $visitDate',
                                style: TextStyle(
                                    fontSize: 10, color: Colors.blue.shade600),
                              ),
                            ]),
                          ],
                        ]),

                    // الحالة + نوع + تعديل
                    Row(children: [
                      if (isWaiting)
                        Container(
                          margin: const EdgeInsets.only(right: 4),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.orange.shade200),
                          ),
                          child: Text(
                            status == 'in_progress' ? '🔄 جاري' : '⏳ انتظار',
                            style: TextStyle(
                                fontSize: 9, color: Colors.orange.shade700),
                          ),
                        ),
                      if (isImported)
                        Container(
                          margin: const EdgeInsets.only(right: 4),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.teal.shade50,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '📋 مستورد',
                            style: TextStyle(
                                fontSize: 9, color: Colors.teal.shade700),
                          ),
                        ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          visit['visit_type'] ?? 'كشف',
                          style:
                              const TextStyle(fontSize: 11, color: kOptiBlue),
                        ),
                      ),
                      const SizedBox(width: 6),
                      // زر تعديل
                      GestureDetector(
                        onTap: () => _openEditVisitDialog(visit),
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(7),
                            border: Border.all(
                                color: Colors.amber.shade300, width: 1),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.edit_rounded,
                                  size: 13, color: Colors.amber.shade700),
                              const SizedBox(width: 3),
                              Text('تعديل',
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.amber.shade700,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ]),
                  ],
                ),

                // ── التشخيص ────────────────────────────────────────────────
                if ((visit['diagnosis'] ?? '').toString().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _visitSection('🩺 التشخيص', visit['diagnosis'],
                      const Color(0xFFE3F2FD)),
                ],

                // ── خطة العلاج ─────────────────────────────────────────────
                if ((visit['treatment'] ?? '').toString().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _visitSection('💊 خطة العلاج', visit['treatment'],
                      const Color(0xFFE8F5E9)),
                ],

                // ── ملاحظات ────────────────────────────────────────────────
                if ((visit['notes'] ?? '').toString().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _visitSection(
                      '📝 ملاحظات', visit['notes'], const Color(0xFFFFF8E1)),
                ],

                // ── ✅ بيانات الدفع الكاملة ────────────────────────────────
                if (hasFee) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: isPaidFull
                          ? Colors.green.shade50
                          : Colors.red.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isPaidFull
                            ? Colors.green.shade200
                            : Colors.red.shade200,
                      ),
                    ),
                    child: Column(children: [
                      // سطر الأرقام
                      Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _payCell('الكشف', '${fee.toStringAsFixed(0)} ج',
                                Colors.black87),
                            _payDivider(),
                            _payCell(
                                'مدفوع',
                                '${amountPaid.toStringAsFixed(0)} ج',
                                Colors.green.shade700),
                            _payDivider(),
                            _payCell(
                              isPaidFull ? 'مسدد ✅' : 'الباقي',
                              isPaidFull
                                  ? 'كامل'
                                  : '${remaining.toStringAsFixed(0)} ج',
                              isPaidFull
                                  ? Colors.green.shade700
                                  : Colors.red.shade700,
                              bold: !isPaidFull,
                            ),
                            if (credit > 0) ...[
                              _payDivider(),
                              _payCell('رصيد 💙',
                                  '${credit.toStringAsFixed(0)} ج', kOptiBlue),
                            ],
                          ]),
                      // شريط تقدم الدفع
                      if (!isPaidFull) ...[
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: fee > 0
                                ? (amountPaid / fee).clamp(0.0, 1.0)
                                : 0,
                            backgroundColor: Colors.red.shade100,
                            color: Colors.green.shade400,
                            minHeight: 5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'دفع ${(fee > 0 ? (amountPaid / fee * 100).clamp(0, 100) : 0).toStringAsFixed(0)}% من إجمالي الكشف',
                          style: TextStyle(
                              fontSize: 10, color: Colors.grey.shade600),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ]),
                  ),
                ],

                // ── مدة الكشف ─────────────────────────────────────────────
                if ((visit['consultation_duration'] ?? '')
                    .toString()
                    .isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(children: [
                    Icon(Icons.timer, size: 13, color: Colors.orange.shade600),
                    const SizedBox(width: 4),
                    Text(
                      visit['consultation_duration'].toString(),
                      style: TextStyle(
                          fontSize: 12, color: Colors.orange.shade700),
                    ),
                  ]),
                ],

                _buildVisitCustomFields(DatabaseService.toInt(visit['id'])),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVisitCustomFields(int patientId) {
    return FutureBuilder<List<CustomField>>(
      future: CustomFieldsDb.getForPatient(patientId),
      builder: (context, snap) {
        if (!snap.hasData || snap.data!.isEmpty) return const SizedBox.shrink();
        return Column(
          children: snap.data!
              .map((f) => Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(children: [
                      if (f.isPinned)
                        const Icon(Icons.push_pin_rounded,
                            size: 12, color: Colors.orange),
                      if (f.showInPrescription)
                        const Icon(Icons.receipt_long_rounded,
                            size: 12, color: kOptiBlue),
                      const SizedBox(width: 4),
                      Text(f.fieldName,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: Colors.black87)),
                      const SizedBox(width: 6),
                      const Text('|', style: TextStyle(color: Colors.grey)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(f.fieldValue.isEmpty ? '—' : f.fieldValue,
                            style: const TextStyle(
                                fontSize: 12, color: Colors.black87)),
                      ),
                    ]),
                  ))
              .toList(),
        );
      },
    );
  }

  // ── خلية دفع ──────────────────────────────────────────────────────────────
  Widget _payCell(String label, String value, Color color,
      {bool bold = false}) {
    return Column(children: [
      Text(value,
          style: TextStyle(
              fontSize: 13,
              fontWeight: bold ? FontWeight.bold : FontWeight.w600,
              color: color)),
      const SizedBox(height: 2),
      Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
    ]);
  }

  Widget _payDivider() => Container(
      width: 1,
      height: 28,
      color: Colors.grey.shade200,
      margin: const EdgeInsets.symmetric(horizontal: 4));

  // ══════════════════════════════════════════════════════════════════════════
  //  SHARED WIDGETS
  // ══════════════════════════════════════════════════════════════════════════
  Widget _visitSection(String label, String? content, Color bgColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration:
          BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(8)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.black54)),
        const SizedBox(height: 4),
        Text(content ?? '', style: const TextStyle(fontSize: 13, height: 1.4)),
      ]),
    );
  }

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: kOptiBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: kOptiBlue, size: 18),
            ),
            const SizedBox(width: 10),
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Colors.black87)),
          ]),
        ),
        const Divider(height: 1),
        Padding(padding: const EdgeInsets.all(16), child: child),
      ]),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        Icon(icon, size: 18, color: kOptiBlue),
        const SizedBox(width: 12),
        Text(label,
            style: const TextStyle(
                fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w500)),
        const Spacer(),
        Text(value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  Widget _divider() => Divider(height: 1, color: Colors.grey.shade100);
}
