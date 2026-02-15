module mutagen.audio;

import std.conv : to;
import std.path : extension;
import std.stdio : File;
import std.string : toLower, toUpper;

import mutagen.flac : FLAC, HeaderType, Picture;
import mutagen.flac.vorbis : Vorbis;
import mutagen.mp3 : MP3, readId3PlayCount, writeId3PlayCount;
import mutagen.mp4 : MP4, readMp4Tag, writeMp4Tag;
import mutagen.opus : Opus, readOpusTags;

enum AudioFormat
{
    flac,
    mp3,
    mp4,
    opus,
    unknown
}

final class Mutagen
{
public:
    string path;
    File file;
    AudioFormat format = AudioFormat.unknown;
    string[string] tags;
    ubyte[] image;

    this(string path)
    {
        this.path = path;
        try
        {
            file = File(path, "rb");
            file.close();
        }
        catch (Exception)
        {
        }
        parseNow();
    }

    void parse()
    {
        parseNow();
    }

private:
    void parseNow()
    {
        tags = null;
        image.length = 0;
        format = AudioFormat.unknown;

        string ext = extension(path).toLower();
        if (ext == ".flac")
        {
            format = AudioFormat.flac;
            parseFlac();
            return;
        }

        if (ext == ".mp3")
        {
            format = AudioFormat.mp3;
            parseMp3();
            return;
        }

        if (ext == ".m4a" || ext == ".mp4" || ext == ".aac")
        {
            format = AudioFormat.mp4;
            parseMp4();
            return;
        }

        if (ext == ".opus" || ext == ".ogg")
        {
            format = AudioFormat.opus;
            parseOpus();
            return;
        }
    }

public:
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
                return value.to!int;
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

        if (format == AudioFormat.mp3)
            writeId3PlayCount(path, count);
        else if (format == AudioFormat.mp4)
            writeMp4Tag(path, "PLAY_COUNT", count.to!string);
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
                            tags[k.toUpper()] = v;
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
            foreach (k, v; mp3.tags)
                tags[k.toUpper()] = v;
            if (mp3.image.length > 0)
                image = mp3.image.dup;
        }
        catch (Exception)
        {
        }

        if (!("PLAY_COUNT" in tags))
            tags["PLAY_COUNT"] = readId3PlayCount(path).to!string;
    }

    void parseMp4()
    {
        try
        {
            MP4 mp4 = new MP4(path);
            foreach (k, v; mp4.tags)
                tags[k.toUpper()] = v;
            if (mp4.image.length > 0)
                image = mp4.image.dup;
        }
        catch (Exception)
        {
        }

        if (!("PLAY_COUNT" in tags))
        {
            string value = readMp4Tag(path, "PLAY_COUNT");
            if (value.length > 0)
                tags["PLAY_COUNT"] = value;
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
