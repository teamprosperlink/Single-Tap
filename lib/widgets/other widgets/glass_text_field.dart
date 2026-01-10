import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../res/config/app_colors.dart';
import '../../res/config/app_text_styles.dart';

/// A reusable glassmorphic text field widget with consistent styling across the app.
///
/// Features:
/// - Glassmorphic background with blur effect
/// - Customizable prefix/suffix icons
/// - Support for multiline input
/// - Consistent dark theme styling
/// - Optional search field variant
class GlassTextField extends StatelessWidget {
  /// Text editing controller
  final TextEditingController? controller;

  /// Hint text displayed when field is empty
  final String? hintText;

  /// Prefix icon widget
  final Widget? prefixIcon;

  /// Suffix icon widget
  final Widget? suffixIcon;

  /// Maximum number of lines (default: 1)
  final int maxLines;

  /// Minimum number of lines
  final int? minLines;

  /// Whether the field is enabled
  final bool enabled;

  /// Whether the field is read-only
  final bool readOnly;

  /// Whether to obscure text (for passwords)
  final bool obscureText;

  /// Keyboard type
  final TextInputType? keyboardType;

  /// Text input action
  final TextInputAction? textInputAction;

  /// Text capitalization
  final TextCapitalization textCapitalization;

  /// Input formatters
  final List<TextInputFormatter>? inputFormatters;

  /// Callback when text changes
  final ValueChanged<String>? onChanged;

  /// Callback when editing is complete
  final VoidCallback? onEditingComplete;

  /// Callback when field is submitted
  final ValueChanged<String>? onSubmitted;

  /// Callback when field is tapped
  final VoidCallback? onTap;

  /// Focus node
  final FocusNode? focusNode;

  /// Whether to autofocus
  final bool autofocus;

  /// Maximum length of input
  final int? maxLength;

  /// Border radius (default: 20)
  final double borderRadius;

  /// Content padding
  final EdgeInsetsGeometry? contentPadding;

  /// Text style (default: AppTextStyles.bodyLarge)
  final TextStyle? style;

  /// Hint style (default: AppTextStyles.bodyMedium with secondary color)
  final TextStyle? hintStyle;

  /// Background alpha (default: 0.15 for default, higher for more visibility)
  final double backgroundAlpha;

  /// Whether to show blur effect (default: true)
  final bool showBlur;

  /// Custom decoration for the container
  final BoxDecoration? decoration;

  const GlassTextField({
    super.key,
    this.controller,
    this.hintText,
    this.prefixIcon,
    this.suffixIcon,
    this.maxLines = 1,
    this.minLines,
    this.enabled = true,
    this.readOnly = false,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
    this.onChanged,
    this.onEditingComplete,
    this.onSubmitted,
    this.onTap,
    this.focusNode,
    this.autofocus = false,
    this.maxLength,
    this.borderRadius = 20,
    this.contentPadding,
    this.style,
    this.hintStyle,
    this.backgroundAlpha = 0.15,
    this.showBlur = true,
    this.decoration,
  });

  /// Factory constructor for search field variant
  factory GlassTextField.search({
    Key? key,
    TextEditingController? controller,
    String? hintText,
    ValueChanged<String>? onChanged,
    VoidCallback? onClear,
    FocusNode? focusNode,
    bool autofocus = false,
  }) {
    return GlassTextField(
      key: key,
      controller: controller,
      hintText: hintText ?? 'Search...',
      prefixIcon: const Icon(
        Icons.search_rounded,
        color: AppColors.textSecondaryDark,
        size: 22,
      ),
      suffixIcon: controller != null && controller.text.isNotEmpty
          ? GestureDetector(
              onTap: () {
                controller.clear();
                onClear?.call();
              },
              child: const Icon(
                Icons.close_rounded,
                color: AppColors.textSecondaryDark,
                size: 20,
              ),
            )
          : null,
      onChanged: onChanged,
      focusNode: focusNode,
      autofocus: autofocus,
      textInputAction: TextInputAction.search,
    );
  }

