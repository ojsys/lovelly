// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart';

import 'clients/auth_client.dart';
import 'clients/blocks_client.dart';
import 'clients/health_client.dart';
import 'clients/match_client.dart';
import 'clients/me_client.dart';
import 'clients/reports_client.dart';
import 'clients/sessions_client.dart';

/// Korram API `v1.0.0`
class KorramApi {
  KorramApi(Dio dio, {String? baseUrl}) : _dio = dio, _baseUrl = baseUrl;

  final Dio _dio;
  final String? _baseUrl;

  static String get version => '1.0.0';

  AuthClient? _auth;
  BlocksClient? _blocks;
  HealthClient? _health;
  MatchClient? _match;
  MeClient? _me;
  ReportsClient? _reports;
  SessionsClient? _sessions;

  AuthClient get auth => _auth ??= AuthClient(_dio, baseUrl: _baseUrl);

  BlocksClient get blocks => _blocks ??= BlocksClient(_dio, baseUrl: _baseUrl);

  HealthClient get health => _health ??= HealthClient(_dio, baseUrl: _baseUrl);

  MatchClient get match => _match ??= MatchClient(_dio, baseUrl: _baseUrl);

  MeClient get me => _me ??= MeClient(_dio, baseUrl: _baseUrl);

  ReportsClient get reports => _reports ??= ReportsClient(_dio, baseUrl: _baseUrl);

  SessionsClient get sessions => _sessions ??= SessionsClient(_dio, baseUrl: _baseUrl);
}
