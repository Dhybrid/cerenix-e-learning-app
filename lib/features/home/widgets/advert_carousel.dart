// lib/features/home/widgets/advert_carousel.dart
import 'dart:async';
import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/endpoints.dart';

class Advertisement {
  final int id;
  final String? title;
  final String imageUrl;
  final String? targetUrl;
  final bool isActive;
  final int displayOrder;

  const Advertisement({
    required this.id,
    this.title,
    required this.imageUrl,
    this.targetUrl,
    required this.isActive,
    required this.displayOrder,
  });

  factory Advertisement.fromJson(Map<String, dynamic> json) {
    return Advertisement(
      id: json['id'] as int,
      title: json['title']?.toString(),
      imageUrl: json['image_url']?.toString() ?? '',
      targetUrl: json['target_url']?.toString(),
      isActive: json['is_active'] == true,
      displayOrder: json['display_order'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'image_url': imageUrl,
      'target_url': targetUrl,
      'is_active': isActive,
      'display_order': displayOrder,
    };
  }

  String get resolvedImageUrl {
    if (imageUrl.startsWith('http')) {
      return imageUrl;
    }

    if (imageUrl.startsWith('/')) {
      return '${ApiEndpoints.baseUrl}$imageUrl';
    }

    return '${ApiEndpoints.baseUrl}/$imageUrl';
  }

  bool sameContentAs(Advertisement other) {
    return id == other.id &&
        title == other.title &&
        imageUrl == other.imageUrl &&
        targetUrl == other.targetUrl &&
        isActive == other.isActive &&
        displayOrder == other.displayOrder;
  }
}

class AdvertCarousel extends StatefulWidget {
  final double height;

  const AdvertCarousel({super.key, this.height = 160});

  @override
  State<AdvertCarousel> createState() => _AdvertCarouselState();
}

class _AdvertCarouselState extends State<AdvertCarousel> {
  static const _cacheKey = 'home_advertisements_cache_v1';
  static const _backgroundRefreshInterval = Duration(minutes: 3);

  final List<String> _fallbackImages = const [
    // 'assets/images/advertboard.jpeg',
    'assets/images/courseboard.png',
    'assets/images/cerenix_courses.png',
  ];

  late final PageController _pageController;
  Timer? _autoPlayTimer;
  Timer? _backgroundUpdateTimer;
  List<Advertisement> _advertisements = const [];
  bool _isLoading = true;
  int _currentPage = 0;
  bool _isRefreshingInBackground = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _restoreCachedAdvertisements();
    _refreshAdvertisementsInBackground();
    _startBackgroundUpdates();
  }

  void _startBackgroundUpdates() {
    _backgroundUpdateTimer?.cancel();
    _backgroundUpdateTimer = Timer.periodic(
      _backgroundRefreshInterval,
      (_) => _refreshAdvertisementsInBackground(),
    );
  }

  Future<void> _restoreCachedAdvertisements() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString(_cacheKey);

