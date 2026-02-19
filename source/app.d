module app;

// import std.file : exists, readText;
// import std.stdio : writeln;

// import gio.types : ApplicationFlags;
// import gtk.application;
// import gtk.css_provider;
// import gtk.style_context;
// import gtk.types : STYLE_PROVIDER_PRIORITY_APPLICATION;
// import gdk.display;

// import turnt.window;

// enum cssPath = "resources/style.css";

// class TurntApp : Application
// {
// private:
//     CssProvider cssProvider;

//     void applyCss()
//     {
//         cssProvider = new CssProvider();
//         if (cssPath.exists)
//             cssProvider.loadFromString(cssPath.readText);
//         else
//             writeln("Warning: CSS file not found at "~cssPath);

//         StyleContext.addProviderForDisplay(
//             Display.getDefault(), cssProvider, STYLE_PROVIDER_PRIORITY_APPLICATION);
//     }

//     void onActivate()
//     {
//         applyCss();
//         window = new TurntWindow(this);
//         window.present();
//     }

// public:
//     this()
//     {
//         super("org.turnt.player", ApplicationFlags.DefaultFlags);
//         connectActivate(&onActivate);
//     }
// }

void main(string[] args)
{
    // TurntApp app = new TurntApp();
    // app.run(args);
}
