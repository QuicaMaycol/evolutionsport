import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';

class TacticalBoardScreen extends StatefulWidget {
  const TacticalBoardScreen({super.key});

  @override
  State<TacticalBoardScreen> createState() => _TacticalBoardScreenState();
}

class _TacticalBoardScreenState extends State<TacticalBoardScreen> {
  final ScreenshotController _screenshotController = ScreenshotController();
  final List<DrawingPoint?> _points = [];
  Color _selectedColor = Colors.white;
  double _strokeWidth = 3.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        title: const Text('Pizarra Táctica'),
        actions: [
          IconButton(
            icon: const Icon(Icons.undo),
            onPressed: () {
              setState(() {
                if (_points.isNotEmpty) {
                  // Remover el último trazo (hasta el null)
                  int lastNull = _points.lastIndexOf(null);
                  if (lastNull == _points.length - 1) {
                     _points.removeLast();
                     lastNull = _points.lastIndexOf(null);
                  }
                  _points.removeRange(lastNull + 1, _points.length);
                }
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: () => setState(() => _points.clear()),
          ),
          TextButton(
            onPressed: _saveAndExit,
            child: const Text('GUARDAR', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: Column(
        children: [
          // Área de la pizarra
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 2/3, // Proporción campo de futbol
                child: Screenshot(
                  controller: _screenshotController,
                  child: Container(
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.shade800,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white, width: 4),
                    ),
                    child: Stack(
                      children: [
                        // Dibujo del campo (Líneas)
                        const FootballFieldLines(),
                        // Capa de dibujo
                        GestureDetector(
                          onPanStart: (details) {
                            setState(() {
                              _points.add(DrawingPoint(
                                offset: details.localPosition,
                                paint: Paint()
                                  ..color = _selectedColor
                                  ..strokeCap = StrokeCap.round
                                  ..strokeWidth = _strokeWidth,
                              ));
                            });
                          },
                          onPanUpdate: (details) {
                            setState(() {
                              _points.add(DrawingPoint(
                                offset: details.localPosition,
                                paint: Paint()
                                  ..color = _selectedColor
                                  ..strokeCap = StrokeCap.round
                                  ..strokeWidth = _strokeWidth,
                              ));
                            });
                          },
                          onPanEnd: (details) {
                            setState(() {
                              _points.add(null);
                            });
                          },
                          child: CustomPaint(
                            painter: DrawingPainter(points: _points),
                            size: Size.infinite,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Barra de herramientas
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.black26,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _colorPicker(Colors.white),
                _colorPicker(Colors.yellow),
                _colorPicker(Colors.red),
                _colorPicker(Colors.blue),
                const VerticalDivider(color: Colors.white24),
                IconButton(
                  icon: Icon(Icons.circle, color: _selectedColor, size: 12),
                  onPressed: () => setState(() => _strokeWidth = 3.0),
                ),
                IconButton(
                  icon: Icon(Icons.circle, color: _selectedColor, size: 24),
                  onPressed: () => setState(() => _strokeWidth = 8.0),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _colorPicker(Color color) {
    bool isSelected = _selectedColor == color;
    return GestureDetector(
      onTap: () => setState(() => _selectedColor = color),
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: isSelected ? Border.all(color: Colors.white, width: 2) : null,
        ),
        child: CircleAvatar(backgroundColor: color, radius: 14),
      ),
    );
  }

  Future<void> _saveAndExit() async {
    final imageBytes = await _screenshotController.capture();
    if (imageBytes != null) {
      final tempDir = await getTemporaryDirectory();
      final file = await File('${tempDir.path}/tactical_board_${DateTime.now().millisecondsSinceEpoch}.png').create();
      await file.writeAsBytes(imageBytes);
      if (mounted) Navigator.pop(context, file);
    }
  }
}

class DrawingPoint {
  Offset offset;
  Paint paint;
  DrawingPoint({required this.offset, required this.paint});
}

class DrawingPainter extends CustomPainter {
  final List<DrawingPoint?> points;
  DrawingPainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) {
        canvas.drawLine(points[i]!.offset, points[i + 1]!.offset, points[i]!.paint);
      } else if (points[i] != null && points[i + 1] == null) {
        canvas.drawPoints(ui.PointMode.points, [points[i]!.offset], points[i]!.paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class FootballFieldLines extends StatelessWidget {
  const FootballFieldLines({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: FieldPainter(),
    );
  }
}

class FieldPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    // Línea de medio campo
    canvas.drawLine(Offset(0, size.height / 2), Offset(size.width, size.height / 2), paint);
    
    // Círculo central
    canvas.drawCircle(Offset(size.width / 2, size.height / 2), 40, paint);
    canvas.drawCircle(Offset(size.width / 2, size.height / 2), 2, paint..style = PaintingStyle.fill);

    // Área Grande superior
    canvas.drawRect(Rect.fromLTWH(size.width * 0.15, 0, size.width * 0.7, size.height * 0.15), paint..style = PaintingStyle.stroke);
    // Área Chica superior
    canvas.drawRect(Rect.fromLTWH(size.width * 0.35, 0, size.width * 0.3, size.height * 0.05), paint);

    // Área Grande inferior
    canvas.drawRect(Rect.fromLTWH(size.width * 0.15, size.height * 0.85, size.width * 0.7, size.height * 0.15), paint);
    // Área Chica inferior
    canvas.drawRect(Rect.fromLTWH(size.width * 0.35, size.height * 0.95, size.width * 0.3, size.height * 0.05), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
