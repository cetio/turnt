module mutagen.catalogue;

import std.algorithm : sort;
import std.ascii : isDigit;
import std.file : dirEntries, exists, isDir, read, SpanMode;
import std.path : baseName, buildPath, extension;
import std.string : indexOf, lastIndexOf, split, toLower;

import mutagen.audio : Mutagen;

enum musicDir = "/home/cet/Music";

private immutable audioExts = [
    ".flac", ".mp3", ".ogg", ".opus", ".wav", ".m4a", ".aac", ".wma", ".mp4"
];

class Track
{
public:
    string name;
    string file;
    int trackNum;
    Mutagen audio;
    ubyte[] image;

    int getPlayCount()
    {
        if (audio is null)
            return 0;
        return audio.getPlayCount();
    }

    void setPlayCount(int count)
    {
        if (audio !is null)
            audio.setPlayCount(count);
    }
}

class Album
{
public:
    string name;
    string dir;
    string coverDir;
    Track[] tracks;
    ubyte[] image;

    int getPlayCount()
    {
        int ret = 0;
        foreach (track; tracks)
        {
            if (track !is null)
                ret += track.getPlayCount();
        }
        return ret;
    }
}

class Artist
{
public:
    string name;
    string dir;
    string coverDir;
    Album[] albums;

    int getPlayCount()
    {
        int ret = 0;
        foreach (album; albums)
        {
            if (album !is null)
                ret += album.getPlayCount();
        }
        return ret;
    }
}

class Catalogue
{
public:
    string dir;
    Artist[] artists;
}

bool isAudioFile(string path)
{
    string ext = extension(path).toLower();
    foreach (e; audioExts)
    {
        if (ext == e)
            return true;
    }
    return false;
}

string[] collectAudio(string dir, SpanMode mode = SpanMode.depth)
{
    string[] ret;
    if (!exists(dir) || !isDir(dir))
        return ret;

    foreach (entry; dirEntries(dir, mode))
    {
        if (entry.isFile && isAudioFile(entry.name))
            ret ~= entry.name;
    }

    ret.sort();
    return ret;
}

string[] findAlbums(string dir)
{
    string[] ret;
    if (!exists(dir) || !isDir(dir))
        return ret;

    foreach (entry; dirEntries(dir, SpanMode.shallow))
    {
        if (entry.isDir)
            ret ~= baseName(entry.name);
    }

    ret.sort();
    return ret;
}

string findCoverArt(string dir)
{
    if (dir.length == 0 || !exists(dir))
        return "";

    immutable names = ["cover", "folder", "front", "album", "art", "Cover", "Folder", "Front", "Album", "Art"];
    immutable exts = [".jpg", ".jpeg", ".png", ".webp"];

    foreach (name; names)
    {
        foreach (ext; exts)
        {
            string path = buildPath(dir, name~ext);
            if (exists(path))
                return path;
        }
    }

    try
    {
        foreach (entry; dirEntries(dir, SpanMode.shallow))
        {
            if (!entry.isFile)
                continue;
            string ext = extension(entry.name).toLower();
            if (ext == ".jpg" || ext == ".jpeg" || ext == ".png" || ext == ".webp")
                return entry.name;
        }
    }
    catch (Exception)
    {
    }

    return "";
}

Catalogue collectAll(string dir)
{
    Catalogue ret = new Catalogue();
    ret.dir = dir;

    if (!exists(dir) || !isDir(dir))
        return ret;

    string[] artistNames;
    foreach (entry; dirEntries(dir, SpanMode.shallow))
    {
        if (entry.isDir)
            artistNames ~= baseName(entry.name);
    }
    artistNames.sort();

    ret.artists.reserve(artistNames.length);
    foreach (artistName; artistNames)
    {
        string artistDir = buildPath(dir, artistName);
        ret.artists ~= scanArtist(artistName, artistDir);
    }

    return ret;
}

private Artist scanArtist(string name, string dir)
{
    Artist artist = new Artist();
    artist.name = name;
    artist.dir = dir;
    artist.coverDir = dir;

    bool artistHasCover = findCoverArt(dir).length > 0;
    if (artistHasCover)
        artist.coverDir = dir;

    string[] albumNames = findAlbums(dir);
    artist.albums.reserve(albumNames.length);

    foreach (albumName; albumNames)
    {
        string albumDir = buildPath(dir, albumName);
        Album album = scanAlbum(albumName, albumDir);
        artist.albums ~= album;

        if (!artistHasCover && artist.coverDir == dir)
        {
            if (album.image.length > 0 || findCoverArt(albumDir).length > 0)
                artist.coverDir = albumDir;
        }
    }

    if (!artistHasCover && artist.coverDir == dir && artist.albums.length > 0)
        artist.coverDir = artist.albums[$ - 1].dir;

    return artist;
}

private Album scanAlbum(string name, string dir)
{
    Album album = new Album();
    album.name = name;
    album.dir = dir;
    album.coverDir = dir;

    string[] trackPaths = collectAudio(dir, SpanMode.shallow);
    album.tracks.reserve(trackPaths.length);

    foreach (idx, path; trackPaths)
    {
        Track track = scanTrack(path, dir, cast(int)idx + 1);
        album.tracks ~= track;

        if (album.image.length == 0 && track.image.length > 0)
            album.image = track.image.dup;
    }

    if (album.image.length == 0)
    {
        string cover = findCoverArt(dir);
        if (cover.length > 0)
            album.image = readImageFromFile(cover);
    }

    return album;
}

private Track scanTrack(string path, string albumDir, int index)
{
    Track track = new Track();
    track.file = path;
    track.audio = new Mutagen(path);

    string title = track.audio.getTag("TITLE");
    if (title.length > 0)
        track.name = title;
    else
        track.name = stripTrackName(baseName(path));

    string trackTag = track.audio.getTag("TRACKNUMBER");
    int parsedTrack = parseTrackNumber(trackTag);
    if (parsedTrack > 0)
        track.trackNum = parsedTrack;
    else
        track.trackNum = index;

    if (track.audio.image.length > 0)
        track.image = track.audio.image.dup;
    else
    {
        string cover = findCoverArt(albumDir);
        if (cover.length > 0)
            track.image = readImageFromFile(cover);
    }

    return track;
}

private int parseTrackNumber(string value)
{
    if (value.length == 0)
        return 0;

    string part = value;
    ptrdiff_t slash = indexOf(value, '/');
    if (slash > 0)
        part = value[0..slash];

    int ret = 0;
    bool haveDigit;
    foreach (ch; part)
    {
        if (!isDigit(ch))
            break;
        haveDigit = true;
        ret = ret * 10 + (ch - '0');
    }

    if (!haveDigit)
        return 0;
    return ret;
}

private string stripTrackName(string filename)
{
    ptrdiff_t dot = lastIndexOf(filename, '.');
    if (dot > 0)
        filename = filename[0..dot];

    ptrdiff_t dash = indexOf(filename, " - ");
    if (dash >= 0)
        filename = filename[dash + 3..$];

    return filename;
}

private ubyte[] readImageFromFile(string path)
{
    ubyte[] ret;
    try
    {
        ret = cast(ubyte[])read(path);
    }
    catch (Exception)
    {
    }
    return ret;
}
