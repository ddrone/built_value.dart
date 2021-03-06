// Copyright (c) 2015, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import 'dart:async';

import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:built_value_generator/built_value_generator.dart';
import 'package:source_gen/source_gen.dart';
import 'package:test/test.dart';

void main() {
  group('generator', () {
    test('ignores empty library', () async {
      expect(await generate('library value;'), isEmpty);
    });

    test('ignores normal class', () async {
      expect(await generate(r'''
library value;

class EmptyClass {}
'''), isEmpty);
    });

    test('ignores built_value class without serializer', () async {
      expect(await generate(r'''
library value;

import 'package:test_support/test_support.dart';

abstract class Value implements Built<Value, ValueBuilder> {}
'''), isNot(contains('implements StructuredSerializer<Value>')));
    });

    test('generates for built_value class with serializer', () async {
      expect(await generate(r'''
library value;

import 'package:test_support/test_support.dart';

abstract class Value implements Built<Value, ValueBuilder> {
  static Serializer<Value> get serializer => _$valueSerializer;
}
'''), contains('implements StructuredSerializer<Value>'));
    });

    test('ignores EnumClass without serializer', () async {
      expect(await generate(r'''
library value;

import 'package:test_support/test_support.dart';

class Enum extends EnumClass {}
'''), isNot(contains('Serializer<Enum>')));
    });

    test('generates for EnumClass with serializer', () async {
      expect(await generate(r'''
library value;

import 'package:test_support/test_support.dart';

class Enum extends EnumClass {
  static Serializer<Enum> get serializer => _$serializer;
}
'''), isNotEmpty);
    });

    test('does not generate for serializers without annotation', () async {
      expect(await generate(r'''
library value;

import 'package:test_support/test_support.dart';

final Serializers serializers = _$serializers;
'''), isEmpty);
    });

    test('generates for serializers with annotation', () async {
      expect(await generate(r'''
library value;

import 'package:test_support/test_support.dart';

part 'value.g.dart';

@SerializersFor(const [Value])
final Serializers serializers = _$serializers;

abstract class Value implements Built<Value, ValueBuilder> {
  static Serializer<Value> get serializer => _$valueSerializer;
  bool get aBool;
  
  Value._();
  factory Value([updates(ValueBuilder b)]) = _$Value;
}
'''), contains(r'_$serializers'));
    });

    test('does not crash for incorrect builder getter', () async {
      expect(await generate(r'''
library value;

import 'package:test_support/test_support.dart';

abstract class Value implements Built<Value, ValueBuilder> {
  static Serializer<Value> get serializer => _$valueSerializer;
  bool get aBool;
}

abstract class ValueBuilder implements Builder<Value, ValueBuilder> {
  set aBool(bool aBool);
}
'''), contains('implements StructuredSerializer<Value>'));
    });

    test('checks serializer declarations use correct values', () async {
      expect(
          await generate(r'''
library value;

import 'package:test_support/test_support.dart';

abstract class Value implements Built<Value, ValueBuilder> {
  static Serializer<Value> get serializer => _$valueSerializer;
  bool get aBool;
}

abstract class OtherValue implements Built<Value, ValueBuilder> {
  static Serializer<Value> get serializer => _$serializer;
  bool get aBool;
}
'''),
          contains(r'1. Declare OtherValue.serializer as: '
              'static Serializer<OtherValue> get serializer => '
              '_\$otherValueSerializer;'));
    });
  });
}

// Test setup.

final String pkgName = 'pkg';

final Builder builder = new PartBuilder([new BuiltValueGenerator()]);

Future<String> generate(String source) async {
  final srcs = <String, String>{
    'test_support|lib/test_support.dart': testSupportSource,
    '$pkgName|lib/value.dart': source,
  };

  final writer = new InMemoryAssetWriter();
  await testBuilder(builder, srcs, rootPackage: pkgName, writer: writer);
  return writer.assets[new AssetId(pkgName, 'lib/value.g.dart')]?.stringValue ??
      '';
}

// Classes mentioned in the test input need to exist, but we don't need the
// real versions. So just use minimal ones.
const String testSupportSource = r'''
const String nullable = 'nullable';

class Built<V, B> {}

class BuiltList<E> {}

class BuiltMap<K, V> {}

class EnumClass {}

class SerializersFor {
  final List<Type> types;

  const SerializersFor(this.types);
}

class Serializer<T> {}

class Serializers {}
''';
