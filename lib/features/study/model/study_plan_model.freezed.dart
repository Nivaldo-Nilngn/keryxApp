// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'study_plan_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$StudyPlan {

 String get id; String get title; String get description; String get level;// beginner, intermediate, advanced, premium
 int get durationDays; bool get isPremium; String? get category; String? get coverImage;
/// Create a copy of StudyPlan
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StudyPlanCopyWith<StudyPlan> get copyWith => _$StudyPlanCopyWithImpl<StudyPlan>(this as StudyPlan, _$identity);

  /// Serializes this StudyPlan to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StudyPlan&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.description, description) || other.description == description)&&(identical(other.level, level) || other.level == level)&&(identical(other.durationDays, durationDays) || other.durationDays == durationDays)&&(identical(other.isPremium, isPremium) || other.isPremium == isPremium)&&(identical(other.category, category) || other.category == category)&&(identical(other.coverImage, coverImage) || other.coverImage == coverImage));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,title,description,level,durationDays,isPremium,category,coverImage);

@override
String toString() {
  return 'StudyPlan(id: $id, title: $title, description: $description, level: $level, durationDays: $durationDays, isPremium: $isPremium, category: $category, coverImage: $coverImage)';
}


}

/// @nodoc
abstract mixin class $StudyPlanCopyWith<$Res>  {
  factory $StudyPlanCopyWith(StudyPlan value, $Res Function(StudyPlan) _then) = _$StudyPlanCopyWithImpl;
@useResult
$Res call({
 String id, String title, String description, String level, int durationDays, bool isPremium, String? category, String? coverImage
});




}
/// @nodoc
class _$StudyPlanCopyWithImpl<$Res>
    implements $StudyPlanCopyWith<$Res> {
  _$StudyPlanCopyWithImpl(this._self, this._then);

  final StudyPlan _self;
  final $Res Function(StudyPlan) _then;

/// Create a copy of StudyPlan
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? title = null,Object? description = null,Object? level = null,Object? durationDays = null,Object? isPremium = null,Object? category = freezed,Object? coverImage = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,level: null == level ? _self.level : level // ignore: cast_nullable_to_non_nullable
as String,durationDays: null == durationDays ? _self.durationDays : durationDays // ignore: cast_nullable_to_non_nullable
as int,isPremium: null == isPremium ? _self.isPremium : isPremium // ignore: cast_nullable_to_non_nullable
as bool,category: freezed == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String?,coverImage: freezed == coverImage ? _self.coverImage : coverImage // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [StudyPlan].
extension StudyPlanPatterns on StudyPlan {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _StudyPlan value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _StudyPlan() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _StudyPlan value)  $default,){
final _that = this;
switch (_that) {
case _StudyPlan():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _StudyPlan value)?  $default,){
final _that = this;
switch (_that) {
case _StudyPlan() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String title,  String description,  String level,  int durationDays,  bool isPremium,  String? category,  String? coverImage)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _StudyPlan() when $default != null:
return $default(_that.id,_that.title,_that.description,_that.level,_that.durationDays,_that.isPremium,_that.category,_that.coverImage);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String title,  String description,  String level,  int durationDays,  bool isPremium,  String? category,  String? coverImage)  $default,) {final _that = this;
switch (_that) {
case _StudyPlan():
return $default(_that.id,_that.title,_that.description,_that.level,_that.durationDays,_that.isPremium,_that.category,_that.coverImage);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String title,  String description,  String level,  int durationDays,  bool isPremium,  String? category,  String? coverImage)?  $default,) {final _that = this;
switch (_that) {
case _StudyPlan() when $default != null:
return $default(_that.id,_that.title,_that.description,_that.level,_that.durationDays,_that.isPremium,_that.category,_that.coverImage);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _StudyPlan implements StudyPlan {
  const _StudyPlan({required this.id, required this.title, required this.description, required this.level, required this.durationDays, this.isPremium = false, this.category, this.coverImage});
  factory _StudyPlan.fromJson(Map<String, dynamic> json) => _$StudyPlanFromJson(json);

@override final  String id;
@override final  String title;
@override final  String description;
@override final  String level;
// beginner, intermediate, advanced, premium
@override final  int durationDays;
@override@JsonKey() final  bool isPremium;
@override final  String? category;
@override final  String? coverImage;

/// Create a copy of StudyPlan
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$StudyPlanCopyWith<_StudyPlan> get copyWith => __$StudyPlanCopyWithImpl<_StudyPlan>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$StudyPlanToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _StudyPlan&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.description, description) || other.description == description)&&(identical(other.level, level) || other.level == level)&&(identical(other.durationDays, durationDays) || other.durationDays == durationDays)&&(identical(other.isPremium, isPremium) || other.isPremium == isPremium)&&(identical(other.category, category) || other.category == category)&&(identical(other.coverImage, coverImage) || other.coverImage == coverImage));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,title,description,level,durationDays,isPremium,category,coverImage);

