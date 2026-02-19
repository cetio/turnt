module mutagen.catalog.types;

import std.conv;
import std.stdio;
import mutagen.audio;

class Track
{
public:
    Audio audio;
    string file;
    string title;
    int trackNumber;
    Album album;
    Artist artist;

    this(string file)
    {
        this.file = file;
        audio = Audio(File(file, "rb"));

        string[] titleTags = audio["TITLE"];
        if (titleTags.length > 0)
            title = titleTags[0];

        string trackValue;
        string[] trackNumberTags = audio["TRACKNUMBER"];
        if (trackNumberTags.length > 0)
            trackValue = trackNumberTags[0];
        
        if (trackValue.length == 0)
        {
            string[] trackTags = audio["TRACK"];
            if (trackTags.length > 0)
                trackValue = trackTags[0];
        }
        trackNumber = parseTrackNumber(trackValue);

        if (title.length == 0)
        {
            import std.path : baseName;
            import std.string : lastIndexOf;
            title = baseName(file);
            ptrdiff_t dot = title.lastIndexOf('.');
            if (dot > 0)
                title = title[0..dot];
        }
    }

    int getPlayCount()
    {
        if (!audio.data.hasValue)
            return 0;

        string value;
        string[] playCountTags = audio["PLAY_COUNT"];
        if (playCountTags.length > 0)
            value = playCountTags[0];

        if (value.length == 0)
        {
            string[] pcntTags = audio["PCNT"];
            if (pcntTags.length > 0)
                value = pcntTags[0];
        }
        return parsePlayCount(value);
    }

    bool setPlayCount(int count)
    {
        if (!audio.data.hasValue)
            return false;

        if (count < 0)
            count = 0;

        audio["PLAY_COUNT"] = count.to!string;
        return true;
    }
}

class Album
{
public:
    string name;
    string dir;
    Track[] tracks;
    Artist artist;

    int getPlayCount()
    {
        int ret;
        foreach (track; tracks)
            ret += track.getPlayCount();
        return ret;
    }

    bool setPlayCount(int count)
    {
        if (tracks.length == 0)
            return false;

        if (count < 0)
            count = 0;

        int baseCount = count / cast(int)tracks.length;
        int extra = count % cast(int)tracks.length;

        bool ret = true;
        foreach (idx, track; tracks)
        {
            int trackCount = baseCount;
            if (cast(int)idx < extra)
                trackCount++;
            if (!track.setPlayCount(trackCount))
                ret = false;
        }

        return ret;
    }
}

class Artist
{
public:
    string name;
    Album[] albums;

    int getPlayCount()
    {
        int ret;
        foreach (album; albums)
            ret += album.getPlayCount();
        return ret;
    }

    bool setPlayCount(int count)
    {
        Track[] allTracks;
        foreach (album; albums)
            allTracks ~= album.tracks;

        if (allTracks.length == 0)
            return false;

        if (count < 0)
            count = 0;

        int baseCount = count / cast(int)allTracks.length;
        int extra = count % cast(int)allTracks.length;

        bool ret = true;
        foreach (idx, track; allTracks)
        {
            int trackCount = baseCount;
            if (cast(int)idx < extra)
                trackCount++;
            if (!track.setPlayCount(trackCount))
                ret = false;
        }

        return ret;
    }
}

struct Catalog
{
    string root;
    string dir;
    Artist[] artists;
    Album[] albums;
    Track[] tracks;
}

private:

int parsePlayCount(string value)
{
    if (value.length == 0)
        return 0;

    try
        return value.to!int;
    catch (Exception)
        return 0;
}

int parseTrackNumber(string value)
{
    if (value.length == 0)
        return 0;

    import std.string : indexOf, strip;

    ptrdiff_t slash = value.indexOf('/');
    if (slash > 0)
        value = value[0..slash];

    value = value.strip();
    if (value.length == 0)
        return 0;

    try
        return value.to!int;
    catch (Exception)
        return 0;
}
