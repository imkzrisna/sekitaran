import 'package:supabase_flutter/supabase_flutter.dart';

class BusinessAssistantFailure implements Exception {
  const BusinessAssistantFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

class AssistantTurn {
  const AssistantTurn({required this.role, required this.text});

  final String role;
  final String text;

  Map<String, String> toJson() => {'role': role, 'text': text};
}

class AssistantSource {
  const AssistantSource({
    required this.commentId,
    required this.businessId,
    required this.businessName,
    required this.excerpt,
    required this.createdAt,
  });

  final String commentId;
  final String businessId;
  final String businessName;
  final String excerpt;
  final DateTime createdAt;
}

class AssistantReply {
  const AssistantReply({required this.answer, required this.sources});

  final String answer;
  final List<AssistantSource> sources;
}

typedef AssistantFunctionResult = ({int status, Object? data});
typedef AssistantFunctionInvoker = Future<AssistantFunctionResult> Function({
  required String functionName,
  required Map<String, Object?> body,
});

abstract interface class BusinessAssistantRepository {
  Future<AssistantReply> ask(
    String question, {
    required List<AssistantTurn> history,
    String? businessId,
  });
}

class SupabaseBusinessAssistantRepository
    implements BusinessAssistantRepository {
  SupabaseBusinessAssistantRepository({
    SupabaseClient? client,
    AssistantFunctionInvoker? invoke,
  }) : _client = client ?? (invoke == null ? Supabase.instance.client : null),
       _invoke = invoke;

  final SupabaseClient? _client;
  final AssistantFunctionInvoker? _invoke;

  @override
  Future<AssistantReply> ask(
    String question, {
    required List<AssistantTurn> history,
    String? businessId,
  }) async {
    try {
      final requestBody = <String, Object?>{
        'question': question,
        'history': history.map((turn) => turn.toJson()).toList(),
        ...?businessId != null ? {'businessId': businessId} : null,
      };
      final response = _invoke == null
          ? await _invokeSupabase(requestBody)
          : await _invoke(functionName: 'recommend-stores', body: requestBody);
      final data = response.data;
      if (response.status != 200 || data is! Map) {
        throw const BusinessAssistantFailure(
          'The assistant returned an unexpected response. Please try again.',
        );
      }

      final answer = data['answer'];
      final rawSources = data['sources'];
      if (answer is! String || rawSources is! List) {
        throw const BusinessAssistantFailure(
          'The assistant returned an unexpected response. Please try again.',
        );
      }

      return AssistantReply(
        answer: answer,
        sources: rawSources.map((value) {
          if (value is! Map) {
            throw const BusinessAssistantFailure(
              'The assistant returned an unexpected response. Please try again.',
            );
          }
          final excerpt = value['comment'] ?? value['excerpt'];
          final createdAt = DateTime.tryParse('${value['createdAt']}');
          if (value['commentId'] is! String ||
              value['businessId'] is! String ||
              value['businessName'] is! String ||
              excerpt is! String ||
              createdAt == null) {
            throw const BusinessAssistantFailure(
              'The assistant returned an unexpected response. Please try again.',
            );
          }
          return AssistantSource(
            commentId: value['commentId'] as String,
            businessId: value['businessId'] as String,
            businessName: value['businessName'] as String,
            excerpt: excerpt,
            createdAt: createdAt.toLocal(),
          );
        }).toList(),
      );
    } on BusinessAssistantFailure {
      rethrow;
    } on FunctionException catch (e) {
      final details = e.details;
      final message = e.status == 0
          ? 'Could not connect to the assistant. Check your internet connection.'
          : details is Map && details['error'] is String
          ? details['error'] as String
          : e.status == 429
          ? 'Too many questions. Please wait a minute and try again.'
          : 'The assistant is temporarily unavailable. Please try again.';
      throw BusinessAssistantFailure(message);
    }
  }

  Future<AssistantFunctionResult> _invokeSupabase(
    Map<String, Object?> body,
  ) async {
    final response = await _client!.functions.invoke(
      'recommend-stores',
      body: body,
    );
    return (status: response.status, data: response.data);
  }
}
