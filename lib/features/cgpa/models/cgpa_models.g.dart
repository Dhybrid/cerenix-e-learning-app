// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cgpa_models.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CGPALevelAdapter extends TypeAdapter<CGPALevel> {
  @override
  final int typeId = 10;

  @override
  CGPALevel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CGPALevel(
      level: fields[0] as String,
      firstSemester: (fields[1] as List).cast<CGPACourse>(),
      secondSemester: (fields[2] as List).cast<CGPACourse>(),
    );
  }

  @override
  void write(BinaryWriter writer, CGPALevel obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.level)
      ..writeByte(1)
      ..write(obj.firstSemester)
      ..writeByte(2)
      ..write(obj.secondSemester);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CGPALevelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class CGPACourseAdapter extends TypeAdapter<CGPACourse> {
  @override
  final int typeId = 11;

  @override
  CGPACourse read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CGPACourse(
      code: fields[0] as String,
      unit: fields[1] as int,
      grade: fields[2] as String,
    );
  }

  @override
  void write(BinaryWriter writer, CGPACourse obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.code)
      ..writeByte(1)
      ..write(obj.unit)
      ..writeByte(2)
      ..write(obj.grade);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CGPACourseAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
