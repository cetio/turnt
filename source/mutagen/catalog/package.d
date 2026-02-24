module mutagen.catalog;

public import mutagen.catalog.album;
public import mutagen.catalog.artist;
public import mutagen.catalog.image;
public import mutagen.catalog.track;

import std.file : SpanMode, dirEntries, exists, isDir;
import std.path : baseName, dirName;
import std.string : strip, split;
import mutagen.audio : isAudio;

struct Catalog
{
    Artist[] artists;
    Album[] albums;
    Track[] tracks;

    static Catalog build(string[] searchPaths)
    {
        Catalog ret;
        Artist[string] artistMap;
        Album[string] albumMap;

        foreach (path; searchPaths)
        {
            if (!exists(path) || !isDir(path))
                continue;

            try
            {
                foreach (entry; dirEntries(path, SpanMode.depth))
                {
                    if (!entry.isFile || !isAudio(entry.name))
                        continue;

                    Track track = Track.fromFile(entry.name);
                    if (!track.audio.data.hasValue)
                        continue;

                    ret.tracks ~= track;

                    // Determine album name
                    string[] albumTags = track.audio["ALBUM"];
                    string albumName = albumTags !is null ? albumTags[0] : baseName(dirName(entry.name));

                    // Get or create album
                    Album album;
                    if (Album* p = albumName in albumMap)
                        album = *p;
                    else
                    {
                        album = new Album(albumName);
                        albumMap[albumName] = album;
                        ret.albums ~= album;
                    }
                    
                    track.album = album;
                    album.tracks ~= track;

                    // Determine artist name(s)
                    string[] artistTags = track.audio["ARTIST"];
                    if (artistTags is null)
                        artistTags = track.audio["ALBUMARTIST"];
                    
                    if (artistTags !is null)
                    {
                        foreach (tagStr; artistTags)
                        {
                            // Some formats return artists comma separated in a single tag
                            string[] splitArtists = tagStr.split(",");
                            foreach (artistNameRaw; splitArtists)
                            {
                                string artistName = artistNameRaw.strip();
                                if (artistName.length == 0)
                                    continue;

                                Artist artist;
                                if (Artist* p = artistName in artistMap)
                                    artist = *p;
                                else
                                {
                                    artist = new Artist(artistName);
                                    artistMap[artistName] = artist;
                                    ret.artists ~= artist;
                                }
                                
                                // Link artist and album if not already linked
                                bool albumHasArtist = false;
                                foreach (a; album.artists)
                                {
                                    if (a.name == artistName)
                                    {
                                        albumHasArtist = true;
                                        break;
                                    }
                                }
                                
                                if (!albumHasArtist)
                                {
                                    album.artists ~= artist;
                                    artist.albums ~= album;
                                }
                            }
                        }
                    }
                }
            }
            catch (Exception) { }
        }

        foreach (album; ret.albums)
            album.sortTracks();

        return ret;
    }
}