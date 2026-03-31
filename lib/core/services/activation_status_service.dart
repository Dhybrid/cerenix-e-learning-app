import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'event_bus.dart';
import '../network/api_service.dart';

class ActivationStatusSnapshot {
  final bool isActivated;
  final String? grade;
  final DateTime? checkedAt;
  final bool hasCachedValue;

  const ActivationStatusSnapshot({
    required this.isActivated,
    required this.grade,
    required this.checkedAt,
    required this.hasCachedValue,
  });

  bool get isStale {
    if (checkedAt == null) return true;
    return DateTime.now().difference(checkedAt!) >
        ActivationStatusService.cacheTtl;
  }
}

class ActivationStatusService {
  ActivationStatusService._();

  static const String boxName = 'activation_cache';
  static const Duration cacheTtl = Duration(minutes: 5);
  static const Duration backgroundRefreshInterval = Duration(minutes: 3);

  static const ActivationStatusSnapshot _emptySnapshot =
      ActivationStatusSnapshot(
        isActivated: false,
        grade: null,
        checkedAt: null,
        hasCachedValue: false,
      );

  static final ValueNotifier<ActivationStatusSnapshot> _statusNotifier =
      ValueNotifier<ActivationStatusSnapshot>(_emptySnapshot);
  static final _ActivationStatusLifecycleObserver _lifecycleObserver =
      _ActivationStatusLifecycleObserver();

  static Future<void>? _initializationFuture;
  static Future<ActivationStatusSnapshot>? _inFlightRefresh;
  static Timer? _backgroundRefreshTimer;

  static ValueListenable<ActivationStatusSnapshot> get listenable =>
      _statusNotifier;

  static ActivationStatusSnapshot get current => _statusNotifier.value;

  static Future<void> initialize() {
    return _initializationFuture ??= _initializeInternal();
  }

  static Future<ActivationStatusSnapshot> getCachedStatus() async {
    try {
      final box = await Hive.openBox(boxName);
      final cachedActivation = box.get('user_activated');
      final cachedGrade = box.get('activation_grade')?.toString();
      final cachedTimestamp = box.get('activation_timestamp')?.toString();

      DateTime? checkedAt;
      if (cachedTimestamp != null && cachedTimestamp.isNotEmpty) {
        checkedAt = DateTime.tryParse(cachedTimestamp);
      }

      return ActivationStatusSnapshot(
        isActivated: cachedActivation == true,
        grade: cachedGrade,
        checkedAt: checkedAt,
        hasCachedValue: cachedActivation != null,
      );
    } catch (_) {
      return const ActivationStatusSnapshot(
        isActivated: false,
        grade: null,
        checkedAt: null,
        hasCachedValue: false,
      );
    }
  }

  static Future<ActivationStatusSnapshot> resolveStatus({
    bool forceRefresh = false,
  }) async {
    await initialize();

    final currentStatus = current;
    if (currentStatus.hasCachedValue) {
      if (forceRefresh || currentStatus.isStale) {
        refreshInBackground(forceRefresh: true);
      }
      return currentStatus;
    }

    final cached = await getCachedStatus();
    if (cached.hasCachedValue) {
      _updateSnapshot(cached, shouldBroadcast: false);
      if (forceRefresh || cached.isStale) {
        refreshInBackground(forceRefresh: true);
      }
      return cached;
    }

    return refreshStatus(forceRefresh: true);
  }

  static Future<ActivationStatusSnapshot> refreshStatus({
    bool forceRefresh = true,
  }) async {
    await initialize();

    if (!forceRefresh) {
      final currentStatus = current;
      if (currentStatus.hasCachedValue && !currentStatus.isStale) {
        return currentStatus;
      }
    }

    return _inFlightRefresh ??= _refreshStatusInternal().whenComplete(() {
      _inFlightRefresh = null;
    });
  }

  static Future<void> refreshInBackground({bool forceRefresh = false}) async {
    try {
      await refreshStatus(forceRefresh: forceRefresh);
    } catch (_) {}
  }

  static Future<void> markActivated({String? grade}) async {
    await _saveStatus(isActivated: true, grade: grade);
  }

  static Future<void> markNotActivated() async {
    await _saveStatus(isActivated: false, grade: null);
  }

  static Future<ActivationStatusSnapshot> _refreshStatusInternal() async {
    final cached = await getCachedStatus();

    try {
      final activationData = await ApiService().getActivationStatus();
      if (activationData != null && activationData.isValid) {
        final normalizedGrade = activationData.grade.toString();
        await _saveStatus(isActivated: true, grade: normalizedGrade);
        return current;
      }

      await _saveStatus(isActivated: false, grade: null);
      return current;
    } catch (_) {
      if (cached.hasCachedValue) {
        return cached;
      }

      return const ActivationStatusSnapshot(
        isActivated: false,
        grade: null,
        checkedAt: null,
        hasCachedValue: false,
      );
    }
  }

  static Future<void> _saveStatus({
    required bool isActivated,
    String? grade,
  }) async {
    final box = await Hive.openBox(boxName);
    final now = DateTime.now();

    await box.put('user_activated', isActivated);
    await box.put('activation_timestamp', now.toIso8601String());

    if (grade != null && grade.isNotEmpty) {
      await box.put('activation_grade', grade);
    } else {
      await box.delete('activation_grade');
    }

    await _syncUserBox(isActivated: isActivated, grade: grade);
    _updateSnapshot(
      ActivationStatusSnapshot(
        isActivated: isActivated,
        grade: grade,
        checkedAt: now,
        hasCachedValue: true,
      ),
    );
  }

  static Future<void> _initializeInternal() async {
    final cached = await getCachedStatus();
    _updateSnapshot(cached, shouldBroadcast: false);

    WidgetsBinding.instance.addObserver(_lifecycleObserver);
    _backgroundRefreshTimer ??= Timer.periodic(backgroundRefreshInterval, (_) {
      refreshInBackground(forceRefresh: true);
    });

    if (!cached.hasCachedValue || cached.isStale) {
      unawaited(refreshInBackground(forceRefresh: true));
    }
  }

  static Future<void> _syncUserBox({
    required bool isActivated,
    String? grade,
  }) async {
    try {
      final userBox = await Hive.openBox('user_box');
      final currentUser = userBox.get('current_user');
      if (currentUser is! Map) {
        return;
      }

      final updatedUser = Map<String, dynamic>.from(currentUser);
      updatedUser['user_activated'] = isActivated;

      if (isActivated && grade != null && grade.isNotEmpty) {
        updatedUser['activation_grade'] = grade;
      } else {
        updatedUser.remove('activation_grade');
      }

      await userBox.put('current_user', updatedUser);
    } catch (_) {}
  }

  static void _updateSnapshot(
    ActivationStatusSnapshot nextSnapshot, {
    bool shouldBroadcast = true,
  }) {
    final previousSnapshot = _statusNotifier.value;
    final didChange =
        previousSnapshot.isActivated != nextSnapshot.isActivated ||
        previousSnapshot.grade != nextSnapshot.grade ||
        previousSnapshot.hasCachedValue != nextSnapshot.hasCachedValue;

    _statusNotifier.value = nextSnapshot;

    if (shouldBroadcast && didChange) {
      EventBusService.instance.fire(
        ActivationStatusChangedEvent(
          isActivated: nextSnapshot.isActivated,
          grade: nextSnapshot.grade,
        ),
      );
    }
  }
}

class _ActivationStatusLifecycleObserver with WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ActivationStatusService.refreshInBackground(forceRefresh: true);
    }
  }
}
