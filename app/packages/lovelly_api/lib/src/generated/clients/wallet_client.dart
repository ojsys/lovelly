// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/ledger.dart';
import '../models/pack.dart';
import '../models/wallet.dart';

part 'wallet_client.g.dart';

@RestApi()
abstract class WalletClient {
  factory WalletClient(Dio dio, {String? baseUrl}) = _WalletClient;

  @GET('/api/v1/wallet')
  Future<Wallet> walletRetrieve();

  @POST('/api/v1/wallet/claim-daily')
  Future<Wallet> walletClaimDailyCreate();

  /// [before] - ISO time: older than this
  @GET('/api/v1/wallet/ledger')
  Future<Ledger> walletLedgerRetrieve({@Query('before') String? before});

  @GET('/api/v1/wallet/packs')
  Future<List<Pack>> walletPacksList();
}
