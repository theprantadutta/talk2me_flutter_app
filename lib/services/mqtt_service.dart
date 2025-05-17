import 'dart:convert';

import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

class MqttService {
  late MqttServerClient _client;
  final String _clientId;
  final String _userId;
  // Track last sent message ID to avoid processing our own messages
  // String? _lastSentMessageId;

  MqttService({required String userId})
    : _userId = userId,
      _clientId = 'flutter_${userId}_${DateTime.now().millisecondsSinceEpoch}';

  Future<void> connect() async {
    _client = MqttServerClient('broker.hivemq.com', _clientId);
    _client.port = 1883; // Default MQTT port
    _client.keepAlivePeriod = 60;
    _client.onDisconnected = _onDisconnected;
    _client.logging(on: false);

    final connMessage =
        MqttConnectMessage().withClientIdentifier(_clientId).startClean();
    _client.connectionMessage = connMessage;

    try {
      await _client.connect();
      print('MQTT Connected');
    } catch (e) {
      print('MQTT Connection failed: $e');
      rethrow;
    }
  }

  void _onDisconnected() {
    print('MQTT Disconnected');
  }

  // Future<void> subscribe(
  //   String topic, {
  //   Function(List<MqttReceivedMessage<MqttMessage>>)? onMessage,
  // }) async {
  //   if (_client.connectionStatus?.state != MqttConnectionState.connected) {
  //     await connect();
  //   }
  //   _client.subscribe(topic, MqttQos.atLeastOnce);

  //   if (onMessage != null) {
  //     _client.updates!.listen(onMessage);
  //   } else {
  //     _client.updates!.listen((
  //       List<MqttReceivedMessage<MqttMessage>> messages,
  //     ) {
  //       for (var msg in messages) {
  //         final MqttPublishMessage pubMsg = msg.payload as MqttPublishMessage;
  //         final payload = MqttPublishPayload.bytesToStringAsString(
  //           pubMsg.payload.message,
  //         );
  //         print('Received message: $payload from topic: ${msg.topic}');
  //         // Handle your message here
  //       }
  //     });
  //   }
  // }

  Future<void> subscribe(
    String topic,
    Function(String, String) onMessage,
  ) async {
    if (_client.connectionStatus?.state != MqttConnectionState.connected) {
      await connect();
    }

    _client.subscribe(topic, MqttQos.atLeastOnce);

    _client.updates!.listen((List<MqttReceivedMessage<MqttMessage>> messages) {
      for (final msg in messages) {
        try {
          final MqttPublishMessage pubMsg = msg.payload as MqttPublishMessage;
          final payload = MqttPublishPayload.bytesToStringAsString(
            pubMsg.payload.message,
          );
          final json = jsonDecode(payload) as Map<String, dynamic>;
          // TODO: Update this
          onMessage(json['content'], json['userId']);
          // Skip our own messages
          // if (json['messageId'] == _lastSentMessageId) {
          //   continue;
          // }

          // Only process messages not from this user
          // if (json['userId'] != _userId) {
          //   onMessage(json['content']);
          // }
        } catch (e) {
          print('Error processing message: $e');
        }
      }
    });
  }

  // Future<void> publish(String topic, String message) async {
  //   if (_client.connectionStatus?.state != MqttConnectionState.connected) {
  //     await connect();
  //   }
  //   final builder = MqttClientPayloadBuilder();
  //   builder.addString(message);
  //   _client.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
  // }
  Future<void> publish(String topic, String content) async {
    if (_client.connectionStatus?.state != MqttConnectionState.connected) {
      await connect();
    }

    final messageId = DateTime.now().millisecondsSinceEpoch.toString();
    // _lastSentMessageId = messageId;

    final message = {
      'userId': _userId,
      'messageId': messageId,
      'content': content,
      'timestamp': DateTime.now().toIso8601String(),
    };

    final builder = MqttClientPayloadBuilder();
    builder.addString(jsonEncode(message));

    _client.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
  }

  void disconnect() {
    _client.disconnect();
  }
}
