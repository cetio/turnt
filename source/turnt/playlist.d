module turnt.playlist;

import std.conv : to;
import std.file : SpanMode;
import std.path : buildPath;
import std.stdio : writeln;
import std.string : indexOf, toUpper;

import cairo.context;
import cairo.types : LineCap;
import gdk.content_provider;
import gdk.drag;
import gdk.types : DragAction;
import gobject.types : GType, GTypeEnum;
import gobject.value;
import gtk.box;
import gtk.drag_source;
import gtk.drawing_area;
import gtk.drop_target;
import gtk.editable;
import gtk.entry;
import gtk.gesture_click;
import gtk.label;
import gtk.overlay;
import gtk.types : Align, Orientation;
import gtk.widget;

import mutagen.catalogue : musicDir, collectAudio, findAlbums;
import turnt.catalogue.card : CardWidget;
import turnt.vinyl : Vinyl, drawVinylFolder;
import turnt.window;

struct PlaylistInfo
{
    string name;
    double r = 0.35, g = 0.35, b = 0.45;
    string[] entries;

    int albumCount()
    {
        int ret = 0;
        foreach (ref e; entries)
        {
            if (indexOf(e, '|') >= 0)
                ret++;
        }
        return ret;
    }

    int trackCount()
    {
        int ret = 0;
        foreach (ref e; entries)
        {
            ptrdiff_t sep = indexOf(e, '|');
            if (sep >= 0 && indexOf(e[sep + 1 .. $], '|') >= 0)
                ret++;
        }
        return ret;
    }
}

string[] collectPlaylistTracks(ref PlaylistInfo pl)
{
    string[] tracks;
    foreach (ref entry; pl.entries)
    {
        ptrdiff_t sep = indexOf(entry, '|');
        if (sep < 0)
        {
            tracks ~= collectAudio(buildPath(musicDir, entry));
            continue;
        }
        string artist = entry[0 .. sep];
        string rest = entry[sep + 1 .. $];
        ptrdiff_t sep2 = indexOf(rest, '|');
        if (sep2 < 0)
            tracks ~= collectAudio(buildPath(musicDir, artist, rest), SpanMode.shallow);
        else
            tracks ~= rest[sep2 + 1 .. $];
    }
    return tracks;
}

struct PlaylistState
{
    PlaylistInfo[] playlists;
    int count;
    bool editing;
    string[] pendingEntries;
    double folderR = 0.35, folderG = 0.35, folderB = 0.45;
    DrawingArea folderDa;
    Label dropHint;
}

Overlay makePlaylistCard(ref PlaylistInfo pl, int idx, void delegate(int) onSelect)
{
    Box row = new Box(Orientation.Horizontal, 8);
    row.addCssClass("card");
    row.marginStart = 4;
    row.marginEnd = 4;
    row.marginTop = 2;
    row.marginBottom = 2;

    DrawingArea plDa = new DrawingArea();
    plDa.contentWidth = 52;
    plDa.contentHeight = 62;
    plDa.halign = Align.Center;
    plDa.valign = Align.Center;
    double pr = pl.r, pg = pl.g, pb = pl.b;
    plDa.setDrawFunc(delegate(DrawingArea, Context cr, int w, int h) {
        drawVinylFolder(cr, w, h, pr, pg, pb, false);
    });
    row.append(plDa);

    Box info = new Box(Orientation.Vertical, 1);
    info.valign = Align.Center;
    info.hexpand = true;

    Label name = new Label(pl.name);
    name.addCssClass("card-name");
    name.halign = Align.Start;
    name.xalign = 0;
    info.append(name);

    int nAlb = pl.albumCount();
    int nTrk = pl.trackCount();
    string detail = nAlb.to!string~" album"~(nAlb != 1 ? "s" : "")
        ~", "~nTrk.to!string~" track"~(nTrk != 1 ? "s" : "");
    Label countLabel = new Label(detail);
    countLabel.addCssClass("count-label");
    countLabel.halign = Align.Start;
    countLabel.xalign = 0;
    info.append(countLabel);

    row.append(info);

    GestureClick click = new GestureClick();
    click.connectReleased(((i) => delegate(int, double, double) {
        onSelect(i);
    })(idx));
    row.addController(click);

    DragSource drag = new DragSource();
    drag.actions = DragAction.Copy;
    drag.connectPrepare(((string pn) => delegate ContentProvider(double, double) {
        return ContentProvider.newForValue(new Value("playlist|"~pn));
    })(pl.name));
    row.addController(drag);

    Overlay wrapper = new Overlay();
    wrapper.setChild(row);
    return wrapper;
}

struct PlaylistWidgets
{
    Box topRow;
    Label dropHint;
}

