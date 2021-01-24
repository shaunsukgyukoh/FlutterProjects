import 'dart:math';

import 'package:http/http.dart';
import 'dart:convert';
import 'package:intl/intl.dart'; // Used for formatting datetime

class WorldTime {

  String location; // location name for the UI
  String time; // time in that location
  String flag; // url to an asset flag icon
  String url; // location url for API endpoint
  bool isDaytime; // true or false if daytime or not

  WorldTime({ this.location, this.flag, this.url});

  Future<void> getTime() async {

    try {
      // make the request
      Response response = await get('http://worldtimeapi.org/api/timezone/$url'); // add 's' to timezone to simulate error
      Map data = jsonDecode(response.body);

      // get properties from data
      String datetime = data['datetime'];
      String offset = data['utc_offset'].substring(1,3);

      // create DateTime obj.
      DateTime now = DateTime.parse(datetime);
      now = now.add(Duration(hours: int.parse(offset)));

      isDaytime = now.hour > 6 && now.hour < 20 ? true : false;
      time = DateFormat.jm().format(now); // Widget provided by intl package
    }catch(e){
      print('caught error: $e');
      time = 'could not get time data';
    }
  }
}
