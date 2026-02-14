module mutagen.parser.scanner;

import std.algorithm : sort;
import std.file : exists, isDir, dirEntries, SpanMode;
import std.path : baseName, buildPath, extension;
import std.string : toLower;
import std.uni : icmp;

import mutagen.parser.config : ParserConfig;

struct TrackInfo
{
    string name;
    string path;
    int trackNum;
    int playCount;
}

struct AlbumInfo
{
    string name;
    string dir;
    TrackInfo[] tracks;
    int playCount;
}

struct ArtistInfo
{
    string name;
    string dir;
    string coverDir;
    AlbumInfo[] albums;
    int playCount;
}

ArtistInfo[] scanLibrary(ParserConfig cfg)
{
    if (!exists(cfg.musicDir) || !isDir(cfg.musicDir))
        return [];

    string[] artistNames;
    foreach (entry; dirEntries(cfg.musicDir, SpanMode.shallow))
    {
        if (entry.isDir)
            artistNames ~= baseName(entry.name);
    }
    artistNames.sort!((a, b) => icmp(a, b) < 0);

    ArtistInfo[] ret;
    ret.reserve(artistNames.length);

    foreach (artistName; artistNames)
    {
        string artistDir = buildPath(cfg.musicDir, artistName);
        ArtistInfo ai = scanArtist(artistName, artistDir);
        ret ~= ai;
    }
    return ret;
}

ArtistInfo scanArtist(string name, string dir)
{
    ArtistInfo ai;
    ai.name = name;
    ai.dir = dir;

    string[] albumNames;
    if (exists(dir) && isDir(dir))
    {
        foreach (entry; dirEntries(dir, SpanMode.shallow))
        {
            if (entry.isDir)
                albumNames ~= baseName(entry.name);
        }
    }
    albumNames.sort();

    ai.albums.reserve(albumNames.length);
    foreach (albumName; albumNames)
    {
        string albumDir = buildPath(dir, albumName);
        ai.albums ~= scanAlbum(albumName, albumDir);
    }
    ai.coverDir = findCoverDir(dir, albumNames);
    return ai;
}

AlbumInfo scanAlbum(string name, string dir)
{
    AlbumInfo ai;
    ai.name = name;
    ai.dir = dir;

    string[] trackPaths = collectAudio(dir, SpanMode.shallow);
    ai.tracks.reserve(trackPaths.length);

    foreach (idx, path; trackPaths)
    {
        TrackInfo ti;
        ti.path = path;
        ti.name = stripTrackName(baseName(path));
        ti.trackNum = cast(int)(idx + 1);
        ai.tracks ~= ti;
    }
    return ai;
}

enum musicDir = "/home/cet/Music";

private immutable audioExts = [".flac", ".mp3", ".ogg", ".opus", ".wav", ".m4a", ".aac", ".wma"];

bool isAudioFile(string path)
{
    string ext = path.extension.toLower();
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

string[] albumNames(ArtistInfo* ai)
{
    string[] ret;
    ret.reserve(ai.albums.length);
    foreach (ref alb; ai.albums)
        ret ~= alb.name;
    return ret;
}

string[] albumDirs(ArtistInfo* ai)
{
    string[] ret;
    ret.reserve(ai.albums.length);
    foreach (ref alb; ai.albums)
        ret ~= alb.dir;
    return ret;
}

private string stripTrackName(string filename)
{
    import std.string : indexOf, lastIndexOf;
    ptrdiff_t dot = lastIndexOf(filename, '.');
    if (dot > 0)
        filename = filename[0..dot];
    ptrdiff_t dash = indexOf(filename, " - ");
    if (dash >= 0)
        filename = filename[dash + 3..$];
    return filename;
}

string findCoverArt(string dir)
{
    if (dir.length == 0 || !exists(dir))
        return "";

    immutable names = ["cover", "folder", "front", "album", "art",
        "Cover", "Folder", "Front", "Album", "Art"];
    immutable exts = [".jpg", ".jpeg", ".png"];

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
            string ext = entry.name.extension.toLower();
            if (ext == ".jpg" || ext == ".jpeg" || ext == ".png")
                return entry.name;
        }
    }
    catch (Exception e) {}

    return "";
}

private string findCoverDir(string artistDir, string[] albNames)
{
    if (findCoverArt(artistDir).length > 0)
        return artistDir;
    if (albNames.length > 0)
        return buildPath(artistDir, albNames[$ - 1]);
    return artistDir;
}
