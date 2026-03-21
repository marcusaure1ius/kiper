import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:kiper/core/currency/currency.dart';
import 'package:kiper/features/subscriptions/models/billing_period.dart';
import 'package:kiper/features/subscriptions/models/subscription_status.dart';

part 'subscription.freezed.dart';
part 'subscription.g.dart';

@freezed
abstract class Subscription with _$Subscription {
  const factory Subscription({
    required String id,
    required String name,
    String? icon,
    required double amount,
    required Currency currency,
    required BillingPeriod billingPeriod,
    int? customPeriodDays,
    String? categoryId,
    required DateTime nextBillingDate,
    @Default(1) int reminderDaysBefore,
    @Default(SubscriptionStatus.active) SubscriptionStatus status,
    required DateTime startDate,
    String? note,
    required DateTime createdAt,
  }) = _Subscription;

  factory Subscription.fromJson(Map<String, dynamic> json) =>
      _$SubscriptionFromJson(json);
}
