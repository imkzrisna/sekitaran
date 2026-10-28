import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sekitaran/features/assistant/business_assistant_page.dart';
import 'package:sekitaran/features/assistant/business_assistant_service.dart';

class _FakeAssistantRepository implements BusinessAssistantRepository {
  final calls =
      <({String question, List<AssistantTurn> history, String? businessId})>[];
  bool failFirst = false;

  @override
  Future<AssistantReply> ask(
    String question, {
    required List<AssistantTurn> history,
    String? businessId,
  }) async {
    calls.add((
      question: question,
      history: List.of(history),
      businessId: businessId,
    ));
    if (failFirst) {
      failFirst = false;
      throw const BusinessAssistantFailure('Temporary failure');
    }
    return AssistantReply(
      answer: 'Customers liked the fresh food.',
      sources: [
        AssistantSource(
          commentId: 'comment-1',
          businessId: 'business-1',
          businessName: 'Warung Sari',
          excerpt: 'The food was fresh and tasty.',
          createdAt: DateTime.utc(2026, 1, 2),
        ),
      ],
    );
  }
}

void main() {
  testWidgets('shows answer sources and sends recent turns as context', (
    tester,
  ) async {
    final repository = _FakeAssistantRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: BusinessAssistantPage(
          repository: repository,
          businessId: 'business-1',
          businessName: 'Warung Sari',
        ),
      ),
    );

    await tester.enterText(
      find.byType(TextField),
      'Which shop has fresh food?',
    );
    await tester.tap(find.byTooltip('Send question'));
    await tester.pumpAndSettle();

    expect(find.text('Customers liked the fresh food.'), findsOneWidget);
    expect(find.text('Warung Sari · 02/01/2026'), findsOneWidget);
    expect(
      find.textContaining('The food was fresh and tasty.'),
      findsOneWidget,
    );

    await tester.enterText(find.byType(TextField), 'What did customers say?');
    await tester.tap(find.byTooltip('Send question'));
    await tester.pumpAndSettle();

    expect(repository.calls, hasLength(2));
    expect(repository.calls.first.businessId, 'business-1');
    expect(repository.calls.last.history, hasLength(2));
    expect(repository.calls.last.history.first.role, 'user');
    expect(
      repository.calls.last.history.last.text,
      'Customers liked the fresh food.',
    );
  });

  testWidgets('shows a recoverable error and retries the failed question', (
    tester,
  ) async {
    final repository = _FakeAssistantRepository()..failFirst = true;
    await tester.pumpWidget(
      MaterialApp(home: BusinessAssistantPage(repository: repository)),
    );

    await tester.enterText(find.byType(TextField), 'Find a good shop');
    await tester.tap(find.byTooltip('Send question'));
    await tester.pumpAndSettle();

    expect(find.text('Temporary failure'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(repository.calls, hasLength(2));
    expect(repository.calls.first.question, repository.calls.last.question);
    expect(find.text('Customers liked the fresh food.'), findsOneWidget);
    expect(
      find.text('Find a good shop'),
      findsOneWidget,
      reason: 'Retry should not duplicate the failed user turn.',
    );
  });
}
