module turnt.vinyl;

import std.math : abs, cos, fmin, fmod, sin, PI;
import std.path : baseName, dirName;

import cairo.context;
import cairo.global;
import cairo.pattern;
import cairo.surface;
import cairo.types;
import gdk.content_provider;
import gdk.drag;
import gdk.memory_texture;
import gdk.types;
import gdkpixbuf.pixbuf;
import glib.bytes;
import glib.global : timeoutAdd;
import gobject.value;
import gtk.drawing_area;
import gtk.drag_source;
import gtk.event_controller_motion;
import gtk.gesture_click;
import gtk.types;
import gtk.widget : Widget;

import mutagen.parser.scanner : findCoverArt;
import turnt.window;

private Surface[string] coverCache;

Surface loadCoverSurface(string dir, int size)
{
    if (dir in coverCache)
        return coverCache[dir];

    string path = findCoverArt(dir);
    if (path.length == 0)
    {
        coverCache[dir] = null;
        return null;
    }

    try
    {
        Pixbuf pb = Pixbuf.newFromFileAtScale(path, size, size, true);
        if (pb is null)
        {
            coverCache[dir] = null;
            return null;
        }
        Surface srf = pixbufToSurface(pb);
        coverCache[dir] = srf;
        return srf;
    }
    catch (Exception e)
    {
        coverCache[dir] = null;
        return null;
    }
}

// ---------------------------------------------------------------------------
// Pixbuf / surface conversion
// ---------------------------------------------------------------------------

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

// ---------------------------------------------------------------------------
// Colour helpers
// ---------------------------------------------------------------------------

double[3] hsvToRgb(double h, double s, double v)
{
    double c = v * s;
    double x = c * (1.0 - abs(fmod(h / 60.0, 2.0) - 1.0));
    double m = v - c;
    double r, g, b;

    if (h < 60)       { r = c; g = x; b = 0; }
    else if (h < 120) { r = x; g = c; b = 0; }
    else if (h < 180) { r = 0; g = c; b = x; }
    else if (h < 240) { r = 0; g = x; b = c; }
    else if (h < 300) { r = x; g = 0; b = c; }
    else              { r = c; g = 0; b = x; }

    return [r + m, g + m, b + m];
}

string toRoman(int n)
{
    if (n <= 0 || n > 3999)
        return "";
    string result;
    immutable int[] vals =    [1000, 900, 500, 400, 100,  90,  50,  40,  10,   9,   5,   4,  1];
    immutable string[] syms = ["M","CM","D","CD","C","XC","L","XL","X","IX","V","IV","I"];
    foreach (i, v; vals)
    {
        while (n >= v)
        {
            result ~= syms[i];
            n -= v;
        }
    }
    return result;
}

// ---------------------------------------------------------------------------
// Drawing primitives
// ---------------------------------------------------------------------------

void roundedRect(Context cr, double x, double y, double w, double h, double r)
{
    cr.newPath();
    cr.arc(x + r, y + r, r, PI, PI * 1.5);
    cr.arc(x + w - r, y + r, r, PI * 1.5, PI * 2);
    cr.arc(x + w - r, y + h - r, r, 0, PI * 0.5);
    cr.arc(x + r, y + h - r, r, PI * 0.5, PI);
    cr.closePath();
}

