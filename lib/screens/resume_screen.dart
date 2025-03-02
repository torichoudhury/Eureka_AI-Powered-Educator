import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'dart:convert';

class ResumeScreen extends StatefulWidget {
  const ResumeScreen({super.key});

  @override
  State<ResumeScreen> createState() {
    return _ResumeScreenState();
  }
}

class _ResumeScreenState extends State<ResumeScreen> {
  bool isUploading = false;
  double atsScore = 0.0;
  List<String> keyStrengths = [];
  List<String> improvementSuggestions = [];
  List<String> jobFitSuggestions = [];
  File? _pdfFile;
  String? _pdfText;

  // Replace with your actual API key
  final String apiKey = dotenv.env['GEMINI_API_KEY']!;

  Future<void> _pickPdfFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null) {
      setState(() {
        _pdfFile = File(result.files.single.path!);
      });
      uploadResume();
    }
  }

  Future<String> _extractTextFromPdf(File pdfFile) async {
    // Load the PDF document
    PdfDocument document = PdfDocument(inputBytes: await pdfFile.readAsBytes());

    // Initialize text extractor
    PdfTextExtractor extractor = PdfTextExtractor(document);

    // Extract text from all pages
    String text = '';
    for (int i = 0; i < document.pages.count; i++) {
      text += extractor.extractText(startPageIndex: i) + '\n';
    }

    // Dispose the document
    document.dispose();

    return text;
  }

  Future<Map<String, dynamic>> _analyzeWithGemini(String resumeText) async {
    print('Analyzing resume with Gemini...$resumeText');
    final model = GenerativeModel(
      model: 'gemini-2.0-flash',
      apiKey: apiKey,
    );

    const prompt = '''
  Analyze the following resume and provide: 
  1. An ATS compatibility score from 0-100
  2. 3-5 key strengths from the resume
  3. 2-3 improvement suggestions 
  4. 2-3 job roles that would be a good fit

  Format your response as a JSON object only, with the following keys:
  {
    "atsScore": 85,
    "keyStrengths": ["strength1", "strength2", "strength3"],
    "improvementSuggestions": ["suggestion1", "suggestion2"],
    "jobFitSuggestions": ["job1", "job2"]
  }

  Only return the JSON object without any explanations.
  
  Resume:
  ''';

    try {
      final content = [Content.text('$prompt\n$resumeText')];
      final response = await model.generateContent(content);
      final responseText = response.text ?? '';

      // Extract JSON from response (remove any extra text or formatting)
      final jsonString =
          responseText.trim().replaceAll('```json', '').replaceAll('```', '');

      final Map<String, dynamic> jsonResponse = jsonDecode(jsonString);
      return jsonResponse;
    } catch (e) {
      print('Error analyzing with Gemini: $e');

      return {
        "atsScore": 70.0,
        "keyStrengths": ["Unable to analyze strengths"],
        "improvementSuggestions": ["Try again later"],
        "jobFitSuggestions": ["General positions"]
      };
    }
  }

  void uploadResume() async {
    if (_pdfFile == null) {
      return;
    }

    setState(() {
      isUploading = true;
    });

    try {
      // Extract text from PDF
      _pdfText = await _extractTextFromPdf(_pdfFile!);

      // Analyze resume with Gemini
      final analysisResult = await _analyzeWithGemini(_pdfText!);

      setState(() {
        isUploading = false;
        atsScore = analysisResult["atsScore"].toDouble();
        keyStrengths = List<String>.from(analysisResult["keyStrengths"]);
        improvementSuggestions =
            List<String>.from(analysisResult["improvementSuggestions"]);
        jobFitSuggestions =
            List<String>.from(analysisResult["jobFitSuggestions"]);
      });
    } catch (e) {
      print('Error processing resume: $e');
      setState(() {
        isUploading = false;
        atsScore = 0.0;
      });

      // Show error dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Error'),
          content: Text('Failed to process the resume. Please try again.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('OK'),
            ),
          ],
        ),
      );
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
          'AI Resume Analyzer',
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
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF3A1C71),
              Color(0xFFD76D77),
              Color(0xFFFFAF7B),
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
                  // Hero Section with animated icon
                  Container(
                    height: 180,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Background pattern
                        Positioned.fill(
                          child: CustomPaint(
                            painter: CirclePatternPainter(),
                          ),
                        ),
                        // Foreground content
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(40),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 10,
                                    offset: Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.description,
                                size: 40,
                                color: Color(0xFF3A1C71),
                              ),
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Resume Analyzer',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 20),

                  // Info Card
                  Container(
                    padding: EdgeInsets.all(20),
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
                    child: Column(
                      children: [
                        Text(
                          'Get AI-powered feedback on your resume',
                          style: TextStyle(
                            fontSize: 18.0,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF3A1C71),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Our AI will analyze your resume for ATS compatibility, highlight your strengths, and suggest improvements to help you land your dream job.',
                          style: TextStyle(
                            fontSize: 14.0,
                            color: Colors.black87,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 20),

                        // Upload Button
                        ElevatedButton.icon(
                          onPressed: _pickPdfFile,
                          icon: Icon(Icons.upload_file),
                          label: Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 12.0, horizontal: 8.0),
                            child: Text(
                              'UPLOAD RESUME (PDF)',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFF3A1C71),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            minimumSize: Size(double.infinity, 0),
                            elevation: 2,
                          ),
                        ),

                        // File name display
                        if (_pdfFile != null && !isUploading) ...[
                          SizedBox(height: 12),
                          Text(
                            'File: ${_pdfFile!.path.split('/').last}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.black87,
                              fontStyle: FontStyle.italic,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],

                        // Loading Indicator
                        if (isUploading) ...[
                          SizedBox(height: 20),
                          Column(
                            children: [
                              CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    Color(0xFF3A1C71)),
                              ),
                              SizedBox(height: 16),
                              Text(
                                'Analyzing your resume...',
                                style: TextStyle(
                                  color: Color(0xFF3A1C71),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  SizedBox(height: 20),

                  // Analysis Results
                  if (!isUploading && atsScore > 0) ...[
                    Container(
                      padding: EdgeInsets.all(20),
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // ATS Score with circular progress indicator
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 100,
                                height: 100,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    SizedBox(
                                      width: 100,
                                      height: 100,
                                      child: CircularProgressIndicator(
                                        value: atsScore / 100,
                                        strokeWidth: 8,
                                        backgroundColor: Colors.grey.shade200,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                          atsScore > 80
                                              ? Colors.green
                                              : atsScore > 60
                                                  ? Colors.orange
                                                  : Colors.red,
                                        ),
                                      ),
                                    ),
                                    Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          '${atsScore.toInt()}%',
                                          style: TextStyle(
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF3A1C71),
                                          ),
                                        ),
                                        Text(
                                          'ATS Score',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 20),

                          // Analysis Sections
                          AnalysisSection(
                            title: 'Key Strengths',
                            icon: Icons.star,
                            iconColor: Colors.amber,
                            items: keyStrengths,
                          ),

                          SizedBox(height: 16),

                          AnalysisSection(
                            title: 'Improvement Suggestions',
                            icon: Icons.build,
                            iconColor: Colors.orange,
                            items: improvementSuggestions,
                          ),

                          SizedBox(height: 16),

                          AnalysisSection(
                            title: 'Job Fit Suggestions',
                            icon: Icons.work,
                            iconColor: Colors.blue,
                            items: jobFitSuggestions,
                          ),
                        ],
                      ),
                    ),
                  ],

                  SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Custom widget for analysis sections
class AnalysisSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final List<String> items;

  const AnalysisSection({
    Key? key,
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.items,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor),
              SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16.0,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF3A1C71),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          ...items
              .map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('•',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: iconColor)),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            item,
                            style: TextStyle(fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ))
              .toList(),
        ],
      ),
    );
  }
}

// Custom painter for background pattern
class CirclePatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Draw circles of various sizes
    for (int i = 0; i < 3; i++) {
      double radius = 40.0 + (i * 30.0);
      canvas.drawCircle(
          Offset(size.width * 0.25, size.height * 0.5), radius, paint);
      canvas.drawCircle(
          Offset(size.width * 0.75, size.height * 0.5), radius, paint);
    }

    // Draw some dots
    final dotPaint = Paint()
      ..color = Colors.white.withOpacity(0.2)
      ..style = PaintingStyle.fill;

    final random = math.Random(42); // Fixed seed for consistent pattern
    for (int i = 0; i < 20; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final radius = random.nextDouble() * 3 + 1;
      canvas.drawCircle(Offset(x, y), radius, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
