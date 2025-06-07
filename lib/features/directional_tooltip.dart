import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter/material.dart';

class DirectionalTooltip extends material.StatefulWidget {
  final String? message;
  final material.InlineSpan? richMessage;
  final material.Widget child;
  final double? height;
  final material.EdgeInsetsGeometry? padding;
  final material.EdgeInsetsGeometry? margin;
  final double verticalOffset;
  final bool preferBelow; // accepted for compatibility; dynamic behavior overrides this
  final bool excludeFromSemantics;
  final material.Decoration? decoration;
  final material.TextStyle? textStyle;
  final Duration? waitDuration;
  final Duration? showDuration;
  final material.TooltipTriggerMode triggerMode;
  final bool? enableFeedback;

  const DirectionalTooltip({
    material.Key? key,
    this.message,
    this.richMessage,
    required this.child,
    this.height,
    this.padding,
    this.margin,
    this.verticalOffset = 24.0,
    this.preferBelow = true,
    this.excludeFromSemantics = false,
    this.decoration,
    this.textStyle,
    this.waitDuration,
    this.showDuration,
    this.triggerMode = material.TooltipTriggerMode.longPress,
    this.enableFeedback,
  })  : assert(message != null || richMessage != null),
        super(key: key);

  @override
  _TooltipState createState() => _TooltipState();
}

class _TooltipState extends material.State<DirectionalTooltip> {
  material.Offset? _lastHoverPosition;
  bool _movingDown = false;

  @override
  material.Widget build(material.BuildContext context) {
    return material.MouseRegion(
      onHover: (PointerHoverEvent event) {
        final currentPos = event.position;
        if (_lastHoverPosition != null) {
          final dy = currentPos.dy - _lastHoverPosition!.dy;
          if (dy != 0) {
            setState(() {
              _movingDown = dy > 0;
            });
          }
        }
        _lastHoverPosition = currentPos;
      },
      child: Tooltip(
        message: widget.message,
        richMessage: widget.richMessage,
        height: widget.height,
        padding: widget.padding,
        margin: widget.margin,
        verticalOffset: widget.verticalOffset,
        // !_movingDown ? widget.verticalOffset + 20 : null,
        // Dynamic behavior: if the mouse is moving down, show the tooltip above.
        preferBelow: !_movingDown,
        excludeFromSemantics: widget.excludeFromSemantics,
        decoration: widget.decoration,
        textStyle: widget.textStyle,
        waitDuration: widget.waitDuration,
        showDuration: widget.showDuration,
        triggerMode: widget.triggerMode,
        enableFeedback: widget.enableFeedback,
        child: widget.child,
      ),
    );
  }
}
