// lib/features/info/screens/general_info_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:hive/hive.dart';
import '../../../../core/services/activation_status_service.dart';
import '../../../../core/constants/endpoints.dart';
import '../../courses/screens/lectures.dart' show LectureRichTextBlock;

// ===================== MODELS =====================
class InformationCategory {
  final int id;
  final String name;
  final String color;
  final int displayOrder;

  InformationCategory({
    required this.id,
    required this.name,
    required this.color,
    required this.displayOrder,
  });

  factory InformationCategory.fromJson(Map<String, dynamic> json) {
    return InformationCategory(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      color: json['color'] ?? '#000000',
      displayOrder: json['display_order'] ?? 0,
    );
  }
}

class InformationItem {
  final int id;
  final String title;
  final String preview;
  final String category;
  final String categoryColor;
  final String date;
  bool isRead;
  final String content;
  final bool isFeatured;
  final bool requiresActivation;
  final String activationMessage;
  final String? isGeneral;
  final String? activationTarget;
  final String? activationGrades;
  final List<int>? universities;
  final List<int>? faculties;
  final String? showToNonActivated;

  InformationItem({
    required this.id,
    required this.title,
    required this.preview,
    required this.category,
    required this.categoryColor,
    required this.date,
    required this.isRead,
    required this.content,
    required this.isFeatured,
    this.requiresActivation = false,
    this.activationMessage = '',
    this.isGeneral,
    this.activationTarget,
    this.activationGrades,
    this.universities,
    this.faculties,
    this.showToNonActivated,
  });

  factory InformationItem.fromJson(Map<String, dynamic> json) {
    return InformationItem(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      preview: json['preview'] ?? '',
      category: json['category_name'] ?? '',
      categoryColor: json['category_color'] ?? '#000000',
      date: json['date'] ?? '',
      isRead: false,
      content: json['content'] ?? '',
      isFeatured: json['is_featured'] ?? false,
      requiresActivation: json['requires_activation'] ?? false,
      activationMessage: json['activation_message'] ?? '',
      isGeneral: json['is_general'] as String?,
      activationTarget: json['activation_target'] as String?,
      activationGrades: json['activation_grades'] as String?,
      universities: json['universities'] != null && json['universities'] is List
          ? List<int>.from(json['universities'] as List)
          : null,
      faculties: json['faculties'] != null && json['faculties'] is List
          ? List<int>.from(json['faculties'] as List)
          : null,
      showToNonActivated: json['show_to_non_activated'] as String?,
    );
  }

  // Helper methods
  bool get isTargeted => isGeneral == 'targeted';
  bool get isGeneralInfo => isGeneral == 'general';

  List<String> get activationGradesList {
    if (activationGrades == null || activationGrades!.isEmpty) return [];
    return activationGrades!.split(',').map((g) => g.trim()).toList();
  }

  String get targetingDescription {
    if (isGeneralInfo) {
      // General information
      if (activationTarget == 'all') {
        return 'General information for everyone';
      } else if (activationTarget == 'activated_only') {
        return 'General information for activated users only';
      } else if (activationTarget == 'specific_plan') {
        return 'General information for ${activationGradesList.join(", ")} plans';
      }
      return 'General information';
    } else {
      // Targeted information
      List<String> parts = ['Targeted information'];

      if (universities != null && universities!.isNotEmpty) {
        parts.add('for specific universities');
      }
      if (faculties != null && faculties!.isNotEmpty) {
        parts.add('for specific faculties');
      }

      if (activationTarget == 'activated_only') {
        parts.add('(activated users only)');
      } else if (activationTarget == 'specific_plan') {
        parts.add('(${activationGradesList.join(", ")} plans)');
      } else if (activationTarget == 'all') {
        parts.add('(all users)');
      }

      return parts.join(' ');
    }
  }

