import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(MyApp());

  // Establecer la orientación de la pantalla a solo vertical
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp, // Vertical normal
    DeviceOrientation.portraitDown, // Vertical invertida
  ]).then((_) {
    runApp(MyApp());
  });
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tienda Productos',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.lightBlue,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        typography: Typography.material2021(),
        fontFamily: 'Roboto',
      ),
      home: HomeScreen(),
    );
  }
}
