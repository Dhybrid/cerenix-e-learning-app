// lib/features/notification/screens/notification_screen.dart
import 'package:flutter/material.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final List<NotificationItem> _notifications = [
    NotificationItem(
      id: '1',
      title: 'New Assignment Posted',
      message: 'CS101 - Introduction to Programming assignment has been posted. Due date: Dec 20, 2024',
      time: '10:30 AM',
      date: 'Today',
      isRead: false,
      type: 'Academic',
      details: '''
Assignment Details:
• Course: CS101 - Introduction to Programming
• Assignment: Project 3 - Data Structures
• Due Date: December 20, 2024, 11:59 PM
• Points: 100
• Submission: Via Student Portal

Requirements:
1. Implement a linked list data structure
2. Create sorting algorithms
3. Write comprehensive documentation
4. Submit source code and report

Late submissions will be penalized by 10% per day.
''',
    ),
    NotificationItem(
      id: '2',
      title: 'Grade Updated',
      message: 'Your grade for Mathematics 201 - Calculus II has been updated. Check your portal for details.',
      time: '9:15 AM',
      date: 'Today',
      isRead: false,
      type: 'Academic',
      details: '''
Grade Update Details:
• Course: Mathematics 201 - Calculus II
• Assignment: Final Exam
• Score: 88/100
• Grade: A-
• Class Average: 76/100

Performance Summary:
- Midterm: 85/100
- Assignments: 92/100
- Final Exam: 88/100
- Overall Grade: A-

Your work has shown consistent improvement throughout the semester. Well done!
''',
    ),
    NotificationItem(
      id: '3',
      title: 'Library Book Due Soon',
      message: 'Your borrowed book "Introduction to Algorithms" is due in 2 days. Please renew or return it.',
      time: 'Yesterday',
      date: 'Dec 14, 2024',
      isRead: true,
      type: 'Library',
      details: '''
Library Book Details:
• Book Title: Introduction to Algorithms
• Author: Thomas H. Cormen
• Borrowed Date: December 1, 2024
• Due Date: December 16, 2024
• Renewals Left: 2

Book Information:
- ISBN: 978-0262033848
- Edition: 3rd Edition
- Location: Main Library, Floor 2
- Shelf: QA76.6 .C662

You can renew this book online through the library portal or return it to any library counter.
''',
    ),
    NotificationItem(
      id: '4',
      title: 'Fee Payment Reminder',
      message: 'Spring 2025 semester fee payment deadline is approaching. Last date: January 15, 2025',
      time: 'Yesterday',
      date: 'Dec 14, 2024',
      isRead: true,
      type: 'Financial',
      details: '''
Fee Payment Details:
• Semester: Spring 2025
• Due Date: January 15, 2025
• Total Amount: \$4,500.00
• Payment Methods: Credit Card, Bank Transfer, Installments

Breakdown:
- Tuition Fee: \$3,800.00
- Library Fee: \$150.00
- Sports Facility: \$100.00
- Student Services: \$450.00

Important Notes:
• Late payment penalty: 5% of total amount
• Installment plan available upon request
• Contact financial office for assistance
''',
    ),
  ];

  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  NotificationItem? _selectedNotification;

  void _clearSearch() {
    setState(() {
      _searchController.clear();
      _isSearching = false;
    });
  }

  void _markAllAsRead() {
    setState(() {
      for (var notification in _notifications) {
        notification.isRead = true;
      }
    });
  }

  void _deleteNotification(int index) {
    setState(() {
      _notifications.removeAt(index);
    });
  }

  void _showNotificationDetails(NotificationItem notification) {
    setState(() {
      notification.isRead = true;
      _selectedNotification = notification;
    });
  }

  void _closeDetails() {
    setState(() {
      _selectedNotification = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _notifications.where((item) => !item.isRead).length;
    
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: _isSearching 
            ? _buildSearchField()
            : const Text(
                'Notifications',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w700,
                  fontSize: 20,
                ),
              ),
        centerTitle: false,
        actions: _buildAppBarActions(unreadCount),
      ),
      body: Stack(
        children: [
          // Main Notifications List
          GestureDetector(
            onTap: () {
              // Close keyboard when tapping outside
              if (_isSearching) {
                FocusScope.of(context).unfocus();
              }
            },
            child: Column(
              children: [
                // Simple header with mark all as read
                if (_notifications.isNotEmpty && !_isSearching)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '$unreadCount unread',
                          style: const TextStyle(
                            color: Colors.black54,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        GestureDetector(
                          onTap: _markAllAsRead,
                          child: const Text(
                            'Mark all as read',
                            style: TextStyle(
                              color: Colors.blue,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                
                // Notifications List
                Expanded(
                  child: _notifications.isEmpty
                      ? _buildEmptyState()
                      : _buildNotificationsList(),
                ),
              ],
            ),
          ),

          // Slide-up Detail Panel
          if (_selectedNotification != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildDetailPanel(_selectedNotification!),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      autofocus: true,
      decoration: InputDecoration(
        hintText: 'Search notifications...',
        border: InputBorder.none,
        hintStyle: TextStyle(color: Colors.grey.shade600),
        suffixIcon: IconButton(
          icon: const Icon(Icons.close, color: Colors.grey),
          onPressed: _clearSearch,
        ),
      ),
      style: const TextStyle(fontSize: 16),
      onTap: () {
        // Ensure cursor is at the end when tapping
        _searchController.selection = TextSelection.fromPosition(
          TextPosition(offset: _searchController.text.length),
        );
      },
    );
  }

  List<Widget> _buildAppBarActions(int unreadCount) {
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
        if (unreadCount > 0)
          IconButton(
            icon: const Icon(Icons.check_circle_outline, color: Colors.black54),
            onPressed: _markAllAsRead,
            tooltip: 'Mark all as read',
          ),
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

  Widget _buildNotificationsList() {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: _notifications.length,
      itemBuilder: (context, index) {
        final notification = _notifications[index];
        return _buildNotificationItem(notification, index);
      },
    );
  }

  Widget _buildNotificationItem(NotificationItem notification, int index) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: notification.isRead ? Colors.white : Colors.blue.shade50,
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
            _showNotificationDetails(notification);
          },
          onLongPress: () {
            _showDeleteDialog(index);
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Notification Icon based on type
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _getTypeColor(notification.type).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _getTypeIcon(notification.type),
                    color: _getTypeColor(notification.type),
                    size: 20,
                  ),
                ),
                
                const SizedBox(width: 12),
                
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title and Unread indicator
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              notification.title,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: notification.isRead ? FontWeight.w500 : FontWeight.w700,
                                color: Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (!notification.isRead)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Colors.blue,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      
                      const SizedBox(height: 4),
                      
                      // Message
                      Text(
                        notification.message,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black54,
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      
                      const SizedBox(height: 8),
                      
                      // Time and Type
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${notification.time} • ${notification.date}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black45,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: _getTypeColor(notification.type).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              notification.type,
                              style: TextStyle(
                                fontSize: 10,
                                color: _getTypeColor(notification.type),
                                fontWeight: FontWeight.w500,
                              ),
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

  Widget _buildDetailPanel(NotificationItem notification) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Header with close button
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  _getTypeIcon(notification.type),
                  color: _getTypeColor(notification.type),
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notification.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        '${notification.time} • ${notification.date}',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: _closeDetails,
                ),
              ],
            ),
          ),
          
          const Divider(height: 1),
          
          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Preview message
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      notification.message,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                        height: 1.4,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Detailed content
                  Text(
                    notification.details,
                    style: const TextStyle(
                      fontSize: 15,
                      color: Colors.black87,
                      height: 1.6,
                    ),
                  ),
                  
                  const SizedBox(height: 30),
                  
                  // Action buttons
                  // Row(
                  //   children: [
                  //     Expanded(
                  //       child: OutlinedButton(
                  //         onPressed: () {},
                  //         style: OutlinedButton.styleFrom(
                  //           padding: const EdgeInsets.symmetric(vertical: 12),
                  //           side: BorderSide(color: Colors.grey.shade300),
                  //         ),
                  //         child: const Text(
                  //           'View Related',
                  //           style: TextStyle(color: Colors.black54),
                  //         ),
                  //       ),
                  //     ),
                  //     const SizedBox(width: 12),
                  //     // Expanded(
                  //     //   child: ElevatedButton(
                  //     //     onPressed: () {},
                  //     //     style: ElevatedButton.styleFrom(
                  //     //       backgroundColor: _getTypeColor(notification.type),
                  //     //       padding: const EdgeInsets.symmetric(vertical: 12),
                  //     //     ),
                  //     //     child: const Text(
                  //     //       'Take Action',
                  //     //       style: TextStyle(color: Colors.white),
                  //     //     ),
                  //     //   ),
                  //     // ),
                  //   ],
                  // ),

                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.notifications_none,
          size: 70,
          color: Colors.grey.shade400,
        ),
        const SizedBox(height: 20),
        const Text(
          'No notifications',
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
            'You\'re all caught up! New notifications will appear here',
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

  void _showDeleteDialog(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Notification'),
        content: const Text('Are you sure you want to delete this notification?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              _deleteNotification(index);
              Navigator.pop(context);
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'Academic':
        return Icons.school;
      case 'Library':
        return Icons.library_books;
      case 'Financial':
        return Icons.payment;
      case 'Event':
        return Icons.event;
      case 'System':
        return Icons.settings;
      default:
        return Icons.notifications;
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'Academic':
        return Colors.blue;
      case 'Library':
        return Colors.green;
      case 'Financial':
        return Colors.orange;
      case 'Event':
        return Colors.purple;
      case 'System':
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }
}

class NotificationItem {
  final String id;
  final String title;
  final String message;
  final String time;
  final String date;
  bool isRead;
  final String type;
  final String details;

  NotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.time,
    required this.date,
    required this.isRead,
    required this.type,
    required this.details,
  });
}