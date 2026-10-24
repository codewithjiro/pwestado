import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// Records requests and answers them with [handler]. No network.
class FakeHttpAdapter implements HttpClientAdapter {
  FakeHttpAdapter(this.handler);

  Future<ResponseBody> Function(RequestOptions options) handler;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    requests.add(options);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody jsonResponse(Object json, {int status = 200}) =>
    ResponseBody.fromString(
      jsonEncode(json),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

Dio fakeDio(FakeHttpAdapter adapter) =>
    Dio(BaseOptions(responseType: ResponseType.json))
      ..httpClientAdapter = adapter;
