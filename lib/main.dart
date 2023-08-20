import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:safeguarduser/shared/theme.dart';
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
      debugShowCheckedModeBanner: false,
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
  String pesan = "Patient Safe";
  String _applicationStatus = "Application Active";

  String? _currentAddress;
  Position? _currentPosition;
  final DatabaseReference _databaseReference =
      FirebaseDatabase.instance.reference().child('data');
  bool _isAccelerometerActive = false;
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  @override
  void initState() {
    super.initState();
    _isAccelerometerActive = false;
    // if (!_isAccelerometerActive) {
    //   _getCurrentPosition();

    //   accelerometerEvents.listen((AccelerometerEvent event) {
    //     setState(() {
    //       _x = event.x;
    //       _y = event.y;
    //       _z = event.z;
    //       if (_y < 3 && _x >= -2.5 && _x <= 1) {
    //         a++;
    //         if (a >= 15) {
    //           _sendLocationToFirebase(
    //               _currentPosition?.latitude, _currentPosition?.longitude);
    //           _startVibration();
    //           pesan = "Alert !!! Patient Fallen";
    //           a = 0;
    //         }
    //       } else {
    //         a = 0; // Reset the counter if conditions are not met
    //         setState(() {
    //           _isVibrating = false;
    //         });
    //         pesan = "Patient Safe";
    //       }
    //     });
    //   });
    // } else {
    //   accelerometerEvents.listen((AccelerometerEvent event) {
    //     _stopVibration();
    //     setState(() {
    //       _isVibrating = false;
    //     });
    //   });
    // }
  }

  void _stopAccelerometer() {
    _stopVibration();
    setState(() {
      a = 0;
      _x = 0;
      _y = 0;
      _z - 0;
      pesan = "Patient Safe";
      _isAccelerometerActive = false;
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

  void _sendLocationToFirebase(
      double? latitude, double? longitude, String? address) async {
    final mapsUrl =
        'https://www.google.com/maps/place/$latitude,$longitude';
    _databaseReference.update({
      'address': mapsUrl,
      'name': "Patient",
      'status': "yes",
      'timestamp': DateTime.now().toString(),
      'position': address,
      'latitude': latitude,
      'longitude': longitude
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
      Future.delayed(Duration(milliseconds: 400), () {
        if (_isVibrating) {
          _vibrateLoop();
        }
      });
    }
  }

  Future<void> _showStatusAlertDialog() async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Patient Fallen!!!!',
            style: redTextStyle.copyWith(
              fontSize: 16,
              fontWeight: semiBold,
            ),
          ),
          content: Text('Have you treated the patient?',
              style: blackTextStyle.copyWith(
                fontSize: 14,
                fontWeight: medium,
              )),
          actions: <Widget>[
            TextButton(
              child: Text(
                'No',
                style: blackTextStyle.copyWith(
                  fontSize: 16,
                  fontWeight: medium,
                ),
              ),
              onPressed: () {
                _stopVibration();

                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text(
                'Yes',
                style: blackTextStyle.copyWith(
                  fontSize: 16,
                  fontWeight: medium,
                ),
              ),
              onPressed: () {
                _stopAccelerometerEvents();
                setState(() {
                  _x = 0;
                  _y = 0;
                  _z = 0;
                });

                _stopAccelerometer();
                Map<String, dynamic> updatedData = {
                  'status': 'no',
                };
                a = 0;
                _databaseReference.update(updatedData).then((_) {
                  print("Data updated successfully");
                }).catchError((error) {
                  print("Failed to update data: $error");
                });
                setState(() {
                  _isAccelerometerActive = false;
                });
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _toggleAccelerometer() {
    setState(() {
      // Toggle _isAccelerometerActive status
      _isAccelerometerActive = !_isAccelerometerActive;

      if (_isAccelerometerActive) {
        // Start listening to accelerometer events
        _getCurrentPosition();
        _accelerometerSubscription =
            accelerometerEvents.listen((AccelerometerEvent event) {
          setState(() {
            _x = event.x;
            _y = event.y;
            _z = event.z;
            if (_y < 3 && _x >= -2.5 && _x <= 1) {
              a++;
              if (a >= 15) {
                _sendLocationToFirebase(_currentPosition?.latitude,
                    _currentPosition?.longitude, _currentAddress);
                _startVibration();
                _showStatusAlertDialog();
                pesan = "Alert !!! Patient Fallen";
                a = 0;
              }
            } else {
              a = 0; // Reset the counter if conditions are not met
              Map<String, dynamic> updatedData = {
                'status': 'no',
              };
              a = 0;
              _databaseReference.update(updatedData).then((_) {
                print("Data updated successfully");
              }).catchError((error) {
                print("Failed to update data: $error");
              });
              setState(() {
                _isVibrating = false;
              });
              pesan = "Patient Safe";
            }
          });
        });
      }
    });
  }

  void _stopAccelerometerEvents() {
    if (_accelerometerSubscription != null) {
      _accelerometerSubscription!.cancel();
      _accelerometerSubscription = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          backgroundColor: greenColor,
          title: Text(
            "Safeguard Sensor",
            style: whiteTextStyle.copyWith(
              fontSize: 20,
              fontWeight: semiBold,
            ),
          )),
      body: SingleChildScrollView(
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              SizedBox(
                height: 40,
              ),
              Center(
                child: Text(
                  "Would you like to activate this application?",
                  style: blackTextStyle.copyWith(
                    fontSize: 20,
                    fontWeight: semiBold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              SizedBox(
                height: 16,
              ),
              ElevatedButton(
                onPressed: _toggleAccelerometer,
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  primary: _isAccelerometerActive
                      ? redColor
                      : greenColor, // Set your desired background color here
                ),
                child: Text(
                  _isAccelerometerActive ? 'Turn OFF' : 'Turn ON',
                  style: whiteTextStyle.copyWith(
                    fontSize: 20,
                    fontWeight: semiBold,
                  ),
                ),
              ),
              SizedBox(
                height: 16,
              ),
              _isAccelerometerActive
                  ? Container(
                      margin: EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Data Location',
                            style: blackTextStyle.copyWith(
                              fontSize: 22,
                              fontWeight: semiBold,
                            ),
                          ),
                          SizedBox(
                            height: 12,
                          ),
                          Text(
                            'Latitude: ${_currentPosition?.latitude ?? ""}',
                            style: blackTextStyle.copyWith(
                              fontSize: 16,
                              fontWeight: medium,
                            ),
                          ),
                          SizedBox(
                            height: 12,
                          ),
                          Text(
                            'Longitude: ${_currentPosition?.longitude ?? ""}',
                            style: blackTextStyle.copyWith(
                              fontSize: 16,
                              fontWeight: medium,
                            ),
                          ),
                          SizedBox(
                            height: 12,
                          ),
                          Text(
                            'Address: ${_currentAddress ?? ""}',
                            style: blackTextStyle.copyWith(
                              fontSize: 16,
                              fontWeight: medium,
                            ),
                          ),
                          SizedBox(
                            height: 12,
                          ),
                          Text(
                            'Accelerometer Sensor Data',
                            style: blackTextStyle.copyWith(
                              fontSize: 22,
                              fontWeight: semiBold,
                            ),
                          ),
                          SizedBox(
                            height: 12,
                          ),
                          Text(
                            'X: $_x',
                            style: blackTextStyle.copyWith(
                              fontSize: 16,
                              fontWeight: medium,
                            ),
                          ),
                          SizedBox(height: 16.0),
                          Text(
                            'Y: $_y',
                            style: blackTextStyle.copyWith(
                              fontSize: 16,
                              fontWeight: medium,
                            ),
                          ),
                          SizedBox(height: 16.0),
                          Text(
                            'Z: $_z',
                            style: blackTextStyle.copyWith(
                              fontSize: 16,
                              fontWeight: medium,
                            ),
                          ),
                          SizedBox(height: 16.0),
                          Text(
                            'Counting: $a',
                            style: blackTextStyle.copyWith(
                              fontSize: 16,
                              fontWeight: medium,
                            ),
                          ),
                          SizedBox(height: 16.0),
                          Text(
                            'Data Location',
                            style: blackTextStyle.copyWith(
                              fontSize: 22,
                              fontWeight: semiBold,
                            ),
                          ),
                          SizedBox(height: 12.0),
                          Text(
                            'Pesan: $pesan',
                            style: blackTextStyle.copyWith(
                              fontSize: 16,
                              fontWeight: medium,
                            ),
                          ),
                          SizedBox(height: 30.0),
                        ],
                      ),
                    )
                  : SizedBox(),
            ],
          ),
        ),
      ),
    );
  }
}
