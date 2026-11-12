<p align="center">
  <img src="assets/logo.svg" width="88" alt="voxblend logo"/>
</p>

# voxblend

Pure Dart 1D/2D animation blendspaces, looping sprite/keyframe motion clips, and root-motion state blend machines for `gl_volition`.

## Features
- **`MotionClipSampler`**: Deterministic frame index, normalized time, and wrap-safe root-motion translation delta extraction.
- **`BlendSpace1D` / `BlendSpace2D`**: Parameterized blend weights yielding normalized multi-clip contributions and blended root-motion velocity.
- **`StateBlendMachine`**: Hierarchical transition evaluator supporting named triggers, float parameter guards, `exitTime`, and smooth crossfades.
