// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'reading_history_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ReadingHistory {

 String get date;// Formato "YYYY-MM-DD"
 List<ChapterRead> get chapters; int get durationSeconds;
/// Create a copy of ReadingHistory
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ReadingHistoryCopyWith<ReadingHistory> get copyWith => _$ReadingHistoryCopyWithImpl<ReadingHistory>(this as ReadingHistory, _$identity);

  /// Serializes this ReadingHistory to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ReadingHistory&&(identical(other.date, date) || other.date == date)&&const DeepCollectionEquality().equals(other.chapters, chapters)&&(identical(other.durationSeconds, durationSeconds) || other.durationSeconds == durationSeconds));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,date,const DeepCollectionEquality().hash(chapters),durationSeconds);

@override
String toString() {
  return 'ReadingHistory(date: $date, chapters: $chapters, durationSeconds: $durationSeconds)';
}


}

/// @nodoc
abstract mixin class $ReadingHistoryCopyWith<$Res>  {
  factory $ReadingHistoryCopyWith(ReadingHistory value, $Res Function(ReadingHistory) _then) = _$ReadingHistoryCopyWithImpl;
@useResult
$Res call({
 String date, List<ChapterRead> chapters, int durationSeconds
});




}
/// @nodoc
class _$ReadingHistoryCopyWithImpl<$Res>
    implements $ReadingHistoryCopyWith<$Res> {
  _$ReadingHistoryCopyWithImpl(this._self, this._then);

  final ReadingHistory _self;
  final $Res Function(ReadingHistory) _then;

/// Create a copy of ReadingHistory
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? date = null,Object? chapters = null,Object? durationSeconds = null,}) {
  return _then(_self.copyWith(
date: null == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as String,chapters: null == chapters ? _self.chapters : chapters // ignore: cast_nullable_to_non_nullable
as List<ChapterRead>,durationSeconds: null == durationSeconds ? _self.durationSeconds : durationSeconds // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [ReadingHistory].
extension ReadingHistoryPatterns on ReadingHistory {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ReadingHistory value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ReadingHistory() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ReadingHistory value)  $default,){
final _that = this;
switch (_that) {
case _ReadingHistory():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ReadingHistory value)?  $default,){
final _that = this;
switch (_that) {
case _ReadingHistory() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String date,  List<ChapterRead> chapters,  int durationSeconds)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ReadingHistory() when $default != null:
return $default(_that.date,_that.chapters,_that.durationSeconds);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String date,  List<ChapterRead> chapters,  int durationSeconds)  $default,) {final _that = this;
switch (_that) {
case _ReadingHistory():
return $default(_that.date,_that.chapters,_that.durationSeconds);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String date,  List<ChapterRead> chapters,  int durationSeconds)?  $default,) {final _that = this;
switch (_that) {
case _ReadingHistory() when $default != null:
return $default(_that.date,_that.chapters,_that.durationSeconds);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ReadingHistory implements ReadingHistory {
  const _ReadingHistory({required this.date, final  List<ChapterRead> chapters = const [], this.durationSeconds = 0}): _chapters = chapters;
  factory _ReadingHistory.fromJson(Map<String, dynamic> json) => _$ReadingHistoryFromJson(json);

@override final  String date;
// Formato "YYYY-MM-DD"
 final  List<ChapterRead> _chapters;
// Formato "YYYY-MM-DD"
@override@JsonKey() List<ChapterRead> get chapters {
  if (_chapters is EqualUnmodifiableListView) return _chapters;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_chapters);
}

@override@JsonKey() final  int durationSeconds;

/// Create a copy of ReadingHistory
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ReadingHistoryCopyWith<_ReadingHistory> get copyWith => __$ReadingHistoryCopyWithImpl<_ReadingHistory>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ReadingHistoryToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ReadingHistory&&(identical(other.date, date) || other.date == date)&&const DeepCollectionEquality().equals(other._chapters, _chapters)&&(identical(other.durationSeconds, durationSeconds) || other.durationSeconds == durationSeconds));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,date,const DeepCollectionEquality().hash(_chapters),durationSeconds);

@override
String toString() {
  return 'ReadingHistory(date: $date, chapters: $chapters, durationSeconds: $durationSeconds)';
}


}

