import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Drag handle for column resize. Tracks the pointer globally while dragging so
/// resize continues after the cursor leaves the narrow handle hit area.
class ColumnResizeHandle extends StatefulWidget {
  const ColumnResizeHandle({
    super.key,
    required this.onResize,
    this.onResizeStart,
    this.onResizeEnd,
    this.width = 14,
  });

  final ValueChanged<double> onResize;
  final VoidCallback? onResizeStart;
  final VoidCallback? onResizeEnd;
  final double width;

  @override
  State<ColumnResizeHandle> createState() => _ColumnResizeHandleState();
}

class _ColumnResizeHandleState extends State<ColumnResizeHandle> {
  bool _dragging = false;
  bool _hovering = false;
  int? _activePointer;

  @override
  void dispose() {
    _stopGlobalTracking();
    super.dispose();
  }

  void _globalPointerHandler(PointerEvent event) {
    if (_activePointer == null || event.pointer != _activePointer) return;
    if (event is PointerMoveEvent) {
      widget.onResize(event.delta.dx);
    } else if (event is PointerUpEvent || event is PointerCancelEvent) {
      _stopGlobalTracking();
      _endDrag();
    }
  }

  void _startGlobalTracking(int pointer) {
    _activePointer = pointer;
    GestureBinding.instance.pointerRouter.addGlobalRoute(_globalPointerHandler);
  }

  void _stopGlobalTracking() {
    if (_activePointer == null) return;
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_globalPointerHandler);
    _activePointer = null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lineColor = _dragging || _hovering
        ? theme.colorScheme.primary
        : theme.dividerColor;

    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (event) {
          if (_dragging) return;
          setState(() => _dragging = true);
          _startGlobalTracking(event.pointer);
          widget.onResizeStart?.call();
        },
        child: SizedBox(
          width: widget.width,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: _dragging || _hovering ? 3 : 1,
              height: double.infinity,
              constraints: const BoxConstraints(minHeight: 24),
              color: lineColor,
            ),
          ),
        ),
      ),
    );
  }

  void _endDrag() {
    if (!_dragging) return;
    setState(() => _dragging = false);
    widget.onResizeEnd?.call();
  }
}
