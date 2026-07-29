import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'rx_layout_helper.dart';
import '../../core/custom_fields_db.dart';

const Color kOptiBlue = Color(0xFF0070BB);

class RxField {
  final String key;
  final String label;
  final String sampleText;
  final bool isCustom;
  Offset position;
  double fontSize;
  bool enabled;

  RxField({
    required this.key,
    required this.label,
    required this.sampleText,
    this.isCustom = false,
    required this.position,
    this.fontSize = 11,
    this.enabled = true,
  });

  Map<String, dynamic> toJson() => {
        'key': key,
        'x': position.dx,
        'y': position.dy,
        'fontSize': fontSize,
        'enabled': enabled,
        'label': label,
        'sampleText': sampleText,
        'isCustom': isCustom,
      };

  void fromJson(Map<String, dynamic> j) {
    position = Offset(
      (j['x'] as num?)?.toDouble() ?? position.dx,
      (j['y'] as num?)?.toDouble() ?? position.dy,
    );
    fontSize = (j['fontSize'] as num?)?.toDouble() ?? fontSize;
    enabled = j['enabled'] as bool? ?? true;
  }
}

class PrescriptionCustomizerScreen extends StatefulWidget {
  final int doctorId;
  const PrescriptionCustomizerScreen({super.key, required this.doctorId});

  @override
  State<PrescriptionCustomizerScreen> createState() =>
      _PrescriptionCustomizerScreenState();
}

