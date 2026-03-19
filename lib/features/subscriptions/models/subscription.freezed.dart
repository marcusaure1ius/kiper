// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'subscription.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Subscription {

 String get id; String get name; String? get icon; double get amount; Currency get currency; BillingPeriod get billingPeriod; int? get customPeriodDays; String? get categoryId; DateTime get nextBillingDate; int get reminderDaysBefore; SubscriptionStatus get status; DateTime get startDate; String? get note; DateTime get createdAt;
/// Create a copy of Subscription
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SubscriptionCopyWith<Subscription> get copyWith => _$SubscriptionCopyWithImpl<Subscription>(this as Subscription, _$identity);

  /// Serializes this Subscription to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Subscription&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.icon, icon) || other.icon == icon)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.currency, currency) || other.currency == currency)&&(identical(other.billingPeriod, billingPeriod) || other.billingPeriod == billingPeriod)&&(identical(other.customPeriodDays, customPeriodDays) || other.customPeriodDays == customPeriodDays)&&(identical(other.categoryId, categoryId) || other.categoryId == categoryId)&&(identical(other.nextBillingDate, nextBillingDate) || other.nextBillingDate == nextBillingDate)&&(identical(other.reminderDaysBefore, reminderDaysBefore) || other.reminderDaysBefore == reminderDaysBefore)&&(identical(other.status, status) || other.status == status)&&(identical(other.startDate, startDate) || other.startDate == startDate)&&(identical(other.note, note) || other.note == note)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,icon,amount,currency,billingPeriod,customPeriodDays,categoryId,nextBillingDate,reminderDaysBefore,status,startDate,note,createdAt);

@override
String toString() {
  return 'Subscription(id: $id, name: $name, icon: $icon, amount: $amount, currency: $currency, billingPeriod: $billingPeriod, customPeriodDays: $customPeriodDays, categoryId: $categoryId, nextBillingDate: $nextBillingDate, reminderDaysBefore: $reminderDaysBefore, status: $status, startDate: $startDate, note: $note, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $SubscriptionCopyWith<$Res>  {
  factory $SubscriptionCopyWith(Subscription value, $Res Function(Subscription) _then) = _$SubscriptionCopyWithImpl;
@useResult
$Res call({
 String id, String name, String? icon, double amount, Currency currency, BillingPeriod billingPeriod, int? customPeriodDays, String? categoryId, DateTime nextBillingDate, int reminderDaysBefore, SubscriptionStatus status, DateTime startDate, String? note, DateTime createdAt
});




}
/// @nodoc
class _$SubscriptionCopyWithImpl<$Res>
    implements $SubscriptionCopyWith<$Res> {
  _$SubscriptionCopyWithImpl(this._self, this._then);

  final Subscription _self;
  final $Res Function(Subscription) _then;

/// Create a copy of Subscription
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? icon = freezed,Object? amount = null,Object? currency = null,Object? billingPeriod = null,Object? customPeriodDays = freezed,Object? categoryId = freezed,Object? nextBillingDate = null,Object? reminderDaysBefore = null,Object? status = null,Object? startDate = null,Object? note = freezed,Object? createdAt = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,icon: freezed == icon ? _self.icon : icon // ignore: cast_nullable_to_non_nullable
as String?,amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as double,currency: null == currency ? _self.currency : currency // ignore: cast_nullable_to_non_nullable
as Currency,billingPeriod: null == billingPeriod ? _self.billingPeriod : billingPeriod // ignore: cast_nullable_to_non_nullable
as BillingPeriod,customPeriodDays: freezed == customPeriodDays ? _self.customPeriodDays : customPeriodDays // ignore: cast_nullable_to_non_nullable
as int?,categoryId: freezed == categoryId ? _self.categoryId : categoryId // ignore: cast_nullable_to_non_nullable
as String?,nextBillingDate: null == nextBillingDate ? _self.nextBillingDate : nextBillingDate // ignore: cast_nullable_to_non_nullable
as DateTime,reminderDaysBefore: null == reminderDaysBefore ? _self.reminderDaysBefore : reminderDaysBefore // ignore: cast_nullable_to_non_nullable
as int,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as SubscriptionStatus,startDate: null == startDate ? _self.startDate : startDate // ignore: cast_nullable_to_non_nullable
as DateTime,note: freezed == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [Subscription].
extension SubscriptionPatterns on Subscription {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Subscription value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Subscription() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Subscription value)  $default,){
final _that = this;
switch (_that) {
case _Subscription():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Subscription value)?  $default,){
final _that = this;
switch (_that) {
case _Subscription() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String? icon,  double amount,  Currency currency,  BillingPeriod billingPeriod,  int? customPeriodDays,  String? categoryId,  DateTime nextBillingDate,  int reminderDaysBefore,  SubscriptionStatus status,  DateTime startDate,  String? note,  DateTime createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Subscription() when $default != null:
return $default(_that.id,_that.name,_that.icon,_that.amount,_that.currency,_that.billingPeriod,_that.customPeriodDays,_that.categoryId,_that.nextBillingDate,_that.reminderDaysBefore,_that.status,_that.startDate,_that.note,_that.createdAt);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String? icon,  double amount,  Currency currency,  BillingPeriod billingPeriod,  int? customPeriodDays,  String? categoryId,  DateTime nextBillingDate,  int reminderDaysBefore,  SubscriptionStatus status,  DateTime startDate,  String? note,  DateTime createdAt)  $default,) {final _that = this;
switch (_that) {
case _Subscription():
return $default(_that.id,_that.name,_that.icon,_that.amount,_that.currency,_that.billingPeriod,_that.customPeriodDays,_that.categoryId,_that.nextBillingDate,_that.reminderDaysBefore,_that.status,_that.startDate,_that.note,_that.createdAt);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String? icon,  double amount,  Currency currency,  BillingPeriod billingPeriod,  int? customPeriodDays,  String? categoryId,  DateTime nextBillingDate,  int reminderDaysBefore,  SubscriptionStatus status,  DateTime startDate,  String? note,  DateTime createdAt)?  $default,) {final _that = this;
switch (_that) {
case _Subscription() when $default != null:
return $default(_that.id,_that.name,_that.icon,_that.amount,_that.currency,_that.billingPeriod,_that.customPeriodDays,_that.categoryId,_that.nextBillingDate,_that.reminderDaysBefore,_that.status,_that.startDate,_that.note,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Subscription implements Subscription {
  const _Subscription({required this.id, required this.name, this.icon, required this.amount, required this.currency, required this.billingPeriod, this.customPeriodDays, this.categoryId, required this.nextBillingDate, this.reminderDaysBefore = 1, this.status = SubscriptionStatus.active, required this.startDate, this.note, required this.createdAt});
  factory _Subscription.fromJson(Map<String, dynamic> json) => _$SubscriptionFromJson(json);

@override final  String id;
@override final  String name;
@override final  String? icon;
@override final  double amount;
@override final  Currency currency;
@override final  BillingPeriod billingPeriod;
@override final  int? customPeriodDays;
@override final  String? categoryId;
@override final  DateTime nextBillingDate;
@override@JsonKey() final  int reminderDaysBefore;
@override@JsonKey() final  SubscriptionStatus status;
@override final  DateTime startDate;
@override final  String? note;
@override final  DateTime createdAt;

/// Create a copy of Subscription
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SubscriptionCopyWith<_Subscription> get copyWith => __$SubscriptionCopyWithImpl<_Subscription>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SubscriptionToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Subscription&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.icon, icon) || other.icon == icon)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.currency, currency) || other.currency == currency)&&(identical(other.billingPeriod, billingPeriod) || other.billingPeriod == billingPeriod)&&(identical(other.customPeriodDays, customPeriodDays) || other.customPeriodDays == customPeriodDays)&&(identical(other.categoryId, categoryId) || other.categoryId == categoryId)&&(identical(other.nextBillingDate, nextBillingDate) || other.nextBillingDate == nextBillingDate)&&(identical(other.reminderDaysBefore, reminderDaysBefore) || other.reminderDaysBefore == reminderDaysBefore)&&(identical(other.status, status) || other.status == status)&&(identical(other.startDate, startDate) || other.startDate == startDate)&&(identical(other.note, note) || other.note == note)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,icon,amount,currency,billingPeriod,customPeriodDays,categoryId,nextBillingDate,reminderDaysBefore,status,startDate,note,createdAt);

