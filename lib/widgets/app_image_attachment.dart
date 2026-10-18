import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../core/theme/app_theme.dart';

/// Full-screen or large dialog to view an attached image with zoom support.
void showAppImageViewer(
  BuildContext context, {
  required String imagePath,
  String title = 'معاينة الصورة المرفقة',
}) {
  if (imagePath.trim().isEmpty) return;

  showDialog(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 900, maxHeight: 750),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A), // Dark slate background
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Colors.black54,
              blurRadius: 24,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Color(0xFF1E293B), width: 1),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.image_outlined,
                    color: Color(0xFF38BDF8),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          imagePath,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (Platform.isWindows && File(imagePath).existsSync()) ...[
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF38BDF8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                      ),
                      onPressed: () {
                        try {
                          Process.run('cmd', ['/c', 'start', '', imagePath]);
                        } catch (_) {}
                      },
                      icon: const Icon(Icons.open_in_new_rounded, size: 16),
                      label: const Text(
                        'فتح بالعارض الخارجي',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    tooltip: 'إغلاق',
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),

            // Image display with zoom & pan
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(16),
                ),
                child: InteractiveViewer(
                  panEnabled: true,
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Center(
                    child: _buildImageView(imagePath),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _buildImageView(String path) {
  final clean = path.trim();
  if (clean.startsWith('http://') || clean.startsWith('https://')) {
    return Image.network(
      clean,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => _buildImageError(clean),
      loadingBuilder: (_, child, progress) {
        if (progress == null) return child;
        return const Center(
          child: CircularProgressIndicator(color: Color(0xFF38BDF8)),
        );
      },
    );
  }

  final file = File(clean);
  if (!file.existsSync()) {
    return _buildImageError(clean);
  }

  return Image.file(
    file,
    fit: BoxFit.contain,
    errorBuilder: (_, _, _) => _buildImageError(clean),
  );
}

Widget _buildImageError(String path) {
  return Container(
    padding: const EdgeInsets.all(24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.broken_image_outlined,
          color: Color(0xFFEF4444),
          size: 56,
        ),
        const SizedBox(height: 12),
        const Text(
          'تعذر فتح أو عرض ملف الصورة',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          path,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 12,
          ),
        ),
      ],
    ),
  );
}

/// Compact thumbnail representation of an image that can be tapped to enlarge.
class AppImageThumbnail extends StatelessWidget {
  final String imagePath;
  final double width;
  final double height;
  final double borderRadius;
  final String? title;
  final String? tooltip;

  const AppImageThumbnail({
    super.key,
    required this.imagePath,
    this.width = 46,
    this.height = 46,
    this.borderRadius = 8,
    this.title,
    this.tooltip = 'انقر لعرض الصورة بحجم كامل',
  });

  @override
  Widget build(BuildContext context) {
    if (imagePath.trim().isEmpty) return const SizedBox.shrink();

    final isUrl =
        imagePath.startsWith('http://') || imagePath.startsWith('https://');
    final file = isUrl ? null : File(imagePath);
    final exists = isUrl || (file != null && file.existsSync());

    return Tooltip(
      message: tooltip ?? '',
      child: InkWell(
        onTap: () => showAppImageViewer(
          context,
          imagePath: imagePath,
          title: title ?? 'معاينة الصورة المرفقة',
        ),
        borderRadius: BorderRadius.circular(borderRadius),
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: const Color(0xFFCBD5E1), width: 1),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A000000),
                blurRadius: 4,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(borderRadius - 1),
                child: !exists
                    ? const Center(
                        child: Icon(
                          Icons.broken_image_rounded,
                          size: 20,
                          color: Color(0xFF94A3B8),
                        ),
                      )
                    : isUrl
                        ? Image.network(
                            imagePath,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const Icon(
                              Icons.broken_image_rounded,
                              size: 20,
                              color: Color(0xFF94A3B8),
                            ),
                          )
                        : Image.file(
                            file!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const Icon(
                              Icons.broken_image_rounded,
                              size: 20,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
              ),
              Positioned(
                bottom: 2,
                right: 2,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(
                    Icons.zoom_in_rounded,
                    color: Colors.white,
                    size: 11,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A formatted card for invoices, orders, details, and projects to show the attached image.
class AppImagePreviewCard extends StatelessWidget {
  final String imagePath;
  final String title;
  final VoidCallback? onDelete;

  const AppImagePreviewCard({
    super.key,
    required this.imagePath,
    this.title = 'مرفق صورة الفاتورة',
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (imagePath.trim().isEmpty) return const SizedBox.shrink();

    final fileName = imagePath.split(RegExp(r'[\\/]')).last;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          AppImageThumbnail(
            imagePath: imagePath,
            width: 44,
            height: 44,
            title: title,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.attachment_rounded,
                      size: 14,
                      color: AppColors.accentPrimary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ],
                ),
                Text(
                  fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEEF2FF),
              foregroundColor: const Color(0xFF4F46E5),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
                side: const BorderSide(color: Color(0xFFC7D2FE)),
              ),
            ),
            onPressed: () => showAppImageViewer(
              context,
              imagePath: imagePath,
              title: title,
            ),
            icon: const Icon(Icons.fullscreen_rounded, size: 16),
            label: const Text(
              'عرض الصورة',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
          if (onDelete != null) ...[
            const SizedBox(width: 6),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, size: 18),
              color: AppColors.dangerWaste,
              tooltip: 'إزالة الصورة',
              onPressed: onDelete,
            ),
          ],
        ],
      ),
    );
  }
}

