// ignore_for_file: unnecessary_cast
// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

/// * `week` - 1 week.
/// * `month` - 1 month.
/// * `year` - 12 months.
@JsonEnum()
enum PlanEnum {
  @JsonValue('week')
  week('week'),
  @JsonValue('month')
  month('month'),
  @JsonValue('year')
  year('year'),

  /// Default value for all unparsed values, allows backward compatibility when adding new values on the backend.
  $unknown(null);

  const PlanEnum(this.json);

  factory PlanEnum.fromJson(String json) =>
      values.firstWhere((e) => e.json == json, orElse: () => $unknown);

  final String? json;
  String toJson() {
    final value = json;
    if (value == null) {
      throw StateError(
        'Cannot convert enum value with null JSON representation to String. '
        'This usually happens for \$unknown or @JsonValue(null) entries.',
      );
    }
    return value as String;
  }

  @override
  String toString() => json?.toString() ?? super.toString();

  /// Returns all defined enum values excluding the $unknown value.
  static List<PlanEnum> get $valuesDefined => values.where((value) => value != $unknown).toList();
}
