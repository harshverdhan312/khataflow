import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khata_flow/core/services/voice_service.dart';
import 'package:khata_flow/features/dashboard/domain/dashboard_summary.dart';
import 'package:khata_flow/features/dashboard/presentation/dashboard_providers.dart';
import 'package:khata_flow/features/dashboard/presentation/dashboard_screen.dart';
import 'package:khata_flow/features/merchant/domain/merchant.dart';
import 'package:khata_flow/features/merchant/domain/merchant_category.dart';
import 'package:khata_flow/features/merchant/domain/merchant_repository.dart';
import 'package:khata_flow/features/merchant/presentation/merchant_providers.dart';
import 'package:khata_flow/features/voice/presentation/voice_entry_sheet.dart';
import 'package:khata_flow/features/voice/presentation/voice_providers.dart';

class FakeVoiceService implements VoiceService {
  bool initializeResult = true;
  bool permissionResult = true;
  bool listening = false;
  void Function(String text, bool isFinal)? onResultCallback;
  void Function(String error)? onErrorCallback;
  String? lastLocaleId;

  @override
  bool get isListening => listening;

  @override
  bool get isAvailable => initializeResult;

  @override
  Future<bool> initialize() async => initializeResult;

  @override
  Future<bool> hasPermission() async => permissionResult;

  @override
  Future<void> startListening({
    required void Function(String text, bool isFinal) onResult,
    required void Function(String error) onError,
    String? localeId,
  }) async {
    listening = true;
    onResultCallback = onResult;
    onErrorCallback = onError;
    lastLocaleId = localeId;
  }

  @override
  Future<void> stopListening() async {
    listening = false;
  }

  @override
  Future<void> cancelListening() async {
    listening = false;
  }

  void emitResult(String text, bool isFinal) {
    onResultCallback?.call(text, isFinal);
  }

  void emitError(String error) {
    onErrorCallback?.call(error);
  }
}

class FakeMerchantRepository implements MerchantRepository {
  List<Merchant> merchants = [];

  @override
  Future<List<Merchant>> getActiveMerchants() async => merchants;
  @override
  Future<Merchant?> getMerchantById(String id) async => null;
  @override
  Future<Merchant> createMerchant(CreateMerchantInput input) async => throw UnimplementedError();
  @override
  Future<void> deactivateMerchant(String merchantId) async {}
  @override
  Future<void> reactivateMerchant(String merchantId) async {}
  @override
  Future<void> updateMerchant(Merchant merchant) async {}
  @override
  Stream<List<Merchant>> watchActiveMerchants() => Stream.value(merchants);
  @override
  Stream<List<Merchant>> watchInactiveMerchants() => Stream.value([]);
}

