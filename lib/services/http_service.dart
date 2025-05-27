import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class HttpService {
  static const kTimeOutDurationInSeconds = 30;
  static Future<Response> get<T>(
    String url, {
    int timeoutInSeconds = kTimeOutDurationInSeconds,
  }) async {
    final dio = Dio();
    // dio.interceptors.add(TalkerDioLogger(talker: talker!));
    try {
      return await dio
          .get<T>(url, options: Options(responseType: ResponseType.plain))
          .timeout(
            Duration(seconds: timeoutInSeconds),
            onTimeout: () {
              // Time has run out, do what you wanted to do.
              return Response(
                requestOptions: RequestOptions(),
                statusCode: 408,
                statusMessage: 'Request Timeout Expired',
              ); // Request Timeout response status code
            },
          );
    } on DioException catch (e) {
      // talker?.error('Dio Exception: ', e);
      if (kDebugMode) {
        print('Dio Exception: ${e.message}');
      }
      rethrow;
    }
  }

  static Future<Response> post<T>(
    String url,
    Object? data, {
    int timeoutInSeconds = kTimeOutDurationInSeconds,
  }) async {
    final dio = Dio();
    // dio.interceptors.add(TalkerDioLogger(talker: talker!));
    try {
      return await dio
          .post(
            url,
            data: json.encode(data),
            options: Options(
              responseType: ResponseType.json,
              headers: {
                'Content-Type':
                    'application/json', // Set the content type to JSON
              },
            ),
          )
          .timeout(
            Duration(seconds: timeoutInSeconds),
            onTimeout: () {
              // Time has run out, do what you wanted to do.
              return Response(
                requestOptions: RequestOptions(),
                statusCode: 408,
                statusMessage: 'Request Timeout Expired',
              ); // Request Timeout response status code
            },
          );
    } on DioException catch (e) {
      if (kDebugMode) {
        print('Dio Exception: ${e.message}');
      }
      rethrow;
    }
  }
}
