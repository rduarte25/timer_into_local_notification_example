import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:rxdart/subjects.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:flutter_native_timezone/flutter_native_timezone.dart';
import 'dart:async';
import 'dart:isolate';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

class ReceivedNotification {
  ReceivedNotification(
      {required this.id,
      required this.title,
      required this.body,
      required this.payload});

  final int id;
  final String? title;
  final String? body;
  final String? payload;
}

final BehaviorSubject<ReceivedNotification> didReceiveLocalNotificationSubject =
    BehaviorSubject<ReceivedNotification>();

final BehaviorSubject<String?> selectNotificationSubject =
    BehaviorSubject<String?>();

String? selectNotificationPayload;

Future<void> _configureLocalTimeZone() async {
  tz.initializeTimeZones();
  final String? timeZoneName = await FlutterNativeTimezone.getLocalTimezone();
  tz.setLocalLocation(tz.getLocation(timeZoneName!));
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await _configureLocalTimeZone();

  const AndroidInitializationSettings initializationAndroidSettings =
      AndroidInitializationSettings('app_icon');

  final InitializationSettings initializationSettings =
      InitializationSettings(android: initializationAndroidSettings);

  await flutterLocalNotificationsPlugin.initialize(initializationSettings,
      onSelectNotification: (String? payload) async {
    if (payload != null) {
      debugPrint('notification payload: $payload');
    }
    selectNotificationPayload = payload;
    selectNotificationSubject.add(payload);
  });

  runApp(App());
}

class App extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Timer into local noticication example',
      theme: new ThemeData(primarySwatch: Colors.blue),
      home: new HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  HomePage({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    _stopwatch = Stopwatch();
  }

  Stopwatch? _stopwatch; //stopwatch
  Isolate? _isolate;
  bool _running = false;
  static int _counter = 0;
  String time = '';
  ReceivePort? _receivePort;

  var secsA = 0;
  String formatTime(int miliseconds) {
    var secs = miliseconds ~/ 1000;
    if (secsA != secs) {
      secsA = secs;
      print(secsA);
    }
    var hours = (secs ~/ 3600).toString().padLeft(2, '0');
    var minutes = ((secs % 3600) ~/ 60).toString().padLeft(2, '0');
    var seconds = (secs ~/ 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  static _checkTimer(SendPort sendPort) async {
    Timer.periodic(new Duration(milliseconds: 1), (Timer timer) {
      _counter++;
      String message = 'Notification ${_counter.toString()}';
      print('SEND $message');
      sendPort.send(message);
    });
  }

  void _handleMessage(dynamic data) {
    print('RECEIVE $data');
    setState(() {
      time = data;
    });
    _showMessaginNotification();
  }

  void _start() async {
    if (!_stopwatch!.isRunning) {
      _stopwatch!.start();
    }

    _running = true;
    _receivePort = ReceivePort();
    _isolate = await Isolate.spawn(_checkTimer, _receivePort!.sendPort);
    _receivePort!.listen(_handleMessage, onDone: () {
      print('done!');
    });
  }

  void _stop() {
    if (_stopwatch!.isRunning) {
      _stopwatch!.stop();
    }

    if (_isolate != null) {
      setState(() {
        _running = false;
        time = '';
      });
      _receivePort!.close();
      _isolate!.kill(priority: Isolate.immediate);
      _isolate = null;
    }
  }

  Future<void> _showMessaginNotification() async {
    const Person coworker = Person(
        name: 'Chronometer',
        key: '1',
        uri: 'tel:584120364792',
        icon: FlutterBitmapAssetAndroidIcon('assets/icons/clock.png'));
    final List<Message> messages = <Message>[
      Message(formatTime(_stopwatch!.elapsedMilliseconds), DateTime.now(),
          coworker),
    ];
    final MessagingStyleInformation messagingStyleInformation =
        MessagingStyleInformation(coworker,
            groupConversation: true,
            conversationTitle: 'Chronometer',
            htmlFormatContent: true,
            htmlFormatTitle: true,
            messages: messages);
    final AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails('message channel id', 'message channel name',
            'message channel description',
            //icon: 'app_icon',
            category: 'msg',
            styleInformation: messagingStyleInformation,
            //importance: Importance.high,
            //priority: Priority.high,
            channelAction: AndroidNotificationChannelAction.update);
    final NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidNotificationDetails);

    await flutterLocalNotificationsPlugin.show(
        0, 'message title', 'message body', platformChannelSpecifics);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:
          AppBar(title: const Text('Timer Into Local Notifications Example')),
      body: new Center(
        child: Column(
          children: <Widget>[],
        ),
      ),
      floatingActionButton: new FloatingActionButton(
        onPressed: _running ? _stop : _start,
        child: Icon(Icons.add),
      ),
    );
  }
}
