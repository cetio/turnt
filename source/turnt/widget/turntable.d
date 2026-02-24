module turnt.widget.turntable;

import std.math;
import std.string : toUpper;
import std.conv;

import cairo.context;
import cairo.pattern;
import cairo.types : FontSlant, FontWeight;
import glib.global : timeoutAdd;
import gobject.value;
import gobject.types;
import gdk.types : DragAction;
import gtk.drawing_area;
import gtk.drop_target;
import gtk.gesture_click;
import gtk.types : Align, Overflow;

import mutagen.catalog : Artist, Album, Track;
import turnt.widget.vinyl : Vinyl;
import turnt.window : window;

class TurntableWidget : DrawingArea
{
private:
    double vinylAngle = 0.0;
    double tonearmAngle = -30.0;
    double targetTonearmAngle = -30.0;
    
    bool hasVinyl = false;
    Vinyl vinyl;
    Vinyl largeVinyl;
    
    double vinylScale = 0.0;
    double targetVinylScale = 1.0;
    bool animatingDrop = false;

    bool liftingOff = false;
    double targetLiftAngle = -60.0;

    void drawPlatter(Context cr, double cx, double cy, double radius)
    {
        cr.save();
        cr.translate(cx, cy);

        // Shadow
        cr.setSourceRgba(0, 0, 0, 0.4);
        cr.arc(4, 6, radius + 2, 0, PI * 2);
        cr.fill();

        // Edge
        cr.setSourceRgb(0.18, 0.18, 0.18);
        cr.arc(0, 0, radius, 0, PI * 2);
        cr.fill();

        // Top surface
        cr.setSourceRgb(0.08, 0.08, 0.08);
        cr.arc(0, 0, radius * 0.98, 0, PI * 2);
        cr.fill();

        // Rings
        for (double r = radius * 0.3; r < radius * 0.95; r += 4)
        {
            cr.setSourceRgba(0.12, 0.12, 0.12, 0.5);
            cr.setLineWidth(0.5);
            cr.arc(0, 0, r, 0, PI * 2);
            cr.stroke();
        }

        cr.restore();
    }

    void drawTonearm(Context cr, double cx, double cy, double platterR)
    {
        cr.save();
        double pivotX = cx + platterR + 50;
        double pivotY = cy - platterR - 10;
        cr.translate(pivotX, pivotY);

        // Base
        cr.setSourceRgb(0.15, 0.15, 0.15);
        cr.arc(0, 0, 30, 0, PI * 2);
        cr.fill();
        
        cr.setSourceRgb(0.3, 0.3, 0.3);
        cr.arc(0, 0, 20, 0, PI * 2);
        cr.fill();

        cr.rotate(tonearmAngle * PI / 180.0);

        // Arm
        cr.setSourceRgb(0.7, 0.7, 0.7);
        cr.setLineWidth(6);
        cr.moveTo(0, 0);
        cr.lineTo(-180, 160);
        cr.stroke();

        // Head shell
        cr.translate(-180, 160);
        cr.rotate(0.4);
        cr.setSourceRgb(0.2, 0.2, 0.2);
        cr.rectangle(-10, -20, 20, 40);
        cr.fill();

        cr.restore();
    }

