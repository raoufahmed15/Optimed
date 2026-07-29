// lib/screens/doctor/custom_fields_widget.dart
// ══════════════════════════════════════════════════════════════════════════
//  Dynamic Custom Fields Widget
//  الاستخدام:
//    CustomFieldsWidget(patientId: id, doctorId: doctorId)
// ══════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import '../../core/custom_fields_db.dart';

const Color _kBlue = Color(0xFF0070BB);
const Color _kBg = Color(0xFFF0F6FC);
const Color _kCard = Colors.white;
const Color _kDanger = Color(0xFFEF4444);
const Color _kSuccess = Color(0xFF22C55E);

class CustomFieldsWidget extends StatefulWidget {
  final int patientId;
  final int doctorId;

  /// true = داخل شاشة الكشف (يسمح بالتعديل)
  /// false = عرض فقط (داخل profile)
  final bool editable;

  const CustomFieldsWidget({
    super.key,
    required this.patientId,
    required this.doctorId,
    this.editable = true,
  });

  @override
  State<CustomFieldsWidget> createState() => _CustomFieldsWidgetState();
}

class _CustomFieldsWidgetState extends State<CustomFieldsWidget> {
  List<CustomField> _fields = [];
  bool _loading = true;
  bool _expanded = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final fields = await CustomFieldsDb.getForPatient(widget.patientId);
      if (mounted)
        setState(() {
          _fields = fields;
          _loading = false;
        });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Add ────────────────────────────────────────────────────────────────
  void _showAddDialog({CustomField? editing}) {
    final nameCtrl = TextEditingController(text: editing?.fieldName ?? '');
    final valueCtrl = TextEditingController(text: editing?.fieldValue ?? '');
    bool pinned = editing?.isPinned ?? false;
    bool rx = editing?.showInPrescription ?? false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          insetPadding: const EdgeInsets.all(20),
          child: Container(
            width: 480,
            decoration: BoxDecoration(
              color: _kCard,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: const BoxDecoration(
                    color: _kBlue,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.add_circle_outline,
                        color: Colors.white, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      editing == null ? 'إضافة حقل مخصص' : 'تعديل الحقل',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ]),
                ),

                // Body
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(children: [
                    // Field Name
                    TextField(
                      controller: nameCtrl,
                      decoration: _dec(
                          'اسم الحقل (مثال: وزن، ضغط)', Icons.label_outline),
                    ),
                    const SizedBox(height: 14),
                    // Field Value
                    TextField(
                      controller: valueCtrl,
                      maxLines: 3,
                      decoration: _dec('القيمة', Icons.edit_note_rounded),
                    ),
                    const SizedBox(height: 16),
                    // Toggles
                    _toggle(
                      icon: Icons.push_pin_rounded,
                      label: 'Pinned — يظهر تلقائياً في كل كشف',
                      value: pinned,
                      color: Colors.orange,
                      onChanged: (v) => setDlg(() => pinned = v),
                    ),
                    const SizedBox(height: 8),
                    _toggle(
                      icon: Icons.receipt_long_rounded,
                      label: 'يظهر في الروشتة عند الطباعة',
                      value: rx,
                      color: _kBlue,
                      onChanged: (v) => setDlg(() => rx = v),
                    ),
                  ]),
                ),

