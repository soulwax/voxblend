import 'package:test/test.dart';
import 'package:voxblend/voxblend.dart';

void main() {
  test('BlendSpace1D and BlendSpace2D evaluate normalized blend weights and root velocity', () {
    const idle = MotionClip(name: 'idle', rootVelocity: BlendVec3(0.0, 0.0, 0.0));
    const walk = MotionClip(name: 'walk', rootVelocity: BlendVec3(0.0, 0.0, 2.0));
    const run = MotionClip(name: 'run', rootVelocity: BlendVec3(0.0, 0.0, 6.0));

    final bs1d = BlendSpace1D([
      const BlendSample1D(clip: idle, position: 0.0),
      const BlendSample1D(clip: walk, position: 2.0),
      const BlendSample1D(clip: run, position: 6.0),
    ]);

    final midWalkRun = bs1d.evaluate(4.0);
    expect(midWalkRun.weightsByClip['walk'], closeTo(0.5, 1e-6));
    expect(midWalkRun.weightsByClip['run'], closeTo(0.5, 1e-6));
    expect(midWalkRun.blendedRootVelocity.z, closeTo(4.0, 1e-6));

    const bs2d = BlendSpace2D([
      BlendSample2D(clip: walk, x: 0.0, y: 1.0),
      BlendSample2D(
        clip: MotionClip(name: 'strafe_r', rootVelocity: BlendVec3(3.0, 0.0, 0.0)),
        x: 1.0,
        y: 0.0,
      ),
    ]);
    final diag = bs2d.evaluate(0.5, 0.5);
    expect(diag.weightsByClip.values.reduce((a, b) => a + b), closeTo(1.0, 1e-6));
    expect(diag.blendedRootVelocity.x, closeTo(1.5, 1e-4));
  });

  test('MotionClipSampler tracks discrete frame indices and wrap-safe root deltas', () {
    const clip = MotionClip(
      name: 'sprint',
      durationSeconds: 0.8,
      frameCount: 8,
      loop: true,
      rootVelocity: BlendVec3(0.0, 0.0, 5.0),
    );

    final s = MotionClipSampler.sample(clip, timeSeconds: 1.0, deltaTime: 0.05);
    expect(s.normalizedTime, closeTo(0.25, 1e-6));
    expect(s.frameIndex, 2);
    expect(s.rootDelta.z, closeTo(0.25, 1e-6));
  });

  test('StateBlendMachine crossfades between states via float parameter and exit-time rules', () {
    const idleClip = MotionClip(name: 'idle', durationSeconds: 1.0, rootVelocity: BlendVec3.zero);
    const runClip = MotionClip(name: 'run', durationSeconds: 0.5, rootVelocity: BlendVec3(0.0, 0.0, 6.0));
    const jumpClip = MotionClip(
      name: 'jump',
      durationSeconds: 0.4,
      loop: false,
      rootVelocity: BlendVec3(0.0, 4.0, 2.0),
    );

    final fsm = StateBlendMachine(
      states: const [
        BlendStateDef(name: 'Idle', clip: idleClip),
        BlendStateDef(name: 'Run', clip: runClip),
        BlendStateDef(name: 'Jump', clip: jumpClip),
      ],
      initialState: 'Idle',
      rules: [
        BlendTransitionRule(
          fromState: 'Idle',
          toState: 'Run',
          crossfadeDuration: 0.2,
          condition: (p, _) => (p['speed'] ?? 0.0) > 0.5,
        ),
        BlendTransitionRule(
          fromState: 'Jump',
          toState: 'Run',
          crossfadeDuration: 0.1,
          exitTimeNormalized: 0.9,
        ),
      ],
    );

    fsm.setFloat('speed', 2.0);
    final midBlend = fsm.step(0.1);
    expect(midBlend.activeState, 'Run');
    expect(midBlend.transitionFromState, 'Idle');
    expect(midBlend.transitionAlpha, closeTo(0.0, 1e-4));

    final halfway = fsm.step(0.1);
    expect(halfway.transitionAlpha, closeTo(0.5, 1e-4));
    expect(halfway.rootMotionDelta.z, closeTo(0.3, 1e-4));

    final finished = fsm.step(0.15);
    expect(finished.transitionFromState, isNull);
    expect(finished.transitionAlpha, closeTo(1.0, 1e-6));

    // Force Jump and verify exit-time automatic return to Run after clip finishes
    fsm.forceTransition('Jump', crossfadeDuration: 0.0);
    for (var i = 0; i < 5; i++) {
      fsm.step(0.1);
    }
    expect(fsm.currentStateName, 'Run');
  });
}