    void drawLabels(Context cr, double cx, double cy, double platterR)
    {
        if (!hasVinyl || vinyl is null)
            return;
            
        cr.save();
        cr.translate(cx - platterR, cy - platterR - 30);
        
        cr.selectFontFace("Sans", FontSlant.Normal, FontWeight.Bold);
        
        string artistStr = null;
        string albumStr = null;
        string detailStr = null;
        
        if (vinyl.isArtist)
        {
            Artist artist = vinyl.artist;
            artistStr = artist.name.toUpper();
            detailStr = artist.albums.length.to!string ~ " ALBUMS";
        }
        else if (vinyl.isAlbum)
        {
            Album album = vinyl.album;
            albumStr = album.name.toUpper();
            detailStr = album.tracks.length.to!string ~ " TRACKS";
            foreach (size_t i, Artist ar; album.artists)
            {
                if (i > 0)
                    artistStr ~= ", ";
                artistStr ~= ar.name.toUpper();
            }
        }
        else if (vinyl.isTrack)
        {
            Track track = vinyl.track;
            detailStr = track.name.toUpper();
            albumStr = track.album.name.toUpper();
            foreach (size_t i, Artist ar; track.album.artists)
            {
                if (i > 0)
                    artistStr ~= ", ";
                artistStr ~= ar.name.toUpper();
            }
        }

        double yPos = 0;
        if (artistStr !is null)
        {
            cr.setFontSize(16);
            cr.setSourceRgba(1.0, 1.0, 1.0, 0.9);
            cr.moveTo(0, yPos);
            cr.showText(artistStr);
            yPos += 24;
        }
        
        if (albumStr !is null)
        {
            cr.setFontSize(14);
            cr.setSourceRgba(0.8, 0.8, 0.8, 0.8);
            cr.moveTo(0, yPos);
            cr.showText(albumStr);
            yPos += 20;
        }
        
        if (detailStr !is null)
        {
            cr.setFontSize(12);
            cr.setSourceRgba(0.6, 0.6, 0.6, 0.7);
            cr.moveTo(0, yPos);
            cr.showText(detailStr);
        }
        
        cr.restore();
    }

    void drawScene(DrawingArea, Context cr, int w, int h)
    {
        double cx = w / 2.0;
        double cy = h / 2.0 + 20;
        double platterR = fmin(cast(double)w, cast(double)h) * 0.40;

        cr.setSourceRgb(0.078, 0.078, 0.078);
        cr.rectangle(0, 0, w, h);
        cr.fill();

        drawPlatter(cr, cx, cy, platterR);

        if (hasVinyl && largeVinyl !is null)
        {
            cr.save();
            cr.translate(cx, cy);
            cr.rotate(vinylAngle);
            cr.scale(vinylScale, vinylScale);
            cr.translate(-cx, -cy);
            
            int vSize = largeVinyl.size;
            cr.translate(cx - vSize/2, cy - vSize/2);
            largeVinyl.onDraw(largeVinyl, cr, vSize, vSize);
            
            cr.restore();
        }

        cr.setSourceRgb(0.6, 0.6, 0.6);
        cr.arc(cx, cy, 4, 0, PI * 2);
        cr.fill();

        drawTonearm(cr, cx, cy, platterR);
        drawLabels(cr, cx, cy, platterR);
    }

