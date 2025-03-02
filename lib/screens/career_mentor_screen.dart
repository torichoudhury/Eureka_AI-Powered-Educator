import 'package:flutter/material.dart';
import '../gemini_ai.dart';

class AiCareerMentorScreen extends StatefulWidget {
  const AiCareerMentorScreen({super.key});

  @override
  State<AiCareerMentorScreen> createState() {
    return _AiCareerMentorScreenState();
  }
}

class _AiCareerMentorScreenState extends State<AiCareerMentorScreen> {
  final TextEditingController _questionController = TextEditingController();
  String aiResponse = '';
  List<String> suggestedPaths = [];
  bool isThinking = false;
  List<Map<String, dynamic>> chatHistory = [];
  
  void askAi() async {
    if (_questionController.text.trim().isEmpty) return;

    final userQuestion = _questionController.text;

    setState(() {
      isThinking = true;
      chatHistory.add({
        'isUser': true,
        'message': userQuestion,
        'timestamp': DateTime.now(),
      });
      _questionController.clear();
    });

    final prompt = '''
  Based on the following question, provide a concise response (maximum 100 words) and suggest 3 learning paths or resources that can help the user achieve their career goals. 
  
  Format your response as a single paragraph without bullet points or stars. 
  
  For the learning paths, place each one on a separate line without any bullet points, stars or numbering.

  Question: $userQuestion
  ''';

    final responseText = await generateResponse(prompt);

    // Handle nullable responseText
    if (responseText == null) {
      setState(() {
        isThinking = false;
        aiResponse = "Sorry, I couldn't generate a response. Please try again.";
        chatHistory.add({
          'isUser': false,
          'message': aiResponse,
          'timestamp': DateTime.now(),
          'suggestedPaths': <String>[],
        });
      });
      return;
    }

    // Parse the response to extract suggested paths
    final responseLines = responseText.split('\n');
    
    // Extract main response (everything before the first empty line)
    String mainResponse = "";
    List<String> paths = [];
    bool foundEmptyLine = false;
    
    for (int i = 0; i < responseLines.length; i++) {
      String line = responseLines[i].trim();
      
      if (line.isEmpty && !foundEmptyLine) {
        // First empty line marks the separation between response and paths
        foundEmptyLine = true;
        mainResponse = responseLines.sublist(0, i).join(' ').trim();
        continue;
      }
      
      if (foundEmptyLine && line.isNotEmpty) {
        // Clean any potential stars, dashes, numbers at the beginning
        String cleanLine = line.replaceAll(RegExp(r'^\s*[\*\-•\d.]\s*'), '');
        paths.add(cleanLine);
        if (paths.length >= 3) break; // Limit to 3 paths
      }
    }
    
    // If no clear separation was found, use first line as response and rest as paths
    if (!foundEmptyLine) {
      mainResponse = responseLines.isNotEmpty ? responseLines[0] : responseText;
      paths = responseLines.skip(1)
          .where((line) => line.trim().isNotEmpty)
          .take(3)
          .map((line) => line.replaceAll(RegExp(r'^\s*[\*\-•\d.]\s*'), ''))
          .toList();
    }

    setState(() {
      isThinking = false;
      aiResponse = mainResponse;
      suggestedPaths = paths;

      chatHistory.add({
        'isUser': false,
        'message': aiResponse,
        'timestamp': DateTime.now(),
        'suggestedPaths': suggestedPaths,
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: Text(
          'AI Career Mentor',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [
              Color(0xFF1A2980),
              Color(0xFF26D0CE),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Chat History
              Expanded(
                child: chatHistory.isEmpty
                    ? _buildWelcomeView()
                    : ListView.builder(
                        padding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                        itemCount: chatHistory.length + (isThinking ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (isThinking && index == chatHistory.length) {
                            return _buildThinkingBubble();
                          }

                          final chat = chatHistory[index];
                          return _buildChatBubble(
                            isUser: chat['isUser'] as bool,
                            message: chat['message'] as String,
                            suggestedPaths: chat['suggestedPaths'] != null
                                ? List<String>.from(
                                    chat['suggestedPaths'] as List)
                                : null,
                          );
                        },
                      ),
              ),

              // Quick Suggestions
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: Colors.white.withOpacity(0.1),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
                      child: Text(
                        'Quick Questions:',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildQuickSuggestionButton(
                            'Best remote jobs for me?',
                            Icons.work_outline,
                          ),
                          _buildQuickSuggestionButton(
                            'How to prepare for an interview?',
                            Icons.record_voice_over_outlined,
                          ),
                          _buildQuickSuggestionButton(
                            'What skills do I need for a tech job?',
                            Icons.lightbulb_outline,
                          ),
                          _buildQuickSuggestionButton(
                            'How to negotiate salary?',
                            Icons.attach_money,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Input Area
              Container(
                padding: EdgeInsets.all(16),
                color: Colors.white,
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _questionController,
                        decoration: InputDecoration(
                          hintText: 'Ask about your career...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 20, vertical: 16),
                          prefixIcon: Icon(Icons.person_outline,
                              color: Color(0xFF1A2980)),
                        ),
                        textCapitalization: TextCapitalization.sentences,
                      ),
                    ),
                    SizedBox(width: 8),
                    FloatingActionButton(
                      onPressed: askAi,
                      backgroundColor: Color(0xFF1A2980),
                      child: Icon(Icons.send),
                      mini: true,
                      elevation: 2,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeView() {
    return Container(
      padding: EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(50),
            ),
            child: Icon(
              Icons.psychology,
              size: 50,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 24),
          Text(
            'Your AI Career Mentor',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16),
          Text(
            'Ask any career-related questions to get personalized advice and learning resources.',
            style:
                TextStyle(fontSize: 16, color: Colors.white.withOpacity(0.9)),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 32),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.lightbulb_outline, color: Colors.yellow),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Try asking about:',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                _buildSuggestionItem('Career transitions'),
                _buildSuggestionItem('Skill development paths'),
                _buildSuggestionItem('Interview preparation'),
                _buildSuggestionItem('Industry trends'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('•', style: TextStyle(color: Colors.white, fontSize: 16)),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: Colors.white.withOpacity(0.9)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickSuggestionButton(String text, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ElevatedButton.icon(
        onPressed: () {
          _questionController.text = text;
          askAi();
        },
        icon: Icon(icon, size: 16),
        label: Text(text),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF1A2980),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        ),
      ),
    );
  }

  Widget _buildChatBubble({
    required bool isUser,
    required String message,
    List<String>? suggestedPaths,
  }) {
    return Padding(
      padding: EdgeInsets.only(
        left: isUser ? 60 : 16,
        right: isUser ? 16 : 60,
        bottom: 16,
      ),
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isUser ? Colors.white : Color(0xFF1A2980).withOpacity(0.8),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomLeft: isUser ? Radius.circular(16) : Radius.circular(4),
                bottomRight: isUser ? Radius.circular(4) : Radius.circular(16),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 5,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: TextStyle(
                    color: isUser ? Color(0xFF1A2980) : Colors.white,
                  ),
                ),
              ],
            ),
          ),

          // Display suggested paths if available
          if (suggestedPaths != null && suggestedPaths.isNotEmpty) ...[
            SizedBox(height: 8),
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 5,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Suggested Learning Paths:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A2980),
                    ),
                  ),
                  SizedBox(height: 8),
                  ...suggestedPaths
                      .map((path) => Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Row(
                              children: [
                                Icon(Icons.school,
                                    size: 16, color: Color(0xFF26D0CE)),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    path,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ))
                      .toList(),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildThinkingBubble() {
    return Padding(
      padding: EdgeInsets.only(left: 16, right: 60, bottom: 16),
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Color(0xFF1A2980).withOpacity(0.8),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(16),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            SizedBox(width: 12),
            Text(
              'Thinking...',
              style: TextStyle(
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}