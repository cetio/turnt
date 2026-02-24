module turnt.window;

import std.file : SpanMode, dirEntries, exists, isDir;
import std.path : buildPath;

import gtk.application;
import gtk.application_window;
import gtk.paned;
import gtk.types : Orientation;

import mutagen.catalog : Artist, Catalog;
import turnt.view.catalog : CatalogView;
import turnt.view.player : PlayerView;
import turnt.widget.vinyl : Vinyl;
import turnt.queue : Queue;

__gshared TurntWindow window;

class TurntWindow : ApplicationWindow
{
public:
    Catalog catalog;
    CatalogView catalogView;
    PlayerView playerView;
    Queue queue;

    this(Application app)
    {
        super(app);
        window = this;

        string home = "/home/cet"; // Hardcoded for now based on context
        string musicDir = buildPath(home, "Music");

        setDefaultSize(1100, 700);
        setTitle("turnt");

        catalogView = new CatalogView();
        playerView = new PlayerView();
        queue = new Queue();

        Paned paned = new Paned(Orientation.Horizontal);
        paned.setStartChild(catalogView);
        paned.setEndChild(playerView);
        paned.shrinkStartChild = false;
        paned.shrinkEndChild = false;
        paned.position = 440;
        paned.addCssClass("no-separator");

        setChild(paned);

        Vinyl[] vinyls;
        if (exists(musicDir) && isDir(musicDir))
        {
            catalog = Catalog.build([musicDir]);
            foreach (artist; catalog.artists)
            {
                if (artist.albums !is null)
                    vinyls ~= new Vinyl(artist);
            }
        }
        catalogView.display(vinyls);
    }
}
