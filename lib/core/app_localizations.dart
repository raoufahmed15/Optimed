// lib/core/app_localizations.dart
enum AppLanguage { arabic, english }

class AppLocalizations {
  final AppLanguage language;
  const AppLocalizations(this.language);

  bool get isArabic => language == AppLanguage.arabic;

  // ── Language toggle ───────────────────────────────────────────────────────
  String get switchLanguageLabel => isArabic ? 'EN' : 'ع';
  String get switchLanguageTooltip =>
      isArabic ? 'Switch to English' : 'التبديل إلى العربية';

  // ── General ───────────────────────────────────────────────────────────────
  String get appTitle =>
      isArabic ? 'نظام العيادة الذكي' : 'Smart Clinic System';
  String get online => isArabic ? 'متصل' : 'Online';
  String get offline => isArabic ? 'غير متصل' : 'Offline';
  String get refresh => isArabic ? 'تحديث' : 'Refresh';
  String get cancel => isArabic ? 'إلغاء' : 'Cancel';
  String get confirm => isArabic ? 'تأكيد' : 'Confirm';
  String get clearAll => isArabic ? 'مسح الكل' : 'Clear All';
  String get logout => isArabic ? 'تسجيل الخروج' : 'Logout';
  String get save => isArabic ? 'حفظ' : 'Save';
  String get delete => isArabic ? 'حذف' : 'Delete';
  String get edit => isArabic ? 'تعديل' : 'Edit';
  String get close => isArabic ? 'إغلاق' : 'Close';
  String get back => isArabic ? 'رجوع' : 'Back';
  String get unknown => isArabic ? 'غير معروف' : 'Unknown';
  String get noPhone => isArabic ? 'لا يوجد هاتف' : 'No phone';
  String get male => isArabic ? 'ذكر' : 'Male';
  String get female => isArabic ? 'أنثى' : 'Female';
  String get years => isArabic ? 'سنة' : 'years';
  String get general => isArabic ? 'عام' : 'General';

  // ── Drawer ────────────────────────────────────────────────────────────────
  String get todaysQueue => isArabic ? 'قائمة اليوم' : "Today's Queue";
  String get analytics => isArabic ? 'الإحصائيات' : 'Analytics';
  String get completedCases =>
      isArabic ? 'الحالات المكتملة' : 'Completed Cases';
  String get patientRecords => isArabic ? 'سجلات المرضى' : 'Patient Records';
  String get customizePrescription =>
      isArabic ? 'تخصيص الوصفة الطبية' : 'Customize Prescription';
  String get importFromOldSystem =>
      isArabic ? 'استيراد من النظام القديم' : 'Import from Old System';

  // ── Dashboard ─────────────────────────────────────────────────────────────
  String get searchHint =>
      isArabic ? 'بحث في قائمة الانتظار...' : 'Search in waiting list...';
  String get queueEmpty => isArabic ? 'القائمة فارغة' : 'Queue is Empty';
  String get noWaiting =>
      isArabic ? 'لا يوجد مرضى في الانتظار.' : 'No patients currently waiting.';
  String get refreshList => isArabic ? 'تحديث القائمة' : 'Refresh List';
  String completedToday(int n) =>
      isArabic ? 'مكتملو اليوم ($n)' : 'Completed Today ($n)';
  String get noCompletedCases =>
      isArabic ? 'لا توجد حالات مكتملة' : 'No Completed Cases';
  String get finishedAppear => isArabic
      ? 'المرضى المنتهية حالاتهم تظهر هنا.'
      : 'Finished patients appear here.';
  String get patientCleared => isArabic
      ? 'تم إخفاء المريض من قائمة اليوم'
      : "Patient cleared from today's list";
  String get confirmClear => isArabic ? 'تأكيد المسح' : 'Confirm Clear';
  String get confirmClearBody => isArabic
      ? 'سيتم إخفاء جميع المرضى المكتملين من هذه الشاشة.'
      : 'This will hide all completed patients from this screen.';

  // ── Nurse call ────────────────────────────────────────────────────────────
  String get callNurse => isArabic ? 'استدعاء الممرضة' : 'Call Nurse';
  String get calling => isArabic ? 'جاري الاتصال...' : 'Calling...';
  String get nursesComing =>
      isArabic ? 'الممرضة في الطريق!' : 'Nurse is Coming!';

