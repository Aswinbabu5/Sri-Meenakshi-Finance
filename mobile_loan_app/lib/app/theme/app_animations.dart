import 'package:flutter/material.dart';
import '../../core/utils/currency_utils.dart';

/// Central animation design tokens and reusable micro-animation components
/// for Sri Meenakshi Finance app.
class AppAnimations {
  // Duration tokens
  static const Duration fast = Duration(milliseconds: 180);
  static const Duration medium = Duration(milliseconds: 320);
  static const Duration normal = Duration(milliseconds: 450);
  static const Duration slow = Duration(milliseconds: 650);
  static const Duration staggerStep = Duration(milliseconds: 45);

  // Curve tokens
  static const Curve entrance = Curves.easeOutCubic;
  static const Curve exit = Curves.easeInCubic;
  static const Curve entranceCurve = entrance;
  static const Curve exitCurve = exit;
  static const Curve emphasized = Curves.fastOutSlowIn;
  static const Curve spring = Curves.easeOutBack;

  /// Check whether animations should be disabled or minimized for accessibility
  static bool shouldReduceMotion(BuildContext context) {
    return MediaQuery.maybeOf(context)?.disableAnimations == true;
  }
}

/// Staggered Entrance widget: smoothly slides in and fades in a widget.
/// Ideal for cards, list items, headers, and form sections.
class StaggeredEntrance extends StatelessWidget {
  final Widget child;
  final int index;
  final Duration? delay;
  final Duration duration;
  final Offset offset;
  final Curve curve;

  const StaggeredEntrance({
    super.key,
    required this.child,
    this.index = 0,
    this.delay,
    this.duration = AppAnimations.normal,
    this.offset = const Offset(0, 18),
    this.curve = AppAnimations.entrance,
  });

  @override
  Widget build(BuildContext context) {
    if (AppAnimations.shouldReduceMotion(context)) {
      return child;
    }

    final effectiveDelay = delay ?? Duration(milliseconds: (index * 45).clamp(0, 450));

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: duration + effectiveDelay,
      curve: curve,
      builder: (context, progress, widgetChild) {
        // Compute effective progress after delay
        final totalMs = (duration + effectiveDelay).inMilliseconds;
        final delayMs = effectiveDelay.inMilliseconds;
        final currentMs = progress * totalMs;

        double animValue;
        if (currentMs < delayMs) {
          animValue = 0.0;
        } else {
          animValue = ((currentMs - delayMs) / duration.inMilliseconds).clamp(0.0, 1.0);
        }

        final curvedValue = curve.transform(animValue);
        final currentOffset = Offset(
          offset.dx * (1.0 - curvedValue),
          offset.dy * (1.0 - curvedValue),
        );

        return Transform.translate(
          offset: currentOffset,
          child: Opacity(
            opacity: curvedValue,
            child: widgetChild,
          ),
        );
      },
      child: child,
    );
  }
}

/// Interactive Card with hover elevation and subtle press feedback
class HoverScaleCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color? color;
  final BorderRadius? borderRadius;
  final Border? border;
  final double elevation;
  final double hoverElevation;
  final double hoverScale;
  final double pressScale;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final List<BoxShadow>? boxShadow;

  const HoverScaleCard({
    super.key,
    required this.child,
    this.onTap,
    this.color,
    this.borderRadius,
    this.border,
    this.elevation = 1.0,
    this.hoverElevation = 4.0,
    this.hoverScale = 1.018,
    this.pressScale = 0.982,
    this.padding,
    this.margin,
    this.boxShadow,
  });

  @override
  State<HoverScaleCard> createState() => _HoverScaleCardState();
}

