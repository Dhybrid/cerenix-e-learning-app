// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_profile.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class UserProfileAdapter extends TypeAdapter<UserProfile> {
  @override
  final int typeId = 10;

  @override
  UserProfile read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return UserProfile(
      id: fields[0] as String,
      universityId: fields[1] as String,
      universityName: fields[2] as String,
      departmentId: fields[3] as String,
      departmentName: fields[4] as String,
      levelId: fields[5] as String,
      levelName: fields[6] as String,
      semesterId: fields[7] as String,
      semesterName: fields[8] as String,
      lastUpdated: fields[9] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, UserProfile obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.universityId)
      ..writeByte(2)
      ..write(obj.universityName)
      ..writeByte(3)
      ..write(obj.departmentId)
      ..writeByte(4)
      ..write(obj.departmentName)
      ..writeByte(5)
      ..write(obj.levelId)
      ..writeByte(6)
      ..write(obj.levelName)
      ..writeByte(7)
      ..write(obj.semesterId)
      ..writeByte(8)
      ..write(obj.semesterName)
      ..writeByte(9)
      ..write(obj.lastUpdated);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserProfileAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