  // ── Chat ──────────────────────────────────────────────────────────────────
  String get nurse => isArabic ? 'الممرضة' : 'Nurse';
  String get noMessages => isArabic ? 'لا توجد رسائل بعد' : 'No messages yet';
  String get typeMessage => isArabic ? 'اكتب رسالتك...' : 'Type a message...';

  // ── PatientCard ───────────────────────────────────────────────────────────
  String get startExam => isArabic ? 'بدء الكشف' : 'Start Examination';
  String get completeExam => isArabic ? 'إنهاء الكشف' : 'Complete Examination';
  String get examDone =>
      isArabic ? 'تم الكشف بنجاح' : 'Examination completed successfully';
  String get deleteFromList => isArabic ? 'حذف من القائمة' : 'Delete from list';
  String get turn => isArabic ? 'الدور' : 'Turn';
  String get examination => isArabic ? 'كشف' : 'Examination';

  // ── AllPatientsScreen ─────────────────────────────────────────────────────
  String get patientRecordsTitle =>
      isArabic ? 'سجلات وبحث المرضى' : 'Patient Records & Search';
  String get searchByNameOrPhone =>
      isArabic ? 'بحث بالاسم أو رقم الهاتف...' : 'Search by name or phone...';
  String foundPatients(int found, int total) => isArabic
      ? 'تم العثور على $found مريض${total != found ? '  (من أصل $total سجل)' : ''}'
      : 'Found $found patient${found != 1 ? 's' : ''}${total != found ? ' (of $total records)' : ''}';
  String noResultsFor(String q) =>
      isArabic ? 'لا توجد نتائج لـ "$q"' : 'No results for "$q"';
  String get searchPrompt => isArabic
      ? 'ابحث باسم أو رقم هاتف المريض'
      : 'Search by patient name or phone number';
  String get tryAgain => isArabic
      ? 'تأكد من الاسم أو الرقم وحاول مرة أخرى'
      : 'Check the name or number and try again';
  String get lastVisit => isArabic ? 'آخر زيارة' : 'Last visit';
  String get importedFromOld =>
      isArabic ? 'مستورد من سيستم قديم' : 'Imported from old system';

  // ── AnalyticsScreen — Clinic Tab ──────────────────────────────────────────
  String get totalEarnings => isArabic ? 'إجمالي الأرباح' : 'Total Earnings';
  String get displayedPeriod =>
      isArabic ? 'الفترة المعروضة' : 'Displayed Period';
  String get toWord => isArabic ? 'إلى' : 'To';
  String get statsForPeriod =>
      isArabic ? 'إحصائيات الفترة المختارة' : 'Statistics for Selected Period';
  String get totalPatients => isArabic ? 'إجمالي المرضى' : 'Total Patients';
  String get cases => isArabic ? 'حالات' : 'Cases';
  String get dailyAverage => isArabic ? 'المتوسط اليومي' : 'Daily Average';
  String get serviceDistrib =>
      isArabic ? 'توزيع الخدمات' : 'Service Distribution';
  String get noRecordsFound => isArabic
      ? 'لا توجد سجلات في هذه الفترة'
      : 'No records found for this period';
  String casesCount(int n, int pct) =>
      isArabic ? '$n حالات ($pct%)' : '$n Cases ($pct%)';

  // ── AnalyticsScreen — Tabs ────────────────────────────────────────────────
  String get tabClinicStats => isArabic ? 'إحصائيات العيادة' : 'Clinic Stats';
  String get tabNursePerf => isArabic ? 'أداء الممرضات' : 'Nurse Performance';

