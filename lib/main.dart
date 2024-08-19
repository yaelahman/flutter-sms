import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:telephony/telephony.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SMS Reader and Sender',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: SmsReaderScreen(),
    );
  }
}

class SmsReaderScreen extends StatefulWidget {
  @override
  _SmsReaderScreenState createState() => _SmsReaderScreenState();
}

class _SmsReaderScreenState extends State<SmsReaderScreen> {
  final Telephony telephony = Telephony.instance;
  List<SmsMessage> _messages = [];
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _fetchSmsMessages();
    startTimer();
  }

  void startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 60), (timer) {
      makePostRequest();
      _fetchSmsMessages();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetchSmsMessages() async {
    if (Platform.isAndroid) {
      if (await Permission.sms.request().isGranted) {
        List<SmsMessage> messages = await telephony.getInboxSms(
          columns: [SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE],
        );

        print(messages.toString());

        setState(() {
          _messages = messages;
        });
      } else {
        print("SMS permission denied");
      }
    } else {
      // On iOS, we can't read SMS messages programmatically.
      print("Reading SMS messages is not supported on iOS.");
    }
  }

  Future<void> makePostRequest() async {
    // The body of the POST request
    String apiUrl =
        "https://api.cloud.cerca.it/sms01/received.php?apitoken=7364hrt26ga&mobilenumber=0092301234567&text=hello";
    // final Map<String, dynamic> requestBody = {
    //   "title": "foo",
    //   "body": "bar",
    //   "userId": 1,
    // };

    // Make the POST request
    final response = await http.post(
      Uri.parse(apiUrl),
      headers: {"Content-Type": "application/json"},
    );

    // Check the status of the response
    if (response.statusCode == 200) {
      final Map<String, dynamic> responseData = json.decode(response.body);
      print("Response Data: $responseData");
    } else {
      print("Request failed with status: ${response.statusCode}");
    }
  }

  Future<void> _sendSms(String address, String message) async {
    print(address + " " + message);
    if (Platform.isAndroid) {
      if (await Permission.sms.request().isGranted) {
        print("SENDED");
        telephony.sendSms(
          to: address,
          message: message,
        );
      } else {
        print("SMS permission denied");
      }
    } else if (Platform.isIOS) {
      final Uri smsUri = Uri(
        scheme: 'sms',
        path: address,
        queryParameters: <String, String>{
          'body': message,
        },
      );
      if (await canLaunch(smsUri.toString())) {
        await launch(smsUri.toString());
      } else {
        print("Could not launch SMS app");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('SMS Reader and Sender'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                SmsMessage message = _messages[index];
                return ListTile(
                  title: Text(message.address ?? 'Unknown'),
                  subtitle: Text(message.body ?? 'No message body'),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                TextField(
                  controller: _phoneController,
                  decoration: InputDecoration(
                    labelText: 'Phone Number',
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 10),
                TextField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    labelText: 'Message',
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () {
                    _sendSms(_phoneController.text, _messageController.text);
                  },
                  child: Text('Send SMS'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
