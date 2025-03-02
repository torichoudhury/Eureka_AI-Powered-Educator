import 'package:flutter/material.dart';
import 'dart:convert';
import '../gemini_ai.dart'; // Import the GeminiAI class

class MicroCourseScreen extends StatefulWidget {
  final String? topic;
  const MicroCourseScreen({super.key, this.topic});

  @override
  State<MicroCourseScreen> createState() {
    return _MicroCourseScreenState();
  }
}

class _MicroCourseScreenState extends State<MicroCourseScreen> {
  final TextEditingController _topicController = TextEditingController();
  bool isGenerating = false;
  List<String> coursePlan = [];
  int? expandedIndex;
  bool isLoadingQuiz = false;
  List<Map<String, dynamic>> quizQuestions = [];
  bool showQuiz = false;
  bool isSubmittingQuiz = false;

  @override
  void initState() {
    super.initState();
    if (widget.topic != null && widget.topic!.isNotEmpty) {
      _topicController.text = widget.topic!;
      Future.delayed(Duration(milliseconds: 500), () {
        generateCourse();
      });
    }
  }

  void generateCourse() async {
    setState(() {
      isGenerating = true;
    });

    await Future.delayed(Duration(seconds: 3)); // Simulate AI generation time

    setState(() {
      isGenerating = false;
      coursePlan = [
        'Day 1: Introduction to ${_topicController.text}',
        'Day 2: Core Concepts',
        'Day 3: Advanced Topics',
        'Day 4: Practical Applications',
        'Day 5: Final Project & Assessment',
      ];
    });
  }

  void toggleQuiz(int index) {
    setState(() {
      if (expandedIndex == index) {
        expandedIndex = null;
      } else {
        expandedIndex = index;
        generateQuiz(index);
      }
    });
  }

  void generateQuiz(int index) async {
    setState(() {
      isLoadingQuiz = true;
      showQuiz = false;
    });

    try {
      final prompt = '''
Based on the course content for Day ${index + 1}, create a quiz with 3 multiple-choice questions to test understanding.
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

Course content for Day ${index + 1}:
${coursePlan[index]}
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
            String explanation =
                q['explanation'].toString().replaceAll('*', '');

            parsedQuestions.add({
              'question': q['question'].toString().replaceAll('*', ''),
              'options': (q['options'] as List)
                  .map((o) => o.toString().replaceAll('*', ''))
                  .toList(),
              'answer': q['answer'],
              'explanation': explanation,
              'userAnswer': null,
            });
          }

          setState(() {
            isLoadingQuiz = false;
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
        isLoadingQuiz = false;
        // Create fallback questions if parsing fails
        quizQuestions = [
          {
            'question':
                'What is the main topic discussed in the course content?',
            'options': [
              'Option A',
              'Option B',
              'Option C',
              'Not clearly stated'
            ],
            'answer': 3,
            'explanation':
                'The question requires reading comprehension of the course content.',
            'userAnswer': null,
          },
          {
            'question':
                'Based on the course content, which conclusion can be drawn?',
            'options': [
              'The topic is simple',
              'The topic is complex',
              'More information is needed',
              'None of the above'
            ],
            'answer': 2,
            'explanation':
                'The course content provides information but more detailed study may be needed.',
            'userAnswer': null,
          },
        ];
        showQuiz = true;
      });
    }
  }

  void submitQuiz() async {
    setState(() {
      isSubmittingQuiz = true;
    });

    try {
      final prompt = '''
The following are the user's answers to the quiz questions. Please check if the answers are correct and provide feedback.

Quiz Questions and Answers:
${jsonEncode(quizQuestions)}

Format the response as a JSON array with the following keys:
[
  {
    "question": "Question text here?",
    "isCorrect": true,
    "feedback": "Feedback text here"
  }
]
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

          // Parse the JSON to get feedback
          List<dynamic> jsonFeedback = json.decode(jsonStr);

          setState(() {
            for (int i = 0; i < quizQuestions.length; i++) {
              quizQuestions[i]['isCorrect'] = jsonFeedback[i]['isCorrect'];
              quizQuestions[i]['feedback'] = jsonFeedback[i]['feedback'];
              quizQuestions[i]['showExplanation'] = true;
            }
            isSubmittingQuiz = false;
          });
        } else {
          throw Exception("Could not find valid JSON in response");
        }
      } else {
        throw Exception("Empty response");
      }
    } catch (e) {
      setState(() {
        isSubmittingQuiz = false;
      });
      print('Error submitting quiz: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: Text(
          'AI Course Creator',
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
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF6A11CB),
              Color(0xFF2575FC),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Center(
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(40),
                      ),
                      child: Icon(
                        Icons.school,
                        size: 40,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                  // Topic Selection Section
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: Offset(0, 5),
                        ),
                      ],
                    ),
                    padding: EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          "What would you like to learn today?",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF6A11CB),
                          ),
                        ),
                        SizedBox(height: 16),
                        TextField(
                          controller: _topicController,
                          decoration: InputDecoration(
                            labelText: 'Enter Topic',
                            hintText:
                                'e.g., Digital Marketing, Flutter Development',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Color(0xFF2575FC)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                  color: Color(0xFF6A11CB), width: 2),
                            ),
                            prefixIcon:
                                Icon(Icons.search, color: Color(0xFF6A11CB)),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                        ),
                        SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: generateCourse,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12.0),
                            child: Text(
                              'GENERATE MY COURSE',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFF6A11CB),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 20),

                  // Loading indicator
                  if (isGenerating)
                    Container(
                      height: 100,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Creating your personalized course...',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Course Display Section
                  if (!isGenerating && coursePlan.isNotEmpty) ...[
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: Offset(0, 5),
                          ),
                        ],
                      ),
                      padding: EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '5-Day Learning Plan',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF6A11CB),
                                ),
                              ),
                             
                            ],
                          ),
                          SizedBox(height: 20),
                          for (var i = 0; i < coursePlan.length; i++)
                            Container(
                              margin: EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 5,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  ListTile(
                                    leading: Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color:
                                            Color(0xFF2575FC).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Center(
                                        child: Text(
                                          '${i + 1}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF2575FC),
                                          ),
                                        ),
                                      ),
                                    ),
                                    title: Text(
                                      coursePlan[i].split(': ')[1],
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                    subtitle: Text('Day ${i + 1}'),
                                    trailing: ElevatedButton(
                                      onPressed: () => toggleQuiz(i),
                                      child: Text(expandedIndex == i
                                          ? 'Hide Quiz'
                                          : 'Quiz'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Color(0xFF2575FC),
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        elevation: 0,
                                      ),
                                    ),
                                    contentPadding: EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 8),
                                  ),
                                  if (expandedIndex == i)
                                    Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          if (isLoadingQuiz)
                                            Center(
                                              child:
                                                  CircularProgressIndicator(),
                                            )
                                          else if (showQuiz)
                                            ...quizQuestions.map((question) {
                                              int questionIndex = quizQuestions
                                                  .indexOf(question);
                                              return _buildQuizQuestion(
                                                  questionIndex, question);
                                            }).toList()
                                          else
                                            Text('No quiz available.'),
                                          if (showQuiz)
                                            ElevatedButton(
                                              onPressed: submitQuiz,
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        vertical: 12.0),
                                                child: Text(
                                                  'SUBMIT QUIZ',
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    Color(0xFF6A11CB),
                                                foregroundColor: Colors.white,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                elevation: 2,
                                              ),
                                            ),
                                          if (isSubmittingQuiz)
                                            Center(
                                              child:
                                                  CircularProgressIndicator(),
                                            ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
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
