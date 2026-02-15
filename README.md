# Turnt

Turnt is a GTK music player built around a vinyl record centric design.
It focuses on simplicity and a semi-neuomorphic UI for local music libraries.

## Features

Among Turnt's features are:

- **Turntable-first playback UI** with a vinyl-focused layout.
- **Local music library browsing** with fast navigation.
- **Simple queue control** focused on “play what you picked” workflows.
- **GTK 4 UI** with a semi-neuomorphic aesthetic.

## Architecture

- `turnt.window` - Main application window and high-level UI composition.
- `turnt.queue` - Playback queue management and control flow.
- `turnt.player` - GStreamer-backed audio playback.
- `turnt.library` - Local library scanning and indexing.
- `turnt.views` - Primary UI views (turntable, browse, queue).

## License

Turnt is licensed under the [AGPL-3.0 license](LICENSE.txt).

