import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// This file contains the generic HelpOverlay widget,
// which will be reused across multiple pages by passing different content data to it. 
// This allows for flexible rendering of various sections and items without needing to change the widget code itself.

// A single help item shown as an icon-card.
class HelpItem {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String body;

  const HelpItem({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.body,
  });
}

// A labelled group of [HelpItem]s rendered under a section heading.
class HelpSection {
  final String heading;
  final List<HelpItem> items;

  const HelpSection({
    required this.heading,
    required this.items,
  });
}

// All the content needed to render one page's help overlay.
class HelpPageContent {
  final String appBarTitle;
  final IconData heroIcon;
  final String heroTitle;
  final String heroSubtitle;
  final String? tipText;
  final List<HelpSection> sections;

  const HelpPageContent({
    required this.appBarTitle,
    required this.heroIcon,
    required this.heroTitle,
    required this.heroSubtitle,
    required this.sections,
    this.tipText,
  });
}

// HelpOverlay widget
// Generic full-screen help overlay.
// Usage:
//   Navigator.of(context).push(HelpOverlay.route(HelpContent.home));
class HelpOverlay extends StatelessWidget {
  final HelpPageContent content;

  const HelpOverlay({super.key, required this.content});

  static Route<void> route(HelpPageContent content) =>
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => HelpOverlay(content: content),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bg      = isDark ? const Color(0xFF0A1628) : const Color(0xFFF0F7FC);
    final cardBg  = isDark ? const Color(0xFF111E30) : Colors.white;
    final accent  = const Color(0xFF1583B7);
    final txtPri  = isDark ? Colors.white            : const Color(0xFF0D1F2D);
    final txtSec  = isDark ? Colors.white60          : const Color(0xFF4A6572);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF0A2233) : accent,
        foregroundColor: Colors.white,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          content.appBarTitle,
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            letterSpacing: 0.5,
            color: Colors.white,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
        children: [
          // Hero banner
          _HeroBanner(
            icon: content.heroIcon,
            title: content.heroTitle,
            subtitle: content.heroSubtitle,
            accent: accent,
          ),

          const SizedBox(height: 28),

          // Sections
          for (final section in content.sections) ...[
            _SectionHeading(label: section.heading, color: accent),
            const SizedBox(height: 14),
            for (final item in section.items)
              _HelpCard(
                cardBg: cardBg,
                icon: item.icon,
                iconColor: item.iconColor,
                title: item.title,
                body: item.body,
                textPrimary: txtPri,
                textSecondary: txtSec,
              ),
            const SizedBox(height: 16),
          ],

          const SizedBox(height: 8),

          // Footer tip
          if (content.tipText != null)
            _TipBanner(text: content.tipText!, accent: accent, isDark: isDark, textSecondary: txtSec),
        ],
      ),
    );
  }
}

// Private sub-widgets automatically based on the content data
class _HeroBanner extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;

  const _HeroBanner({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [accent, const Color(0xFF0D6B9A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: accent.withOpacity(0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white, size: 36),
          const SizedBox(height: 12),
          Text(
            title,
            style: GoogleFonts.montserrat(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: GoogleFonts.lato(
              fontSize: 14,
              color: Colors.white.withOpacity(0.88),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  final String label;
  final Color color;
  const _SectionHeading({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          label.toUpperCase(),
          style: GoogleFonts.montserrat(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.4,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _HelpCard extends StatelessWidget {
  final Color cardBg;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String body;
  final Color textPrimary;
  final Color textSecondary;

  const _HelpCard({
    required this.cardBg,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.body,
    required this.textPrimary,
    required this.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  body,
                  style: GoogleFonts.lato(
                    fontSize: 13,
                    color: textSecondary,
                    height: 1.55,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TipBanner extends StatelessWidget {
  final String text;
  final Color accent;
  final bool isDark;
  final Color textSecondary;

  const _TipBanner({
    required this.text,
    required this.accent,
    required this.isDark,
    required this.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: accent.withOpacity(isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_outline, color: accent, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.lato(
                fontSize: 13,
                color: textSecondary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}