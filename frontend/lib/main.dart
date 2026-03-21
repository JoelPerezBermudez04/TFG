import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData.from(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'Flutter + Django Demo'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String message = "Carregant...";

  @override
  void initState() {
    super.initState();
    fetchMessage();
  }

  fetchMessage() async {
    try {
      // ⚠️ CANVIA AQUÍ LA IP pel teu PC
      final response = await http.get(Uri.parse('http://127.0.0.1:8000/api/'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          message = data['message'];
        });
      } else {
        setState(() {
          message = "Error: ${response.statusCode}";
        });
      }
    } catch (e) {
      setState(() {
        message = "Error: $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Center(
        child: Text(message, style: const TextStyle(fontSize: 24)),
      ),
    );
  }
}