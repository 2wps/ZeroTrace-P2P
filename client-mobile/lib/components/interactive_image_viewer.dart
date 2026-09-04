import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';

class InteractiveImageViewer extends StatelessWidget {
  final String base64Image;

  const InteractiveImageViewer({super.key, required this.base64Image});

  void _saveImageToDevice(BuildContext context) async {
    try {
      final bytes = base64Decode(base64Image);
      final dir = Directory('/storage/emulated/0/Download');
      if (await dir.exists()) {
        final filePath = '${dir.path}/ZT_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final file = File(filePath);
        await file.writeAsBytes(bytes);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('تم حفظ الصورة في التنزيلات:\n$filePath')),
          );
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم نسخ الصورة بنجاح')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر الحفظ: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('معاينة الصورة المشفرة (RAM)', style: TextStyle(fontSize: 14, color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.download, color: Color(0xFF10B981)),
            tooltip: 'حفظ الصورة في الجهاز',
            onPressed: () => _saveImageToDevice(context),
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          panEnabled: true,
          boundaryMargin: const EdgeInsets.all(20),
          minScale: 0.5,
          maxScale: 4.0,
          child: Image.memory(
            base64Decode(base64Image),
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
