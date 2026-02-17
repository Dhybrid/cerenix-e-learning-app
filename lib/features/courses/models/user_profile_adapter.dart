// lib/features/courses/models/user_profile_adapter.dart
import 'package:hive/hive.dart';
import 'course_models.dart';

class UserProfileAdapter extends TypeAdapter<UserProfile> {
  @override
  final int typeId = 33; // Must match the typeId in main.dart

  @override
  UserProfile read(BinaryReader reader) {
    final map = Map<String, dynamic>.from(reader.readMap());
    return UserProfile.fromJson(map);
  }

  @override
  void write(BinaryWriter writer, UserProfile obj) {
    writer.writeMap(obj.toJson());
  }
}