  bool requiresActivationFor(ActivationStatusSnapshot snapshot) {
    if (!requiresActivation) {
      return false;
    }

    if (!snapshot.hasCachedValue || !snapshot.isActivated) {
      return true;
    }

    if (activationTarget == 'specific_plan' &&
        activationGradesList.isNotEmpty) {
      final normalizedGrade = snapshot.grade?.trim().toLowerCase();
      if (normalizedGrade == null || normalizedGrade.isEmpty) {
        return true;
      }

      return !activationGradesList.any(
        (grade) => grade.toLowerCase() == normalizedGrade,
      );
    }

    return false;
  }
}

// ===================== MAIN SCREEN =====================
class GeneralInfoScreen extends StatefulWidget {
  const GeneralInfoScreen({super.key});

  @override
  State<GeneralInfoScreen> createState() => _GeneralInfoScreenState();
}

class _GeneralInfoScreenState extends State<GeneralInfoScreen> {
  // State variables
  List<InformationItem> _infoItems = [];
  List<InformationItem> _filteredItems = [];
  List<InformationCategory> _categories = [];
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'All';
  bool _isSearching = false;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  int? _userId;
  ActivationStatusSnapshot _activationSnapshot =
      ActivationStatusService.current;

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _pageBackground => _isDark ? const Color(0xFF09111F) : Colors.white;
  Color get _surfaceColor => _isDark ? const Color(0xFF101A2B) : Colors.white;
  Color get _secondarySurfaceColor =>
      _isDark ? const Color(0xFF162235) : const Color(0xFFF8FAFC);
  Color get _borderColor =>
      _isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE5E7EB);
  Color get _titleColor => _isDark ? const Color(0xFFF8FAFC) : Colors.black;
  Color get _bodyColor => _isDark ? const Color(0xFFCBD5E1) : Colors.black54;

  @override
  void initState() {
    super.initState();
    ActivationStatusService.listenable.addListener(
      _handleActivationStatusChanged,
    );
    _applyActivationSnapshot(ActivationStatusService.current);
    unawaited(_syncActivationStatus());
    _initAndLoadData();
  }

  @override
  void dispose() {
    ActivationStatusService.listenable.removeListener(
      _handleActivationStatusChanged,
    );
    _searchController.dispose();
    super.dispose();
  }

  void _handleActivationStatusChanged() {
    if (!mounted) return;
    _applyActivationSnapshot(ActivationStatusService.current);
  }

  void _applyActivationSnapshot(ActivationStatusSnapshot snapshot) {
    if (!mounted) return;

    setState(() {
      _activationSnapshot = snapshot;
    });
  }

  Future<void> _syncActivationStatus() async {
    try {
      await ActivationStatusService.initialize();
      final status = await ActivationStatusService.resolveStatus(
        forceRefresh: false,
      );

      _applyActivationSnapshot(status);

      if (status.isStale || !status.hasCachedValue) {
        ActivationStatusService.refreshInBackground(forceRefresh: true);
      }
    } catch (_) {}
  }

  Future<void> _initAndLoadData() async {
    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });

      // 1. Get user ID from Hive
      await _getUserId();

      // 2. Load categories
      await _loadCategories();

      // 3. Load information items
      await _loadInformationItems();
    } catch (e) {
      print('❌ Error initializing: $e');
      setState(() {
        _hasError = true;
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _getUserId() async {
    try {
      final box = await Hive.openBox('user_box');
      final userData = box.get('current_user');

      if (userData == null) {
        print('⚠️ No user data in Hive');
        return;
      }

      // Extract user ID
      if (userData is Map) {
        _userId = userData['id'] as int?;
      } else if (userData is String) {
        try {
          final parsed = json.decode(userData);
          _userId = parsed['id'] as int?;
        } catch (e) {
          print('⚠️ Could not parse userData: $e');
        }
      }

      print('👤 User ID retrieved: $_userId');
    } catch (e) {
      print('❌ Error getting user ID: $e');
    }
  }

  Future<void> _loadCategories() async {
    try {
      final url = Uri.parse(ApiEndpoints.informationCategories);
      print('🌐 Loading categories from: $url');

      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<InformationCategory> loadedCategories = [];

        if (data is List) {
          loadedCategories = data
              .map((cat) => InformationCategory.fromJson(cat))
              .toList();
        } else if (data is Map && data.containsKey('results')) {
          loadedCategories = (data['results'] as List)
              .map((cat) => InformationCategory.fromJson(cat))
              .toList();
        }

        print('✅ Loaded ${loadedCategories.length} categories');

        setState(() {
          _categories = loadedCategories;
        });
      } else {
        print('⚠️ Failed to load categories: ${response.statusCode}');
      }
    } catch (e) {
      print('⚠️ Error loading categories: $e');
      // Don't fail the whole screen if categories fail
    }
  }

  Future<void> _loadInformationItems() async {
    try {
      print('🔄 Loading information items...');

      // Build URL with user_id if available
      String url = ApiEndpoints.informationItems;
      if (_userId != null) {
        url = '${ApiEndpoints.informationItems}?user_id=$_userId';
      }

      print('🌐 Request URL: $url');

      // Get auth token
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      // Prepare headers
      final headers = <String, String>{'Content-Type': 'application/json'};

      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Token $token';
        print('🔑 Using auth token');
      }

      // Make request
      final response = await http
          .get(Uri.parse(url), headers: headers)
          .timeout(const Duration(seconds: 30));

      print('📡 Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        print('📦 Response type: ${responseData.runtimeType}');

        List<InformationItem> loadedItems = [];

        // Parse response - handle different formats
        if (responseData is List) {
          // Direct list
          print('✅ Direct list response with ${responseData.length} items');
          loadedItems = responseData
              .map((item) => InformationItem.fromJson(item))
              .toList();
        } else if (responseData is Map) {
          // Check for items key
          if (responseData.containsKey('items') &&
              responseData['items'] is List) {
            print(
              '✅ Found "items" key with ${responseData['items'].length} items',
            );
            loadedItems = (responseData['items'] as List)
                .map((item) => InformationItem.fromJson(item))
                .toList();
          } else if (responseData.containsKey('results') &&
              responseData['results'] is List) {
            print(
              '✅ Found "results" key with ${responseData['results'].length} items',
            );
            loadedItems = (responseData['results'] as List)
                .map((item) => InformationItem.fromJson(item))
                .toList();
          } else if (responseData.containsKey('data') &&
              responseData['data'] is List) {
            print(
              '✅ Found "data" key with ${responseData['data'].length} items',
            );
            loadedItems = (responseData['data'] as List)
                .map((item) => InformationItem.fromJson(item))
                .toList();
          } else {
            print('⚠️ No recognized list key found in response');
            print('   Available keys: ${responseData.keys}');

            // Try to find any list in the response
            for (var key in responseData.keys) {
              final value = responseData[key];
              if (value is List) {
                print('✅ Found list in key "$key" with ${value.length} items');
                loadedItems = (value as List)
                    .map((item) => InformationItem.fromJson(item))
                    .toList();
                break;
              }
            }
          }
        }

        // IMPORTANT: Server already filtered items, so we show ALL received items
        print(
          '📊 Server returned ${loadedItems.length} items (already filtered)',
        );

        // Load read status
        final prefs = await SharedPreferences.getInstance();
        for (var item in loadedItems) {
          item.isRead = prefs.getBool('read_${item.id}') ?? false;
        }

        // Print item details for debugging
        for (var item in loadedItems) {
          print('📄 Item: ${item.title}');
          print('   - ID: ${item.id}');
          print('   - is_general: ${item.isGeneral}');
          print('   - isTargeted: ${item.isTargeted}');
          print('   - isGeneralInfo: ${item.isGeneralInfo}');
          print('   - Activation Required: ${item.requiresActivation}');
          print('   - Targeting Description: ${item.targetingDescription}');
          print('---');
        }

        setState(() {
          _infoItems = loadedItems;
          _filteredItems = loadedItems; // Show ALL items returned by server
          _isLoading = false;
          _hasError = false;
        });
      } else {
        print('❌ Server error: ${response.statusCode}');
        throw Exception('Server returned status ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error loading items: $e');
      setState(() {
        _hasError = true;
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _markAsRead(int itemId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('read_$itemId', true);

    setState(() {
      for (var item in _infoItems) {
        if (item.id == itemId) {
          item.isRead = true;
        }
      }
      for (var item in _filteredItems) {
        if (item.id == itemId) {
          item.isRead = true;
        }
      }
    });
  }

  void _filterItems() {
    setState(() {
      if (_searchController.text.isEmpty) {
        _filteredItems = _infoItems;
      } else {
        final searchTerm = _searchController.text.toLowerCase();
        _filteredItems = _infoItems.where((item) {
          return item.title.toLowerCase().contains(searchTerm) ||
              item.preview.toLowerCase().contains(searchTerm) ||
              item.content.toLowerCase().contains(searchTerm);
        }).toList();
      }

      if (_selectedCategory != 'All') {
        _filteredItems = _filteredItems
            .where((item) => item.category == _selectedCategory)
            .toList();
      }
    });
  }

  void _clearSearch() {
    setState(() {
      _searchController.clear();
      _isSearching = false;
      _filterItems();
    });
  }

  void _onCategorySelected(String category) {
    setState(() {
      _selectedCategory = category;
      _filterItems();
    });
  }

  Future<void> _refreshData() async {
    await _initAndLoadData();
  }

  // ===================== UI BUILDERS =====================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBackground,
      appBar: AppBar(
        backgroundColor: _surfaceColor,
        elevation: 0.5,
        title: _isSearching
            ? _buildSearchField()
            : Text(
                'General Information',
                style: TextStyle(
                  color: _titleColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 20,
                ),
              ),
        centerTitle: false,
        actions: _buildAppBarActions(),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: GestureDetector(
          onTap: () {
            if (_isSearching) {
              FocusScope.of(context).unfocus();
            }
          },
          child: Column(
            children: [
              _buildCategoriesFilter(),
              Expanded(child: _buildInformationList()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      autofocus: true,
      decoration: InputDecoration(
        hintText: 'Search information...',
        border: InputBorder.none,
        hintStyle: TextStyle(color: _bodyColor),
        suffixIcon: IconButton(
          icon: Icon(Icons.close, color: _bodyColor),
          onPressed: _clearSearch,
        ),
      ),
      style: TextStyle(fontSize: 16, color: _titleColor),
      onChanged: (value) => _filterItems(),
    );
  }

  List<Widget> _buildAppBarActions() {
    if (_isSearching) {
      return [
        IconButton(
          icon: const Text(
            'Cancel',
            style: TextStyle(color: Colors.blue, fontWeight: FontWeight.w500),
          ),
          onPressed: _clearSearch,
        ),
      ];
    } else {
      return [
        IconButton(
          icon: Icon(Icons.search, color: _bodyColor),
          onPressed: () {
            setState(() {
              _isSearching = true;
            });
          },
        ),
      ];
    }
  }

  Widget _buildCategoriesFilter() {
    final categories = ['All', ..._categories.map((cat) => cat.name)];

    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected = category == _selectedCategory;
          final categoryObj = _categories.firstWhere(
            (cat) => cat.name == category,
            orElse: () => InformationCategory(
              id: 0,
              name: 'All',
              color: '#000000',
              displayOrder: 0,
            ),
          );

          return Container(
            margin: const EdgeInsets.only(right: 8),
            child: ElevatedButton(
              onPressed: () => _onCategorySelected(category),
              style: ElevatedButton.styleFrom(
                backgroundColor: isSelected
                    ? _parseColor(categoryObj.color)
                    : _secondarySurfaceColor,
                foregroundColor: isSelected ? Colors.white : _bodyColor,
                elevation: 0,
                side: BorderSide(
                  color: isSelected
                      ? _parseColor(categoryObj.color)
                      : _borderColor,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
              child: Text(
                category,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInformationList() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading information...', style: TextStyle(color: _bodyColor)),
          ],
        ),
      );
    }

    if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'Failed to load information',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            // if (_errorMessage.isNotEmpty)
            //   Padding(
            //     padding: const EdgeInsets.symmetric(
            //       horizontal: 40,
            //       vertical: 8,
            //     ),
            //     child: Text(
            //       _errorMessage,
            //       textAlign: TextAlign.center,
            //       style: const TextStyle(color: Colors.grey, fontSize: 12),
            //     ),
            //   ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _refreshData,
              child: const Text('Try Again'),
            ),
          ],
        ),
      );
    }

    if (_filteredItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.info_outline, size: 70, color: Colors.grey.shade400),
            const SizedBox(height: 20),
            Text(
              'No information found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: _titleColor,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Try adjusting your search or filter to find what you\'re looking for',
                textAlign: TextAlign.center,
                style: TextStyle(color: _bodyColor, fontSize: 14),
              ),
            ),
          ],
        ),
      );
    }

    final unreadCount = _filteredItems.where((item) => !item.isRead).length;
    final activationRequiredCount = _filteredItems
        .where((item) => item.requiresActivationFor(_activationSnapshot))
        .length;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_filteredItems.length} items • $unreadCount unread${activationRequiredCount > 0 ? ' • $activationRequiredCount require activation' : ''}',
                style: TextStyle(
                  color: _bodyColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 16),
            itemCount: _filteredItems.length,
            itemBuilder: (context, index) {
              final item = _filteredItems[index];
              return _buildInfoListItem(item);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildInfoListItem(InformationItem item) {
    final requiresActivation = item.requiresActivationFor(_activationSnapshot);
    final isTargeted = item.isTargeted;
    final isGeneralInfo = item.isGeneralInfo;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: item.isRead
            ? _surfaceColor
            : (_isDark
                  ? Colors.blue.withValues(alpha: 0.14)
                  : Colors.blue.shade50),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: requiresActivation
              ? Colors.orange.shade200
              : isTargeted
              ? Colors.purple.shade200
              : _borderColor,
          width: requiresActivation || isTargeted ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: _isDark ? 0.2 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            if (requiresActivation) {
              _showActivationRequiredDialog(item);
            } else {
              _openInfoDetail(item);
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!item.isRead)
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(top: 6, right: 12),
                    decoration: BoxDecoration(
                      color: requiresActivation
                          ? Colors.orange
                          : isTargeted
                          ? Colors.purple
                          : Colors.blue,
                      shape: BoxShape.circle,
                    ),
                  )
                else if (requiresActivation || isTargeted)
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(top: 6, right: 12),
                    decoration: BoxDecoration(
                      color: requiresActivation ? Colors.orange : Colors.purple,
                      shape: BoxShape.circle,
                    ),
                  )
                else
                  const SizedBox(width: 20),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _parseColor(
                                item.categoryColor,
                              ).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              item.category,
                              style: TextStyle(
                                color: _parseColor(item.categoryColor),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (isTargeted)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.purple.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.radio_button_checked,
                                    size: 12,
                                    color: Colors.purple,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Targeted',
                                    style: TextStyle(
                                      color: Colors.purple,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (requiresActivation)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Row(
                                children: [
                                  Icon(
                                    Icons.lock,
                                    size: 12,
                                    color: Colors.orange,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'Activation Required',
                                    style: TextStyle(
                                      color: Colors.orange,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          // Show badge for general info with restrictions
                          if (isGeneralInfo &&
                              item.activationTarget != 'all' &&
                              !requiresActivation)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    size: 12,
                                    color: Colors.blue,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    item.activationTarget == 'activated_only'
                                        ? 'Activated Only'
                                        : 'Specific Plan',
                                    style: TextStyle(
                                      color: Colors.blue,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      Text(
                        item.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: item.isRead
                              ? FontWeight.w500
                              : FontWeight.w700,
                          color: requiresActivation
                              ? Colors.grey.shade600
                              : Colors.black87,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),

                      const SizedBox(height: 8),

                      if (requiresActivation)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 14,
                                color: Colors.orange.shade700,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  item.activationMessage,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.orange.shade700,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        )
                      else if (isTargeted ||
                          (isGeneralInfo && item.activationTarget != 'all'))
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: isTargeted
                                ? Colors.purple.withOpacity(0.05)
                                : Colors.blue.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isTargeted ? Icons.school : Icons.info_outline,
                                size: 14,
                                color: isTargeted
                                    ? Colors.purple.shade700
                                    : Colors.blue.shade700,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  item.targetingDescription,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isTargeted
                                        ? Colors.purple.shade700
                                        : Colors.blue.shade700,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Text(
                          item.preview,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black54,
                            height: 1.4,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),

                      const SizedBox(height: 12),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            item.date,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black45,
                            ),
                          ),
                          if (item.activationGrades != null &&
                              item.activationGrades!.isNotEmpty)
                            Text(
                              'Plan: ${item.activationGrades}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).primaryColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showActivationRequiredDialog(InformationItem item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _surfaceColor,
        title: const Text('Activation Required'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.activationMessage),
            const SizedBox(height: 16),
            if (item.activationGrades != null &&
                item.activationGrades!.isNotEmpty)
              Text(
                'Required Plan: ${item.activationGrades}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Navigate to activation screen
              // Navigator.push(context, MaterialPageRoute(builder: (context) => ActivationScreen()));
            },
            child: const Text('Activate Now'),
          ),
        ],
      ),
    );
  }

  void _openInfoDetail(InformationItem item) {
    _markAsRead(item.id);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => InfoDetailScreen(infoItem: item)),
    );
  }

  Color _parseColor(String hexColor) {
    hexColor = hexColor.replaceAll("#", "");
    if (hexColor.length == 6) {
      hexColor = "FF$hexColor";
    }
    return Color(int.parse(hexColor, radix: 16));
  }
}

