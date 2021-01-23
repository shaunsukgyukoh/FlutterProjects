import 'package:flutter/material.dart';
import 'package:project02_world_time/pages/choose_location.dart';
import 'package:project02_world_time/pages/home.dart';
import 'package:project02_world_time/pages/loading.dart';

void main() {
  runApp(MaterialApp(
    // home: Home(), // delete since it conflicts w/ '/' in routes. --> instead, use initialRoute.
    initialRoute: '/', // '/' is default but we can override it.
    routes: {
      '/': (context) => Loading(), // '/' indicate first route and context keep track of where we are on widget tree
      '/home': (context) => Home(),
      '/location': (context) => ChooseLocation(),
    },
  ));
}

