module turnt.catalogue.view;

import std.algorithm : sort, reverse;
import std.file : SpanMode;
import std.string : indexOf, toLower;

import gtk.adjustment;
import gtk.box;
import gtk.scrolled_window;
import gtk.types : Orientation, Overflow, PolicyType;
import gtk.widget;

import turnt.catalogue.browse;
import turnt.playlist : PlaylistState;
import turnt.vinyl : Vinyl;

import mutagen.parser.config : ParserConfig;
import mutagen.parser.scanner : ArtistInfo, AlbumInfo, TrackInfo, scanLibrary,
    collectAudio, albumNames, albumDirs;
import mutagen.parser.cache : saveLibrary, loadLibrary;

enum BrowseView
{
    Artists,
    Albums,
    Tracks
}

enum SortMode
{
    AZ,
    ZA,
    Plays
}

class CatalogueView : Box
{
public:
    BrowseView currentView = BrowseView.Artists;
    ArtistInfo[] artistCache;
    ArtistInfo[] filteredCache;
    enum cardWidth = 372;

    ScrolledWindow scrolled;
    Box contentBox;
    bool dragged = false;
    bool isRightPanel = false;
    string stickyArtist;
    string stickyAlbum;
    PlaylistState playlist;
    Widget searchWidget;
    bool playlistDropAttached;

    void delegate(int) lazyMakeCard;

private:
    Vinyl[string] artistVinyls;
    Vinyl[string] albumVinyls;
    Vinyl[string] trackVinyls;
    int lazyTotal = 0;
    int lazyCount = 0;
    double lazyCardHeight = 74;
    string searchFilter;
    SortMode sortMode = SortMode.AZ;

public:
    this()
    {
        super(Orientation.Vertical, 0);
        addCssClass("browser-panel");
        hexpand = true;
        vexpand = true;
        overflow = Overflow.Hidden;

        scrolled = new ScrolledWindow();
        scrolled.hscrollbarPolicy = PolicyType.Never;
        scrolled.vscrollbarPolicy = PolicyType.External;
        scrolled.vexpand = true;
        scrolled.overflow = Overflow.Hidden;

        contentBox = new Box(Orientation.Vertical, 8);
        contentBox.marginStart = 4;
        contentBox.marginEnd = 4;
        contentBox.marginTop = 8;
        contentBox.marginBottom = 8;

        scrolled.setChild(contentBox);
        append(scrolled);

        Adjustment vadj = scrolled.getVadjustment();
        if (vadj !is null)
            vadj.connectValueChanged(&ensureCards);

        loadLibraryCache();
        showArtists();
    }

    void ensureCards()
    {
        if (!isRightPanel && playlist.editing)
        {
            resetLazy();
            return;
        }

        if (lazyMakeCard is null || lazyCount >= lazyTotal)
            return;

        Adjustment adj = scrolled.getVadjustment();
        double viewBottom = 600;
        if (adj !is null && adj.pageSize > 0)
            viewBottom = adj.value + adj.pageSize;

        int needed = cast(int)(viewBottom / lazyCardHeight) + 4;
        if (needed > lazyTotal)
            needed = lazyTotal;

        while (lazyCount < needed)
        {
            lazyMakeCard(lazyCount);
            lazyCount++;
        }

        if (lazyCount >= lazyTotal)
            contentBox.heightRequest = -1;
    }

    void setupLazy(int total, double cardH, int contentH)
    {
        lazyTotal = total;
        lazyCount = 0;
        lazyCardHeight = cardH;
        contentBox.heightRequest = contentH;
    }

    void resetLazy()
    {
        lazyMakeCard = null;
        lazyTotal = 0;
        lazyCount = 0;
        contentBox.heightRequest = -1;
    }

    void filterArtists(string query)
    {
        searchFilter = query;
        rebuildFiltered();
        if (currentView == BrowseView.Artists)
            showArtists();
    }

    void setSortMode(SortMode mode)
    {
        sortMode = mode;
        rebuildFiltered();
        if (currentView == BrowseView.Artists)
            showArtists();
    }

    void showArtists()
    {
        turnt.catalogue.browse.showArtists(this);
    }

    void showAlbums(string artist)
    {
        turnt.catalogue.browse.showAlbums(this, artist);
    }

    void showTracks(string artist, string album)
    {
        turnt.catalogue.browse.showTracks(this, artist, album);
    }

    void showPlaylist(int idx)
    {
        turnt.catalogue.browse.showPlaylist(this, idx);
    }

    void scrollTo(double target)
    {
        Adjustment adj = scrolled.getVadjustment();
        if (adj is null)
            return;
        double mx = adj.upper - adj.pageSize;
        if (target < adj.lower)
            target = adj.lower;
        if (target > mx)
            target = mx;
        adj.value = target;
    }

    Vinyl getOrCreateArtistVinyl(ref ArtistInfo ai)
    {
        if (ai.name in artistVinyls)
            return artistVinyls[ai.name];
        string[] albNames = albumNames(&ai);
        string[] albDirs = albumDirs(&ai);
        Vinyl v = new Vinyl(ai.name, ai.coverDir, 58);
        v.artist = ai.name;
        v.albums = albNames;
        v.albumDirs = albDirs;
        v.trackNum = cast(int)ai.albums.length;
        artistVinyls[ai.name] = v;
        return v;
    }

    Vinyl getOrCreateAlbumVinyl(string artist, string album, string albumDir, int trackCount = -1)
    {
        string key = artist~"|"~album;
        if (Vinyl* p = key in albumVinyls)
            return *p;
        Vinyl v = new Vinyl(album, albumDir, 50, artist, album);
        if (trackCount < 0)
            trackCount = cast(int)collectAudio(albumDir, SpanMode.shallow).length;
        v.trackNum = trackCount;
        albumVinyls[key] = v;
        return v;
    }

    Vinyl getOrCreateTrackVinyl(string artist, string album,
        string albumDir, string trackName, string path)
    {
        if (Vinyl* p = path in trackVinyls)
            return *p;
        Vinyl v = new Vinyl(trackName, albumDir, 32, artist, album);
        v.filePath = path;
        trackVinyls[path] = v;
        return v;
    }

    ArtistInfo* findArtist(string name)
    {
        foreach (ref ai; artistCache)
        {
            if (ai.name == name)
                return &ai;
        }
        return null;
    }

    void rebuildFiltered()
    {
        filteredCache.length = 0;
        if (searchFilter.length == 0)
        {
            filteredCache = artistCache.dup;
        }
        else
        {
            string lf = searchFilter.toLower();
            foreach (ref ai; artistCache)
            {
                if (ai.name.toLower().indexOf(lf) >= 0)
                    filteredCache ~= ai;
            }
        }
        if (sortMode == SortMode.ZA)
            filteredCache.reverse();
        else if (sortMode == SortMode.Plays)
            filteredCache.sort!((a, b) => a.playCount > b.playCount);
    }

private:
    void loadLibraryCache()
    {
        ParserConfig cfg;
        artistCache = loadLibrary(cfg);
        if (artistCache.length == 0)
        {
            artistCache = scanLibrary(cfg);
            saveLibrary(cfg, artistCache);
        }
    }
}

void clearBox(Box box)
{
    Widget child = box.getFirstChild();
    while (child !is null)
    {
        Widget next = child.getNextSibling();
        box.remove(child);
        child = next;
    }
}
