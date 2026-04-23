import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:chataway_plus/core/themes/colors/app_colors.dart';
import 'package:chataway_plus/core/responsive_layout/responsive_layout_builder.dart';

/// A draggable floating ball that can be moved freely across the screen
/// Double-tap to select emoji
class DraggableFloatingBall extends StatefulWidget {
  final double size;
  final Color color;
  final String? initialEmoji;
  final ValueChanged<String>? onEmojiChanged;
  final Offset? initialPosition;

  const DraggableFloatingBall({
    super.key,
    this.size = 60,
    this.color = Colors.blue,
    this.initialEmoji,
    this.onEmojiChanged,
    this.initialPosition,
  });

  @override
  State<DraggableFloatingBall> createState() => _DraggableFloatingBallState();
}

class _DraggableFloatingBallState extends State<DraggableFloatingBall>
    with SingleTickerProviderStateMixin {
  late Offset _position;
  String? _emoji;

  late final AnimationController _blinkController;
  late final Animation<double> _blinkAnimation;

  @override
  void initState() {
    super.initState();
    _position = widget.initialPosition ?? const Offset(50, 100);
    _emoji = widget.initialEmoji;

    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _blinkAnimation = Tween<double>(begin: 1.0, end: 0.3).animate(
      CurvedAnimation(parent: _blinkController, curve: Curves.easeInOut),
    );

    _updateBlinkState();
  }

  @override
  void didUpdateWidget(covariant DraggableFloatingBall oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If parent provides a different initialEmoji, reflect it here
    if (widget.initialEmoji != oldWidget.initialEmoji &&
        widget.initialEmoji != _emoji) {
      setState(() {
        _emoji = widget.initialEmoji;
      });
      _updateBlinkState();
    }
  }

  void _updateBlinkState() {
    if (!_blinkController.isAnimating) {
      _blinkController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _blinkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final safeArea = MediaQuery.of(context).padding;

    return Positioned(
      left: _position.dx,
      top: _position.dy,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            double newX = _position.dx + details.delta.dx;
            double newY = _position.dy + details.delta.dy;

            // Clamp within screen bounds
            newX = newX.clamp(0.0, screenSize.width - widget.size);
            newY = newY.clamp(
              safeArea.top,
              screenSize.height - widget.size - safeArea.bottom - 40,
            );

            _position = Offset(newX, newY);
          });
        },
        onTap: () => _openEmojiPicker(context),
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey.shade300, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha((0.2 * 255).round()),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    _emoji ?? '😊',
                    style: TextStyle(fontSize: widget.size * 0.70),
                  ),
                ),
              ),
              // Blinking hint dot — top-left, 4px away from circle
              Positioned(
                top: widget.size * 0.09,
                left: -4 - (widget.size * 0.26),
                child: AnimatedBuilder(
                  animation: _blinkAnimation,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _blinkAnimation.value,
                      child: child,
                    );
                  },
                  child: Container(
                    width: widget.size * 0.24,
                    height: widget.size * 0.24,
                    decoration: const BoxDecoration(
                      color: Color(0xFF00E676),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openEmojiPicker(BuildContext context) async {
    final sheetTheme = Theme.of(context);

    final newEmoji = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: sheetTheme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return _EmojiPickerSheet(initialEmoji: _emoji ?? '😊');
      },
    );

    final trimmed = newEmoji?.trim();
    if (!mounted || trimmed == null || trimmed.isEmpty) return;
    setState(() => _emoji = trimmed);
    _updateBlinkState();
    widget.onEmojiChanged?.call(trimmed);
  }
}

class _EmojiPickerSheet extends StatefulWidget {
  const _EmojiPickerSheet({required this.initialEmoji});

  final String initialEmoji;

  @override
  State<_EmojiPickerSheet> createState() => _EmojiPickerSheetState();
}

class _EmojiPickerSheetState extends State<_EmojiPickerSheet> {
  late final TextEditingController _emojiController;

  @override
  void initState() {
    super.initState();
    _emojiController = TextEditingController(text: widget.initialEmoji);
  }

  @override
  void dispose() {
    _emojiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sheetTheme = Theme.of(context);
    final sheetIsDark = sheetTheme.brightness == Brightness.dark;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 100),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: ResponsiveLayoutBuilder(
        builder: (context, constraints, breakpoint) {
          final responsive = ResponsiveSize(
            context: context,
            constraints: constraints,
            breakpoint: breakpoint,
          );

          return SafeArea(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: responsive.spacing(16),
                      vertical: responsive.spacing(8),
                    ),
                    child: Row(
                      children: [
                        Text(
                          'Select Emoji',
                          style: TextStyle(
                            fontSize: responsive.size(18),
                            fontWeight: FontWeight.w600,
                            color: sheetTheme.colorScheme.onSurface,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '1 emoji only',
                          style: TextStyle(
                            fontSize: responsive.size(14),
                            color: sheetIsDark ? Colors.white54 : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: responsive.spacing(20),
                    ),
                    child: TextField(
                      controller: _emojiController,
                      autofocus: true,
                      style: TextStyle(
                        fontSize: responsive.size(48),
                        color: sheetTheme.colorScheme.onSurface,
                      ),
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        hintText: '😊',
                        hintStyle: TextStyle(
                          color: sheetIsDark ? Colors.white54 : Colors.grey,
                          fontSize: responsive.size(48),
                        ),
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          vertical: responsive.spacing(20),
                        ),
                      ),
                      inputFormatters: [_SingleEmojiInputFormatter()],
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(responsive.spacing(12)),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: OutlinedButton.styleFrom(
                              shape: const StadiumBorder(),
                              side: BorderSide(
                                color: sheetIsDark
                                    ? Colors.white24
                                    : Colors.grey.shade400,
                              ),
                              padding: EdgeInsets.symmetric(
                                vertical: responsive.spacing(10),
                              ),
                            ),
                            child: Text(
                              'Cancel',
                              style: TextStyle(
                                color: sheetTheme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: responsive.spacing(12)),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              final newEmoji = _emojiController.text.trim();
                              Navigator.of(context).pop(newEmoji);
                            },
                            style: OutlinedButton.styleFrom(
                              shape: const StadiumBorder(),
                              side: BorderSide(
                                color: sheetIsDark
                                    ? Colors.white24
                                    : Colors.grey.shade400,
                              ),
                              padding: EdgeInsets.symmetric(
                                vertical: responsive.spacing(10),
                              ),
                            ),
                            child: Text(
                              'Save',
                              style: TextStyle(color: AppColors.primary),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Input formatter that allows only a single emoji
class _SingleEmojiInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final emojiRegex = RegExp(
      r'(\u00a9|\u00ae|[\u2000-\u3300]|\ud83c[\ud000-\udfff]|\ud83d[\ud000-\udfff]|\ud83e[\ud000-\udfff])',
    );

    // Extract only emojis
    final emojis = newValue.text.characters
        .where((c) => emojiRegex.hasMatch(c))
        .toList();

    // Take only the first emoji
    final filtered = emojis.isEmpty ? '' : emojis.first;

    return TextEditingValue(
      text: filtered,
      selection: TextSelection.collapsed(offset: filtered.length),
    );
  }
}
