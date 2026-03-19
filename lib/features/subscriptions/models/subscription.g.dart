// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'subscription.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Subscription _$SubscriptionFromJson(Map<String, dynamic> json) =>
    _Subscription(
      id: json['id'] as String,
      name: json['name'] as String,
      icon: json['icon'] as String?,
      amount: (json['amount'] as num).toDouble(),
      currency: $enumDecode(_$CurrencyEnumMap, json['currency']),
      billingPeriod: $enumDecode(_$BillingPeriodEnumMap, json['billingPeriod']),
      customPeriodDays: (json['customPeriodDays'] as num?)?.toInt(),
      categoryId: json['categoryId'] as String?,
      nextBillingDate: DateTime.parse(json['nextBillingDate'] as String),
      reminderDaysBefore: (json['reminderDaysBefore'] as num?)?.toInt() ?? 1,
      status:
          $enumDecodeNullable(_$SubscriptionStatusEnumMap, json['status']) ??
          SubscriptionStatus.active,
      startDate: DateTime.parse(json['startDate'] as String),
      note: json['note'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );

Map<String, dynamic> _$SubscriptionToJson(_Subscription instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'icon': instance.icon,
      'amount': instance.amount,
      'currency': _$CurrencyEnumMap[instance.currency]!,
      'billingPeriod': _$BillingPeriodEnumMap[instance.billingPeriod]!,
      'customPeriodDays': instance.customPeriodDays,
      'categoryId': instance.categoryId,
      'nextBillingDate': instance.nextBillingDate.toIso8601String(),
      'reminderDaysBefore': instance.reminderDaysBefore,
      'status': _$SubscriptionStatusEnumMap[instance.status]!,
      'startDate': instance.startDate.toIso8601String(),
      'note': instance.note,
      'createdAt': instance.createdAt.toIso8601String(),
    };

const _$CurrencyEnumMap = {
  Currency.rub: 'rub',
  Currency.usd: 'usd',
  Currency.eur: 'eur',
};

const _$BillingPeriodEnumMap = {
  BillingPeriod.weekly: 'weekly',
  BillingPeriod.monthly: 'monthly',
  BillingPeriod.quarterly: 'quarterly',
  BillingPeriod.semiannual: 'semiannual',
  BillingPeriod.annual: 'annual',
  BillingPeriod.custom: 'custom',
};

const _$SubscriptionStatusEnumMap = {
  SubscriptionStatus.active: 'active',
  SubscriptionStatus.paused: 'paused',
  SubscriptionStatus.cancelled: 'cancelled',
};
