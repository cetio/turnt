module turnt.widget.vinyl;

import std.conv;
import std.math : abs, cos, fmin, fmod, sin, PI;
import std.variant;;

import cairo.context;
import cairo.global;
import cairo.pattern;
import cairo.surface;
import cairo.types;
import gdk.memory_texture;
import gdkpixbuf.pixbuf : Pixbuf;
import gdkpixbuf.pixbuf_loader : PixbufLoader;
import gdkpixbuf.types : InterpType;
import glib.bytes;
import glib.global : timeoutAdd;
import gtk.drawing_area;
import gtk.event_controller_motion;
import gtk.types : Align, Overflow;
import gtk.widget : Widget;

import mutagen.catalog : Artist, Album, Track, Image;

Surface pixbufToSurface(Pixbuf pb)
{
    if (pb is null)
        return null;

    int w = pb.getWidth();
    int h = pb.getHeight();
    int channels = pb.getNChannels();
    int srcStride = pb.getRowstride();
    const(ubyte)* src = pb.readPixels();

    if (src is null || w <= 0 || h <= 0)
        return null;

    Surface srf = imageSurfaceCreate(Format.Argb32, w, h);
    if (srf is null)
        return null;

    int dstStride = imageSurfaceGetStride(srf);
    ubyte* dst = imageSurfaceGetData(srf);
    if (dst is null)
        return null;

    srf.flush();

    for (int y = 0; y < h; y++)
    {
        const(ubyte)* sRow = src + y * srcStride;
        ubyte* dRow = dst + y * dstStride;
        for (int x = 0; x < w; x++)
        {
            ubyte r = sRow[x * channels + 0];
            ubyte g = sRow[x * channels + 1];
            ubyte b = sRow[x * channels + 2];
            ubyte a = (channels == 4) ? sRow[x * channels + 3] : 255;
            dRow[x * 4 + 0] = cast(ubyte)(b * a / 255);
            dRow[x * 4 + 1] = cast(ubyte)(g * a / 255);
            dRow[x * 4 + 2] = cast(ubyte)(r * a / 255);
            dRow[x * 4 + 3] = a;
        }
    }

    srf.markDirty();
    return srf;
}

class Vinyl : DrawingArea
{
private:
    uint hoverGen;

    void drawDisc(Context cr, double cx, double cy, double radius, double angle = 0.0)
    {
        cr.save();
        cr.translate(cx, cy);
        cr.rotate(angle);

        cr.setSourceRgb(0.02, 0.02, 0.02);
        cr.arc(0, 0, radius, 0, PI * 2);
        cr.fill();

        cr.setSourceRgba(0.35, 0.35, 0.35, 0.15);
        cr.setLineWidth(1.0);
        cr.arc(0, 0, radius * 0.97, 0, PI * 2);
        cr.stroke();

        for (double r = radius * 0.36; r < radius * 0.95; r += 1.8)
        {
            double alpha = 0.14 + 0.10 * sin(r * 0.7);
            cr.setSourceRgba(0.45, 0.45, 0.45, alpha);
            cr.setLineWidth(0.5);
            cr.arc(0, 0, r, 0, PI * 2);
            cr.stroke();
        }

        cr.setSourceRgba(0.6, 0.6, 0.6, 0.08);
        cr.setLineWidth(radius * 0.5);
        cr.arc(0, 0, radius * 0.65, -0.25, 0.25);
        cr.stroke();

        cr.setSourceRgba(0.5, 0.5, 0.5, 0.04);
        cr.setLineWidth(radius * 0.3);
        cr.arc(0, 0, radius * 0.55, PI - 0.4, PI + 0.15);
        cr.stroke();

        double labelRadius = radius * 0.32;

        cr.save();
        cr.arc(0, 0, labelRadius, 0, PI * 2);
        cr.clip();

        if (surface !is null && size > 0)
        {
            double scale = (labelRadius * 2.0) / fmin(cast(double)size, cast(double)size);
            cr.translate(-size * scale / 2.0, -size * scale / 2.0);
            cr.scale(scale, scale);
            cr.setSourceSurface(surface, 0, 0);
            cr.paint();
        }
        else
        {
            cr.setSourceRgb(0.15, 0.15, 0.15);
            cr.paint();
        }

        cr.restore();

        cr.setSourceRgba(0.7, 0.7, 0.7, 0.55);
        cr.setLineWidth(1.5);
        cr.arc(0, 0, labelRadius, 0, PI * 2);
        cr.stroke();

        cr.setSourceRgb(0.05, 0.05, 0.05);
        cr.arc(0, 0, radius * 0.04, 0, PI * 2);
        cr.fill();

        if (isTrack)
        {
            double fontSize = radius * 0.20;
            if (fontSize < 5) 
                fontSize = 5;

            cr.selectFontFace("Sans", FontSlant.Normal, FontWeight.Bold);
            cr.setFontSize(fontSize);

            TextExtents ext;
            cr.textExtents(track.number.to!string, ext);
            double ty = -radius * 0.68;
            double tx = -ext.width / 2 - ext.xBearing;

            cr.moveTo(tx, ty);
            cr.textPath(track.number.to!string);
            cr.clip();

            cr.setSourceRgba(0.72, 0.72, 0.72, 0.85);
            cr.paint();

            for (double r = radius * 0.36; r < radius * 0.95; r += 1.8)
            {
                double alpha = 0.25 + 0.15 * sin(r * 0.7);
                cr.setSourceRgba(0.0, 0.0, 0.0, alpha);
                cr.setLineWidth(0.5);
                cr.arc(0, 0, r, 0, PI * 2);
                cr.stroke();
            }
        }

        cr.restore();
    }

