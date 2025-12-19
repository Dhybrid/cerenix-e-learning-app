// lib/features/home/widgets/advert_carousel.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../../../core/constants/endpoints.dart';

class Advertisement {
  final int id;
  final String? title;
  final String imageUrl;
  final String? targetUrl;
  final bool isActive;
  final int displayOrder;

  Advertisement({
    required this.id,
    this.title,
    required this.imageUrl,
    this.targetUrl,
    required this.isActive,
    required this.displayOrder,
  });

  factory Advertisement.fromJson(Map<String, dynamic> json) {
    return Advertisement(
      id: json['id'],
      title: json['title'],
      imageUrl: json['image_url'] ?? '',
      targetUrl: json['target_url'],
      isActive: json['is_active'] ?? false,
      displayOrder: json['display_order'] ?? 0,
    );
  }
}

class AdvertCarousel extends StatefulWidget {
  final double height;

  const AdvertCarousel({
    super.key,
    this.height = 160,
  });

  @override
  State<AdvertCarousel> createState() => _AdvertCarouselState();
}

class _AdvertCarouselState extends State<AdvertCarousel> {
  late PageController _pageController;
  int _currentPage = 0;
  Timer? _autoPlayTimer;
  Timer? _backgroundUpdateTimer;
  List<Advertisement> _advertisements = [];
  bool _isLoading = true;
  bool _hasInternet = true;

  // TODO: Uncomment these when you add fallback images to assets
  // Fallback images for when network images fail to load
  // final List<String> _fallbackImages = [
  //   'assets/images/advert_fallback_1.jpg',
  //   'assets/images/advert_fallback_2.jpg',
  // ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _loadAds();
    _startBackgroundUpdates();
  }

  // Background updates to check for new ads every 3 minutes
  void _startBackgroundUpdates() {
    _backgroundUpdateTimer = Timer.periodic(const Duration(minutes: 3), (timer) {
      if (mounted) {
        _loadAds(); // Silently refresh ads in background
      }
    });
  }

  Future<void> _loadAds() async {
    // Check internet connection
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      if (mounted) {
        setState(() {
          _hasInternet = false;
          _isLoading = false;
        });
      }
      return;
    }

    await _loadAdvertisements();
  }

  Future<void> _loadAdvertisements() async {
    try {
      final response = await http.get(
        Uri.parse(ApiEndpoints.activeAdvertisements),
      );

      if (response.statusCode == 200) {
        final dynamic data = json.decode(response.body);
        List<Advertisement> loadedAds = [];

        // Handle paginated response format: {count, next, previous, results}
        if (data is Map<String, dynamic> && data.containsKey('results')) {
          final results = data['results'];
          if (results is List) {
            loadedAds = results.map((ad) => Advertisement.fromJson(ad)).toList();
          }
        }
        // Handle direct list response
        else if (data is List) {
          loadedAds = data.map((ad) => Advertisement.fromJson(ad)).toList();
        }

        if (mounted) {
          setState(() {
            _advertisements = loadedAds;
            _isLoading = false;
          });
        }

        // Start auto-play if we have multiple ads
        if (_advertisements.length > 1) {
          _startAutoPlay();
        } else {
          _autoPlayTimer?.cancel(); // Stop autoplay if only one ad
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _advertisements = [];
        });
      }
    }
  }

  void _startAutoPlay() {
    _autoPlayTimer?.cancel(); // Cancel existing timer
    _autoPlayTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (!mounted || _advertisements.length <= 1) {
        timer.cancel();
        return;
      }
      _currentPage = (_currentPage + 1) % _advertisements.length;
      _pageController.animateToPage(
        _currentPage,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _autoPlayTimer?.cancel();
    _backgroundUpdateTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Don't show if no internet
    if (!_hasInternet) return const SizedBox.shrink();

    // Don't show if still loading
    if (_isLoading) return const SizedBox.shrink();

    // Don't show if no ads
    if (_advertisements.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        SizedBox(
          height: widget.height,
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemCount: _advertisements.length,
            itemBuilder: (context, index) {
              final ad = _advertisements[index];
              final imageUrl = ad.imageUrl.startsWith('http') 
                  ? ad.imageUrl 
                  : '${ApiEndpoints.baseUrl}${ad.imageUrl}';

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    imageUrl,
                    width: double.infinity,
                    height: widget.height,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Center(
                          child: CircularProgressIndicator(),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      // TODO: Uncomment fallback images when added to assets
                      // return Image.asset(
                      //   _fallbackImages[index % _fallbackImages.length],
                      //   width: double.infinity,
                      //   height: widget.height,
                      //   fit: BoxFit.cover,
                      // );
                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.error_outline,
                            color: Colors.grey,
                            size: 40,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            _advertisements.length,
            (i) => AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: _currentPage == i ? 24 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: _currentPage == i
                    ? const Color(0xFFFF6B35)
                    : const Color(0xFFD1D5DB),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      ],
    );
  }
}