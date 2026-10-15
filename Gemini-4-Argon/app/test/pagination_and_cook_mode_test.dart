import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/services/one_handed_cook_mode_controller.dart';
import 'package:morphcook/services/pagination_controller.dart';

void main() {
  group('PaginationController', () {
    test('loads pages, triggers shouldLoadMore within prefetch threshold, and caps at maxRendered=50', () async {
      final controller = PaginationController<int>.search(
        fetcher: ({
          required int pageIndex,
          required int offset,
          required int pageSize,
          String? cursor,
        }) async {
          final start = pageIndex * pageSize;
          final items = List<int>.generate(pageSize, (i) => start + i);
          return PaginatedPageResult<int>(
            items: items,
            nextCursor: '${start + pageSize - 1}',
            hasMore: pageIndex < 4,
          );
        },
      );

      await controller.refresh();
      expect(controller.items.length, 20);
      expect(controller.shouldLoadMore(5), isFalse);
      // Within prefetchThreshold (10 items from end -> index >= 9)
      expect(controller.shouldLoadMore(10), isTrue);

      await controller.loadMore();
      expect(controller.items.length, 40);

      await controller.loadMore();
      // 60 items fetched total, but maxRendered guardrail caps at 50!
      expect(controller.items.length, 50);
      expect(controller.items.first, 10);
      expect(controller.items.last, 59);

      controller.reset();
      expect(controller.items, isEmpty);
      expect(controller.currentPageIndex, 0);
    });
  });

  group('OneHandedCookModeController', () {
    test('enforces opt-in quickNextTapEnabled and 300ms debounce window', () {
      final controller = OneHandedCookModeController(
        quickNextTapEnabled: false,
        visualAlertEnabled: true,
      );

      int stepAdvances = 0;
      final t0 = DateTime(2026, 10, 14, 12, 0, 0, 0);

      // Disabled by default -> does not advance
      expect(
        controller.handleStepContentTap(
          () => stepAdvances++,
          timestamp: t0,
          triggerHaptics: false,
        ),
        isFalse,
      );
      expect(stepAdvances, 0);

      // Enable quick tap
      controller.quickNextTapEnabled = true;
      expect(
        controller.handleStepContentTap(
          () => stepAdvances++,
          timestamp: t0,
          triggerHaptics: false,
        ),
        isTrue,
      );
      expect(stepAdvances, 1);

      // Tap 150ms later (< 300ms debounce) -> ignored!
      expect(
        controller.handleStepContentTap(
          () => stepAdvances++,
          timestamp: t0.add(const Duration(milliseconds: 150)),
          triggerHaptics: false,
        ),
        isFalse,
      );
      expect(stepAdvances, 1);

      // Tap 320ms later (>= 300ms debounce) -> advances!
      expect(
        controller.handleStepContentTap(
          () => stepAdvances++,
          timestamp: t0.add(const Duration(milliseconds: 320)),
          triggerHaptics: false,
        ),
        isTrue,
      );
      expect(stepAdvances, 2);
    });

    test('triggers coral/teal visual flash alert and respects reduceMotion', () {
      final controller = OneHandedCookModeController(
        visualAlertEnabled: true,
        reduceMotion: false,
      );

      controller.triggerTimerVisualAlert();
      expect(controller.isVisualAlertActive, isTrue);
      expect(
        controller.currentAlertColor,
        OneHandedCookModeController.coralAlertColor,
      );

      controller.stepFlashPhase();
      expect(
        controller.currentAlertColor,
        OneHandedCookModeController.tealAlertColor,
      );

      // With reduceMotion = true, stepTransitionDuration is zero and flashPhase stays steady
      controller.reduceMotion = true;
      expect(controller.stepTransitionDuration(), Duration.zero);
      controller.triggerTimerVisualAlert();
      controller.stepFlashPhase();
      expect(controller.flashPhase, 0);

      controller.dismissVisualAlert();
      expect(controller.isVisualAlertActive, isFalse);
    });
  });
}
