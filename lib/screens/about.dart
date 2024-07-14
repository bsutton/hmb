import 'package:flutter/material.dart';

import '../version/version.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar:
          AppBar(title: const Text('About'), automaticallyImplyLeading: false),
      body: Center(
          child: Column(
        children: [
          const Text("Hold My Beer (HMB) - I'm a handyman"),
          Text('Version: $hmbVersion'),
          const Text('Author: S. Brett Sutton'),
        ],
      )));
}