PlaylistWidgets buildPlaylistEditRow(
    PlaylistState* state,
    Box contentBox,
    void delegate() onShowArtists,
    void delegate() onSearchVisibility
)
{
    Box topRow = new Box(Orientation.Horizontal, 6);
    topRow.addCssClass("card");
    topRow.marginStart = 4;
    topRow.marginEnd = 4;
    topRow.marginTop = 2;
    topRow.marginBottom = 2;
    topRow.heightRequest = 84;

    state.folderDa = new DrawingArea();
    state.folderDa.contentWidth = 70;
    state.folderDa.contentHeight = 70;
    state.folderDa.halign = Align.Center;
    state.folderDa.valign = Align.Center;
    state.folderDa.setDrawFunc(delegate(DrawingArea, Context cr, int w, int h) {
        if (!state.editing)
        {
            cr.setSourceRgb(0.53, 0.53, 0.53);
            cr.setLineWidth(2.5);
            cr.setLineCap(LineCap.Round);
            double cx = w / 2.0;
            double cy = h / 2.0;
            double sz = 14;
            cr.moveTo(cx - sz, cy);
            cr.lineTo(cx + sz, cy);
            cr.stroke();
            cr.moveTo(cx, cy - sz);
            cr.lineTo(cx, cy + sz);
            cr.stroke();
        }
        else
        {
            drawVinylFolder(cr, w, h, state.folderR, state.folderG, state.folderB, true);
        }
    });

    Entry playlistEntry = new Entry();
    playlistEntry.addCssClass("add-artist-entry");
    playlistEntry.setPlaceholderText("Playlist name...");
    playlistEntry.hexpand = true;
    playlistEntry.valign = Align.Center;
    playlistEntry.visible = false;

    state.dropHint = new Label("Drag artists or albums here");
    state.dropHint.addCssClass("drop-hint");
    state.dropHint.halign = Align.Center;
    state.dropHint.valign = Align.Center;
    state.dropHint.visible = false;

    GestureClick addClick = new GestureClick();
    addClick.connectReleased(delegate(int, double, double) {
        if (!state.editing)
        {
            state.editing = true;
            state.pendingEntries.length = 0;
            playlistEntry.visible = true;
            state.folderDa.queueDraw();
            playlistEntry.grabFocus();

            Widget ch = contentBox.getFirstChild();
            while (ch !is null)
            {
                ch.visible = false;
                ch = ch.getNextSibling();
            }
            topRow.visible = true;
            state.dropHint.visible = true;
            onSearchVisibility();

            window.turntableStack.setVisibleChildName("empty");
            window.rightCatalogue.showArtists();
        }
        else
        {
            if (state.pendingEntries.length == 0)
            {
                writeln("[playlist] No entries, cancelling");
                state.editing = false;
                window.turntableStack.setVisibleChildName("turntable");
                onShowArtists();
                return;
            }

            Editable editable = cast(Editable)playlistEntry;
            string pname = editable !is null ? editable.getText() : "";
            if (pname.length == 0)
            {
                state.count++;
                pname = "Playlist "~state.count.to!string;
            }

            PlaylistInfo pl;
            pl.name = pname;
            pl.r = state.folderR;
            pl.g = state.folderG;
            pl.b = state.folderB;
            pl.entries = state.pendingEntries.dup;
            state.playlists ~= pl;
            writeln("[playlist] Created: "~pname~" ("~pl.entries.length.to!string~" items)");

            state.editing = false;
            state.pendingEntries.length = 0;
            window.turntableStack.setVisibleChildName("turntable");
            onShowArtists();
        }
    });
    state.folderDa.addController(addClick);

    topRow.append(state.folderDa);
    topRow.append(playlistEntry);

    PlaylistWidgets ret;
    ret.topRow = topRow;
    ret.dropHint = state.dropHint;
    return ret;
}

void attachPlaylistDrop(PlaylistState* state, Widget target, Box contentBox)
{
    DropTarget playlistDrop = new DropTarget(cast(GType)GTypeEnum.String, DragAction.Copy);
    playlistDrop.connectDrop(delegate bool(Value val, double, double) {
        if (!state.editing)
            return false;
        string payload = val.getString();
        if (payload.length == 0)
            return false;

        if (state.dropHint !is null)
            state.dropHint.visible = false;

        ptrdiff_t sep = indexOf(payload, '|');
        if (sep < 0)
        {
            string artistDir = buildPath(musicDir, payload);
            string[] albums = findAlbums(artistDir);
            foreach (album; albums)
            {
                string entry = payload~"|"~album;
                state.pendingEntries ~= entry;
                addDroppedCard(entry, contentBox);
            }
            writeln("[playlist] Decomposed artist '"~payload~"' into "
                ~albums.length.to!string~" albums");
        }
        else
        {
            state.pendingEntries ~= payload;
            addDroppedCard(payload, contentBox);
            writeln("[playlist] Added: "~payload
                ~" ("~state.pendingEntries.length.to!string~" total)");
        }
        return true;
    });
    target.addController(playlistDrop);
}

private void addDroppedCard(string payload, Box contentBox)
{
    ptrdiff_t sep = indexOf(payload, '|');
    string displayName;
    string coverDir;
    string artist;
    string album;
    if (sep < 0)
    {
        displayName = payload;
        artist = payload;
        coverDir = buildPath(musicDir, payload);
    }
    else
    {
        artist = payload[0 .. sep];
        string rest = payload[sep + 1 .. $];
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

    int tc = cast(int)collectAudio(coverDir, SpanMode.shallow).length;
    Vinyl v = new Vinyl(displayName, coverDir, 50, artist, album);
    v.trackNum = tc;
    string detail = tc.to!string~" track"~(tc != 1 ? "s" : "");
    CardWidget card = new CardWidget(v, displayName.toUpper(), detail);
    contentBox.append(card);
}
