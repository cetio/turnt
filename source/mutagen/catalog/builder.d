module mutagen.catalog.builder;

import std.algorithm : sort;
import std.file : SpanMode, dirEntries, exists, isDir, isFile;
import std.path : baseName, buildPath, dirName, extension;
import std.string : toLower;

import mutagen.catalog.types : Album, Artist, Catalog, Track;

enum musicDir = "/home/cet/Music";

private Catalog cachedCatalog;
private bool catalogLoaded;

Catalog collectAll(string dir)
{
    if (catalogLoaded && cachedCatalog.root == dir)
        return cachedCatalog;

    Catalog ret;
    ret.root = dir;
    ret.dir = dir;

    if (!exists(dir) || !isDir(dir))
        return ret;

    size_t[string] artistByName;
    size_t[string] albumByKey;

    foreach (entry; dirEntries(dir, SpanMode.depth))
    {
        if (!entry.isFile)
            continue;
        if (!isAudioPath(entry.name))
            continue;

        Track track = new Track(entry.name);

        string albumDir = dirName(entry.name);
        string artistDir = dirName(albumDir);

        string trackArtist;
        string[] artistTags = track.audio["ARTIST"];
        if (artistTags.length > 0)
            trackArtist = artistTags[0];

        string trackAlbum;
        string[] albumTags = track.audio["ALBUM"];
        if (albumTags.length > 0)
            trackAlbum = albumTags[0];

        if (trackAlbum.length == 0)
            trackAlbum = baseName(albumDir);
        if (trackArtist.length == 0)
            trackArtist = baseName(artistDir);
        if (trackArtist.length == 0)
            trackArtist = "Unknown Artist";
        if (trackAlbum.length == 0)
            trackAlbum = "Unknown Album";

        size_t artistIndex;
        if (trackArtist in artistByName)
        {
            artistIndex = artistByName[trackArtist];
        }
        else
        {
            Artist artist = new Artist();
            artist.name = trackArtist;
            ret.artists ~= artist;
            artistIndex = ret.artists.length - 1;
            artistByName[trackArtist] = artistIndex;
        }

        string albumKey = trackArtist~"\n"~trackAlbum;
        size_t albumIndex;
        if (albumKey in albumByKey)
        {
            albumIndex = albumByKey[albumKey];
        }
        else
        {
            Album album = new Album();
            album.name = trackAlbum;
            album.dir = albumDir;
            album.artist = ret.artists[artistIndex];
            ret.albums ~= album;
            albumIndex = ret.albums.length - 1;
            albumByKey[albumKey] = albumIndex;
            ret.artists[artistIndex].albums ~= album;
        }

        Album album = ret.albums[albumIndex];
        if (track.trackNumber <= 0)
            track.trackNumber = cast(int)album.tracks.length + 1;

        track.album = album;
        track.artist = ret.artists[artistIndex];
        album.tracks ~= track;
        ret.tracks ~= track;
    }

    cachedCatalog = ret;
    catalogLoaded = true;
    return ret;
}

string[] collectAudio(string dir, SpanMode mode = SpanMode.depth)
{
    string[] ret;
    if (dir.length == 0 || !exists(dir) || !isDir(dir))
        return ret;

    try
    {
        foreach (entry; dirEntries(dir, mode))
        {
            if (!entry.isFile)
                continue;
            if (!isAudioPath(entry.name))
                continue;
            ret ~= entry.name;
        }
    }
    catch (Exception)
    {
        return ret;
    }

    ret.sort();
    return ret;
}

string[] findAlbums(string dir)
{
    string[] ret;
    if (dir.length == 0 || !exists(dir) || !isDir(dir))
        return ret;

    try
    {
        foreach (entry; dirEntries(dir, SpanMode.shallow))
        {
            if (!entry.isDir)
                continue;
            ret ~= baseName(entry.name);
        }
    }
    catch (Exception)
    {
        return ret;
    }

    ret.sort();
    return ret;
}

string findCoverArt(string dir)
{
    if (dir.length == 0 || !exists(dir) || !isDir(dir))
        return "";

    string[] names = [
        "cover", "folder", "front", "album", "art",
        "Cover", "Folder", "Front", "Album", "Art"
    ];
    string[] exts = [".jpg", ".jpeg", ".png", ".webp"];

    foreach (name; names)
    {
        foreach (ext; exts)
        {
            string path = buildPath(dir, name~ext);
            if (exists(path) && isFile(path))
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
        return "";
    }

    return "";
}

private:

bool isAudioPath(string path)
{
    string ext = extension(path).toLower();

    switch (ext)
    {
    case ".flac":
    case ".mp3":
    case ".m4a":
    case ".mp4":
    case ".m4b":
    case ".m4p":
    case ".opus":
    case ".ogg":
        return true;

    default:
        return false;
    }
}
