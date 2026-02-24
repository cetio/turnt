module turnt.view.catalog;

import std.conv;
import std.string : toUpper;

import gtk.adjustment;
import gtk.box;
import gtk.gesture_click;
import gtk.scrolled_window;
import gtk.types : Orientation, Overflow, PolicyType;
import gtk.widget : Widget;

import mutagen.catalog : Artist, Album, Track;
import turnt.widget.card : CardWidget;
import turnt.widget.vinyl : Vinyl;

enum BrowseView
{
    Artists,
    Albums,
    Tracks
}

class CatalogView : Box
{
public:
    BrowseView currentView = BrowseView.Artists;
    ScrolledWindow scrolled;
    Box contentBox;
    enum cardWidth = 372;

private:
    Vinyl[] vinyls;
    string stickyArtist;
    string stickyAlbum;
    void delegate(int) lazyMakeCard;
    int lazyTotal;
    int lazyCount;
    double lazyCardHeight = 74;

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
    }

    void display(Vinyl[] vs)
    {
        vinyls = vs;
        showArtists();
    }

    void showArtists()
    {
        currentView = BrowseView.Artists;
        stickyArtist = "";
        stickyAlbum = "";
        clearBox(contentBox);

        Vinyl[] artistVinyls;
        foreach (v; vinyls)
        {
            if (v.isArtist)
                artistVinyls ~= v;
        }

        setupLazy(cast(int)artistVinyls.length, 82, cast(int)(artistVinyls.length * 82));

        lazyMakeCard = (int idx) {
            Vinyl v = artistVinyls[idx];
            int albumCount = cast(int)v.artist.albums.length;
            string detail = albumCount.to!string~" album"~(albumCount != 1 ? "s" : "");
            CardWidget card = new CardWidget(v, v.name.toUpper(), detail, v.artist.getPlayCount());

            GestureClick click = new GestureClick();
            click.connectReleased(((Vinyl vv) => delegate(int n, double x, double y) {
                if (n == 1 && x > 70)
                    showAlbums(vv.artist);
            })(v));
            card.overlay.addController(click);
            
            import gtk.drag_source : DragSource;
            import gdk.content_provider : ContentProvider;
            DragSource drag = new DragSource();
            drag.connectPrepare(((Vinyl vv) => delegate ContentProvider(double x, double y) {
                return ContentProvider.newForValue(vv.name);
            })(v));
            card.overlay.addController(drag);
            
            contentBox.append(card);
        };

        ensureCards();
    }

    void showAlbums(Artist artist)
    {
        currentView = BrowseView.Albums;
        stickyArtist = artist.name;
        stickyAlbum = "";
        clearBox(contentBox);

        Vinyl artistVinyl = new Vinyl(artist);
        string aDetail = artist.albums.length.to!string~" album"~(artist.albums.length != 1 ? "s" : "");
        CardWidget sticky = new CardWidget(artistVinyl, artist.name.toUpper(), aDetail, artist.getPlayCount());
        makeStickyCard(sticky, &showArtists);
        contentBox.append(sticky);

        Album[] albums = artist.albums;
        setupLazy(cast(int)albums.length, 74, cast(int)(albums.length * 74));

        lazyMakeCard = (int idx) {
            Album album = albums[idx];
            Vinyl vinyl = new Vinyl(album);
            
            string artistsStr = "";
            foreach (i, a; album.artists)
            {
                if (i > 0) artistsStr ~= ", ";
                artistsStr ~= a.name;
            }
            
            CardWidget card = new CardWidget(vinyl, album.name.toUpper(), artistsStr.toUpper(), album.getPlayCount());

            GestureClick click = new GestureClick();
            click.connectReleased(((Album a, Artist ar) => delegate(int n, double x, double y) {
                if (n == 1 && x > 70)
                    showTracks(ar, a);
            })(album, artist));
            card.overlay.addController(click);

            import gtk.drag_source : DragSource;
            import gdk.content_provider : ContentProvider;
            DragSource drag = new DragSource();
            drag.connectPrepare(((Vinyl vv) => delegate ContentProvider(double x, double y) {
                return ContentProvider.newForValue(vv.name);
            })(vinyl));
            card.overlay.addController(drag);

            contentBox.append(card);
        };

        ensureCards();
    }

    void showTracks(Artist artist, Album album)
    {
        currentView = BrowseView.Tracks;
        stickyAlbum = album.name;
        clearBox(contentBox);

        Vinyl artistVinyl = new Vinyl(artist);
        string aDetail = artist.albums.length.to!string~" album"~(artist.albums.length != 1 ? "s" : "");
        CardWidget artistCard = new CardWidget(artistVinyl, artist.name.toUpper(), aDetail, artist.getPlayCount());
        makeStickyCard(artistCard, delegate void() { showAlbums(artist); });
        contentBox.append(artistCard);

        Vinyl albumVinyl = new Vinyl(album);
        string artistsStr = "";
        foreach (i, a; album.artists)
        {
            if (i > 0) artistsStr ~= ", ";
            artistsStr ~= a.name;
        }
        
        CardWidget albumCard = new CardWidget(
            albumVinyl, album.name.toUpper(), artistsStr.toUpper(), album.getPlayCount());
        makeStickyCard(albumCard, delegate void() { showAlbums(artist); });
        contentBox.append(albumCard);

        Track[] tracks = album.tracks;
        setupLazy(cast(int)tracks.length, 56, cast(int)(tracks.length * 56));

        lazyMakeCard = (int idx) {
            Track track = tracks[idx];
            Vinyl vinyl = new Vinyl(track);
            string title = track.number.to!string~". "~track.name.toUpper();
            CardWidget card = new CardWidget(vinyl, title, "", track.getPlayCount(), 1, 1, "track-name");
            contentBox.append(card);
        };

        ensureCards();
    }

private:
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

    void ensureCards()
    {
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

    static void makeStickyCard(CardWidget card, void delegate() onClick)
    {
        card.removeCssClass("card");
        card.addCssClass("card-sticky");
        GestureClick click = new GestureClick();
        click.connectReleased(delegate(int, double, double) {
            onClick();
        });
        card.overlay.addController(click);
    }
}

private void clearBox(Box box)
{
    Widget child = box.getFirstChild();
    while (child !is null)
    {
        Widget next = child.getNextSibling();
        box.remove(child);
        child = next;
    }
}