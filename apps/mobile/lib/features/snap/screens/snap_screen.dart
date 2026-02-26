import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:snapspend_core/snapspend_core.dart';
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      controller.dispose();
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
    final file = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
      maxWidth: 2000,
    );
    if (file == null || !mounted) return;
    await _processImage(file.path);
  }

  Future<void> _processImage(String imagePath) async {
    setState(() => _isProcessing = true);
    try {
      final result = await _ocrService.processImage(imagePath);
      if (!mounted) return;
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
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: const Text('Snap Receipt'),
        actions: [
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
          if (_isProcessing) const OcrOverlayWidget(),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Center(
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