  // ── AnalyticsScreen — Nurse Tab ───────────────────────────────────────────
  String get nursePeriodLabel => isArabic ? 'الفترة الزمنية' : 'Time Period';
  String get nurseCompletedNote => isArabic
      ? 'الكشوفات المحسوبة فقط هي التي أكملها الدكتور فعلاً'
      : 'Only examinations actually completed by the doctor are counted';
  String get nurseSummaryTotal => isArabic ? 'إجمالي الحالات' : 'Total Cases';
  String get nurseSummaryCompleted => isArabic ? 'مكتملة' : 'Completed';
  String get nurseSummaryDeleted => isArabic ? 'محذوفة' : 'Deleted by Nurse';
  String get nurseSummaryEarnings => isArabic ? 'إجمالي EGP' : 'Total EGP';
  String get noNurseData => isArabic
      ? 'لا توجد بيانات للممرضات في هذه الفترة'
      : 'No nurse data found for this period';
  String get noNurseDataHint => isArabic
      ? 'تأكد أن الكشوفات مسجل فيها nurse_username'
      : 'Make sure visits have a nurse_username recorded';
  String get nurseLoadError => isArabic
      ? 'خطأ في تحميل إحصائيات الممرضات'
      : 'Error loading nurse statistics';
  String get nurseSentLabel => isArabic ? 'أُرسلت للدكتور' : 'Sent to Doctor';
  String get nurseCompletedLabel =>
      isArabic ? 'أكملها الدكتور ✓' : 'Completed by Doctor ✓';
  String get nurseDeletedLabel =>
      isArabic ? 'حذفتها الممرضة' : 'Deleted by Nurse';
  String get nurseCompletionRate =>
      isArabic ? 'نسبة الإنجاز' : 'Completion Rate';