@override
String toString() {
  return 'StudyPlan(id: $id, title: $title, description: $description, level: $level, durationDays: $durationDays, isPremium: $isPremium, category: $category, coverImage: $coverImage)';
}


}

/// @nodoc
abstract mixin class _$StudyPlanCopyWith<$Res> implements $StudyPlanCopyWith<$Res> {
  factory _$StudyPlanCopyWith(_StudyPlan value, $Res Function(_StudyPlan) _then) = __$StudyPlanCopyWithImpl;
@override @useResult
$Res call({
 String id, String title, String description, String level, int durationDays, bool isPremium, String? category, String? coverImage
});




}
/// @nodoc
class __$StudyPlanCopyWithImpl<$Res>
    implements _$StudyPlanCopyWith<$Res> {
  __$StudyPlanCopyWithImpl(this._self, this._then);

  final _StudyPlan _self;
  final $Res Function(_StudyPlan) _then;

/// Create a copy of StudyPlan
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? title = null,Object? description = null,Object? level = null,Object? durationDays = null,Object? isPremium = null,Object? category = freezed,Object? coverImage = freezed,}) {
  return _then(_StudyPlan(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,level: null == level ? _self.level : level // ignore: cast_nullable_to_non_nullable
as String,durationDays: null == durationDays ? _self.durationDays : durationDays // ignore: cast_nullable_to_non_nullable
as int,isPremium: null == isPremium ? _self.isPremium : isPremium // ignore: cast_nullable_to_non_nullable
as bool,category: freezed == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String?,coverImage: freezed == coverImage ? _self.coverImage : coverImage // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$StudyLesson {

 String get id; int get lessonIndex; String get title; List<BibleReference> get verses; String get devotional; List<String> get questions; List<StudyTopic> get topics; List<StudyQuestion> get quiz;
/// Create a copy of StudyLesson
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StudyLessonCopyWith<StudyLesson> get copyWith => _$StudyLessonCopyWithImpl<StudyLesson>(this as StudyLesson, _$identity);

  /// Serializes this StudyLesson to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StudyLesson&&(identical(other.id, id) || other.id == id)&&(identical(other.lessonIndex, lessonIndex) || other.lessonIndex == lessonIndex)&&(identical(other.title, title) || other.title == title)&&const DeepCollectionEquality().equals(other.verses, verses)&&(identical(other.devotional, devotional) || other.devotional == devotional)&&const DeepCollectionEquality().equals(other.questions, questions)&&const DeepCollectionEquality().equals(other.topics, topics)&&const DeepCollectionEquality().equals(other.quiz, quiz));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,lessonIndex,title,const DeepCollectionEquality().hash(verses),devotional,const DeepCollectionEquality().hash(questions),const DeepCollectionEquality().hash(topics),const DeepCollectionEquality().hash(quiz));

@override
String toString() {
  return 'StudyLesson(id: $id, lessonIndex: $lessonIndex, title: $title, verses: $verses, devotional: $devotional, questions: $questions, topics: $topics, quiz: $quiz)';
}


}

/// @nodoc
abstract mixin class $StudyLessonCopyWith<$Res>  {
  factory $StudyLessonCopyWith(StudyLesson value, $Res Function(StudyLesson) _then) = _$StudyLessonCopyWithImpl;
@useResult
$Res call({
 String id, int lessonIndex, String title, List<BibleReference> verses, String devotional, List<String> questions, List<StudyTopic> topics, List<StudyQuestion> quiz
});




}
/// @nodoc
class _$StudyLessonCopyWithImpl<$Res>
    implements $StudyLessonCopyWith<$Res> {
  _$StudyLessonCopyWithImpl(this._self, this._then);

  final StudyLesson _self;
  final $Res Function(StudyLesson) _then;

/// Create a copy of StudyLesson
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? lessonIndex = null,Object? title = null,Object? verses = null,Object? devotional = null,Object? questions = null,Object? topics = null,Object? quiz = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,lessonIndex: null == lessonIndex ? _self.lessonIndex : lessonIndex // ignore: cast_nullable_to_non_nullable
as int,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,verses: null == verses ? _self.verses : verses // ignore: cast_nullable_to_non_nullable
as List<BibleReference>,devotional: null == devotional ? _self.devotional : devotional // ignore: cast_nullable_to_non_nullable
as String,questions: null == questions ? _self.questions : questions // ignore: cast_nullable_to_non_nullable
as List<String>,topics: null == topics ? _self.topics : topics // ignore: cast_nullable_to_non_nullable
as List<StudyTopic>,quiz: null == quiz ? _self.quiz : quiz // ignore: cast_nullable_to_non_nullable
as List<StudyQuestion>,
  ));
}

}


