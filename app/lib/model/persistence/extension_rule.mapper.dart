// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'extension_rule.dart';

class ExtensionRuleMapper extends ClassMapperBase<ExtensionRule> {
  ExtensionRuleMapper._();

  static ExtensionRuleMapper? _instance;
  static ExtensionRuleMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = ExtensionRuleMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'ExtensionRule';

  static String _$id(ExtensionRule v) => v.id;
  static const Field<ExtensionRule, String> _f$id = Field('id', _$id);
  static List<String> _$extensions(ExtensionRule v) => v.extensions;
  static const Field<ExtensionRule, List<String>> _f$extensions = Field(
    'extensions',
    _$extensions,
  );
  static String _$folderUri(ExtensionRule v) => v.folderUri;
  static const Field<ExtensionRule, String> _f$folderUri = Field(
    'folderUri',
    _$folderUri,
  );
  static String _$folderName(ExtensionRule v) => v.folderName;
  static const Field<ExtensionRule, String> _f$folderName = Field(
    'folderName',
    _$folderName,
  );
  static bool _$invalid(ExtensionRule v) => v.invalid;
  static const Field<ExtensionRule, bool> _f$invalid = Field(
    'invalid',
    _$invalid,
    opt: true,
    def: false,
  );

  @override
  final MappableFields<ExtensionRule> fields = const {
    #id: _f$id,
    #extensions: _f$extensions,
    #folderUri: _f$folderUri,
    #folderName: _f$folderName,
    #invalid: _f$invalid,
  };

  static ExtensionRule _instantiate(DecodingData data) {
    return ExtensionRule(
      id: data.dec(_f$id),
      extensions: data.dec(_f$extensions),
      folderUri: data.dec(_f$folderUri),
      folderName: data.dec(_f$folderName),
      invalid: data.dec(_f$invalid),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static ExtensionRule fromJson(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<ExtensionRule>(map);
  }

  static ExtensionRule deserialize(String json) {
    return ensureInitialized().decodeJson<ExtensionRule>(json);
  }
}

mixin ExtensionRuleMappable {
  String serialize() {
    return ExtensionRuleMapper.ensureInitialized().encodeJson<ExtensionRule>(
      this as ExtensionRule,
    );
  }

  Map<String, dynamic> toJson() {
    return ExtensionRuleMapper.ensureInitialized().encodeMap<ExtensionRule>(
      this as ExtensionRule,
    );
  }

  ExtensionRuleCopyWith<ExtensionRule, ExtensionRule, ExtensionRule>
  get copyWith => _ExtensionRuleCopyWithImpl<ExtensionRule, ExtensionRule>(
    this as ExtensionRule,
    $identity,
    $identity,
  );
  @override
  String toString() {
    return ExtensionRuleMapper.ensureInitialized().stringifyValue(
      this as ExtensionRule,
    );
  }

  @override
  bool operator ==(Object other) {
    return ExtensionRuleMapper.ensureInitialized().equalsValue(
      this as ExtensionRule,
      other,
    );
  }

  @override
  int get hashCode {
    return ExtensionRuleMapper.ensureInitialized().hashValue(
      this as ExtensionRule,
    );
  }
}

extension ExtensionRuleValueCopy<$R, $Out>
    on ObjectCopyWith<$R, ExtensionRule, $Out> {
  ExtensionRuleCopyWith<$R, ExtensionRule, $Out> get $asExtensionRule =>
      $base.as((v, t, t2) => _ExtensionRuleCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class ExtensionRuleCopyWith<$R, $In extends ExtensionRule, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  ListCopyWith<$R, String, ObjectCopyWith<$R, String, String>> get extensions;
  $R call({
    String? id,
    List<String>? extensions,
    String? folderUri,
    String? folderName,
    bool? invalid,
  });
  ExtensionRuleCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _ExtensionRuleCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, ExtensionRule, $Out>
    implements ExtensionRuleCopyWith<$R, ExtensionRule, $Out> {
  _ExtensionRuleCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<ExtensionRule> $mapper =
      ExtensionRuleMapper.ensureInitialized();
  @override
  ListCopyWith<$R, String, ObjectCopyWith<$R, String, String>> get extensions =>
      ListCopyWith(
        $value.extensions,
        (v, t) => ObjectCopyWith(v, $identity, t),
        (v) => call(extensions: v),
      );
  @override
  $R call({
    String? id,
    List<String>? extensions,
    String? folderUri,
    String? folderName,
    bool? invalid,
  }) => $apply(
    FieldCopyWithData({
      if (id != null) #id: id,
      if (extensions != null) #extensions: extensions,
      if (folderUri != null) #folderUri: folderUri,
      if (folderName != null) #folderName: folderName,
      if (invalid != null) #invalid: invalid,
    }),
  );
  @override
  ExtensionRule $make(CopyWithData data) => ExtensionRule(
    id: data.get(#id, or: $value.id),
    extensions: data.get(#extensions, or: $value.extensions),
    folderUri: data.get(#folderUri, or: $value.folderUri),
    folderName: data.get(#folderName, or: $value.folderName),
    invalid: data.get(#invalid, or: $value.invalid),
  );

  @override
  ExtensionRuleCopyWith<$R2, ExtensionRule, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _ExtensionRuleCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

