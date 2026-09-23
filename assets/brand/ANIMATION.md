# Vitail loading artwork

Derived from the supplied `logo animation.mp4` (84 frames, 25 fps, 3.36 seconds) and `logo & title - colourful trans.png`.

- `vitail-launch.webp`: one playback of the source animation.
- `vitail-loading.webp`: looping version of the same animation.
- `vitail-mark.png`: completed logo frame for the launch reveal and reduced motion.
- `vitail-title.png`: title extracted from the supplied PNG.
- `vitail-logo-title.png`: supplied full artwork, preserved for reuse.

The animation's white video background was removed and its empty margins trimmed for use on themed surfaces. Assets are bundled and require no video playback plugin or network request. The Flutter launch sequence holds the revealed title for one second, and runs once per app instance. The operating system's native launch screen still precedes this Flutter sequence.