/// Adds pattern-matching-related methods to [StudyLesson].
extension StudyLessonPatterns on StudyLesson {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _StudyLesson value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _StudyLesson() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _StudyLesson value)  $default,){
final _that = this;
switch (_that) {
case _StudyLesson():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _StudyLesson value)?  $default,){
final _that = this;
switch (_that) {
case _StudyLesson() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  int lessonIndex,  String title,  List<BibleReference> verses,  String devotional,  List<String> questions,  List<StudyTopic> topics,  List<StudyQuestion> quiz)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _StudyLesson() when $default != null:
return $default(_that.id,_that.lessonIndex,_that.title,_that.verses,_that.devotional,_that.questions,_that.topics,_that.quiz);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  int lessonIndex,  String title,  List<BibleReference> verses,  String devotional,  List<String> questions,  List<StudyTopic> topics,  List<StudyQuestion> quiz)  $default,) {final _that = this;
switch (_that) {
case _StudyLesson():
return $default(_that.id,_that.lessonIndex,_that.title,_that.verses,_that.devotional,_that.questions,_that.topics,_that.quiz);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  int lessonIndex,  String title,  List<BibleReference> verses,  String devotional,  List<String> questions,  List<StudyTopic> topics,  List<StudyQuestion> quiz)?  $default,) {final _that = this;
switch (_that) {
case _StudyLesson() when $default != null:
return $default(_that.id,_that.lessonIndex,_that.title,_that.verses,_that.devotional,_that.questions,_that.topics,_that.quiz);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _StudyLesson implements StudyLesson {
  const _StudyLesson({required this.id, required this.lessonIndex, required this.title, final  List<BibleReference> verses = const [], required this.devotional, final  List<String> questions = const [], final  List<StudyTopic> topics = const [], final  List<StudyQuestion> quiz = const []}): _verses = verses,_questions = questions,_topics = topics,_quiz = quiz;
  factory _StudyLesson.fromJson(Map<String, dynamic> json) => _$StudyLessonFromJson(json);

@override final  String id;
@override final  int lessonIndex;
@override final  String title;
 final  List<BibleReference> _verses;
@override@JsonKey() List<BibleReference> get verses {
  if (_verses is EqualUnmodifiableListView) return _verses;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_verses);
}

@override final  String devotional;
 final  List<String> _questions;
@override@JsonKey() List<String> get questions {
  if (_questions is EqualUnmodifiableListView) return _questions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_questions);
}

 final  List<StudyTopic> _topics;
@override@JsonKey() List<StudyTopic> get topics {
  if (_topics is EqualUnmodifiableListView) return _topics;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_topics);
}

 final  List<StudyQuestion> _quiz;
@override@JsonKey() List<StudyQuestion> get quiz {
  if (_quiz is EqualUnmodifiableListView) return _quiz;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_quiz);
}


/// Create a copy of StudyLesson
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$StudyLessonCopyWith<_StudyLesson> get copyWith => __$StudyLessonCopyWithImpl<_StudyLesson>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$StudyLessonToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _StudyLesson&&(identical(other.id, id) || other.id == id)&&(identical(other.lessonIndex, lessonIndex) || other.lessonIndex == lessonIndex)&&(identical(other.title, title) || other.title == title)&&const DeepCollectionEquality().equals(other._verses, _verses)&&(identical(other.devotional, devotional) || other.devotional == devotional)&&const DeepCollectionEquality().equals(other._questions, _questions)&&const DeepCollectionEquality().equals(other._topics, _topics)&&const DeepCollectionEquality().equals(other._quiz, _quiz));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,lessonIndex,title,const DeepCollectionEquality().hash(_verses),devotional,const DeepCollectionEquality().hash(_questions),const DeepCollectionEquality().hash(_topics),const DeepCollectionEquality().hash(_quiz));

@override
String toString() {
  return 'StudyLesson(id: $id, lessonIndex: $lessonIndex, title: $title, verses: $verses, devotional: $devotional, questions: $questions, topics: $topics, quiz: $quiz)';
}


}