/// @nodoc
abstract mixin class _$ReadingHistoryCopyWith<$Res> implements $ReadingHistoryCopyWith<$Res> {
  factory _$ReadingHistoryCopyWith(_ReadingHistory value, $Res Function(_ReadingHistory) _then) = __$ReadingHistoryCopyWithImpl;
@override @useResult
$Res call({
 String date, List<ChapterRead> chapters, int durationSeconds
});




}
/// @nodoc
class __$ReadingHistoryCopyWithImpl<$Res>
    implements _$ReadingHistoryCopyWith<$Res> {
  __$ReadingHistoryCopyWithImpl(this._self, this._then);

  final _ReadingHistory _self;
  final $Res Function(_ReadingHistory) _then;

/// Create a copy of ReadingHistory
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? date = null,Object? chapters = null,Object? durationSeconds = null,}) {
  return _then(_ReadingHistory(
date: null == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as String,chapters: null == chapters ? _self._chapters : chapters // ignore: cast_nullable_to_non_nullable
as List<ChapterRead>,durationSeconds: null == durationSeconds ? _self.durationSeconds : durationSeconds // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$ChapterRead {

 String get book;// Ex: "GEN"
 int get chapter;
/// Create a copy of ChapterRead
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ChapterReadCopyWith<ChapterRead> get copyWith => _$ChapterReadCopyWithImpl<ChapterRead>(this as ChapterRead, _$identity);

  /// Serializes this ChapterRead to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ChapterRead&&(identical(other.book, book) || other.book == book)&&(identical(other.chapter, chapter) || other.chapter == chapter));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,book,chapter);

@override
String toString() {
  return 'ChapterRead(book: $book, chapter: $chapter)';
}


}

/// @nodoc
abstract mixin class $ChapterReadCopyWith<$Res>  {
  factory $ChapterReadCopyWith(ChapterRead value, $Res Function(ChapterRead) _then) = _$ChapterReadCopyWithImpl;
@useResult
$Res call({
 String book, int chapter
});




}
/// @nodoc
class _$ChapterReadCopyWithImpl<$Res>
    implements $ChapterReadCopyWith<$Res> {
  _$ChapterReadCopyWithImpl(this._self, this._then);

  final ChapterRead _self;
  final $Res Function(ChapterRead) _then;

/// Create a copy of ChapterRead
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? book = null,Object? chapter = null,}) {
  return _then(_self.copyWith(
book: null == book ? _self.book : book // ignore: cast_nullable_to_non_nullable
as String,chapter: null == chapter ? _self.chapter : chapter // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [ChapterRead].
extension ChapterReadPatterns on ChapterRead {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ChapterRead value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ChapterRead() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ChapterRead value)  $default,){
final _that = this;
switch (_that) {
case _ChapterRead():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ChapterRead value)?  $default,){
final _that = this;
switch (_that) {
case _ChapterRead() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String book,  int chapter)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ChapterRead() when $default != null:
return $default(_that.book,_that.chapter);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String book,  int chapter)  $default,) {final _that = this;
switch (_that) {
case _ChapterRead():
return $default(_that.book,_that.chapter);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String book,  int chapter)?  $default,) {final _that = this;
switch (_that) {
case _ChapterRead() when $default != null:
return $default(_that.book,_that.chapter);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ChapterRead implements ChapterRead {
  const _ChapterRead({required this.book, required this.chapter});
  factory _ChapterRead.fromJson(Map<String, dynamic> json) => _$ChapterReadFromJson(json);

@override final  String book;
// Ex: "GEN"
@override final  int chapter;

/// Create a copy of ChapterRead
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ChapterReadCopyWith<_ChapterRead> get copyWith => __$ChapterReadCopyWithImpl<_ChapterRead>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ChapterReadToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ChapterRead&&(identical(other.book, book) || other.book == book)&&(identical(other.chapter, chapter) || other.chapter == chapter));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,book,chapter);

@override
String toString() {
  return 'ChapterRead(book: $book, chapter: $chapter)';
}


}

/// @nodoc
abstract mixin class _$ChapterReadCopyWith<$Res> implements $ChapterReadCopyWith<$Res> {
  factory _$ChapterReadCopyWith(_ChapterRead value, $Res Function(_ChapterRead) _then) = __$ChapterReadCopyWithImpl;
@override @useResult
$Res call({
 String book, int chapter
});




}
/// @nodoc
class __$ChapterReadCopyWithImpl<$Res>
    implements _$ChapterReadCopyWith<$Res> {
  __$ChapterReadCopyWithImpl(this._self, this._then);

  final _ChapterRead _self;
  final $Res Function(_ChapterRead) _then;

/// Create a copy of ChapterRead
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? book = null,Object? chapter = null,}) {
  return _then(_ChapterRead(
book: null == book ? _self.book : book // ignore: cast_nullable_to_non_nullable
as String,chapter: null == chapter ? _self.chapter : chapter // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
