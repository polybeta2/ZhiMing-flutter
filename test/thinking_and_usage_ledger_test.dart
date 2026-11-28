import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zhiming/core/database/app_database.dart' show ProviderRecord;
import 'package:zhiming/core/llm/llm_types.dart';
import 'package:zhiming/core/llm/stream_progress.dart';
import 'package:zhiming/core/llm/token_usage_ledger.dart';
import 'package:zhiming/core/widgets/thinking_process_card.dart';
import 'package:zhiming/core/widgets/token_usage_dashboard.dart';

void main() {
  group('StreamProgressTracker live reasoning capture', () {
    test('captures reasoning deltas, preserves after finish, and resets on begin', () {
      final tracker = StreamProgressTracker();
      addTearDown(tracker.dispose);

      tracker.begin();
      expect(tracker.value.hasReasoning, isFalse);

      tracker.handle(const ReasoningDelta('第一步：梳理时间线。'));
      tracker.handle(const ReasoningDelta('\n第二步：核对人物伏笔。'));
      expect(tracker.value.stage, StreamStage.thinking);
      expect(tracker.value.reasoningChars, 22);
      expect(tracker.value.reasoningText, contains('梳理时间线'));
      expect(tracker.value.reasoningText, contains('核对人物伏笔'));

      tracker.handle(const ContentDelta('正文开始。'));
      expect(tracker.value.stage, StreamStage.outputting);
      expect(tracker.value.reasoningText, contains('核对人物伏笔'));

      tracker.handle(
        const UsageReport(
          promptTokens: 10000,
          completionTokens: 1200,
          cachedTokens: 8000,
          reasoningTokens: 400,
        ),
      );
      tracker.finish();

      expect(tracker.value.isActive, isFalse);
      expect(tracker.lastCompletedReasoningText, contains('梳理时间线'));
      expect(tracker.value.reasoningText, contains('核对人物伏笔'));
      expect(tracker.value.lastUsage?.cachedTokens, 8000);

      tracker.begin();
      expect(tracker.lastCompletedReasoningText, isEmpty);
      expect(tracker.value.reasoningText, isEmpty);
      expect(tracker.value.hasReasoning, isFalse);
    });
  });

  group('TokenUsageLedger & TokenPricingConfig', () {
    test('computes actual cost, cache savings, per-novel & category summaries, and persists', () async {
      SharedPreferences.setMockInitialValues({});
      const pricing = TokenPricingConfig(
        currencySymbol: '¥',
        inputPerMillion: 2.0,
        cachedInputPerMillion: 0.2,
        outputPerMillion: 8.0,
      );
      // 1M prompt (800k cached + 200k uncached) + 500k output:
      // actual = (0.2*2 + 0.8*0.2 + 0.5*8) = 0.4 + 0.16 + 4.0 = 4.56
      // without cache = (1.0*2 + 0.5*8) = 6.0 -> savings = 1.44
      expect(
        pricing.estimateActualCost(
          promptTokens: 1000000,
          cachedTokens: 800000,
          completionTokens: 500000,
        ),
        closeTo(4.56, 0.0001),
      );
      expect(
        pricing.estimateCacheSavings(
          promptTokens: 1000000,
          cachedTokens: 800000,
          completionTokens: 500000,
        ),
        closeTo(1.44, 0.0001),
      );

      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(tokenUsageLedgerProvider.notifier);
      final provider = ProviderRecord(
        id: 'p1',
        name: 'DeepSeek',
        baseUrl: 'https://api.example.com/v1',
        apiKeyId: 'k1',
        modelName: 'deepseek-v4.1-flash',
        temperature: 0.7,
        maxTokens: 16384,
        contextBudgetChars: 120000,
        isDefault: true,
        createdAt: DateTime(2026, 11, 28),
      );

      await notifier.recordUsage(
        usage: const UsageReport(
          promptTokens: 20000,
          cachedTokens: 16000,
          completionTokens: 4000,
          reasoningTokens: 1000,
        ),
        category: UsageCategory.writing,
        provider: provider,
        novelId: 'n1',
        chapterId: 'c1',
        chapterTitle: '第1章 雨夜',
        effort: ReasoningEffort.low,
      );
      await notifier.recordUsage(
        usage: const UsageReport(
          promptTokens: 10000,
          cachedTokens: 5000,
          completionTokens: 1000,
        ),
        category: UsageCategory.factReview,
        provider: provider,
        novelId: 'n1',
        chapterId: 'c1',
        chapterTitle: '第1章 雨夜',
        effort: ReasoningEffort.none,
      );
      await notifier.recordRaw(
        category: UsageCategory.sourceScan,
        providerName: 'DeepSeek',
        modelName: 'deepseek-v4.1-flash',
        promptTokens: 50000,
        cachedTokens: 25000,
        completionTokens: 5000,
        chapterTitle: '原作A',
      );

      final state = container.read(tokenUsageLedgerProvider);
      final globalSum = state.summarize();
      expect(globalSum.requests, 3);
      expect(globalSum.promptTokens, 80000);
      expect(globalSum.cachedTokens, 46000);
      expect(globalSum.completionTokens, 10000);
      expect(globalSum.reasoningTokens, 1000);
      expect(globalSum.byCategory.length, 3);

      final novelSum = state.summarize(novelId: 'n1');
      expect(novelSum.requests, 2);
      expect(novelSum.promptTokens, 30000);
      expect(novelSum.cachedTokens, 21000);
      expect(novelSum.cacheHitRate, closeTo(0.7, 0.001));
      expect(novelSum.byChapter.single.label, '第1章 雨夜');

      // Persists across container recreation
      final container2 = ProviderContainer();
      addTearDown(container2.dispose);
      container2.read(tokenUsageLedgerProvider);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(container2.read(tokenUsageLedgerProvider).records.length, 3);

      await container2.read(tokenUsageLedgerProvider.notifier).clearForNovel('n1');
      expect(container2.read(tokenUsageLedgerProvider).records.length, 1);
      expect(
        container2.read(tokenUsageLedgerProvider).records.single.category,
        UsageCategory.sourceScan,
      );
    });
  });

  group('ThinkingProcessCard & TokenUsageDashboardCard widgets', () {
    testWidgets('ThinkingProcessCard stays hidden without reasoning and expands cleanly when present', (
      tester,
    ) async {
      final tracker = StreamProgressTracker();
      addTearDown(tracker.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: ThinkingProcessCard(tracker: tracker),
            ),
          ),
        ),
      );
      expect(find.textContaining('思考'), findsNothing);

      tracker.begin();
      tracker.handle(const ReasoningDelta('先检查第178章人物位置，再衔接约会收尾。'));
      await tester.pump();

      expect(find.textContaining('深度思考中'), findsOneWidget);
      // Collapsed live preview shows tail snippet
      expect(find.textContaining('先检查第178章人物位置'), findsOneWidget);

      tracker.handle(const ContentDelta('夜色渐深。'));
      tracker.handle(
        const UsageReport(
          promptTokens: 12000,
          completionTokens: 800,
          cachedTokens: 9600,
        ),
      );
      tracker.finish();
      await tester.pump();

      expect(find.textContaining('思考过程'), findsOneWidget);
      expect(find.textContaining('缓存 80%'), findsOneWidget);

      // Tap header to expand and inspect full reasoning text + copy icon
      await tester.tap(find.textContaining('思考过程'));
      await tester.pump();
      expect(find.byTooltip('复制思考过程'), findsOneWidget);
      expect(find.textContaining('衔接约会收尾'), findsOneWidget);
    });

    testWidgets('TokenUsageDashboardCard renders KPIs, category breakdown, and opens pricing dialog', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(tokenUsageLedgerProvider.notifier).recordRaw(
            category: UsageCategory.writing,
            providerName: 'DeepSeek',
            modelName: 'deepseek-v4.1-flash',
            promptTokens: 40000,
            cachedTokens: 32000,
            completionTokens: 6000,
            reasoningTokens: 1500,
            novelId: 'n-ui',
            chapterTitle: '第179章 血月',
            effort: 'High',
          );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: const TokenUsageDashboardCard(novelId: 'n-ui'),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('本书 Token 与 KV 缓存账单'), findsOneWidget);
      expect(find.text('46.0k'), findsOneWidget);
      expect(find.text('80.0%'), findsOneWidget);
      expect(find.textContaining('正文撰写/续写'), findsOneWidget);
      expect(find.textContaining('第179章 血月'), findsOneWidget);

      // Expand recent details
      await tester.tap(find.textContaining('最近调用明细'));
      await tester.pump();
      expect(find.textContaining('Effort:High'), findsOneWidget);

      // Open pricing dialog and switch to USD preset
      await tester.tap(find.text('单价'));
      await tester.pumpAndSettle();
      expect(find.text('Token 费率设置（每百万 Token）'), findsOneWidget);
      await tester.tap(find.text('保存费率'));
      await tester.pumpAndSettle();
    });
  });
}
