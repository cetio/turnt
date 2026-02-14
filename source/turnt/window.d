module turnt.window;

import std.format : format;

import gdk.display : Display;
import glib.global : timeoutAdd;
import gtk.application;
import gtk.application_window;
import gtk.box;
import gtk.button;
import gtk.css_provider;
import gtk.label;
import gtk.overlay;
import gtk.paned;
import gtk.stack;
import gtk.style_context;
import gtk.toggle_button;
import gtk.types : Align, Orientation, Overflow, STYLE_PROVIDER_PRIORITY_APPLICATION,
    STYLE_PROVIDER_PRIORITY_USER;
import gtk.widget;
import gtk.window;

import turnt.catalogue.search : SearchWidget;
import turnt.catalogue.view : CatalogueView;
import turnt.controller : attachControllers;
import turnt.queue : Queue;
import turnt.turntable : TurntableWidget;

TurntWindow window;

class TurntWindow : ApplicationWindow
{
    Queue queue;
    TurntableWidget turntable;
    CatalogueView catalogue;
    CatalogueView rightCatalogue;
    SearchWidget searchBar;
    Stack turntableStack;
    Label playlistLabel;

    this(Application app)
    {
        super(app);
        window = this;

        setDefaultSize(900, 650);
        setTitle("turnt");

        queue = new Queue();
        turntable = new TurntableWidget();
        catalogue = new CatalogueView();
        rightCatalogue = new CatalogueView();
        rightCatalogue.isRightPanel = true;
        searchBar = new SearchWidget();
        searchBar.catalogue = catalogue;
        catalogue.searchWidget = searchBar;
        attachControllers(catalogue);
        attachControllers(rightCatalogue);

        // Create stack for turntable area
        turntableStack = new Stack();
        turntableStack.hexpand = false;
        turntableStack.addCssClass("turntable-stack");
        
        // Create turntable page with overlay for settings and play button
        Overlay turntableOverlay = new Overlay();
        turntableOverlay.setChild(turntable);
        
        // Add play/pause button to overlay
        ToggleButton playPauseBtn = new ToggleButton();
        playPauseBtn.setIconName("media-playback-pause-symbolic");
        playPauseBtn.addCssClass("flat");
        playPauseBtn.addCssClass("play-pause-btn");
        playPauseBtn.widthRequest = 50;
        playPauseBtn.heightRequest = 50;
        playPauseBtn.setActive(!queue.playing); // Initial state - inverted
        playPauseBtn.valign = Align.End;
        playPauseBtn.halign = Align.Start;
        playPauseBtn.marginStart = 60;
        playPauseBtn.marginBottom = 80;
        playPauseBtn.connectToggled(delegate void() {
            if (queue !is null)
            {
                if (playPauseBtn.active)
                    queue.resume();
                else
                    queue.pause();
            }
        });
        turntableOverlay.addOverlay(playPauseBtn);
        
        // Add settings to top right of turntable
        Box turntableSettings = new Box(Orientation.Horizontal, 6);
        turntableSettings.addCssClass("turntable-settings");
        turntableSettings.valign = Align.Start;
        turntableSettings.halign = Align.End;
        turntableSettings.marginTop = 8;
        turntableSettings.marginEnd = 8;
        
        // Create shuffle and loop buttons for turntable
        ToggleButton turntableShuffle = new ToggleButton();
        turntableShuffle.setIconName("media-playlist-shuffle-symbolic");
        turntableShuffle.addCssClass("flat");
        turntableShuffle.addCssClass("top-btn");
        turntableShuffle.connectToggled(delegate void() {
            if (queue !is null)
                queue.shuffle = turntableShuffle.active;
        });
        turntableSettings.append(turntableShuffle);
        
        ToggleButton turntableLoop = new ToggleButton();
        turntableLoop.setIconName("media-playlist-repeat-symbolic");
        turntableLoop.addCssClass("flat");
        turntableLoop.addCssClass("top-btn");
        turntableLoop.connectToggled(delegate void() {
            if (queue !is null)
                queue.loop = turntableLoop.active;
        });
        turntableSettings.append(turntableLoop);

        Button turntableGear = new Button();
        turntableGear.setIconName("emblem-system-symbolic");
        turntableGear.addCssClass("flat");
        turntableGear.addCssClass("top-btn");
        turntableSettings.append(turntableGear);
        
        turntableOverlay.addOverlay(turntableSettings);
        turntableStack.addNamed(turntableOverlay, "turntable");
        
        Box rightPanel = new Box(Orientation.Horizontal, 0);
        rightPanel.hexpand = true;

        // Color palette for vinyl folder
        Box colorStrip = new Box(Orientation.Vertical, 4);
        colorStrip.addCssClass("color-strip");
        colorStrip.valign = Align.Center;
        colorStrip.marginStart = 6;
        colorStrip.marginEnd = 2;

        static struct Rgb { double r, g, b; }
        Rgb[6] palette = [
            Rgb(0.35, 0.35, 0.45),
            Rgb(0.55, 0.25, 0.25),
            Rgb(0.25, 0.45, 0.30),
            Rgb(0.50, 0.40, 0.20),
            Rgb(0.30, 0.30, 0.50),
            Rgb(0.45, 0.25, 0.40),
        ];
        
        foreach (idx, ref c; palette)
        {
            string cls = format("color-btn-%d", cast(int)idx);
            Button cb = new Button();
            cb.addCssClass("color-btn");
            cb.addCssClass(cls);
            cb.widthRequest = 18;
            cb.heightRequest = 18;

            CssProvider btnCss = new CssProvider();
            string cssStr = format(".%s { background-color: rgb(%d,%d,%d); }",
                cls, cast(int)(c.r * 255), cast(int)(c.g * 255), cast(int)(c.b * 255));
            btnCss.loadFromString(cssStr);
            StyleContext.addProviderForDisplay(
                Display.getDefault(), btnCss, STYLE_PROVIDER_PRIORITY_USER);

            cb.connectClicked(((double cr, double cg, double cb_) => delegate void() {
                catalogue.playlist.folderR = cr;
                catalogue.playlist.folderG = cg;
                catalogue.playlist.folderB = cb_;
                if (catalogue.playlist.folderDa !is null)
                    catalogue.playlist.folderDa.queueDraw();
            })(c.r, c.g, c.b));
            colorStrip.append(cb);
        }
        rightPanel.append(colorStrip);

        Box catalogueBox = new Box(Orientation.Vertical, 0);
        catalogueBox.hexpand = true;
        catalogueBox.vexpand = true;

        SearchWidget rightSearchBar = new SearchWidget();
        rightSearchBar.catalogue = rightCatalogue;
        catalogueBox.append(rightSearchBar);
        catalogueBox.append(rightCatalogue);
        rightPanel.append(catalogueBox);

        turntableStack.addNamed(rightPanel, "empty");
        
        turntableStack.setVisibleChildName("turntable");

        turntableStack.hexpand = true;

        playlistLabel = new Label("");
        playlistLabel.addCssClass("count-label");
        playlistLabel.halign = Align.Center;
        playlistLabel.marginBottom = 6;
        playlistLabel.marginTop = 2;
        playlistLabel.visible = false;

        timeoutAdd(0, 500, &updatePlaylistLabel);

        Box rightWrapper = new Box(Orientation.Vertical, 0);
        rightWrapper.append(turntableStack);
        rightWrapper.append(playlistLabel);

        Box leftPanel = new Box(Orientation.Vertical, 0);
        leftPanel.append(searchBar);
        leftPanel.append(catalogue);

        Paned paned = new Paned(Orientation.Horizontal);
        paned.setStartChild(leftPanel);
        paned.setEndChild(rightWrapper);
        paned.shrinkStartChild = false;
        paned.shrinkEndChild = false;
        paned.position = 360;
        paned.addCssClass("no-separator");
        
        setChild(paned);
    }

    bool updatePlaylistLabel()
    {
        if (queue is null || playlistLabel is null)
            return true;
        string pn = queue.playlistName;
        if (pn.length > 0 && queue.playing)
        {
            playlistLabel.setLabel("♫ "~pn);
            playlistLabel.visible = true;
        }
        else
            playlistLabel.visible = false;
        return true;
    }
}
