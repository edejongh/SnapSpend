import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:snapspend_core/snapspend_core.dart';
import '../../../core/providers/scan_provider.dart';
import '../../../core/services/ocr_service_impl.dart';
import '../widgets/camera_preview_widget.dart';
import '../widgets/ocr_overlay_widget.dart';

class SnapScreen extends ConsumerStatefulWidget {
  const SnapScreen({super.key});

  @override
  ConsumerState<SnapScreen> createState() => _SnapScreenState();
}

class _SnapScreenState extends ConsumerState<SnapScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  bool _isInitializing = true;
  bool _isProcessing = false;
  String? _initError;
  FlashMode _flashMode = FlashMode.off;
  final _imagePicker = ImagePicker();
  final _ocrService = OcrServiceImpl();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          _initError = 'No camera found on this device.';
          _isInitializing = false;
        });
        return;
      }
      // Prefer the back camera for scanning receipts
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        back,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _isInitializing = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _initError = 'Camera unavailable: $e';
          _isInitializing = false;
        });
      }
    }
  }

  Future<void> _toggleFlash() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    final next =
        _flashMode == FlashMode.off ? FlashMode.torch : FlashMode.off;
    try {
      await controller.setFlashMode(next);
      if (mounted) setState(() => _flashMode = next);
    } catch (_) {
      // Flash not available on this device — silently ignore
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      controller.dispose();
      if (mounted) setState(() => _flashMode = FlashMode.off);
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    _ocrService.dispose();
    super.dispose();
  }

  Future<void> _captureFromCamera() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (_isProcessing) return;
    if (!_checkScansAvailable()) return;
    try {
      final file = await controller.takePicture();
      await _processImage(file.path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Capture failed: $e')),
        );
      }
    }
  }

  Future<void> _captureFromGallery() async {
    if (!_checkScansAvailable()) return;
    final file = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
      maxWidth: 2000,
    );
    if (file == null || !mounted) return;
    await _processImage(file.path);
  }

  bool _checkScansAvailable() {
    final scanCount = ref.read(monthlyScanCountProvider);
    final remaining = scansRemaining(scanCount);
    if (remaining > 0) return true;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Monthly scan limit reached'),
        action: SnackBarAction(
          label: 'Enter manually',
          onPressed: () => context.push('/snap/review'),
        ),
      ),
    );
    return false;
  }

  Future<void> _processImage(String imagePath) async {
    setState(() => _isProcessing = true);
    try {
      final result = await _ocrService.processImage(imagePath);
      if (!mounted) return;
      // Increment scan counter
      final newCount = await ScanCountService.increment();
      ref.read(monthlyScanCountProvider.notifier).state = newCount;
      // Attach the local image path so the review screen can upload it
      final resultWithPath = OcrResult(
        rawText: result.rawText,
        confidence: result.confidence,
        extractedAmount: result.extractedAmount,
        extractedDate: result.extractedDate,
        extractedVendor: result.extractedVendor,
        suggestedCategory: result.suggestedCategory,
        imagePath: imagePath,
      );
      context.push('/snap/review', extra: resultWithPath);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('OCR failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scanCount = ref.watch(monthlyScanCountProvider);
    final remaining = scansRemaining(scanCount);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: const Text('Snap Receipt'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: remaining <= 5
                    ? Colors.red.withOpacity(0.8)
                    : Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$remaining scans left',
                style: const TextStyle(fontSize: 12, color: Colors.white),
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              _flashMode == FlashMode.torch
                  ? Icons.flashlight_on
                  : Icons.flashlight_off,
            ),
            tooltip: _flashMode == FlashMode.torch
                ? 'Turn off torch'
                : 'Turn on torch',
            onPressed: _controller?.value.isInitialized == true
                ? _toggleFlash
                : null,
          ),
          IconButton(
            icon: const Icon(Icons.photo_library_outlined),
            tooltip: 'Import from gallery',
            onPressed: _isProcessing ? null : _captureFromGallery,
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          _buildCameraBody(),
          if (!_isProcessing && _controller?.value.isInitialized == true)
            const _ScanGuideOverlay(),
          if (_isProcessing) const OcrOverlayWidget(),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: GestureDetector(
                  onTap: _isProcessing ? null : _captureFromCamera,
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      color: Colors.white.withOpacity(0.15),
                    ),
                    child: Icon(
                      Icons.camera,
                      color: _controller?.value.isInitialized == true
                          ? Colors.white
                          : Colors.white38,
                      size: 36,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _isProcessing
                    ? null
                    : () => context.push('/snap/review'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white70,
                ),
                child: const Text('Enter manually'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCameraBody() {
    if (_isInitializing) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (_initError != null || _controller == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.camera_alt_outlined,
                  size: 72, color: Colors.white.withOpacity(0.4)),
              const SizedBox(height: 16),
              Text(
                _initError ?? 'Camera not available',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withOpacity(0.7)),
              ),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: _captureFromGallery,
                icon: const Icon(Icons.photo_library_outlined,
                    color: Colors.white),
                label: const Text('Import from gallery',
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }

    return CameraPreviewWidget(controller: _controller!);
  }
}

// ── Scan guide overlay ────────────────────────────────────────────────────────

class _ScanGuideOverlay extends StatelessWidget {
  const _ScanGuideOverlay();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Guide rect: 80% wide, 55% tall, centred slightly above middle
        final w = constraints.maxWidth * 0.82;
        final h = constraints.maxHeight * 0.52;
        final left = (constraints.maxWidth - w) / 2;
        final top = (constraints.maxHeight - h) / 2 - 24;

        return Stack(
          children: [
            // Semi-transparent surround
            ClipPath(
              clipper: _GuideClipper(
                  rect: Rect.fromLTWH(left, top, w, h)),
              child: Container(color: Colors.black54),
            ),
            // Corner brackets
            Positioned(
              left: left,
              top: top,
              child: _CornerBrackets(width: w, height: h),
            ),
            // Hint text below the guide
            Positioned(
              left: 0,
              right: 0,
              top: top + h + 12,
              child: const Center(
                child: Text(
                  'Align receipt within the frame',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _GuideClipper extends CustomClipper<Path> {
  final Rect rect;
  const _GuideClipper({required this.rect});

  @override
  Path getClip(Size size) {
    return Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(8)))
      ..fillType = PathFillType.evenOdd;
  }

  @override
  bool shouldReclip(_GuideClipper old) => old.rect != rect;
}

class _CornerBrackets extends StatelessWidget {
  final double width;
  final double height;
  const _CornerBrackets({required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    const len = 24.0;
    const thick = 3.0;
    const color = Colors.white;

    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        children: [
          // Top-left
          _Bracket(top: 0, left: 0, lenH: len, lenV: len, thick: thick, color: color),
          // Top-right
          _Bracket(top: 0, right: 0, lenH: len, lenV: len, thick: thick, color: color, flipH: true),
          // Bottom-left
          _Bracket(bottom: 0, left: 0, lenH: len, lenV: len, thick: thick, color: color, flipV: true),
          // Bottom-right
          _Bracket(bottom: 0, right: 0, lenH: len, lenV: len, thick: thick, color: color, flipH: true, flipV: true),
        ],
      ),
    );
  }
}

class _Bracket extends StatelessWidget {
  final double? top, bottom, left, right;
  final double lenH, lenV, thick;
  final Color color;
  final bool flipH, flipV;
  const _Bracket({
    this.top, this.bottom, this.left, this.right,
    required this.lenH, required this.lenV,
    required this.thick, required this.color,
    this.flipH = false, this.flipV = false,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top, bottom: bottom, left: left, right: right,
      child: SizedBox(
        width: lenH,
        height: lenV,
        child: CustomPaint(
          painter: _BracketPainter(
              thick: thick, color: color, flipH: flipH, flipV: flipV),
        ),
      ),
    );
  }
}

class _BracketPainter extends CustomPainter {
  final double thick;
  final Color color;
  final bool flipH, flipV;
  const _BracketPainter(
      {required this.thick, required this.color, required this.flipH, required this.flipV});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = thick
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final x = flipH ? size.width : 0.0;
    final y = flipV ? size.height : 0.0;
    final dx = flipH ? -size.width : size.width;
    final dy = flipV ? -size.height : size.height;

    canvas.drawLine(Offset(x, y), Offset(x + dx, y), paint);
    canvas.drawLine(Offset(x, y), Offset(x, y + dy), paint);
  }

  @override
  bool shouldRepaint(_BracketPainter old) => false;
}
