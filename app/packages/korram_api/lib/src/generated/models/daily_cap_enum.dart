// ignore_for_file: unnecessary_cast
// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

/// * `50` - 50.
/// * `100` - 100.
/// * `200` - 200.
/// * `0` - 0.
@JsonEnum()
enum DailyCapEnum {
  @JsonValue(50)
  value50(50),
  @JsonValue(100)
  value100(100),
  @JsonValue(200)
  value200(200),
  @JsonValue(0)
  value0(0),

  /// Default value for all unparsed values, allows backward compatibility when adding new values on the backend.
  $unknown(null);

  const DailyCapEnum(this.json);

  factory DailyCapEnum.fromJson(int json) =>
      values.firstWhere((e) => e.json == json, orElse: () => $unknown);

  final int? json;
  int toJson() {
    final value = json;
    if (value == null) {
      throw StateError(
        'Cannot convert enum value with null JSON representation to int. '
        'This usually happens for \$unknown or @JsonValue(null) entries.',
      );
    }
    return value as int;
  }

  @override
  String toString() => json?.toString() ?? super.toString();

  /// Returns all defined enum values excluding the $unknown value.
  static List<DailyCapEnum> get $valuesDefined =>
      values.where((value) => value != $unknown).toList();
}