/// The upload component used in all forms and modals.
/// Completely removes the text field for entering paths and replaces it
/// with a button to pick an image, shows a thumbnail preview, and allows
/// viewing, changing, or removing the image.
class AppImageAttachmentPicker extends StatefulWidget {
  final String? initialPath;
  final ValueChanged<String> onImageChanged;
  final String label;
  final String hint;

  const AppImageAttachmentPicker({
    super.key,
    this.initialPath,
    required this.onImageChanged,
    this.label = 'إرفاق صورة',
    this.hint = 'انقر لرفع صورة من جهازك (PNG, JPG, WEBP)',
  });

  @override
  State<AppImageAttachmentPicker> createState() =>
      _AppImageAttachmentPickerState();
}

class _AppImageAttachmentPickerState extends State<AppImageAttachmentPicker> {
  String _currentPath = '';
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _currentPath = widget.initialPath ?? '';
  }

  @override
  void didUpdateWidget(covariant AppImageAttachmentPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialPath != null && widget.initialPath != _currentPath) {
      _currentPath = widget.initialPath!;
    }
  }

  Future<void> _pickImage() async {
    setState(() => _isUploading = true);
    try {
      final file = await FilePicker.pickFile(
        type: FileType.image,
      );

      if (file != null && file.path != null && file.path!.isNotEmpty) {
        final pickedPath = file.path!;
        // Make a safe local copy in app storage so the image remains available
        final permanentPath = await _copyToAppStorage(pickedPath);
        setState(() {
          _currentPath = permanentPath;
        });
        widget.onImageChanged(permanentPath);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تعذر اختيار ملف الصورة: $e'),
            backgroundColor: AppColors.dangerWaste,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  Future<String> _copyToAppStorage(String originalPath) async {
    try {
      final sourceFile = File(originalPath);
      if (!await sourceFile.exists()) return originalPath;

      String baseDir;
      if (Platform.isWindows) {
        final appData = Platform.environment['APPDATA'];
        baseDir = appData != null && appData.isNotEmpty
            ? '$appData\\MarbleGraniteERP\\media'
            : '${Directory.current.path}\\erp_media';
      } else {
        baseDir = '${Directory.systemTemp.path}/marble_granite_erp/media';
      }

      final dir = Directory(baseDir);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final ext = originalPath.contains('.')
          ? '.${originalPath.split('.').last}'
          : '.jpg';
      final fileName = 'erp_img_${DateTime.now().millisecondsSinceEpoch}$ext';
      final targetPath = '$baseDir${Platform.pathSeparator}$fileName';

      await sourceFile.copy(targetPath);
      return targetPath;
    } catch (_) {
      // In case copy fails, fallback safely to original path
      return originalPath;
    }
  }

  void _clearImage() {
    setState(() {
      _currentPath = '';
    });
    widget.onImageChanged('');
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = _currentPath.trim().isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: hasImage ? const Color(0xFF93C5FD) : const Color(0xFFCBD5E1),
          width: hasImage ? 1.5 : 1,
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                hasImage ? Icons.check_circle_rounded : Icons.photo_library_outlined,
                size: 18,
                color: hasImage ? AppColors.successGreen : const Color(0xFF64748B),
              ),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Color(0xFF1E293B),
                ),
              ),
              const Spacer(),
              if (_isUploading)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 10),

          if (!hasImage)
            InkWell(
              onTap: _isUploading ? null : _pickImage,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFFE2E8F0),
                    style: BorderStyle.solid,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: Color(0xFFEFF6FF),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.cloud_upload_outlined,
                        color: AppColors.accentPrimary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'رفع صورة مباشرة من الجهاز',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: AppColors.accentPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.hint,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  AppImageThumbnail(
                    imagePath: _currentPath,
                    width: 64,
                    height: 64,
                    borderRadius: 8,
                    title: widget.label,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'تم إرفاق الصورة بنجاح',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.successGreen,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _currentPath.split(RegExp(r'[\\/]')).last,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            InkWell(
                              onTap: () => showAppImageViewer(
                                context,
                                imagePath: _currentPath,
                                title: widget.label,
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.visibility_outlined,
                                    size: 14,
                                    color: AppColors.accentPrimary,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'معاينة مكبرة',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.accentPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                        ),
                        onPressed: _isUploading ? null : _pickImage,
                        icon: const Icon(Icons.autorenew_rounded, size: 14),
                        label: const Text(
                          'تغيير',
                          style: TextStyle(fontSize: 11),
                        ),
                      ),
                      const SizedBox(height: 4),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.dangerWaste,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                        ),
                        onPressed: _clearImage,
                        icon: const Icon(Icons.delete_outline_rounded, size: 14),
                        label: const Text(
                          'حذف',
                          style: TextStyle(fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
