// lib/features/info/screens/general_info_screen.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter_html/flutter_html.dart';
import '../../../../core/constants/endpoints.dart';

// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;
// import 'dart:convert';

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
      id: json['id'],
      name: json['name'],
      color: json['color'],
      displayOrder: json['display_order'],
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
  });

  factory InformationItem.fromJson(Map<String, dynamic> json) {
    return InformationItem(
      id: json['id'],
      title: json['title'],
      preview: json['preview'] ?? '', // This should now be clean text
      category: json['category_name'],
      categoryColor: json['category_color'],
      date: json['date'],
      isRead: false,
      content: json['content'] ?? '', // This keeps HTML for details
      isFeatured: json['is_featured'] ?? false,
    );
  }
}

class GeneralInfoScreen extends StatefulWidget {
  const GeneralInfoScreen({super.key});

  @override
  State<GeneralInfoScreen> createState() => _GeneralInfoScreenState();
}

class _GeneralInfoScreenState extends State<GeneralInfoScreen> {
  List<InformationItem> _infoItems = [];
  List<InformationItem> _filteredItems = [];
  List<InformationCategory> _categories = [];
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'All';
  bool _isSearching = false;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadInformation();
  }

  Future<void> _loadInformation() async {
    try {
      // Load categories
      final categoriesResponse = await http.get(
        Uri.parse(ApiEndpoints.informationCategories),
      );

      if (categoriesResponse.statusCode == 200) {
        final dynamic categoriesData = json.decode(categoriesResponse.body);
        List<InformationCategory> loadedCategories = [];

        if (categoriesData is List) {
          loadedCategories = categoriesData.map((cat) => InformationCategory.fromJson(cat)).toList();
        } else if (categoriesData is Map && categoriesData.containsKey('results')) {
          loadedCategories = (categoriesData['results'] as List).map((cat) => InformationCategory.fromJson(cat)).toList();
        }

        setState(() {
          _categories = loadedCategories;
        });
      }

      // Load information items
      final itemsResponse = await http.get(
        Uri.parse(ApiEndpoints.informationItems),
      );

      if (itemsResponse.statusCode == 200) {
        final dynamic itemsData = json.decode(itemsResponse.body);
        List<InformationItem> loadedItems = [];

        if (itemsData is List) {
          loadedItems = itemsData.map((item) => InformationItem.fromJson(item)).toList();
        } else if (itemsData is Map && itemsData.containsKey('results')) {
          loadedItems = (itemsData['results'] as List).map((item) => InformationItem.fromJson(item)).toList();
        }

        // Load read status from shared preferences
        final prefs = await SharedPreferences.getInstance();
        for (var item in loadedItems) {
          item.isRead = prefs.getBool('read_${item.id}') ?? false;
        }

        setState(() {
          _infoItems = loadedItems;
          _filteredItems = loadedItems;
          _isLoading = false;
          _hasError = false;
        });
      } else {
        throw Exception('Failed to load information');
      }
    } catch (e) {
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
    }
  }

  // Mark item as read
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
        _filteredItems = _infoItems.where((item) {
          return item.title.toLowerCase().contains(_searchController.text.toLowerCase()) ||
                 item.preview.toLowerCase().contains(_searchController.text.toLowerCase()) ||
                 item.content.toLowerCase().contains(_searchController.text.toLowerCase());
        }).toList();
      }

      if (_selectedCategory != 'All') {
        _filteredItems = _filteredItems.where((item) => item.category == _selectedCategory).toList();
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

  Future<void> _refreshInformation() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    await _loadInformation();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: _isSearching 
            ? _buildSearchField()
            : const Text(
                'General Information',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w700,
                  fontSize: 20,
                ),
              ),
        centerTitle: false,
        actions: _buildAppBarActions(),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshInformation,
        child: GestureDetector(
          onTap: () {
            if (_isSearching) {
              FocusScope.of(context).unfocus();
            }
          },
          child: Column(
            children: [
              _buildCategoriesFilter(),
              Expanded(
                child: _buildInformationList(),
              ),
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
        hintStyle: TextStyle(color: Colors.grey.shade600),
        suffixIcon: IconButton(
          icon: const Icon(Icons.close, color: Colors.grey),
          onPressed: _clearSearch,
        ),
      ),
      style: const TextStyle(fontSize: 16),
      onChanged: (value) {
        _filterItems();
      },
    );
  }

  List<Widget> _buildAppBarActions() {
    if (_isSearching) {
      return [
        IconButton(
          icon: const Text(
            'Cancel',
            style: TextStyle(
              color: Colors.blue,
              fontWeight: FontWeight.w500,
            ),
          ),
          onPressed: _clearSearch,
        ),
      ];
    } else {
      return [
        IconButton(
          icon: const Icon(Icons.search, color: Colors.black54),
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
            orElse: () => InformationCategory(id: 0, name: 'All', color: '#000000', displayOrder: 0)
          );
          
          return Container(
            margin: const EdgeInsets.only(right: 8),
            child: ElevatedButton(
              onPressed: () => _onCategorySelected(category),
              style: ElevatedButton.styleFrom(
                backgroundColor: isSelected ? _getColorFromHex(categoryObj.color) : Colors.grey.shade100,
                foregroundColor: isSelected ? Colors.white : Colors.black54,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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

  Color _getColorFromHex(String hexColor) {
    hexColor = hexColor.replaceAll("#", "");
    if (hexColor.length == 6) {
      hexColor = "FF$hexColor";
    }
    return Color(int.parse(hexColor, radix: 16));
  }

  Widget _buildInformationList() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
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
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _refreshInformation,
              child: const Text('Try Again'),
            ),
          ],
        ),
      );
    }

    final unreadCount = _filteredItems.where((item) => !item.isRead).length;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_filteredItems.length} items • $unreadCount unread',
                style: const TextStyle(
                  color: Colors.black54,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        
        Expanded(
          child: _filteredItems.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 16),
                  itemCount: _filteredItems.length,
                  itemBuilder: (context, index) {
                    final item = _filteredItems[index];
                    return _buildInfoListItem(item, index);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.info_outline,
          size: 70,
          color: Colors.grey.shade400,
        ),
        const SizedBox(height: 20),
        const Text(
          'No information found',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 8),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            'Try adjusting your search or filter to find what you\'re looking for',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.black45,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoListItem(InformationItem item, int index) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: item.isRead ? Colors.white : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.shade200,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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
            _openInfoDetail(item, index);
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
                    decoration: const BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                    ),
                  )
                else
                  const SizedBox(width: 20),
                
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getColorFromHex(item.categoryColor).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          item.category,
                          style: TextStyle(
                            color: _getColorFromHex(item.categoryColor),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 8),
                      
                      Text(
                        item.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: item.isRead ? FontWeight.w500 : FontWeight.w700,
                          color: Colors.black87,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      
                      const SizedBox(height: 8),
                      
                      Text(
                        item.preview, // This should now be clean text without HTML
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black54,
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      
                      const SizedBox(height: 12),
                      
                      Text(
                        item.date,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black45,
                        ),
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

  void _openInfoDetail(InformationItem item, int index) {
    // Mark as read immediately when opened
    _markAsRead(item.id);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => InfoDetailScreen(
          infoItem: item,
        ),
      ),
    );
  }
}

