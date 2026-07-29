import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:printing/printing.dart';
import '../../core/custom_fields_db.dart';

const double kPdfPageW = 419.53;
const double kPdfPageH = 595.28;

class RxFieldLayout {
  final String key;
  final Offset position;
  final double fontSize;
  final bool enabled;
  final bool isCustom;
  final String sampleText;

  const RxFieldLayout({
    required this.key,
    required this.position,
    required this.fontSize,
    required this.enabled,
    this.isCustom = false,
    this.sampleText = '',
  });
}

Future<Map<String, RxFieldLayout>> loadRxLayout() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString('rx_field_positions');

  final defaults = {
    'patient_name': const RxFieldLayout(key: 'patient_name', position: Offset(0.18, 0.12), fontSize: 11, enabled: true),
    'patient_age':  const RxFieldLayout(key: 'patient_age',  position: Offset(0.18, 0.18), fontSize: 10, enabled: true),
    'date_day':     const RxFieldLayout(key: 'date_day',     position: Offset(0.52, 0.18), fontSize: 10, enabled: true),
    'date_month':   const RxFieldLayout(key: 'date_month',   position: Offset(0.63, 0.18), fontSize: 10, enabled: true),
    'date_year':    const RxFieldLayout(key: 'date_year',    position: Offset(0.73, 0.18), fontSize: 10, enabled: true),
    'diagnosis':    const RxFieldLayout(key: 'diagnosis',    position: Offset(0.08, 0.35), fontSize: 10, enabled: true),
    'medicines':    const RxFieldLayout(key: 'medicines',    position: Offset(0.10, 0.48), fontSize: 11, enabled: true),
  };

  if (raw == null) return defaults;
  try {
    final Map<String, dynamic> decoded = jsonDecode(raw);
    final result = <String, RxFieldLayout>{};
    for (final entry in defaults.entries) {
      final k = entry.key;
      if (decoded.containsKey(k)) {
        final j = decoded[k] as Map<String, dynamic>;
        result[k] = RxFieldLayout(
          key: k,
          position: Offset(
            (j['x'] as num?)?.toDouble() ?? entry.value.position.dx,
            (j['y'] as num?)?.toDouble() ?? entry.value.position.dy,
          ),
          fontSize: (j['fontSize'] as num?)?.toDouble() ?? entry.value.fontSize,
          enabled: j['enabled'] as bool? ?? entry.value.enabled,
        );
      } else {
        result[k] = entry.value;
      }
    }
    // ✅ جيب كل custom fields المحفوظة (سواء من DB أو من الـ customizer)
    decoded.forEach((key, value) {
      if (value is Map<String, dynamic> &&
          (value['isCustom'] as bool? ?? false) == true) {
        result[key] = RxFieldLayout(
          key: key,
          position: Offset(
            (value['x'] as num?)?.toDouble() ?? 0.1,
            (value['y'] as num?)?.toDouble() ?? 0.5,
          ),
          fontSize: (value['fontSize'] as num?)?.toDouble() ?? 11,
          enabled: value['enabled'] as bool? ?? true,
          isCustom: true,
          sampleText: value['sampleText'] as String? ?? '',
        );
      }
    });
    return result;
  } catch (_) {
    return defaults;
  }
}

Future<bool> loadRxIsArabic() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool('rx_is_arabic') ?? false;
}

Future<void> saveRxIsArabic(bool isArabic) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('rx_is_arabic', isArabic);
}

