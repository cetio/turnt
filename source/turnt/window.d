module turnt.window;

import std.file : SpanMode, dirEntries, exists, isDir;

import gtk.application;
import gtk.application_window;
import gtk.box;
import gtk.paned;
import gtk.types : Orientation;

import mutagen.catalog : Artist;
import turnt.view.catalog : CatalogView;
import turnt.view.player : PlayerView;
import turnt.widget.vinyl : Vinyl;

enum musicDir = "/home/cet/Music";

TurntWindow window;

class TurntWindow : ApplicationWindow
{
public:
    CatalogView catalogView;
    PlayerView playerView;

    this(Application app)
    {
        super(app);
        window = this;

        setDefaultSize(1100, 700);
        setTitle("turnt");

        catalogView = new CatalogView();
        playerView = new PlayerView();

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
            import mutagen.catalog : Catalog;
            Catalog catalog = Catalog.build([musicDir]);
            foreach (artist; catalog.artists)
            {
                if (artist.albums.length > 0)
                    vinyls ~= new Vinyl(artist);
            }
        }
        catalogView.display(vinyls);
    }
}
