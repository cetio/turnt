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

class TurntableWidget : DrawingArea
{
private:
    double vinylAngle = 0.0;
    double tonearmAngle = -30.0;
    double targetTonearmAngle = -30.0;
    
    bool hasVinyl = false;
    Vinyl vinyl;
    
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
        cr.translate(cx + platterR + 30, cy + platterR - 40);
        
        cr.selectFontFace("Sans", FontSlant.Normal, FontWeight.Bold);
        
        string artistStr = "";
        string albumStr = "";
        string detailStr = "";
        
        if (vinyl.isArtist)
        {
            Artist a = vinyl.artist;
            artistStr = a.name.toUpper();
            detailStr = a.albums.length.to!string ~ " ALBUMS";
        }
        else if (vinyl.isAlbum)
        {
            Album a = vinyl.album;
            albumStr = a.name.toUpper();
            detailStr = a.tracks.length.to!string ~ " TRACKS";
            foreach (i, ar; a.artists)
            {
                if (i > 0) artistStr ~= ", ";
                artistStr ~= ar.name.toUpper();
            }
        }
        else if (vinyl.isTrack)
        {
            Track t = vinyl.track;
            detailStr = t.name.toUpper();
            albumStr = t.album.name.toUpper();
            foreach (i, ar; t.album.artists)
            {
                if (i > 0) artistStr ~= ", ";
                artistStr ~= ar.name.toUpper();
            }
        }

        double y = 0;
        if (artistStr.length > 0)
        {
            cr.setFontSize(16);
            cr.setSourceRgba(1.0, 1.0, 1.0, 0.9);
            cr.moveTo(0, y);
            cr.showText(artistStr);
            y += 24;
        }
        
        if (albumStr.length > 0)
        {
            cr.setFontSize(14);
            cr.setSourceRgba(0.8, 0.8, 0.8, 0.8);
            cr.moveTo(0, y);
            cr.showText(albumStr);
            y += 20;
        }
        
        if (detailStr.length > 0)
        {
            cr.setFontSize(12);
            cr.setSourceRgba(0.6, 0.6, 0.6, 0.7);
            cr.moveTo(0, y);
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

        if (hasVinyl && vinyl !is null)
        {
            cr.save();
            cr.translate(cx, cy);
            cr.rotate(vinylAngle);
            cr.scale(vinylScale, vinylScale);
            cr.translate(-cx, -cy);
            
            // Draw actual vinyl large
            int vSize = cast(int)(platterR * 1.84);
            Vinyl tempVinyl;
            
            if (vinyl.isArtist)
                tempVinyl = new Vinyl(vinyl.artist, vSize);
            else if (vinyl.isAlbum)
                tempVinyl = new Vinyl(vinyl.album, vSize);
            else if (vinyl.isTrack)
                tempVinyl = new Vinyl(vinyl.track, vSize);
                
            if (tempVinyl !is null)
            {
                cr.translate(cx - vSize/2, cy - vSize/2);
                tempVinyl.onDraw(tempVinyl, cr, vSize, vSize);
            }
            
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
                vinyl = null;
            }
        }
        else
        {
            tonearmAngle += (targetTonearmAngle - tonearmAngle) * 0.08;
            if (hasVinyl)
                vinylAngle += 0.02; // Spin constantly for now
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
        // For now just accept strings (like pointer addresses to vinyls or IDs, but we don't have that yet)
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
        queueDraw();
    }

    void playVinyl(Vinyl v)
    {
        vinyl = v;
        liftingOff = false;
        hasVinyl = true;
        vinylScale = 0.3;
        targetVinylScale = 1.0;
        animatingDrop = true;
        targetTonearmAngle = 5.0;
        queueDraw();
    }
}