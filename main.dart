import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const cyan = Color(0xFF00E5FF);
const bg = Color(0xFF05070B);
const panel = Color(0xFF0B1018);

void main() => runApp(const EliApp());

class EliApp extends StatelessWidget {
  const EliApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ELI',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: bg,
        colorScheme: ColorScheme.fromSeed(seedColor: cyan, brightness: Brightness.dark),
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
  final input = TextEditingController();
  final messages = <Map<String,String>>[];
  final tasks = <String>[];
  String? server;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    server = p.getString('sync_url');
    final saved = p.getString('messages');
    final savedTasks = p.getString('tasks');
    if (saved != null) messages.addAll(List<Map<String,String>>.from(
      (jsonDecode(saved) as List).map((x) => Map<String,String>.from(x))));
    if (savedTasks != null) tasks.addAll(List<String>.from(jsonDecode(savedTasks)));
    if (messages.isEmpty) messages.add({'who':'ELI','text':'Online. What are you working on?'});
    setState(() {});
  }

  Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('messages', jsonEncode(messages));
    await p.setString('tasks', jsonEncode(tasks));
  }

  Future<void> sync() async {
    if (server == null || server!.isEmpty) return;
    try {
      await http.post(Uri.parse('$server/sync'),
        headers: {'Content-Type':'application/json'},
        body: jsonEncode({'messages':messages,'tasks':tasks}));
    } catch (_) {}
  }

  Future<void> send() async {
    final text = input.text.trim();
    if (text.isEmpty) return;
    input.clear();
    setState(() => messages.add({'who':'YOU','text':text}));
    await save();
    await sync();

    // The mobile client can call the PC/self-hosted AI gateway.
    if (server != null && server!.isNotEmpty) {
      try {
        final r = await http.post(Uri.parse('$server/chat'),
          headers: {'Content-Type':'application/json'},
          body: jsonEncode({'message':text}));
        if (r.statusCode == 200) {
          final answer = (jsonDecode(r.body)['answer'] ?? 'I am ready.').toString();
          setState(() => messages.add({'who':'ELI','text':answer}));
          await save();
          await sync();
        }
      } catch (_) {
        setState(() => messages.add({'who':'ELI','text':'I could not reach the sync server.'}));
      }
    } else {
      setState(() => messages.add({'who':'ELI','text':'Connect a sync server in Settings to enable cloud/PC sync.'}));
    }
  }

  void addTask() {
    final c = TextEditingController();
    showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text('NEW TASK'),
      content: TextField(controller:c, autofocus:true, decoration:const InputDecoration(hintText:'What needs doing?')),
      actions:[TextButton(onPressed:()=>Navigator.pop(context), child:const Text('CANCEL')),
        FilledButton(onPressed:() { if(c.text.trim().isNotEmpty) { setState(()=>tasks.add(c.text.trim())); save(); sync(); } Navigator.pop(context); }, child:const Text('ADD'))],
    ));
  }

  Future<void> settings() async {
    final c = TextEditingController(text: server ?? '');
    await showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text('SYNC SERVER'),
      content: TextField(controller:c, decoration:const InputDecoration(hintText:'http://192.168.x.x:8000')),
      actions:[TextButton(onPressed:()=>Navigator.pop(context), child:const Text('CANCEL')),
        FilledButton(onPressed:() async {
          final p=await SharedPreferences.getInstance();
          server=c.text.trim();
          await p.setString('sync_url', server!);
          if(mounted) Navigator.pop(context);
          setState((){});
        }, child:const Text('SAVE'))],
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: bg,
        title: const Column(crossAxisAlignment:CrossAxisAlignment.start, children:[
          Text('E L I', style:TextStyle(color:cyan,fontWeight:FontWeight.bold,letterSpacing:6)),
          Text('WORK INTELLIGENCE', style:TextStyle(fontSize:9,color:Colors.white54,letterSpacing:2))
        ]),
        actions:[
          IconButton(onPressed:addTask, icon:const Icon(Icons.add_task,color:cyan)),
          IconButton(onPressed:settings, icon:const Icon(Icons.settings_outlined))
        ],
      ),
      body: Column(children:[
        Container(
          margin:const EdgeInsets.all(14), padding:const EdgeInsets.all(18),
          decoration:BoxDecoration(color:panel,borderRadius:BorderRadius.circular(20),border:Border.all(color:cyan.withOpacity(.25))),
          child:Row(children:[
            const Text('◉', style:TextStyle(fontSize:48,color:cyan)),
            const SizedBox(width:16),
            Column(crossAxisAlignment:CrossAxisAlignment.start, children:[
              const Text('ELI CORE',style:TextStyle(fontWeight:FontWeight.bold)),
              Text(server==null?'LOCAL MODE':'SYNC LINK ACTIVE',style:const TextStyle(color:Colors.white54,fontSize:11))
            ])
          ])
        ),
        Expanded(child:ListView.builder(
          padding:const EdgeInsets.symmetric(horizontal:14),
          itemCount:messages.length,
          itemBuilder:(c,i){
            final m=messages[i];
            return Align(
              alignment:m['who']=='YOU'?Alignment.centerRight:Alignment.centerLeft,
              child:Container(
                constraints:const BoxConstraints(maxWidth:340),
                margin:const EdgeInsets.symmetric(vertical:5),
                padding:const EdgeInsets.all(13),
                decoration:BoxDecoration(color:m['who']=='YOU'?const Color(0xFF103641):panel,borderRadius:BorderRadius.circular(14)),
                child:Text('${m['who']}: ${m['text']}',style:const TextStyle(color:Colors.white)),
              ));
          })),
        SafeArea(child:Padding(
          padding:const EdgeInsets.all(12),
          child:Row(children:[
            Expanded(child:TextField(controller:input,onSubmitted:(_)=>send(),decoration:InputDecoration(hintText:'Talk to Eli...',filled:true,fillColor:panel,border:OutlineInputBorder(borderRadius:BorderRadius.circular(16),borderSide:BorderSide.none)))),
            const SizedBox(width:8),
            IconButton(onPressed:send, icon:const Icon(Icons.arrow_upward_rounded,color:cyan,size:30))
          ])))
      ])
    );
  }
}
