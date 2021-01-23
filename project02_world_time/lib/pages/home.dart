import 'package:flutter/material.dart';

class Home extends StatefulWidget {
  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> {

  Map data = {};

  @override
  Widget build(BuildContext context) {

    data = ModalRoute.of(context).settings.arguments;// recieve data
    print(data);

    return Scaffold(
      body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 120.0, 0, 0),
            child: Column(
              children: [
                FlatButton.icon(
                    onPressed: () {
                      Navigator.pushNamed(context, '/location');// use .pushNamed to navigate w/ name
                    },
                    icon: Icon(Icons.edit_location),
                    label: Text('edit location')
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
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 19.0),
                Text(
                  data['time'],
                  style: TextStyle(
                    fontSize: 66,
                  ),
                ),
              ],
            ),
          )
      ), // Move text widget to safe area (not behind status bar)
    );
  }
}
