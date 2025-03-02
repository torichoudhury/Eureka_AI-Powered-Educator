
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

Future<String?> generateResponse(String message) async {
  final apiKey = dotenv.env['GEMINI_API_KEY'];
  if (apiKey == null) {
    throw Exception('No GEMINI_API_KEY found in .env file');
  }

  final model = GenerativeModel(
    model: 'gemini-2.0-flash',
    apiKey: apiKey,
    generationConfig: GenerationConfig(
      temperature: 1,
      topK: 40,
      topP: 0.95,
      maxOutputTokens: 8192,
      responseMimeType: 'text/plain',
    ),
  );

  final chat = model.startChat(history: []);
  final content = Content.text(message);

  final response = await chat.sendMessage(content);
  return response.text;
}
