import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/logic/feedback.dart';

Matcher failsWith(FeedbackDraftFailure failure) => throwsA(
  isA<FeedbackDraftException>().having((e) => e.failure, 'failure', failure),
);

void main() {
  test(
    'draft encodes only the entered title and body for the right issue form',
    () {
      const title = 'Timer & portions? #1 / Öl';
      const message = 'First line\nSecond: + 100% & title=another#fragment 🍲';
      final uri = buildFeedbackDraftUrl(
        title: '  $title  ',
        message: '  $message\n',
      );
      expect(uri.scheme, 'https');
      expect(uri.host, 'github.com');
      expect(uri.path, '/TheMorpheus407/morphcook/issues/new');
      expect(uri.fragment, isEmpty);
      expect(uri.userInfo, isEmpty);
      expect(Uri.parse(uri.toString()).queryParameters, {
        'title': title,
        'body': message,
      });
    },
  );

  test('blank and excessive text is rejected before an external action', () {
    expect(
      () => buildFeedbackDraftUrl(title: ' \n ', message: 'message'),
      failsWith(FeedbackDraftFailure.emptyTitle),
    );
    expect(
      () => buildFeedbackDraftUrl(title: 'Title', message: '\t '),
      failsWith(FeedbackDraftFailure.emptyMessage),
    );
    expect(
      () => buildFeedbackDraftUrl(title: 't' * 121, message: 'message'),
      failsWith(FeedbackDraftFailure.tooLong),
    );
    expect(
      () => feedbackClipboardText(title: 'Title', message: 'm' * 2001),
      failsWith(FeedbackDraftFailure.tooLong),
    );
    expect(
      buildFeedbackDraftUrl(
        title: 't' * 120,
        message: 'm' * 2000,
      ).queryParameters['body'],
      'm' * 2000,
    );
  });

  test(
    'percent-encoded URL is bounded without truncating the copy fallback',
    () {
      final text = '料' * 1000;
      expect(text.length, lessThan(maxFeedbackMessageLength));
      expect(
        () => buildFeedbackDraftUrl(title: 'PDF', message: text),
        failsWith(FeedbackDraftFailure.urlTooLong),
      );
      expect(
        feedbackClipboardText(title: ' PDF ', message: '$text\n'),
        'PDF\n\n$text',
      );
    },
  );
}
