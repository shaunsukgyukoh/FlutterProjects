class Friend {
  String name;
  int age;

  // // Way 1
  // Friend(String name, int age){ // Constructor
  //   this.name = name;
  //   this.age = age;
  // }

  // // Way 2: named parameter
  // Friend({String name, int age}){ // Constructor
  //   this.name = name;
  //   this.age = age;
  // }

  // Way 3: Simpler way 2
  Friend({this.name, this.age});

}

/*
// making new Friend obj.
Friend myFriend = Friend("Hi", 21);

// another way to assign values: named parameter: param order does not matter
Friend myFriend = Friend(name: "Hi", age: 21);
 */