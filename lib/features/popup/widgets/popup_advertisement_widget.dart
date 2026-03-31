// // lib/features/popup/widgets/popup_advertisement_widget.dart
// import 'package:flutter/material.dart';
// import 'package:url_launcher/url_launcher.dart';
// import '../models/popup_advertisement.dart';
// import '../services/popup_service.dart';

// class PopupAdvertisementWidget extends StatefulWidget {
//   final PopupAdvertisement popup;
//   final int? userId;
//   final VoidCallback? onClose;

//   const PopupAdvertisementWidget({
//     super.key,
//     required this.popup,
//     this.userId,
//     this.onClose,
//   });

//   @override
//   State<PopupAdvertisementWidget> createState() =>
//       _PopupAdvertisementWidgetState();
// }

// class _PopupAdvertisementWidgetState extends State<PopupAdvertisementWidget>
//     with SingleTickerProviderStateMixin {
//   late AnimationController _controller;
//   late Animation<double> _scaleAnimation;
//   late Animation<double> _fadeAnimation;
//   bool _isClosing = false;

//   final PopupService _popupService = PopupService();

//   @override
//   void initState() {
//     super.initState();
//     _controller = AnimationController(
//       duration: const Duration(milliseconds: 300),
//       vsync: this,
//     );

//     _scaleAnimation = Tween<double>(
//       begin: 0.8,
//       end: 1.0,
//     ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

//     _fadeAnimation = Tween<double>(
//       begin: 0.0,
//       end: 1.0,
//     ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

//     // Start animation after a small delay
//     Future.delayed(const Duration(milliseconds: 100), () {
//       _controller.forward();
//     });

//     // Record that popup was shown
//     _recordPopupShown();
//   }

//   Future<void> _recordPopupShown() async {
//     try {
//       await widget.popup.trackUserViews
//           ? _popupService.recordPopupShown(widget.popup, widget.userId)
//           : null;
//     } catch (e) {
//       print('⚠️ Error recording popup shown: $e');
//     }
//   }

//   Future<void> _handlePopupClick() async {
//     if (widget.popup.hasTargetUrl) {
//       // Record click
//       await _popupService.recordPopupClick(widget.popup.id, widget.userId);

//       // Launch URL
//       try {
//         final url = Uri.parse(widget.popup.targetUrl!);
//         if (await canLaunchUrl(url)) {
//           await launchUrl(url, mode: LaunchMode.externalApplication);
//         }
//       } catch (e) {
//         print('❌ Error launching URL: $e');
//       }
//     }

//     // Close popup
//     _closePopup();
//   }

//   void _closePopup() {
//     if (_isClosing) return;

//     _isClosing = true;
//     _controller.reverse().then((_) {
//       if (widget.onClose != null) {
//         widget.onClose!();
//       }
//     });
//   }

//   @override
//   void dispose() {
//     _controller.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Material(
//       color: Colors.black54,
//       child: AnimatedBuilder(
//         animation: _controller,
//         builder: (context, child) {
//           return Opacity(
//             opacity: _fadeAnimation.value,
//             child: Transform.scale(scale: _scaleAnimation.value, child: child),
//           );
//         },
//         child: Stack(
//           children: [
//             // Tap outside to close
//             GestureDetector(
//               behavior: HitTestBehavior.opaque,
//               onTap: _closePopup,
//               child: Container(
//                 color: Colors.transparent,
//                 width: double.infinity,
//                 height: double.infinity,
//               ),
//             ),

//             // Popup content
//             Center(
//               child: Container(
//                 constraints: BoxConstraints(
//                   maxWidth: MediaQuery.of(context).size.width * 0.85,
//                   maxHeight: MediaQuery.of(context).size.height * 0.85,
//                 ),
//                 decoration: BoxDecoration(
//                   color: Colors.white,
//                   borderRadius: BorderRadius.circular(20),
//                   boxShadow: [
//                     BoxShadow(
//                       color: Colors.black.withOpacity(0.3),
//                       blurRadius: 20,
//                       spreadRadius: 2,
//                     ),
//                   ],
//                 ),
//                 child: Column(
//                   mainAxisSize: MainAxisSize.min,
//                   children: [
//                     // Header with close button
//                     Container(
//                       padding: const EdgeInsets.all(16),
//                       decoration: BoxDecoration(
//                         color: Colors.grey.shade50,
//                         borderRadius: const BorderRadius.only(
//                           topLeft: Radius.circular(20),
//                           topRight: Radius.circular(20),
//                         ),
//                       ),
//                       child: Row(
//                         children: [
//                           Expanded(
//                             child: Text(
//                               widget.popup.title ?? 'Notification',
//                               style: const TextStyle(
//                                 fontSize: 18,
//                                 fontWeight: FontWeight.bold,
//                               ),
//                               maxLines: 1,
//                               overflow: TextOverflow.ellipsis,
//                             ),
//                           ),
//                           IconButton(
//                             icon: const Icon(Icons.close, size: 20),
//                             onPressed: _closePopup,
//                             padding: EdgeInsets.zero,
//                             constraints: const BoxConstraints(),
//                           ),
//                         ],
//                       ),
//                     ),

