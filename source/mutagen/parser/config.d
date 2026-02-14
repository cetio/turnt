module mutagen.parser.config;

import std.path : buildPath, expandTilde;
import std.file : exists, mkdirRecurse;

struct ParserConfig
{
    string musicDir = "/home/cet/Music";
    string cacheDir = "~/.cache/turnt";
    bool useFileCache = true;

    string resolvedCacheDir()
    {
        return expandTilde(cacheDir);
    }

    string cacheFilePath()
    {
        return buildPath(resolvedCacheDir(), "library.cache");
    }

    void ensureCacheDir()
    {
        string dir = resolvedCacheDir();
        if (!exists(dir))
            mkdirRecurse(dir);
    }
}