Future<pw.Page> buildRxPage({
  required String? imagePath,
  required String patientName,
  required String patientAge,
  required DateTime visitDate,
  required String diagnosis,
  required List<Map<String, String>> medicines,
  required pw.Font? arabicFont,
  required int patientId,
  bool printOnBlank = false,
  bool isArabic = false,
}) async {
  final layout = await loadRxLayout();
  final rxFields = await CustomFieldsDb.getPrescriptionFields(patientId);

  final pw.Font finalFont = arabicFont ?? await PdfGoogleFonts.cairoRegular();
  final pw.Font boldFont  = await PdfGoogleFonts.cairoBold();

  Uint8List? imageBytes;
  if (!printOnBlank && imagePath != null && File(imagePath).existsSync()) {
    imageBytes = await File(imagePath).readAsBytes();
  }

  const double pageW = kPdfPageW;
  const double pageH = kPdfPageH;
  double toX(double nx) => nx * pageW;
  double toY(double ny) => ny * pageH;

  pw.TextStyle fieldStyle(RxFieldLayout l, {pw.FontWeight? weight, PdfColor? color}) =>
      pw.TextStyle(
        font:        weight == pw.FontWeight.bold ? boldFont : finalFont,
        fontSize:    l.fontSize,
        fontWeight:  weight,
        color:       color,
        lineSpacing: 0,
      );

  final String doseLabel     = isArabic ? 'الجرعة'  : 'Dose';
  final String durationLabel = isArabic ? 'المدة'   : 'Duration';

  final List<pw.Widget> children = [];

  // 1. Background image
  if (imageBytes != null && !printOnBlank) {
    children.add(pw.Positioned(
      left: 0, top: 0,
      child: pw.SizedBox(
        width: pageW, height: pageH,
        child: pw.Image(pw.MemoryImage(imageBytes), fit: pw.BoxFit.fill),
      ),
    ));
  }

  void addText(String key, String text, {pw.FontWeight? weight, PdfColor? color}) {
    final l = layout[key];
    if (l == null || !l.enabled || text.isEmpty) return;
    children.add(pw.Positioned(
      left: toX(l.position.dx),
      top:  toY(l.position.dy),
      child: pw.Directionality(
        textDirection: pw.TextDirection.rtl,
        child: pw.Text(text, style: fieldStyle(l, weight: weight, color: color)),
      ),
    ));
  }

  addText('patient_name', patientName, weight: pw.FontWeight.bold);
  addText('patient_age',  patientAge);
  addText('date_day',     visitDate.day.toString().padLeft(2, '0'));
  addText('date_month',   visitDate.month.toString().padLeft(2, '0'));
  addText('date_year',    visitDate.year.toString());
  addText('diagnosis',    diagnosis);

  // Medicines
  final medL = layout['medicines'];
  if (medL != null && medL.enabled && medicines.isNotEmpty) {
    final activeMeds =
        medicines.where((m) => (m['name'] ?? '').isNotEmpty).toList();
    if (activeMeds.isNotEmpty) {
      children.add(pw.Positioned(
        left: toX(medL.position.dx),
        top:  toY(medL.position.dy),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: activeMeds.asMap().entries.map((entry) {
            final idx      = entry.key + 1;
            final m        = entry.value;
            final dose     = m['dose']     ?? '';
            final duration = m['duration'] ?? '';
            final details = [
              if (dose.isNotEmpty)     '$doseLabel: $dose',
              if (duration.isNotEmpty) '$durationLabel: $duration',
            ].join('   |   ');

            return pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 10),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    mainAxisSize: pw.MainAxisSize.min,
                    children: [
                      pw.Text(
                        '$idx.  ',
                        style: fieldStyle(medL,
                            weight: pw.FontWeight.bold,
                            color: PdfColors.blue900),
                      ),
                      pw.Text(
                        m['name'] ?? '',
                        style: fieldStyle(medL, weight: pw.FontWeight.bold),
                      ),
                    ],
                  ),
                  if (details.isNotEmpty)
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(left: 12, top: 2),
                      child: pw.Directionality(
                        textDirection: pw.TextDirection.rtl,
                        child: pw.Text(
                          details,
                          style: fieldStyle(medL).copyWith(
                            fontSize: medL.fontSize - 2,
                            color: PdfColors.grey700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          }).toList(),
        ),
      ));
    }
  }

  // ✅ الحقول المخصصة من DB — بتاخد مكانها من الـ layout بـ key = 'cf_fieldName'
  int fallbackIdx = 0;
  for (final f in rxFields) {
    final key = 'cf_${f.fieldName}';
    final text = f.fieldValue.isNotEmpty
        ? '${f.fieldName}: ${f.fieldValue}'
        : f.fieldName;

    final l = layout[key];
    if (l != null && l.enabled) {
      // ✅ موجود في الـ layout — استخدم مكانه المحفوظ
      children.add(pw.Positioned(
        left: toX(l.position.dx),
        top:  toY(l.position.dy),
        child: pw.Text(
          text,
          style: pw.TextStyle(
            font: finalFont,
            fontSize: l.fontSize,
          ),
        ),
      ));
    } else {
      // fallback لو لسه مش في الـ layout
      children.add(pw.Positioned(
        left: toX(0.08),
        top:  toY(0.65 + fallbackIdx * 0.05),
        child: pw.Text(
          text,
          style: pw.TextStyle(font: finalFont, fontSize: 10),
        ),
      ));
      fallbackIdx++;
    }
  }

  // Custom static fields من الـ customizer (مش من DB)
  for (final entry in layout.entries) {
    final l = entry.value;
    if (l.isCustom && l.enabled && l.sampleText.isNotEmpty &&
        !entry.key.startsWith('cf_')) {
      addText(entry.key, l.sampleText);
    }
  }

  return pw.Page(
    pageFormat: const PdfPageFormat(kPdfPageW, kPdfPageH),
    margin: pw.EdgeInsets.zero,
    build: (_) => pw.Stack(children: children),
  );
}