  // ── KashfScreen ───────────────────────────────────────────────────────────
  String get newExamination => isArabic ? 'كشف جديد' : 'New Examination';
  String get uploadLetterhead =>
      isArabic ? 'رفع الترويسة' : 'Upload Letterhead';
  String get previewBg =>
      isArabic ? 'معاينة مع الخلفية' : 'Preview with Background';
  String get printPrePrinted =>
      isArabic ? 'طباعة على ورق مطبوع' : 'Print on Pre-printed Paper';
  String get examTime => isArabic ? 'وقت الكشف' : 'Examination Time';
  String get patientRecord => isArabic ? 'سجل المريض' : 'Patient Record';
  String get ageLabel => isArabic ? 'السن' : 'Age';
  String get phoneNumber => isArabic ? 'الهاتف' : 'Phone';
  String get quickTemplates => isArabic ? 'قوالب سريعة' : 'Quick Templates';
  String get manage => isArabic ? 'إدارة' : 'Manage';
  String get tapToAddTemplate => isArabic
      ? 'اضغط "إدارة" لإضافة قالب سريع'
      : 'Tap "Manage" to add a quick template';
  String get diagnosisField => isArabic ? 'التشخيص' : 'Diagnosis';
  String get enterDiagnosis =>
      isArabic ? 'أدخل التشخيص هنا...' : 'Enter diagnosis here...';
  String get prescriptionLabel =>
      isArabic ? 'الروشتة (Rx)' : 'Prescription  (Rx)';
  String get addMedicine => isArabic ? 'إضافة دواء' : 'Add Medicine';
  String get saveAndPrint => isArabic ? 'حفظ وطباعة' : 'Save & Print';
  String get saving => isArabic ? 'جاري الحفظ...' : 'Saving...';
  String get diagnosisRequired => isArabic
      ? 'أدخل التشخيص قبل الحفظ'
      : 'Please enter a diagnosis before saving';
  String get medicineRequired => isArabic
      ? 'أضف دواءً واحداً على الأقل'
      : 'Please add at least one medicine';
  String get savedOpening => isArabic
      ? 'تم الحفظ ✓ — جاري فتح الـ PDF...'
      : 'Saved ✓ — Opening PDF...';
  String get failedSave => isArabic
      ? 'فشل الحفظ. حاول مرة أخرى.'
      : 'Failed to save. Please try again.';
  String get selectMedicine =>
      isArabic ? 'اختر أو اكتب دواءً...' : 'Select or type medicine...';
  String get removeMedicine => isArabic ? 'إزالة' : 'Remove';
  String get doseHint => isArabic ? 'الجرعة (مثال: 1×3)' : 'Dose (e.g. 1x3)';
  String get durationHint =>
      isArabic ? 'المدة (مثال: 5 أيام)' : 'Duration (e.g. 5 days)';
  // Medicine dialog
  String get selectMedicineTitle => isArabic ? 'اختر دواءً' : 'Select Medicine';
  String get typeManually => isArabic ? 'اكتب يدوياً' : 'Type Manually';
  String get searchDatabase => isArabic ? 'بحث في القاعدة' : 'Search Database';
  String get addToDatabase => isArabic ? 'أضف للقاعدة' : 'Add to Database';
  String get typeMedicineManual =>
      isArabic ? 'أدخل اسم الدواء يدوياً:' : 'Enter medicine name manually:';
  String get medicineNameHint =>
      isArabic ? 'مثال: أموكسيسيلين 500 ملجم' : 'e.g. Amoxicillin 500mg';
  String get confirmBtn => isArabic ? 'تأكيد' : 'Confirm';
  String get typeMedicineSearch =>
      isArabic ? 'اكتب اسم الدواء...' : 'Type medicine name...';
  String get browseByLetter =>
      isArabic ? 'تصفح حسب الحرف:' : 'Browse by letter:';
  String get noMedicinesFound =>
      isArabic ? 'لا توجد أدوية' : 'No medicines found';
  String get addNewMedicine =>
      isArabic ? 'أضف دواءً جديداً للقاعدة:' : 'Add new medicine to database:';
  String get newMedicineHint =>
      isArabic ? 'مثال: أزيثروميسين 250 ملجم' : 'e.g. Azithromycin 250mg';
  String get saveAndSelect => isArabic ? 'حفظ واختيار' : 'Save and Select';
  String get medicineAdded =>
      isArabic ? 'تم إضافة الدواء للقاعدة' : 'Medicine added to database';
  // Quick Templates
  String get noQuickTemplates =>
      isArabic ? 'لا توجد قوالب سريعة بعد' : 'No quick templates yet';
  String get tapNewToAdd =>
      isArabic ? 'اضغط "جديد" لإضافة قالب' : 'Tap "New" to add a template';
  String get newTemplate => isArabic ? 'جديد' : 'New';
  String get editTemplateLbl => isArabic ? 'تعديل القالب' : 'Edit Template';
  String get newQuickTemplate =>
      isArabic ? 'قالب سريع جديد' : 'New Quick Template';
  String get templateNameLbl => isArabic ? 'اسم القالب' : 'Template Name';
  String get templateNameHint =>
      isArabic ? 'مثال: نزلة برد أو التهاب حلق' : 'e.g. URTI or Sore Throat';
  String get applyTemplate => isArabic ? 'تطبيق' : 'Apply';
  String get deleteTemplate => isArabic ? 'حذف القالب' : 'Delete Template';
  String deleteTemplateMsg(String n) =>
      isArabic ? 'هل تريد حذف القالب "$n"؟' : 'Delete template "$n"?';
  String get medicinesLbl => isArabic ? 'الأدوية' : 'Medicines';
  String get saveTemplate => isArabic ? 'حفظ القالب' : 'Save Template';
  String get saveChanges => isArabic ? 'حفظ التعديلات' : 'Save Changes';
  String templateApplied(String n) =>
      isArabic ? '✓ تم تطبيق القالب: $n' : '✓ Template applied: $n';
  String get templateDiagnosis => isArabic ? 'التشخيص:' : 'Diagnosis:';
  String get templateMedicinesLbl => isArabic ? 'الأدوية:' : 'Medicines:';
  String get formWillFill => isArabic
      ? 'سيتم ملء النموذج بهذه البيانات. يمكنك تعديله قبل الطباعة.'
      : 'The form will be filled with this data. You can edit it before printing.';
  String medsCount(int n) =>
      isArabic ? '$n دواء' : '$n med${n == 1 ? '' : 's'}';
  String get enterTemplateName =>
      isArabic ? 'أدخل اسم القالب' : 'Please enter a template name';
  String get tapManageApply => isArabic
      ? 'اضغط على قالب لتطبيقه أو تعديله'
      : 'Tap a template to apply it or edit it';

