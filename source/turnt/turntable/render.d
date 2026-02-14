module turnt.turntable.render;

import std.math : cos, fmin, sin, PI;

import cairo.context;
import cairo.types;

import turnt.vinyl : roundedRect;

void drawBase(Context cr, int w, int h)
{
    enum margin = 12.0;
    enum radius = 16.0;
    roundedRect(cr, margin, margin, w - margin * 2, h - margin * 2, radius);
    cr.setSourceRgb(0.14, 0.12, 0.10);
    cr.fill();

    roundedRect(cr, margin + 8, margin + 8,
        w - margin * 2 - 16, h - margin * 2 - 16, radius - 4);
    cr.setSourceRgb(0.12, 0.10, 0.09);
    cr.fill();
}

void drawPlatter(Context cr, double cx, double cy, double radius)
{
    cr.setSourceRgb(0.18, 0.18, 0.18);
    cr.arc(cx, cy, radius + 6, 0, PI * 2);
    cr.fill();

    cr.setSourceRgb(0.13, 0.13, 0.13);
    cr.arc(cx, cy, radius, 0, PI * 2);
    cr.fill();

    cr.setSourceRgba(0.2, 0.2, 0.2, 0.5);
    foreach (i; 0..60)
    {
        double angle = i * PI * 2.0 / 60.0;
        cr.arc(cx + cos(angle) * (radius - 8),
            cy + sin(angle) * (radius - 8), 1.2, 0, PI * 2);
        cr.fill();
    }

    cr.setSourceRgb(0.08, 0.08, 0.08);
    cr.arc(cx, cy, radius * 0.88, 0, PI * 2);
    cr.fill();
}

void drawTonearm(Context cr, double cx, double cy, double platterR, double tonearmAngle)
{
    double pivotX = cx + platterR + 50;
    double pivotY = cy - platterR - 10;

    cr.save();
    cr.translate(pivotX, pivotY);
    cr.rotate(tonearmAngle * PI / 180.0);

    // Pivot base
    cr.setSourceRgb(0.25, 0.25, 0.25);
    cr.arc(0, 0, 14, 0, PI * 2);
    cr.fill();

    // Pivot center highlight
    cr.setSourceRgba(0.5, 0.5, 0.5, 0.3);
    cr.arc(-3, -3, 6, 0, PI * 2);
    cr.fill();

    // Pivot ring
    cr.setSourceRgb(0.15, 0.15, 0.15);
    cr.arc(0, 0, 14, 0, PI * 2);
    cr.setLineWidth(1);
    cr.stroke();

    double armLen = platterR * 1.5;

    // Main tonearm
    cr.setSourceRgb(0.35, 0.35, 0.35);
    cr.setLineWidth(8);
    cr.setLineCap(LineCap.Round);
    cr.moveTo(0, 0);
    cr.lineTo(-armLen * 0.3, armLen * 0.85);
    cr.stroke();

    // Arm highlight
    cr.setSourceRgba(0.5, 0.5, 0.5, 0.3);
    cr.setLineWidth(2);
    cr.moveTo(-2, -2);
    cr.lineTo(-armLen * 0.3 - 2, armLen * 0.85 - 2);
    cr.stroke();

    // Secondary arm section
    cr.setSourceRgb(0.4, 0.4, 0.4);
    cr.setLineWidth(6);
    cr.moveTo(-armLen * 0.3, armLen * 0.85);
    cr.lineTo(-armLen * 0.35, armLen * 0.95);
    cr.stroke();

    // Cartridge head
    cr.setSourceRgb(0.25, 0.25, 0.25);
    cr.rectangle(-armLen * 0.39, armLen * 0.92, 8, 12);
    cr.fill();

    // Cartridge highlight
    cr.setSourceRgba(0.6, 0.6, 0.6, 0.2);
    cr.rectangle(-armLen * 0.37, armLen * 0.94, 4, 8);
    cr.fill();

    // Stylus tip
    cr.setSourceRgb(0.1, 0.1, 0.1);
    cr.moveTo(-armLen * 0.35, armLen * 1.02);
    cr.lineTo(-armLen * 0.33, armLen * 1.04);
    cr.lineTo(-armLen * 0.31, armLen * 1.02);
    cr.closePath();
    cr.fill();

    // Counterweight
    cr.setSourceRgb(0.3, 0.3, 0.3);
    cr.arc(armLen * 0.12, -armLen * 0.1, 8, 0, PI * 2);
    cr.fill();

    // Counterweight highlight
    cr.setSourceRgba(0.6, 0.6, 0.6, 0.3);
    cr.arc(armLen * 0.09, -armLen * 0.13, 3, 0, PI * 2);
    cr.fill();

    // Counterweight ring
    cr.setSourceRgb(0.15, 0.15, 0.15);
    cr.arc(armLen * 0.12, -armLen * 0.1, 8, 0, PI * 2);
    cr.setLineWidth(1);
    cr.stroke();

    cr.restore();
}

void drawTurntableLabels(Context cr, double cx, double cy, double platterR,
    string displayArtist, string displayAlbum, string displayTrack)
{
    TextExtents ext;
    double y = cy - platterR - 16;

    if (displayAlbum.length > 0)
    {
        cr.setSourceRgba(0.65, 0.65, 0.65, 0.8);
        cr.selectFontFace("Sans", FontSlant.Normal, FontWeight.Normal);
        cr.setFontSize(13);
        cr.textExtents(displayAlbum, ext);
        cr.moveTo(cx - ext.width / 2, y);
        cr.showText(displayAlbum);
        y -= ext.height + 6;
    }

    if (displayTrack.length > 0)
    {
        cr.setSourceRgba(1, 1, 1, 0.95);
        cr.selectFontFace("Sans", FontSlant.Normal, FontWeight.Bold);
        cr.setFontSize(20);
        cr.textExtents(displayTrack, ext);
        cr.moveTo(cx - ext.width / 2, y);
        cr.showText(displayTrack);
        y -= ext.height + 6;
    }

    if (displayArtist.length > 0)
    {
        cr.setSourceRgba(0.65, 0.65, 0.65, 0.8);
        cr.selectFontFace("Sans", FontSlant.Normal, FontWeight.Normal);
        cr.setFontSize(13);
        cr.textExtents(displayArtist, ext);
        cr.moveTo(cx - ext.width / 2, y);
        cr.showText(displayArtist);
    }
}

string findLatestAlbumDir(string artistDir)
{
    import std.file : exists, dirEntries, SpanMode;
    import std.algorithm : sort;
    import mutagen.parser.scanner : findCoverArt;

    if (!exists(artistDir))
        return artistDir;
    if (findCoverArt(artistDir).length > 0)
        return artistDir;
    string[] albums;
    try
    {
        foreach (entry; dirEntries(artistDir, SpanMode.shallow))
        {
            if (entry.isDir)
                albums ~= entry.name;
        }
    }
    catch (Exception) {}
    if (albums.length > 0)
    {
        albums.sort();
        return albums[$ - 1];
    }
    return artistDir;
}
