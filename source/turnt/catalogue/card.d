module turnt.catalogue.card;

import std.conv : to;
import std.file : SpanMode;
import std.path : baseName;
import std.string : indexOf, lastIndexOf, toUpper;

import gtk.box;
import gtk.gesture_click;
import gtk.label;
import gtk.overlay;
import gtk.types : Align, Orientation, Overflow;
import gtk.widget : Widget;
import pango.types : EllipsizeMode;

import mutagen.parser.scanner : collectAudio;
import turnt.vinyl : Vinyl;

class CardWidget : Box
{
    Overlay overlay;
    Box row;
    Box infoBox;
    Vinyl[] vinyls;
    Label titleLabel;
    Label subLabel;
    Label playCountLabel;
    bool splayed;

    this(Vinyl v, string title, string detail, int plays = 0,
        int mTop = 2, int mBot = 2, string extraTitleCss = "")
    {
        super(Orientation.Horizontal, 0);
        addCssClass("card");
        marginStart = 4;
        marginEnd = 4;
        marginTop = mTop;
        marginBottom = mBot;

        v.outlined = false;
        vinyls ~= v;

        row = new Box(Orientation.Horizontal, 8);
        v.detach();
        row.append(v);

        infoBox = new Box(Orientation.Vertical, 1);
        infoBox.valign = Align.Center;
        infoBox.hexpand = true;

        titleLabel = new Label(title);
        titleLabel.addCssClass("card-name");
        if (extraTitleCss.length > 0)
            titleLabel.addCssClass(extraTitleCss);
        titleLabel.halign = Align.Start;
        titleLabel.hexpand = true;
        titleLabel.xalign = 0;
        titleLabel.ellipsize = EllipsizeMode.End;
        infoBox.append(titleLabel);

        if (detail.length > 0)
        {
            subLabel = new Label(detail);
            subLabel.addCssClass("count-label");
            subLabel.halign = Align.Start;
            subLabel.xalign = 0;
            subLabel.ellipsize = EllipsizeMode.End;
            infoBox.append(subLabel);
        }

        row.append(infoBox);

        overlay = new Overlay();
        overlay.setChild(row);

        if (plays > 0)
        {
            playCountLabel = new Label(plays.to!string);
            playCountLabel.addCssClass("play-count-label");
            playCountLabel.halign = Align.End;
            playCountLabel.valign = Align.End;
            playCountLabel.marginEnd = 8;
            playCountLabel.marginBottom = 4;
            overlay.addOverlay(playCountLabel);
        }

        append(overlay);
    }

    void attachSplay(int cardWidth)
    {
        if (vinyls.length == 0)
            return;
        Vinyl primary = vinyls[0];
        if (primary.albumDirs.length == 0 && (primary.album.length == 0 || primary.coverDir.length == 0))
            return;

        GestureClick rclick = new GestureClick();
        rclick.button = 3;
        rclick.connectPressed(delegate(int, double, double) {
            if (!primary.hovered)
                return;
            if (splayed)
                unsplay();
            else
                splay(cardWidth);
        });
        overlay.addController(rclick);
    }

    void splay(int cardWidth)
    {
        if (vinyls.length == 0)
            return;
        Vinyl primary = vinyls[0];
        splayed = true;

        int diam = primary.contentHeight;
        int step = (diam * 45) / 100;
        if (step <= 0) step = 1;
        int maxVinyls = (cardWidth - 100) / step;
        if (maxVinyls < 1) maxVinyls = 1;
        if (primary.albumDirs.length > 0)
        {
            foreach (dir; primary.albumDirs)
            {
                if (cast(int)vinyls.length - 1 >= maxVinyls)
                    break;
                string albumName = baseName(dir);
                Vinyl v = new Vinyl(albumName, dir, primary.baseSize, primary.artist, albumName);
                v.outlined = false;
                v.trackNum = cast(int)collectAudio(dir, SpanMode.shallow).length;
                vinyls ~= v;
            }
        }
        else if (primary.album.length > 0 && primary.coverDir.length > 0)
        {
            string[] tracks = collectAudio(primary.coverDir, SpanMode.shallow);
            foreach (idx, track; tracks)
            {
                if (cast(int)vinyls.length - 1 >= maxVinyls)
                    break;
                string trackName = baseName(track);
                ptrdiff_t dot = trackName.lastIndexOf('.');
                if (dot > 0)
                    trackName = trackName[0..dot];
                ptrdiff_t dash = trackName.indexOf(" - ");
                if (dash >= 0)
                    trackName = trackName[dash + 3..$];

                Vinyl v = new Vinyl(trackName, primary.coverDir, primary.baseSize,
                    primary.artist, primary.album);
                v.outlined = false;
                v.filePath = track;
                v.trackNum = cast(int)(idx + 1);
                vinyls ~= v;
            }
        }

        rebuild(cardWidth);
    }

    void unsplay()
    {
        splayed = false;
        vinyls = vinyls[0..1];
        clearRow();
        vinyls[0].detach();
        vinyls[0].outlined = false;
        vinyls[0].marginStart = 0;
        vinyls[0].halign = Align.Center;
        row.append(vinyls[0]);
        row.append(infoBox);
        infoBox.hexpand = true;
    }

    private void rebuild(int cardWidth)
    {
        clearRow();
        Vinyl primary = vinyls[0];
        int diam = primary.contentHeight;
        int step = (diam * 45) / 100;
        if (step <= 0)
            step = 1;
        int count = cast(int)vinyls.length - 1;

        int maxChildren = (cardWidth - 100) / step;
        if (count > maxChildren && maxChildren > 0)
            count = maxChildren;

        Overlay splayArea = new Overlay();
        splayArea.overflow = Overflow.Visible;

        int splayW = diam + step * count;
        Box base = new Box(Orientation.Horizontal, 0);
        base.widthRequest = splayW;
        base.heightRequest = diam;
        splayArea.setChild(base);

        for (int i = count; i >= 1; i--)
        {
            Vinyl v = vinyls[i];
            v.detach();
            v.outlined = false;
            v.halign = Align.Start;
            v.valign = Align.Center;
            v.marginStart = step * i;
            v.marginTop = 0;
            v.overflow = Overflow.Visible;
            splayArea.addOverlay(v);
        }

        primary.detach();
        primary.outlined = true;
        primary.halign = Align.Start;
        primary.valign = Align.Center;
        primary.marginStart = 0;
        primary.overflow = Overflow.Visible;
        splayArea.addOverlay(primary);

        row.append(splayArea);

        int remaining = cardWidth - splayW - 16;
        if (remaining >= 80)
        {
            row.append(infoBox);
            infoBox.hexpand = true;
        }
    }

    private void clearRow()
    {
        Widget ch = row.getFirstChild();
        while (ch !is null)
        {
            Widget next = ch.getNextSibling();
            row.remove(ch);
            ch = next;
        }
    }
}