  // ── PatientProfileScreen ──────────────────────────────────────────────────
  String get personalData => isArabic ? 'البيانات الشخصية' : 'Personal Info';
  String get fullHistory =>
      isArabic ? 'التاريخ المرضي الكامل' : 'Full Medical History';
  String get totalVisits => isArabic ? 'إجمالي الزيارات' : 'Total Visits';
  String get completedVisits => isArabic ? 'زيارات مكتملة' : 'Completed Visits';
  String get lastVisitLabel => isArabic ? 'آخر زيارة' : 'Last Visit';
  String get noCompletedVisits =>
      isArabic ? 'لا توجد زيارات مكتملة بعد' : 'No completed visits yet';
  String get editVisit => isArabic ? 'تعديل الكشف' : 'Edit Visit';
  String get doctorOnly => isArabic ? 'دكتور فقط' : 'Doctor Only';
  String get visitDate => isArabic ? 'تاريخ الكشف' : 'Visit Date';
  String get visitTypeAndPrice =>
      isArabic ? 'نوع الكشف والسعر' : 'Visit Type & Price';
  String get treatmentPlan =>
      isArabic ? 'خطة العلاج / الأدوية' : 'Treatment Plan';
  String get notesField => isArabic ? 'ملاحظات' : 'Notes';
  String get saveEdits => isArabic ? 'حفظ التعديلات' : 'Save Changes';
  String get editSaved =>
      isArabic ? '✅ تم حفظ تعديلات الكشف' : '✅ Visit saved successfully';
  String get editFailed => isArabic ? 'فشل التعديل' : 'Edit failed';
  String get genderLabel => isArabic ? 'الجنس' : 'Gender';
  String get ageField => isArabic ? 'العمر' : 'Age';
  String get priorityLabel => isArabic ? 'الأولوية' : 'Priority';
  String get departmentLabel => isArabic ? 'القسم' : 'Department';
  String get visitTypeLbl => isArabic ? 'نوع الكشف' : 'Visit Type';
  String get visitTypesNotReady => isArabic
      ? 'لم يتم استلام أنواع الكشوفات من الممرضة بعد.\nاطلب من الممرضة الضغط على "مزامنة" في إعدادات التطبيق.'
      : 'Visit types not yet received from nurse.\nAsk the nurse to tap "Sync" in the app settings.';
  String typeAddedAuto(String t) => isArabic
      ? 'نوع الكشف الحالي "$t" تم إضافته تلقائياً للقائمة.'
      : 'Current visit type "$t" was added automatically to the list.';
  String get priceAutoFromType => isArabic
      ? 'السعر بيتحدد أوتوماتيك من نوع الكشف'
      : 'Price is set automatically from the visit type';
  String get diagnosisLabel => isArabic ? '🩺 التشخيص' : '🩺 Diagnosis';
  String get treatmentLabel => isArabic ? '💊 خطة العلاج' : '💊 Treatment';
  String get notesLabel => isArabic ? '📝 ملاحظات' : '📝 Notes';
  String get feesLabel => isArabic ? 'الرسوم' : 'Fees';
  String get priceLbl => isArabic ? 'السعر (EGP)' : 'Price (EGP)';
  String get editVisitDialogTitle => isArabic ? 'تعديل الكشف' : 'Edit Visit';
  String get additionalNotes =>
      isArabic ? 'ملاحظات إضافية' : 'Additional notes';
  String get editBtn => isArabic ? 'تعديل' : 'Edit';

