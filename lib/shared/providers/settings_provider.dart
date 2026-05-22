import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/hive_service.dart';

const _kAvoidTollsExpressways = 'avoid_tolls_expressways';

class SettingsNotifier extends StateNotifier<SettingsState> {
  SettingsNotifier() : super(SettingsState._fromBox());

  void setAvoidTollsExpressways(bool value) {
    HiveService.settingsBox.put(_kAvoidTollsExpressways, value);
    state = state.copyWith(avoidTollsExpressways: value);
  }
}

class SettingsState {
  final bool avoidTollsExpressways;

  const SettingsState({this.avoidTollsExpressways = false});

  factory SettingsState._fromBox() {
    final box = HiveService.settingsBox;
    return SettingsState(
      avoidTollsExpressways:
          box.get(_kAvoidTollsExpressways, defaultValue: false) as bool,
    );
  }

  SettingsState copyWith({bool? avoidTollsExpressways}) {
    return SettingsState(
      avoidTollsExpressways:
          avoidTollsExpressways ?? this.avoidTollsExpressways,
    );
  }
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  return SettingsNotifier();
});
