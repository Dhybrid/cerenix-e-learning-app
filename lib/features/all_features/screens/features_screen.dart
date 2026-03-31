import 'package:flutter/material.dart';
import '../../../core/widgets/custom_app_bar.dart';
import '../../../core/widgets/custom_drawer.dart';

class FeaturesScreen extends StatefulWidget {
  const FeaturesScreen({super.key});

  @override
  State<FeaturesScreen> createState() => _FeaturesScreenState();
}

class _FeaturesScreenState extends State<FeaturesScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // List of all features with their properties
  final List<Map<String, dynamic>> _features = [
    {
      'title': 'Courses',
      'icon': Icons.book,
      'color': const Color(0xFF0077B6),
      'route': '/courses',
      'hasImage': true,
    },
    {
      'title': 'CGPA Calculator',
      'icon': Icons.calculate,
      'color': const Color(0xFF00B894),
      'route': '/cgpa',
      'hasImage': true,
    },
    {
      'title': 'Past Questions',
      'icon': Icons.history_edu,
      'color': const Color(0xFF6C5CE7),
      'route': '/past-questions',
      'hasImage': true,
    },
    {
      'title': 'Scan Documents',
      'icon': Icons.document_scanner,
      'color': const Color(0xFFFD79A8),
      'route': '/coming-soon',
      'hasImage': true,
    },
    {
      'title': 'Cereva GPT',
      'icon': Icons.smart_toy,
      'color': const Color(0xFF00CEC9),
      'route': '/gpt',
      'hasImage': false,
    },
    {
      'title': 'Learning Board',
      'icon': Icons.dashboard,
      'color': const Color(0xFFFDCB6E),
      'route': '/ai-board',
      'hasImage': false,
    },
    {
      'title': 'Read and Study Documents',
      'icon': Icons.article,
      'color': const Color(0xFFE17055),
      'route': '/study-guide',
      'hasImage': false,
    },
    {
      'title': 'Alarm Calendar',
      'icon': Icons.alarm,
      'color': const Color(0xFFA29BFE),
      'route': '/coming-soon',
      'hasImage': false,
    },

    // {
    //   'title': 'AI Features',
    //   'icon': Icons.alarm,
    //   'color': const Color.fromARGB(255, 195, 86, 8),
    //   'route': '/ai-home',
    //   'hasImage': false,
    // },
    // ADD MORE FEATURES HERE - Just copy the format above
    // {
    //   'title': 'Feature Name',
    //   'icon': Icons.icon_name,
    //   'color': const Color(0xFFHEXCODE),
    //   'route': '/route-name',
    //   'hasImage': false,
    // },
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: isDark
          ? const Color(0xFF09111F)
          : const Color(0xFFF8FAFC),
      appBar: CustomAppBar(
        scaffoldKey: _scaffoldKey,
        title: 'Features',
        showNotifications: false,
        showProfile: true,
      ),
      drawer: const CustomDrawer(),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Advert Board
            _buildAdvertBoard(),

            // Features Heading
            _buildFeaturesHeading(),

            // Features Grid
            _buildFeaturesGrid(),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildAdvertBoard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 120, // Small height as requested
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xFF0077B6),
        image: const DecorationImage(
          image: AssetImage(
            'assets/images/courseboard.png',
          ), // Your advert image
          fit: BoxFit.cover,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.bottomRight,
            end: Alignment.topLeft,
            colors: [
              Colors.black.withValues(alpha: isDark ? 0.48 : 0.30),
              Colors.transparent,
            ],
          ),
        ),
        child: const Center(
          child: Text(
            'Discover Amazing Features',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeaturesHeading() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Text(
        'Features',
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF1A1A2E),
        ),
      ),
    );
  }

  Widget _buildFeaturesGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, // Two items horizontally
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.1, // Slightly rectangular cards
        ),
        itemCount: _features.length,
        itemBuilder: (context, index) {
          final feature = _features[index];
          return _buildFeatureCard(feature);
        },
      ),
    );
  }

  Widget _buildFeatureCard(Map<String, dynamic> feature) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF101A2B) : Colors.white;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : const Color(0xFFE2E8F0);
    final titleColor = isDark
        ? const Color(0xFFF8FAFC)
        : const Color(0xFF1A1A2E);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.pushNamed(context, feature['route']),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.10),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Background Image or Color
              if (feature['hasImage'] as bool)
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.asset(
                    'assets/images/${feature['title'].toString().toLowerCase().replaceAll(' ', '_')}.png',
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    errorBuilder: (_, __, ___) => Container(
                      color: (feature['color'] as Color).withValues(alpha: 0.1),
                    ),
                  ),
                )
              else
                Container(
                  decoration: BoxDecoration(
                    color: (feature['color'] as Color).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),

              // Content
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Icon with separate background (top right)
                    Align(
                      alignment: Alignment.topRight,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF162235).withValues(alpha: 0.92)
                              : Colors.white.withValues(alpha: 0.92),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(
                                alpha: isDark ? 0.24 : 0.10,
                              ),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          feature['icon'] as IconData,
                          color: feature['color'] as Color,
                          size: 20,
                        ),
                      ),
                    ),

                    // Feature Title
                    Text(
                      feature['title'] as String,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: titleColor,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
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
