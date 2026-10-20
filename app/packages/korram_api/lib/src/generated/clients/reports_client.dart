// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/report.dart';
import '../models/report_request_request.dart';

part 'reports_client.g.dart';

@RestApi()
abstract class ReportsClient {
  factory ReportsClient(Dio dio, {String? baseUrl}) = _ReportsClient;

  /// SF-4: report the other person in a session (screen 08).
  @POST('/api/v1/reports')
  Future<Report> reportsCreate({@Body() required ReportRequestRequest body});
}