  /// Factory constructor for multiline text area
  factory GlassTextField.multiline({
    Key? key,
    TextEditingController? controller,
    String? hintText,
    int maxLines = 5,
    int? minLines,
    ValueChanged<String>? onChanged,
    FocusNode? focusNode,
    int? maxLength,
  }) {
    return GlassTextField(
      key: key,
      controller: controller,
      hintText: hintText,
      maxLines: maxLines,
      minLines: minLines,
      onChanged: onChanged,
      focusNode: focusNode,
      maxLength: maxLength,
      keyboardType: TextInputType.multiline,
      textInputAction: TextInputAction.newline,
    );
  }

  @override
  Widget build(BuildContext context) {
    final defaultDecoration = BoxDecoration(
      borderRadius: BorderRadius.circular(borderRadius),
      color: AppColors.glassBackgroundDark(alpha: backgroundAlpha),
      border: Border.all(
        color: AppColors.glassBorder(alpha: 0.3),
        width: 1.5,
      ),
      boxShadow: [
        BoxShadow(
          color: AppColors.darkShadow(),
          blurRadius: 8,
          spreadRadius: 1,
        ),
      ],
    );

    final textField = TextField(
      controller: controller,
      style: style ?? AppTextStyles.bodyLarge,
      cursorColor: Colors.white,
      cursorHeight: 18,
      maxLines: maxLines,
      minLines: minLines,
      enabled: enabled,
      readOnly: readOnly,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      textCapitalization: textCapitalization,
      inputFormatters: inputFormatters,
      onChanged: onChanged,
      onEditingComplete: onEditingComplete,
      onSubmitted: onSubmitted,
      onTap: onTap,
      focusNode: focusNode,
      autofocus: autofocus,
      maxLength: maxLength,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: hintStyle ??
            AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondaryDark,
            ),
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        disabledBorder: InputBorder.none,
        filled: true,
        fillColor: Colors.transparent,
        contentPadding: contentPadding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        counterText: '',
      ),
    );

    final container = Container(
      decoration: decoration ?? defaultDecoration,
      child: textField,
    );

    if (!showBlur) {
      return container;
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: container,
      ),
    );
  }
}

/// A search-specific glass text field with built-in clear functionality
class GlassSearchField extends StatefulWidget {
  final TextEditingController? controller;
  final String? hintText;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;
  final VoidCallback? onMicTap;
  final FocusNode? focusNode;
  final bool autofocus;
  final double borderRadius;
  final bool showMic;
  final bool isListening;
  final VoidCallback? onStopListening;

  const GlassSearchField({
    super.key,
    this.controller,
    this.hintText,
    this.onChanged,
    this.onClear,
    this.onMicTap,
    this.focusNode,
    this.autofocus = false,
    this.borderRadius = 20,
    this.showMic = false,
    this.isListening = false,
    this.onStopListening,
  });

  @override
  State<GlassSearchField> createState() => _GlassSearchFieldState();
}

