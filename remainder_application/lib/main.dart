import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

void main() {
  runApp(ReminderApp());
}

class ReminderApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Reminder App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      debugShowCheckedModeBanner: false,
      home: ReminderHomePage(),
    );
  }
}

class ReminderHomePage extends StatefulWidget {
  @override
  _ReminderHomePageState createState() => _ReminderHomePageState();
}

class _ReminderHomePageState extends State<ReminderHomePage> {
  late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;
  String? selectedDay;
  TimeOfDay? selectedTime;
  String? selectedActivity;

  final List<String> daysOfWeek = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday'
  ];

  final List<String> activities = [
    'Wake up',
    'Go to gym',
    'Breakfast',
    'Meetings',
    'Lunch',
    'Quick nap',
    'Go to library',
    'Dinner',
    'Go to sleep'
  ];

  List<Reminder> reminders = [];
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    tz.initializeTimeZones();

    flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    var initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    var initializationSettingsDarwin = DarwinInitializationSettings();
    var initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );
    flutterLocalNotificationsPlugin.initialize(initializationSettings,
        onDidReceiveNotificationResponse:
            (NotificationResponse response) async {
      print("Notification tapped with ID: ${response.id}");

      if (response.id != null) {
        final reminder = reminders.firstWhere(
            (reminder) => reminder.id == response.id,
            orElse: () => Reminder(
                id: -1,
                day: '',
                time: TimeOfDay.now(),
                activity: '',
                isPlayed: false));
        if (reminder.id != -1) {
          setState(() {
            reminder.isPlayed = true;
          });
          _saveRemindersToLocalStorage();
        }
      }
    });

    _loadRemindersFromLocalStorage();

    _timer = Timer.periodic(Duration(minutes: 1), (timer) {
      _checkReminders();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _scheduleNotification() async {
    if (selectedDay == null || selectedTime == null || selectedActivity == null)
      return;

    final scheduledNotificationDateTime =
        tz.TZDateTime.now(tz.local).add(Duration(
      days: (((daysOfWeek.indexOf(selectedDay!) + 1) - DateTime.now().weekday) +
              7) %
          7,
      hours: selectedTime!.hour - DateTime.now().hour,
      minutes: selectedTime!.minute - DateTime.now().minute,
    ));

    final reminderText =
        '$selectedActivity on $selectedDay at ${selectedTime!.format(context)}';

    final androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'your_channel_id',
      'your_channel_name',
      channelDescription: 'your channel description',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: false,
    );

    final darwinPlatformChannelSpecifics = DarwinNotificationDetails();
    final platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: darwinPlatformChannelSpecifics,
    );

    final reminderId = reminders.length;

    await flutterLocalNotificationsPlugin.zonedSchedule(
      reminderId,
      'Reminder',
      reminderText,
      scheduledNotificationDateTime,
      platformChannelSpecifics,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );

    setState(() {
      reminders.add(Reminder(
        id: reminderId,
        day: selectedDay!,
        time: selectedTime!,
        activity: selectedActivity!,
        isPlayed: false,
      ));
      _saveRemindersToLocalStorage();
    });
  }

  void _checkReminders() {
    final now = DateTime.now();

    setState(() {
      for (var reminder in reminders) {
        final reminderDateTime = DateTime(
          now.year,
          now.month,
          now.day,
          reminder.time.hour,
          reminder.time.minute,
        );

        if (now.isAfter(reminderDateTime) && !reminder.isPlayed) {
          reminder.isPlayed = true;
        }
      }
      _saveRemindersToLocalStorage();
    });
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: selectedTime ?? TimeOfDay.now(),
    );
    if (picked != null && picked != selectedTime) {
      setState(() {
        selectedTime = picked;
      });
    }
  }

  Future<void> _loadRemindersFromLocalStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final String? remindersJson = prefs.getString('reminders');

    if (remindersJson != null) {
      final List<dynamic> decodedReminders = json.decode(remindersJson);
      setState(() {
        reminders = decodedReminders
            .map((json) => Reminder.fromJson(json as Map<String, dynamic>))
            .toList();
      });
    }
  }

  Future<void> _saveRemindersToLocalStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final String encodedReminders =
        json.encode(reminders.map((reminder) => reminder.toJson()).toList());
    prefs.setString('reminders', encodedReminders);
  }

  void _deleteReminder(int id) {
    setState(() {
      reminders.removeWhere((reminder) => reminder.id == id);
      _saveRemindersToLocalStorage();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Color.fromARGB(255, 168, 16, 140),
        title: Text(
          'Daily Remainder',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Container(
              margin: EdgeInsetsDirectional.only(top: 20),
              width: 200,
              child: DropdownButton<String>(
                hint: Text('Select Day of the Week'),
                value: selectedDay,
                onChanged: (String? newValue) {
                  setState(() {
                    selectedDay = newValue;
                  });
                },
                items: daysOfWeek.map((String day) {
                  return DropdownMenuItem<String>(
                    value: day,
                    child: Text(day),
                  );
                }).toList(),
                icon: Icon(
                  Icons.arrow_drop_down,
                  color: Color.fromARGB(255, 168, 16, 140),
                ),
                underline: Container(
                  height: 1,
                  color: Color.fromARGB(255, 168, 16, 140),
                ),
              ),
            ),
            SizedBox(height: 20),
            TextButton(
              onPressed: () => _selectTime(context),
              child: Text(
                selectedTime == null
                    ? 'Select Time'
                    : 'Selected Time: ${selectedTime!.format(context)}',
              ),
            ),
            SizedBox(height: 20),
            Container(
              width: 200,
              child: DropdownButton<String>(
                hint: Text('Select Activity'),
                value: selectedActivity,
                onChanged: (String? newValue) {
                  setState(() {
                    selectedActivity = newValue;
                  });
                },
                items: activities.map((String activity) {
                  return DropdownMenuItem<String>(
                    value: activity,
                    child: Text(activity),
                  );
                }).toList(),
                icon: Icon(
                  Icons.arrow_drop_down,
                  color: Color.fromARGB(255, 168, 16, 140),
                ),
                underline: Container(
                  height: 1,
                  color: Color.fromARGB(255, 168, 16, 140),
                ),
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _scheduleNotification,
              child: Text('Set Reminder'),
            ),
            SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: reminders.length,
                itemBuilder: (context, index) {
                  final reminder = reminders[index];
                  return Container(
                      margin: EdgeInsets.fromLTRB(0, 0, 0, 10),
                      decoration: BoxDecoration(
                        color: Color.fromARGB(255, 168, 16, 140),
                        borderRadius: BorderRadius.circular(15.0),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.5),
                            spreadRadius: 2,
                            blurRadius: 5,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: ListTile(
                        contentPadding: EdgeInsets.fromLTRB(30, 0, 10, 0),
                        tileColor: Colors.white,
                        title: Text(
                          '${reminder.activity} on ${reminder.day} at ${reminder.time.format(context)}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15),
                        ),
                        subtitle: Text(
                          reminder.isPlayed
                              ? 'Remainder Played'
                              : 'Remainder Pending',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 12),
                        ),
                        trailing: IconButton(
                          icon: Icon(
                            Icons.delete,
                            color: Colors.white,
                          ),
                          onPressed: () => _deleteReminder(reminder.id),
                        ),
                      ));
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class Reminder {
  final int id;
  final String day;
  final TimeOfDay time;
  final String activity;
  bool isPlayed;

  Reminder({
    required this.id,
    required this.day,
    required this.time,
    required this.activity,
    this.isPlayed = false,
  });

  factory Reminder.fromJson(Map<String, dynamic> json) {
    return Reminder(
      id: json['id'],
      day: json['day'],
      time: TimeOfDay(
        hour: json['hour'],
        minute: json['minute'],
      ),
      activity: json['activity'],
      isPlayed: json['isPlayed'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'day': day,
      'hour': time.hour,
      'minute': time.minute,
      'activity': activity,
      'isPlayed': isPlayed,
    };
  }
}