      if (cachedJson == null || cachedJson.isEmpty) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
        return;
      }

      final decoded = json.decode(cachedJson);
      if (decoded is! List) {
        return;
      }

      final cachedAds =
          decoded
              .whereType<Map>()
              .map(
                (item) =>
                    Advertisement.fromJson(Map<String, dynamic>.from(item)),
              )
              .toList()
            ..sort((a, b) {
              final orderComparison = a.displayOrder.compareTo(b.displayOrder);
              if (orderComparison != 0) {
                return orderComparison;
              }
              return a.id.compareTo(b.id);
            });

      if (!mounted) {
        return;
      }

      setState(() {
        _advertisements = cachedAds;
        _isLoading = false;
      });
      _configureAutoPlay();
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _cacheAdvertisements(List<Advertisement> advertisements) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _cacheKey,
      json.encode(advertisements.map((ad) => ad.toJson()).toList()),
    );
  }

  Future<void> _refreshAdvertisementsInBackground() async {
    if (_isRefreshingInBackground) {
      return;
    }

    _isRefreshingInBackground = true;

    try {
      final fetchedAds = await _fetchAdvertisements();

      if (fetchedAds.isEmpty) {
        if (mounted && _advertisements.isEmpty) {
          setState(() {
            _isLoading = false;
          });
        }
        return;
      }

      final mergedAds = _mergeAdvertisements(_advertisements, fetchedAds);
      final hasChanged =
          _advertisements.length != mergedAds.length ||
          !_haveSameContent(_advertisements, mergedAds);

      if (!hasChanged) {
        if (mounted && _isLoading) {
          setState(() {
            _isLoading = false;
          });
        }
        return;
      }

      await _cacheAdvertisements(mergedAds);

      if (!mounted) {
        return;
      }

      final currentAdId =
          _advertisements.isNotEmpty &&
              _currentPage >= 0 &&
              _currentPage < _advertisements.length
          ? _advertisements[_currentPage].id
          : null;

      setState(() {
        _advertisements = mergedAds;
        _isLoading = false;
        if (currentAdId != null) {
          final preservedIndex = mergedAds.indexWhere(
            (ad) => ad.id == currentAdId,
          );
          _currentPage = preservedIndex >= 0 ? preservedIndex : 0;
        } else {
          _currentPage = 0;
        }
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted ||
            !_pageController.hasClients ||
            _advertisements.isEmpty) {
          return;
        }
        final safePage = _currentPage.clamp(0, _advertisements.length - 1);
        _pageController.jumpToPage(safePage);
      });

      _configureAutoPlay();
    } catch (_) {
      if (mounted && _advertisements.isEmpty) {
        setState(() {
          _isLoading = false;
        });
      }
    } finally {
      _isRefreshingInBackground = false;
    }
  }

  Future<List<Advertisement>> _fetchAdvertisements() async {
    final response = await http
        .get(Uri.parse(ApiEndpoints.activeAdvertisements))
        .timeout(const Duration(seconds: 20));

    if (response.statusCode != 200) {
      return const [];
    }

    final dynamic data = json.decode(response.body);
    List<Advertisement> loadedAds = const [];

    if (data is Map<String, dynamic> && data['results'] is List) {
      loadedAds = (data['results'] as List)
          .whereType<Map>()
          .map((ad) => Advertisement.fromJson(Map<String, dynamic>.from(ad)))
          .toList();
    } else if (data is List) {
      loadedAds = data
          .whereType<Map>()
          .map((ad) => Advertisement.fromJson(Map<String, dynamic>.from(ad)))
          .toList();
    }

    loadedAds.sort((a, b) {
      final orderComparison = a.displayOrder.compareTo(b.displayOrder);
      if (orderComparison != 0) {
        return orderComparison;
      }
      return a.id.compareTo(b.id);
    });

    return loadedAds;
  }

  List<Advertisement> _mergeAdvertisements(
    List<Advertisement> currentAds,
    List<Advertisement> fetchedAds,
  ) {
    final currentById = {for (final ad in currentAds) ad.id: ad};

    return fetchedAds.map((fetched) {
      final existing = currentById[fetched.id];
      if (existing != null && existing.sameContentAs(fetched)) {
        return existing;
      }
      return fetched;
    }).toList();
  }

  bool _haveSameContent(
    List<Advertisement> currentAds,
    List<Advertisement> nextAds,
  ) {
    if (currentAds.length != nextAds.length) {
      return false;
    }

    for (var i = 0; i < currentAds.length; i++) {
      if (!currentAds[i].sameContentAs(nextAds[i])) {
        return false;
      }
    }

    return true;
  }

  void _configureAutoPlay() {
    _autoPlayTimer?.cancel();

    if (_advertisements.length <= 1) {
      return;
    }

    _autoPlayTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted ||
          !_pageController.hasClients ||
          _advertisements.length <= 1) {
        return;
      }

      final nextPage = (_currentPage + 1) % _advertisements.length;
      _pageController.animateToPage(
        nextPage,
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
    if (_advertisements.isEmpty) {
      if (_isLoading) {
        return _buildPlaceholderBoard();
      }
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        SizedBox(
          height: widget.height,
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              if (!mounted) {
                return;
              }
              setState(() {
                _currentPage = index;
              });
            },
            itemCount: _advertisements.length,
            itemBuilder: (context, index) {
              final advertisement = _advertisements[index];
              final fallbackAsset =
                  _fallbackImages[index % _fallbackImages.length];

              return _AdvertisementCard(
                key: ValueKey(advertisement.id),
                advertisement: advertisement,
                height: widget.height,
                fallbackAsset: fallbackAsset,
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            _advertisements.length,
            (index) => AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: _currentPage == index ? 24 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: _currentPage == index
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

  Widget _buildPlaceholderBoard() {
    return SizedBox(
      height: widget.height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.asset(
          _fallbackImages.first,
          width: double.infinity,
          height: widget.height,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}

class _AdvertisementCard extends StatelessWidget {
  final Advertisement advertisement;
  final double height;
  final String fallbackAsset;

  const _AdvertisementCard({
    super.key,
    required this.advertisement,
    required this.height,
    required this.fallbackAsset,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: CachedNetworkImage(
          imageUrl: advertisement.resolvedImageUrl,
          width: double.infinity,
          height: height,
          fit: BoxFit.cover,
          fadeInDuration: const Duration(milliseconds: 220),
          fadeOutDuration: const Duration(milliseconds: 120),
          placeholderFadeInDuration: Duration.zero,
          placeholder: (_, __) => Image.asset(
            fallbackAsset,
            width: double.infinity,
            height: height,
            fit: BoxFit.cover,
          ),
          errorWidget: (_, __, ___) => Image.asset(
            fallbackAsset,
            width: double.infinity,
            height: height,
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
}
