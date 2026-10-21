// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'daily_cap_enum.dart';
import 'plus_status.dart';
import 'prices.dart';

part 'spend_settings.g.dart';

@JsonSerializable()
class SpendSettings {
  const SpendSettings({
    required this.paygEnabled,
    required this.dailyCap,
    required this.autoTopup,
    required this.topupPack,
    required this.plus,
    required this.prices,
  });

  factory SpendSettings.fromJson(Map<String, Object?> json) => _$SpendSettingsFromJson(json);

  @JsonKey(name: 'payg_enabled')
  final bool paygEnabled;

  /// 0 = no cap.
  ///
  /// * `50` - 50.
  /// * `100` - 100.
  /// * `200` - 200.
  /// * `0` - 0.
  @JsonKey(name: 'daily_cap')
  final DailyCapEnum dailyCap;
  @JsonKey(name: 'auto_topup')
  final bool autoTopup;
  @JsonKey(name: 'topup_pack')
  final String topupPack;
  final PlusStatus plus;
  final Prices prices;

  Map<String, Object?> toJson() => _$SpendSettingsToJson(this);
}
