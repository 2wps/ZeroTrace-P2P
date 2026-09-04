import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:image_picker/image_picker.dart';

class QRScannerView extends StatefulWidget {
  const QRScannerView({super.key});

  @override
  State<QRScannerView> createState() => _QRScannerViewState();
}

class _QRScannerViewState extends State<QRScannerView> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    torchEnabled: false,
  );
  bool _isProcessing = false;

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing) return;
    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      if (barcode.rawValue != null && barcode.rawValue!.isNotEmpty) {
        _isProcessing = true;
        Navigator.pop(context, barcode.rawValue);
        break;
      }
    }
  }

  Future<void> _scanFromGallery() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    try {
      final barcodeCapture = await _controller.analyzeImage(image.path);
      if (barcodeCapture != null && barcodeCapture.barcodes.isNotEmpty) {
        final code = barcodeCapture.barcodes.first.rawValue;
        if (code != null && code.isNotEmpty && mounted) {
          Navigator.pop(context, code);
          return;
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لم يتم العثور على رمز QR صالح في الصورة المحددة')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ أثناء فحص الصورة: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('مسح رمز الـ QR', style: TextStyle(fontSize: 16)),
        backgroundColor: const Color(0xFF0D131F),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            tooltip: 'تشغيل/إيقاف الفلاش',
            onPressed: () => _controller.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.flip_camera_android),
            tooltip: 'تبديل الكاميرا',
            onPressed: () => _controller.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        alignment: Alignment.center,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
          // Scanner Overlay Frame
          Container(
            width: 260,
            height: 260,
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFF10B981), width: 3),
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          // Bottom Controls
          Positioned(
            bottom: 40,
            child: Column(
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.photo_library),
                  label: const Text('اختيار صورة من الاستوديو (Gallery)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF162032),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _scanFromGallery,
                ),
                const SizedBox(height: 12),
                const Text(
                  'وجه الكاميرا نحو رمز QR لشاشة الهاتف الآخر أو اختر صورة من المعرض',
                  style: TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
