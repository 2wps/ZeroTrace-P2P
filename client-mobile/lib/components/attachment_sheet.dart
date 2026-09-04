import 'package:flutter/material.dart';

class AttachmentSheet extends StatelessWidget {
  final VoidCallback onPickGallery;
  final VoidCallback onPickCamera;
  final VoidCallback onPickDocument;
  final VoidCallback onOpenStegano;
  final VoidCallback onOpenWhiteboard;
  final VoidCallback onRecordVoice;

  const AttachmentSheet({
    super.key,
    required this.onPickGallery,
    required this.onPickCamera,
    required this.onPickDocument,
    required this.onOpenStegano,
    required this.onOpenWhiteboard,
    required this.onRecordVoice,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: const BoxDecoration(
        color: Color(0xFF0D131F),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildOption(
                icon: Icons.photo_library,
                label: 'معرض الصور',
                color: const Color(0xFF10B981),
                onTap: () {
                  Navigator.pop(context);
                  onPickGallery();
                },
              ),
              _buildOption(
                icon: Icons.camera_alt,
                label: 'الكاميرا',
                color: const Color(0xFF06B6D4),
                onTap: () {
                  Navigator.pop(context);
                  onPickCamera();
                },
              ),
              _buildOption(
                icon: Icons.insert_drive_file,
                label: 'مستند / ملف',
                color: const Color(0xFFF59E0B),
                onTap: () {
                  Navigator.pop(context);
                  onPickDocument();
                },
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildOption(
                icon: Icons.mic,
                label: 'رسالة صوتية',
                color: const Color(0xFF3B82F6),
                onTap: () {
                  Navigator.pop(context);
                  onRecordVoice();
                },
              ),
              _buildOption(
                icon: Icons.hide_image,
                label: 'تشفير إخفائي',
                color: const Color(0xFF8B5CF6),
                onTap: () {
                  Navigator.pop(context);
                  onOpenStegano();
                },
              ),
              _buildOption(
                icon: Icons.draw,
                label: 'لوحة رسم',
                color: const Color(0xFFEC4899),
                onTap: () {
                  Navigator.pop(context);
                  onOpenWhiteboard();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withAlpha(40),
              shape: BoxShape.circle,
              border: Border.all(color: color.withAlpha(100), width: 1.5),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.white70)),
        ],
      ),
    );
  }
}
