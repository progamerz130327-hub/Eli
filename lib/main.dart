import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const Color eliCyan = Color(0xFF00E5FF);
const Color background = Color(0xFF05070B);
const Color panel = Color(0xFF0B1018);

void main() {
  runApp(const EliApp());
}

class EliApp extends StatelessWidget {
  const EliApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ELI',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: eliCyan,
          brightness: Brightness.dark,
        ),
        fontFamily: 'sans',
      ),
      home: const EliHome(),
    );
  }
}

class EliHome extends StatefulWidget {
  const EliHome({super.key});

  @override
  State<EliHome> createState() => _EliHomeState();
}

class _EliHomeState extends State<EliHome> {
  final TextEditingController inputController = TextEditingController();

  final List<Map<String, String>> messages = [];
  final List<String> tasks = [];

  String? syncServer;
  bool syncing = false;

  @override
  void initState() {
    super.initState();
    loadData();
  }

  @override
  void dispose() {
    inputController.dispose();
    super.dispose();
  }

  Future<void> loadData() async {
    final prefs = await SharedPreferences.getInstance();

    syncServer = prefs.getString('sync_url');

    final savedMessages = prefs.getString('messages');
    final savedTasks = prefs.getString('tasks');

    if (savedMessages != null) {
      final decoded = jsonDecode(savedMessages) as List;

      messages.addAll(
        decoded.map(
          (item) => Map<String, String>.from(item),
        ),
      );
    }

    if (savedTasks != null) {
      tasks.addAll(
        List<String>.from(jsonDecode(savedTasks)),
      );
    }

    if (messages.isEmpty) {
      messages.add({
        'who': 'ELI',
        'text':
            'Online. I\\'m Eli. Tell me what you\\'re working on and I\\'ll help you.',
      });
    }

    setState(() {});
  }

  Future<void> saveData() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      'messages',
      jsonEncode(messages),
    );

    await prefs.setString(
      'tasks',
      jsonEncode(tasks),
    );
  }

  Future<void> syncData() async {
    if (syncServer == null || syncServer!.isEmpty) {
      return;
    }

    try {
      syncing = true;
      setState(() {});

      await http.post(
        Uri.parse('$syncServer/sync'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'messages': messages,
          'tasks': tasks,
        }),
      );
    } catch (_) {
      // Keep Eli usable even if the sync server is unavailable.
    } finally {
      syncing = false;
      setState(() {});
    }
  }

  Future<void> sendMessage() async {
    final text = inputController.text.trim();

    if (text.isEmpty) {
      return;
    }

    inputController.clear();

    setState(() {
      messages.add({
        'who': 'YOU',
        'text': text,
      });
    });

    await saveData();
    await
