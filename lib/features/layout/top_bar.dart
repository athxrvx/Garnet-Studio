import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import '../../core/constants/app_constants.dart';

enum _WindowIconType { minimize, maximize, restore, close }

class TopBar extends StatefulWidget {
  const TopBar({super.key});

  @override
  State<TopBar> createState() => _TopBarState();
}

class _TopBarState extends State<TopBar> with WindowListener {
  @override
  void initState() {
    windowManager.addListener(this);
    super.initState();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      color: Colors.transparent, 
      child: Row(
        children: [
          // Draggable Title Area - Covers almost everything except buttons
          Expanded(
            child: DragToMoveArea(
              child: Container(
                color: Colors.transparent,
              ),
            ),
          ),

          // Window Controls - Buttons act as "negative space" in drag area
          const _WindowButton(
            type: _WindowIconType.minimize,
            onPressed: _minimize,
          ),
          FutureBuilder<bool>(
            future: windowManager.isMaximized(),
            builder: (context, snapshot) {
              final isMaximized = snapshot.data ?? false;
              return _WindowButton(
                type: isMaximized ? _WindowIconType.restore : _WindowIconType.maximize,
                onPressed: _maximizeOrRestore,
              );
            },
          ),
          const _WindowButton(
            type: _WindowIconType.close,
            onPressed: _close,
            isCloseButton: true,
          ),
        ],
      ),
    );
  }

  static void _minimize() => windowManager.minimize();

  static void _maximizeOrRestore() async {
    final isMaximized = await windowManager.isMaximized();
    if (isMaximized) {
      windowManager.unmaximize();
    } else {
      windowManager.maximize();
    }
  }

  static void _close() => windowManager.close();
  
  // Update state when window maximizes/unmaximizes to change icon
  @override
  void onWindowMaximize() => setState(() {});
  @override
  void onWindowUnmaximize() => setState(() {});
}

class _WindowButton extends StatelessWidget {
  final _WindowIconType type;
  final VoidCallback onPressed;
  final bool isCloseButton;

  const _WindowButton({
    required this.type,
    required this.onPressed,
    this.isCloseButton = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        hoverColor: isCloseButton ? Colors.red : Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.zero,
        child: Container(
          width: 46,
          height: 32,
          alignment: Alignment.center,
          child: CustomPaint(
            size: const Size(10, 10),
            painter: _WindowIconPainter(
              type: type, 
              color: Colors.white.withOpacity(0.8)
            ),
          ),
        ),
      ),
    );
  }
}

class _WindowIconPainter extends CustomPainter {
  final _WindowIconType type;
  final Color color;

  _WindowIconPainter({required this.type, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square; // Crisp edges

    switch (type) {
      case _WindowIconType.minimize:
        // Simple horizontal line
        canvas.drawLine(
          Offset(0, size.height / 2), 
          Offset(size.width, size.height / 2), 
          paint,
        );
        break;
      
      case _WindowIconType.maximize:
        // Square
        canvas.drawRect(
          Rect.fromLTWH(0, 0, size.width, size.height), 
          paint
        );
        break;
        
      case _WindowIconType.restore:
        // Two overlapping squares
        // Background square
        canvas.drawRect(
          Rect.fromLTWH(2, 0, size.width - 2, size.height - 2), 
          paint
        );
         // Foreground square (filled with background color to occlude)
        final bgPaint = Paint()..color = Colors.transparent..style = PaintingStyle.fill;
        // Actually we just draw another rect shifted, 
        // to look correct without complex clipping, we draw front rect
        // and mask the parts of back rect or just draw partial lines
        
        // Easier: Back rect top-right part
        canvas.drawPath(
          Path()
            ..moveTo(2, 2) // Intersection start
            ..lineTo(2, 0)
            ..lineTo(size.width, 0)
            ..lineTo(size.width, size.height - 2)
            ..lineTo(size.width - 2, size.height - 2),
            paint
        );
        
        // Front rect
        canvas.drawRect(
          Rect.fromLTWH(0, 2, size.width - 2, size.height - 2), 
          paint
        );
        break;
        
      case _WindowIconType.close:
        // X shape
        canvas.drawLine(Offset(0, 0), Offset(size.width, size.height), paint);
        canvas.drawLine(Offset(size.width, 0), Offset(0, size.height), paint);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _WindowIconPainter oldDelegate) {
    return oldDelegate.type != type || oldDelegate.color != color;
  }
}
