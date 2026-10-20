// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'peer.g.dart';

@JsonSerializable()
class Peer {
  const Peer({
    required this.firstName,
    required this.age,
    required this.city,
    required this.sharedInterests,
    required this.verified,
  });

  factory Peer.fromJson(Map<String, Object?> json) => _$PeerFromJson(json);

  @JsonKey(name: 'first_name')
  final String firstName;
  final int? age;
  final String city;
  @JsonKey(name: 'shared_interests')
  final List<String> sharedInterests;
  final bool verified;

  Map<String, Object?> toJson() => _$PeerToJson(this);
}