class _HoverScaleCardState extends State<HoverScaleCard> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = AppAnimations.shouldReduceMotion(context);

    double currentScale = 1.0;
    if (!reduceMotion) {
      if (_isPressed) {
        currentScale = widget.pressScale;
      } else if (_isHovered) {
        currentScale = widget.hoverScale;
      }
    }

    final radius = widget.borderRadius ?? BorderRadius.circular(12);

    return Container(
      margin: widget.margin,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        cursor: widget.onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: GestureDetector(
          onTapDown: (_) => setState(() => _isPressed = true),
          onTapUp: (_) => setState(() => _isPressed = false),
          onTapCancel: () => setState(() => _isPressed = false),
          onTap: widget.onTap,
          child: AnimatedScale(
            scale: currentScale,
            duration: AppAnimations.fast,
            curve: AppAnimations.entrance,
            child: AnimatedContainer(
              duration: AppAnimations.fast,
              curve: AppAnimations.entrance,
              padding: widget.padding,
              decoration: BoxDecoration(
                color: widget.color ?? Colors.white,
                borderRadius: radius,
                border: widget.border,
                boxShadow: widget.boxShadow ??
                    [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: _isHovered ? 0.12 : (_isPressed ? 0.04 : 0.06),
                        ),
                        blurRadius: _isHovered ? widget.hoverElevation * 2.5 : widget.elevation * 2,
                        offset: Offset(0, _isHovered ? 3 : 1.5),
                      ),
                    ],
              ),
              child: ClipRRect(
                borderRadius: radius,
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Interactive button wrapper providing smooth micro-press and hover feedback
class AnimatedPressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double pressScale;
  final double hoverScale;
  final Duration duration;
  final HitTestBehavior behavior;

  const AnimatedPressable({
    super.key,
    required this.child,
    this.onTap,
    this.pressScale = 0.96,
    this.hoverScale = 1.025,
    this.duration = AppAnimations.fast,
    this.behavior = HitTestBehavior.opaque,
  });

  @override
  State<AnimatedPressable> createState() => _AnimatedPressableState();
}

class _AnimatedPressableState extends State<AnimatedPressable> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    if (AppAnimations.shouldReduceMotion(context) || widget.onTap == null) {
      return GestureDetector(
        onTap: widget.onTap,
        behavior: widget.behavior,
        child: widget.child,
      );
    }

    double scale = 1.0;
    if (_isPressed) {
      scale = widget.pressScale;
    } else if (_isHovered) {
      scale = widget.hoverScale;
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: widget.behavior,
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: scale,
          duration: widget.duration,
          curve: AppAnimations.entrance,
          child: widget.child,
        ),
      ),
    );
  }
}

/// Smooth counting number animation for financial figures, totals, and stats.
/// Preserves strict financial precision and displays currency correctly.
class AnimatedCountingNumber extends StatelessWidget {
  final num value;
  final String? prefix;
  final String? suffix;
  final TextStyle? style;
  final Duration duration;
  final Curve curve;
  final bool isCurrency;
  final int decimalDigits;

  const AnimatedCountingNumber({
    super.key,
    required this.value,
    this.prefix,
    this.suffix,
    this.style,
    this.duration = const Duration(milliseconds: 600),
    this.curve = AppAnimations.entrance,
    this.isCurrency = false,
    this.decimalDigits = 0,
  });

  @override
  Widget build(BuildContext context) {
    if (AppAnimations.shouldReduceMotion(context)) {
      final text = isCurrency
          ? CurrencyUtils.format(value.toDouble())
          : (decimalDigits > 0 ? value.toStringAsFixed(decimalDigits) : value.toInt().toString());
      return Text('${prefix ?? ''}$text${suffix ?? ''}', style: style);
    }

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: value.toDouble()),
      duration: duration,
      curve: curve,
      builder: (context, currentValue, child) {
        String formatted;
        if (isCurrency) {
          formatted = CurrencyUtils.format(currentValue);
        } else if (decimalDigits > 0) {
          formatted = currentValue.toStringAsFixed(decimalDigits);
        } else {
          formatted = currentValue.toInt().toString();
        }
        return Text(
          '${prefix ?? ''}$formatted${suffix ?? ''}',
          style: style,
        );
      },
    );
  }
}

/// Smooth empty state container with animated entrance and soft floating icon
class AnimatedEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Color? iconColor;
  final VoidCallback? onAction;
  final String? actionLabel;

  const AnimatedEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.iconColor,
    this.onAction,
    this.actionLabel,
  });

  @override
  Widget build(BuildContext context) {
    return StaggeredEntrance(
      offset: const Offset(0, 16),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0.8, end: 1.0),
                duration: AppAnimations.medium,
                curve: AppAnimations.spring,
                builder: (context, val, child) {
                  return Transform.scale(
                    scale: val,
                    child: Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        color: (iconColor ?? Colors.grey).withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        icon,
                        size: 38,
                        color: iconColor ?? Colors.grey.shade600,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF374151),
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 6),
                Text(
                  subtitle!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6B7280),
                    height: 1.35,
                  ),
                ),
              ],
              if (onAction != null && actionLabel != null) ...[
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: onAction,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: Text(actionLabel!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Custom smooth page transitions builder that eliminates flickering and harsh jumps
class SmoothFadeUpwardsPageTransitionsBuilder extends PageTransitionsBuilder {
  const SmoothFadeUpwardsPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (AppAnimations.shouldReduceMotion(context)) {
      return child;
    }

    final curvedAnimation = CurvedAnimation(
      parent: animation,
      curve: AppAnimations.entrance,
      reverseCurve: AppAnimations.exit,
    );

    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0.0, 0.04),
        end: Offset.zero,
      ).animate(curvedAnimation),
      child: FadeTransition(
        opacity: Tween<double>(begin: 0.0, end: 1.0).animate(curvedAnimation),
        child: child,
      ),
    );
  }
}
