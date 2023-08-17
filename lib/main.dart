import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:sensors/sensors.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Location Example',
      home: LocationPage(),
    );
  }
}

class LocationPage extends StatefulWidget {
  const LocationPage({Key? key}) : super(key: key);

  @override
  State<LocationPage> createState() => _LocationPageState();
}

class _LocationPageState extends State<LocationPage> {
  double _x = 0.0;
  double _y = 0.0;
  double _z = 0.0;
  double a = 0.0;
  String pesan = "Pasien Aman";

  String? _currentAddress;
  Position? _currentPosition;
  final DatabaseReference _databaseReference =
      FirebaseDatabase.instance.reference().child('data');
  
  @override
  void initState() {
    super.initState();
 _getCurrentPosition();
    accelerometerEvents.listen((AccelerometerEvent event) {
      setState(() {
        _x = event.x;
        _y = event.y;
        _z = event.z;
        if (_y < 3 && _x >= -2.5 && _x <= 1) {
          a++;
          if (a >= 15) {
            _sendLocationToFirebase(
                _currentPosition?.latitude, _currentPosition?.longitude);
            _startVibration();
            pesan = "Pasien Terjatuh";
            a = 0;
          }
        } else {
          a = 0; // Reset the counter if conditions are not met
        }
      });
    });
  }

  Future<bool> _handleLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Location services are disabled. Please enable the services')));
      return false;
    }
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permissions are denied')));
        return false;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Location permissions are permanently denied, we cannot request permissions.')));
      return false;
    }
    return true;
  }

  Future<void> _getCurrentPosition() async {
    final hasPermission = await _handleLocationPermission();

    if (!hasPermission) return;
    await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high)
        .then((Position position) {
      setState(() => _currentPosition = position);
      _getAddressFromLatLng(_currentPosition!);
    }).catchError((e) {
      debugPrint(e);
    });
  }

  Future<void> _getAddressFromLatLng(Position position) async {
    await placemarkFromCoordinates(
            _currentPosition!.latitude, _currentPosition!.longitude)
        .then((List<Placemark> placemarks) {
      Placemark place = placemarks[0];
      setState(() {
        _currentAddress =
            '${place.street}, ${place.subLocality}, ${place.subAdministrativeArea}, ${place.postalCode}';
      });
    }).catchError((e) {
      debugPrint(e);
    });
  }

  void _sendLocationToFirebase(double? latitude, double? longitude) async {
    final mapsUrl =
        'https://maps.app.goo.gl/?link=https://www.google.com/maps/place/$latitude,$longitude';
    _databaseReference.update({
      'address': mapsUrl,
      'name': "vcvcv",
      'status': "54ddd",
    });
  }

  bool _isVibrating = false;

  void _startVibration() {
    _isVibrating = true;
    _vibrateLoop();
  }

  void _stopVibration() {
    Vibration.cancel();
    setState(() {
      _isVibrating = false;
    });
  }

  void _vibrateLoop() {
    if (_isVibrating) {
      Vibration.vibrate(duration: 1000);
      Future.delayed(Duration(seconds: 1), () {
        if (_isVibrating) {
          _vibrateLoop();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Location Page")),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('LAT: ${_currentPosition?.latitude ?? ""}'),
              Text('LNG: ${_currentPosition?.longitude ?? ""}'),
              Text('ADDRESS: ${_currentAddress ?? ""}'),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _getCurrentPosition,
                child: const Text("Get Current Location"),
              ),
              ElevatedButton(
                onPressed: () => _sendLocationToFirebase(
                    _currentPosition?.latitude, _currentPosition?.longitude),
                child: const Text("Send Location to Firebase"),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text('Accelerometer Data'),
                  SizedBox(height: 16.0),
                  Text('X: $_x'),
                  SizedBox(height: 16.0),
                  Text('Y: $_y'),
                  SizedBox(height: 16.0),
                  Text('Z: $_z'),
                  SizedBox(height: 50.0),
                  Text('Counting: $a'),
                  SizedBox(height: 50.0),
                  Text('Pesan: $pesan'),
                ],
              ),
              _isVibrating
                  ? ElevatedButton(
                      onPressed: _stopVibration,
                      child: Text('Stop Vibration'),
                    )
                  : ElevatedButton(
                      onPressed: _startVibration,
                      child: Text('Start Vibration'),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
