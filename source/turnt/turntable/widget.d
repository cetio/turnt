module turnt.turntable.widget;

import std.math : abs;
import std.string : indexOf, lastIndexOf, toUpper;
import std.path : buildPath, baseName, dirName;
import std.file : SpanMode;

import cairo.context;
import cairo.surface;
import glib.global : timeoutAdd;
import gobject.value;
import gobject.types;
import gdk.types;
import gtk.drawing_area;
import gtk.drop_target;
import gtk.gesture_click;
import gtk.types : Align, Overflow;

import turnt.vinyl : Vinyl, drawVinylDisc, pixbufToSurface;
import turnt.turntable.render : drawPlatter, drawTonearm, drawTurntableLabels, findLatestAlbumDir;
import mutagen.parser.scanner : musicDir, collectAudio, findAlbums, findCoverArt;
import turnt.playlist : PlaylistInfo, collectPlaylistTracks;
import turnt.queue;
import turnt.window;
import cairo.surface : Surface = Surface;
import gdkpixbuf.pixbuf : Pixbuf;

class TurntableWidget : DrawingArea
{
private:
    double vinylAngle = 0.0;
    double tonearmAngle = -30.0;
    double targetTonearmAngle = -30.0;
    string displayArtist;
    string displayAlbum;
    string displayTrack;
    bool hasVinyl = false;
    string lastFile;
    string lastAlbumDir;
    uint vinylHue = 0;
    Surface coverSurface;
    int coverW, coverH;
    int displayTrackNum = 0;

    double vinylScale = 0.0;
    double targetVinylScale = 1.0;
    bool animatingDrop = false;

    bool liftingOff = false;
    double targetLiftAngle = -60.0;

    void drawScene(DrawingArea, Context cr, int w, int h)
    {
        import std.math : fmin, PI;
        double cx = w / 2.0;
        double cy = h / 2.0 + 20;
        double platterR = fmin(cast(double)w, cast(double)h) * 0.40;

        cr.setSourceRgb(0.078, 0.078, 0.078);
        cr.rectangle(0, 0, w, h);
        cr.fill();

        drawPlatter(cr, cx, cy, platterR);

        if (hasVinyl)
            drawVinylDisc(cr, cx, cy, platterR * 0.92 * vinylScale, vinylAngle, vinylHue,
                coverSurface, coverW, coverH, displayTrackNum);

        cr.setSourceRgb(0.6, 0.6, 0.6);
        cr.arc(cx, cy, 4, 0, PI * 2);
        cr.fill();

        drawTonearm(cr, cx, cy, platterR, tonearmAngle);
        drawTurntableLabels(cr, cx, cy, platterR, displayArtist, displayAlbum, displayTrack);
    }

    void updateLabelsFromFile(string filePath)
    {
        if (filePath.length == 0)
            return;
        string albumDir = dirName(filePath);
        string artistDir = dirName(albumDir);
        string artist = baseName(artistDir);
        string album = baseName(albumDir);
        string trackName = baseName(filePath);
        ptrdiff_t dot = lastIndexOf(trackName, '.');
        if (dot > 0)
            trackName = trackName[0..dot];
        ptrdiff_t dash = indexOf(trackName, " - ");
        if (dash >= 0)
            trackName = trackName[dash + 3..$];

        displayArtist = artist.toUpper();
        displayAlbum = album.toUpper();
        displayTrack = trackName.toUpper();
        vinylHue = hashOf(artist) & 0xFF;

        if (albumDir != lastAlbumDir)
        {
            lastAlbumDir = albumDir;
            coverSurface = null;
            coverW = 0;
            coverH = 0;
            string artPath = findCoverArt(albumDir);
            if (artPath.length > 0)
            {
                try
                {
                    Pixbuf pb = Pixbuf.newFromFileAtScale(artPath, 200, 200, true);
                    if (pb !is null)
                    {
                        coverSurface = pixbufToSurface(pb);
                        coverW = 200;
                        coverH = 200;
                    }
                }
                catch (Exception) { }
            }
        }
    }

