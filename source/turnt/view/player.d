module turnt.view.player;

import gtk.box;
import gtk.types : Orientation, Overflow;
import turnt.widget.turntable;

class PlayerView : Box
{
public:
    TurntableWidget turntable;

    this()
    {
        super(Orientation.Vertical, 0);
        addCssClass("player-panel");
        hexpand = true;
        vexpand = true;
        overflow = Overflow.Hidden;

        turntable = new TurntableWidget();
        append(turntable);
    }
}