import 'package:flutter_test/flutter_test.dart';
import 'package:sub_tracker/features/subscriptions/models/billing_period.dart';

void main() {
  group('BillingPeriod', () {
    test('nextDate advances monthly correctly', () {
      final date = DateTime(2026, 1, 15);
      final next = BillingPeriod.monthly.nextDate(date);
      expect(next, DateTime(2026, 2, 15));
    });

    test('nextDate advances quarterly correctly', () {
      final date = DateTime(2026, 1, 15);
      final next = BillingPeriod.quarterly.nextDate(date);
      expect(next, DateTime(2026, 4, 15));
    });

    test('nextDate advances annually correctly', () {
      final date = DateTime(2026, 1, 15);
      final next = BillingPeriod.annual.nextDate(date);
      expect(next, DateTime(2027, 1, 15));
    });

    test('nextDate advances weekly correctly', () {
      final date = DateTime(2026, 1, 15);
      final next = BillingPeriod.weekly.nextDate(date);
      expect(next, DateTime(2026, 1, 22));
    });

    test('nextDate advances semiannually correctly', () {
      final date = DateTime(2026, 1, 15);
      final next = BillingPeriod.semiannual.nextDate(date);
      expect(next, DateTime(2026, 7, 15));
    });

    test('monthlyEquivalent returns correct multiplier', () {
      expect(BillingPeriod.monthly.monthlyEquivalent, 1.0);
      expect(BillingPeriod.quarterly.monthlyEquivalent, closeTo(0.3333, 0.001));
      expect(BillingPeriod.annual.monthlyEquivalent, closeTo(0.0833, 0.001));
      expect(BillingPeriod.weekly.monthlyEquivalent, closeTo(4.333, 0.01));
      expect(BillingPeriod.semiannual.monthlyEquivalent, closeTo(0.1667, 0.001));
    });

    test('customNextDate advances by N days', () {
      final date = DateTime(2026, 1, 15);
      final next = BillingPeriod.custom.nextDateCustom(date, 45);
      expect(next, DateTime(2026, 3, 1));
    });
  });
}
