// app.dart — root MaterialApp
import 'package:flutter/material.dart';
import 'routes.dart';
import 'theme/theme.dart';

class KaiqiuApp extends StatelessWidget {
  const KaiqiuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: '开球',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      routerConfig: router,
    );
  }
}
