import 'dart:convert';

import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

class MqttService {
  late MqttServerClient _client;
  final String _clientId;
  final String _userId;

  // Track subscriptions and handlers
  final Set<String> _subscribedTopics = {};
  final Map<String, Function(String, String)> _topicHandlers = {};

  MqttService({required String userId})
    : _userId = userId,
      _clientId = 'flutter_${userId}_${DateTime.now().millisecondsSinceEpoch}';

  Future<void> connect() async {
    _client = MqttServerClient('broker.hivemq.com', _clientId);
    _client.port = 1883;
    _client.keepAlivePeriod = 60;
    _client.onDisconnected = _onDisconnected;
    _client.logging(on: false);

    final connMessage =
        MqttConnectMessage().withClientIdentifier(_clientId).startClean();
    _client.connectionMessage = connMessage;

    try {
      await _client.connect();
      print('MQTT Connected');

      // Setup SINGLE listener for all messages
      _client.updates!.listen((
        List<MqttReceivedMessage<MqttMessage>> messages,
      ) {
        for (final msg in messages) {
          final topic = msg.topic;
          try {
            final pubMsg = msg.payload as MqttPublishMessage;
            final payload = MqttPublishPayload.bytesToStringAsString(
              pubMsg.payload.message,
            );

            // Route message to correct handler
            if (_topicHandlers.containsKey(topic)) {
              print('Message received on topic: $topic');
              print('Payload: $payload');
              _topicHandlers[topic]!(payload, topic);
            }
          } catch (e) {
            print('Error processing $topic message: $e');
          }
        }
      });
    } catch (e) {
      print('MQTT Connection failed: $e');
      rethrow;
    }
  }

  void _onDisconnected() {
    print('MQTT Disconnected');
    _topicHandlers.clear();
    _subscribedTopics.clear();
  }

  Future<void> subscribeToUserMessages(
    String userId,
    Function(String, String) onMessage,
  ) async {
    final topic = 'user/$userId';
    await _subscribe(topic, (payload, _) {
      final json = jsonDecode(payload) as Map<String, dynamic>;
      onMessage(json['content'], json['userId']);
    });
  }

  Future<void> subscribeToGroupMessages(
    String groupId,
    Function(String, String) onMessage,
  ) async {
    final topic = 'group/$groupId';
    await _subscribe(topic, (payload, _) {
      final json = jsonDecode(payload) as Map<String, dynamic>;
      onMessage(json['content'], json['userId']);
    });
  }

  Future<void> subscribeToTypingIndicator(
    String userId,
    Function(String, bool) onTyping,
  ) async {
    final topic = 'typing/$userId';
    await _subscribe(topic, (payload, _) {
      final json = jsonDecode(payload) as Map<String, dynamic>;

      // DECODE THE CONTENT FIELD
      final contentJson =
          jsonDecode(json['content'] as String) as Map<String, dynamic>;

      onTyping(contentJson['senderId'], contentJson['isTyping']);
    });
  }

  Future<void> subscribeToGroupTypingIndicator(
    String groupId,
    Function(String, String, bool) onTyping,
  ) async {
    final topic = 'group/$groupId/typing';
    await _subscribe(topic, (payload, _) {
      final json = jsonDecode(payload) as Map<String, dynamic>;

      // DECODE THE CONTENT FIELD
      final contentJson =
          jsonDecode(json['content'] as String) as Map<String, dynamic>;

      onTyping(
        contentJson['groupId'],
        contentJson['senderId'],
        contentJson['isTyping'],
      );
    });
  }

  Future<void> _subscribe(
    String topic,
    Function(String, String) handler,
  ) async {
    if (_subscribedTopics.contains(topic)) return;

    if (_client.connectionStatus?.state != MqttConnectionState.connected) {
      await connect();
    }

    _client.subscribe(topic, MqttQos.atLeastOnce);
    _subscribedTopics.add(topic);
    _topicHandlers[topic] = handler;
  }

  Future<void> sendUserMessage(String recipientId, String content) async {
    final topic = 'user/$recipientId';
    await _publish(topic, content);
  }

  Future<void> sendGroupMessage(String groupId, String content) async {
    final topic = 'group/$groupId';
    await _publish(topic, content);
  }

  Future<void> sendTypingIndicator(String recipientId, bool isTyping) async {
    final topic = 'typing/$recipientId';
    final message = {
      'senderId': _userId,
      'isTyping': isTyping,
      'timestamp': DateTime.now().toIso8601String(),
    };
    await _publish(topic, jsonEncode(message));
  }

  Future<void> sendGroupTypingIndicator(String groupId, bool isTyping) async {
    final topic = 'group/$groupId/typing';
    final message = {
      'senderId': _userId,
      'groupId': groupId,
      'isTyping': isTyping,
      'timestamp': DateTime.now().toIso8601String(),
    };
    await _publish(topic, jsonEncode(message));
  }

  Future<void> _publish(String topic, String content) async {
    if (_client.connectionStatus?.state != MqttConnectionState.connected) {
      await connect();
    }

    final message = {
      'userId': _userId,
      'messageId': DateTime.now().millisecondsSinceEpoch.toString(),
      'content': content,
      'timestamp': DateTime.now().toIso8601String(),
    };

    final builder = MqttClientPayloadBuilder();
    builder.addString(jsonEncode(message));

    _client.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
  }

  void disconnect() {
    _client.disconnect();
    _topicHandlers.clear();
    _subscribedTopics.clear();
  }
}
