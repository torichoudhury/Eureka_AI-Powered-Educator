import 'package:flutter/material.dart';
import '../gemini_ai.dart'; // Import the generateResponse function
import 'dart:convert';

class AiTutorScreen extends StatefulWidget {
  const AiTutorScreen({super.key});

  @override
  State<AiTutorScreen> createState() {
    return _AiTutorScreenState();
  }
}

class _AiTutorScreenState extends State<AiTutorScreen> {
  final TextEditingController _questionController = TextEditingController();
  String aiResponse = '';
  List<Map<String, dynamic>> quizQuestions = [];
  bool showQuiz = false;
  bool isLoading = false;
  final int maxWordLimit = 300; // Maximum word limit for AI responses

  void askAi() async {
    if (_questionController.text.trim().isEmpty) return;

    setState(() {
      isLoading = true;
      aiResponse = '';
      showQuiz = false;
    });

    try {
      // Updated prompt to specify formatting requirements
      final promptWithInstructions = '''
${_questionController.text}

Please follow these formatting guidelines in your response:
1. Do not use asterisks (*) or stars for emphasis or bullet points
2. Keep your response concise and under $maxWordLimit words
3. Use clear paragraph breaks for readability
4. Avoid using markdown formatting
''';

      final response = await generateResponse(promptWithInstructions);
      
      setState(() {
        isLoading = false;
        // Process the response to enforce word limit and remove any stars
        aiResponse = _processAiResponse(response ?? 'No response from AI');
      });
    } catch (e) {
      setState(() {
        isLoading = false;
        aiResponse = 'Error: Could not get a response. Please try again.';
      });
    }
  }

  // New method to process AI responses
  String _processAiResponse(String response) {
    // Remove any asterisks that might be used for formatting
    String processedResponse = response.replaceAll('*', '');
    
    // Count words and truncate if needed
    List<String> words = processedResponse.split(' ');
    if (words.length > maxWordLimit) {
      // Join only the first maxWordLimit words
      processedResponse = words.take(maxWordLimit).join(' ');
      // Add an indicator that the response was truncated
      processedResponse += '... (Response truncated to $maxWordLimit words)';
    }
    
    // Ensure proper paragraph formatting
    processedResponse = processedResponse
        .replaceAll('\n\n\n', '\n\n') // Remove excess line breaks
        .trim();
    
    return processedResponse;
  }

  void simplifyAnswer() async {
    if (aiResponse.isEmpty) return;
    
    setState(() {
      isLoading = true;
    });

    try {
      final promptWithInstructions = '''
Please simplify this explanation for a student who is new to the topic. 
Use simpler language and shorter sentences. 
Keep your response under $maxWordLimit words.
Do not use asterisks or stars for emphasis.
Use clear paragraph breaks:

$aiResponse
''';

      final response = await generateResponse(promptWithInstructions);

      setState(() {
        isLoading = false;
        aiResponse = _processAiResponse(response ?? 'Could not simplify the response');
      });
    } catch (e) {
      setState(() {
        isLoading = false;
        aiResponse += '\n\nCould not simplify the explanation. Please try again.';
      });
    }
  }

