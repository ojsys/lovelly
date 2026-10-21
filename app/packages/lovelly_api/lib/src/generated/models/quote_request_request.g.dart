// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'quote_request_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

QuoteRequestRequest _$QuoteRequestRequestFromJson(Map<String, dynamic> json) => QuoteRequestRequest(
  mode: ModeEnum.fromJson(json['mode'] as String),
  filters: FiltersRequest.fromJson(json['filters'] as Map<String, dynamic>),
);

Map<String, dynamic> _$QuoteRequestRequestToJson(QuoteRequestRequest instance) => <String, dynamic>{
  'mode': instance.mode,
  'filters': instance.filters,
};
