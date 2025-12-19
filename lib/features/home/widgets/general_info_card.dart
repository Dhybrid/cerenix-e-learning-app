// lib/features/home/widgets/general_info_card.dart
import 'package:flutter/material.dart';

class GeneralInfoCard extends StatefulWidget {
  final String? imagePath;        // Image first (if exists)
  final IconData? fallbackIcon;   // Lively icon if no image
  final Color? iconColor;         // Icon color
  final String title;
  final String subtitle;
  final List<Widget> expandedContent;
  final VoidCallback? onTap;      // Click to full page

  const GeneralInfoCard({
    super.key,
    this.imagePath,
    this.fallbackIcon,
    this.iconColor,
    required this.title,
    required this.subtitle,
    required this.expandedContent,
    this.onTap,
  });

  @override
  State<GeneralInfoCard> createState() => _GeneralInfoCardState();
}

class _GeneralInfoCardState extends State<GeneralInfoCard>
    with TickerProviderStateMixin {  // For lively icon animation
  bool _isExpanded = false;
  late AnimationController _controller;
  late Animation<double> _heightAnimation;
  late AnimationController _pulseController;  // Lively pulse for icon
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _heightAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    // LIVELY ICON: Pulsing animation (gives life)
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _toggleExpand() {
    setState(() {
      _isExpanded = !_isExpanded;
      _isExpanded ? _controller.forward() : _controller.reverse();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: widget.onTap ?? _toggleExpand,  // Click to page OR expand
        child: Column(
          children: [
            // HEADER: Image OR Lively Icon + Title + Subtitle
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // LEFT: Image first (no icon/color) OR Lively Icon (56x56)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: widget.imagePath != null
                        ? Image.asset(
                            widget.imagePath!,
                            width: 56,
                            height: 56,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _buildLivelyIcon(),  // Fallback to lively icon
                          )
                        : _buildLivelyIcon(),  // No image → lively icon
                  ),
                  const SizedBox(width: 16),

                  // CENTER: Title + Subtitle
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Color(0xFF1A1A2E),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.subtitle,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF6B7280),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  // RIGHT: Expand Arrow (if no onTap)
                  if (widget.onTap == null)
                    AnimatedRotation(
                      turns: _isExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 300),
                      child: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
                ],
              ),
            ),

            // EXPANDED CONTENT (if no onTap)
            if (widget.onTap == null)
              SizeTransition(
                sizeFactor: _heightAnimation,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: widget.expandedContent,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // HELPER: Lively animated icon (pulsing scale)
  Widget _buildLivelyIcon() {
    return ScaleTransition(
      scale: _pulseAnimation,  // Pulsing life
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: (widget.iconColor ?? const Color(0xFF0077B6)).withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          widget.fallbackIcon ?? Icons.info_outline,
          color: widget.iconColor ?? const Color(0xFF0077B6),
          size: 28,
        ),
      ),
    );
  }
}