module mutagen.audio;

import std.path;
import std.stdio;
import std.string;
import std.conv;
import std.variant;

import mutagen.format.flac;
import mutagen.format.mp3;
import mutagen.format.mp4;

enum AudioFormat
{
    Unknown,
    Flac,
    MP3,
    MP4
}

struct Audio
{
    File file;
    Variant data;

    this(File file)
    {
        this.file = file;

        switch (extension(file.name).toLower())
        {
            case ".flac":
                data = new FLAC(file);
                break;
            case ".mp3":
                data = new MP3(file);
                break;
            case ".m4a":
            case ".mp4":
            case ".aac":
                data = new MP4(file);
                break;
            default:
                break;
        }

        file.close();
    }

    string[] opIndex(string str) const
    {
        if (data.type == typeid(FLAC))
        {
            const(FLAC) flac = data.get!FLAC;
            return flac[str];
        }
        if (data.type == typeid(MP3))
        {
            const(MP3) mp3 = data.get!MP3;
            return mp3[str];
        }
        if (data.type == typeid(MP4))
        {
            const(MP4) mp4 = data.get!MP4;
            return mp4[str];
        }
        return null;
    }

    string opIndexAssign(string val, string tag)
    {
        if (data.type == typeid(FLAC))
        {
            FLAC flac = data.get!FLAC;
            return flac[tag] = val;
        }
        else if (data.type == typeid(MP3))
        {
            MP3 mp3 = data.get!MP3;
            return mp3[tag] = val;
        }
        else if (data.type == typeid(MP4))
        {
            MP4 mp4 = data.get!MP4;
            return mp4[tag] = val;
        }
        return val;
    }

    ubyte[] image() const
    {
        if (data.type == typeid(FLAC))
        {
            const(FLAC) flac = data.get!FLAC;
            return flac.image();
        }
        if (data.type == typeid(MP3))
        {
            const(MP3) mp3 = data.get!MP3;
            return mp3.image();
        }
        if (data.type == typeid(MP4))
        {
            const(MP4) mp4 = data.get!MP4;
            return mp4.image();
        }
        return [];
    }
}
