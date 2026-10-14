import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../core/database/erp_provider.dart';

/// Critical multi-step security dialog for the full system factory reset.
/// Returns `true` through [Navigator.pop] only after the wipe succeeded.
class SystemResetModal extends StatefulWidget {
  const SystemResetModal({super.key});

  @override
  State<SystemResetModal> createState() => _SystemResetModalState();
}

class _SystemResetModalState extends State<SystemResetModal> {
  final TextEditingController _confirmController = TextEditingController();
  bool _isWiping = false;
  String? _error;

  bool get _isUnlocked {
    final v = _confirmController.text.trim();
    return v == 'تصفير' || v.toUpperCase() == 'RESET';
  }

  @override
  void dispose() {
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _executeReset() async {
    if (!_isUnlocked || _isWiping) return;
    setState(() {
      _isWiping = true;
      _error = null;
    });
    try {
      await context.read<ERPProvider>().systemFactoryReset();
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isWiping = false;
        _error = 'حدث خطأ أثناء تصفير النظام: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.dangerWaste, width: 2),
      ),
      child: Container(
        width: 580,
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.chipBgRed,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.warning_amber_rounded,
                      color: AppColors.dangerWaste,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      '⚠️ تحذير عالي الخطورة: تصفير وتفريغ النظام بالكامل',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AppColors.dangerWaste,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Warning body
              const Text(
                'هل أنت متأكد تماماً من رغبتك في مسح كافة البيانات والمستندات المخزنة؟\n'
                'هذا الإجراء سيقوم بحذف: (جميع الفواتير، المخزون، سجلات العمال، الحسابات المالية، والديون) '
                'وإعادة البرنامج خالياً تماماً كما لو أنه ثُبّت للتو. لا يمكن التراجع عن هذه العملية بعد التأكيد!',
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.6,
                  color: AppColors.brandPrimaryText,
                ),
              ),
              const SizedBox(height: 18),

              // EXTRA SAFETY MECHANISM: typed confirmation
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFCD34D)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'لتفعيل زر التأكيد، اكتب كلمة الأمان  "تصفير"  أو  "RESET"  في الحقل أدناه:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12.5,
                        color: AppColors.partnersEquityAccent,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _confirmController,
                      enabled: !_isWiping,
                      autofocus: true,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'اكتب: تصفير  أو  RESET',
                      ),
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (_) => _executeReset(),
                    ),
                  ],
                ),
              ),

              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: const TextStyle(
                    color: AppColors.dangerWaste,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // Modal buttons
              Row(
                children: [
                  // Button 1: Cancel (default / safe)
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        foregroundColor: AppColors.brandPrimaryText,
                        side: const BorderSide(color: AppColors.brandSecondaryText),
                      ),
                      onPressed:
                          _isWiping ? null : () => Navigator.of(context).pop(false),
                      icon: const Icon(Icons.cancel_outlined),
                      label: const Text(
                        '[إلغاء الأمر - Cancel]',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Button 2: Confirm (danger, disabled until safety word typed)
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.dangerWaste,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor:
                            AppColors.dangerWaste.withValues(alpha: 0.35),
                        disabledForegroundColor: Colors.white70,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: (_isUnlocked && !_isWiping) ? _executeReset : null,
                      icon: _isWiping
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.delete_forever_rounded),
                      label: Text(
                        _isWiping
                            ? 'جارٍ تصفير النظام...'
                            : '[تأكيد المسح النهائي وتصفير البيانات]',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
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
}
