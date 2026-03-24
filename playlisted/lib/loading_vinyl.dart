import 'dart:math' as math;
import 'package:flutter/material.dart';

// How to implment into a page:
//
// Step 1: Import the widget
//
// import 'loading_vinyl.dart';
// 
// Step 2: Use it in your build method, simaler to this  
//
// Widget build(BuildContext context) {
//    final appState = context.read<MyAppState>();
//    return StreamBuilder<List<Map<String, dynamic>>>(
//      stream: stream,
//      builder: (context, snap) {
//        if (snap.connectionState == ConnectionState.waiting) {
//          return const LoadingVinylPage(
//            labelText: 'Loading songs...',
//            ringText: ' NOW LOADING YOUR SONGS ',
//          );
//        }

class LoadingVinyl extends StatefulWidget {
  final String labelText;
  final String ringText;
  final String? errorText;
  final VoidCallback? onRetry;
  final double size;
  final Color vinylColor;
  final int grooveCount;

  // A spinning vinyl widget to indicate loading state
  const LoadingVinyl({
    super.key,
    this.labelText = 'Loading...',
    this.ringText = ' NOW LOADING ',
    this.errorText,
    this.onRetry,
    this.size = 200,
    this.vinylColor = Colors.black,
    this.grooveCount = 5,
  });

  @override
  State<LoadingVinyl> createState() => _LoadingVinylState();
}

class _LoadingVinylState extends State<LoadingVinyl>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasError =
        widget.errorText != null && widget.errorText!.trim().isNotEmpty;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Spinning vinyl
        SizedBox(
          width: widget.size,
          height: widget.size,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) => Transform.rotate(
              angle: _controller.value * 2 * math.pi,
              child: child,
            ),
            child: _VinylDisc(
              size: widget.size,
              vinylColor: widget.vinylColor,
              grooveCount: widget.grooveCount,
              ringText: widget.ringText,
            ),
          ),
        ),

        const SizedBox(height: 20),

        // Label
        Text(
          hasError ? 'Couldn\'t load' : widget.labelText,
          style: theme.textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),

        // Error details + retry
        if (hasError) ...[
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              widget.errorText!,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.error),
              textAlign: TextAlign.center,
              maxLines: 6,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (widget.onRetry != null) ...[
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: widget.onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ],
      ],
    );
  }
}

// inside of the vinyl disc
class _VinylDisc extends StatelessWidget {
  final double size;
  final Color vinylColor;
  final int grooveCount;
  final String ringText;

  const _VinylDisc({
    required this.size,
    required this.vinylColor,
    required this.grooveCount,
    required this.ringText,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final grooveStep = size / (grooveCount + 1);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: vinylColor,
        boxShadow: [
          BoxShadow(
            color: vinylColor.withOpacity(0.30),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Grooves
          for (int i = 1; i <= grooveCount; i++)
            Container(
              width: size - (i * grooveStep),
              height: size - (i * grooveStep),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.grey.withOpacity(0.30),
                  width: 1,
                ),
              ),
            ),

          // Center label
          Container(
            width: size * 0.30,
            height: size * 0.30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.colorScheme.primary,
            ),
            child: Icon(
              Icons.album,
              color: theme.colorScheme.onPrimary,
              size: size * 0.15,
            ),
          ),

          // Center hole
          Container(
            width: size * 0.07,
            height: size * 0.07,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black,
            ),
          ),

          // Curved ring text
          _VinylRingText(label: ringText, radius: size * 0.425),
        ],
      ),
    );
  }
}

// Curved ring text
class _VinylRingText extends StatelessWidget {
  final String label;
  final double radius;

  const _VinylRingText({required this.label, required this.radius});

  @override
  Widget build(BuildContext context) {
    const double fontSize = 8.0;
    const double anglePerChar = 0.15;

    final characters = label.characters.toList();
    final int charCount = characters.length;
    final double totalAngle = anglePerChar * (charCount - 1);
    final double startAngle = -math.pi / 2 - totalAngle / 2;
    final double containerSize = radius * 2 + fontSize * 2;

    return SizedBox(
      width: containerSize,
      height: containerSize,
      child: Stack(
        alignment: Alignment.center,
        children: List.generate(charCount, (i) {
          final double angle = startAngle + anglePerChar * i;
          final double x = radius * math.cos(angle);
          final double y = radius * math.sin(angle);

          return Transform.translate(
            offset: Offset(x, y),
            child: Transform.rotate(
              angle: angle + math.pi / 2,
              child: Text(
                characters[i],
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withOpacity(0.75),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class LoadingVinylPage extends StatelessWidget {
  final String labelText;
  final String ringText;
  final String? errorText;
  final VoidCallback? onRetry;
  final double vinylSize;
  final Color vinylColor;

  const LoadingVinylPage({
    super.key,
    this.labelText = 'Loading...',
    this.ringText = ' NOW LOADING ',
    this.errorText,
    this.onRetry,
    this.vinylSize = 200,
    this.vinylColor = Colors.black,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: LoadingVinyl(
          labelText: labelText,
          ringText: ringText,
          errorText: errorText,
          onRetry: onRetry,
          size: vinylSize,
          vinylColor: vinylColor,
        ),
      ),
    );
  }
}