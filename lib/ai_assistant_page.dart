import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'dart:ui';

class AIAssistantPage extends StatefulWidget {
  const AIAssistantPage({super.key});

  @override
  State<AIAssistantPage> createState() => _AIAssistantPageState();
}

class _AIAssistantPageState extends State<AIAssistantPage> {
  final TextEditingController _chatCtrl = TextEditingController();
  final List<Map<String, String>> _messages = [];
  bool _isTyping = false;

  // ILAGAY DITO ANG API KEY MO (mula sa Google AI Studio)
  final String _apiKey = "AIzaSyCdbZAyddAKPrAuvhn9n0xADCC7HSREcN8";

  late GenerativeModel _model;

  @override
  void initState() {
    super.initState();
    _model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: _apiKey);
  }

  Future<void> _sendMessage() async {
    if (_chatCtrl.text.isEmpty) return;

    String userMsg = _chatCtrl.text;
    setState(() {
      _messages.add({"role": "user", "text": userMsg});
      _isTyping = true;
    });
    _chatCtrl.clear();

    try {
      // Context para maging "Emergency Assistant" ang AI
      final prompt = [Content.text("You are AI-RES Emergency Assistant. Be concise and helpful. User says: $userMsg")];
      final response = await _model.generateContent(prompt);

      setState(() {
        _messages.add({"role": "ai", "text": response.text ?? "Sorry, I can't think right now."});
      });
    } catch (e) {
      setState(() {
        _messages.add({"role": "ai", "text": "Error: Connection failed."});
      });
    } finally {
      setState(() => _isTyping = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text("AI-RES ASSISTANT"), backgroundColor: Colors.transparent, elevation: 0),
      body: Stack(
        children: [
          // Background Gradient (Match sa main.dart)
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.black, Colors.blueAccent, Colors.black],
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
              ),
            ),
          ),
          Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(15),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    bool isUser = _messages[index]["role"] == "user";
                    return Align(
                      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 5),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isUser ? Colors.blueAccent.withOpacity(0.8) : Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Text(_messages[index]["text"]!, style: const TextStyle(color: Colors.white)),
                      ),
                    );
                  },
                ),
              ),
              if (_isTyping) const Padding(padding: EdgeInsets.all(8.0), child: LinearProgressIndicator()),

              // Input Box with Glassmorphism
              Padding(
                padding: const EdgeInsets.all(20),
                child: ClipRRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 15),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _chatCtrl,
                              style: const TextStyle(color: Colors.white),
                              decoration: const InputDecoration(hintText: "Type emergency question...", hintStyle: TextStyle(color: Colors.white54), border: InputBorder.none),
                            ),
                          ),
                          IconButton(icon: const Icon(Icons.send, color: Colors.blueAccent), onPressed: _sendMessage),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}