  // ── ImportMigrationScreen ─────────────────────────────────────────────────
  String get importTitle =>
      isArabic ? 'استيراد بيانات من سيستم قديم' : 'Import Data from Old System';
  String get startOver => isArabic ? 'بدء من جديد' : 'Start Over';
  String get pickFileStep => isArabic ? 'اختيار ملف' : 'Pick File';
  String get mapColumnsStep => isArabic ? 'ربط الأعمدة' : 'Map Columns';
  String get reviewStep => isArabic ? 'مراجعة' : 'Review';
  String get doneStep => isArabic ? 'مكتمل' : 'Done';
  String get transferTitle =>
      isArabic ? 'نقل بياناتك إلى OptiMed' : 'Transfer Your Data to OptiMed';
  String get transferSubtitle => isArabic
      ? 'ارفع ملف بياناتك من أي سيستم قديم.\nالسيستم هيتكيّف تلقائياً مع أي شكل للبيانات.'
      : 'Upload your data file from any old system.\nThe system adapts automatically to any data format.';
  String get autoFormatsNote => isArabic
      ? 'التواريخ بأي صيغة (DD/MM/YYYY أو M/D/YYYY أو YYYY-MM-DD)\nالجنس بالعربي أو الإنجليزي  •  أسماء الأعمدة مختلطة — كلها مدعومة'
      : 'Dates in any format (DD/MM/YYYY, M/D/YYYY, or YYYY-MM-DD)\nGender in Arabic or English  •  Mixed column names — all supported';
  String get supportedFormats =>
      isArabic ? 'الصيغ المدعومة' : 'Supported Formats';
  String get howItWorks => isArabic ? 'كيف يعمل؟' : 'How it works?';
  String get chooseFile => isArabic ? 'اختر ملف البيانات' : 'Choose Data File';
  String get localStorageNote => isArabic
      ? 'البيانات تُخزّن محلياً فقط على جهازك'
      : 'Data is stored locally on your device only';
  String get readingFile =>
      isArabic ? 'جاري قراءة الملف...' : 'Reading file...';
  String get emptyFile => isArabic
      ? 'الملف فارغ أو لا يحتوي على بيانات صالحة.'
      : 'File is empty or has no valid data.';
  String fileReadError(String e) =>
      isArabic ? 'خطأ في قراءة الملف: $e' : 'Error reading file: $e';
  String get confirmMappingBtn =>
      isArabic ? 'تأكيد الربط والمعاينة' : 'Confirm Mapping & Preview';
  String get nameColumnRequired => isArabic
      ? '⚠️ يجب تحديد عمود "اسم المريض" على الأقل'
      : '⚠️ Must select the "Patient Name" column at least';
  String get noValidRecords =>
      isArabic ? 'لم يتم العثور على سجلات صالحة.' : 'No valid records found.';
  String get skipDuplicates => isArabic ? 'تجاهل التكرارات' : 'Skip Duplicates';
  String get skipDuplicatesSub => isArabic
      ? 'لو رقم الهاتف أو الاسم والتاريخ موجودان'
      : 'If phone or name+date already exist';
  String get keepOriginalDates =>
      isArabic ? 'الاحتفاظ بالتواريخ الأصلية' : 'Keep Original Dates';
  String get keepOriginalDatesSub => isArabic
      ? 'سيُسجَّل تاريخ الزيارة من الملف'
      : 'Visit date will be taken from the file';
  String startImport(int n) =>
      isArabic ? 'ابدأ الاستيراد ($n سجل)' : 'Start Import ($n records)';
  String get editMapping => isArabic ? 'تعديل الربط' : 'Edit Mapping';
  String get importDone =>
      isArabic ? 'تم الاستيراد بنجاح! 🎉' : 'Import Successful! 🎉';
  String get importDoneWithErrors =>
      isArabic ? 'اكتمل مع أخطاء' : 'Completed with errors';
  String get importedLabel => isArabic ? 'مستورد' : 'Imported';
  String get skippedLabel => isArabic ? 'مُتجاهل' : 'Skipped';
  String get errorLabel => isArabic ? 'خطأ' : 'Error';
  String get errorDetailsTitle => isArabic ? 'تفاصيل الأخطاء' : 'Error Details';
  String get viewErrorDetails =>
      isArabic ? 'اضغط لرؤية تفاصيل الأخطاء' : 'Tap to view error details';
  String get importDoneNote => isArabic
      ? 'كل بيانات المرضى أُضيفت كأرشيف تاريخي.\nيمكنك الآن مراجعتها في سجلات المرضى.'
      : 'All patient data was added as a historical archive.\nYou can now review them in Patient Records.';
  String get backToDashboard =>
      isArabic ? 'العودة للداشبورد' : 'Back to Dashboard';
  String get importAnotherFile =>
      isArabic ? 'استيراد ملف آخر' : 'Import Another File';
  String get processing => isArabic ? 'جاري المعالجة...' : 'Processing...';
  String importedCount(int n) =>
      isArabic ? 'تم استيراد $n سجل' : 'Imported $n records';
  String get autoNormalized =>
      isArabic ? 'تم التطبيع التلقائي' : 'Auto-Normalized';
  String datesFixed(int n) => isArabic
      ? '• $n تاريخ تم تحويله لصيغة موحدة'
      : '• $n date(s) converted to standard format';
  String genderFixed(int n) =>
      isArabic ? '• $n قيمة جنس تم توحيدها' : '• $n gender value(s) normalized';
  String feeFixed(int n) =>
      isArabic ? '• $n قيمة رسوم تم تنظيفها' : '• $n fee value(s) cleaned';
  String get previewFirst5 =>
      isArabic ? 'معاينة أول 5 سجلات' : 'Preview first 5 records';
  String get afterNormalize => isArabic ? 'بعد التطبيع' : 'After normalizing';
  String get originalValues => isArabic ? 'القيم الأصلية' : 'Original values';
  String get readyRecords => isArabic ? 'سجل جاهز' : 'Ready';
  String get mappedLbl => isArabic ? 'مربوط' : 'Mapped';
  String get ignoredLbl => isArabic ? 'متجاهل' : 'Ignored';
  String get autoSuggested => isArabic ? 'تلقائي' : 'Auto';
  String get mappingInfo => isArabic
      ? 'لكل عمود اختر الحقل المقابل. "تلقائي" = اقتراح السيستم.'
      : 'For each column choose the matching field. "Auto" = system suggestion.';
  String get afterNorm => isArabic ? 'بعد التطبيع:' : 'After norm:';
  // Import – Step 1 how-it-works items
  String get importStep1Title => isArabic ? 'ارفع الملف' : 'Upload File';
  String get importStep1Sub =>
      isArabic ? 'أي صيغة من أي سيستم قديم' : 'Any format from any old system';
  String get importStep2Title => isArabic ? 'ربط الأعمدة' : 'Map Columns';
  String get importStep2Sub => isArabic
      ? 'السيستم يقترح تلقائياً — راجع وعدّل'
      : 'System auto-suggests — review & adjust';
  String get importStep3Title =>
      isArabic ? 'التطبيع التلقائي' : 'Auto Normalize';
  String get importStep3Sub => isArabic
      ? 'تواريخ وجنس ورسوم تتحوّل لصيغة موحدة'
      : 'Dates, gender & fees converted to standard format';
  String get importStep4Title => isArabic ? 'راجع المعاينة' : 'Review Preview';
  String get importStep4Sub => isArabic
      ? 'شوف البيانات بعد التطبيع قبل الاستيراد'
      : 'See normalized data before importing';
  String get importStep5Title => isArabic ? 'استيراد كامل' : 'Full Import';
  String get importStep5Sub => isArabic
      ? 'كل بياناتك تنتقل بأمان كأرشيف تاريخي'
      : 'All your data migrates safely as a historical archive';
  // Import – mapping screen
  String importFileSummary(String name, int cols, int rows) => isArabic
      ? '$name  •  $cols عمود  •  $rows سجل'
      : '$name  •  $cols columns  •  $rows records';
  String mappedCount(int n) => isArabic ? '$n مربوط' : '$n mapped';
  String autoCount(int n) => isArabic ? '$n تلقائي' : '$n auto';
  String ignoredCount(int n) => isArabic ? '$n مُتجاهل' : '$n ignored';
  String get sampleLabel => isArabic ? 'مثال:' : 'Sample:';
  // Import – preview screen
  String get archiveNote => isArabic
      ? 'سيتم حفظ السجلات كأرشيف تاريخي — لن تظهر في قائمة الانتظار'
      : 'Records will be saved as historical archive — won\'t appear in waiting queue';
  String get importingLabel => isArabic ? 'جاري الاستيراد...' : 'Importing...';
  String get importError => isArabic
      ? 'حدث خطأ أثناء الاستيراد:'
      : 'An error occurred during import:';

