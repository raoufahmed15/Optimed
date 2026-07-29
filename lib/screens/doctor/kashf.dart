import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants.dart';
import '../../models/patient.dart';
import '../../core/database.dart';
import '../../core/custom_fields_db.dart';
import 'rx_layout_helper.dart';
import 'patient_profile_screen.dart';
import 'custom_fields_widget.dart';

const Color kOptiBlue = Color(0xFF0070BB);
const Color kAccent = Color(0xFF00A8E8);
const Color kBg = Color(0xFFF0F6FC);
const Color kCard = Colors.white;
const Color kSuccess = Color(0xFF22C55E);
const Color kDanger = Color(0xFFEF4444);

class PrescriptionItem {
  TextEditingController nameController = TextEditingController();
  TextEditingController doseController = TextEditingController();
  TextEditingController durationController = TextEditingController();
  bool isManual = false;

  void dispose() {
    nameController.dispose();
    doseController.dispose();
    durationController.dispose();
  }
}

class QuickTemplate {
  String id;
  String name;
  String diagnosis;
  List<Map<String, String>> medicines;

  QuickTemplate({
    required this.id,
    required this.name,
    required this.diagnosis,
    required this.medicines,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'diagnosis': diagnosis,
        'medicines': medicines,
      };

  factory QuickTemplate.fromJson(Map<String, dynamic> json) => QuickTemplate(
        id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
        name: json['name'] ?? '',
        diagnosis: json['diagnosis'] ?? '',
        medicines: (json['medicines'] as List<dynamic>? ?? [])
            .map((m) => Map<String, String>.from(m as Map))
            .toList(),
      );
}

class TemplatesStorage {
  static const _key = 'quick_templates_v1';

  static Future<List<QuickTemplate>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    return raw.map((s) => QuickTemplate.fromJson(jsonDecode(s))).toList();
  }

  static Future<void> saveAll(List<QuickTemplate> templates) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        _key, templates.map((t) => jsonEncode(t.toJson())).toList());
  }

  static Future<void> add(QuickTemplate t) async {
    final list = await loadAll();
    list.add(t);
    await saveAll(list);
  }

  static Future<void> update(QuickTemplate t) async {
    final list = await loadAll();
    final idx = list.indexWhere((x) => x.id == t.id);
    if (idx != -1) list[idx] = t;
    await saveAll(list);
  }

  static Future<void> delete(String id) async {
    final list = await loadAll();
    list.removeWhere((x) => x.id == id);
    await saveAll(list);
  }
}

class KashfScreen extends StatefulWidget {
  final Patient? patient;
  final Map<String, dynamic>? doctorData;
  const KashfScreen({super.key, this.patient, this.doctorData});

  @override
  State<KashfScreen> createState() => _KashfScreenState();
}