// class InfoDetailScreen extends StatelessWidget {
//   final InformationItem infoItem;

//   const InfoDetailScreen({
//     super.key,
//     required this.infoItem,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.white,
//       appBar: AppBar(
//         backgroundColor: Colors.white,
//         elevation: 0.5,
//         leading: IconButton(
//           icon: const Icon(Icons.arrow_back, color: Colors.black),
//           onPressed: () => Navigator.pop(context),
//         ),
//         title: const Text(
//           'Information',
//           style: TextStyle(
//             color: Colors.black,
//             fontWeight: FontWeight.w600,
//           ),
//         ),
//       ),
//       body: SingleChildScrollView(
//         padding: const EdgeInsets.all(20),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Container(
//               padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//               decoration: BoxDecoration(
//                 color: _getColorFromHex(infoItem.categoryColor).withOpacity(0.1),
//                 borderRadius: BorderRadius.circular(8),
//               ),
//               child: Text(
//                 infoItem.category,
//                 style: TextStyle(
//                   color: _getColorFromHex(infoItem.categoryColor),
//                   fontSize: 14,
//                   fontWeight: FontWeight.w600,
//                 ),
//               ),
//             ),
            
//             const SizedBox(height: 16),
            
//             Text(
//               infoItem.title,
//               style: const TextStyle(
//                 fontSize: 24,
//                 fontWeight: FontWeight.w700,
//                 color: Colors.black87,
//                 height: 1.3,
//               ),
//             ),
            