class _GlassSearchFieldState extends State<GlassSearchField> {
  late TextEditingController _controller;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    _hasText = _controller.text.isNotEmpty;
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _controller.dispose();
    } else {
      _controller.removeListener(_onTextChanged);
    }
    super.dispose();
  }

  void _onTextChanged() {
    final hasText = _controller.text.isNotEmpty;
    if (hasText != _hasText) {
      setState(() {
        _hasText = hasText;
      });
    }
  }

  void _onClear() {
    _controller.clear();
    widget.onClear?.call();
    widget.onChanged?.call('');
  }

  Widget? _buildSuffixIcon() {
    if (_hasText) {
      return GestureDetector(
        onTap: _onClear,
        child: const Icon(
          Icons.close_rounded,
          color: AppColors.textSecondaryDark,
          size: 20,
        ),
      );
    } else if (widget.showMic && widget.onMicTap != null) {
      // Show recording indicator when listening, otherwise show mic button
      if (widget.isListening) {
        return _RecordingIndicator(onStop: widget.onStopListening);
      }
      return GestureDetector(
        onTap: widget.onMicTap,
        child: Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Icon(
            Icons.mic,
            color: Colors.white.withValues(alpha: 0.9),
            size: 22,
          ),
        ),
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    // Show wave bars when listening
    if (widget.isListening) {
      return _AudioWaveSearchField(
        borderRadius: widget.borderRadius,
        onStop: widget.onStopListening,
      );
    }

    return SizedBox(
      height: 48,
      child: GlassTextField(
        controller: _controller,
        hintText: widget.hintText ?? 'Search...',
        prefixIcon: const Icon(
          Icons.search_rounded,
          color: AppColors.textSecondaryDark,
          size: 22,
        ),
        suffixIcon: _buildSuffixIcon(),
        onChanged: widget.onChanged,
        focusNode: widget.focusNode,
        autofocus: widget.autofocus,
        textInputAction: TextInputAction.search,
        borderRadius: widget.borderRadius,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      ),
    );
  }
}

/// Audio wave search field widget for listening mode (like home screen)
class _AudioWaveSearchField extends StatefulWidget {
  final double borderRadius;
  final VoidCallback? onStop;

  const _AudioWaveSearchField({
    required this.borderRadius,
    this.onStop,
  });

  @override
  State<_AudioWaveSearchField> createState() => _AudioWaveSearchFieldState();
}

class _AudioWaveSearchFieldState extends State<_AudioWaveSearchField>
    with SingleTickerProviderStateMixin {
  late AnimationController _waveController;
  bool _visible = true;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed ||
            status == AnimationStatus.dismissed) {
          setState(() {
            _visible = !_visible;
          });
          if (_visible) {
            _waveController.forward();
          } else {
            _waveController.reverse();
          }
        }
      });
    _waveController.forward();
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            color: AppColors.glassBackgroundDark(alpha: 0.15),
            border: Border.all(
              color: AppColors.glassBorder(alpha: 0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.darkShadow(),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                // Recording indicator dot
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _visible
                        ? AppColors.error
                        : AppColors.error.withValues(alpha: 0.3),
                  ),
                ),
                const SizedBox(width: 12),
                // Audio wave bars
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      const barWidth = 3.0;
                      const barMargin = 2.0;
                      const totalBarWidth = barWidth + (barMargin * 2);
                      final barCount =
                          (constraints.maxWidth / totalBarWidth)
                              .floor()
                              .clamp(1, 20);

                      return Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: List.generate(barCount, (index) {
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: barWidth,
                            height: _visible
                                ? (6.0 +
                                    ((index % 3 == 0
                                        ? 18.0
                                        : (index % 2 == 0 ? 12.0 : 8.0))))
                                : (6.0 +
                                    ((index % 3 == 0
                                        ? 8.0
                                        : (index % 2 == 0 ? 16.0 : 10.0)))),
                            margin: const EdgeInsets.symmetric(
                              horizontal: barMargin,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.error.withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          );
                        }),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                // Recording text
                Text(
                  'Recording...',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.iosGray,
                  ),
                ),
                const SizedBox(width: 8),
                // Stop button (mic with blink)
                _RecordingIndicator(onStop: widget.onStop),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Recording indicator widget with pulsing mic and wave bars
class _RecordingIndicator extends StatefulWidget {
  final VoidCallback? onStop;

  const _RecordingIndicator({this.onStop});

  @override
  State<_RecordingIndicator> createState() => _RecordingIndicatorState();
}

