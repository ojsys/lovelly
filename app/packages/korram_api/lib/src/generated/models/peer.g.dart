// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'peer.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Peer _$PeerFromJson(Map<String, dynamic> json) => Peer(
  firstName: json['first_name'] as String,
  age: (json['age'] as num?)?.toInt(),
  city: json['city'] as String,
  sharedInterests: (json['shared_interests'] as List<dynamic>).map((e) => e as String).toList(),
  sharedLanguages: (json['shared_languages'] as List<dynamic>).map((e) => e as String).toList(),
  verified: json['verified'] as bool,
);

Map<String, dynamic> _$PeerToJson(Peer instance) => <String, dynamic>{
  'first_name': instance.firstName,
  'age': instance.age,
  'city': instance.city,
  'shared_interests': instance.sharedInterests,
  'shared_languages': instance.sharedLanguages,
  'verified': instance.verified,
};