//             const SizedBox(height: 12),
            
//             Row(
//               children: [
//                 const Icon(Icons.access_time, size: 16, color: Colors.grey),
//                 const SizedBox(width: 4),
//                 Text(
//                   infoItem.date,
//                   style: const TextStyle(
//                     color: Colors.grey,
//                     fontSize: 14,
//                   ),
//                 ),
//                 const SizedBox(width: 16),
//                 Icon(
//                   Icons.circle,
//                   size: 8,
//                   color: infoItem.isRead ? Colors.green : Colors.blue,
//                 ),
//                 const SizedBox(width: 4),
//                 Text(
//                   infoItem.isRead ? 'Read' : 'Unread',
//                   style: const TextStyle(
//                     color: Colors.grey,
//                     fontSize: 14,
//                   ),
//                 ),
//               ],
//             ),
            
//             const SizedBox(height: 24),
            
//             // This will show the full HTML content WITH images
//             _buildHtmlContent(infoItem.content, context),
            
//             const SizedBox(height: 40),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildHtmlContent(String content, BuildContext context) {
//     if (content.isEmpty) {
//       return const Padding(
//         padding: EdgeInsets.symmetric(vertical: 20),
//         child: Text(
//           'No content available',
//           style: TextStyle(
//             fontSize: 16,
//             color: Colors.grey,
//             fontStyle: FontStyle.italic,
//           ),
//         ),
//       );
//     }

//     // Process the content to fix image URLs
//     String processedContent = _processImageUrls(content);

//     return Html(
//       data: processedContent,
//       style: {
//         "body": Style(
//           fontSize: FontSize(16.0),
//           lineHeight: LineHeight(1.6),
//           color: Colors.black87,
//         ),
//         "p": Style(
//           fontSize: FontSize(16.0),
//           lineHeight: LineHeight(1.6),
//           margin: Margins.only(bottom: 16),
//         ),
//         "h1": Style(
//           fontSize: FontSize(22.0),
//           fontWeight: FontWeight.bold,
//           margin: Margins.only(top: 24, bottom: 16),
//         ),
//         "h2": Style(
//           fontSize: FontSize(20.0),
//           fontWeight: FontWeight.bold,
//           margin: Margins.only(top: 20, bottom: 12),
//         ),
//         "h3": Style(
//           fontSize: FontSize(18.0),
//           fontWeight: FontWeight.bold,
//           margin: Margins.only(top: 16, bottom: 12),
//         ),
//         "ul": Style(
//           margin: Margins.only(bottom: 16),
//         ),
//         "ol": Style(
//           margin: Margins.only(bottom: 16),
//         ),
//         "li": Style(
//           fontSize: FontSize(16.0),
//           lineHeight: LineHeight(1.6),
//           margin: Margins.only(bottom: 8),
//         ),
//         "strong": Style(
//           fontWeight: FontWeight.bold,
//         ),
//         "em": Style(
//           fontStyle: FontStyle.italic,
//         ),
//         "img": Style(
//           margin: Margins.symmetric(vertical: 16),
//           alignment: Alignment.center,
//           width: Width(MediaQuery.of(context).size.width - 40),
//         ),
//       },
//     );
//   }

//   String _processImageUrls(String content) {
//     // Convert relative image URLs to absolute URLs
//     return content.replaceAllMapped(
//       RegExp(r'src="(/[^"]*)"'),
//       (Match match) {
//         String relativePath = match.group(1)!;
//         String fullUrl = '${ApiEndpoints.baseUrl}$relativePath';
//         return 'src="$fullUrl"';
//       },
//     );
//   }

//   Color _getColorFromHex(String hexColor) {
//     hexColor = hexColor.replaceAll("#", "");
//     if (hexColor.length == 6) {
//       hexColor = "FF$hexColor";
//     }
//     return Color(int.parse(hexColor, radix: 16));
//   }
// }

class InfoDetailScreen extends StatefulWidget {
  final InformationItem infoItem;

  const InfoDetailScreen({
    super.key,
    required this.infoItem,
  });

  @override
  State<InfoDetailScreen> createState() => _InfoDetailScreenState();
}