class _RecordingIndicatorState extends State<_RecordingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _blinkController;
  late Animation<double> _blinkAnimation;

  @override
  void initState() {
    super.initState();
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);

    _blinkAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _blinkController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _blinkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onStop,
      child: AnimatedBuilder(
        animation: _blinkAnimation,
        builder: (context, child) {
          return Container(
            width: 32,
            height: 32,
            margin: const EdgeInsets.only(right: 6),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.error,
            ),
            child: Icon(
              Icons.stop,
              color: Colors.white.withValues(alpha: _blinkAnimation.value),
              size: 18,
            ),
          );
        },
      ),
    );
  }
}

/// Voice wave animation widget for listening mode
// ignore: unused_element
class _VoiceWaveSearchField extends StatefulWidget {
  final double borderRadius;
  final VoidCallback? onStop;

  const _VoiceWaveSearchField({
    required this.borderRadius,
    this.onStop, // ignore: unused_element_parameter
  });

  @override
  State<_VoiceWaveSearchField> createState() => _VoiceWaveSearchFieldState();
}

class _VoiceWaveSearchFieldState extends State<_VoiceWaveSearchField>
    with TickerProviderStateMixin {
  late AnimationController _waveController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _waveController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              colors: [
                AppColors.iosBlue.withValues(alpha: 0.3),
                AppColors.vibrantGreen.withValues(alpha: 0.3),
              ],
            ),
            border: Border.all(
              color: AppColors.iosBlue.withValues(alpha: 0.5),
              width: 1.5,
            ),
          ),
          child: Stack(
            children: [
              // Wave animation
              AnimatedBuilder(
                animation: _waveController,
                builder: (context, child) {
                  return CustomPaint(
                    size: Size.infinite,
                    painter: _WavePainter(
                      animationValue: _waveController.value,
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                  );
                },
              ),
              // Content row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    // Animated mic icon
                    AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _pulseAnimation.value,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  AppColors.iosBlue,
                                  AppColors.vibrantGreen,
                                ],
                              ),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.3),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.iosBlue.withValues(alpha: 0.4),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.mic,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 12),
                    // Listening text with animated dots
                    Expanded(
                      child: _ListeningText(),
                    ),
                    // Close button
                    GestureDetector(
                      onTap: widget.onStop,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              AppColors.iosBlue,
                              AppColors.vibrantGreen,
                            ],
                          ),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.iosBlue.withValues(alpha: 0.4),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Animated "Listening..." text
class _ListeningText extends StatefulWidget {
  @override
  State<_ListeningText> createState() => _ListeningTextState();
}

class _ListeningTextState extends State<_ListeningText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  int _dotCount = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          setState(() {
            _dotCount = (_dotCount + 1) % 4;
          });
          _controller.reset();
          _controller.forward();
        }
      });
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      'Listening${'.' * _dotCount}',
      style: const TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

/// Custom painter for wave effect
class _WavePainter extends CustomPainter {
  final double animationValue;
  final Color color;

  _WavePainter({
    required this.animationValue,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    const waveHeight = 8.0;
    const waveCount = 3;

    path.moveTo(0, size.height);

    for (double x = 0; x <= size.width; x++) {
      final y = size.height / 2 +
          waveHeight *
              math.sin((x / size.width * waveCount * 2 * math.pi) +
                  (animationValue * 2 * math.pi));
      path.lineTo(x, y);
    }

    path.lineTo(size.width, size.height);
    path.close();

    canvas.drawPath(path, paint);

    // Draw second wave with offset
    final paint2 = Paint()
      ..color = color.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;

    final path2 = Path();
    path2.moveTo(0, size.height);

    for (double x = 0; x <= size.width; x++) {
      final y = size.height / 2 +
          waveHeight *
              0.7 *
              math.sin((x / size.width * waveCount * 2 * math.pi) +
                  (animationValue * 2 * math.pi) +
                  math.pi / 2);
      path2.lineTo(x, y);
    }

    path2.lineTo(size.width, size.height);
    path2.close();

    canvas.drawPath(path2, paint2);
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}