//                     // Image
//                     if (widget.popup.imageUrl.isNotEmpty)
//                       ClipRRect(
//                         borderRadius: const BorderRadius.vertical(
//                           bottom: Radius.circular(20),
//                         ),
//                         child: GestureDetector(
//                           onTap: _handlePopupClick,
//                           child: Image.network(
//                             widget.popup.imageUrl,
//                             fit: BoxFit.cover,
//                             width: double.infinity,
//                             height: MediaQuery.of(context).size.height * 0.5,
//                             errorBuilder: (context, error, stackTrace) {
//                               return Container(
//                                 height: 200,
//                                 color: Colors.grey.shade200,
//                                 child: const Center(
//                                   child: Icon(
//                                     Icons.image_not_supported,
//                                     size: 50,
//                                     color: Colors.grey,
//                                   ),
//                                 ),
//                               );
//                             },
//                             loadingBuilder: (context, child, loadingProgress) {
//                               if (loadingProgress == null) return child;
//                               return Container(
//                                 height: 200,
//                                 color: Colors.grey.shade200,
//                                 child: const Center(
//                                   child: CircularProgressIndicator(),
//                                 ),
//                               );
//                             },
//                           ),
//                         ),
//                       ),

//                     // Activation prompt (if required)
//                     if (widget.popup.shouldShowActivationPrompt)
//                       Container(
//                         padding: const EdgeInsets.all(16),
//                         decoration: BoxDecoration(
//                           color: Colors.orange.shade50,
//                           border: Border.all(color: Colors.orange.shade200),
//                         ),
//                         child: Row(
//                           children: [
//                             Icon(
//                               Icons.lock_outline,
//                               color: Colors.orange.shade700,
//                             ),
//                             const SizedBox(width: 12),
//                             Expanded(
//                               child: Text(
//                                 widget.popup.activationMessage,
//                                 style: TextStyle(
//                                   color: Colors.orange.shade700,
//                                   fontSize: 14,
//                                 ),
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//                   ],
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
// lib/features/popup/widgets/popup_advertisement_widget.dart
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/popup_advertisement.dart';
import '../services/popup_service.dart';

class PopupAdvertisementWidget extends StatefulWidget {
  final PopupAdvertisement popup;
  final int? userId;
  final VoidCallback? onClose;

  const PopupAdvertisementWidget({
    super.key,
    required this.popup,
    this.userId,
    this.onClose,
  });

  @override
  State<PopupAdvertisementWidget> createState() =>
      _PopupAdvertisementWidgetState();
}

class _PopupAdvertisementWidgetState extends State<PopupAdvertisementWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  bool _isClosing = false;

  final PopupService _popupService = PopupService();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    // Start animation after a small delay
    Future.delayed(const Duration(milliseconds: 100), () {
      _controller.forward();
    });

    _recordPopupShown();
  }

  Future<void> _recordPopupShown() async {
    try {
      if (widget.popup.trackUserViews) {
        await _popupService.recordPopupShown(widget.popup, widget.userId);
      }
    } catch (e) {
      print('⚠️ Error recording popup shown: $e');
    }
  }

  Future<void> _handlePopupClick() async {
    if (widget.popup.hasTargetUrl) {
      // Record click
      await _popupService.recordPopupClick(widget.popup.id, widget.userId);

      // Launch URL
      try {
        final url = Uri.parse(widget.popup.targetUrl!);
        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
        }
      } catch (e) {
        print('❌ Error launching URL: $e');
      }
    }

    // Close popup
    _closePopup();
  }

  void _closePopup() {
    if (_isClosing) return;

    _isClosing = true;
    _controller.reverse().then((_) {
      if (widget.onClose != null) {
        widget.onClose!();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Opacity(
            opacity: _fadeAnimation.value,
            child: Transform.scale(scale: _scaleAnimation.value, child: child),
          );
        },
        child: Stack(
          children: [
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(color: Colors.black.withValues(alpha: 0.12)),
              ),
            ),

            // Tap anywhere to close
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _closePopup,
              child: Container(
                color: Colors.transparent,
                width: double.infinity,
                height: double.infinity,
              ),
            ),

            // Center content
            Center(
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.9,
                  maxHeight: MediaQuery.of(context).size.height * 0.8,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.16),
                      blurRadius: 28,
                      offset: const Offset(0, 14),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    // Clickable image only - NO BACKGROUND
                    GestureDetector(
                      onTap: _handlePopupClick,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.network(
                          widget.popup.displayImageUrl,
                          fit: BoxFit.contain,
                          width: double.infinity,
                          height: double.infinity,
                          frameBuilder:
                              (context, child, frame, wasSynchronouslyLoaded) {
                                if (wasSynchronouslyLoaded || frame != null) {
                                  return AnimatedOpacity(
                                    duration: const Duration(milliseconds: 220),
                                    opacity: 1,
                                    child: child,
                                  );
                                }
                                return _buildFallbackPopupContent(
                                  isError: false,
                                );
                              },
                          errorBuilder: (context, error, stackTrace) {
                            return _buildFallbackPopupContent(isError: true);
                          },
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return _buildFallbackPopupContent(isError: false);
                          },
                        ),
                      ),
                    ),

                    // Close button (X) at top-right corner of image
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: _closePopup,
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.42),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.18),
                            ),
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),

                    // Optional: Show a small indicator if image is clickable
                    if (widget.popup.hasTargetUrl)
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.42),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.16),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.open_in_new,
                                color: Colors.white,
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Tap to open',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackPopupContent({required bool isError}) {
    return Container(
      width: 300,
      height: 400,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        image: const DecorationImage(
          image: AssetImage('assets/images/advertboard.jpeg'),
          fit: BoxFit.cover,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0.08),
              Colors.black.withValues(alpha: 0.26),
            ],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              left: 14,
              top: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.16),
                  ),
                ),
                child: const Text(
                  'Sponsored',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            if (isError)
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.image_not_supported_outlined,
                      size: 54,
                      color: Colors.white.withValues(alpha: 0.86),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.popup.title ?? 'Advertisement',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              )
            else
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.14),
                      ),
                    ),
                    child: const Text(
                      'Preparing advert',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