                // Actions
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Row(children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.grey.shade300),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                        ),
                        child: const Text('إلغاء',
                            style: TextStyle(color: Colors.grey)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _kBlue,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.save_rounded,
                            color: Colors.white, size: 18),
                        label: const Text('حفظ',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                        onPressed: () async {
                          final name = nameCtrl.text.trim();
                          final value = valueCtrl.text.trim();
                          if (name.isEmpty) return;
                          Navigator.pop(ctx);
                          if (editing == null) {
                            final f = CustomField(
                              patientId: widget.patientId,
                              doctorId: widget.doctorId,
                              fieldName: name,
                              fieldValue: value,
                              isPinned: pinned,
                              showInPrescription: rx,
                            );
                            await CustomFieldsDb.addField(f);
                            if (pinned) {
                              await _offerSaveAsTemplate(name, rx);
                            }
                          } else {
                            final wasNotPinned = !editing.isPinned;
                            editing.fieldName = name;
                            editing.fieldValue = value;
                            editing.isPinned = pinned;
                            editing.showInPrescription = rx;
                            await CustomFieldsDb.updateField(editing);
                            if (pinned && wasNotPinned) {
                              await _offerSaveAsTemplate(name, rx);
                            }
                          }
                          await _load();
                          _showSnack(editing == null
                              ? '✓ تمت الإضافة'
                              : '✓ تم التعديل');
                        },
                      ),
                    ),
                  ]),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _offerSaveAsTemplate(String name, bool rx) async {
    if (name.isEmpty) return;
    final save = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('حفظ كقالب؟',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        content: Text(
          'هل تريد حفظ "$name" كحقل ثابت يظهر تلقائياً في كل مريض جديد؟',
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('لا', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _kBlue,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child:
                const Text('نعم، احفظه', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (save == true) {
      await CustomFieldsDb.addDoctorTemplate(PinnedTemplate(
        doctorId: widget.doctorId,
        fieldName: name,
        showInPrescription: rx,
      ));
    }
  }

  Future<void> _deleteField(CustomField f) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('حذف الحقل؟',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        content: Text('سيتم حذف "${f.fieldName}" نهائياً.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: _kDanger,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8))),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await CustomFieldsDb.deleteField(f.id!);
      await _load();
      _showSnack('تم الحذف');
    }
  }

  void _showSnack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(msg,
            style: const TextStyle(color: Colors.white, fontSize: 13)),
        backgroundColor: error ? _kDanger : _kSuccess,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ));
  }

  // ── Build ──────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD0E8F5)),
        boxShadow: [
          BoxShadow(
            color: _kBlue.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ────────────────────────────────────────────────────
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: _kBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child:
                      const Icon(Icons.tune_rounded, color: _kBlue, size: 18),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'حقول مخصصة',
                    style: TextStyle(
                        color: _kBlue,
                        fontWeight: FontWeight.bold,
                        fontSize: 14),
                  ),
                ),
                if (_fields.isNotEmpty)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _kBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${_fields.length}',
                      style: const TextStyle(
                          color: _kBlue,
                          fontWeight: FontWeight.bold,
                          fontSize: 12),
                    ),
                  ),
                const SizedBox(width: 6),
                if (widget.editable)
                  TextButton.icon(
                    onPressed: () => _showAddDialog(),
                    icon: const Icon(Icons.add_circle_outline,
                        size: 16, color: _kBlue),
                    label: const Text('إضافة',
                        style: TextStyle(
                            color: _kBlue,
                            fontWeight: FontWeight.bold,
                            fontSize: 13)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                Icon(
                  _expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: Colors.grey,
                  size: 20,
                ),
              ]),
            ),
          ),

          // ── Body ──────────────────────────────────────────────────────
          if (_expanded) ...[
            const Divider(height: 1),
            _loading
                ? const Padding(
                    padding: EdgeInsets.all(20),
                    child:
                        Center(child: CircularProgressIndicator(color: _kBlue)),
                  )
                : _fields.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(16),
                        child: Center(
                          child: Column(children: [
                            Icon(Icons.add_circle_outline,
                                color: _kBlue.withOpacity(0.3), size: 32),
                            const SizedBox(height: 6),
                            Text(
                              widget.editable
                                  ? 'اضغط "إضافة" لإدخال حقل مخصص'
                                  : 'لا توجد حقول مخصصة',
                              style: TextStyle(
                                  color: Colors.grey.shade500, fontSize: 12),
                            ),
                          ]),
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children:
                              _fields.map((f) => _buildFieldRow(f)).toList(),
                        ),
                      ),
          ],
        ],
      ),
    );
  }

  Widget _buildFieldRow(CustomField f) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _kBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFD0E8F5)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // اسم الحقل
        SizedBox(
          width: 130,
          child: Row(children: [
            if (f.isPinned)
              const Icon(Icons.push_pin_rounded,
                  size: 13, color: Colors.orange),
            if (f.showInPrescription)
              const Padding(
                padding: EdgeInsets.only(left: 2),
                child:
                    Icon(Icons.receipt_long_rounded, size: 13, color: _kBlue),
              ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                f.fieldName,
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Colors.black87),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ]),
        ),
        const SizedBox(width: 8),
        const Text('|', style: TextStyle(color: Colors.grey, fontSize: 13)),
        const SizedBox(width: 8),
        // القيمة
        Expanded(
          child: Text(
            f.fieldValue.isEmpty ? '—' : f.fieldValue,
            style: TextStyle(
                fontSize: 13,
                color: f.fieldValue.isEmpty
                    ? Colors.grey.shade400
                    : Colors.black87),
          ),
        ),
        // أزرار التعديل
        if (widget.editable) ...[
          GestureDetector(
            onTap: () => _showAddDialog(editing: f),
            child: const Icon(Icons.edit_rounded, size: 16, color: _kBlue),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => _deleteField(f),
            child: const Icon(Icons.delete_outline_rounded,
                size: 16, color: _kDanger),
          ),
        ],
      ]),
    );
  }

  InputDecoration _dec(String hint, IconData icon) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
        prefixIcon: Icon(icon, color: _kBlue, size: 18),
        filled: true,
        fillColor: _kBg,
        contentPadding:
            const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFD0E8F5))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFD0E8F5))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _kBlue, width: 2)),
      );

  Widget _toggle({
    required IconData icon,
    required String label,
    required bool value,
    required Color color,
    required void Function(bool) onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: value ? color.withOpacity(0.07) : _kBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: value ? color.withOpacity(0.4) : const Color(0xFFD0E8F5)),
      ),
      child: SwitchListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        secondary: Icon(icon, color: value ? color : Colors.grey, size: 18),
        title: Text(label,
            style: TextStyle(
                fontSize: 12,
                color: value ? color : Colors.grey.shade600,
                fontWeight: value ? FontWeight.w600 : FontWeight.normal)),
        value: value,
        activeColor: color,
        onChanged: onChanged,
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
//  PinnedTemplatesManager — لإدارة قوالب الدكتور من الإعدادات
// ══════════════════════════════════════════════════════════════════════════
class PinnedTemplatesManager extends StatefulWidget {
  final int doctorId;
  const PinnedTemplatesManager({super.key, required this.doctorId});

