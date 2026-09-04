import 'package:flutter/material.dart';

class MobileWhiteboard extends StatefulWidget {
  final Function(Map<String, dynamic>) onSendDrawEvent;
  final Stream<Map<String, dynamic>> drawEventStream;

  const MobileWhiteboard({
    super.key,
    required this.onSendDrawEvent,
    required this.drawEventStream,
  });

  @override
  State<MobileWhiteboard> createState() => _MobileWhiteboardState();
}

class _MobileWhiteboardState extends State<MobileWhiteboard> {
  final List<List<Offset>> _lines = [];
  final List<Color> _lineColors = [];
  final List<double> _lineWidths = [];
  Color _selectedColor = const Color(0xFF10B981); // Emerald
  double _strokeWidth = 3.0;
  bool _isEraser = false;

  @override
  void initState() {
    super.initState();
    widget.drawEventStream.listen((event) {
      final type = event['type'];
      if (type == 'clear') {
        setState(() {
          _lines.clear();
          _lineColors.clear();
          _lineWidths.clear();
        });
      } else if (type == 'undo') {
        setState(() {
          if (_lines.isNotEmpty) {
            _lines.removeLast();
            _lineColors.removeLast();
            _lineWidths.removeLast();
          }
        });
      } else if (type == 'line') {
        final x0 = (event['x0'] as num).toDouble();
        final y0 = (event['y0'] as num).toDouble();
        final x1 = (event['x1'] as num).toDouble();
        final y1 = (event['y1'] as num).toDouble();
        final colorVal = int.tryParse(event['color']?.toString() ?? '') ?? 0xFF10B981;
        final widthVal = (event['width'] as num?)?.toDouble() ?? 3.0;

        setState(() {
          _lines.add([Offset(x0, y0), Offset(x1, y1)]);
          _lineColors.add(Color(colorVal));
          _lineWidths.add(widthVal);
        });
      }
    });
  }

  void _clearCanvas() {
    setState(() {
      _lines.clear();
      _lineColors.clear();
      _lineWidths.clear();
    });
    widget.onSendDrawEvent({'type': 'clear'});
  }

  void _undo() {
    if (_lines.isNotEmpty) {
      setState(() {
        _lines.removeLast();
        _lineColors.removeLast();
        _lineWidths.removeLast();
      });
      widget.onSendDrawEvent({'type': 'undo'});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Top Toolbar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          color: const Color(0xFF0D131F),
          child: Row(
            children: [
              // Undo
              IconButton(
                icon: const Icon(Icons.undo, color: Colors.white70, size: 20),
                tooltip: 'تراجع',
                onPressed: _undo,
              ),
              // Eraser
              IconButton(
                icon: Icon(Icons.cleaning_services, color: _isEraser ? const Color(0xFF10B981) : Colors.white54, size: 20),
                tooltip: 'الممحاة',
                onPressed: () => setState(() => _isEraser = !_isEraser),
              ),
              // Stroke Width
              PopupMenuButton<double>(
                icon: const Icon(Icons.line_weight, color: Colors.white70, size: 20),
                tooltip: 'سُمك الخط',
                onSelected: (w) => setState(() => _strokeWidth = w),
                itemBuilder: (ctx) => [
                  const PopupMenuItem(value: 2.0, child: Text('رفيع (Thin)')),
                  const PopupMenuItem(value: 4.0, child: Text('متوسط (Medium)')),
                  const PopupMenuItem(value: 8.0, child: Text('عريض (Thick)')),
                ],
              ),
              const Spacer(),
              // Color Palette
              for (final color in [
                const Color(0xFF10B981),
                const Color(0xFF06B6D4),
                const Color(0xFFA855F7),
                const Color(0xFFF59E0B),
                const Color(0xFFEF4444),
                Colors.white,
              ])
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedColor = color;
                      _isEraser = false;
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: (!_isEraser && _selectedColor == color) ? Colors.white : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              const SizedBox(width: 6),
              // Clear All
              IconButton(
                icon: const Icon(Icons.delete_sweep, color: Colors.redAccent, size: 20),
                tooltip: 'مسح اللوحة',
                onPressed: _clearCanvas,
              ),
            ],
          ),
        ),
        // Drawing Canvas
        Expanded(
          child: Container(
            color: const Color(0xFF07090E),
            child: GestureDetector(
              onPanStart: (details) {
                final drawColor = _isEraser ? const Color(0xFF07090E) : _selectedColor;
                final drawWidth = _isEraser ? 20.0 : _strokeWidth;
                setState(() {
                  _lines.add([details.localPosition]);
                  _lineColors.add(drawColor);
                  _lineWidths.add(drawWidth);
                });
              },
              onPanUpdate: (details) {
                final drawColor = _isEraser ? const Color(0xFF07090E) : _selectedColor;
                final drawWidth = _isEraser ? 20.0 : _strokeWidth;
                setState(() {
                  if (_lines.isNotEmpty) {
                    final currentLine = _lines.last;
                    final prevPoint = currentLine.last;
                    currentLine.add(details.localPosition);

                    widget.onSendDrawEvent({
                      'type': 'line',
                      'x0': prevPoint.dx,
                      'y0': prevPoint.dy,
                      'x1': details.localPosition.dx,
                      'y1': details.localPosition.dy,
                      'color': drawColor.toARGB32(),
                      'width': drawWidth,
                    });
                  }
                });
              },
              child: CustomPaint(
                painter: WhiteboardPainter(lines: _lines, colors: _lineColors, widths: _lineWidths),
                size: Size.infinite,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class WhiteboardPainter extends CustomPainter {
  final List<List<Offset>> lines;
  final List<Color> colors;
  final List<double> widths;

  WhiteboardPainter({
    required this.lines,
    required this.colors,
    required this.widths,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final color = i < colors.length ? colors[i] : const Color(0xFF10B981);
      final width = i < widths.length ? widths[i] : 3.0;
      final paint = Paint()
        ..color = color
        ..strokeCap = StrokeCap.round
        ..strokeWidth = width;

      for (int j = 0; j < line.length - 1; j++) {
        canvas.drawLine(line[j], line[j + 1], paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
