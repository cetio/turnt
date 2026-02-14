module turnt.catalogue.search;

import gtk.box;
import gtk.button;
import gtk.editable;
import gtk.label;
import gtk.popover;
import gtk.search_entry;
import gtk.types : Align, Orientation;

import turnt.catalogue.view : CatalogueView, SortMode;

class SearchWidget : Box
{
    SearchEntry searchEntry;
    CatalogueView catalogue;
    Popover sortPopover;
    Popover filterPopover;

    this()
    {
        super(Orientation.Horizontal, 4);
        addCssClass("search-bar");
        marginStart = 4;
        marginEnd = 4;
        marginTop = 8;
        marginBottom = 4;

        searchEntry = new SearchEntry();
        searchEntry.hexpand = true;
        searchEntry.addCssClass("top-search");
        searchEntry.setPlaceholderText("Search...");
        searchEntry.marginStart = 4;
        searchEntry.marginEnd = 4;
        searchEntry.connectSearchChanged(&onSearchChanged);
        append(searchEntry);

        append(makeSortButton());
        append(makeFilterButton());
    }

    private Button makeSortButton()
    {
        Button btn = new Button();
        btn.setIconName("view-sort-ascending-symbolic");
        btn.addCssClass("flat");
        btn.addCssClass("top-btn");

        Box menu = new Box(Orientation.Vertical, 2);
        menu.marginStart = 4;
        menu.marginEnd = 4;
        menu.marginTop = 4;
        menu.marginBottom = 4;

        addSortOption(menu, btn, "Alphabetical \u2191", "view-sort-ascending-symbolic", SortMode.AZ);
        addSortOption(menu, btn, "Alphabetical \u2193", "view-sort-descending-symbolic", SortMode.ZA);
        addSortOption(menu, btn, "Most Played", "media-playback-start-symbolic", SortMode.Plays);

        sortPopover = new Popover();
        sortPopover.setChild(menu);
        sortPopover.setHasArrow(false);
        btn.connectClicked(delegate void() {
            if (sortPopover.getParent() is null)
                sortPopover.setParent(btn);
            sortPopover.popup();
        });
        return btn;
    }

    private void addSortOption(Box menu, Button btn, string label, string icon, SortMode mode)
    {
        Button opt = new Button();
        opt.setChild(new Label(label));
        opt.addCssClass("flat");
        opt.connectClicked(delegate void() {
            btn.setIconName(icon);
            if (catalogue !is null)
                catalogue.setSortMode(mode);
            sortPopover.popdown();
        });
        menu.append(opt);
    }

    private Button makeFilterButton()
    {
        Button btn = new Button();
        btn.setIconName("view-list-symbolic");
        btn.addCssClass("flat");
        btn.addCssClass("top-btn");

        Box menu = new Box(Orientation.Vertical, 2);
        menu.marginStart = 4;
        menu.marginEnd = 4;
        menu.marginTop = 4;
        menu.marginBottom = 4;

        Button artistsBtn = new Button();
        artistsBtn.setChild(new Label("Artists"));
        artistsBtn.addCssClass("flat");
        artistsBtn.connectClicked(delegate void() {
            if (catalogue !is null)
                catalogue.showArtists();
            filterPopover.popdown();
        });
        menu.append(artistsBtn);

        Button albumsBtn = new Button();
        albumsBtn.setChild(new Label("Albums"));
        albumsBtn.addCssClass("flat");
        albumsBtn.connectClicked(delegate void() {
            if (catalogue !is null && catalogue.stickyArtist.length > 0)
                catalogue.showAlbums(catalogue.stickyArtist);
            filterPopover.popdown();
        });
        menu.append(albumsBtn);

        Button tracksBtn = new Button();
        tracksBtn.setChild(new Label("Tracks"));
        tracksBtn.addCssClass("flat");
        tracksBtn.connectClicked(delegate void() {
            if (catalogue !is null && catalogue.stickyArtist.length > 0
                && catalogue.stickyAlbum.length > 0)
                catalogue.showTracks(catalogue.stickyArtist, catalogue.stickyAlbum);
            filterPopover.popdown();
        });
        menu.append(tracksBtn);

        filterPopover = new Popover();
        filterPopover.setChild(menu);
        filterPopover.setHasArrow(false);
        btn.connectClicked(delegate void() {
            if (filterPopover.getParent() is null)
                filterPopover.setParent(btn);
            filterPopover.popup();
        });
        return btn;
    }

    private void onSearchChanged(SearchEntry)
    {
        if (catalogue is null)
            return;
        Editable editable = cast(Editable)searchEntry;
        string text = editable !is null ? editable.getText() : "";
        catalogue.filterArtists(text);
    }
}
