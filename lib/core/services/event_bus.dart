// lib/core/services/event_bus.dart
import 'package:event_bus/event_bus.dart';

class EventBusService {
  static final EventBus _eventBus = EventBus();

  static EventBus get instance => _eventBus;
}

// Define events
class ProfileUpdatedEvent {
  final Map<String, dynamic> userData;
  ProfileUpdatedEvent(this.userData);
}

class CoursesRefreshEvent {
  CoursesRefreshEvent();
}

class ActivationStatusChangedEvent {
  final bool isActivated;
  final String? grade;

  ActivationStatusChangedEvent({
    required this.isActivated,
    this.grade,
  });
}
