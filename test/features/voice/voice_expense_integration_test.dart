import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khata_flow/core/services/voice_service.dart';
import 'package:khata_flow/database/app_database.dart';
import 'package:khata_flow/features/dashboard/domain/expense_dashboard_summary.dart';
import 'package:khata_flow/features/expense/data/expense_repository_impl.dart';
import 'package:khata_flow/features/expense/domain/expense_category.dart';
import 'package:khata_flow/features/ledger/data/ledger_repository_impl.dart';
import 'package:khata_flow/features/merchant/data/merchant_repository_impl.dart';
import 'package:khata_flow/features/settlement/data/settlement_repository_impl.dart';
import 'package:khata_flow/features/voice/data/deterministic_voice_command_parser.dart';
import 'package:khata_flow/features/voice/domain/merchant_resolver.dart';
import 'package:khata_flow/features/voice/domain/voice_command.dart';
import 'package:khata_flow/features/voice/domain/voice_transcript.dart';
import 'package:khata_flow/features/voice/presentation/voice_controller.dart';
import 'package:khata_flow/features/voice/presentation/voice_state.dart';

class StubVoiceService implements VoiceService {
  @override
  bool get isListening => false;
  @override
  bool get isAvailable => true;
  @override
  Future<bool> initialize() async => true;
  @override
  Future<bool> hasPermission() async => true;
  @override
  Future<void> startListening({required void Function(String text, bool isFinal) onResult, required void Function(String error) onError, String? localeId}) async {}
  @override
  Future<void> stopListening() async {}
  @override
  Future<void> cancelListening() async {}
}

void main() {
  group('Voice Expense End-to-End Real SQLite Integration Tests (M6.5)', () {
    late AppDatabase db;
    late ExpenseRepositoryImpl expenseRepo;
    late MerchantRepositoryImpl merchantRepo;
    late LedgerRepositoryImpl ledgerRepo;
    late SettlementRepositoryImpl settlementRepo;
    late VoiceController controller;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      expenseRepo = ExpenseRepositoryImpl(db);
      merchantRepo = MerchantRepositoryImpl(db);
      ledgerRepo = LedgerRepositoryImpl(db);
      settlementRepo = SettlementRepositoryImpl(db);

      controller = VoiceController(
        voiceService: StubVoiceService(),
        parser: const DeterministicVoiceCommandParser(),
        merchantRepository: merchantRepo,
        ledgerRepository: ledgerRepo,
        settlementRepository: settlementRepo,
        expenseRepository: expenseRepo,
        merchantResolver: const MerchantResolver(),
      );
    });

    tearDown(() async {
      controller.dispose();
      await db.close();
    });

    test('Speech transcript -> Parser -> Command -> Controller -> Confirmation -> Real SQLite + SyncQueue -> Reactivity', () async {
      // 1. Process Spoken Expense
      await controller.processTranscript(
        VoiceTranscript(
          text: 'Food pe 250 kharch kiye',
          locale: 'en_IN',
          isFinal: true,
          capturedAt: DateTime.now(),
        ),
      );

      expect(controller.state.status, equals(VoiceStatus.commandReady));
      expect(controller.state.command, isA<AddExpenseCommand>());
      final cmd = controller.state.command as AddExpenseCommand;
      expect(cmd.amountPaise, equals(25000));
      expect(cmd.category, equals(ExpenseCategory.food));
      expect(controller.state.pendingExpenseCategory, equals(ExpenseCategory.food));

      // 2. Explicit User Confirmation
      final success = await controller.executeConfirmedCommand();
      expect(success, isTrue);
      expect(controller.state.status, equals(VoiceStatus.completed));

      // 3. Verify SQLite Expenses table record
      final dbExpenses = await db.select(db.expenses).get();
      expect(dbExpenses.length, equals(1));
      final row = dbExpenses.first;
      expect(row.amountPaise, equals(25000));
      expect(row.category, equals('FOOD'));
      expect(row.note, isNull);

      // 4. Verify SQLite SyncQueue table outbox record
      final syncEntries = await db.select(db.syncQueue).get();
      expect(syncEntries.length, equals(1));
      expect(syncEntries.first.entityType, equals('EXPENSE'));
      expect(syncEntries.first.entityId, equals(row.id));
      expect(syncEntries.first.operation, equals('UPSERT'));

      // 5. Verify Zero Merchant Ledger Mutations
      final merchants = await db.select(db.merchants).get();
      expect(merchants, isEmpty);
      final purchases = await db.select(db.purchases).get();
      expect(purchases, isEmpty);
      final settlements = await db.select(db.settlements).get();
      expect(settlements, isEmpty);

      // 6. Verify Reactive Stream & Dashboard Summary Integration
      final currentExpenses = await expenseRepo.getExpenses();
      expect(currentExpenses.length, equals(1));
      final dashboardSummary = deriveExpenseDashboardSummary(currentExpenses, DateTime.now());
      expect(dashboardSummary.totalAmountPaise, equals(25000));
      expect(dashboardSummary.currentMonthExpenseCount, equals(1));
      expect(dashboardSummary.categoryBreakdown.first.category, equals(ExpenseCategory.food));
      expect(dashboardSummary.categoryBreakdown.first.totalAmountPaise, equals(25000));
    });

    test('Speech transcript without category requires category selection before SQLite persistence', () async {
      await controller.processTranscript(
        VoiceTranscript(
          text: 'Spent 500',
          locale: 'en_IN',
          isFinal: true,
          capturedAt: DateTime.now(),
        ),
      );

      expect(controller.state.status, equals(VoiceStatus.commandReady));
      expect(controller.state.pendingExpenseCategory, isNull);

      // User selects Transport category in confirmation UI
      controller.setPendingExpenseCategory(ExpenseCategory.transport);

      final success = await controller.executeConfirmedCommand();
      expect(success, isTrue);
      expect(controller.state.status, equals(VoiceStatus.completed));

      // Verify SQLite row
      final dbExpenses = await db.select(db.expenses).get();
      expect(dbExpenses.length, equals(1));
      expect(dbExpenses.first.amountPaise, equals(50000));
      expect(dbExpenses.first.category, equals('TRANSPORT'));
    });
  });
}
