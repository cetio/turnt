module mutagen.audio;

import std.conv : to;
import std.path : extension;
import std.stdio : File;
import std.string : toLower, toUpper;

import mutagen.format.flac;
import mutagen.format.mp3;
import mutagen.format.mp4;

enum AudioFormat
{
    Unknown,
    Flac,
    Mp3,
    Mp4
}

final class Audio
{
public:
    string path;
    File file;
    AudioFormat format;
    string[string] tags;
    ubyte[] image;

    this(File file)
    {
        switch (extension(file.name).toLower())
        {
            case ".flac":
                format = AudioFormat.Flac;
                parseFlac();
                break;
            case ".mp3":
                format = AudioFormat.Mp3;
                parseMp3();
                break;
            case ".m4a":
            case ".mp4":
            case ".aac":
                format = AudioFormat.Mp4;
                parseMp4();
                break;
            default:
                format = AudioFormat.Unknown;
                break;
        }

        file.close();
    }

    string getTag(string key)
    {
        string upper = key.toUpper();
        if (string* value = upper in tags)
            return *value;
        return "";
    }

    int getPlayCount()
    {
        if (string* value = "PLAY_COUNT" in tags)
        {
            try
            {
                return (*value).to!int;
            }
            catch (Exception)
            {
                return 0;
            }
        }
        return 0;
    }

    void setPlayCount(int count)
    {
        tags["PLAY_COUNT"] = count.to!string;
    }

private:
    void parseFlac()
    {
        try
        {
            FLAC flac = new FLAC(File(path, "rb"));
            foreach (ref header; flac.headers)
            {
                if (header.type == HeaderType.VorbisComment)
                {
                    Vorbis* vorbis = header.data.peek!Vorbis;
                    if (vorbis !is null)
                    {
                        foreach (k, v; vorbis.tags)
                        if (v.length > 0)
                            tags[k] = v[0];
                    }
                }
                else if (header.type == HeaderType.Picture && image.length == 0)
                {
                    Picture* picture = header.data.peek!Picture;
                    if (picture !is null)
                        image = picture.data.dup;
                }
            }
        }
        catch (Exception)
        {
        }
    }

    void parseMp3()
    {
        try
        {
            MP3 mp3 = new MP3(File(path, "rb"));
            tags["TITLE"] = mp3["TITLE"];
            tags["ARTIST"] = mp3["ARTIST"];
            tags["ALBUM"] = mp3["ALBUM"];
            tags["TRACKNUMBER"] = mp3["TRACKNUMBER"];
            tags["PLAY_COUNT"] = mp3["PLAY_COUNT"];
            if (mp3.image.length > 0)
                image = mp3.image.dup;
        }
        catch (Exception)
        {
        }
    }

    void parseMp4()
    {
        try
        {
            MP4 mp4 = new MP4(File(path, "rb"));
            tags["TITLE"] = mp4["TITLE"];
            tags["ARTIST"] = mp4["ARTIST"];
            tags["ALBUM"] = mp4["ALBUM"];
            tags["TRACKNUMBER"] = mp4["TRACKNUMBER"];
            if (mp4.image.length > 0)
                image = mp4.image.dup;
        }
        catch (Exception)
        {
        }
    }

    void parseOpus()
    {
        try
        {
            Opus opus = new Opus(path);
            foreach (k, v; opus.tags)
                tags[k.toUpper()] = v;
            if (opus.image.length > 0)
                image = opus.image.dup;
        }
        catch (Exception)
        {
            string[string] fallback = readOpusTags(path);
            foreach (k, v; fallback)
                tags[k.toUpper()] = v;
        }
    }
}