    bool onTick()
    {
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
                
                if (largeVinyl !is null)
                {
                    largeVinyl.detach();
                    largeVinyl = null;
                }
                vinyl = null;
            }
        }
        else
        {
            tonearmAngle += (targetTonearmAngle - tonearmAngle) * 0.08;
            if (hasVinyl && window !is null && window.queue !is null && window.queue.playing)
                vinylAngle += 0.02;
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
        if (raw is null)
            return true;

        import std.string : split;
        string[] parts = raw.split("|");
        if (parts is null)
            return true;
            
        string type = parts[0];
        
        if (type == "artist" && parts.length >= 2)
        {
            string artistName = parts[1];
            
            if (window.catalog.artists !is null)
            {
                foreach (Artist a; window.catalog.artists)
                {
                    if (a.name == artistName)
                    {
                        if (window.catalogView !is null)
                            window.catalogView.showAlbums(a);
                        Vinyl v = new Vinyl(a);
                        playVinyl(v);
                        break;
                    }
                }
            }
        }
        else if (type == "album" && parts.length >= 3)
        {
            string artistName = parts[1];
            string albumName = parts[2];
            
            if (window.catalog.artists !is null)
            {
                Artist targetArtist = null;
                foreach (Artist a; window.catalog.artists)
                {
                    if (a.name == artistName)
                    {
                        targetArtist = a;
                        break;
                    }
                }
                
                if (targetArtist !is null)
                {
                    foreach (Album a; targetArtist.albums)
                    {
                        if (a.name == albumName)
                        {
                            if (window.catalogView !is null)
                                window.catalogView.showTracks(targetArtist, a);
                            Vinyl v = new Vinyl(a);
                            playVinyl(v);
                            break;
                        }
                    }
                }
            }
        }
        else if (type == "track" && parts.length >= 4)
        {
            string artistName = parts[1];
            string albumName = parts[2];
            string trackPath = parts[3];
            
            if (window.catalog.artists !is null)
            {
                Artist targetArtist = null;
                foreach (Artist a; window.catalog.artists)
                {
                    if (a.name == artistName)
                    {
                        targetArtist = a;
                        break;
                    }
                }
                
                if (targetArtist !is null)
                {
                    foreach (Album a; targetArtist.albums)
                    {
                        if (a.name == albumName)
                        {
                            if (window.catalogView !is null)
                                window.catalogView.showTracks(targetArtist, a);
                            foreach (Track t; a.tracks)
                            {
                                if (t.audio.file.name == trackPath)
                                {
                                    Vinyl v = new Vinyl(t);
                                    playVinyl(v);
                                    break;
                                }
                            }
                            break;
                        }
                    }
                }
            }
        }

        return true;
    }
    
    void onClicked(int, double x, double y)
    {
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

public:
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

    void liftOff()
    {
        liftingOff = true;
        targetLiftAngle = -60.0;
        if (window !is null && window.queue !is null)
            window.queue.stop();
        queueDraw();
    }

    void playVinyl(Vinyl v)
    {
        if (largeVinyl !is null)
        {
            largeVinyl.detach();
            largeVinyl = null;
        }

        vinyl = v;
        
        int w = contentWidth;
        int h = contentHeight;
        double platterR = fmin(cast(double)w, cast(double)h) * 0.40;
        int vSize = cast(int)(platterR * 1.84);
        
        if (vinyl.isArtist)
            largeVinyl = new Vinyl(vinyl.artist, vSize);
        else if (vinyl.isAlbum)
            largeVinyl = new Vinyl(vinyl.album, vSize);
        else if (vinyl.isTrack)
            largeVinyl = new Vinyl(vinyl.track, vSize);
            
        liftingOff = false;
        hasVinyl = true;
        vinylScale = 0.3;
        targetVinylScale = 1.0;
        animatingDrop = true;
        targetTonearmAngle = 5.0;
        
        if (window !is null && window.queue !is null)
        {
            string[] trackPaths;
            if (vinyl.isArtist)
            {
                foreach (Album a; vinyl.artist.albums)
                    foreach (Track t; a.tracks)
                        trackPaths ~= t.audio.file.name;
            }
            else if (vinyl.isAlbum)
            {
                foreach (Track t; vinyl.album.tracks)
                    trackPaths ~= t.audio.file.name;
            }
            else if (vinyl.isTrack)
            {
                foreach (Track t; vinyl.track.album.tracks)
                    trackPaths ~= t.audio.file.name;
            }
            
            if (trackPaths !is null)
            {
                int startIdx = 0;
                if (vinyl.isTrack)
                {
                    foreach (size_t i, string p; trackPaths)
                    {
                        if (p == vinyl.track.audio.file.name)
                        {
                            startIdx = cast(int)i;
                            break;
                        }
                    }
                }
                
                string artistName = null;
                if (vinyl.isArtist)
                    artistName = vinyl.artist.name;
                else if (vinyl.isAlbum && vinyl.album.artists !is null)
                    artistName = vinyl.album.artists[0].name;
                else if (vinyl.isTrack && vinyl.track.album.artists !is null)
                    artistName = vinyl.track.album.artists[0].name;
                    
                window.queue.playQueue(trackPaths, artistName, startIdx);
            }
        }
        
        queueDraw();
    }
}