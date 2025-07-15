import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:workmanager/workmanager.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  Workmanager().initialize(callbackDispatcher, isInDebugMode: true);
  runApp(const MyApp());
}

// Callback function to handle background tasks
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      Position position = await _getCurrentLocation();
      final geolocation = "${position.latitude}, ${position.longitude}";
      await _sendGeoLocation(geolocation);
    } catch (e) {
      print('Error in background task: $e');
    }
    return Future.value(true);
  });
}

// Function to send geolocation to the server
Future<void> _sendGeoLocation(String geolocation) async {
  try {
    final response = await http.post(
      Uri.parse('https://livetrack.pakarit.sbs/creatego.php'),
      body: {'geolocation': geolocation},
    );
    if (response.statusCode == 200) {
      print('Geolocation sent successfully');
    } else {
      print('Failed to send geolocation: ${response.statusCode}');
    }
  } catch (e) {
    print('Error sending geolocation: $e');
  }
}

// Function to get the current location
Future<Position> _getCurrentLocation() async {
  bool serviceEnabled;
  LocationPermission permission;

  serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    throw 'Location services are disabled.';
  }

  permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      throw 'Location permissions are denied';
    }
  }

  if (permission == LocationPermission.deniedForever) {
    throw 'Location permissions are permanently denied, we cannot request permissions.';
  }

  return await Geolocator.getCurrentPosition();
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PAKAR GPS',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.deepPurple),
      ),
      home: const GeolocationApp(),
    );
  }
}

class GeolocationApp extends StatefulWidget {
  const GeolocationApp({Key? key}) : super(key: key);

  @override
  State<GeolocationApp> createState() => _GeolocationAppState();
}

class _GeolocationAppState extends State<GeolocationApp> {
  String? _currentLocation;
  Timer? _timer;
  bool _isFetching = true;

  @override
  void initState() {
    super.initState();
    _startFetchingLocation();
  }

  void _startFetchingLocation() {
    _timer = Timer.periodic(Duration(seconds: 5), (Timer timer) {
      if (_isFetching) {
        _getCurrentLocation().then((Position position) {
          setState(() {
            _currentLocation = "${position.latitude}, ${position.longitude}";
          });
          _sendGeoLocation(_currentLocation!);
        }).catchError((e) {
          print('Error getting location: $e');
        });
      }
    });

    Workmanager().registerPeriodicTask(
      "1",
      "simplePeriodicTask",
      frequency: Duration(minutes: 15),
    );
  }

  void _stopFetchingLocation() {
    _timer?.cancel();
    Workmanager().cancelAll();
  }

  @override
  void dispose() {
    _stopFetchingLocation();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Geolocation App'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              "Location coordinates",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(_currentLocation ?? "Coordinates"),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () async {
                try {
                  Position position = await _getCurrentLocation();
                  setState(() {
                    _currentLocation = "${position.latitude}, ${position.longitude}";
                  });
                  await _sendGeoLocation(_currentLocation!);
                } catch (e) {
                  print("Error getting location: $e");
                }
              },
              child: const Text("Get Location"),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _isFetching = !_isFetching;
                });
                if (_isFetching) {
                  _startFetchingLocation();
                } else {
                  _stopFetchingLocation();
                }
              },
              child: Text(_isFetching ? "Stop Fetching" : "Start Fetching"),
            ),
          ],
        ),
      ),
    );
  }
}
