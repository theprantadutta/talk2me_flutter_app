import 'package:dio/dio.dart'; // or use 'package:http/http.dart'

class MqttApiService {
  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: 'http://192.168.0.141:5010',
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 5),
    ),
  );

  Future<void> publishMessage(String topic, String message) async {
    try {
      await _dio.post(
        '/api/mqtt/publish',
        data: {'topic': topic, 'message': message},
      );
    } catch (e) {
      print('Error publishing message: $e');
      rethrow;
    }
  }

  // Add other API methods as needed
}