void main() {
  group('Voice Ledger Widget Tests', () {
    late FakeVoiceService fakeVoiceService;
    late FakeMerchantRepository fakeMerchantRepo;

    final testMerchant = Merchant(
      id: 'm1',
      name: 'Sharma General Store',
      category: MerchantCategory.grocery,
      phone: '9876543210',
      upiVpa: 'sharma@upi',
      isActive: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    setUp(() {
      fakeVoiceService = FakeVoiceService();
      fakeMerchantRepo = FakeMerchantRepository();
      fakeMerchantRepo.merchants = [testMerchant];
    });

    testWidgets('Dashboard mic button opens VoiceEntrySheet and starts listening', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            voiceServiceProvider.overrideWithValue(fakeVoiceService),
            merchantRepositoryProvider.overrideWithValue(fakeMerchantRepo),
            activeMerchantsStreamProvider.overrideWith((ref) => Stream.value([testMerchant])),
            dashboardSummaryStreamProvider.overrideWith(
              (ref) => Stream.value(
                const DashboardSummary(
                  totalOutstandingPaise: 0,
                  merchantSummaries: [],
                ),
              ),
            ),
            inactiveMerchantsStreamProvider.overrideWith((ref) => Stream.value([])),
          ],
          child: const MaterialApp(
            home: DashboardScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify mic button in AppBar
      expect(find.byIcon(Icons.mic_rounded), findsOneWidget);

      // Tap mic button
      await tester.tap(find.byIcon(Icons.mic_rounded));
      await tester.pumpAndSettle();

      // Verify VoiceEntrySheet opened
      expect(find.byType(VoiceEntrySheet), findsOneWidget);
      expect(find.text('Voice Ledger'), findsOneWidget);
      expect(find.text('Listening...'), findsOneWidget);
      expect(find.text('English'), findsOneWidget);
      expect(find.text('हिन्दी'), findsOneWidget);
    });

    testWidgets('Displays partial speech transcript dynamically during listening', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            voiceServiceProvider.overrideWithValue(fakeVoiceService),
            merchantRepositoryProvider.overrideWithValue(fakeMerchantRepo),
            activeMerchantsStreamProvider.overrideWith((ref) => Stream.value([testMerchant])),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: VoiceEntrySheet(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Listening...'), findsOneWidget);

      // Emit partial transcript
      fakeVoiceService.emitResult('Sharma se doodh 60', false);
      await tester.pump();

      expect(find.text('"Sharma se doodh 60"'), findsOneWidget);
    });

    testWidgets('Transitions to Review Purchase confirmation when speech is final and merchant matches', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            voiceServiceProvider.overrideWithValue(fakeVoiceService),
            merchantRepositoryProvider.overrideWithValue(fakeMerchantRepo),
            activeMerchantsStreamProvider.overrideWith((ref) => Stream.value([testMerchant])),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: VoiceEntrySheet(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Emit speech and tap Done
      fakeVoiceService.emitResult('Sharma se doodh 60 aur bread 40 liya', false);
      await tester.pump();

      expect(find.text('Done'), findsOneWidget);
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      // M5.3 Confirmation UI
      expect(find.text('Review Purchase'), findsOneWidget);
      expect(find.text('Sharma General Store'), findsOneWidget);
      expect(find.text('Doodh'), findsOneWidget);
      expect(find.text('₹60'), findsOneWidget);
      expect(find.text('Bread'), findsOneWidget);
      expect(find.text('₹40'), findsOneWidget);
      expect(find.text('₹100'), findsOneWidget);
      expect(find.text('Record Purchase'), findsOneWidget);
    });

    testWidgets('Cancel button clears transcript and dismisses bottom sheet', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            voiceServiceProvider.overrideWithValue(fakeVoiceService),
            merchantRepositoryProvider.overrideWithValue(fakeMerchantRepo),
            activeMerchantsStreamProvider.overrideWith((ref) => Stream.value([testMerchant])),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                return Scaffold(
                  body: ElevatedButton(
                    onPressed: () => VoiceEntrySheet.show(context),
                    child: const Text('Open Sheet'),
                  ),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      expect(find.byType(VoiceEntrySheet), findsOneWidget);

      // Emit some speech
      fakeVoiceService.emitResult('Temporary words', false);
      await tester.pump();
      expect(find.text('"Temporary words"'), findsOneWidget);

      // Tap Cancel
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Sheet is dismissed
      expect(find.byType(VoiceEntrySheet), findsNothing);
    });

    testWidgets('Error state displays clear failure message and Try Again option', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            voiceServiceProvider.overrideWithValue(fakeVoiceService),
            merchantRepositoryProvider.overrideWithValue(fakeMerchantRepo),
            activeMerchantsStreamProvider.overrideWith((ref) => Stream.value([testMerchant])),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: VoiceEntrySheet(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      fakeVoiceService.emitError('Microphone permission is required to use Voice Ledger.');
      await tester.pump();

      expect(find.text('Could not process voice entry'), findsOneWidget);
      expect(find.text('Microphone permission is required to use Voice Ledger.'), findsOneWidget);
      expect(find.text('Try Again'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('Language toggle switches locale between English and Hindi', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            voiceServiceProvider.overrideWithValue(fakeVoiceService),
            merchantRepositoryProvider.overrideWithValue(fakeMerchantRepo),
            activeMerchantsStreamProvider.overrideWith((ref) => Stream.value([testMerchant])),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: VoiceEntrySheet(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(fakeVoiceService.lastLocaleId, equals('en_IN'));

      // Tap हिन्दी
      await tester.tap(find.text('हिन्दी'));
      await tester.pump();

      // Emit invalid speech to get to error state
      fakeVoiceService.emitError('Some error');
      await tester.pumpAndSettle();

      expect(find.text('Try Again'), findsOneWidget);
      await tester.tap(find.text('Try Again'));
      await tester.pumpAndSettle();

      expect(fakeVoiceService.lastLocaleId, equals('hi_IN'));
    });
  });
}