  @override
  State<PinnedTemplatesManager> createState() => _PinnedTemplatesManagerState();
}

class _PinnedTemplatesManagerState extends State<PinnedTemplatesManager> {
  List<PinnedTemplate> _templates = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await CustomFieldsDb.getDoctorTemplates(widget.doctorId);
    if (mounted)
      setState(() {
        _templates = list;
        _loading = false;
      });
  }

  void _addTemplate() async {
    final ctrl = TextEditingController();
    bool rx = false;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('إضافة حقل ثابت',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: ctrl,
              decoration: const InputDecoration(
                  labelText: 'اسم الحقل', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title:
                  const Text('يظهر في الروشتة', style: TextStyle(fontSize: 13)),
              value: rx,
              activeColor: const Color(0xFF0070BB),
              onChanged: (v) => setDlg(() => rx = v),
            ),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0070BB),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                final name = ctrl.text.trim();
                if (name.isEmpty) return;
                Navigator.pop(ctx);
                await CustomFieldsDb.addDoctorTemplate(PinnedTemplate(
                  doctorId: widget.doctorId,
                  fieldName: name,
                  showInPrescription: rx,
                ));
                await _load();
              },
              child: const Text('إضافة', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F6FC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0070BB),
        foregroundColor: Colors.white,
        title: const Text('الحقول الثابتة (Pinned Fields)',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: _addTemplate,
            tooltip: 'إضافة حقل ثابت',
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF0070BB)))
          : _templates.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.push_pin_outlined,
                          size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      Text(
                        'لا توجد حقول ثابتة بعد',
                        style: TextStyle(
                            color: Colors.grey.shade500, fontSize: 15),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'اضغط + لإضافة حقل يظهر تلقائياً في كل مريض',
                        style: TextStyle(
                            color: Colors.grey.shade400, fontSize: 13),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _templates.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final t = _templates[i];
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFD0E8F5)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.push_pin_rounded,
                            color: Colors.orange, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(t.fieldName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 14)),
                        ),
                        if (t.showInPrescription)
                          Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0070BB).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('روشتة',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF0070BB),
                                    fontWeight: FontWeight.bold)),
                          ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded,
                              color: Color(0xFFEF4444), size: 20),
                          onPressed: () async {
                            await CustomFieldsDb.deleteDoctorTemplate(t.id!);
                            await _load();
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ]),
                    );
                  },
                ),
    );
  }
}
