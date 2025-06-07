// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'locale_switch_widget.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

@ProviderFor(LangsForSwitcher)
const langsForSwitcherProvider = LangsForSwitcherProvider._();

final class LangsForSwitcherProvider
    extends $NotifierProvider<LangsForSwitcher, List<String>> {
  const LangsForSwitcherProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'langsForSwitcherProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$langsForSwitcherHash();

  @$internal
  @override
  LangsForSwitcher create() => LangsForSwitcher();

  @$internal
  @override
  $NotifierProviderElement<LangsForSwitcher, List<String>> $createElement(
    $ProviderPointer pointer,
  ) => $NotifierProviderElement(pointer);

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<String> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $ValueProvider<List<String>>(value),
    );
  }
}

String _$langsForSwitcherHash() => r'1b5aed12761d18983ffc9c138ffcf2050624dba6';

abstract class _$LangsForSwitcher extends $Notifier<List<String>> {
  List<String> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<List<String>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<List<String>>,
              List<String>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