    bool onTick()
    {
        if (window is null)
        {
            queueDraw();
            return true;
        }

        if (liftingOff)
        {
            tonearmAngle += (targetLiftAngle - tonearmAngle) * 0.06;
            vinylScale += (0.0 - vinylScale) * 0.05;
            if (abs(tonearmAngle - targetLiftAngle) < 0.5 && vinylScale < 0.02)
            {
                liftingOff = false;
                hasVinyl = false;
                vinylScale = 0.0;
                tonearmAngle = targetLiftAngle;
                targetTonearmAngle = -30.0;
                displayArtist = "";
                displayAlbum = "";
                displayTrack = "";
                displayTrackNum = 0;
                lastFile = "";
            }
        }
        else
        {
            tonearmAngle += (targetTonearmAngle - tonearmAngle) * 0.08;
            if (hasVinyl)
            {
                if (window.queue.playing)
                    vinylAngle += 0.02;
                string curFile = window.queue.file;
                if (curFile.length > 0 && curFile != lastFile)
                {
                    lastFile = curFile;
                    updateLabelsFromFile(curFile);
                }
            }
        }

        if (animatingDrop)
        {
            vinylScale += (targetVinylScale - vinylScale) * 0.12;
            if (abs(vinylScale - targetVinylScale) < 0.005)
            {
                vinylScale = targetVinylScale;
                animatingDrop = false;
            }
        }

        queueDraw();
        return true;
    }

    bool onDrop(Value val, double, double)
    {
        string raw = val.getString();
        if (raw.length == 0)
            return true;

        // Playlist drop: "playlist|name"
        if (raw.length > 9 && raw[0 .. 9] == "playlist|")
        {
            string plName = raw[9 .. $];
            loadPlaylist(plName);
            return true;
        }

        ptrdiff_t sep1 = indexOf(raw, '|');
        if (sep1 < 0)
        {
            loadArtist(null, raw);
            if (window.catalogue !is null)
                window.catalogue.showAlbums(raw);
            return true;
        }

        string artist = raw[0 .. sep1];
        string rest = raw[sep1 + 1 .. $];
        ptrdiff_t sep2 = indexOf(rest, '|');
        if (sep2 < 0)
        {
            loadAlbum(null, artist, rest);
            if (window.catalogue !is null)
                window.catalogue.showTracks(artist, rest);
        }
        else
        {
            string album = rest[0 .. sep2];
            loadTrack(null, artist, album, rest[sep2 + 1 .. $]);
            if (window.catalogue !is null)
                window.catalogue.showTracks(artist, album);
        }
        return true;
    }

public:
    Vinyl vinyl;

    this()
    {
        contentWidth = 500;
        contentHeight = 600;
        hexpand = true;
        vexpand = true;
        overflow = Overflow.Visible;

        setDrawFunc(&drawScene);

        DropTarget drop = new DropTarget(cast(GType)GTypeEnum.String, DragAction.Copy);
        drop.connectDrop(&onDrop);
        addController(drop);

        GestureClick click = new GestureClick();
        click.connectPressed(&onClicked);
        addController(click);

        timeoutAdd(0, 16, &onTick);
    }

    void onClicked(int, double x, double y)
    {
        import std.math : fmin;
        if (!hasVinyl || liftingOff)
            return;

        int w = contentWidth;
        int h = contentHeight;
        double cx = w / 2.0;
        double cy = h / 2.0 + 20;
        double platterR = fmin(cast(double)w, cast(double)h) * 0.40;

        double dx = x - cx;
        double dy = y - cy;
        double dist = dx * dx + dy * dy;
        double vinylR = platterR * 0.92 * vinylScale;

        double pivotX = cx + platterR + 50;
        double pivotY = cy - platterR - 10;
        double armDx = x - pivotX;
        double armDy = y - pivotY;
        double armDist = armDx * armDx + armDy * armDy;

        if (dist < vinylR * vinylR || armDist < (platterR * 1.5) * (platterR * 1.5) * 0.15)
            liftOff();
    }

