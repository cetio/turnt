module turnt.catalogue.browse;

import std.conv : to;
import std.path : buildPath;
import std.string : indexOf, toUpper;

import cairo.context : Context;
import gtk.box;
import gtk.drawing_area : DrawingArea;
import gtk.gesture_click;
import gtk.label : Label;
import gtk.types : Align, Orientation;

import turnt.catalogue.card : CardWidget;
import turnt.catalogue.view : CatalogueView, BrowseView, clearBox;
import turnt.playlist;
import turnt.vinyl : Vinyl, drawVinylFolder;
import turnt.window;

import mutagen.catalogue : Artist, Album, Track, musicDir;

void showArtists(CatalogueView cv)
{
    cv.currentView = BrowseView.Artists;
    cv.stickyArtist = "";
    cv.stickyAlbum = "";
    clearBox(cv.contentBox);

    if (!cv.isRightPanel)
    {
        if (cv.searchWidget !is null)
            cv.searchWidget.visible = !cv.playlist.editing;

        foreach (idx, ref pl; cv.playlist.playlists)
            cv.contentBox.append(makePlaylistCard(pl, cast(int)idx, &cv.showPlaylist));

        PlaylistWidgets pw = buildPlaylistEditRow(
            &cv.playlist, cv.contentBox, &cv.showArtists,
            delegate void() {
                if (cv.searchWidget !is null)
                    cv.searchWidget.visible = false;
            });
        cv.contentBox.append(pw.topRow);
        cv.contentBox.append(pw.dropHint);

        if (!cv.playlistDropAttached)
        {
            attachPlaylistDrop(&cv.playlist, cv, cv.contentBox);
            cv.playlistDropAttached = true;
        }
    }

    if (cv.playlist.editing)
    {
        cv.resetLazy();
        return;
    }

    cv.rebuildFiltered();
    int extra = cv.isRightPanel ? 0 : cast(int)(cv.playlist.playlists.length + 1);
    cv.setupLazy(cast(int)cv.filteredCache.length, 82,
        cast(int)((cv.filteredCache.length + extra) * 82));

    cv.lazyMakeCard = (int idx) {
        Artist ai = cv.filteredCache[idx];
        Vinyl v = cv.getOrCreateArtistVinyl(ai);
        string detail = ai.albums.length.to!string~" album"~(ai.albums.length != 1 ? "s" : "");
        CardWidget card = new CardWidget(v, v.name.toUpper(), detail, ai.getPlayCount());
        card.attachSplay(cv.cardWidth);

        GestureClick click = new GestureClick();
        click.connectReleased(((a) => delegate(int n, double x, double y) {
            if (cv.dragged)
                return;
            if (n == 1 && x > 70)
                cv.showAlbums(a);
        })(ai.name));
        card.overlay.addController(click);
        cv.contentBox.append(card);
    };

    cv.ensureCards();
}

void showAlbums(CatalogueView cv, string artist)
{
    cv.currentView = BrowseView.Albums;
    cv.stickyArtist = artist;
    cv.stickyAlbum = "";
    clearBox(cv.contentBox);

    Artist ai = cv.findArtist(artist);
    if (ai is null)
        return;

    Vinyl av = cv.getOrCreateArtistVinyl(ai);
    string aDetail = ai.albums.length.to!string~" album"~(ai.albums.length != 1 ? "s" : "");
    CardWidget sticky = new CardWidget(av, av.name.toUpper(), aDetail, ai.getPlayCount());
    makeStickyCard(sticky, &cv.showArtists);
    cv.contentBox.append(sticky);

    Album[] albums = ai.albums;
    cv.setupLazy(cast(int)albums.length, 74, cast(int)(albums.length * 74));

    cv.lazyMakeCard = (int idx) {
        Album alb = albums[idx];
        int tc = cast(int)alb.tracks.length;
        Vinyl v = cv.getOrCreateAlbumVinyl(artist, alb.name, alb.dir, tc);
        string detail = tc.to!string~" track"~(tc != 1 ? "s" : "");
        CardWidget card = new CardWidget(v, v.name.toUpper(), detail, alb.getPlayCount());
        card.attachSplay(cv.cardWidth);

        GestureClick click = new GestureClick();
        click.connectReleased(((a, ar) => delegate(int n, double x, double y) {
            if (cv.dragged)
                return;
            if (n == 1 && x > 70)
                cv.showTracks(ar, a);
        })(alb.name, artist));
        card.overlay.addController(click);
        cv.contentBox.append(card);
    };

    cv.ensureCards();
}

