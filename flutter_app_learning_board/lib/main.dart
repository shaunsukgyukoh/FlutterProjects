import 'package:flutter/material.dart';
import 'package:flutter_app_learning_board/friend.dart';
import 'package:flutter_app_learning_board/friend_card.dart';

void main() => runApp(MaterialApp(
  home: FriendsLists(),
));

class FriendsLists extends StatefulWidget {
  @override
  _FriendsListsState createState() => _FriendsListsState();
}

class _FriendsListsState extends State<FriendsLists> {
  List<Friend> friends = [
    Friend(name: 'sso', age: 22),
    Friend(name: 'tam2burin', age: 522),
    Friend(name: 'yoosona', age: 6),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        title: Text("My friends"),
        centerTitle: true,
        backgroundColor: Colors.redAccent,
      ),
      body: Column(
        children: friends.map((friend) => FriendCard(
          friend: friend,
          delete: (){
            setState((){
              friends.remove(friend);
            });
          }
        )).toList(), // if you want to output var which require property, must cover w/ curly braces
      ),
    );
  }
}

