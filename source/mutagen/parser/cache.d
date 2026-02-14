module mutagen.parser.cache;

import std.conv : to;
import std.file : exists, read, write;
import std.stdio : writeln;
import std.string : indexOf, split, strip;

import mutagen.parser.config : ParserConfig;
import mutagen.parser.scanner : ArtistInfo, AlbumInfo, TrackInfo;

void saveLibrary(ParserConfig cfg, ArtistInfo[] artists)
{
    if (!cfg.useFileCache)
        return;

    cfg.ensureCacheDir();
    string path = cfg.cacheFilePath();

    try
    {
        string data;
        foreach (ref ai; artists)
        {
            data ~= "A\t"~ai.name~"\t"~ai.dir~"\t"~ai.coverDir~"\t"~ai.playCount.to!string~"\n";
            foreach (ref alb; ai.albums)
            {
                data ~= "B\t"~alb.name~"\t"~alb.dir~"\t"~alb.playCount.to!string~"\n";
                foreach (ref tr; alb.tracks)
                    data ~= "T\t"~tr.name~"\t"~tr.path~"\t"~tr.trackNum.to!string~"\t"~tr.playCount.to!string~"\n";
            }
        }
        write(path, data);
        writeln("[cache] Saved library cache: "~path);
    }
    catch (Exception e)
        writeln("[cache] Error saving: "~e.msg);
}

ArtistInfo[] loadLibrary(ParserConfig cfg)
{
    if (!cfg.useFileCache)
        return [];

    string path = cfg.cacheFilePath();
    if (!exists(path))
        return [];

    try
    {
        string raw = cast(string)read(path);
        string[] lines = raw.split("\n");

        ArtistInfo[] ret;
        ArtistInfo* curArtist;
        AlbumInfo* curAlbum;

        foreach (line; lines)
        {
            if (line.length < 3)
                continue;
            string[] parts = line.split("\t");
            if (parts.length == 0)
                continue;

            string tag = parts[0];
            if (tag == "A" && parts.length >= 5)
            {
                ArtistInfo ai;
                ai.name = parts[1];
                ai.dir = parts[2];
                ai.coverDir = parts[3];
                ai.playCount = parts[4].to!int;
                ret ~= ai;
                curArtist = &ret[$ - 1];
                curAlbum = null;
            }
            else if (tag == "B" && parts.length >= 4 && curArtist !is null)
            {
                AlbumInfo alb;
                alb.name = parts[1];
                alb.dir = parts[2];
                alb.playCount = parts[3].to!int;
                curArtist.albums ~= alb;
                curAlbum = &curArtist.albums[$ - 1];
            }
            else if (tag == "T" && parts.length >= 5 && curAlbum !is null)
            {
                TrackInfo ti;
                ti.name = parts[1];
                ti.path = parts[2];
                ti.trackNum = parts[3].to!int;
                ti.playCount = parts[4].to!int;
                curAlbum.tracks ~= ti;
            }
        }

        if (ret.length > 0)
            writeln("[cache] Loaded library cache: "~ret.length.to!string~" artists");
        return ret;
    }
    catch (Exception e)
    {
        writeln("[cache] Error loading: "~e.msg);
        return [];
    }
}
