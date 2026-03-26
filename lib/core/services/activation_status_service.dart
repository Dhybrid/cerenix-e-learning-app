import 'package:hive_flutter/hive_flutter.dart';

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

  static Future<ActivationStatusSnapshot>? _inFlightRefresh;

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
    final cached = await getCachedStatus();
    if (!forceRefresh && cached.hasCachedValue && !cached.isStale) {
      return cached;
    }

    return refreshStatus();
  }

  static Future<ActivationStatusSnapshot> refreshStatus() {
    return _inFlightRefresh ??= _refreshStatusInternal().whenComplete(() {
      _inFlightRefresh = null;
    });
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
        return ActivationStatusSnapshot(
          isActivated: true,
          grade: normalizedGrade,
          checkedAt: DateTime.now(),
          hasCachedValue: true,
        );
      }

      await _saveStatus(isActivated: false, grade: null);
      return ActivationStatusSnapshot(
        isActivated: false,
        grade: null,
        checkedAt: DateTime.now(),
        hasCachedValue: true,
      );
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
    await box.put('user_activated', isActivated);
    await box.put('activation_timestamp', DateTime.now().toIso8601String());

    if (grade != null && grade.isNotEmpty) {
      await box.put('activation_grade', grade);
    } else {
      await box.delete('activation_grade');
    }
  }
}
