// import 'package:flutter/material.dart';
// import 'package:mqtt_client/mqtt_client.dart';

// import 'services/mqtt_service.dart';

// class MqttPage extends StatefulWidget {
//   const MqttPage({super.key});

//   @override
//   State<MqttPage> createState() => _MqttPageState();
// }

// class _MqttPageState extends State<MqttPage> {
//   final MqttService _mqttService = MqttService();
//   final TextEditingController _messageController = TextEditingController();
//   final List<String> _messages = [];

//   @override
//   void initState() {
//     super.initState();
//     _initMqtt();
//   }

//   Future<void> _initMqtt() async {
//     await _mqttService.connect();
//     _mqttService.subscribe(
//       'flutter/demo',
//       onMessage: (messages) {
//         for (var msg in messages) {
//           final MqttPublishMessage pubMsg = msg.payload as MqttPublishMessage;
//           final payload = MqttPublishPayload.bytesToStringAsString(
//             pubMsg.payload.message,
//           );
//           setState(() {
//             _messages.add('MQTT: $payload');
//           });
//         }
//       },
//     );
//   }

//   Future<void> _sendViaMqtt() async {
//     await _mqttService.publish('flutter/demo', _messageController.text);
//     setState(() {
//       _messages.add('MQTT Sent: ${_messageController.text}');
//     });
//     _messageController.clear();
//   }

//   @override
//   void dispose() {
//     _mqttService.disconnect();
//     _messageController.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: Text('MQTT Demo')),
//       body: Column(
//         children: [
//           Padding(
//             padding: const EdgeInsets.all(8.0),
//             child: TextField(
//               controller: _messageController,
//               decoration: InputDecoration(
//                 labelText: 'Message',
//                 border: OutlineInputBorder(),
//               ),
//             ),
//           ),
//           Row(
//             mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//             children: [
//               ElevatedButton(
//                 onPressed: _sendViaMqtt,
//                 child: Text('Send via MQTT'),
//               ),
//             ],
//           ),
//           Expanded(
//             child: ListView.builder(
//               itemCount: _messages.length,
//               itemBuilder: (context, index) {
//                 return ListTile(title: Text(_messages[index]));
//               },
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
