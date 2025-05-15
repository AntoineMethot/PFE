import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.green,
          centerTitle: true,
          title: Text('ACCELEROMETER DATA'),
        ),
        body:  Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('X: ', style: TextStyle(fontSize: 18)),
                  Text('0.00', style: const TextStyle(fontSize: 18)), // Replace '0.00' with dynamic data
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Y: ', style: TextStyle(fontSize: 18)),
                  Text('0.00', style: const TextStyle(fontSize: 18)), // Replace '0.00' with dynamic data
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Z: ', style: TextStyle(fontSize: 18)),
                  Text('0.00', style: const TextStyle(fontSize: 18)), // Replace '0.00' with dynamic data
                ],
              ),
            ],
          ),
        )       // Replace the Center widget in your body with this Column widget
        
      ),
    );
  }
}