void drawVinylDisc(
    Context cr,
    double cx, double cy,
    double radius, double angle, uint hue,
    Surface labelSurface = null,
    int labelW = 0, int labelH = 0,
    int trackNum = 0
)
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

    if (labelSurface !is null && labelW > 0 && labelH > 0)
    {
        double scale = (labelRadius * 2.0) / fmin(cast(double)labelW, cast(double)labelH);
        cr.translate(-labelW * scale / 2.0, -labelH * scale / 2.0);
        cr.scale(scale, scale);
        cr.setSourceSurface(labelSurface, 0, 0);
        cr.paint();
    }
    else
    {
        double h_ = (cast(double)hue / 255.0) * 360.0;
        double[3] rgb = hsvToRgb(h_, 0.5, 0.35);
        cr.setSourceRgb(rgb[0], rgb[1], rgb[2]);
        cr.paint();
    }

    cr.restore();

    // Label outline
    cr.setSourceRgba(0.7, 0.7, 0.7, 0.55);
    cr.setLineWidth(1.5);
    cr.arc(0, 0, labelRadius, 0, PI * 2);
    cr.stroke();

    // Center hole
    cr.setSourceRgb(0.05, 0.05, 0.05);
    cr.arc(0, 0, radius * 0.04, 0, PI * 2);
    cr.fill();

    if (trackNum > 0)
    {
        string roman = toRoman(trackNum);
        if (roman.length > 0)
        {
            double fontSize = radius * 0.20;
            if (fontSize < 5) fontSize = 5;
            cr.selectFontFace("Sans", FontSlant.Normal, FontWeight.Bold);
            cr.setFontSize(fontSize);
            TextExtents ext;
            cr.textExtents(roman, ext);
            double ty = -radius * 0.68;
            double tx = -ext.width / 2 - ext.xBearing;

            cr.save();
            cr.moveTo(tx, ty);
            cr.textPath(roman);
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

            cr.restore();
        }
    }

    cr.restore();
}

void drawVinylFolder(
    Context cr, int w, int h,
    double r, double g, double b,
    bool showCheck
)
{
    double pad = 4;
    double fw = w - pad * 2;
    double fh = h - pad * 2;
    double rad = 3;
    double left = pad;
    double top = pad;
    double cx = left + fw * 0.5;

    // Sleeve fills most of the space
    double sleeveH = fh * 0.78;
    double sleeveTop = top + fh - sleeveH;
    double br = 0.16 + r * 0.84;
    double bg = 0.16 + g * 0.84;
    double bb = 0.16 + b * 0.84;

    // Disc peeking above the sleeve
    double discR = fw * 0.30;
    double discCy = sleeveTop + discR * 0.35;

    cr.setSourceRgb(0.05, 0.05, 0.05);
    cr.arc(cx, discCy, discR, 0, PI * 2);
    cr.fill();

    // Grooves
    cr.setSourceRgba(0.3, 0.3, 0.3, 0.18);
    cr.setLineWidth(0.4);
    for (double gr = discR * 0.45; gr < discR * 0.88; gr += 1.8)
    {
        cr.arc(cx, discCy, gr, 0, PI * 2);
        cr.stroke();
    }

    // Center label
    double labelR = discR * 0.30;
    cr.setSourceRgb(br * 0.7, bg * 0.7, bb * 0.7);
    cr.arc(cx, discCy, labelR, 0, PI * 2);
    cr.fill();

    // Center hole
    cr.setSourceRgb(0.05, 0.05, 0.05);
    cr.arc(cx, discCy, 1.2, 0, PI * 2);
    cr.fill();

    // Drop shadow
    cr.setSourceRgba(0.0, 0.0, 0.0, 0.20);
    roundedRect(cr, left + 1, sleeveTop + 1, fw, sleeveH, rad);
    cr.fill();

    // Sleeve fill
    cr.setSourceRgb(br, bg, bb);
    roundedRect(cr, left, sleeveTop, fw, sleeveH, rad);
    cr.fill();

    // Border
    cr.setSourceRgba(0.0, 0.0, 0.0, 0.28);
    cr.setLineWidth(0.7);
    roundedRect(cr, left, sleeveTop, fw, sleeveH, rad);
    cr.stroke();

    if (showCheck)
    {
        double ccx = left + fw * 0.5;
        double ccy = sleeveTop + sleeveH * 0.5;
        double sz = fmin(fw, sleeveH) * 0.18;
        cr.setSourceRgb(0.078, 0.078, 0.078);
        cr.setLineWidth(sz * 0.28);
        cr.setLineCap(LineCap.Round);
        cr.moveTo(ccx - sz * 0.35, ccy);
        cr.lineTo(ccx - sz * 0.05, ccy + sz * 0.3);
        cr.lineTo(ccx + sz * 0.4, ccy - sz * 0.28);
        cr.stroke();
    }
}

