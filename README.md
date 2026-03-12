# Mutagen

Mutagen is an audio metadata parsing library for D supporting FLAC, MP3, and MP4 formats. It provides a clean, unified interface for reading and writing audio file metadata, including tags, images, and playback statistics.

## Features

- **Multi-format support**: FLAC, MP3, M4A, MP4, AAC
- **Unified interface**: Simple `Track` class that handles all formats
- **Metadata access**: Read/write tags via array indexing
- **Image extraction**: Extract embedded album artwork
- **Playback statistics**: Track play counts and usage data
- **Catalog types**: `Track`, `Album`, `Artist`, and `Image` classes

## Quick Start

```d
import mutagen;
import std.stdio;

void main()
{
    // Load a track from file
    Track track = Track.fromFile("music.flac");
    
    // Read metadata
    writeln("Title: ", track.name);
    writeln("Artist: ", track["ARTIST"]);
    writeln("Album: ", track["ALBUM"]);
    
    // Write metadata
    track["GENRE"] = "Electronic";
    
    // Extract album art
    Image cover = track.image();
    if (cover.hasData()) {
        writeln("Album art available: ", cover.type);
    }
}
```

## Architecture

- `mutagen.track` - Core audio type with format dispatch
- `mutagen.album` - Album grouping and metadata
- `mutagen.artist` - Artist information and collections
- `mutagen.image` - Image handling and type detection
- `mutagen.format` - Format-specific parsers (FLAC, MP3, MP4)

## License

Mutagen is licensed under the [AGPL-3.0 license](LICENSE.txt).
