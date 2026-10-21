// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'ledger_reason_enum.dart';

part 'ledger_entry.g.dart';

@JsonSerializable()
class LedgerEntry {
  const LedgerEntry({
    required this.id,
    required this.delta,
    required this.reason,
    required this.refId,
    required this.createdAt,
  });

  factory LedgerEntry.fromJson(Map<String, Object?> json) => _$LedgerEntryFromJson(json);

  final String id;
  final int delta;
  final LedgerReasonEnum reason;

  /// For gifts: the gift slug
  @JsonKey(name: 'ref_id')
  final String refId;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  Map<String, Object?> toJson() => _$LedgerEntryToJson(this);
}