MemoryTexture renderVinylTexture(int diam, double r,
    uint h, Surface label, int lw, int lh, int trackNum = 0)
{
    Surface srf = imageSurfaceCreate(Format.Argb32, diam, diam);
    Context cr = create(srf);
    double cx = diam / 2.0;
    double cy = diam / 2.0;

    cr.setSourceRgb(0.10, 0.08, 0.07);
    cr.arc(cx, cy, r, 0, PI * 2);
    cr.fill();

    drawVinylDisc(cr, cx, cy, r * 0.96, 0.0, h, label, lw, lh, trackNum);
    srf.flush();

    int stride = imageSurfaceGetStride(srf);
    ubyte* data = imageSurfaceGetData(srf);
    ubyte[] pixelData = data[0 .. stride * diam].dup;
    Bytes bytes = new Bytes(pixelData);
    return new MemoryTexture(diam, diam,
        MemoryFormat.B8g8r8a8Premultiplied, bytes, stride);
}

// ---------------------------------------------------------------------------
// Vinyl widget
// ---------------------------------------------------------------------------

class Vinyl : DrawingArea
{
private:
    uint hoverGen;
    bool dragging;
    enum pad = 8;

    void onDraw(DrawingArea, Context cr, int w, int h)
    {
        double maxR = fmin(cast(double)(w - 2), cast(double)(h - 2)) * 0.5;
        double cx = w / 2.0;
        double cy = h / 2.0;

        cr.setSourceRgb(0.10, 0.08, 0.07);
        cr.arc(cx, cy, maxR, 0, PI * 2);
        cr.fill();

        if (!dragging)
            drawVinylDisc(cr, cx, cy, maxR * 0.96, 0.0, hue,
                labelSurface, labelW, labelH, trackNum);

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

    ContentProvider onPrepare(double x, double y)
    {
        string payload;
        if (filePath.length > 0)
            payload = artist~"|"~album~"|"~filePath;
        else if (album.length > 0)
            payload = artist~"|"~album;
        else
            payload = name;
        return ContentProvider.newForValue(new Value(payload));
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

public:
    bool hovered;
    bool outlined;
    string name;
    string artist;
    string album;
    string coverDir;
    string filePath;
    string[] albums;
    string[] albumDirs;
    uint hue;
    int baseSize;
    Surface labelSurface;
    int labelW, labelH;
    int trackNum;

    this(string name, string dir, int size = 70,
        string artist = null, string album = null)
    {
        this.name = name;
        this.artist = artist !is null ? artist : name;
        this.album = album !is null ? album : "";
        this.coverDir = dir;
        this.hue = hashOf(name) & 0xFF;
        this.baseSize = size;

        int totalSize = size + pad * 2;
        contentWidth = totalSize;
        contentHeight = totalSize;
        halign = Align.Center;
        valign = Align.Center;
        overflow = Overflow.Visible;
        setDrawFunc(&onDraw);

        labelSurface = loadCoverSurface(dir, size);
        if (labelSurface !is null)
        {
            labelW = size;
            labelH = size;
        }

        GestureClick vinylClick = new GestureClick();
        vinylClick.connectReleased(delegate(int nPress, double, double) {
            if (nPress != 2 || dragging)
                return;
            if (window is null || window.queue is null)
                return;
            if (coverDir.length > 0 && albums.length > 0)
                window.turntable.loadAlbum(this, artist, coverDir);
            else if (filePath.length > 0)
            {
                string albumDir = dirName(filePath);
                string artistDir = dirName(albumDir);
                window.turntable.loadTrack(this, baseName(artistDir), albumDir, filePath);
            }
        });
        addController(vinylClick);

        DragSource drag = new DragSource();
        drag.actions = DragAction.Copy;
        drag.connectPrepare(&onPrepare);
        drag.connectDragBegin(delegate(gdk.drag.Drag, DragSource ds) {
            dragging = true;
            int diam = baseSize + pad * 2;
            double r = diam * 0.5 - 1;
            MemoryTexture tex = renderVinylTexture(diam, r,
                hue, labelSurface, labelW, labelH, trackNum);
            ds.setIcon(tex, diam / 2, diam / 2);
            queueDraw();
        });
        drag.connectDragEnd(delegate void(gdk.drag.Drag, bool) {
            dragging = false;
            queueDraw();
        });
        addController(drag);

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