    void onDraw(DrawingArea, Context cr, int w, int h)
    {
        double maxR = fmin(cast(double)(w - 2), cast(double)(h - 2)) * 0.5;
        double cx = w / 2.0;
        double cy = h / 2.0;

        cr.setSourceRgb(0.10, 0.08, 0.07);
        cr.arc(cx, cy, maxR, 0, PI * 2);
        cr.fill();

        drawDisc(cr, cx, cy, maxR * 0.96);

        if (outlined)
        {
            cr.setSourceRgba(1.0, 1.0, 1.0, 0.65);
            cr.setLineWidth(1.6);
            cr.newPath();
            cr.arc(cx, cy, maxR * 0.97, 0, PI * 2);
            cr.closePath();
            cr.stroke();
        }
    }

    void onEnter(double x, double y)
    {
        uint gen = ++hoverGen;
        timeoutAdd(0, 200, delegate bool() {
            if (hoverGen == gen)
            {
                hovered = true;
                queueDraw();
            }
            return false;
        });
    }

    void onLeave()
    {
        hoverGen++;
        hovered = false;
        queueDraw();
    }

    void loadLabel(Image img, int size)
    {
        if (!img.hasData)
            return;

        try
        {
            
        }
        catch (Exception) { }
    }

public:
    Variant data;
    string name;
    bool hovered;
    bool outlined;
    
    int size;
    Surface surface;

    Artist artist()
        => data.get!Artist;

    Album album()
        => data.get!Album;

    Track track()
        => data.get!Track;

    bool isArtist()
        => data.type == typeid(Artist);

    bool isAlbum()
        => data.type == typeid(Album);

    bool isTrack()
        => data.type == typeid(Track);

    this(T)(T val, int size = -1)
    {
        data = Variant(val);
        name = val.name;

        static if (is(T == Artist))
            size = size == -1 ? 58 : size;
        else static if (is(T == Album))
            size = size == -1 ? 50 : size;
        else static if (is(T == Track))
            size = size == -1 ? 32 : size;

        contentWidth = size + 16;
        contentHeight = size + 16;
        halign = Align.Center;
        valign = Align.Center;
        overflow = Overflow.Visible;
        setDrawFunc(&onDraw);

        if (val.image.hasData)
        {
            PixbufLoader loader = new PixbufLoader();
            loader.write(val.image.data);
            loader.close();
            Pixbuf pixbuf = loader.getPixbuf();
            if (pixbuf !is null)
            {
                Pixbuf scaled = pixbuf.scaleSimple(size, size, InterpType.Bilinear);
                if (scaled !is null)
                {
                    this.surface = pixbufToSurface(scaled);
                    this.size = size;
                }
            }
        }

        EventControllerMotion motion = new EventControllerMotion();
        motion.connectEnter(&onEnter);
        motion.connectLeave(&onLeave);
        addController(motion);
    }

    void detach()
    {
        if (getParent() !is null)
            unparent();
    }
}