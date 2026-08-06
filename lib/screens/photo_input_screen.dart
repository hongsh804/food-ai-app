import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../widgets/app_colors.dart';
import '../widgets/app_ui.dart';
import 'analyzing_screen.dart';

class PhotoInputScreen extends StatefulWidget {
  const PhotoInputScreen({super.key});

  @override
  State<PhotoInputScreen> createState() => _PhotoInputScreenState();
}

class _PhotoInputScreenState extends State<PhotoInputScreen> {
  final ImagePicker _picker = ImagePicker();
  Uint8List? _selectedImageBytes;
  String? _selectedSourceLabel;
  bool _isPicking = false;

  Future<void> _pickImage(ImageSource source) async {
    if (_isPicking) return;
    setState(() => _isPicking = true);
    try {
      final image = await _picker.pickImage(
        source: source,
        imageQuality: 84,
        maxWidth: 1600,
      );
      if (image == null) return;
      final bytes = await image.readAsBytes();
      if (!mounted) return;
      setState(() {
        _selectedImageBytes = bytes;
        _selectedSourceLabel = source == ImageSource.camera
            ? '촬영한 사진'
            : '앨범에서 선택한 사진';
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('사진을 가져오지 못했습니다: $error')));
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }

  void _startAnalysis() {
    final bytes = _selectedImageBytes;
    if (bytes == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AnalyzingScreen(
          imageBytes: bytes,
          imageSourceLabel: _selectedSourceLabel,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = _selectedImageBytes != null;
    return Scaffold(
      backgroundColor: const Color(0xFF0F1719),
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (hasImage)
            Image.memory(_selectedImageBytes!, fit: BoxFit.cover)
          else
            const _CameraBackdrop(),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xA6000000),
                  Color(0x10000000),
                  Color(0xC9000000),
                ],
                stops: [0, .48, 1],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                  child: Row(
                    children: [
                      _RoundIconButton(
                        icon: Icons.close_rounded,
                        onTap: () => Navigator.pop(context),
                      ),
                      const Spacer(),
                      if (hasImage)
                        _RoundIconButton(
                          icon: Icons.refresh_rounded,
                          onTap: () => setState(() {
                            _selectedImageBytes = null;
                            _selectedSourceLabel = null;
                          }),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  hasImage ? '사진이 선명한지 확인해주세요' : '음식 전체가 보이도록 촬영해주세요',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  hasImage
                      ? (_selectedSourceLabel ?? '선택한 사진')
                      : 'AI가 음식과 영양 정보를 분석해드려요',
                  style: const TextStyle(
                    color: Color(0xCCFFFFFF),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (!hasImage) const _FocusFrame(),
                const Spacer(),
                _CameraControls(
                  hasImage: hasImage,
                  isPicking: _isPicking,
                  onGallery: () => _pickImage(ImageSource.gallery),
                  onCamera: () => _pickImage(ImageSource.camera),
                  onAnalyze: _startAnalysis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CameraBackdrop extends StatelessWidget {
  const _CameraBackdrop();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -.15),
          radius: 1.15,
          colors: [Color(0xFF40534C), Color(0xFF17201F), Color(0xFF0C1112)],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.restaurant_rounded,
          color: Colors.white.withValues(alpha: .08),
          size: 210,
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .28),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        onPressed: onTap,
        icon: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}

class _FocusFrame extends StatelessWidget {
  const _FocusFrame();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: MediaQuery.sizeOf(context).width * .78,
      height: MediaQuery.sizeOf(context).width * .68,
      child: CustomPaint(painter: _FocusFramePainter()),
    );
  }
}

class _FocusFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const length = 34.0;
    const radius = 15.0;
    final path = Path()
      ..moveTo(0, length)
      ..lineTo(0, radius)
      ..quadraticBezierTo(0, 0, radius, 0)
      ..lineTo(length, 0)
      ..moveTo(size.width - length, 0)
      ..lineTo(size.width - radius, 0)
      ..quadraticBezierTo(size.width, 0, size.width, radius)
      ..lineTo(size.width, length)
      ..moveTo(size.width, size.height - length)
      ..lineTo(size.width, size.height - radius)
      ..quadraticBezierTo(
        size.width,
        size.height,
        size.width - radius,
        size.height,
      )
      ..lineTo(size.width - length, size.height)
      ..moveTo(length, size.height)
      ..lineTo(radius, size.height)
      ..quadraticBezierTo(0, size.height, 0, size.height - radius)
      ..lineTo(0, size.height - length);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CameraControls extends StatelessWidget {
  const _CameraControls({
    required this.hasImage,
    required this.isPicking,
    required this.onGallery,
    required this.onCamera,
    required this.onAnalyze,
  });

  final bool hasImage;
  final bool isPicking;
  final VoidCallback onGallery;
  final VoidCallback onCamera;
  final VoidCallback onAnalyze;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      decoration: const BoxDecoration(
        color: Color(0xF5161D1F),
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: hasImage
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      color: AppColors.mint,
                      size: 19,
                    ),
                    SizedBox(width: 7),
                    Text(
                      '분석할 사진이 준비됐어요',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 17),
                GradientButton(
                  label: 'AI 분석 시작',
                  icon: Icons.auto_awesome_rounded,
                  onPressed: isPicking ? null : onAnalyze,
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: isPicking ? null : onGallery,
                  child: const Text(
                    '다른 사진 선택',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _ControlItem(
                  icon: Icons.photo_library_outlined,
                  label: '앨범',
                  onTap: isPicking ? null : onGallery,
                ),
                GestureDetector(
                  onTap: isPicking ? null : onCamera,
                  child: Container(
                    width: 74,
                    height: 74,
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isPicking ? Colors.white54 : Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: isPicking
                          ? const Padding(
                              padding: EdgeInsets.all(17),
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                color: AppColors.primaryDark,
                              ),
                            )
                          : null,
                    ),
                  ),
                ),
                const _ControlItem(
                  icon: Icons.help_outline_rounded,
                  label: '가이드',
                ),
              ],
            ),
    );
  }
}

class _ControlItem extends StatelessWidget {
  const _ControlItem({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(height: 5),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