class _PrescriptionCustomizerScreenState
    extends State<PrescriptionCustomizerScreen> {
  String? _imagePath;
  Key _imageKey = UniqueKey();

  final ImagePicker _picker = ImagePicker();
  late List<RxField> _fields;
  String? _draggingKey;

  double _zoomLevel = 1.0;
  static const double _zoomStep = 0.25;
  static const double _zoomMin = 0.5;
  static const double _zoomMax = 3.0;

  @override
  void initState() {
    super.initState();
    _initFields();
    _loadSaved();
  }

  void _initFields() {
    _fields = [
      RxField(
        key: 'patient_name',
        label: 'Patient Name',
        sampleText: 'AHMED MOHAMED',
        position: const Offset(0.18, 0.12),
        fontSize: 11,
      ),
      RxField(
        key: 'patient_age',
        label: 'Age',
        sampleText: '35',
        position: const Offset(0.18, 0.18),
        fontSize: 10,
      ),
      RxField(
        key: 'date_day',
        label: 'Day',
        sampleText: '24',
        position: const Offset(0.52, 0.18),
        fontSize: 10,
      ),
      RxField(
        key: 'date_month',
        label: 'Month',
        sampleText: '02',
        position: const Offset(0.63, 0.18),
        fontSize: 10,
      ),
      RxField(
        key: 'date_year',
        label: 'Year',
        sampleText: '2026',
        position: const Offset(0.73, 0.18),
        fontSize: 10,
      ),
      RxField(
        key: 'diagnosis',
        label: 'Diagnosis',
        sampleText: 'Acute conjunctivitis OD',
        position: const Offset(0.08, 0.35),
        fontSize: 10,
      ),
      RxField(
        key: 'medicines',
        label: 'Medicines',
        sampleText: '1.  Tobramycin Eye Drops',
        position: const Offset(0.10, 0.48),
        fontSize: 11,
      ),
    ];
    _zoomLevel = 1.0;
  }

  Future<void> _loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final String? savedPath = prefs.getString('doctor_letterhead_path');
    final raw = prefs.getString('rx_field_positions');

    if (raw != null) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(raw);
        for (final f in _fields) {
          if (decoded.containsKey(f.key)) f.fromJson(decoded[f.key]);
        }
        decoded.forEach((key, value) {
          if (value is Map<String, dynamic> &&
              (value['isCustom'] as bool? ?? false) == true) {
            if (!_fields.any((f) => f.key == key)) {
              final cf = RxField(
                key: key,
                label: value['label'] as String? ?? key,
                sampleText: value['sampleText'] as String? ?? key,
                isCustom: true,
                position: Offset(
                  (value['x'] as num?)?.toDouble() ?? 0.5,
                  (value['y'] as num?)?.toDouble() ?? 0.5,
                ),
                fontSize: (value['fontSize'] as num?)?.toDouble() ?? 11,
                enabled: value['enabled'] as bool? ?? true,
              );
              _fields.add(cf);
            }
          }
        });
      } catch (_) {}
    }

    // ✅ جيب الحقول الـ rx من DB وأضيفها لو مش موجودة
    await _syncRxFieldsFromDb();

    if (!mounted) return;
    setState(() {
      _imagePath = savedPath;
      _imageKey = UniqueKey();
    });
  }

  Future<void> _syncRxFieldsFromDb() async {
    final templates = await CustomFieldsDb.getDoctorTemplates(widget.doctorId);
    int fallbackIdx = _fields.length;
    for (final t in templates) {
      if (!t.showInPrescription) continue;
      final key = 'cf_${t.fieldName}';
      if (_fields.any((f) => f.key == key)) continue;
      _fields.add(RxField(
        key: key,
        label: t.fieldName,
        sampleText: '${t.fieldName}: ...',
        isCustom: true,
        position: Offset(0.08, 0.65 + fallbackIdx * 0.06),
        fontSize: 10,
        enabled: true,
      ));
      fallbackIdx++;
    }
  }

  Future<void> _saveAll() async {
    final prefs = await SharedPreferences.getInstance();
    final Map<String, dynamic> out = {};
    for (final f in _fields) {
      out[f.key] = f.toJson();
    }
    await prefs.setString('rx_field_positions', jsonEncode(out));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Row(children: [
          Icon(Icons.check_circle_rounded, color: Colors.white),
          SizedBox(width: 10),
          Text('Layout saved ✓', style: TextStyle(fontWeight: FontWeight.bold)),
        ]),
        backgroundColor: const Color(0xFF22C55E),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ));
    }
  }

  Future<void> _pickImage() async {
    final XFile? picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    if (_imagePath != null) await FileImage(File(_imagePath!)).evict();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('doctor_letterhead_path', picked.path);
    if (!mounted) return;
    setState(() {
      _imagePath = picked.path;
      _imageKey = UniqueKey();
    });
  }

  void _resetPositions() => setState(_initFields);

  void _showAddCustomFieldDialog() {
    final labelController = TextEditingController();
    final textController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: kOptiBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.add_box_rounded,
                        color: kOptiBlue, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Text('Add Custom Field',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.black87)),
                ],
              ),
              const SizedBox(height: 20),
              const Text('Field Name',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey)),
              const SizedBox(height: 6),
              _dialogTextField(labelController,
                  hint: 'e.g. Phone, Doctor Name …'),
              const SizedBox(height: 14),
              const Text('Text to print on prescription',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey)),
              const SizedBox(height: 6),
              _dialogTextField(textController,
                  hint: 'e.g. Dr. Ahmed, 01234567890 …'),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.grey,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        final label = labelController.text.trim();
                        final text = textController.text.trim();
                        if (label.isEmpty || text.isEmpty) return;
                        final key =
                            'custom_${DateTime.now().millisecondsSinceEpoch}';
                        setState(() {
                          _fields.add(RxField(
                            key: key,
                            label: label,
                            sampleText: text,
                            isCustom: true,
                            position: const Offset(0.1, 0.5),
                            fontSize: 11,
                          ));
                        });
                        Navigator.pop(ctx);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kOptiBlue,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Add Field',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dialogTextField(TextEditingController ctrl, {required String hint}) {
    return TextField(
      controller: ctrl,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: const Color(0xFFF0F6FC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFD0E8F5)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFD0E8F5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: kOptiBlue, width: 2),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F6FC),
      appBar: AppBar(
        backgroundColor: kOptiBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Customize Prescription',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 17)),
            Text('Drag text to set print positions',
                style: TextStyle(color: Colors.white70, fontSize: 11)),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: _resetPositions,
            icon: const Icon(Icons.refresh_rounded,
                color: Colors.white70, size: 18),
            label: const Text('Reset',
                style: TextStyle(color: Colors.white70, fontSize: 13)),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12, left: 4),
            child: ElevatedButton.icon(
              onPressed: _saveAll,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: kOptiBlue,
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.save_rounded, size: 18),
              label: const Text('Save',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildToolbar(),
          Expanded(
            child: _imagePath == null
                ? _buildNoImagePlaceholder()
                : _buildEditor(),
          ),
          _buildFieldPanel(),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          ElevatedButton.icon(
            onPressed: _pickImage,
            style: ElevatedButton.styleFrom(
              backgroundColor: kOptiBlue,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.upload_rounded, size: 18),
            label:
                Text(_imagePath == null ? 'Upload Letterhead' : 'Change Image'),
          ),
          const Spacer(),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF0F6FC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFD0E8F5)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _zoomButton(
                  icon: Icons.remove_rounded,
                  onTap: _zoomLevel > _zoomMin
                      ? () => setState(() => _zoomLevel =
                          (_zoomLevel - _zoomStep).clamp(_zoomMin, _zoomMax))
                      : null,
                ),
                GestureDetector(
                  onTap: () => setState(() => _zoomLevel = 1.0),
                  child: Container(
                    width: 52,
                    alignment: Alignment.center,
                    child: Text(
                      '${(_zoomLevel * 100).round()}%',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _zoomLevel == 1.0 ? Colors.blueGrey : kOptiBlue,
                      ),
                    ),
                  ),
                ),
                _zoomButton(
                  icon: Icons.add_rounded,
                  onTap: _zoomLevel < _zoomMax
                      ? () => setState(() => _zoomLevel =
                          (_zoomLevel + _zoomStep).clamp(_zoomMin, _zoomMax))
                      : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _zoomButton({required IconData icon, required VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Icon(icon,
            size: 18, color: onTap == null ? Colors.grey.shade300 : kOptiBlue),
      ),
    );
  }

  Widget _buildNoImagePlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image_search_rounded,
              size: 70, color: kOptiBlue.withOpacity(0.4)),
          const SizedBox(height: 20),
          const Text('No Letterhead Uploaded',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueGrey)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _pickImage,
            style: ElevatedButton.styleFrom(
              backgroundColor: kOptiBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            icon: const Icon(Icons.upload_rounded),
            label: const Text('Upload Letterhead',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ),
        ],
      ),
    );
  }

  Widget _buildEditor() {
    const double pdfAspectRatio = kPdfPageW / kPdfPageH;

    return LayoutBuilder(builder: (context, constraints) {
      const double pad = 16.0;
      final double availW = constraints.maxWidth - pad * 2;
      final double availH = constraints.maxHeight - pad * 2;

      double baseW = availW;
      double baseH = baseW / pdfAspectRatio;
      if (baseH > availH) {
        baseH = availH;
        baseW = baseH * pdfAspectRatio;
      }

      final double previewW = baseW * _zoomLevel;
      final double previewH = baseH * _zoomLevel;
      final double scale = previewW / kPdfPageW;

      return SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Padding(
            padding: const EdgeInsets.all(pad),
            child: SizedBox(
              width: previewW,
              height: previewH,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.18),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Image.file(
                          key: _imageKey,
                          File(_imagePath!),
                          fit: BoxFit.fill,
                        ),
                      ),
                      ..._fields.where((f) => f.enabled).map((f) =>
                          _buildDraggableText(f, previewW, previewH, scale)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _buildDraggableText(
      RxField field, double imgW, double imgH, double scale) {
    final double left = field.position.dx * imgW;
    final double top = field.position.dy * imgH;
    final bool isDragging = _draggingKey == field.key;
    final double displayFontSize = (field.fontSize * scale).clamp(4.0, 60.0);

    final bool isBold = field.key == 'patient_name' ||
        field.key == 'diagnosis' ||
        field.key == 'medicines';

    return Positioned(
      left: left.clamp(0.0, imgW - 10),
      top: top.clamp(0.0, imgH - 10),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onPanStart: (_) => setState(() => _draggingKey = field.key),
        onPanEnd: (_) => setState(() => _draggingKey = null),
        onPanCancel: () => setState(() => _draggingKey = null),
        onPanUpdate: (details) {
          setState(() {
            _draggingKey = field.key;
            final double newLeft =
                (field.position.dx * imgW) + details.delta.dx;
            final double newTop =
                (field.position.dy * imgH) + details.delta.dy;
            field.position = Offset(
              (newLeft / imgW).clamp(0.0, 1.0),
              (newTop / imgH).clamp(0.0, 1.0),
            );
          });
        },
        child: Opacity(
          opacity: isDragging ? 0.5 : 1.0,
          child: Text(
            field.sampleText,
            style: TextStyle(
              fontSize: displayFontSize,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: Colors.black87,
              height: 1.0,
              shadows: isDragging
                  ? [Shadow(color: kOptiBlue.withOpacity(0.6), blurRadius: 8)]
                  : null,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFieldPanel() {
    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
                color: Colors.black12, blurRadius: 12, offset: Offset(0, -4))
          ],
        ),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                    width: 4,
                    height: 16,
                    decoration: BoxDecoration(
                        color: kOptiBlue,
                        borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 8),
                const Text('Fields',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.blueGrey)),
                const SizedBox(width: 6),
                Text('(${_fields.where((f) => f.enabled).length} active)',
                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
                const Spacer(),
                const Text('Drag text on preview',
                    style: TextStyle(color: Colors.grey, fontSize: 11)),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 110,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _fields.length + 1,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  if (i == _fields.length) return _buildAddFieldButton();
                  return _buildFieldCard(_fields[i]);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddFieldButton() {
    return GestureDetector(
      onTap: _showAddCustomFieldDialog,
      child: Container(
        width: 90,
        decoration: BoxDecoration(
          color: kOptiBlue.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kOptiBlue.withOpacity(0.3), width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                  color: kOptiBlue.withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(Icons.add_rounded, color: kOptiBlue, size: 22),
            ),
            const SizedBox(height: 8),
            const Text('Add Field',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: kOptiBlue),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldCard(RxField field) {
    return Container(
      width: 130,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color:
            field.enabled ? kOptiBlue.withOpacity(0.06) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: field.enabled
              ? kOptiBlue.withOpacity(0.25)
              : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  field.label,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    color: field.enabled ? kOptiBlue : Colors.grey,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (field.isCustom)
                GestureDetector(
                  onTap: () => setState(() => _fields.remove(field)),
                  child: Padding(
                    padding: const EdgeInsets.only(left: 2),
                    child: Icon(Icons.close_rounded,
                        size: 15, color: Colors.red.shade300),
                  ),
                )
              else
                Transform.scale(
                  scale: 0.65,
                  alignment: Alignment.centerRight,
                  child: Switch(
                    value: field.enabled,
                    onChanged: (v) => setState(() => field.enabled = v),
                    activeColor: kOptiBlue,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
            ],
          ),
          Row(
            children: [
              Text('pt',
                  style: TextStyle(fontSize: 9, color: Colors.grey.shade500)),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 2,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 5),
                    overlayShape:
                        const RoundSliderOverlayShape(overlayRadius: 10),
                  ),
                  child: Slider(
                    value: field.fontSize.clamp(6, 20),
                    min: 6,
                    max: 20,
                    divisions: 14,
                    activeColor: kOptiBlue,
                    onChanged: (v) => setState(() => field.fontSize = v),
                  ),
                ),
              ),
              Text('${field.fontSize.round()}',
                  style: TextStyle(fontSize: 9, color: Colors.grey.shade500)),
            ],
          ),
          Text(
            'x:${(field.position.dx * 100).round()}%  '
            'y:${(field.position.dy * 100).round()}%',
            style: TextStyle(fontSize: 9, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }
}