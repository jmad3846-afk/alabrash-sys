import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../core/models/models.dart';
import '../core/database/erp_provider.dart';

/// Modal dialog providing comprehensive Backup Export & Restore functionality.
/// Allows exporting all software data to external storage (e.g., USB flash drive)
/// and safely restoring and distributing all data across 100% of the software's screens.
class BackupRestoreModal extends StatefulWidget {
  /// 0 = Export Tab, 1 = Restore Tab
  final int initialTab;

  const BackupRestoreModal({super.key, this.initialTab = 0});

  @override
  State<BackupRestoreModal> createState() => _BackupRestoreModalState();
}

class _BackupRestoreModalState extends State<BackupRestoreModal>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Export State
  bool _isExporting = false;
  String? _exportSuccessPath;
  int? _exportFileSizeBytes;
  String? _exportError;

  // Restore State
  bool _isLoadingFile = false;
  bool _isRestoring = false;
  String? _selectedFilePath;
  Map<String, dynamic>? _loadedBackupData;
  Map<String, dynamic>? _restoredMetrics;
  String? _restoreError;
  bool _confirmOverwrite = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 1),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // =========================================================================
  // EXPORT OPERATIONS
  // =========================================================================

  Future<void> _handleExportToFile(ERPProvider erp) async {
    setState(() {
      _isExporting = true;
      _exportError = null;
      _exportSuccessPath = null;
    });

    try {
      final now = DateTime.now();
      final dateStr = DateFormat('yyyy_MM_dd_HHmm').format(now);
      final suggestedFileName = 'Abaad_Backup_$dateStr.json';

      // 1. Pack 100% of the ERP system data
      final backupData = erp.exportFullBackupData();
      final jsonString =
          const JsonEncoder.withIndent('  ').convert(backupData);
      final bytes = Uint8List.fromList(utf8.encode(jsonString));

      // 2. Open Save File Dialog via FilePicker
      Uri? savedUri;
      String? savedPath;

      try {
        savedUri = await FilePicker.saveFile(
          dialogTitle:
              'اختر مكان حفظ النسخة الاحتياطية (فلاشة USB أو قرص خارجي)',
          fileName: suggestedFileName,
          bytes: bytes,
          type: FileType.custom,
          allowedExtensions: ['json'],
        );
        if (savedUri != null) {
          try {
            savedPath = savedUri.toFilePath();
          } catch (_) {
            savedPath = savedUri.path;
          }
        }
      } catch (err) {
        // Fallback: Pick directory and write manually
        final dirPath = await FilePicker.getDirectoryPath(
          dialogTitle: 'اختر مجلد الفلاشة أو القرص لحفظ النسخة الاحتياطية',
        );
        if (dirPath != null) {
          final target = File('$dirPath${Platform.pathSeparator}$suggestedFileName');
          await target.writeAsBytes(bytes, flush: true);
          savedPath = target.path;
        }
      }

      if (savedPath == null && savedUri == null) {
        setState(() => _isExporting = false);
        return;
      }

      final effectivePath = savedPath ?? savedUri?.path ?? suggestedFileName;
      final fileSize = bytes.length;

      if (!mounted) return;
      setState(() {
        _isExporting = false;
        _exportSuccessPath = effectivePath;
        _exportFileSizeBytes = fileSize;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isExporting = false;
        _exportError = 'حدث خطأ أثناء تصدير النسخة الاحتياطية: $e';
      });
    }
  }

  // =========================================================================
  // RESTORE OPERATIONS
  // =========================================================================

  Future<void> _handlePickBackupFile() async {
    setState(() {
      _isLoadingFile = true;
      _restoreError = null;
      _loadedBackupData = null;
      _selectedFilePath = null;
      _confirmOverwrite = false;
      _restoredMetrics = null;
    });

    try {
      final pickedFile = await FilePicker.pickFile(
        dialogTitle:
            'اختر ملف النسخة الاحتياطية (.json) من الفلاشة أو القرص الصلب',
        type: FileType.custom,
        allowedExtensions: ['json', 'abaad'],
      );

      if (pickedFile == null) {
        setState(() => _isLoadingFile = false);
        return;
      }

      String content = '';
      String filePath = pickedFile.name;

      if (pickedFile.path != null && pickedFile.path!.isNotEmpty) {
        filePath = pickedFile.path!;
        final file = File(filePath);
        if (await file.exists()) {
          content = await file.readAsString(encoding: utf8);
        }
      }

      if (content.trim().isEmpty) {
        throw 'تعذر قراءة محتوى الملف أو أن الملف فارغ.';
      }

      final dynamic decoded = jsonDecode(content);

      if (decoded is! Map<String, dynamic>) {
        throw 'تنسيق الملف غير صالح؛ يجب أن يحتوي الملف على كائن بيانات صالح.';
      }

      // Quick validation for Abaad ERP backup
      final hasFinancials = decoded.containsKey('financials') ||
          decoded.containsKey('mainCashBox');
      final hasFactory =
          decoded.containsKey('factory') || decoded.containsKey('factoryBlocks');
      final hasWorkshop =
          decoded.containsKey('workshop') || decoded.containsKey('workshopStock');

      if (!hasFinancials && !hasFactory && !hasWorkshop) {
        throw 'هذا الملف لا يطابق بنية نسخ نظام أبعاد (Abaad ERP).';
      }

      if (!mounted) return;
      setState(() {
        _isLoadingFile = false;
        _selectedFilePath = filePath;
        _loadedBackupData = decoded;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingFile = false;
        _restoreError = 'خطأ في قراءة ملف النسخة الاحتياطية: $e';
      });
    }
  }

  Future<void> _executeRestore(ERPProvider erp) async {
    if (_loadedBackupData == null || !_confirmOverwrite || _isRestoring) return;

    setState(() {
      _isRestoring = true;
      _restoreError = null;
    });

    try {
      // Import and distribute data across 100% of the software sections
      final metrics = await erp.importFullBackupData(_loadedBackupData!);

      if (!mounted) return;
      setState(() {
        _isRestoring = false;
        _restoredMetrics = metrics;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isRestoring = false;
        _restoreError = 'حدث خطأ أثناء استعادة وتوزيع البيانات: $e';
      });
    }
  }

  // =========================================================================
  // BUILD METHOD
  // =========================================================================

  @override
  Widget build(BuildContext context) {
    final erp = Provider.of<ERPProvider>(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Container(
        width: 860,
        constraints: const BoxConstraints(maxHeight: 760),
        child: Column(
          children: [
            // Header Bar
            _buildDialogHeader(context),

            // Tab Bar
            TabBar(
              controller: _tabController,
              labelColor: const Color(0xFF1E293B),
              unselectedLabelColor: Colors.grey.shade600,
              indicatorColor: const Color(0xFF0D9488),
              indicatorWeight: 3,
              tabs: const [
                Tab(
                  icon: Icon(Icons.cloud_upload_rounded),
                  text: 'تصدير نسخة احتياطية (تأمين على فلاشة / خارجي)',
                ),
                Tab(
                  icon: Icon(Icons.cloud_download_rounded),
                  text: 'استعادة نسخة احتياطية (توزيع شامل للبيانات)',
                ),
              ],
            ),

            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildExportTab(context, erp),
                  _buildRestoreTab(context, erp),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // HEADER
  // =========================================================================

  Widget _buildDialogHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A), // Dark slate
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(18),
          topRight: Radius.circular(18),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF0D9488).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF0D9488)),
            ),
            child: const Icon(
              Icons.security_rounded,
              color: Color(0xFF14B8A6),
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'نظام النسخ الاحتياطي والاستعادة الشامل • برنامج أبعاد',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'تأمين وحفظ البيانات على فلاشة خارجية واستعادتها وتوزيعها بدقة على كافة الواجهات',
                  style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded, color: Colors.white70),
            tooltip: 'إغلاق',
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // TAB 1: EXPORT
  // =========================================================================

  Widget _buildExportTab(BuildContext context, ERPProvider erp) {
    final totalCashUsd =
        erp.mainCashBox + erp.scrapCashBox + erp.orderCashBox;
    final totalCashSyp =
        erp.mainCashBoxSyp + erp.scrapCashBoxSyp + erp.orderCashBoxSyp;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Info Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.usb_rounded,
                  color: Color(0xFF16A34A),
                  size: 36,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'حفظ نسخة احتياطية آمنة على فلاشة USB أو وحدة تخزين خارجية',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Color(0xFF15803D),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'يقوم النظام بحزم 100% من بيانات البرمجية (الفواتير، الصناديق بالدولار والليرة، المخزون، العمال، المشاريع، وبيانات المركز) وتشفيرها في ملف موحد جاهز للنقل والتخزين الخارجي لحمايتها من أي طارئ.',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: Colors.grey.shade800,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Statistics Grid of What Will Be Backed Up
          const Text(
            'نطاق التغطية الشاملة للنسخة الحالية:',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 2.2,
            children: [
              _buildSummaryItem(
                icon: Icons.account_balance_rounded,
                title: 'القيد الافتتاحي (الأصول والمخزون)',
                value:
                    '${erp.openingEntry.isLocked ? 'معتمد' : 'مسودة'} • ${erp.openingEntry.fixedAssets.length} أصول • ${erp.openingEntry.openingStock.length} صنف أول مدة',
                color: const Color(0xFF0F766E),
              ),
              _buildSummaryItem(
                icon: Icons.account_balance_wallet_rounded,
                title: 'صناديق السيولة المالية',
                value: AppCurrency.dual(totalCashUsd, totalCashSyp),
                color: const Color(0xFF0D9488),
              ),
              _buildSummaryItem(
                icon: Icons.receipt_long_rounded,
                title: 'فواتير المصنع والمعمل',
                value:
                    '${erp.factoryInvoices.length + erp.workshopInvoices.length + erp.returnInvoices.length} فاتورة',
                color: const Color(0xFF2563EB),
              ),
              _buildSummaryItem(
                icon: Icons.inventory_2_rounded,
                title: 'المخزون (بلوكات وألواح)',
                value:
                    '${erp.factoryBlocks.length} بلوك • ${erp.factoryWarehouse.length} صنف مستودع',
                color: const Color(0xFFD97706),
              ),
              _buildSummaryItem(
                icon: Icons.people_alt_rounded,
                title: 'المعتمدين والموردين',
                value:
                    '${erp.clients.length} معتمد • ${erp.suppliers.length} مورد',
                color: const Color(0xFF7C3AED),
              ),
              _buildSummaryItem(
                icon: Icons.engineering_rounded,
                title: 'الكادر وسجلات الحضور',
                value:
                    '${erp.staffList.length} موظف • ${erp.staffAttendance.length} سجل دوام',
                color: const Color(0xFF059669),
              ),
              _buildSummaryItem(
                icon: Icons.apartment_rounded,
                title: 'مشاريع وورشات المعمل',
                value:
                    '${erp.workshopProjects.length} مشروع • ${erp.workshopOrders.length} طلبية',
                color: const Color(0xFFDC2626),
              ),
              _buildSummaryItem(
                icon: Icons.analytics_rounded,
                title: 'أرشيف التقارير اليومية',
                value: '${erp.dailyReports.length} تقرير يومي محفوظ',
                color: const Color(0xFF0284C7),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Error Display
          if (_exportError != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Color(0xFFDC2626)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _exportError!,
                      style: const TextStyle(
                        color: Color(0xFFDC2626),
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Success Card
          if (_exportSuccessPath != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF22C55E), width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.check_circle_rounded,
                          color: Color(0xFF16A34A), size: 26),
                      SizedBox(width: 8),
                      Text(
                        'تم تصدير وحفظ النسخة الاحتياطية بنجاح تام! 🎉',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Color(0xFF15803D),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'مسار الحفظ: $_exportSuccessPath',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  if (_exportFileSizeBytes != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'حجم الملف: ${(_exportFileSizeBytes! / 1024).toStringAsFixed(1)} كيلوبايت',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    children: [
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF15803D),
                          side: const BorderSide(color: Color(0xFF16A34A)),
                        ),
                        onPressed: () {
                          if (Platform.isWindows && _exportSuccessPath != null) {
                            Process.run('explorer.exe',
                                ['/select,', _exportSuccessPath!]);
                          }
                        },
                        icon: const Icon(Icons.folder_open_rounded, size: 18),
                        label: const Text('فتح موقع الملف في المجلد / الفلاشة'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Export Action Button
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D9488),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 2,
            ),
            onPressed: _isExporting ? null : () => _handleExportToFile(erp),
            icon: _isExporting
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.usb_rounded, size: 24),
            label: Text(
              _isExporting
                  ? 'جاري تجميع وتصدير النسخة الاحتياطية...'
                  : 'تصدير وحفظ النسخة الاحتياطية على فلاشة USB أو قرص خارجي',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // TAB 2: RESTORE
  // =========================================================================

  Widget _buildRestoreTab(BuildContext context, ERPProvider erp) {
    if (_restoredMetrics != null) {
      return _buildRestoreSuccessView(context);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Warning Banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFCD34D)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: Color(0xFFD97706),
                  size: 32,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'إعادة توزيع واستعادة شاملة للبيانات',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Color(0xFF92400E),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'عند تأكيد الاستعادة، سيتم استخراج كافة الملفات والسجلات وإعادة توزيعها تلقائياً على أماكنها الصحيحة (واجهة المصنع، واجهة المعمل، واجهة الحسابات، شؤون العمال، القيد الافتتاحي، الصناديق بالليرة والدولار، والمشاريع). ستظهر التغييرات فوراً في كافة الشاشات دون الحاجة لإعادة تشغيل البرنامج.',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: Colors.brown.shade900,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // File Selection Trigger
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF0F172A),
              side: BorderSide(color: Colors.grey.shade400, width: 1.5),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: _isLoadingFile || _isRestoring
                ? null
                : _handlePickBackupFile,
            icon: _isLoadingFile
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.file_open_rounded,
                    color: Color(0xFF0D9488), size: 24),
            label: Text(
              _selectedFilePath != null
                  ? 'تم اختيار: ${_selectedFilePath!.split(Platform.pathSeparator).last} (انقر للتغيير)'
                  : '📂 استعراض واختيار ملف النسخة الاحتياطية (.json) من الفلاشة أو القرص',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Error Display
          if (_restoreError != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Color(0xFFDC2626)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _restoreError!,
                      style: const TextStyle(
                        color: Color(0xFFDC2626),
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Loaded File Preview & Inspection
          if (_loadedBackupData != null) ...[
            _buildBackupAuditCard(_loadedBackupData!),
            const SizedBox(height: 16),

            // Confirmation Checkbox
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: CheckboxListTile(
                value: _confirmOverwrite,
                onChanged: (val) {
                  setState(() => _confirmOverwrite = val ?? false);
                },
                activeColor: const Color(0xFF0D9488),
                title: const Text(
                  'أؤكد رغبتي في استعادة هذه النسخة وتوزيع بياناتها بالكامل على جميع أقسام وشاشات البرنامج.',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                subtitle: const Text(
                  'سيتم تحديث واجهات المصنع والمعمل والمالية والعمال فوراً.',
                  style: TextStyle(fontSize: 11.5, color: Colors.grey),
                ),
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ),
            const SizedBox(height: 20),

            // Execute Button
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _confirmOverwrite
                    ? const Color(0xFF2563EB)
                    : Colors.grey.shade400,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: _confirmOverwrite ? 2 : 0,
              ),
              onPressed: (_confirmOverwrite && !_isRestoring)
                  ? () => _executeRestore(erp)
                  : null,
              icon: _isRestoring
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.restore_page_rounded, size: 24),
              label: Text(
                _isRestoring
                    ? 'جاري استعادة وتوزيع البيانات عبر كافة الأقسام...'
                    : 'بدء الاستعادة وتوزيع البيانات على كافة الواجهات',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // =========================================================================
  // AUDIT CARD: PREVIEW BEFORE RESTORE
  // =========================================================================

  Widget _buildBackupAuditCard(Map<String, dynamic> raw) {
    final meta = raw['metadata'] is Map ? raw['metadata'] as Map : {};
    final fin = raw['financials'] is Map ? raw['financials'] as Map : raw;
    final fac = raw['factory'] is Map ? raw['factory'] as Map : raw;
    final wrk = raw['workshop'] is Map ? raw['workshop'] as Map : raw;
    final stf = raw['staff'] is Map ? raw['staff'] as Map : raw;
    final ops = raw['operations'] is Map ? raw['operations'] as Map : raw;

    final systemName = meta['systemName']?.toString() ?? 'برنامج أبعاد';
    final exportDate = meta['exportDate']?.toString();
    String formattedDate = 'غير محدد';
    if (exportDate != null) {
      try {
        final dt = DateTime.parse(exportDate);
        formattedDate = DateFormat('yyyy/MM/dd - hh:mm a').format(dt);
      } catch (_) {}
    }

    final facInvoices = (fac['factoryInvoices'] as List?)?.length ?? 0;
    final wrkInvoices = (wrk['workshopInvoices'] as List?)?.length ?? 0;
    final retInvoices = (ops['returnInvoices'] as List?)?.length ?? 0;
    final blocksCount = (fac['factoryBlocks'] as List?)?.length ?? 0;
    final warehouseCount = (fac['factoryWarehouse'] as List?)?.length ?? 0;
    final clientsCount = (fac['clients'] as List?)?.length ?? 0;
    final suppliersCount = (fac['suppliers'] as List?)?.length ?? 0;
    final staffCount = (stf['staffList'] as List?)?.length ?? 0;
    final projectsCount = (wrk['workshopProjects'] as List?)?.length ?? 0;
    final dailyReportsCount = (ops['dailyReports'] as List?)?.length ??
        ((raw['dailyReports'] as List?)?.length ?? 0);

    final mainUsd = (fin['mainCashBox'] as num?)?.toDouble() ?? 0.0;
    final scrapUsd = (fin['scrapCashBox'] as num?)?.toDouble() ?? 0.0;
    final orderUsd = (fin['orderCashBox'] as num?)?.toDouble() ?? 0.0;
    final totalUsd = mainUsd + scrapUsd + orderUsd;

    final mainSyp = (fin['mainCashBoxSyp'] as num?)?.toDouble() ?? 0.0;
    final scrapSyp = (fin['scrapCashBoxSyp'] as num?)?.toDouble() ?? 0.0;
    final orderSyp = (fin['orderCashBoxSyp'] as num?)?.toDouble() ?? 0.0;
    final totalSyp = mainSyp + scrapSyp + orderSyp;

    final opening = fin['openingEntry'] is Map ? fin['openingEntry'] as Map : null;
    final openingLocked = opening?['isLocked'] == true;
    final fixedAssetsCount = (opening?['fixedAssets'] as List?)?.length ?? 0;
    final openingStockCount = (opening?['openingStock'] as List?)?.length ?? 0;
    final legacyCount = (opening?['legacyFinancials'] as List?)?.length ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.verified_rounded, color: Color(0xFF0D9488), size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'فحص محتويات ملف النسخة الاحتياطية ($systemName)',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14.5,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'تاريخ النسخة: $formattedDate',
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF334155)),
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          const Text(
            'سيتم توزيع السجلات التالية تلقائياً عند التطبيق:',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.bold,
              color: Color(0xFF475569),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildDetailPill(
                  label: 'القيد الافتتاحي (Opening Entry)',
                  detail: openingLocked
                      ? 'معتمد ومرحل ($fixedAssetsCount أصول • $openingStockCount بضاعة أول مدة • $legacyCount ذمم سابقة)'
                      : 'مسودة قيد ($fixedAssetsCount أصول • $openingStockCount بضاعة أول مدة)',
                  icon: Icons.account_balance_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildDetailPill(
                  label: 'قسم الحسابات والسيولة',
                  detail: AppCurrency.dual(totalUsd, totalSyp),
                  icon: Icons.account_balance_wallet_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildDetailPill(
                  label: 'فواتير المصنع والمعمل',
                  detail: '$facInvoices مصنع • $wrkInvoices معمل • $retInvoices مرتجع',
                  icon: Icons.receipt_long_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildDetailPill(
                  label: 'المخزون والمستودع',
                  detail: '$blocksCount بلوك • $warehouseCount أصناف ألواح',
                  icon: Icons.inventory_2_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildDetailPill(
                  label: 'الذمم والجهات',
                  detail: '$clientsCount معتمد • $suppliersCount مورد',
                  icon: Icons.people_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildDetailPill(
                  label: 'المشاريع والورشات',
                  detail: '$projectsCount مشروع مسجل بالمعمل',
                  icon: Icons.apartment_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildDetailPill(
                  label: 'كادر العمل',
                  detail: '$staffCount عامل وموظف مسجل',
                  icon: Icons.badge_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildDetailPill(
                  label: 'أرشيف التقارير اليومية',
                  detail: '$dailyReportsCount تقرير يومي شامل',
                  icon: Icons.analytics_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailPill({
    required String label,
    required String detail,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF64748B)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
                Text(
                  detail,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // SUCCESS VIEW AFTER RESTORE
  // =========================================================================

  Widget _buildRestoreSuccessView(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFFDCFCE7),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF86EFAC), width: 2),
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              size: 54,
              color: Color(0xFF16A34A),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'تمت الاستعادة وإعادة التوزيع بنجاح تام! 🎉',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF15803D),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'تمت استعادة وتوزيع كافة البيانات على 100% من أقسام وشاشات البرنامج (المصنع، المعمل، الحسابات، الذمم، العمال، والمشاريع). تم حفظ السجلات على القرص وتحديث واجهات النظام بالكامل فوراً.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Color(0xFF475569), height: 1.5),
          ),
          const SizedBox(height: 24),

          // Restored Metrics Table
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                _buildMetricRow(
                  'القيد الافتتاحي المستعاد:',
                  '${_restoredMetrics?['openingEntryStatus'] ?? 'معتمد ومرحل'} (${_restoredMetrics?['openingFixedAssets'] ?? 0} أصول ثابتة • ${_restoredMetrics?['openingStockItems'] ?? 0} صنف أول مدة)',
                ),
                const Divider(),
                _buildMetricRow(
                  'فواتير المصنع المستعادة:',
                  '${_restoredMetrics?['factoryInvoices'] ?? 0} فاتورة',
                ),
                const Divider(),
                _buildMetricRow(
                  'فواتير المعمل المستعادة:',
                  '${_restoredMetrics?['workshopInvoices'] ?? 0} فاتورة',
                ),
                const Divider(),
                _buildMetricRow(
                  'مخزون البلوكات والمستودع:',
                  '${_restoredMetrics?['factoryBlocks'] ?? 0} بلوك • ${_restoredMetrics?['factoryWarehouse'] ?? 0} ألواح',
                ),
                const Divider(),
                _buildMetricRow(
                  'جهات التعامل المستعادة:',
                  '${_restoredMetrics?['clients'] ?? 0} معتمد • ${_restoredMetrics?['suppliers'] ?? 0} مورد',
                ),
                const Divider(),
                _buildMetricRow(
                  'مشاريع المعمل المستعادة:',
                  '${_restoredMetrics?['workshopProjects'] ?? 0} مشروع كامل',
                ),
                const Divider(),
                _buildMetricRow(
                  'أرشيف التقارير اليومية:',
                  '${_restoredMetrics?['dailyReports'] ?? 0} تقرير يومي مستعاد',
                ),
                const Divider(),
                _buildMetricRow(
                  'إجمالي السيولة النقدية المستعادة:',
                  AppCurrency.dual(
                    (_restoredMetrics?['totalCashUsd'] as num?)?.toDouble() ?? 0.0,
                    (_restoredMetrics?['totalCashSyp'] as num?)?.toDouble() ?? 0.0,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.done_all_rounded),
            label: const Text(
              'العودة إلى الشاشة الرئيسية',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF475569))),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // HELPER METRIC CARD
  // =========================================================================

  Widget _buildSummaryItem({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Colors.grey.shade700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