void showTracks(CatalogueView cv, string artist, string album)
{
    cv.currentView = BrowseView.Tracks;
    cv.stickyAlbum = album;
    clearBox(cv.contentBox);

    Artist ai = cv.findArtist(artist);
    if (ai is null)
        return;

    // Artist sticky
    Vinyl av = cv.getOrCreateArtistVinyl(ai);
    string aDetail = ai.albums.length.to!string~" album"~(ai.albums.length != 1 ? "s" : "");
    CardWidget artistCard = new CardWidget(av, av.name.toUpper(), aDetail, ai.getPlayCount());
    makeStickyCard(artistCard, delegate void() { cv.showAlbums(artist); });
    cv.contentBox.append(artistCard);

    // Find album
    Album albInfo;
    foreach (alb; ai.albums)
    {
        if (alb.name == album)
        {
            albInfo = alb;
            break;
        }
    }
    string albumDir = albInfo !is null ? albInfo.dir : buildPath(ai.dir, album);
    int tc = albInfo !is null ? cast(int)albInfo.tracks.length : 0;
    int albumPlays = albInfo !is null ? albInfo.getPlayCount() : 0;

    // Album sticky
    Vinyl albumV = cv.getOrCreateAlbumVinyl(artist, album, albumDir, tc);
    string albDetail = tc.to!string~" track"~(tc != 1 ? "s" : "");
    CardWidget albumCard = new CardWidget(albumV, albumV.name.toUpper(), albDetail, albumPlays);
    makeStickyCard(albumCard, delegate void() { cv.showAlbums(artist); });
    cv.contentBox.append(albumCard);

    // Tracks
    Track[] trackInfos = albInfo !is null ? albInfo.tracks : [];
    cv.setupLazy(cast(int)trackInfos.length, 56, cast(int)(trackInfos.length * 56));

    cv.lazyMakeCard = (int idx) {
        Track ti = trackInfos[idx];
        Vinyl v = cv.getOrCreateTrackVinyl(artist, album, albumDir, ti.name, ti.file);
        v.trackNum = ti.trackNum;
        string title = ti.trackNum.to!string~". "~ti.name.toUpper();
        CardWidget card = new CardWidget(v, title, "", ti.getPlayCount(), 1, 1, "track-name");

        GestureClick click = new GestureClick();
        click.connectReleased(((vi, t, ar, al) => delegate(int, double, double) {
            if (cv.dragged)
                return;
            window.turntable.loadTrack(vi, ar, al, t);
        })(v, ti.file, artist, album));
        card.overlay.addController(click);
        cv.contentBox.append(card);
    };

    cv.ensureCards();
}

void showPlaylist(CatalogueView cv, int idx)
{
    if (idx < 0 || idx >= cast(int)cv.playlist.playlists.length)
        return;
    PlaylistInfo* pl = &cv.playlist.playlists[idx];
    cv.currentView = BrowseView.Artists;
    cv.stickyArtist = "";
    cv.stickyAlbum = "";
    clearBox(cv.contentBox);

    // Playlist header
    DrawingArea plDa = new DrawingArea();
    plDa.contentWidth = 58;
    plDa.contentHeight = 68;
    plDa.halign = Align.Center;
    plDa.valign = Align.Center;
    double pr = pl.r, pg = pl.g, pb = pl.b;
    plDa.setDrawFunc(delegate(DrawingArea, Context cr, int w, int h) {
        drawVinylFolder(cr, w, h, pr, pg, pb, false);
    });

    Box headerRow = new Box(Orientation.Horizontal, 8);
    headerRow.addCssClass("card-sticky");
    headerRow.marginStart = 4;
    headerRow.marginEnd = 4;
    headerRow.marginTop = 2;
    headerRow.marginBottom = 2;
    headerRow.append(plDa);

    Box headerInfo = new Box(Orientation.Vertical, 1);
    headerInfo.valign = Align.Center;
    headerInfo.hexpand = true;

    Label headerName = new Label(pl.name);
    headerName.addCssClass("card-name");
    headerName.halign = Align.Start;
    headerName.xalign = 0;
    headerInfo.append(headerName);

    int nAlb = pl.albumCount();
    string hDetail = nAlb.to!string~" album"~(nAlb != 1 ? "s" : "");
    Label headerCount = new Label(hDetail);
    headerCount.addCssClass("count-label");
    headerCount.halign = Align.Start;
    headerCount.xalign = 0;
    headerInfo.append(headerCount);
    headerRow.append(headerInfo);

    GestureClick navClick = new GestureClick();
    navClick.connectReleased(delegate(int, double, double) {
        cv.showArtists();
    });
    headerRow.addController(navClick);
    cv.contentBox.append(headerRow);

    // Entry cards
    string[] entries = pl.entries;
    cv.setupLazy(cast(int)entries.length, 74, cast(int)(entries.length * 74));

    cv.lazyMakeCard = (int i) {
        string entry = entries[i];
        ptrdiff_t sep = indexOf(entry, '|');
        string artist, album, coverDir, displayName;
        if (sep < 0)
        {
            artist = entry;
            displayName = entry;
            Artist ai = cv.findArtist(entry);
            coverDir = ai is null ? "" : ai.coverDir;
        }
        else
        {
            artist = entry[0 .. sep];
            string rest = entry[sep + 1 .. $];
            ptrdiff_t sep2 = indexOf(rest, '|');
            if (sep2 < 0)
            {
                album = rest;
                displayName = rest;
                coverDir = buildPath(musicDir, artist, rest);
            }
            else
            {
                album = rest[0 .. sep2];
                displayName = album;
                coverDir = buildPath(musicDir, artist, album);
            }
        }

        Vinyl v = new Vinyl(displayName, coverDir, 50, artist, album);
        string detail = artist.toUpper();
        CardWidget card = new CardWidget(v, displayName.toUpper(), detail);
        cv.contentBox.append(card);
    };

    cv.ensureCards();
}

private void makeStickyCard(CardWidget card, void delegate() onClick)
{
    card.removeCssClass("card");
    card.addCssClass("card-sticky");
    GestureClick click = new GestureClick();
    click.connectReleased(delegate(int, double, double) {
        onClick();
    });
    card.overlay.addController(click);
}