// class _InfoDetailScreenState extends State<InfoDetailScreen> {
//   List<Widget> _contentWidgets = [];
//   bool _isProcessingContent = true;

//   @override
//   void initState() {
//     super.initState();
//     _processContent();
//   }

//   void _processContent() {
//     final content = widget.infoItem.content;
//     if (content.isEmpty) {
//       setState(() {
//         _isProcessingContent = false;
//       });
//       return;
//     }

//     // Simple HTML parsing to extract text and images
//     final widgets = <Widget>[];
//     final lines = content.split('\n');
    
//     for (final line in lines) {
//       if (line.trim().isEmpty) continue;
      
//       // Check if line contains an image
//       if (line.contains('<img')) {
//         final imageUrls = _extractImageUrls(line);
//         for (final imageUrl in imageUrls) {
//           widgets.add(
//             Container(
//               margin: const EdgeInsets.symmetric(vertical: 16),
//               child: _buildNetworkImage(imageUrl),
//             ),
//           );
//         }
        
//         // Also add any text that might be in the same line
//         final textContent = _extractTextFromLine(line);
//         if (textContent.isNotEmpty) {
//           widgets.add(
//             Padding(
//               padding: const EdgeInsets.only(bottom: 16),
//               child: Text(
//                 textContent,
//                 style: const TextStyle(
//                   fontSize: 16,
//                   height: 1.6,
//                   color: Colors.black87,
//                 ),
//               ),
//             ),
//           );
//         }
//       } else {
//         // Regular text line
//         final cleanText = _cleanHtmlText(line);
//         if (cleanText.isNotEmpty) {
//           widgets.add(
//             Padding(
//               padding: const EdgeInsets.only(bottom: 16),
//               child: Text(
//                 cleanText,
//                 style: const TextStyle(
//                   fontSize: 16,
//                   height: 1.6,
//                   color: Colors.black87,
//                 ),
//               ),
//             ),
//           );
//         }
//       }
//     }

//     setState(() {
//       _contentWidgets = widgets;
//       _isProcessingContent = false;
//     });
//   }

//   List<String> _extractImageUrls(String html) {
//     final urls = <String>[];
//     final regex = RegExp(r'src="([^"]*)"');
//     final matches = regex.allMatches(html);
    
//     for (final match in matches) {
//       String url = match.group(1)!;
//       // Convert relative URLs to absolute URLs
//       if (url.startsWith('/')) {
//         url = '${ApiEndpoints.baseUrl}$url';
//       }
//       urls.add(url);
//     }
    
//     return urls;
//   }

//   String _extractTextFromLine(String html) {
//     // Remove image tags and get the remaining text
//     return html.replaceAll(RegExp(r'<img[^>]*>'), '').trim();
//   }

//   String _cleanHtmlText(String html) {
//     // Basic HTML tag removal
//     return html
//         .replaceAll(RegExp(r'<[^>]*>'), '')
//         .replaceAll('&nbsp;', ' ')
//         .replaceAll('&amp;', '&')
//         .replaceAll('&lt;', '<')
//         .replaceAll('&gt;', '>')
//         .replaceAll('&quot;', '"')
//         .replaceAll('&#39;', "'")
//         .trim();
//   }

