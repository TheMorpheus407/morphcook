/// A small JSON Schema validator covering the subset the pipeline schemas use:
/// `type`, `properties`, `required`, `additionalProperties`, `items`,
/// `minItems`, `maxItems`, `uniqueItems`, `enum`, `minimum`, `maximum`,
/// `minLength`, `pattern` and local `$ref` into `$defs`.
class MiniJsonSchema {
  const MiniJsonSchema(this.root);

  final Map<String, dynamic> root;

  /// Returns one message per violation, each prefixed with the JSON path.
  List<String> validate(Object? data) {
    final errors = <String>[];
    _check(root, data, r'$', errors);
    return errors;
  }

  Map<String, dynamic> _resolve(Map<String, dynamic> schema) {
    final ref = schema[r'$ref'];
    if (ref is! String) return schema;
    if (!ref.startsWith('#/')) throw ArgumentError('Only local refs are supported: $ref');
    Object? node = root;
    for (final part in ref.substring(2).split('/')) {
      node = (node as Map)[part];
    }
    return (node as Map).cast<String, dynamic>();
  }

  bool _isType(Object? data, String type) {
    switch (type) {
      case 'object':
        return data is Map;
      case 'array':
        return data is List;
      case 'string':
        return data is String;
      case 'integer':
        return data is int || (data is double && data == data.roundToDouble());
      case 'number':
        return data is num;
      case 'boolean':
        return data is bool;
      case 'null':
        return data == null;
    }
    return false;
  }

  void _check(Map<String, dynamic> rawSchema, Object? data, String path, List<String> errors) {
    final schema = _resolve(rawSchema);

    final type = schema['type'];
    if (type != null) {
      final types = type is List ? type.cast<String>() : <String>[type as String];
      if (!types.any((t) => _isType(data, t))) {
        errors.add('$path: expected ${types.join(' or ')}, found ${data.runtimeType}');
        return;
      }
    }
    final enumValues = schema['enum'];
    if (enumValues is List && !enumValues.contains(data)) {
      errors.add('$path: "$data" is not one of ${enumValues.join(', ')}');
    }

    if (data is String) {
      final minLength = schema['minLength'];
      if (minLength is int && data.length < minLength) errors.add('$path: shorter than $minLength characters');
      final pattern = schema['pattern'];
      if (pattern is String && !RegExp(pattern).hasMatch(data)) errors.add('$path: "$data" does not match $pattern');
    }
    if (data is num) {
      final minimum = schema['minimum'];
      if (minimum is num && data < minimum) errors.add('$path: $data is below $minimum');
      final maximum = schema['maximum'];
      if (maximum is num && data > maximum) errors.add('$path: $data is above $maximum');
    }
    if (data is List) {
      final minItems = schema['minItems'];
      if (minItems is int && data.length < minItems) errors.add('$path: needs at least $minItems items');
      final maxItems = schema['maxItems'];
      if (maxItems is int && data.length > maxItems) errors.add('$path: allows at most $maxItems items');
      if (schema['uniqueItems'] == true && data.toSet().length != data.length) {
        errors.add('$path: items are not unique');
      }
      final items = schema['items'];
      if (items is Map) {
        for (var i = 0; i < data.length; i++) {
          _check(items.cast<String, dynamic>(), data[i], '$path[$i]', errors);
        }
      }
    }
    if (data is Map) {
      final required = schema['required'];
      if (required is List) {
        for (final key in required) {
          if (!data.containsKey(key)) errors.add('$path: missing required "$key"');
        }
      }
      final properties = (schema['properties'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
      for (final entry in data.entries) {
        final key = entry.key.toString();
        final sub = properties[key];
        if (sub is Map) {
          _check(sub.cast<String, dynamic>(), entry.value, '$path.$key', errors);
        } else if (schema['additionalProperties'] == false) {
          errors.add('$path: unexpected property "$key"');
        } else if (schema['additionalProperties'] is Map) {
          _check((schema['additionalProperties'] as Map).cast<String, dynamic>(), entry.value, '$path.$key', errors);
        }
      }
    }
  }
}
