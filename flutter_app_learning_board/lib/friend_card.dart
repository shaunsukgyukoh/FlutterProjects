import 'package:flutter/material.dart';
import 'package:flutter_app_learning_board/friend.dart';

class FriendCard extends StatelessWidget {
  // const FriendCard({
  //   Key key,
  // }) : super(key: key);

  final Friend friend; // Final set this var as final and not gonna be changed later, Thus, allow us to use in stless widget
  final Function delete; // Passing function as parameter
  FriendCard({ this.friend, this.delete});


  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 0.0),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              friend.name,
              style: TextStyle(
                fontSize: 18.0,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 5.0,),
            Text(
              friend.age.toString(),
              style: TextStyle(
                fontSize: 14.0,
                color: Colors.grey[800],
              ),
            ),
            SizedBox(height: 5.0,),
            FlatButton.icon(onPressed: delete, icon: Icon(Icons.delete), label: Text('delete')),
          ],
        ),
      ),
    );
  }
}