// ===================== DETAIL SCREEN =====================
class InfoDetailScreen extends StatefulWidget {
  final InformationItem infoItem;

  const InfoDetailScreen({super.key, required this.infoItem});

  @override
  State<InfoDetailScreen> createState() => _InfoDetailScreenState();
}

class _InfoDetailScreenState extends State<InfoDetailScreen> {
  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  ActivationStatusSnapshot _activationSnapshot =
      ActivationStatusService.current;

  Color _parseColor(String hexColor) {
    hexColor = hexColor.replaceAll("#", "");
    if (hexColor.length == 6) {
      hexColor = "FF$hexColor";
    }
    return Color(int.parse(hexColor, radix: 16));
  }

  @override
  void initState() {
    super.initState();
    ActivationStatusService.listenable.addListener(
      _handleActivationStatusChanged,
    );
    _applyActivationSnapshot(ActivationStatusService.current);
    unawaited(_syncActivationStatus());
  }

  @override
  void dispose() {
    ActivationStatusService.listenable.removeListener(
      _handleActivationStatusChanged,
    );
    super.dispose();
  }

  void _handleActivationStatusChanged() {
    if (!mounted) return;
    _applyActivationSnapshot(ActivationStatusService.current);
  }

  void _applyActivationSnapshot(ActivationStatusSnapshot snapshot) {
    if (!mounted) return;

    setState(() {
      _activationSnapshot = snapshot;
    });
  }

