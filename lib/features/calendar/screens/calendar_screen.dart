// lib/features/calendar/screens/calendar_timer_screen.dart
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';

class CalendarTimerScreen extends StatefulWidget {
  const CalendarTimerScreen({super.key});

  @override
  State<CalendarTimerScreen> createState() => _CalendarTimerScreenState();
}

class _CalendarTimerScreenState extends State<CalendarTimerScreen> {
  // Calendar variables
  CalendarFormat _calendarFormat = CalendarFormat.week;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  
  // Timer variables
  final TextEditingController _timerTitleController = TextEditingController();
  TimeOfDay _selectedTime = TimeOfDay.now();
  Color _selectedColor = Colors.blue;
  final List<TimerItem> _timers = [];

  // Available colors for timer
  final List<Color> _availableColors = [
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.red,
    Colors.teal,
    Colors.pink,
    Colors.indigo,
  ];

  // Error state for add timer dialog
  String? _addTimerError;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _startTimerUpdates();
  }

  void _startTimerUpdates() {
    // Update timers every second for countdown
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {});
        _startTimerUpdates();
      }
    });
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    setState(() {
      _selectedDay = selectedDay;
      _focusedDay = focusedDay;
    });
  }

  void _showAddTimerDialog() {
    _timerTitleController.clear();
    _selectedTime = TimeOfDay.now();
    _selectedColor = Colors.blue;
    _addTimerError = null;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildAddTimerSheet(),
    ).then((_) {
      // Clear error when dialog is closed
      _addTimerError = null;
    });
  }

  void _addTimer() {
    // Clear previous errors
    setState(() {
      _addTimerError = null;
    });

    if (_timerTitleController.text.isEmpty) {
      setState(() {
        _addTimerError = 'Please enter a timer title';
      });
      return;
    }

    // Check if selected time is in the past
    final selectedDateTime = DateTime(
      _selectedDay!.year,
      _selectedDay!.month,
      _selectedDay!.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );
    final nowDateTime = DateTime.now();

    if (selectedDateTime.isBefore(nowDateTime)) {
      setState(() {
        _addTimerError = 'Cannot set timer for past time!';
      });
      return;
    }

    final newTimer = TimerItem(
      id: DateTime.now().millisecondsSinceEpoch,
      title: _timerTitleController.text,
      time: _selectedTime,
      color: _selectedColor,
      date: _selectedDay!,
      isActive: true,
    );

    setState(() {
      _timers.add(newTimer);
    });

    _timerTitleController.clear();
    Navigator.pop(context);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Timer added successfully!'),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
      ),
    );

    // Schedule alarm
    _scheduleAlarm(newTimer);
  }

  void _scheduleAlarm(TimerItem timer) {
    final timerDateTime = DateTime(
      timer.date.year,
      timer.date.month,
      timer.date.day,
      timer.time.hour,
      timer.time.minute,
    );
    
    final now = DateTime.now();
    final difference = timerDateTime.difference(now);
    
    if (difference.inSeconds > 0) {
      // In real app, you'd use Workmanager to schedule background task
      // Workmanager().registerOneShot(
      //   "alarm-${timer.id}",
      //   "alarm_task",
      //   initialDelay: difference,
      //   inputData: {'timerId': timer.id, 'title': timer.title},
      // );
      
      print('Alarm scheduled for ${timer.title} at ${timer.time.format(context)}');
    }
  }

  void _showAlarmNotification(TimerItem timer) {
    // This should be called from background task
    // For now, we'll show a simple dialog
    _showAlarmDialog(timer);
  }

  void _showAlarmDialog(TimerItem timer) {
    // Use a delayed future to avoid setState during build
    Future.delayed(Duration.zero, () {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.alarm, color: Colors.red),
              SizedBox(width: 8),
              Text('Timer Alert!'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                timer.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text('Time: ${timer.time.format(context)}'),
              Text('Date: ${DateFormat('MMM d, yyyy').format(timer.date)}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Dismiss'),
            ),
          ],
        ),
      );
    });
  }

  void _editTimer(TimerItem timer) {
    _timerTitleController.text = timer.title;
    _selectedTime = timer.time;
    _selectedColor = timer.color;
    _addTimerError = null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildAddTimerSheet(isEditing: true, timer: timer),
    ).then((_) {
      // Clear error when dialog is closed
      _addTimerError = null;
    });
  }

  void _updateTimer(TimerItem oldTimer) {
    setState(() {
      _addTimerError = null;
    });

    if (_timerTitleController.text.isEmpty) {
      setState(() {
        _addTimerError = 'Please enter a timer title';
      });
      return;
    }

    // Check if selected time is in the past
    final selectedDateTime = DateTime(
      _selectedDay!.year,
      _selectedDay!.month,
      _selectedDay!.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );
    final nowDateTime = DateTime.now();

    if (selectedDateTime.isBefore(nowDateTime)) {
      setState(() {
        _addTimerError = 'Cannot set timer for past time!';
      });
      return;
    }

    final updatedTimer = TimerItem(
      id: oldTimer.id,
      title: _timerTitleController.text,
      time: _selectedTime,
      color: _selectedColor,
      date: _selectedDay!,
      isActive: true,
    );

    setState(() {
      final index = _timers.indexWhere((t) => t.id == oldTimer.id);
      if (index != -1) {
        _timers[index] = updatedTimer;
      }
    });

    _timerTitleController.clear();
    Navigator.pop(context);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Timer updated successfully!'),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
      ),
    );

    // Reschedule alarm
    _scheduleAlarm(updatedTimer);
  }

  void _deleteTimer(TimerItem timer) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Timer'),
        content: const Text('Are you sure you want to delete this timer?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _timers.removeWhere((t) => t.id == timer.id);
              });
              Navigator.pop(context);
              
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Timer deleted'),
                  backgroundColor: Colors.red.shade600,
                  behavior: SnackBarBehavior.floating,
                ),
              );
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

  List<TimerItem> _getTimersForSelectedDay() {
    return _timers.where((timer) => 
      timer.date.year == _selectedDay!.year &&
      timer.date.month == _selectedDay!.month &&
      timer.date.day == _selectedDay!.day
    ).toList();
  }

  String _getTimeRemaining(TimerItem timer) {
    final now = DateTime.now();
    final timerDateTime = DateTime(
      timer.date.year,
      timer.date.month,
      timer.date.day,
      timer.time.hour,
      timer.time.minute,
    );
    
    if (timerDateTime.isBefore(now)) {
      // Check if it's time to show alarm (within 10 seconds of target time)
      final timeSinceTarget = now.difference(timerDateTime).inSeconds;
      if (timeSinceTarget >= 0 && timeSinceTarget <= 10) {
        // Show alarm only once to avoid multiple dialogs
        if (!timer.hasShownAlarm) {
          timer.hasShownAlarm = true;
          _showAlarmDialog(timer);
        }
      }
      return 'Time\'s up!';
    }
    
    final difference = timerDateTime.difference(now);
    if (difference.inDays > 0) {
      return '${difference.inDays}d ${difference.inHours.remainder(24)}h ${difference.inMinutes.remainder(60)}m';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ${difference.inMinutes.remainder(60)}m';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ${difference.inSeconds.remainder(60)}s';
    } else {
      return '${difference.inSeconds}s';
    }
  }

  bool _isTimerExpired(TimerItem timer) {
    final now = DateTime.now();
    final timerDateTime = DateTime(
      timer.date.year,
      timer.date.month,
      timer.date.day,
      timer.time.hour,
      timer.time.minute,
    );
    return timerDateTime.isBefore(now);
  }

  @override
  Widget build(BuildContext context) {
    final selectedDayTimers = _getTimersForSelectedDay();
    final screenHeight = MediaQuery.of(context).size.height;
    
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Header Section (Black) - Fixed height
            _buildHeaderSection(),
            
            // Calendar Section (Black) - Adjust height here: change 0.35 to your desired value
            SizedBox(
              height: screenHeight * 0.25, // ← CHANGE THIS VALUE: 0.3 = 30%, 0.4 = 40%, etc.
              child: _buildCalendarSection(),
            ),
            
            // Timer Section (White with curved top)
            Expanded(
              child: _buildTimerSection(selectedDayTimers),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
          const Text(
            'Timer & Calendar',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarSection() {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // Single month/year navigation
          _buildMonthNavigation(),
          const SizedBox(height: 8),
          
          // Calendar
          Expanded(
            child: TableCalendar(
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              onDaySelected: _onDaySelected,
              onPageChanged: (focusedDay) {
                setState(() => _focusedDay = focusedDay);
              },
              calendarFormat: _calendarFormat,
              onFormatChanged: (format) {
                setState(() => _calendarFormat = format);
              },
              
              // Styling - Hide built-in header
              headerStyle: const HeaderStyle(
                formatButtonVisible: false,
                titleCentered: false,
                headerPadding: EdgeInsets.zero,
                leftChevronVisible: false,
                rightChevronVisible: false,
                titleTextStyle: TextStyle(fontSize: 0),
              ),
              daysOfWeekStyle: const DaysOfWeekStyle(
                weekdayStyle: TextStyle(color: Colors.white70, fontWeight: FontWeight.w500, fontSize: 12),
                weekendStyle: TextStyle(color: Colors.white70, fontWeight: FontWeight.w500, fontSize: 12),
              ),
              calendarStyle: CalendarStyle(
                defaultTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 12),
                weekendTextStyle: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w500, fontSize: 12),
                selectedTextStyle: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12),
                todayTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                todayDecoration: BoxDecoration(
                  color: Colors.transparent,
                  border: Border.all(color: Colors.blue, width: 1.5),
                  shape: BoxShape.circle,
                ),
                selectedDecoration: BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                ),
                outsideTextStyle: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w500, fontSize: 11),
                cellPadding: const EdgeInsets.all(4),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthNavigation() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, color: Colors.white, size: 28),
            onPressed: () {
              setState(() {
                if (_calendarFormat == CalendarFormat.week) {
                  _focusedDay = _focusedDay.subtract(const Duration(days: 7));
                } else {
                  _focusedDay = DateTime(_focusedDay.year, _focusedDay.month - 1);
                }
              });
            },
          ),
          GestureDetector(
            onTap: () {
              _showMonthYearPicker();
            },
            child: Text(
              DateFormat('MMMM yyyy').format(_focusedDay),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, color: Colors.white, size: 28),
            onPressed: () {
              setState(() {
                if (_calendarFormat == CalendarFormat.week) {
                  _focusedDay = _focusedDay.add(const Duration(days: 7));
                } else {
                  _focusedDay = DateTime(_focusedDay.year, _focusedDay.month + 1);
                }
              });
            },
          ),
        ],
      ),
    );
  }

  void _showMonthYearPicker() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _focusedDay,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDatePickerMode: DatePickerMode.year,
    );
    if (picked != null) {
      setState(() {
        _focusedDay = picked;
        _selectedDay = picked;
      });
    }
  }

  Widget _buildTimerSection(List<TimerItem> timers) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        children: [
          // Selected Date Header - ALWAYS SHOW THIS
          _buildSelectedDateHeader(),
          const SizedBox(height: 16),
          
          // Add Timer Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _showAddTimerDialog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade600,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                icon: const Icon(Icons.add, size: 20),
                label: const Text(
                  'Add New Timer',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Timers List or Empty State
          Expanded(
            child: timers.isEmpty
                ? _buildEmptyState()
                : _buildTimersList(timers),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedDateHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                DateFormat('EEEE').format(_selectedDay!),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
              Text(
                DateFormat('MMM d, yyyy').format(_selectedDay!),
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.chevron_left, color: Colors.grey.shade600, size: 24),
                onPressed: () {
                  setState(() {
                    _selectedDay = _selectedDay!.subtract(const Duration(days: 1));
                    _focusedDay = _selectedDay!;
                  });
                },
              ),
              IconButton(
                icon: Icon(Icons.chevron_right, color: Colors.grey.shade600, size: 24),
                onPressed: () {
                  setState(() {
                    _selectedDay = _selectedDay!.add(const Duration(days: 1));
                    _focusedDay = _selectedDay!;
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Padding(
      padding: EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.access_time_rounded,
            size: 70,
            color: Colors.grey,
          ),
          SizedBox(height: 16),
          Text(
            'No Timers Set',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Add a timer to get started',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTimersList(List<TimerItem> timers) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      itemCount: timers.length,
      itemBuilder: (context, index) {
        final timer = timers[index];
        return _buildTimerItem(timer);
      },
    );
  }

  Widget _buildTimerItem(TimerItem timer) {
    final timeRemaining = _getTimeRemaining(timer);
    final isExpired = _isTimerExpired(timer);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Time on left
          Container(
            width: 80,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  timer.time.format(context),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isExpired ? Colors.red : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  timeRemaining,
                  style: TextStyle(
                    fontSize: 11,
                    color: isExpired ? Colors.red : Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          
          // Colored rectangle with title and countdown
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: timer.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: timer.color.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          timer.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: timer.color,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Countdown: $timeRemaining',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert, color: timer.color, size: 20),
                    onSelected: (value) {
                      if (value == 'edit') {
                        _editTimer(timer);
                      } else if (value == 'delete') {
                        _deleteTimer(timer);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 18),
                            SizedBox(width: 8),
                            Text('Edit'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, size: 18, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Delete', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddTimerSheet({bool isEditing = false, TimerItem? timer}) {
    return StatefulBuilder(
      builder: (context, setSheetState) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(25),
              topRight: Radius.circular(25),
            ),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  isEditing ? 'Edit Timer' : 'Add New Timer',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 20),
                
                // Error Message - SHOWS IN THE DIALOG
                if (_addTimerError != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error, color: Colors.red.shade600, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _addTimerError!,
                            style: TextStyle(
                              color: Colors.red.shade700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (_addTimerError != null) const SizedBox(height: 16),
                
                // Timer Title
                TextFormField(
                  controller: _timerTitleController,
                  decoration: InputDecoration(
                    labelText: 'Timer Title',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.title),
                  ),
                ),
                const SizedBox(height: 20),
                
                // Time Picker
                ListTile(
                  leading: const Icon(Icons.access_time),
                  title: const Text('Select Time'),
                  subtitle: Text(_selectedTime.format(context)),
                  onTap: () async {
                    final TimeOfDay? pickedTime = await showTimePicker(
                      context: context,
                      initialTime: _selectedTime,
                    );
                    if (pickedTime != null) {
                      setSheetState(() {
                        _selectedTime = pickedTime;
                      });
                    }
                  },
                ),
                const SizedBox(height: 20),
                
                // Color Selection
                const Text(
                  'Select Color',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 60,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _availableColors.length,
                    itemBuilder: (context, index) {
                      final color = _availableColors[index];
                      final isSelected = _selectedColor == color;
                      
                      return GestureDetector(
                        onTap: () {
                          setSheetState(() {
                            _selectedColor = color;
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: isSelected ? 50 : 40,
                          height: isSelected ? 50 : 40,
                          margin: const EdgeInsets.symmetric(horizontal: 6),
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: isSelected
                                ? Border.all(color: Colors.white, width: 3)
                                : null,
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: color.withOpacity(0.6),
                                      blurRadius: 10,
                                      spreadRadius: 2,
                                    ),
                                  ]
                                : null,
                          ),
                          child: isSelected
                              ? const Icon(Icons.check, color: Colors.white, size: 24)
                              : null,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Selected: ${_selectedColor.value.toRadixString(16).toUpperCase()}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 30),
                
                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: isEditing 
                            ? () => _updateTimer(timer!)
                            : _addTimer,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _selectedColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          isEditing ? 'Update' : 'Add Timer',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }
}

class TimerItem {
  final int id;
  final String title;
  final TimeOfDay time;
  final Color color;
  final DateTime date;
  final bool isActive;
  bool hasShownAlarm;

  TimerItem({
    required this.id,
    required this.title,
    required this.time,
    required this.color,
    required this.date,
    required this.isActive,
    this.hasShownAlarm = false,
  });
}