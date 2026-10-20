// ignore_for_file: unnecessary_cast
// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

/// * `minor` - May be under 18.
/// * `nudity` - Nudity or sexual content.
/// * `harassment` - Harassment or hate.
/// * `scam` - Scam or asking for money.
/// * `fake` - Fake profile or impersonation.
/// * `other` - Something else.
@JsonEnum()
enum ReasonEnum {
  @JsonValue('minor')
  minor('minor'),
  @JsonValue('nudity')
  nudity('nudity'),
  @JsonValue('harassment')
  harassment('harassment'),
  @JsonValue('scam')
  scam('scam'),
  @JsonValue('fake')
  fake('fake'),
  @JsonValue('other')
  other('other'),

  /// Default value for all unparsed values, allows backward compatibility when adding new values on the backend.
  $unknown(null);

  const ReasonEnum(this.json);

  factory ReasonEnum.fromJson(String json) =>
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
  static List<ReasonEnum> get $valuesDefined => values.where((value) => value != $unknown).toList();
}
