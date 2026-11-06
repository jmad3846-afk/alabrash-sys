import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/licensing/license_service.dart';

class LicenseLockScreen extends StatefulWidget {
  const LicenseLockScreen({super.key, required this.onActivated});

  final VoidCallback onActivated;

  @override
  State<LicenseLockScreen> createState() => _LicenseLockScreenState();
}

class _LicenseLockScreenState extends State<LicenseLockScreen> {
  final _service = LicenseService();
  final _codeController = TextEditingController();
  String? _deviceId;
  String? _error;
  bool _loading = true;
  bool _activating = false;

  @override
  void initState() {
    super.initState();
    _loadDeviceId();
  }

  Future<void> _loadDeviceId() async {
    try {
      final id = await _service.getDeviceId();
      if (mounted) {
        setState(() {
          _deviceId = id;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'تعذر قراءة معرف الجهاز';
          _loading = false;
        });
      }
    }
  }

  Future<void> _activate() async {
    final id = _deviceId;
    if (id == null) return;
    setState(() {
      _activating = true;
      _error = null;
    });
    final result = await _service.activate(_codeController.text, id);
    if (!mounted) return;
    if (result == ActivationResult.activated) {
      widget.onActivated();
    } else {
      setState(() {
        _error = switch (result) {
          ActivationResult.expired => 'انتهت صلاحية مفتاح التفعيل',
          ActivationResult.notConfigured =>
            'إعداد مفتاح التوقيع غير مكتمل. يرجى التواصل مع الدعم.',
          _ => 'مفتاح التفعيل غير صالح لهذه الجلسة أو الجهاز',
        };
      });
    }
    setState(() => _activating = false);
  }

  Future<void> _copyDeviceId() async {
    final id = _deviceId;
    if (id == null) return;
    await Clipboard.setData(ClipboardData(text: _service.cleanDeviceId(id)));
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم نسخ معرف الجهاز بنجاح')));
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF0B1220);
    const surface = Color(0xFF121D2E);
    const accent = Color(0xFF43C6AC);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: bg,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Card(
                  color: surface,
                  elevation: 16,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                    side: const BorderSide(color: Color(0xFF26364B)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(32, 32, 32, 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(
                          'assets/images/abaad_logo.png',
                          height: 82,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(
                                Icons.view_in_ar,
                                size: 72,
                                color: accent,
                              ),
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'تفعيل أبعاد ERP',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'يلزم تفعيل ترخيص البرنامج للمتابعة',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFFB7C4D5),
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 28),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            'معرف الجهاز',
                            style: TextStyle(
                              color: Colors.blueGrey.shade100,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 14,
                                ),
                                decoration: BoxDecoration(
                                  color: bg,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xFF34445B),
                                  ),
                                ),
                                child: SelectableText(
                                  _loading
                                      ? 'جارٍ التحميل...'
                                      : (_deviceId ?? 'غير متاح'),
                                  textDirection: TextDirection.ltr,
                                  style: const TextStyle(
                                    color: Color(0xFFE6EDF5),
                                    fontFamily: 'monospace',
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton.filledTonal(
                              onPressed: _deviceId == null
                                  ? null
                                  : _copyDeviceId,
                              icon: const Icon(Icons.copy),
                              tooltip: 'نسخ معرف الجهاز',
                              style: IconButton.styleFrom(
                                foregroundColor: accent,
                                backgroundColor: const Color(0xFF203448),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            'رمز التفعيل',
                            style: TextStyle(
                              color: Colors.blueGrey.shade100,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _codeController,
                          enabled: !_activating,
                          textDirection: TextDirection.ltr,
                          textAlign: TextAlign.center,
                          keyboardType: TextInputType.visiblePassword,
                          autocorrect: false,
                          style: const TextStyle(
                            color: Colors.white,
                            letterSpacing: 1.2,
                          ),
                          decoration: InputDecoration(
                            hintText: 'YYYY-MM-DD-XXXXXXXXXX',
                            hintStyle: const TextStyle(
                              color: Color(0xFF77879B),
                            ),
                            filled: true,
                            fillColor: bg,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Color(0xFF34445B),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Color(0xFF34445B),
                              ),
                            ),
                          ),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Color(0xFFFF7B7B)),
                          ),
                        ],
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed:
                                _loading || _activating || _deviceId == null
                                ? null
                                : _activate,
                            icon: _activating
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.lock_open),
                            label: Text(
                              _activating ? 'جارٍ التحقق...' : 'تفعيل البرنامج',
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: accent,
                              foregroundColor: bg,
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),
                        const Divider(color: Color(0xFF26364B)),
                        const SizedBox(height: 12),
                        const Text(
                          'الشركة: إيليون للحلول البرمجية (Elyon)',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Color(0xFFCBD5E1)),
                        ),
                        const SizedBox(height: 7),
                        const Text(
                          'هاتف: 0931691900',
                          style: TextStyle(color: Color(0xFFCBD5E1)),
                        ),
                        TextButton.icon(
                          onPressed: () => launchUrl(
                            Uri.parse('https://wa.me/963996913023'),
                            mode: LaunchMode.externalApplication,
                          ),
                          icon: const Icon(Icons.chat, size: 18),
                          label: const Text('واتساب: 0996913023'),
                          style: TextButton.styleFrom(foregroundColor: accent),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
