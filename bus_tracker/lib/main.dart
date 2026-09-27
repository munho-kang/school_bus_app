// 앱 진입점. BusService를 Provider로 등록하고 첫 화면(HomePage)을 렌더한다.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/bus_service.dart';
import 'ui/board.dart';
import 'ui/home_page.dart';

void main() {
  final service = BusService();
  runApp(
    ChangeNotifierProvider<BusService>(
      create: (_) => service,
      child: const MyApp(),
     ),
   );
}

class MyApp extends StatelessWidget {
   const MyApp({super.key});

   @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '제주대 순환버스',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      home: const HomePage(),
     );
   }
}