//   Widget _buildNetworkImage(String imageUrl) {
//     return Container(
//       width: double.infinity,
//       constraints: const BoxConstraints(
//         maxHeight: 400,
//       ),
//       child: Image.network(
//         imageUrl,
//         fit: BoxFit.contain,
//         loadingBuilder: (context, child, loadingProgress) {
//           if (loadingProgress == null) return child;
//           return Container(
//             height: 200,
//             color: Colors.grey[200],
//             child: Center(
//               child: CircularProgressIndicator(
//                 value: loadingProgress.expectedTotalBytes != null
//                     ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
//                     : null,
//               ),
//             ),
//           );
//         },
//         errorBuilder: (context, error, stackTrace) {
//           print('Image load error: $error - URL: $imageUrl');
//           return Container(
//             height: 200,
//             color: Colors.grey[200],
//             child: Column(
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: [
//                 const Icon(Icons.broken_image, color: Colors.grey, size: 50),
//                 const SizedBox(height: 8),
//                 const Text(
//                   'Failed to load image',
//                   style: TextStyle(color: Colors.grey),
//                 ),
//                 const SizedBox(height: 4),
//                 Text(
//                   'URL: ${Uri.parse(imageUrl).path}',
//                   style: const TextStyle(color: Colors.grey, fontSize: 10),
//                   textAlign: TextAlign.center,
//                   maxLines: 2,
//                   overflow: TextOverflow.ellipsis,
//                 ),
//               ],
//             ),
//           );
//         },
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.white,
//       appBar: AppBar(
//         backgroundColor: Colors.white,
//         elevation: 0.5,
//         leading: IconButton(
//           icon: const Icon(Icons.arrow_back, color: Colors.black),
//           onPressed: () => Navigator.pop(context),
//         ),
//         title: const Text(
//           'Information',
//           style: TextStyle(
//             color: Colors.black,
//             fontWeight: FontWeight.w600,
//           ),
//         ),
//       ),
//       body: _isProcessingContent
//           ? const Center(
//               child: CircularProgressIndicator(),
//             )
//           : SingleChildScrollView(
//               padding: const EdgeInsets.all(20),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Container(
//                     padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//                     decoration: BoxDecoration(
//                       color: _getColorFromHex(widget.infoItem.categoryColor).withOpacity(0.1),
//                       borderRadius: BorderRadius.circular(8),
//                     ),
//                     child: Text(
//                       widget.infoItem.category,
//                       style: TextStyle(
//                         color: _getColorFromHex(widget.infoItem.categoryColor),
//                         fontSize: 14,
//                         fontWeight: FontWeight.w600,
//                       ),
//                     ),
//                   ),
                  
//                   const SizedBox(height: 16),
                  
//                   Text(
//                     widget.infoItem.title,
//                     style: const TextStyle(
//                       fontSize: 24,
//                       fontWeight: FontWeight.w700,
//                       color: Colors.black87,
//                       height: 1.3,
//                     ),
//                   ),
                  
//                   const SizedBox(height: 12),
                  
//                   Row(
//                     children: [
//                       const Icon(Icons.access_time, size: 16, color: Colors.grey),
//                       const SizedBox(width: 4),
//                       Text(
//                         widget.infoItem.date,
//                         style: const TextStyle(
//                           color: Colors.grey,
//                           fontSize: 14,
//                         ),
//                       ),
//                       const SizedBox(width: 16),
//                       Icon(
//                         Icons.circle,
//                         size: 8,
//                         color: widget.infoItem.isRead ? Colors.green : Colors.blue,
//                       ),
//                       const SizedBox(width: 4),
//                       Text(
//                         widget.infoItem.isRead ? 'Read' : 'Unread',
//                         style: const TextStyle(
//                           color: Colors.grey,
//                           fontSize: 14,
//                         ),
//                       ),
//                     ],
//                   ),
                  
//                   const SizedBox(height: 24),
                  
//                   // Display processed content
//                   ..._contentWidgets,
                  
//                   const SizedBox(height: 40),
//                 ],
//               ),
//             ),
//     );
//   }

//   Color _getColorFromHex(String hexColor) {
//     hexColor = hexColor.replaceAll("#", "");
//     if (hexColor.length == 6) {
//       hexColor = "FF$hexColor";
//     }
//     return Color(int.parse(hexColor, radix: 16));
//   }
// }


class _InfoDetailScreenState extends State<InfoDetailScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Information',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _getColorFromHex(widget.infoItem.categoryColor).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                widget.infoItem.category,
                style: TextStyle(
                  color: _getColorFromHex(widget.infoItem.categoryColor),
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
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                  ),
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
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Use flutter_html to properly render the CKEditor content
            _buildHtmlContent(widget.infoItem.content),
            
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // Widget _buildHtmlContent(String content) {
  //   if (content.isEmpty) {
  //     return const Padding(
  //       padding: EdgeInsets.symmetric(vertical: 20),
  //       child: Text(
  //         'No content available',
  //         style: TextStyle(
  //           fontSize: 16,
  //           color: Colors.grey,
  //           fontStyle: FontStyle.italic,
  //         ),
  //       ),
  //     );
  //   }

  //   // Process the content to fix image URLs
  //   String processedContent = _processImageUrls(content);

  //   return Html(
  //     data: processedContent,
  //     style: {
  //       "body": Style(
  //         fontSize: FontSize(16.0),
  //         lineHeight: LineHeight(1.6),
  //         color: Colors.black87,
  //         margin: Margins.zero,
  //         padding: HtmlPaddings.zero,
  //       ),
  //       "p": Style(
  //         fontSize: FontSize(16.0),
  //         lineHeight: LineHeight(1.6),
  //         margin: Margins.only(bottom: 16),
  //       ),
  //       "h1": Style(
  //         fontSize: FontSize(22.0),
  //         fontWeight: FontWeight.bold,
  //         margin: Margins.only(top: 24, bottom: 16),
  //       ),
  //       "h2": Style(
  //         fontSize: FontSize(20.0),
  //         fontWeight: FontWeight.bold,
  //         margin: Margins.only(top: 20, bottom: 12),
  //       ),
  //       "h3": Style(
  //         fontSize: FontSize(18.0),
  //         fontWeight: FontWeight.bold,
  //         margin: Margins.only(top: 16, bottom: 12),
  //       ),
  //       "ul": Style(
  //         margin: Margins.only(bottom: 16),
  //       ),
  //       "ol": Style(
  //         margin: Margins.only(bottom: 16),
  //       ),
  //       "li": Style(
  //         fontSize: FontSize(16.0),
  //         lineHeight: LineHeight(1.6),
  //         margin: Margins.only(bottom: 8),
  //       ),
  //       "strong": Style(
  //         fontWeight: FontWeight.bold,
  //       ),
  //       "em": Style(
  //         fontStyle: FontStyle.italic,
  //       ),
  //       "img": Style(
  //         margin: Margins.symmetric(vertical: 16),
  //         alignment: Alignment.center,
  //       ),
  //     },
  //   );
  // }

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

  // Process the content to fix image URLs
  String processedContent = _processImageUrls(content);

  // Add CSS to center images
  processedContent = '''
    <style>
      img { 
        display: block; 
        margin-left: auto; 
        margin-right: auto; 
        max-width: 100%; 
        height: auto;
      }
    </style>
    $processedContent
  ''';

  return Html(
    data: processedContent,
    style: {
      "body": Style(
        fontSize: FontSize(16.0),
        lineHeight: LineHeight(1.6),
        color: Colors.black87,
        margin: Margins.zero,
        padding: HtmlPaddings.zero,
        textAlign: TextAlign.justify,
      ),
      "p": Style(
        fontSize: FontSize(16.0),
        lineHeight: LineHeight(1.6),
        margin: Margins.only(bottom: 16),
        textAlign: TextAlign.justify,
      ),
      "h1": Style(
        fontSize: FontSize(22.0),
        fontWeight: FontWeight.bold,
        margin: Margins.only(top: 24, bottom: 16),
        textAlign: TextAlign.start,
      ),
      "h2": Style(
        fontSize: FontSize(20.0),
        fontWeight: FontWeight.bold,
        margin: Margins.only(top: 20, bottom: 12),
        textAlign: TextAlign.start,
      ),
      "h3": Style(
        fontSize: FontSize(18.0),
        fontWeight: FontWeight.bold,
        margin: Margins.only(top: 16, bottom: 12),
        textAlign: TextAlign.start,
      ),
      "ul": Style(
        margin: Margins.only(bottom: 16),
      ),
      "ol": Style(
        margin: Margins.only(bottom: 16),
      ),
      "li": Style(
        fontSize: FontSize(16.0),
        lineHeight: LineHeight(1.6),
        margin: Margins.only(bottom: 8),
        textAlign: TextAlign.justify,
      ),
      "strong": Style(
        fontWeight: FontWeight.bold,
      ),
      "em": Style(
        fontStyle: FontStyle.italic,
      ),
    },
  );
}
  // ///

  String _processImageUrls(String content) {
    // Convert relative image URLs to absolute URLs
    return content.replaceAllMapped(
      RegExp(r'src="(/[^"]*)"'),
      (Match match) {
        String relativePath = match.group(1)!;
        String fullUrl = '${ApiEndpoints.baseUrl}$relativePath';
        return 'src="$fullUrl"';
      },
    );
  }

  Color _getColorFromHex(String hexColor) {
    hexColor = hexColor.replaceAll("#", "");
    if (hexColor.length == 6) {
      hexColor = "FF$hexColor";
    }
    return Color(int.parse(hexColor, radix: 16));
  }
}