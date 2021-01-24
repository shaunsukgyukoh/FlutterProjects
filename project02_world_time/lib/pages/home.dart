import 'package:flutter/material.dart';

class Home extends StatefulWidget {
  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> {

  Map data = {};

  @override
  Widget build(BuildContext context) {

    data = data.isNotEmpty ? data : ModalRoute.of(context).settings.arguments;// recieve data

    String bgImage = data['isDaytime'] ? 'ssoDay.png' : 'ssoNight.jpg';
    Color bgColor = data['isDaytime'] ? Colors.transparent : Colors.black12;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
          child: Container(
            decoration: BoxDecoration(
              image: DecorationImage(// allow image to apply in background
                image: AssetImage('assets/images/$bgImage'),
                fit: BoxFit.cover, //cover entire container
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 120.0, 0, 0),
              child: Column(
                children: [
                  FlatButton.icon(
                      onPressed: () async {// use .pushNamed to navigate w/ name
                        dynamic result = await Navigator.pushNamed(context, '/location'); // use await to wait until the navigator pops out w/ new contexts in choose_location.dart
                        // and use dynamic variable since we don't know what will come.
                        setState(() { // update data w/ result
                          data = {
                            'time': result['time'],
                            'location': result['location'],
                            'isDaytime': result['isDaytime'],
                            'flag': result['flag'],
                          };
                        });
                      },
                      icon: Icon(
                        Icons.edit_location,
                        color: Colors.grey[300],
                      ),
                      label: Text(
                        'edit location',
                        style: TextStyle(
                          color: Colors.grey[300],
                        ),
                      )
                  ),
                  SizedBox(height: 19.0),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        data['location'],
                        style: TextStyle(
                          fontSize: 28.0,
                          letterSpacing: 2.0,
                          color: Colors.grey[300],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 19.0),
                  Text(
                    data['time'],
                    style: TextStyle(
                      fontSize: 66,
                      color: Colors.grey[300],
                    ),
                  ),
                ],
              ),
            ),
          )
      ), // Move text widget to safe area (not behind status bar)
    );
  }
}