/// @nodoc
abstract mixin class _$StudyLessonCopyWith<$Res> implements $StudyLessonCopyWith<$Res> {
  factory _$StudyLessonCopyWith(_StudyLesson value, $Res Function(_StudyLesson) _then) = __$StudyLessonCopyWithImpl;
@override @useResult
$Res call({
 String id, int lessonIndex, String title, List<BibleReference> verses, String devotional, List<String> questions, List<StudyTopic> topics, List<StudyQuestion> quiz
});




}
/// @nodoc
class __$StudyLessonCopyWithImpl<$Res>
    implements _$StudyLessonCopyWith<$Res> {
  __$StudyLessonCopyWithImpl(this._self, this._then);

  final _StudyLesson _self;
  final $Res Function(_StudyLesson) _then;

/// Create a copy of StudyLesson
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? lessonIndex = null,Object? title = null,Object? verses = null,Object? devotional = null,Object? questions = null,Object? topics = null,Object? quiz = null,}) {
  return _then(_StudyLesson(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,lessonIndex: null == lessonIndex ? _self.lessonIndex : lessonIndex // ignore: cast_nullable_to_non_nullable
as int,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,verses: null == verses ? _self._verses : verses // ignore: cast_nullable_to_non_nullable
as List<BibleReference>,devotional: null == devotional ? _self.devotional : devotional // ignore: cast_nullable_to_non_nullable
as String,questions: null == questions ? _self._questions : questions // ignore: cast_nullable_to_non_nullable
as List<String>,topics: null == topics ? _self._topics : topics // ignore: cast_nullable_to_non_nullable
as List<StudyTopic>,quiz: null == quiz ? _self._quiz : quiz // ignore: cast_nullable_to_non_nullable
as List<StudyQuestion>,
  ));
}


}


/// @nodoc
mixin _$StudyTopic {

 String get title; String get summary; List<String> get questions;
/// Create a copy of StudyTopic
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StudyTopicCopyWith<StudyTopic> get copyWith => _$StudyTopicCopyWithImpl<StudyTopic>(this as StudyTopic, _$identity);

  /// Serializes this StudyTopic to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StudyTopic&&(identical(other.title, title) || other.title == title)&&(identical(other.summary, summary) || other.summary == summary)&&const DeepCollectionEquality().equals(other.questions, questions));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,title,summary,const DeepCollectionEquality().hash(questions));

@override
String toString() {
  return 'StudyTopic(title: $title, summary: $summary, questions: $questions)';
}


}

/// @nodoc
abstract mixin class $StudyTopicCopyWith<$Res>  {
  factory $StudyTopicCopyWith(StudyTopic value, $Res Function(StudyTopic) _then) = _$StudyTopicCopyWithImpl;
@useResult
$Res call({
 String title, String summary, List<String> questions
});




}
/// @nodoc
class _$StudyTopicCopyWithImpl<$Res>
    implements $StudyTopicCopyWith<$Res> {
  _$StudyTopicCopyWithImpl(this._self, this._then);

  final StudyTopic _self;
  final $Res Function(StudyTopic) _then;

/// Create a copy of StudyTopic
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? title = null,Object? summary = null,Object? questions = null,}) {
  return _then(_self.copyWith(
title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,summary: null == summary ? _self.summary : summary // ignore: cast_nullable_to_non_nullable
as String,questions: null == questions ? _self.questions : questions // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}

}


/// Adds pattern-matching-related methods to [StudyTopic].
extension StudyTopicPatterns on StudyTopic {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _StudyTopic value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _StudyTopic() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _StudyTopic value)  $default,){
final _that = this;
switch (_that) {
case _StudyTopic():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _StudyTopic value)?  $default,){
final _that = this;
switch (_that) {
case _StudyTopic() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String title,  String summary,  List<String> questions)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _StudyTopic() when $default != null:
return $default(_that.title,_that.summary,_that.questions);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String title,  String summary,  List<String> questions)  $default,) {final _that = this;
switch (_that) {
case _StudyTopic():
return $default(_that.title,_that.summary,_that.questions);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String title,  String summary,  List<String> questions)?  $default,) {final _that = this;
switch (_that) {
case _StudyTopic() when $default != null:
return $default(_that.title,_that.summary,_that.questions);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _StudyTopic implements StudyTopic {
  const _StudyTopic({required this.title, required this.summary, final  List<String> questions = const []}): _questions = questions;
  factory _StudyTopic.fromJson(Map<String, dynamic> json) => _$StudyTopicFromJson(json);

@override final  String title;
@override final  String summary;
 final  List<String> _questions;
@override@JsonKey() List<String> get questions {
  if (_questions is EqualUnmodifiableListView) return _questions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_questions);
}


/// Create a copy of StudyTopic
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$StudyTopicCopyWith<_StudyTopic> get copyWith => __$StudyTopicCopyWithImpl<_StudyTopic>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$StudyTopicToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _StudyTopic&&(identical(other.title, title) || other.title == title)&&(identical(other.summary, summary) || other.summary == summary)&&const DeepCollectionEquality().equals(other._questions, _questions));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,title,summary,const DeepCollectionEquality().hash(_questions));

@override
String toString() {
  return 'StudyTopic(title: $title, summary: $summary, questions: $questions)';
}


}

