import 'package:flutter/material.dart';
import 'package:project02_world_time/services/world_time.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart'; // Using spinner

class Loading extends StatefulWidget {
  @override
  _LoadingState createState() => _LoadingState();
}

class _LoadingState extends State<Loading> {

  void setupWorldTime() async {
    WorldTime instance = WorldTime(location: 'Seoul', flag: 'korea.png', url: 'Asia/Seoul');
    await instance.getTime(); // To use await for the custom function, we have to add 'Future<type>' keyword in front of getTime() function.
    Navigator.pushReplacementNamed(context, '/home', arguments: { // using arguments property to send data to /home route
      'location': instance.location,
      'flag': instance.flag,
      'time': instance.time,
    });
  }

  @override
  void initState() {
    super.initState();
    setupWorldTime();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue[900],
      body: Center(
        child: SpinKitRotatingCircle(
          color: Colors.white,
          size: 50.0,
        ),

      ),
    );
  }
}