  // ── PrescriptionCustomizerScreen ──────────────────────────────────────────
  String get customizeRx =>
      isArabic ? 'تخصيص الوصفة' : 'Customize Prescription';
  String get resetLayout => isArabic ? 'إعادة ضبط' : 'Reset';
  String get uploadLetterheadBtn =>
      isArabic ? 'رفع الترويسة' : 'Upload Letterhead';
  String get changeImage => isArabic ? 'تغيير الصورة' : 'Change Image';
  String get layoutSaved =>
      isArabic ? 'تم حفظ التخطيط واللغة' : 'Layout & Language saved';
  String get noLetterhead =>
      isArabic ? 'لم يتم رفع الترويسة' : 'No Letterhead Uploaded';
  String get uploadToStart => isArabic
      ? 'ارفع قالب الوصفة للبدء'
      : 'Upload your prescription template to get started';
  String get addCustomField => isArabic ? 'إضافة حقل مخصص' : 'Add Custom Field';
  String get fieldLabel => isArabic ? 'التسمية' : 'Label';
  String get englishSample => isArabic ? 'نموذج إنجليزي' : 'English Sample';
  String get arabicSample => isArabic ? 'نموذج عربي' : 'Arabic Sample';
  String get addFieldBtn => isArabic ? 'إضافة الحقل' : 'Add Field';
  String get addFieldShort => isArabic ? 'إضافة\nحقل' : 'Add\nField';
  String get sizeLabel => isArabic ? 'الحجم' : 'Size';
}