/// @nodoc
abstract mixin class _$StudyTopicCopyWith<$Res> implements $StudyTopicCopyWith<$Res> {
  factory _$StudyTopicCopyWith(_StudyTopic value, $Res Function(_StudyTopic) _then) = __$StudyTopicCopyWithImpl;
@override @useResult
$Res call({
 String title, String summary, List<String> questions
});




}
/// @nodoc
class __$StudyTopicCopyWithImpl<$Res>
    implements _$StudyTopicCopyWith<$Res> {
  __$StudyTopicCopyWithImpl(this._self, this._then);

  final _StudyTopic _self;
  final $Res Function(_StudyTopic) _then;

/// Create a copy of StudyTopic
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? title = null,Object? summary = null,Object? questions = null,}) {
  return _then(_StudyTopic(
title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,summary: null == summary ? _self.summary : summary // ignore: cast_nullable_to_non_nullable
as String,questions: null == questions ? _self._questions : questions // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}


}


/// @nodoc
mixin _$StudyQuestion {

 String get text; bool get isTrue; String? get explanation;
/// Create a copy of StudyQuestion
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StudyQuestionCopyWith<StudyQuestion> get copyWith => _$StudyQuestionCopyWithImpl<StudyQuestion>(this as StudyQuestion, _$identity);

  /// Serializes this StudyQuestion to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StudyQuestion&&(identical(other.text, text) || other.text == text)&&(identical(other.isTrue, isTrue) || other.isTrue == isTrue)&&(identical(other.explanation, explanation) || other.explanation == explanation));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,text,isTrue,explanation);

@override
String toString() {
  return 'StudyQuestion(text: $text, isTrue: $isTrue, explanation: $explanation)';
}


}

/// @nodoc
abstract mixin class $StudyQuestionCopyWith<$Res>  {
  factory $StudyQuestionCopyWith(StudyQuestion value, $Res Function(StudyQuestion) _then) = _$StudyQuestionCopyWithImpl;
@useResult
$Res call({
 String text, bool isTrue, String? explanation
});




}
/// @nodoc
class _$StudyQuestionCopyWithImpl<$Res>
    implements $StudyQuestionCopyWith<$Res> {
  _$StudyQuestionCopyWithImpl(this._self, this._then);

  final StudyQuestion _self;
  final $Res Function(StudyQuestion) _then;

/// Create a copy of StudyQuestion
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? text = null,Object? isTrue = null,Object? explanation = freezed,}) {
  return _then(_self.copyWith(
text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,isTrue: null == isTrue ? _self.isTrue : isTrue // ignore: cast_nullable_to_non_nullable
as bool,explanation: freezed == explanation ? _self.explanation : explanation // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [StudyQuestion].
extension StudyQuestionPatterns on StudyQuestion {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _StudyQuestion value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _StudyQuestion() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _StudyQuestion value)  $default,){
final _that = this;
switch (_that) {
case _StudyQuestion():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _StudyQuestion value)?  $default,){
final _that = this;
switch (_that) {
case _StudyQuestion() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String text,  bool isTrue,  String? explanation)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _StudyQuestion() when $default != null:
return $default(_that.text,_that.isTrue,_that.explanation);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String text,  bool isTrue,  String? explanation)  $default,) {final _that = this;
switch (_that) {
case _StudyQuestion():
return $default(_that.text,_that.isTrue,_that.explanation);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String text,  bool isTrue,  String? explanation)?  $default,) {final _that = this;
switch (_that) {
case _StudyQuestion() when $default != null:
return $default(_that.text,_that.isTrue,_that.explanation);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _StudyQuestion implements StudyQuestion {
  const _StudyQuestion({required this.text, required this.isTrue, this.explanation});
  factory _StudyQuestion.fromJson(Map<String, dynamic> json) => _$StudyQuestionFromJson(json);

@override final  String text;
@override final  bool isTrue;
@override final  String? explanation;

/// Create a copy of StudyQuestion
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$StudyQuestionCopyWith<_StudyQuestion> get copyWith => __$StudyQuestionCopyWithImpl<_StudyQuestion>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$StudyQuestionToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _StudyQuestion&&(identical(other.text, text) || other.text == text)&&(identical(other.isTrue, isTrue) || other.isTrue == isTrue)&&(identical(other.explanation, explanation) || other.explanation == explanation));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,text,isTrue,explanation);

@override
String toString() {
  return 'StudyQuestion(text: $text, isTrue: $isTrue, explanation: $explanation)';
}


}

/// @nodoc
abstract mixin class _$StudyQuestionCopyWith<$Res> implements $StudyQuestionCopyWith<$Res> {
  factory _$StudyQuestionCopyWith(_StudyQuestion value, $Res Function(_StudyQuestion) _then) = __$StudyQuestionCopyWithImpl;
@override @useResult
$Res call({
 String text, bool isTrue, String? explanation
});




}
/// @nodoc
class __$StudyQuestionCopyWithImpl<$Res>
    implements _$StudyQuestionCopyWith<$Res> {
  __$StudyQuestionCopyWithImpl(this._self, this._then);

  final _StudyQuestion _self;
  final $Res Function(_StudyQuestion) _then;

/// Create a copy of StudyQuestion
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? text = null,Object? isTrue = null,Object? explanation = freezed,}) {
  return _then(_StudyQuestion(
text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,isTrue: null == isTrue ? _self.isTrue : isTrue // ignore: cast_nullable_to_non_nullable
as bool,explanation: freezed == explanation ? _self.explanation : explanation // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$BibleReference {

 String get book; int get chapter; int get verseStart; int? get verseEnd; String? get label;
/// Create a copy of BibleReference
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BibleReferenceCopyWith<BibleReference> get copyWith => _$BibleReferenceCopyWithImpl<BibleReference>(this as BibleReference, _$identity);

  /// Serializes this BibleReference to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BibleReference&&(identical(other.book, book) || other.book == book)&&(identical(other.chapter, chapter) || other.chapter == chapter)&&(identical(other.verseStart, verseStart) || other.verseStart == verseStart)&&(identical(other.verseEnd, verseEnd) || other.verseEnd == verseEnd)&&(identical(other.label, label) || other.label == label));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,book,chapter,verseStart,verseEnd,label);

@override
String toString() {
  return 'BibleReference(book: $book, chapter: $chapter, verseStart: $verseStart, verseEnd: $verseEnd, label: $label)';
}


}

/// @nodoc
abstract mixin class $BibleReferenceCopyWith<$Res>  {
  factory $BibleReferenceCopyWith(BibleReference value, $Res Function(BibleReference) _then) = _$BibleReferenceCopyWithImpl;
@useResult
$Res call({
 String book, int chapter, int verseStart, int? verseEnd, String? label
});




}
/// @nodoc
class _$BibleReferenceCopyWithImpl<$Res>
    implements $BibleReferenceCopyWith<$Res> {
  _$BibleReferenceCopyWithImpl(this._self, this._then);

  final BibleReference _self;
  final $Res Function(BibleReference) _then;

/// Create a copy of BibleReference
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? book = null,Object? chapter = null,Object? verseStart = null,Object? verseEnd = freezed,Object? label = freezed,}) {
  return _then(_self.copyWith(
book: null == book ? _self.book : book // ignore: cast_nullable_to_non_nullable
as String,chapter: null == chapter ? _self.chapter : chapter // ignore: cast_nullable_to_non_nullable
as int,verseStart: null == verseStart ? _self.verseStart : verseStart // ignore: cast_nullable_to_non_nullable
as int,verseEnd: freezed == verseEnd ? _self.verseEnd : verseEnd // ignore: cast_nullable_to_non_nullable
as int?,label: freezed == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [BibleReference].
extension BibleReferencePatterns on BibleReference {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _BibleReference value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BibleReference() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _BibleReference value)  $default,){
final _that = this;
switch (_that) {
case _BibleReference():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _BibleReference value)?  $default,){
final _that = this;
switch (_that) {
case _BibleReference() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String book,  int chapter,  int verseStart,  int? verseEnd,  String? label)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BibleReference() when $default != null:
return $default(_that.book,_that.chapter,_that.verseStart,_that.verseEnd,_that.label);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String book,  int chapter,  int verseStart,  int? verseEnd,  String? label)  $default,) {final _that = this;
switch (_that) {
case _BibleReference():
return $default(_that.book,_that.chapter,_that.verseStart,_that.verseEnd,_that.label);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String book,  int chapter,  int verseStart,  int? verseEnd,  String? label)?  $default,) {final _that = this;
switch (_that) {
case _BibleReference() when $default != null:
return $default(_that.book,_that.chapter,_that.verseStart,_that.verseEnd,_that.label);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _BibleReference implements BibleReference {
  const _BibleReference({required this.book, required this.chapter, required this.verseStart, this.verseEnd, this.label});
  factory _BibleReference.fromJson(Map<String, dynamic> json) => _$BibleReferenceFromJson(json);

@override final  String book;
@override final  int chapter;
@override final  int verseStart;
@override final  int? verseEnd;
@override final  String? label;

/// Create a copy of BibleReference
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BibleReferenceCopyWith<_BibleReference> get copyWith => __$BibleReferenceCopyWithImpl<_BibleReference>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$BibleReferenceToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _BibleReference&&(identical(other.book, book) || other.book == book)&&(identical(other.chapter, chapter) || other.chapter == chapter)&&(identical(other.verseStart, verseStart) || other.verseStart == verseStart)&&(identical(other.verseEnd, verseEnd) || other.verseEnd == verseEnd)&&(identical(other.label, label) || other.label == label));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,book,chapter,verseStart,verseEnd,label);

@override
String toString() {
  return 'BibleReference(book: $book, chapter: $chapter, verseStart: $verseStart, verseEnd: $verseEnd, label: $label)';
}


}

/// @nodoc
abstract mixin class _$BibleReferenceCopyWith<$Res> implements $BibleReferenceCopyWith<$Res> {
  factory _$BibleReferenceCopyWith(_BibleReference value, $Res Function(_BibleReference) _then) = __$BibleReferenceCopyWithImpl;
@override @useResult
$Res call({
 String book, int chapter, int verseStart, int? verseEnd, String? label
});




}
/// @nodoc
class __$BibleReferenceCopyWithImpl<$Res>
    implements _$BibleReferenceCopyWith<$Res> {
  __$BibleReferenceCopyWithImpl(this._self, this._then);

  final _BibleReference _self;
  final $Res Function(_BibleReference) _then;

/// Create a copy of BibleReference
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? book = null,Object? chapter = null,Object? verseStart = null,Object? verseEnd = freezed,Object? label = freezed,}) {
  return _then(_BibleReference(
book: null == book ? _self.book : book // ignore: cast_nullable_to_non_nullable
as String,chapter: null == chapter ? _self.chapter : chapter // ignore: cast_nullable_to_non_nullable
as int,verseStart: null == verseStart ? _self.verseStart : verseStart // ignore: cast_nullable_to_non_nullable
as int,verseEnd: freezed == verseEnd ? _self.verseEnd : verseEnd // ignore: cast_nullable_to_non_nullable
as int?,label: freezed == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$UserPlanProgress {

 String get planId; DateTime get startedAt; int get currentLessonIndex; List<int> get completedLessons; String get status;// active, completed
 double get progress; String? get planTitle;
/// Create a copy of UserPlanProgress
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UserPlanProgressCopyWith<UserPlanProgress> get copyWith => _$UserPlanProgressCopyWithImpl<UserPlanProgress>(this as UserPlanProgress, _$identity);

  /// Serializes this UserPlanProgress to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UserPlanProgress&&(identical(other.planId, planId) || other.planId == planId)&&(identical(other.startedAt, startedAt) || other.startedAt == startedAt)&&(identical(other.currentLessonIndex, currentLessonIndex) || other.currentLessonIndex == currentLessonIndex)&&const DeepCollectionEquality().equals(other.completedLessons, completedLessons)&&(identical(other.status, status) || other.status == status)&&(identical(other.progress, progress) || other.progress == progress)&&(identical(other.planTitle, planTitle) || other.planTitle == planTitle));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,planId,startedAt,currentLessonIndex,const DeepCollectionEquality().hash(completedLessons),status,progress,planTitle);

@override
String toString() {
  return 'UserPlanProgress(planId: $planId, startedAt: $startedAt, currentLessonIndex: $currentLessonIndex, completedLessons: $completedLessons, status: $status, progress: $progress, planTitle: $planTitle)';
}


}

/// @nodoc
abstract mixin class $UserPlanProgressCopyWith<$Res>  {
  factory $UserPlanProgressCopyWith(UserPlanProgress value, $Res Function(UserPlanProgress) _then) = _$UserPlanProgressCopyWithImpl;
@useResult
$Res call({
 String planId, DateTime startedAt, int currentLessonIndex, List<int> completedLessons, String status, double progress, String? planTitle
});




}
/// @nodoc
class _$UserPlanProgressCopyWithImpl<$Res>
    implements $UserPlanProgressCopyWith<$Res> {
  _$UserPlanProgressCopyWithImpl(this._self, this._then);

  final UserPlanProgress _self;
  final $Res Function(UserPlanProgress) _then;

/// Create a copy of UserPlanProgress
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? planId = null,Object? startedAt = null,Object? currentLessonIndex = null,Object? completedLessons = null,Object? status = null,Object? progress = null,Object? planTitle = freezed,}) {
  return _then(_self.copyWith(
planId: null == planId ? _self.planId : planId // ignore: cast_nullable_to_non_nullable
as String,startedAt: null == startedAt ? _self.startedAt : startedAt // ignore: cast_nullable_to_non_nullable
as DateTime,currentLessonIndex: null == currentLessonIndex ? _self.currentLessonIndex : currentLessonIndex // ignore: cast_nullable_to_non_nullable
as int,completedLessons: null == completedLessons ? _self.completedLessons : completedLessons // ignore: cast_nullable_to_non_nullable
as List<int>,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,progress: null == progress ? _self.progress : progress // ignore: cast_nullable_to_non_nullable
as double,planTitle: freezed == planTitle ? _self.planTitle : planTitle // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [UserPlanProgress].
extension UserPlanProgressPatterns on UserPlanProgress {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UserPlanProgress value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UserPlanProgress() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UserPlanProgress value)  $default,){
final _that = this;
switch (_that) {
case _UserPlanProgress():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UserPlanProgress value)?  $default,){
final _that = this;
switch (_that) {
case _UserPlanProgress() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String planId,  DateTime startedAt,  int currentLessonIndex,  List<int> completedLessons,  String status,  double progress,  String? planTitle)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UserPlanProgress() when $default != null:
return $default(_that.planId,_that.startedAt,_that.currentLessonIndex,_that.completedLessons,_that.status,_that.progress,_that.planTitle);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String planId,  DateTime startedAt,  int currentLessonIndex,  List<int> completedLessons,  String status,  double progress,  String? planTitle)  $default,) {final _that = this;
switch (_that) {
case _UserPlanProgress():
return $default(_that.planId,_that.startedAt,_that.currentLessonIndex,_that.completedLessons,_that.status,_that.progress,_that.planTitle);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String planId,  DateTime startedAt,  int currentLessonIndex,  List<int> completedLessons,  String status,  double progress,  String? planTitle)?  $default,) {final _that = this;
switch (_that) {
case _UserPlanProgress() when $default != null:
return $default(_that.planId,_that.startedAt,_that.currentLessonIndex,_that.completedLessons,_that.status,_that.progress,_that.planTitle);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _UserPlanProgress implements UserPlanProgress {
  const _UserPlanProgress({required this.planId, required this.startedAt, this.currentLessonIndex = 1, final  List<int> completedLessons = const [], this.status = 'active', this.progress = 0.0, this.planTitle}): _completedLessons = completedLessons;
  factory _UserPlanProgress.fromJson(Map<String, dynamic> json) => _$UserPlanProgressFromJson(json);

@override final  String planId;
@override final  DateTime startedAt;
@override@JsonKey() final  int currentLessonIndex;
 final  List<int> _completedLessons;
@override@JsonKey() List<int> get completedLessons {
  if (_completedLessons is EqualUnmodifiableListView) return _completedLessons;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_completedLessons);
}

@override@JsonKey() final  String status;
// active, completed
@override@JsonKey() final  double progress;
@override final  String? planTitle;

/// Create a copy of UserPlanProgress
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UserPlanProgressCopyWith<_UserPlanProgress> get copyWith => __$UserPlanProgressCopyWithImpl<_UserPlanProgress>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$UserPlanProgressToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _UserPlanProgress&&(identical(other.planId, planId) || other.planId == planId)&&(identical(other.startedAt, startedAt) || other.startedAt == startedAt)&&(identical(other.currentLessonIndex, currentLessonIndex) || other.currentLessonIndex == currentLessonIndex)&&const DeepCollectionEquality().equals(other._completedLessons, _completedLessons)&&(identical(other.status, status) || other.status == status)&&(identical(other.progress, progress) || other.progress == progress)&&(identical(other.planTitle, planTitle) || other.planTitle == planTitle));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,planId,startedAt,currentLessonIndex,const DeepCollectionEquality().hash(_completedLessons),status,progress,planTitle);

@override
String toString() {
  return 'UserPlanProgress(planId: $planId, startedAt: $startedAt, currentLessonIndex: $currentLessonIndex, completedLessons: $completedLessons, status: $status, progress: $progress, planTitle: $planTitle)';
}


}

/// @nodoc
abstract mixin class _$UserPlanProgressCopyWith<$Res> implements $UserPlanProgressCopyWith<$Res> {
  factory _$UserPlanProgressCopyWith(_UserPlanProgress value, $Res Function(_UserPlanProgress) _then) = __$UserPlanProgressCopyWithImpl;
@override @useResult
$Res call({
 String planId, DateTime startedAt, int currentLessonIndex, List<int> completedLessons, String status, double progress, String? planTitle
});




}
/// @nodoc
class __$UserPlanProgressCopyWithImpl<$Res>
    implements _$UserPlanProgressCopyWith<$Res> {
  __$UserPlanProgressCopyWithImpl(this._self, this._then);

  final _UserPlanProgress _self;
  final $Res Function(_UserPlanProgress) _then;

/// Create a copy of UserPlanProgress
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? planId = null,Object? startedAt = null,Object? currentLessonIndex = null,Object? completedLessons = null,Object? status = null,Object? progress = null,Object? planTitle = freezed,}) {
  return _then(_UserPlanProgress(
planId: null == planId ? _self.planId : planId // ignore: cast_nullable_to_non_nullable
as String,startedAt: null == startedAt ? _self.startedAt : startedAt // ignore: cast_nullable_to_non_nullable
as DateTime,currentLessonIndex: null == currentLessonIndex ? _self.currentLessonIndex : currentLessonIndex // ignore: cast_nullable_to_non_nullable
as int,completedLessons: null == completedLessons ? _self._completedLessons : completedLessons // ignore: cast_nullable_to_non_nullable
as List<int>,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,progress: null == progress ? _self.progress : progress // ignore: cast_nullable_to_non_nullable
as double,planTitle: freezed == planTitle ? _self.planTitle : planTitle // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