  void generateQuiz() async {
    if (aiResponse.isEmpty) return;
    
    setState(() {
      isLoading = true;
      showQuiz = false;
    });

    try {
      final prompt = '''
Based on this information, create a quiz with 3 multiple-choice questions to test understanding.
Format the response exactly like this JSON array (and only return the JSON):
[
  {
    "question": "Question text here?",
    "options": ["Option A", "Option B", "Option C", "Option D"],
    "answer": 0,
    "explanation": "Explanation why Option A is correct"
  },
  {
    "question": "Second question text here?",
    "options": ["Option A", "Option B", "Option C", "Option D"],
    "answer": 2,
    "explanation": "Explanation why Option C is correct"
  }
]

Do not use asterisks or stars in the questions or explanations.
Keep explanations under 50 words each.

Information to base the quiz on:
$aiResponse
''';

      final response = await generateResponse(prompt);
      
      if (response != null && response.isNotEmpty) {
        // Extract JSON from the response
        String jsonStr = response;
        
        // In case the model adds text before or after the JSON
        int startBracket = jsonStr.indexOf('[');
        int endBracket = jsonStr.lastIndexOf(']');
        
        if (startBracket >= 0 && endBracket > startBracket) {
          jsonStr = jsonStr.substring(startBracket, endBracket + 1);
          
          // Parse the JSON to create quiz questions
          List<dynamic> jsonQuestions = json.decode(jsonStr);
          List<Map<String, dynamic>> parsedQuestions = [];
          
          for (var q in jsonQuestions) {
            // Process the explanation text to remove any asterisks
            String explanation = q['explanation'].toString().replaceAll('*', '');
            
            parsedQuestions.add({
              'question': q['question'].toString().replaceAll('*', ''),
              'options': (q['options'] as List).map((o) => o.toString().replaceAll('*', '')).toList(),
              'answer': q['answer'],
              'explanation': explanation,
              'userAnswer': null,
            });
          }
          
          setState(() {
            isLoading = false;
            quizQuestions = parsedQuestions;
            showQuiz = true;
          });
        } else {
          throw Exception("Could not find valid JSON in response");
        }
      } else {
        throw Exception("Empty response");
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        // Create fallback questions if parsing fails
        quizQuestions = [
          {
            'question': 'What is the main topic discussed in the AI response?',
            'options': [
              'Option A',
              'Option B',
              'Option C',
              'Not clearly stated'
            ],
            'answer': 3,
            'explanation': 'The question requires reading comprehension of the AI response.',
            'userAnswer': null,
          },
          {
            'question': 'Based on the AI response, which conclusion can be drawn?',
            'options': [
              'The topic is simple',
              'The topic is complex',
              'More information is needed',
              'None of the above'
            ],
            'answer': 2,
            'explanation': 'The AI provides information but more detailed study may be needed.',
            'userAnswer': null,
          },
        ];
        showQuiz = true;
      });
    }
  }

  void _generateExample(String topic) async {
    _questionController.text = "Tell me about $topic";
    askAi();
  }

  int _calculateScore() {
    int correct = 0;
    for (var question in quizQuestions) {
      if (question['userAnswer'] == question['answer']) {
        correct++;
      }
    }
    return correct;
  }

  void _checkQuizAnswers() {
    // Check if all questions have been answered
    bool allAnswered = quizQuestions.every((q) => q['userAnswer'] != null);
    
    if (!allAnswered) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please answer all questions before submitting'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    int score = _calculateScore();
    String feedback;
    Color color;
    
    if (score == quizQuestions.length) {
      feedback = 'Perfect! You got all ${quizQuestions.length} questions correct!';
      color = Colors.green;
    } else if (score >= quizQuestions.length / 2) {
      feedback = 'Good job! You got $score out of ${quizQuestions.length} correct.';
      color = Colors.green.shade700;
    } else {
      feedback = 'You got $score out of ${quizQuestions.length} correct. Keep learning!';
      color = Colors.orange;
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(feedback),
        backgroundColor: color,
        duration: const Duration(seconds: 4),
      ),
    );
    
    // Show explanations for each question
    setState(() {
      for (var question in quizQuestions) {
        question['showExplanation'] = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: const Text(
          'AI Learning Assistant',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.lightbulb_outline, color: Colors.orange),
            onPressed: () {
              // Show tips popup
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Learning Tips'),
                  content: const Text(
                      'Try asking specific questions to get more detailed answers. You can also request simplified explanations or generate quizzes to test your knowledge.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Got it'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Header Section
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "What would you like to learn today?",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Enhanced Question Input
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            spreadRadius: 1,
                            blurRadius: 3,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _questionController,
                        decoration: InputDecoration(
                          hintText: 'Ask me anything about your studies...',
                          hintStyle: TextStyle(color: Colors.grey.shade400),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.search, color: Colors.blue),
                            onPressed: askAi,
                          ),
                        ),
                        onSubmitted: (_) => askAi(),
                        maxLines: null,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Topic Suggestions
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildSuggestionChip("Climate Change", Colors.green),
                          _buildSuggestionChip("Mathematics", Colors.blue),
                          _buildSuggestionChip("History", Colors.amber),
                          _buildSuggestionChip("Programming", Colors.purple),
                          _buildSuggestionChip("Literature", Colors.teal),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Content Area
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Loading indicator
                    if (isLoading)
                      Center(
                        child: Column(
                          children: [
                            const SizedBox(height: 24),
                            const CircularProgressIndicator(),
                            const SizedBox(height: 16),
                            Text(
                              "Researching your answer...",
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),

                    // AI Response Section
                    if (aiResponse.isNotEmpty && !isLoading)
                      _buildAiResponseSection(),

                    const SizedBox(height: 24),

                    // Quiz Section
                    if (showQuiz && !isLoading) ...[
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: Colors.orange.shade100,
                                  child: Icon(Icons.quiz, color: Colors.orange),
                                ),
                                SizedBox(width: 12),
                                Text(
                                  'Test Your Knowledge:',
                                  style: TextStyle(
                                    fontSize: 16.0,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange.shade800,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 16),
                            for (var i = 0; i < quizQuestions.length; i++)
                              _buildQuizQuestion(i, quizQuestions[i]),
                            SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                icon: Icon(Icons.check_circle),
                                label: Text('Submit Answers'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  textStyle: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                onPressed: _checkQuizAnswers,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // New method to build the AI response section with improved formatting
  Widget _buildAiResponseSection() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.05),
            spreadRadius: 1,
            blurRadius: 5,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.blue.shade50,
                child: Icon(Icons.school, color: Colors.blue),
              ),
              SizedBox(width: 12),
              Text(
                'AI Tutor Response:',
                style: TextStyle(
                  fontSize: 16.0,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade800,
                ),
              ),
              Spacer(),
              Text(
                '${aiResponse.split(' ').length} words',
                style: TextStyle(
                  fontSize: 12.0,
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Text(
            aiResponse,
            style: TextStyle(
              fontSize: 15,
              height: 1.5,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 16),
          // Action Buttons
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildActionButton(
                "Simplify",
                Icons.auto_awesome,
                Colors.green,
                simplifyAnswer,
              ),
              _buildActionButton(
                "Generate Quiz",
                Icons.quiz,
                Colors.orange,
                generateQuiz,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionChip(String label, Color color) {
    return Container(
      margin: EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: () {
          _generateExample(label);
        },
        child: Chip(
          label: Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
          backgroundColor: color.withOpacity(0.1),
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 0),
        ),
      ),
    );
  }

  Widget _buildActionButton(
      String label, IconData icon, Color color, VoidCallback onPressed) {
    return OutlinedButton.icon(
      icon: Icon(icon, size: 18, color: color),
      label: Text(label, style: TextStyle(color: color)),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: color.withOpacity(0.5)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      onPressed: onPressed,
    );
  }

  Widget _buildQuizQuestion(int index, Map<String, dynamic> question) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: Colors.orange.shade800,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  question['question'],
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          ...List.generate(
            question['options'].length,
            (i) => RadioListTile<int>(
              title: Text(
                question['options'][i],
                style: TextStyle(fontSize: 14),
              ),
              value: i,
              groupValue: question['userAnswer'],
              activeColor: Colors.orange,
              contentPadding: EdgeInsets.symmetric(horizontal: 0),
              dense: true,
              onChanged: (value) {
                setState(() {
                  question['userAnswer'] = value;
                });
              },
            ),
          ),
          // Show explanation after submission
          if (question['showExplanation'] == true) ...[
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: question['userAnswer'] == question['answer']
                    ? Colors.green.shade50
                    : Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: question['userAnswer'] == question['answer']
                      ? Colors.green.shade200
                      : Colors.red.shade200,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    question['userAnswer'] == question['answer']
                        ? 'Correct!'
                        : 'Incorrect',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: question['userAnswer'] == question['answer']
                          ? Colors.green.shade800
                          : Colors.red.shade800,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    question['explanation'] ?? 'No explanation provided.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                  ),
                  if (question['userAnswer'] != question['answer']) ...[
                    SizedBox(height: 4),
                    Text(
                      'Correct answer: ${question['options'][question['answer']]}',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: Colors.green.shade800,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}