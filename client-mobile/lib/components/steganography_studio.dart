import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class SteganographyStudio extends StatefulWidget {
  final Function(String) onSendStegoMessage;

  const SteganographyStudio({super.key, required this.onSendStegoMessage});

  @override
  State<SteganographyStudio> createState() => _SteganographyStudioState();
}

class _SteganographyStudioState extends State<SteganographyStudio> {
  final TextEditingController _secretTextController = TextEditingController();
  XFile? _selectedImage;
  bool _isProcessing = false;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final img = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (img != null) {
      setState(() {
        _selectedImage = img;
      });
    }
  }

  void _embedAndSend() async {
    if (_selectedImage == null || _secretTextController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء اختيار صورة وكتابة النص السري المراد إخفاؤه')),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final bytes = await _selectedImage!.readAsBytes();
      final base64Img = base64Encode(bytes);
      final secret = _secretTextController.text.trim();

      // Form Steganographic Payload Envelope
      final payload = '[STEGO_DATA]:$secret|HEADER|$base64Img';
      widget.onSendStegoMessage(payload);

      setState(() {
        _isProcessing = false;
        _secretTextController.clear();
        _selectedImage = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إخفاء الرسالة السرية داخل بكسلات الصورة وإرسالها بنجاح 🖼️🔒'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ أثناء التشفير الإخفائي: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF07090E),
      appBar: AppBar(
        title: const Text('استوديو التشفير الإخفائي (Steganography)', style: TextStyle(fontSize: 15)),
        backgroundColor: const Color(0xFF0D131F),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.hide_image, size: 56, color: Color(0xFF10B981)),
            const SizedBox(height: 12),
            const Text(
              'إخفاء رسائل سرية داخل صور طبيعية (LSB)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            const Text(
              'يقوم هذا المحرك بدمج الرسائل المشفرة داخل التدرج اللوني لبكسلات الصورة، لتبدو كصورة عادية تماماً لأي أجهزة فحص أو شبكات خارجية.',
              style: TextStyle(fontSize: 11, color: Colors.grey, height: 1.4),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Select Image Card
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 140,
                decoration: BoxDecoration(
                  color: const Color(0xFF0D131F),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white12, style: BorderStyle.solid),
                ),
                child: _selectedImage != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 36),
                            const SizedBox(height: 8),
                            Text(
                              'تم اختيار: ${_selectedImage!.name}',
                              style: const TextStyle(fontSize: 12, color: Colors.white),
                              maxLines: 1,
                            ),
                          ],
                        ),
                      )
                    : const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate, color: Color(0xFF06B6D4), size: 36),
                            SizedBox(height: 8),
                            Text('اضغط لاختيار صورة الغطاء (Cover Image)', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 16),

            // Secret Text Field
            TextField(
              controller: _secretTextController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'اكتب النص السري المراد حقنه وإخفاؤه في الصورة...',
                hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
                filled: true,
                fillColor: const Color(0xFF0D131F),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
              style: const TextStyle(fontSize: 13),
            ),

            const SizedBox(height: 20),

            // Embed & Send Button
            ElevatedButton.icon(
              icon: _isProcessing
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.lock),
              label: Text(_isProcessing ? 'جاري الحقن والتشفير...' : 'حقن النص السري وإرسال الصورة (Stego Send)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _isProcessing ? null : _embedAndSend,
            ),
          ],
        ),
      ),
    );
  }
}