@override
String toString() {
  return 'Subscription(id: $id, name: $name, icon: $icon, amount: $amount, currency: $currency, billingPeriod: $billingPeriod, customPeriodDays: $customPeriodDays, categoryId: $categoryId, nextBillingDate: $nextBillingDate, reminderDaysBefore: $reminderDaysBefore, status: $status, startDate: $startDate, note: $note, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$SubscriptionCopyWith<$Res> implements $SubscriptionCopyWith<$Res> {
  factory _$SubscriptionCopyWith(_Subscription value, $Res Function(_Subscription) _then) = __$SubscriptionCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String? icon, double amount, Currency currency, BillingPeriod billingPeriod, int? customPeriodDays, String? categoryId, DateTime nextBillingDate, int reminderDaysBefore, SubscriptionStatus status, DateTime startDate, String? note, DateTime createdAt
});




}
/// @nodoc
class __$SubscriptionCopyWithImpl<$Res>
    implements _$SubscriptionCopyWith<$Res> {
  __$SubscriptionCopyWithImpl(this._self, this._then);

  final _Subscription _self;
  final $Res Function(_Subscription) _then;

/// Create a copy of Subscription
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? icon = freezed,Object? amount = null,Object? currency = null,Object? billingPeriod = null,Object? customPeriodDays = freezed,Object? categoryId = freezed,Object? nextBillingDate = null,Object? reminderDaysBefore = null,Object? status = null,Object? startDate = null,Object? note = freezed,Object? createdAt = null,}) {
  return _then(_Subscription(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,icon: freezed == icon ? _self.icon : icon // ignore: cast_nullable_to_non_nullable
as String?,amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as double,currency: null == currency ? _self.currency : currency // ignore: cast_nullable_to_non_nullable
as Currency,billingPeriod: null == billingPeriod ? _self.billingPeriod : billingPeriod // ignore: cast_nullable_to_non_nullable
as BillingPeriod,customPeriodDays: freezed == customPeriodDays ? _self.customPeriodDays : customPeriodDays // ignore: cast_nullable_to_non_nullable
as int?,categoryId: freezed == categoryId ? _self.categoryId : categoryId // ignore: cast_nullable_to_non_nullable
as String?,nextBillingDate: null == nextBillingDate ? _self.nextBillingDate : nextBillingDate // ignore: cast_nullable_to_non_nullable
as DateTime,reminderDaysBefore: null == reminderDaysBefore ? _self.reminderDaysBefore : reminderDaysBefore // ignore: cast_nullable_to_non_nullable
as int,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as SubscriptionStatus,startDate: null == startDate ? _self.startDate : startDate // ignore: cast_nullable_to_non_nullable
as DateTime,note: freezed == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

// dart format on
