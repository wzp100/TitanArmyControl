# Pinned upstream

- Source: https://github.com/briankendall/proxy-audio-device
- Revision: d3d8c8c0343845e03fd95e6764f0fa9853d88e10
- License: Unlicense; Apple PublicUtility sources retain their original Apple sample-code license headers.
- Sources were retrieved using the GitHub connector at this revision. No upstream settings app is shipped.

`AudioDriver/prepare.py` stages the original files into `.build/audio-driver-sources` and applies all Titan Army adaptations. The original vendor source is kept separate from generated driver code.

Titan Army adaptations include a distinct device/bundle identity, display-only routing, a typed configuration property, persisted volume/mute, matching reported and actual dB gain, bounded buffers, planar stereo routing, short gain ramps, and read-only PCM counters for validation. The audio component performs software gain after Core Audio mixing; it does not write DDC registers or change the display's hardware volume.
