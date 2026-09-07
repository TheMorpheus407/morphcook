const maxFeedbackTitleLength = 120;
const maxFeedbackMessageLength = 2000;

// Bound the encoded URL as well as the input: non-ASCII text expands when
// percent-encoded. A draft that exceeds this limit can still be copied.
const maxFeedbackDraftUrlLength = 8000;

enum FeedbackDraftFailure { emptyTitle, emptyMessage, tooLong, urlTooLong }

class FeedbackDraftException implements Exception {
  final FeedbackDraftFailure failure;
  const FeedbackDraftException(this.failure);
}

({String title, String message}) _normalizedFeedback(
  String title,
  String message,
) {
  final cleanTitle = title.trim();
  final cleanMessage = message.trim();
  if (cleanTitle.isEmpty) {
    throw const FeedbackDraftException(FeedbackDraftFailure.emptyTitle);
  }
  if (cleanMessage.isEmpty) {
    throw const FeedbackDraftException(FeedbackDraftFailure.emptyMessage);
  }
  if (cleanTitle.length > maxFeedbackTitleLength ||
      cleanMessage.length > maxFeedbackMessageLength) {
    throw const FeedbackDraftException(FeedbackDraftFailure.tooLong);
  }
  return (title: cleanTitle, message: cleanMessage);
}

/// Only the text explicitly entered by the user is included. Constructing a
/// URI does not contact GitHub or submit an issue.
Uri buildFeedbackDraftUrl({required String title, required String message}) {
  final feedback = _normalizedFeedback(title, message);
  final uri = Uri.https('github.com', '/TheMorpheus407/morphcook/issues/new', {
    'title': feedback.title,
    'body': feedback.message,
  });
  if (uri.toString().length > maxFeedbackDraftUrlLength) {
    throw const FeedbackDraftException(FeedbackDraftFailure.urlTooLong);
  }
  return uri;
}

/// Clipboard fallback keeps the complete text even when its URL would be too
/// long for the external browser handoff.
String feedbackClipboardText({required String title, required String message}) {
  final feedback = _normalizedFeedback(title, message);
  return '${feedback.title}\n\n${feedback.message}';
}