  Future<void> _syncActivationStatus() async {
    try {
      await ActivationStatusService.initialize();
      final status = await ActivationStatusService.resolveStatus(
        forceRefresh: false,
      );

      _applyActivationSnapshot(status);

      if (status.isStale || !status.hasCachedValue) {
        ActivationStatusService.refreshInBackground(forceRefresh: true);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final requiresActivation = widget.infoItem.requiresActivationFor(
      _activationSnapshot,
    );
    final isTargeted = widget.infoItem.isTargeted;
    final isGeneralInfo = widget.infoItem.isGeneralInfo;

    return Scaffold(
      backgroundColor: _isDark ? const Color(0xFF09111F) : Colors.white,
      appBar: AppBar(
        backgroundColor: _isDark ? const Color(0xFF101A2B) : Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: _isDark ? const Color(0xFFF8FAFC) : Colors.black,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Information',
          style: TextStyle(
            color: _isDark ? const Color(0xFFF8FAFC) : Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (requiresActivation)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.lock, color: Colors.orange.shade700),
                        const SizedBox(width: 8),
                        const Text(
                          'Activation Required',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(widget.infoItem.activationMessage),
                    const SizedBox(height: 16),
                    if (widget.infoItem.activationGrades != null &&
                        widget.infoItem.activationGrades!.isNotEmpty)
                      Text(
                        'Required Plan: ${widget.infoItem.activationGrades}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          // Navigate to activation screen
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange.shade600,
                        ),
                        child: const Text('Activate Now'),
                      ),
                    ),
                  ],
                ),
              )
            else if (isTargeted ||
                (isGeneralInfo && widget.infoItem.activationTarget != 'all'))
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: isTargeted
                      ? Colors.purple.shade50
                      : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isTargeted
                        ? Colors.purple.shade200
                        : Colors.blue.shade200,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isTargeted ? Icons.school : Icons.info_outline,
                          color: isTargeted
                              ? Colors.purple.shade700
                              : Colors.blue.shade700,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isTargeted
                              ? 'Targeted Information'
                              : 'General Information',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: isTargeted
                                ? Colors.purple.shade700
                                : Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.infoItem.targetingDescription,
                      style: TextStyle(
                        color: isTargeted
                            ? Colors.purple.shade700
                            : Colors.blue.shade700,
                      ),
                    ),
                  ],
                ),
              ),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _parseColor(
                  widget.infoItem.categoryColor,
                ).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                widget.infoItem.category,
                style: TextStyle(
                  color: _parseColor(widget.infoItem.categoryColor),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            const SizedBox(height: 16),

            Text(
              widget.infoItem.title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
                height: 1.3,
              ),
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                const Icon(Icons.access_time, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  widget.infoItem.date,
                  style: const TextStyle(color: Colors.grey, fontSize: 14),
                ),
                const SizedBox(width: 16),
                Icon(
                  Icons.circle,
                  size: 8,
                  color: widget.infoItem.isRead ? Colors.green : Colors.blue,
                ),
                const SizedBox(width: 4),
                Text(
                  widget.infoItem.isRead ? 'Read' : 'Unread',
                  style: const TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ],
            ),

            const SizedBox(height: 24),

            if (!requiresActivation)
              _buildHtmlContent(widget.infoItem.content)
            else
              _buildPlaceholderContent(),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderContent() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(Icons.lock, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 20),
          Text(
            'Content Locked',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            widget.infoItem.activationMessage,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey.shade500),
          ),
          if (widget.infoItem.activationGrades != null &&
              widget.infoItem.activationGrades!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Required: ${widget.infoItem.activationGrades} plan',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Navigate to activation screen
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade600,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
            child: const Text(
              'Upgrade to View',
              style: TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHtmlContent(String content) {
    if (content.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Text(
          'No content available',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 50),
      child: LectureRichTextBlock(content: content, fontSize: 16),
    );
  }
}
