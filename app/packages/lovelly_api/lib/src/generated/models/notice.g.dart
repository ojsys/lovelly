// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notice.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Notice _$NoticeFromJson(Map<String, dynamic> json) => Notice(
  id: json['id'] as String,
  kind: json['kind'] as String,
  title: json['title'] as String,
  body: json['body'] as String,
);

Map<String, dynamic> _$NoticeToJson(Notice instance) => <String, dynamic>{
  'id': instance.id,
  'kind': instance.kind,
  'title': instance.title,
  'body': instance.body,
};
