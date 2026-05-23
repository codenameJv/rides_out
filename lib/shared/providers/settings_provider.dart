import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/hive_service.dart';

const _kAvoidTollsExpressways = 'avoid_tolls_expressways';
const _kUseMiles = 'use_miles';
const _kSessionGapMinutes = 'session_gap_minutes';
const _kShowSuggestedRoute = 'show_suggested_route';

class SettingsNotifier extends StateNotifier<SettingsState> {
  SettingsNotifier() : super(SettingsState._fromBox());

  void setAvoidTollsExpressways(bool value) {
    HiveService.settingsBox.put(_kAvoidTollsExpressways, value);
    state = state.copyWith(avoidTollsExpressways: value);
  }

  void setUseMiles(bool value) {
    HiveService.settingsBox.put(_kUseMiles, value);
    state = state.copyWith(useMiles: value);
  }

  void setSessionGapMinutes(int value) {
    HiveService.settingsBox.put(_kSessionGapMinutes, value);
    state = state.copyWith(sessionGapMinutes: value);
  }

  void setShowSuggestedRoute(bool value) {
    HiveService.settingsBox.put(_kShowSuggestedRoute, value);
    state = state.copyWith(showSuggestedRoute: value);
  }
}

class SettingsState {
  final bool avoidTollsExpressways;
  final bool useMiles;
  final bool showSuggestedRoute;
  final int sessionGapMinutes;

  const SettingsState({
    this.avoidTollsExpressways = false,
    this.useMiles = false,
    this.showSuggestedRoute = true,
    this.sessionGapMinutes = 30,
  });

  factory SettingsState._fromBox() {
    final box = HiveService.settingsBox;
    return SettingsState(
      avoidTollsExpressways:
          box.get(_kAvoidTollsExpressways, defaultValue: false) as bool,
      useMiles: box.get(_kUseMiles, defaultValue: false) as bool,
      showSuggestedRoute:
          box.get(_kShowSuggestedRoute, defaultValue: true) as bool,
      sessionGapMinutes:
          box.get(_kSessionGapMinutes, defaultValue: 30) as int,
    );
  }

  SettingsState copyWith({
    bool? avoidTollsExpressways,
    bool? useMiles,
    bool? showSuggestedRoute,
    int? sessionGapMinutes,
  }) {
    return SettingsState(
      avoidTollsExpressways:
          avoidTollsExpressways ?? this.avoidTollsExpressways,
      useMiles: useMiles ?? this.useMiles,
      showSuggestedRoute: showSuggestedRoute ?? this.showSuggestedRoute,
      sessionGapMinutes: sessionGapMinutes ?? this.sessionGapMinutes,
    );
  }
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  return SettingsNotifier();
});
