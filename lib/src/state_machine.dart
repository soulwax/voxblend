import 'dart:math' as math;

import 'math.dart';
import 'motion_clip.dart';

/// State node inside [StateBlendMachine].
final class BlendStateDef {
  final String name;
  final MotionClip clip;
  final double playbackSpeed;

  const BlendStateDef({
    required this.name,
    required this.clip,
    this.playbackSpeed = 1.0,
  });
}

/// Declarative transition edge between states with optional float guard & normalized exit time.
final class BlendTransitionRule {
  final String fromState;
  final String toState;
  final double crossfadeDuration;
  final double? exitTimeNormalized;
  final bool Function(Map<String, double> params, Set<String> triggers)? condition;

  const BlendTransitionRule({
    required this.fromState,
    required this.toState,
    this.crossfadeDuration = 0.25,
    this.exitTimeNormalized,
    this.condition,
  });
}

/// Active state crossfade & sprite/root-motion snapshot returned by [StateBlendMachine.step].
final class StateBlendSnapshot {
  final String activeState;
  final String? transitionFromState;
  final double transitionAlpha;
  final int activeFrameIndex;
  final BlendVec3 rootMotionDelta;

  const StateBlendSnapshot({
    required this.activeState,
    this.transitionFromState,
    required this.transitionAlpha,
    required this.activeFrameIndex,
    required this.rootMotionDelta,
  });
}

/// Deterministic animation state machine with crossfade blending, triggers & exit-time scheduling.
final class StateBlendMachine {
  final Map<String, BlendStateDef> _states = {};
  final List<BlendTransitionRule> _rules = [];
  final Map<String, double> _params = {};
  final Set<String> _triggers = {};

  String _currentState;
  double _stateTime = 0.0;

  String? _prevState;
  double _prevStateTime = 0.0;
  double _blendElapsed = 0.0;
  double _blendDuration = 0.0;

  StateBlendMachine({
    required List<BlendStateDef> states,
    required String initialState,
    List<BlendTransitionRule> rules = const [],
  }) : _currentState = initialState {
    for (final s in states) {
      _states[s.name] = s;
    }
    _rules.addAll(rules);
  }

  String get currentStateName => _currentState;
  String? get previousStateName => _prevState;
  bool get isInTransition => _prevState != null && _blendDuration > 0.0;

  void setFloat(String name, double value) => _params[name] = value;
  double getFloat(String name) => _params[name] ?? 0.0;
  void setTrigger(String name) => _triggers.add(name);

  void addRule(BlendTransitionRule rule) => _rules.add(rule);

  void forceTransition(String toState, {double crossfadeDuration = 0.2}) {
    if (!_states.containsKey(toState) || toState == _currentState) return;
    _prevState = _currentState;
    _prevStateTime = _stateTime;
    _currentState = toState;
    _stateTime = 0.0;
    _blendElapsed = 0.0;
    _blendDuration = math.max(0.0, crossfadeDuration);
    if (_blendDuration <= 1e-6) {
      _prevState = null;
    }
  }

  StateBlendSnapshot step(double dt) {
    final curDef = _states[_currentState];
    if (curDef == null) {
      return StateBlendSnapshot(
        activeState: _currentState,
        transitionAlpha: 1.0,
        activeFrameIndex: 0,
        rootMotionDelta: BlendVec3.zero,
      );
    }

    if (dt > 0.0) {
      _stateTime += dt * curDef.playbackSpeed;
      if (_prevState != null) {
        final prevDef = _states[_prevState];
        _prevStateTime += dt * (prevDef?.playbackSpeed ?? 1.0);
        _blendElapsed += dt;
        if (_blendElapsed >= _blendDuration) {
          _prevState = null;
          _blendElapsed = 0.0;
          _blendDuration = 0.0;
        }
      }
    }

    // Evaluate eligible rules when not already locked in a crossfade.
    if (!isInTransition) {
      final normCur = _stateTime / math.max(1e-4, curDef.clip.durationSeconds);
      for (final rule in _rules) {
        if (rule.fromState != _currentState && rule.fromState != '*') continue;
        if (rule.toState == _currentState) continue;
        final exitOk =
            rule.exitTimeNormalized == null || normCur >= rule.exitTimeNormalized!;
        if (!exitOk) continue;
        final condOk = rule.condition == null || rule.condition!(_params, _triggers);
        if (condOk) {
          forceTransition(rule.toState, crossfadeDuration: rule.crossfadeDuration);
          _triggers.clear();
          break;
        }
      }
    }

    final activeDef = _states[_currentState]!;
    final activeSample = MotionClipSampler.sample(
      activeDef.clip,
      timeSeconds: _stateTime,
      deltaTime: dt * activeDef.playbackSpeed,
    );

    var alpha = 1.0;
    var rootDelta = activeSample.rootDelta;
    if (_prevState != null && _blendDuration > 1e-6) {
      final prevDef = _states[_prevState];
      alpha = (_blendElapsed / _blendDuration).clamp(0.0, 1.0).toDouble();
      if (prevDef != null) {
        final prevSample = MotionClipSampler.sample(
          prevDef.clip,
          timeSeconds: _prevStateTime,
          deltaTime: dt * prevDef.playbackSpeed,
        );
        rootDelta = BlendVec3.lerp(prevSample.rootDelta, activeSample.rootDelta, alpha);
      }
    }

    return StateBlendSnapshot(
      activeState: _currentState,
      transitionFromState: _prevState,
      transitionAlpha: alpha,
      activeFrameIndex: activeSample.frameIndex,
      rootMotionDelta: rootDelta,
    );
  }
}