    void liftOff()
    {
        window.queue.stop();
        vinyl = null;
        liftingOff = true;
        targetLiftAngle = -60.0;
        queueDraw();
    }

    void showVinyl(Vinyl v, string artist, string album, string track, string coverDir, int trackNum = 0)
    {
        vinyl = v;
        liftingOff = false;
        lastFile = "";
        displayArtist = artist.length > 0 ? artist.toUpper() : "";
        displayAlbum = album.length > 0 ? album.toUpper() : "";
        displayTrack = track.length > 0 ? track.toUpper() : "";
        vinylHue = hashOf(artist.length > 0 ? artist : album) & 0xFF;
        displayTrackNum = trackNum > 0 ? trackNum : (v !is null ? v.trackNum : 0);
        hasVinyl = true;
        vinylScale = 0.3;
        targetVinylScale = 1.0;
        animatingDrop = true;
        targetTonearmAngle = 5.0;

        coverSurface = null;
        coverW = 0;
        coverH = 0;
        if (coverDir.length > 0)
        {
            string artPath = findCoverArt(coverDir);
            if (artPath.length > 0)
            {
                try
                {
                    Pixbuf pb = Pixbuf.newFromFileAtScale(artPath, 200, 200, true);
                    if (pb !is null)
                    {
                        coverSurface = pixbufToSurface(pb);
                        coverW = 200;
                        coverH = 200;
                    }
                }
                catch (Exception) {}
            }
        }
        queueDraw();
    }

    void loadPlaylist(string plName)
    {
        foreach (ref pl; window.catalogue.playlist.playlists)
        {
            if (pl.name == plName)
            {
                string[] tracks = collectPlaylistTracks(pl);
                if (tracks.length == 0)
                    return;
                showVinyl(null, plName, "", "", "", cast(int)tracks.length);
                window.queue.playQueue(tracks, plName);
                window.queue.playlistName = plName;
                return;
            }
        }
    }

    void loadArtist(Vinyl v, string artistName)
    {
        string artistDir = buildPath(musicDir, artistName);
        string coverDir = findLatestAlbumDir(artistDir);
        int numAlbums = cast(int)findAlbums(artistDir).length;
        showVinyl(v, artistName, "", "", coverDir, numAlbums);
        string[] tracks = collectAudio(artistDir);
        window.queue.playQueue(tracks, artistName);
    }

    void loadAlbum(Vinyl v, string artistName, string album)
    {
        string albumDir = buildPath(musicDir, artistName, album);
        string[] tracks = collectAudio(albumDir, SpanMode.shallow);
        showVinyl(v, artistName, album, "", albumDir, cast(int)tracks.length);
        window.queue.playQueue(tracks, artistName);
    }

    void loadTrack(Vinyl v, string artistName, string album, string trackPath)
    {
        string albumDir = buildPath(musicDir, artistName, album);
        string trackName = baseName(trackPath);
        ptrdiff_t dot = lastIndexOf(trackName, '.');
        if (dot > 0)
            trackName = trackName[0 .. dot];

        ptrdiff_t dash = indexOf(trackName, " - ");
        if (dash >= 0)
            trackName = trackName[dash + 3 .. $];

        string[] tracks = collectAudio(albumDir, SpanMode.shallow);
        int startIdx = 0;
        foreach (i, t; tracks)
        {
            if (t == trackPath)
            {
                startIdx = cast(int)i;
                break;
            }
        }
        showVinyl(v, artistName, album, trackName, albumDir, startIdx + 1);
        window.queue.playQueue(tracks, artistName, startIdx);
    }
}
