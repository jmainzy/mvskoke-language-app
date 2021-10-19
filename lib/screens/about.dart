import 'package:flutter/material.dart';

class About extends StatelessWidget {

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
        "Mvskoke Language"
        )
      ),
      body: Container(
        child: Text("About info here."),
      ),
    );
  }

}