class _KashfScreenState extends State<KashfScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _diagnosisController = TextEditingController();
  final List<PrescriptionItem> _medicines = [];
  bool _isLoadingHistory = true;
  late DateTime _entryTime;
  late AnimationController _animController;
  late Future<void> _seedFuture;

  String? _headerImagePath;
  final ImagePicker _picker = ImagePicker();

  Map<String, List<String>> _medicinesByFirstLetter = {};
  List<String> _allMedicines = [];
  bool _isMedicinesLoaded = false;
  bool _isLoadingMedicines = false;
  bool _isSaving = false;

  List<QuickTemplate> _quickTemplates = [];

  bool _rxIsArabic = false;

  @override
  void initState() {
    super.initState();
    _entryTime = DateTime.now();
    _animController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _loadHistory();
    _loadMedicinesFromCsv();
    _loadSavedHeader();
    _loadTemplates();
    _loadRxLanguage();
    _addMedicine();
    _seedFuture = _seedPinnedFieldsOnOpen();
  }

  Future<void> _seedPinnedFieldsOnOpen() async {
    if (widget.patient?.id == null) return;
    await CustomFieldsDb.seedPinnedFields(
      patientId: widget.patient!.id!,
      doctorId: int.tryParse(widget.doctorData?['id']?.toString() ?? '0') ?? 0,
    );
  }

  @override
  void dispose() {
    _diagnosisController.dispose();
    _animController.dispose();
    for (var med in _medicines) med.dispose();
    super.dispose();
  }

  Future<void> _loadRxLanguage() async {
    final isAr = await loadRxIsArabic();
    if (mounted) setState(() => _rxIsArabic = isAr);
  }

  Future<void> _toggleRxLanguage() async {
    final next = !_rxIsArabic;
    await saveRxIsArabic(next);
    if (mounted) {
      setState(() => _rxIsArabic = next);
      _showMsg(
        next ? 'الروشتة ستُطبع بالعربي ✓' : 'Rx will print in English ✓',
      );
    }
  }

  void _showMsg(String msg, {bool isError = false}) {
    if (!mounted) return;
    final screenWidth = MediaQuery.of(context).size.width;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(
          msg,
          style: const TextStyle(fontSize: 12, color: Colors.white),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
        backgroundColor: isError ? kDanger : kSuccess,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        margin: EdgeInsets.only(
            bottom: 80, left: screenWidth * 0.22, right: screenWidth * 0.22),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: 4,
      ));
  }

  Future<void> _loadTemplates() async {
    final list = await TemplatesStorage.loadAll();
    if (mounted) setState(() => _quickTemplates = list);
  }

  void _applyTemplate(QuickTemplate t) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.bolt_rounded, color: kOptiBlue),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                t.name,
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: kOptiBlue),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: kBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Diagnosis:",
                      style: TextStyle(
                          color: Colors.grey,
                          fontSize: 11,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(t.diagnosis,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  const Text("Medicines:",
                      style: TextStyle(
                          color: Colors.grey,
                          fontSize: 11,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  ...t.medicines.map((m) => Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text(
                          "• ${m['name']}  ${m['dose'] != null && m['dose']!.isNotEmpty ? '— ${m['dose']}' : ''}  ${m['duration'] != null && m['duration']!.isNotEmpty ? '(${m['duration']})' : ''}",
                          style: const TextStyle(fontSize: 13),
                        ),
                      )),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              "The form will be filled with this data. You can edit it before printing.",
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: kOptiBlue,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.check, color: Colors.white, size: 18),
            label: const Text("Apply",
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
            onPressed: () {
              Navigator.pop(ctx);
              _fillFormFromTemplate(t);
            },
          ),
        ],
      ),
    );
  }

  void _fillFormFromTemplate(QuickTemplate t) {
    setState(() {
      _diagnosisController.text = t.diagnosis;
      for (var m in _medicines) m.dispose();
      _medicines.clear();
      for (var med in t.medicines) {
        final item = PrescriptionItem();
        item.nameController.text = med['name'] ?? '';
        item.doseController.text = med['dose'] ?? '';
        item.durationController.text = med['duration'] ?? '';
        _medicines.add(item);
      }
      if (_medicines.isEmpty) _medicines.add(PrescriptionItem());
    });
    _showMsg("✓ Template applied: ${t.name}");
  }

  void _showQuickTemplatesSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _TemplatesBottomSheet(
        templates: _quickTemplates,
        allMedicines: _allMedicines,
        medicinesByFirstLetter: _medicinesByFirstLetter,
        isMedicinesLoaded: _isMedicinesLoaded,
        onApply: (t) {
          Navigator.pop(ctx);
          _applyTemplate(t);
        },
        onAdded: (t) async {
          await TemplatesStorage.add(t);
          await _loadTemplates();
        },
        onUpdated: (t) async {
          await TemplatesStorage.update(t);
          await _loadTemplates();
        },
        onDeleted: (id) async {
          await TemplatesStorage.delete(id);
          await _loadTemplates();
        },
        onAddCustomMedicine: _addCustomMedicine,
      ),
    );
  }

  Future<void> _loadSavedHeader() async {
    final prefs = await SharedPreferences.getInstance();
    setState(
        () => _headerImagePath = prefs.getString('doctor_letterhead_path'));
  }

  Future<void> _pickHeaderImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('doctor_letterhead_path', image.path);
      setState(() => _headerImagePath = image.path);
      _showMsg("Letterhead updated successfully");
    }
  }

  Future<void> _generateAndOpenPDF({bool printOnBlank = false}) async {
    pw.Font? arabicFont;
    try {
      final data = await rootBundle.load('assets/fonts/Amiri-Regular.ttf');
      arabicFont = pw.Font.ttf(data);
    } catch (_) {}

    final medicinesList = _medicines
        .where((m) => m.nameController.text.isNotEmpty)
        .map((m) => {
              'name': m.nameController.text,
              'dose': m.doseController.text,
              'duration': m.durationController.text,
            })
        .toList();

    final page = await buildRxPage(
      imagePath: _headerImagePath,
      patientName: widget.patient?.name ?? '',
      patientAge: widget.patient?.age?.toString() ?? '',
      visitDate: DateTime.now(),
      diagnosis: _diagnosisController.text.trim(),
      medicines: medicinesList,
      arabicFont: arabicFont,
      patientId: widget.patient!.id!,
      printOnBlank: printOnBlank,
      isArabic: _rxIsArabic,
    );

    final pdf = pw.Document();
    pdf.addPage(page);
    final pdfBytes = await pdf.save();

    final patientName =
        (widget.patient?.name ?? 'Patient').replaceAll(RegExp(r'[^\w]'), '_');
    final now = DateTime.now();
    final fileName =
        'Rx_${patientName}_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}.pdf';

    Directory saveDir;
    try {
      saveDir = await getApplicationDocumentsDirectory();
    } catch (_) {
      saveDir = await getTemporaryDirectory();
    }

    final file = File('${saveDir.path}/$fileName');
    await file.writeAsBytes(pdfBytes);

    final result = await OpenFile.open(file.path);
    if (result.type != ResultType.done) {
      _showMsg("Could not open PDF viewer: ${result.message}", isError: true);
    }
  }

  Future<void> _addCustomMedicine(String name) async {
    if (name.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('custom_medicines') ?? [];
    if (!list.contains(name)) {
      list.add(name);
      await prefs.setStringList('custom_medicines', list);
      setState(() {
        _allMedicines = (_allMedicines..add(name)).toSet().toList()..sort();
        final letter = name[0].toUpperCase();
        _medicinesByFirstLetter.putIfAbsent(letter, () => []).add(name);
        _medicinesByFirstLetter[letter]?.sort();
      });
    }
  }

  Future<void> _loadMedicinesFromCsv() async {
    try {
      if (_isLoadingMedicines) return;
      setState(() => _isLoadingMedicines = true);

      void addName(
          String name, List<String> temp, Map<String, List<String>> tempMap) {
        if (name.length < 2) return;
        temp.add(name);
        String letter = name[0].toUpperCase();
        tempMap.putIfAbsent(letter, () => []).add(name);
      }

      final rawData = await rootBundle
          .loadString('assets/medicines_data_clean_updated.csv');
      final lines = const LineSplitter().convert(rawData);
      final List<String> temp = [];
      final Map<String, List<String>> tempMap = {};

      for (var line in lines) {
        String name =
            line.contains(',') ? line.split(',')[0].trim() : line.trim();
        addName(name, temp, tempMap);
      }

      final prefs = await SharedPreferences.getInstance();
      final custom = prefs.getStringList('custom_medicines') ?? [];
      for (var name in custom) {
        addName(name, temp, tempMap);
      }

      setState(() {
        _allMedicines = temp.toSet().toList()..sort();
        _medicinesByFirstLetter = tempMap;
        _isMedicinesLoaded = true;
        _isLoadingMedicines = false;
      });
    } catch (e) {
      setState(() => _isLoadingMedicines = false);
    }
  }

  void _showMedicineDialog(int index) {
    String query = "";
    List<String> filtered = [];
    final manualController = TextEditingController(
      text: _medicines[index].isManual
          ? _medicines[index].nameController.text
          : "",
    );

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final sortedKeys = _medicinesByFirstLetter.keys.toList()..sort();
          return Dialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            insetPadding: const EdgeInsets.all(16),
            child: Container(
              width: 520,
              height: 640,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: kCard,
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                    decoration: const BoxDecoration(
                      color: kOptiBlue,
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.medication_rounded,
                            color: Colors.white, size: 22),
                        const SizedBox(width: 10),
                        const Text(
                          "Select Medicine",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.pop(dialogContext),
                        ),
                      ],
                    ),
                  ),
                  DefaultTabController(
                    length: 3,
                    child: Expanded(
                      child: Column(
                        children: [
                          const TabBar(
                            labelColor: kOptiBlue,
                            unselectedLabelColor: Colors.grey,
                            indicatorColor: kOptiBlue,
                            tabs: [
                              Tab(
                                  icon: Icon(Icons.edit_rounded),
                                  text: "Type Manually"),
                              Tab(
                                  icon: Icon(Icons.search),
                                  text: "Search Database"),
                              Tab(
                                  icon: Icon(Icons.add),
                                  text: "Add to Database"),
                            ],
                          ),
                          Expanded(
                            child: TabBarView(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        "Enter medicine name manually:",
                                        style: TextStyle(
                                          color: Colors.grey,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      TextField(
                                        controller: manualController,
                                        autofocus: false,
                                        textCapitalization:
                                            TextCapitalization.words,
                                        decoration: InputDecoration(
                                          hintText: "e.g. Amoxicillin 500mg",
                                          prefixIcon: const Icon(
                                              Icons.edit_rounded,
                                              color: kOptiBlue),
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            borderSide: const BorderSide(
                                                color: kOptiBlue, width: 2),
                                          ),
                                          filled: true,
                                          fillColor: kBg,
                                        ),
                                      ),
                                      const SizedBox(height: 20),
                                      SizedBox(
                                        width: double.infinity,
                                        height: 48,
                                        child: ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: kOptiBlue,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                          ),
                                          icon: const Icon(Icons.check,
                                              color: Colors.white),
                                          label: const Text(
                                            "Confirm",
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          onPressed: () {
                                            final text =
                                                manualController.text.trim();
                                            if (text.isEmpty) return;
                                            setState(() {
                                              _medicines[index]
                                                  .nameController
                                                  .text = text;
                                              _medicines[index].isManual = true;
                                            });
                                            Navigator.pop(dialogContext);
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                    children: [
                                      TextField(
                                        autofocus: true,
                                        decoration: InputDecoration(
                                          hintText: "Type medicine name...",
                                          prefixIcon: const Icon(Icons.search,
                                              color: kOptiBlue),
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            borderSide: const BorderSide(
                                                color: kOptiBlue, width: 2),
                                          ),
                                          filled: true,
                                          fillColor: kBg,
                                        ),
                                        onChanged: (v) => setDialogState(() {
                                          query = v.toLowerCase();
                                          filtered = _allMedicines
                                              .where((m) => m
                                                  .toLowerCase()
                                                  .contains(query))
                                              .take(80)
                                              .toList();
                                        }),
                                      ),
                                      const SizedBox(height: 10),
                                      if (query.isEmpty && !_isMedicinesLoaded)
                                        const Expanded(
                                          child: Center(
                                              child: CircularProgressIndicator(
                                                  color: kOptiBlue)),
                                        )
                                      else if (query.isEmpty)
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                "Browse by letter:",
                                                style: TextStyle(
                                                  color: Colors.grey,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              Expanded(
                                                child: SingleChildScrollView(
                                                  child: Wrap(
                                                    spacing: 6,
                                                    runSpacing: 6,
                                                    children: sortedKeys
                                                        .map((l) => ActionChip(
                                                              label: Text(
                                                                l,
                                                                style:
                                                                    const TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  color:
                                                                      kOptiBlue,
                                                                ),
                                                              ),
                                                              backgroundColor:
                                                                  kOptiBlue
                                                                      .withOpacity(
                                                                          0.08),
                                                              onPressed: () =>
                                                                  setDialogState(
                                                                      () {
                                                                query = l
                                                                    .toLowerCase();
                                                                filtered =
                                                                    _medicinesByFirstLetter[
                                                                        l]!;
                                                              }),
                                                            ))
                                                        .toList(),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        )
                                      else
                                        Expanded(
                                          child: filtered.isEmpty
                                              ? const Center(
                                                  child: Text(
                                                    "No medicines found",
                                                    style: TextStyle(
                                                        color: Colors.grey),
                                                  ),
                                                )
                                              : ListView.separated(
                                                  itemCount: filtered.length,
                                                  separatorBuilder: (_, __) =>
                                                      const Divider(height: 1),
                                                  itemBuilder: (context, i) =>
                                                      ListTile(
                                                    dense: true,
                                                    leading: const Icon(
                                                      Icons
                                                          .medication_liquid_rounded,
                                                      color: kOptiBlue,
                                                      size: 20,
                                                    ),
                                                    title: Text(
                                                      filtered[i],
                                                      style: const TextStyle(
                                                          fontSize: 14),
                                                    ),
                                                    onTap: () {
                                                      setState(() {
                                                        _medicines[index]
                                                            .nameController
                                                            .text = filtered[i];
                                                        _medicines[index]
                                                            .isManual = false;
                                                      });
                                                      Navigator.pop(
                                                          dialogContext);
                                                    },
                                                  ),
                                                ),
                                        ),
                                    ],
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        "Add new medicine to database:",
                                        style: TextStyle(
                                          color: Colors.grey,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      TextField(
                                        controller: manualController,
                                        autofocus: false,
                                        textCapitalization:
                                            TextCapitalization.words,
                                        decoration: InputDecoration(
                                          hintText: "e.g. Azithromycin 250mg",
                                          prefixIcon: const Icon(Icons.add,
                                              color: kOptiBlue),
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            borderSide: const BorderSide(
                                                color: kOptiBlue, width: 2),
                                          ),
                                          filled: true,
                                          fillColor: kBg,
                                        ),
                                      ),
                                      const SizedBox(height: 20),
                                      SizedBox(
                                        width: double.infinity,
                                        height: 48,
                                        child: ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: kOptiBlue,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                          ),
                                          icon: const Icon(Icons.save,
                                              color: Colors.white),
                                          label: const Text(
                                            "Save and Select",
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          onPressed: () async {
                                            final text =
                                                manualController.text.trim();
                                            if (text.isEmpty) return;
                                            await _addCustomMedicine(text);
                                            setState(() {
                                              _medicines[index]
                                                  .nameController
                                                  .text = text;
                                              _medicines[index].isManual = true;
                                            });
                                            _showMsg(
                                                'Medicine added to database');
                                            Navigator.pop(dialogContext);
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _loadHistory() async {
    if (widget.patient != null) {
      await DatabaseService.getLastVisit(
          widget.patient!.name, widget.patient!.phone);
      if (mounted) setState(() => _isLoadingHistory = false);
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  ✅ FIX: _saveAndFinish — raw SQL بدل updatePatientStatus
  //  updatePatientStatus كان بيعمل reorder مخفي بيغير أرقام الدور
  //  دلوقتي بنغير الـ status بس بدون أي تعديل على الـ turn
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> _saveAndFinish() async {
    if (_diagnosisController.text.trim().isEmpty) {
      _showMsg("Please enter a diagnosis before saving", isError: true);
      return;
    }

    final activeMeds =
        _medicines.where((m) => m.nameController.text.isNotEmpty).toList();
    if (activeMeds.isEmpty) {
      _showMsg("Please add at least one medicine", isError: true);
      return;
    }

    setState(() => _isSaving = true);

    try {
      final treatment = activeMeds.map((m) => m.nameController.text).join(", ");

      final elapsed = DateTime.now().difference(_entryTime);
      final mins = elapsed.inMinutes;
      final secs = elapsed.inSeconds % 60;
      final durationStr = mins > 0
          ? '$mins دقيقة${secs > 0 ? ' و$secs ثانية' : ''}'
          : '$secs ثانية';

      await DatabaseService.saveExamination(
        patientId: widget.patient!.id!,
        diagnosis: _diagnosisController.text,
        treatment: treatment,
        duration: durationStr,
      );

      await CustomFieldsDb.seedPinnedFields(
        patientId: widget.patient!.id!,
        doctorId:
            int.tryParse(widget.doctorData?['id']?.toString() ?? '0') ?? 0,
      );

      // ✅ FIX: raw SQL مباشر — مفيش reorder، الأرقام تفضل زي ما هي
      await DatabaseService.execute(
        "UPDATE patients SET status = 'completed' WHERE id = :id",
        {'id': widget.patient!.id!},
      );
      await DatabaseService.updateSetting(
        'last_patient_change',
        DateTime.now().toIso8601String(),
      );

      _showMsg("Saved ✓ — Opening PDF...");
      await Future.delayed(const Duration(milliseconds: 400));
      await _generateAndOpenPDF(printOnBlank: true);

      // ✅ رجّع true عشان patient_card يعرف إن الحفظ تم فعلاً
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      _showMsg("Failed to save. Please try again.", isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ✅ dialog تأكيد الخروج بدون حفظ
  Future<void> _confirmExit() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: kDanger, size: 24),
            SizedBox(width: 8),
            Text(
              "Exit without saving?",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        content: const Text(
          "If you go back now, the examination will NOT be saved and the patient will stay in the queue.",
          style: TextStyle(fontSize: 13, color: Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              "Stay",
              style: TextStyle(color: kOptiBlue, fontWeight: FontWeight.bold),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kDanger,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              "Exit",
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      Navigator.pop(context);
    }
  }

  void _addMedicine() => setState(() => _medicines.add(PrescriptionItem()));

  Widget _buildRxLangToggle() {
    final isAr = _rxIsArabic;
    return Tooltip(
      message: isAr ? 'Switch Rx to English' : 'تبديل الروشتة للعربي',
      child: GestureDetector(
        onTap: _toggleRxLanguage,
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 6),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withOpacity(0.5),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  style: TextStyle(
                    color:
                        !isAr ? Colors.white : Colors.white.withOpacity(0.35),
                    fontSize: 11,
                    fontWeight: !isAr ? FontWeight.bold : FontWeight.normal,
                    fontFamily: 'Roboto',
                  ),
                  child: const Text('E'),
                ),
                const SizedBox(width: 5),
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withOpacity(0.6),
                        blurRadius: 3,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 5),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  style: TextStyle(
                    color: isAr ? Colors.white : Colors.white.withOpacity(0.35),
                    fontSize: 11,
                    fontWeight: isAr ? FontWeight.bold : FontWeight.normal,
                    fontFamily: 'Roboto',
                  ),
                  child: const Text('A'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _confirmExit();
      },
      child: Scaffold(
        backgroundColor: kBg,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: kOptiBlue,
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: _confirmExit,
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "New Examination",
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 17),
              ),
              Text(
                widget.patient?.name ?? '',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
          actions: [
            SizedBox(height: 40, child: _buildRxLangToggle()),
            Tooltip(
              message: "Upload Letterhead",
              child: IconButton(
                icon: const Icon(Icons.image_rounded),
                onPressed: _pickHeaderImage,
              ),
            ),
            Tooltip(
              message: "Preview with Background",
              child: IconButton(
                icon: const Icon(Icons.preview_rounded),
                onPressed: () => _generateAndOpenPDF(printOnBlank: false),
              ),
            ),
            Tooltip(
              message: "Print on Pre-printed Paper",
              child: IconButton(
                icon: const Icon(Icons.print_rounded),
                onPressed: () => _generateAndOpenPDF(printOnBlank: true),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            _buildLiveTimer(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPatientCard(),
                    const SizedBox(height: 12),
                    _buildQuickTemplatesSection(),
                    const SizedBox(height: 16),
                    _buildDiagnosisSection(),
                    const SizedBox(height: 16),
                    FutureBuilder(
                      future: _seedFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState != ConnectionState.done) {
                          return const SizedBox(
                            height: 60,
                            child: Center(
                              child: CircularProgressIndicator(
                                  color: kOptiBlue, strokeWidth: 2),
                            ),
                          );
                        }
                        return CustomFieldsWidget(
                          patientId: widget.patient!.id!,
                          doctorId: int.tryParse(
                                  widget.doctorData?['id']?.toString() ??
                                      '0') ??
                              0,
                          editable: true,
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildPrescriptionHeader(),
                    _buildMedicinesList(),
                    const SizedBox(height: 30),
                    _buildSaveButton(),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickTemplatesSection() {
    return Container(
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD0E8F5)),
        boxShadow: [
          BoxShadow(
            color: kOptiBlue.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: kOptiBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.bolt_rounded,
                      color: kOptiBlue, size: 18),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    "Quick Templates",
                    style: TextStyle(
                      color: kOptiBlue,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: _showQuickTemplatesSheet,
                  icon: const Icon(Icons.settings_rounded,
                      size: 16, color: kOptiBlue),
                  label: const Text(
                    "Manage",
                    style: TextStyle(
                        color: kOptiBlue,
                        fontWeight: FontWeight.bold,
                        fontSize: 13),
                  ),
                  style: TextButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ),
          if (_quickTemplates.isEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 14, right: 14, bottom: 12),
              child: InkWell(
                onTap: _showQuickTemplatesSheet,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                  decoration: BoxDecoration(
                    color: kBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: kOptiBlue.withOpacity(0.3),
                        style: BorderStyle.solid),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_circle_outline,
                          color: kOptiBlue.withOpacity(0.6), size: 18),
                      const SizedBox(width: 8),
                      Text(
                        "Tap \"Manage\" to add a quick template",
                        style: TextStyle(
                            color: kOptiBlue.withOpacity(0.7), fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SizedBox(
                height: 70,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  itemCount: _quickTemplates.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final t = _quickTemplates[i];
                    return _buildTemplateChip(t);
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTemplateChip(QuickTemplate t) {
    final colors = [
      const Color(0xFF0070BB),
      const Color(0xFF7C3AED),
      const Color(0xFF059669),
      const Color(0xFFD97706),
      const Color(0xFFDC2626),
      const Color(0xFF0891B2),
    ];
    final idx = _quickTemplates.indexOf(t) % colors.length;
    final color = colors[idx];

    return InkWell(
      onTap: () => _applyTemplate(t),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        constraints: const BoxConstraints(minWidth: 90, maxWidth: 140),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.bolt_rounded, color: color, size: 14),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    t.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              "${t.medicines.length} med${t.medicines.length == 1 ? '' : 's'}",
              style: TextStyle(
                color: color.withOpacity(0.7),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveTimer() {
    return StreamBuilder(
      stream: Stream.periodic(const Duration(seconds: 1)),
      builder: (context, _) {
        final elapsed = DateTime.now().difference(_entryTime);
        final minutes = elapsed.inMinutes.toString().padLeft(2, '0');
        final seconds = (elapsed.inSeconds % 60).toString().padLeft(2, '0');
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: kOptiBlue.withOpacity(0.08),
            border: const Border(bottom: BorderSide(color: Color(0xFFD0E8F5))),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.timer_rounded, color: kOptiBlue, size: 16),
              const SizedBox(width: 6),
              Text(
                "Examination Time: $minutes:$seconds",
                style: const TextStyle(
                  color: kOptiBlue,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPatientCard() {
    return GestureDetector(
      onTap: () {
        if (widget.patient != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PatientProfileScreen(
                patientName: widget.patient!.name,
                patientPhone: widget.patient!.phone,
                doctorId:
                    int.tryParse(widget.doctorData?['id']?.toString() ?? '0') ??
                        0,
              ),
            ),
          );
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFD0E8F5)),
          boxShadow: [
            BoxShadow(
              color: kOptiBlue.withOpacity(0.07),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          leading: CircleAvatar(
            backgroundColor: kOptiBlue,
            child: Text(
              (widget.patient?.name ?? 'P')[0].toUpperCase(),
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          title: Text(
            widget.patient?.name ?? 'Unknown Patient',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          subtitle: Text(
            "Age: ${widget.patient?.age ?? '---'}   •   Phone: ${widget.patient?.phone ?? '---'}",
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: kOptiBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.history_rounded, color: kOptiBlue, size: 15),
                SizedBox(width: 5),
                Text(
                  "سجل المريض",
                  style: TextStyle(
                    color: kOptiBlue,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDiagnosisSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel("Diagnosis", Icons.medical_information_rounded),
        const SizedBox(height: 8),
        TextField(
          controller: _diagnosisController,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: "Enter diagnosis here...",
            filled: true,
            fillColor: kCard,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFD0E8F5))),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFD0E8F5))),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: kOptiBlue, width: 2)),
          ),
        ),
      ],
    );
  }

  Widget _buildPrescriptionHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _sectionLabel("Prescription  (Rx)", Icons.receipt_long_rounded),
        TextButton.icon(
          onPressed: _addMedicine,
          icon:
              const Icon(Icons.add_circle_outline, size: 18, color: kOptiBlue),
          label: const Text("Add Medicine",
              style: TextStyle(color: kOptiBlue, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildMedicinesList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _medicines.length,
      itemBuilder: (_, i) => _buildMedCard(i),
    );
  }

  Widget _buildMedCard(int i) {
    final med = _medicines[i];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD0E8F5)),
        boxShadow: [
          BoxShadow(
              color: kOptiBlue.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                      color: kOptiBlue, borderRadius: BorderRadius.circular(8)),
                  alignment: Alignment.center,
                  child: Text("${i + 1}",
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _showMedicineDialog(i),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: kBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFD0E8F5)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              med.nameController.text.isEmpty
                                  ? "Select or type medicine..."
                                  : med.nameController.text,
                              style: TextStyle(
                                color: med.nameController.text.isEmpty
                                    ? Colors.grey
                                    : Colors.black87,
                                fontWeight: med.nameController.text.isEmpty
                                    ? FontWeight.normal
                                    : FontWeight.w600,
                              ),
                            ),
                          ),
                          Icon(
                            med.isManual
                                ? Icons.edit_rounded
                                : Icons.keyboard_arrow_down_rounded,
                            color: Colors.grey,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  onPressed: () => setState(() => _medicines.removeAt(i)),
                  icon:
                      const Icon(Icons.delete_outline_rounded, color: kDanger),
                  tooltip: "Remove",
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const SizedBox(width: 38),
                Expanded(
                  child: TextField(
                    controller: med.doseController,
                    decoration: _inputDecoration(
                        _rxIsArabic ? "الجرعة (مثال: ١×٣)" : "Dose (e.g. 1x3)",
                        Icons.medication_liquid_rounded),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: med.durationController,
                    decoration: _inputDecoration(
                        _rxIsArabic
                            ? "المدة (مثال: ٥ أيام)"
                            : "Duration (e.g. 5 days)",
                        Icons.schedule_rounded),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
      prefixIcon: Icon(icon, color: kOptiBlue, size: 18),
      filled: true,
      fillColor: kBg,
      contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFD0E8F5))),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFD0E8F5))),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: kOptiBlue, width: 1.5)),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: kOptiBlue,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        onPressed: _isSaving ? null : _saveAndFinish,
        icon: _isSaving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2),
              )
            : const Icon(Icons.print_rounded, color: Colors.white),
        label: Text(
          _isSaving ? "Saving..." : "Save & Print",
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String label, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: kOptiBlue, size: 18),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: kOptiBlue,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Templates Bottom Sheet
// ─────────────────────────────────────────────────────────────────────────────
class _TemplatesBottomSheet extends StatefulWidget {
  final List<QuickTemplate> templates;
  final List<String> allMedicines;
  final Map<String, List<String>> medicinesByFirstLetter;
  final bool isMedicinesLoaded;
  final void Function(QuickTemplate) onApply;
  final void Function(QuickTemplate) onAdded;
  final void Function(QuickTemplate) onUpdated;
  final void Function(String id) onDeleted;
  final Future<void> Function(String name) onAddCustomMedicine;

  const _TemplatesBottomSheet({
    required this.templates,
    required this.allMedicines,
    required this.medicinesByFirstLetter,
    required this.isMedicinesLoaded,
    required this.onApply,
    required this.onAdded,
    required this.onUpdated,
    required this.onDeleted,
    required this.onAddCustomMedicine,
  });

  @override
  State<_TemplatesBottomSheet> createState() => _TemplatesBottomSheetState();
}

class _TemplatesBottomSheetState extends State<_TemplatesBottomSheet> {
  late List<QuickTemplate> _templates;

  @override
  void initState() {
    super.initState();
    _templates = List.from(widget.templates);
  }

  void _showMsg(String msg, {bool isError = false}) {
    if (!mounted) return;
    final screenWidth = MediaQuery.of(context).size.width;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(
          msg,
          style: const TextStyle(fontSize: 12, color: Colors.white),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
        backgroundColor: isError ? kDanger : kSuccess,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        margin: EdgeInsets.only(
            bottom: 80, left: screenWidth * 0.22, right: screenWidth * 0.22),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: 4,
      ));
  }

  void _openEditor({QuickTemplate? existing}) async {
    final result = await showDialog<QuickTemplate>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _TemplateEditorDialog(
        template: existing,
        allMedicines: widget.allMedicines,
        medicinesByFirstLetter: widget.medicinesByFirstLetter,
        isMedicinesLoaded: widget.isMedicinesLoaded,
        onAddCustomMedicine: widget.onAddCustomMedicine,
      ),
    );
    if (result != null) {
      if (existing == null) {
        widget.onAdded(result);
        setState(() => _templates.add(result));
      } else {
        widget.onUpdated(result);
        setState(() {
          final idx = _templates.indexWhere((t) => t.id == result.id);
          if (idx != -1) _templates[idx] = result;
        });
      }
    }
  }

  void _delete(QuickTemplate t) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Delete Template",
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Delete template "${t.name}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child:
                  const Text("Cancel", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: kDanger,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8))),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Delete", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      widget.onDeleted(t.id);
      setState(() => _templates.removeWhere((x) => x.id == t.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: kOptiBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.bolt_rounded,
                      color: kOptiBlue, size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Quick Templates",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                          color: kOptiBlue,
                        ),
                      ),
                      Text(
                        "Tap a template to apply it or edit it",
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _openEditor(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kOptiBlue,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                  icon: const Icon(Icons.add, color: Colors.white, size: 18),
                  label: const Text("New",
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _templates.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long_rounded,
                            size: 60, color: Colors.grey[300]),
                        const SizedBox(height: 12),
                        const Text(
                          "No quick templates yet",
                          style: TextStyle(color: Colors.grey, fontSize: 15),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          "Tap \"New\" to add a template",
                          style: TextStyle(color: Colors.grey, fontSize: 13),
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
                      return _buildTemplateCard(t);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTemplateCard(QuickTemplate t) {
    return Container(
      decoration: BoxDecoration(
        color: kBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD0E8F5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: kOptiBlue.withOpacity(0.06),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                const Icon(Icons.bolt_rounded, color: kOptiBlue, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    t.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: kOptiBlue,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => widget.onApply(t),
                  style: TextButton.styleFrom(
                    backgroundColor: kOptiBlue,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text("Apply",
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12)),
                ),
                const SizedBox(width: 4),
                IconButton(
                  onPressed: () => _openEditor(existing: t),
                  icon: const Icon(Icons.edit_rounded,
                      color: kOptiBlue, size: 18),
                  tooltip: "Edit",
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 4),
                IconButton(
                  onPressed: () => _delete(t),
                  icon: const Icon(Icons.delete_outline_rounded,
                      color: kDanger, size: 18),
                  tooltip: "Delete",
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
            child: Row(
              children: [
                const Icon(Icons.medical_information_rounded,
                    size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                const Text("Diagnosis: ",
                    style: TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                        fontWeight: FontWeight.bold)),
                Expanded(
                  child: Text(
                    t.diagnosis.isEmpty ? "—" : t.diagnosis,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 2, 14, 12),
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: t.medicines
                  .map((m) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: kOptiBlue.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          m['name'] ?? '',
                          style: const TextStyle(
                              fontSize: 11,
                              color: kOptiBlue,
                              fontWeight: FontWeight.w600),
                        ),
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Template Editor Dialog
// ─────────────────────────────────────────────────────────────────────────────
class _TemplateEditorDialog extends StatefulWidget {
  final QuickTemplate? template;
  final List<String> allMedicines;
  final Map<String, List<String>> medicinesByFirstLetter;
  final bool isMedicinesLoaded;
  final Future<void> Function(String name) onAddCustomMedicine;

  const _TemplateEditorDialog({
    this.template,
    required this.allMedicines,
    required this.medicinesByFirstLetter,
    required this.isMedicinesLoaded,
    required this.onAddCustomMedicine,
  });

  @override
  State<_TemplateEditorDialog> createState() => _TemplateEditorDialogState();
}

class _TemplateEditorDialogState extends State<_TemplateEditorDialog> {
  final _nameCtrl = TextEditingController();
  final _diagCtrl = TextEditingController();
  final List<_EditableMedRow> _meds = [];

  @override
  void initState() {
    super.initState();
    if (widget.template != null) {
      final t = widget.template!;
      _nameCtrl.text = t.name;
      _diagCtrl.text = t.diagnosis;
      for (var m in t.medicines) {
        _meds.add(_EditableMedRow(
          name: m['name'] ?? '',
          dose: m['dose'] ?? '',
          duration: m['duration'] ?? '',
        ));
      }
    }
    if (_meds.isEmpty) _meds.add(_EditableMedRow());
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _diagCtrl.dispose();
    for (var m in _meds) m.dispose();
    super.dispose();
  }

  void _showMsg(String msg, {bool isError = false}) {
    if (!mounted) return;
    final screenWidth = MediaQuery.of(context).size.width;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(
          msg,
          style: const TextStyle(fontSize: 12, color: Colors.white),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
        backgroundColor: isError ? kDanger : kSuccess,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        margin: EdgeInsets.only(
            bottom: 80, left: screenWidth * 0.22, right: screenWidth * 0.22),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: 4,
      ));
  }

  void _showMedicinePickerForTemplate(int index) {
    String query = "";
    List<String> filtered = [];
    final manualController = TextEditingController(
      text: _meds[index].nameCtrl.text,
    );

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final sortedKeys = widget.medicinesByFirstLetter.keys.toList()
            ..sort();
          return Dialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            insetPadding: const EdgeInsets.all(16),
            child: Container(
              width: 520,
              height: 640,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: kCard,
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                    decoration: const BoxDecoration(
                      color: kOptiBlue,
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.medication_rounded,
                            color: Colors.white, size: 22),
                        const SizedBox(width: 10),
                        const Text(
                          "Select Medicine",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.pop(dialogContext),
                        ),
                      ],
                    ),
                  ),
                  DefaultTabController(
                    length: 3,
                    child: Expanded(
                      child: Column(
                        children: [
                          const TabBar(
                            labelColor: kOptiBlue,
                            unselectedLabelColor: Colors.grey,
                            indicatorColor: kOptiBlue,
                            tabs: [
                              Tab(
                                  icon: Icon(Icons.edit_rounded),
                                  text: "Type Manually"),
                              Tab(
                                  icon: Icon(Icons.search),
                                  text: "Search Database"),
                              Tab(
                                  icon: Icon(Icons.add),
                                  text: "Add to Database"),
                            ],
                          ),
                          Expanded(
                            child: TabBarView(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                          "Enter medicine name manually:",
                                          style: TextStyle(
                                              color: Colors.grey,
                                              fontWeight: FontWeight.w600)),
                                      const SizedBox(height: 12),
                                      TextField(
                                        controller: manualController,
                                        textCapitalization:
                                            TextCapitalization.words,
                                        decoration: InputDecoration(
                                          hintText: "e.g. Amoxicillin 500mg",
                                          prefixIcon: const Icon(
                                              Icons.edit_rounded,
                                              color: kOptiBlue),
                                          border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12)),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            borderSide: const BorderSide(
                                                color: kOptiBlue, width: 2),
                                          ),
                                          filled: true,
                                          fillColor: kBg,
                                        ),
                                      ),
                                      const SizedBox(height: 20),
                                      SizedBox(
                                        width: double.infinity,
                                        height: 48,
                                        child: ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: kOptiBlue,
                                            shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12)),
                                          ),
                                          icon: const Icon(Icons.check,
                                              color: Colors.white),
                                          label: const Text("Confirm",
                                              style: TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold)),
                                          onPressed: () {
                                            final text =
                                                manualController.text.trim();
                                            if (text.isEmpty) return;
                                            setState(() => _meds[index]
                                                .nameCtrl
                                                .text = text);
                                            Navigator.pop(dialogContext);
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                    children: [
                                      TextField(
                                        autofocus: true,
                                        decoration: InputDecoration(
                                          hintText: "Type medicine name...",
                                          prefixIcon: const Icon(Icons.search,
                                              color: kOptiBlue),
                                          border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12)),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            borderSide: const BorderSide(
                                                color: kOptiBlue, width: 2),
                                          ),
                                          filled: true,
                                          fillColor: kBg,
                                        ),
                                        onChanged: (v) => setDialogState(() {
                                          query = v.toLowerCase();
                                          filtered = widget.allMedicines
                                              .where((m) => m
                                                  .toLowerCase()
                                                  .contains(query))
                                              .take(80)
                                              .toList();
                                        }),
                                      ),
                                      const SizedBox(height: 10),
                                      if (query.isEmpty &&
                                          !widget.isMedicinesLoaded)
                                        const Expanded(
                                            child: Center(
                                                child:
                                                    CircularProgressIndicator(
                                                        color: kOptiBlue)))
                                      else if (query.isEmpty)
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const Text("Browse by letter:",
                                                  style: TextStyle(
                                                      color: Colors.grey,
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w600)),
                                              const SizedBox(height: 8),
                                              Expanded(
                                                child: SingleChildScrollView(
                                                  child: Wrap(
                                                    spacing: 6,
                                                    runSpacing: 6,
                                                    children: sortedKeys
                                                        .map((l) => ActionChip(
                                                              label: Text(l,
                                                                  style: const TextStyle(
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .bold,
                                                                      color:
                                                                          kOptiBlue)),
                                                              backgroundColor:
                                                                  kOptiBlue
                                                                      .withOpacity(
                                                                          0.08),
                                                              onPressed: () =>
                                                                  setDialogState(
                                                                      () {
                                                                query = l
                                                                    .toLowerCase();
                                                                filtered = widget
                                                                    .medicinesByFirstLetter[l]!;
                                                              }),
                                                            ))
                                                        .toList(),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        )
                                      else
                                        Expanded(
                                          child: filtered.isEmpty
                                              ? const Center(
                                                  child: Text(
                                                      "No medicines found",
                                                      style: TextStyle(
                                                          color: Colors.grey)))
                                              : ListView.separated(
                                                  itemCount: filtered.length,
                                                  separatorBuilder: (_, __) =>
                                                      const Divider(height: 1),
                                                  itemBuilder: (context, i) =>
                                                      ListTile(
                                                    dense: true,
                                                    leading: const Icon(
                                                        Icons
                                                            .medication_liquid_rounded,
                                                        color: kOptiBlue,
                                                        size: 20),
                                                    title: Text(filtered[i],
                                                        style: const TextStyle(
                                                            fontSize: 14)),
                                                    onTap: () {
                                                      setState(() =>
                                                          _meds[index]
                                                                  .nameCtrl
                                                                  .text =
                                                              filtered[i]);
                                                      Navigator.pop(
                                                          dialogContext);
                                                    },
                                                  ),
                                                ),
                                        ),
                                    ],
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                          "Add new medicine to database:",
                                          style: TextStyle(
                                              color: Colors.grey,
                                              fontWeight: FontWeight.w600)),
                                      const SizedBox(height: 12),
                                      TextField(
                                        controller: manualController,
                                        textCapitalization:
                                            TextCapitalization.words,
                                        decoration: InputDecoration(
                                          hintText: "e.g. Azithromycin 250mg",
                                          prefixIcon: const Icon(Icons.add,
                                              color: kOptiBlue),
                                          border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12)),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            borderSide: const BorderSide(
                                                color: kOptiBlue, width: 2),
                                          ),
                                          filled: true,
                                          fillColor: kBg,
                                        ),
                                      ),
                                      const SizedBox(height: 20),
                                      SizedBox(
                                        width: double.infinity,
                                        height: 48,
                                        child: ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: kOptiBlue,
                                            shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12)),
                                          ),
                                          icon: const Icon(Icons.save,
                                              color: Colors.white),
                                          label: const Text("Save and Select",
                                              style: TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold)),
                                          onPressed: () async {
                                            final text =
                                                manualController.text.trim();
                                            if (text.isEmpty) return;
                                            await widget
                                                .onAddCustomMedicine(text);
                                            setState(() => _meds[index]
                                                .nameCtrl
                                                .text = text);
                                            if (context.mounted) {
                                              _showMsg(
                                                  'Medicine added to database');
                                              Navigator.pop(dialogContext);
                                            }
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _save() {
    if (_nameCtrl.text.trim().isEmpty) {
      _showMsg("Please enter a template name", isError: true);
      return;
    }
    final medicines = _meds
        .where((m) => m.nameCtrl.text.isNotEmpty)
        .map((m) => {
              'name': m.nameCtrl.text.trim(),
              'dose': m.doseCtrl.text.trim(),
              'duration': m.durationCtrl.text.trim(),
            })
        .toList();

    final t = QuickTemplate(
      id: widget.template?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameCtrl.text.trim(),
      diagnosis: _diagCtrl.text.trim(),
      medicines: medicines,
    );
    Navigator.pop(context, t);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.template != null;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        width: 540,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: const BoxDecoration(
                color: kOptiBlue,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  Icon(
                    isEdit ? Icons.edit_rounded : Icons.add_circle_outline,
                    color: Colors.white,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    isEdit ? "Edit Template" : "New Quick Template",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label("Template Name", Icons.label_rounded),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _nameCtrl,
                      decoration: _dec("e.g. URTI or Sore Throat",
                          Icons.drive_file_rename_outline_rounded),
                    ),
                    const SizedBox(height: 16),
                    _label("Diagnosis", Icons.medical_information_rounded),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _diagCtrl,
                      maxLines: 2,
                      decoration: _dec("Enter diagnosis here...",
                          Icons.medical_information_rounded),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _label("Medicines", Icons.medication_rounded),
                        TextButton.icon(
                          onPressed: () =>
                              setState(() => _meds.add(_EditableMedRow())),
                          icon: const Icon(Icons.add_circle_outline,
                              size: 16, color: kOptiBlue),
                          label: const Text("Add Medicine",
                              style: TextStyle(
                                  color: kOptiBlue,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13)),
                          style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...List.generate(
                        _meds.length,
                        (i) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _buildMedRow(i),
                            )),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFEEEEEE))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.grey),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text("Cancel",
                          style: TextStyle(
                              color: Colors.grey, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kOptiBlue,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: const Icon(Icons.save_rounded, color: Colors.white),
                      label: Text(
                        isEdit ? "Save Changes" : "Save Template",
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMedRow(int i) {
    final med = _meds[i];
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: kBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD0E8F5)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                    color: kOptiBlue, borderRadius: BorderRadius.circular(6)),
                alignment: Alignment.center,
                child: Text("${i + 1}",
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 11)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: () => _showMedicinePickerForTemplate(i),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: kCard,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFD0E8F5)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.medication_rounded,
                            color: kOptiBlue, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            med.nameCtrl.text.isEmpty
                                ? "Select or type medicine..."
                                : med.nameCtrl.text,
                            style: TextStyle(
                              color: med.nameCtrl.text.isEmpty
                                  ? Colors.grey
                                  : Colors.black87,
                              fontWeight: med.nameCtrl.text.isEmpty
                                  ? FontWeight.normal
                                  : FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const Icon(Icons.keyboard_arrow_down_rounded,
                            color: Colors.grey, size: 18),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                onPressed: _meds.length > 1
                    ? () => setState(() {
                          _meds[i].dispose();
                          _meds.removeAt(i);
                        })
                    : null,
                icon: Icon(Icons.delete_outline_rounded,
                    color: _meds.length > 1 ? kDanger : Colors.grey[300],
                    size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const SizedBox(width: 32),
              Expanded(
                child: TextField(
                  controller: med.doseCtrl,
                  decoration:
                      _dec("Dose (e.g. 1x3)", Icons.medication_liquid_rounded),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: med.durationCtrl,
                  decoration:
                      _dec("Duration (e.g. 5 days)", Icons.schedule_rounded),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _label(String text, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: kOptiBlue, size: 16),
        const SizedBox(width: 6),
        Text(text,
            style: const TextStyle(
                color: kOptiBlue, fontWeight: FontWeight.bold, fontSize: 13)),
      ],
    );
  }

  InputDecoration _dec(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
      prefixIcon: Icon(icon, color: kOptiBlue, size: 16),
      filled: true,
      fillColor: kCard,
      contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFD0E8F5))),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFD0E8F5))),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: kOptiBlue, width: 1.5)),
    );
  }
}

class _EditableMedRow {
  TextEditingController nameCtrl;
  TextEditingController doseCtrl;
  TextEditingController durationCtrl;

  _EditableMedRow({String name = '', String dose = '', String duration = ''})
      : nameCtrl = TextEditingController(text: name),
        doseCtrl = TextEditingController(text: dose),
        durationCtrl = TextEditingController(text: duration);

  void dispose() {
    nameCtrl.dispose();
    doseCtrl.dispose();
    durationCtrl.dispose();
  }
}
