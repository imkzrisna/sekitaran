import 'package:flutter_test/flutter_test.dart';
import 'package:sekitaran/features/assistant/business_assistant_service.dart';

void main() {
  test('invokes recommend-stores with question and recent history', () async {
    String? invokedFunction;
    Map<String, Object?>? invokedBody;
    final repository = SupabaseBusinessAssistantRepository(
      invoke: ({required functionName, required body}) async {
        invokedFunction = functionName;
        invokedBody = body;
        return (
          status: 200,
          data: {
            'answer': 'Customers liked the service.',
            'sources': [
              {
                'commentId': 'comment-1',
                'businessId': 'business-1',
                'businessName': 'Warung Sari',
                'comment': 'The service was friendly.',
                'createdAt': '2026-01-02T00:00:00Z',
              },
            ],
          },
        );
      },
    );

    final reply = await repository.ask(
      'What about service?',
      businessId: 'business-1',
      history: const [
        AssistantTurn(role: 'user', text: 'Tell me about this store.'),
        AssistantTurn(role: 'assistant', text: 'What would you like to know?'),
      ],
    );

    expect(invokedFunction, 'recommend-stores');
    expect(invokedBody?['question'], 'What about service?');
    expect(invokedBody?['businessId'], 'business-1');
    expect(invokedBody?['history'], [
      {'role': 'user', 'text': 'Tell me about this store.'},
      {'role': 'assistant', 'text': 'What would you like to know?'},
    ]);
    expect(reply.sources, hasLength(1));
    expect(reply.sources.single.businessName, 'Warung Sari');
  });

  test('omits store context for general questions', () async {
    Map<String, Object?>? invokedBody;
    final repository = SupabaseBusinessAssistantRepository(
      invoke: ({required functionName, required body}) async {
        invokedBody = body;
        return (
          status: 200,
          data: {'answer': 'An answer.', 'sources': <Object>[]},
        );
      },
    );

    await repository.ask('General question?', history: const []);

    expect(invokedBody?.containsKey('businessId'), isFalse);
  });

  test('accepts a valid empty-evidence response', () async {
    final repository = SupabaseBusinessAssistantRepository(
      invoke: ({required functionName, required body}) async => (
        status: 200,
        data: {
          'answer': "I couldn't find relevant business comments.",
          'sources': <Object>[],
        },
      ),
    );

    final reply = await repository.ask('Unmatched question', history: const []);

    expect(reply.answer, contains("couldn't find"));
    expect(reply.sources, isEmpty);
  });

  test('rejects a response with an incompatible source contract', () async {
    final repository = SupabaseBusinessAssistantRepository(
      invoke: ({required functionName, required body}) async => (
        status: 200,
        data: {
          'answer': 'An answer.',
          'sources': [
            {'comment_id': 'snake-case-only'},
          ],
        },
      ),
    );

    await expectLater(
      repository.ask('Question?', history: const []),
      throwsA(isA<BusinessAssistantFailure>()),
    );
  });
}
