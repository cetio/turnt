module turnt.controller;

import std.math : abs;

import glib.global : timeoutAdd;
import gtk.adjustment;
import gtk.event_controller_motion;
import gtk.event_controller_scroll;
import gtk.gesture_drag;
import gtk.types : EventControllerScrollFlags;

import turnt.catalogue.view : CatalogueView;

void attachControllers(CatalogueView view)
{
    ScrollState state = new ScrollState(view);

    GestureDrag scrollDrag = new GestureDrag();
    scrollDrag.connectDragBegin(&state.onDragBegin);
    scrollDrag.connectDragUpdate(&state.onDragUpdate);
    scrollDrag.connectDragEnd(&state.onDragEnd);
    view.scrolled.addController(scrollDrag);

    EventControllerScroll scrollCtrl = new EventControllerScroll(
        EventControllerScrollFlags.BothAxes);
    scrollCtrl.connectScroll(&state.onScroll);
    view.scrolled.addController(scrollCtrl);

    EventControllerMotion cursorTracker = new EventControllerMotion();
    cursorTracker.connectMotion(delegate(double, double y) {
        state.cursorY = y;
    });
    view.scrolled.addController(cursorTracker);
}

private class ScrollState
{
    CatalogueView view;

    double dragStartScroll = 0;
    double velocity = 0;
    double lastDragY = 0;
    bool coasting = false;
    double scrollVelocity = 0;
    bool scrollCoasting = false;

    double cursorY = 0;

    this(CatalogueView view)
    {
        this.view = view;
    }

    void onDragBegin(double x, double y)
    {
        coasting = false;
        scrollCoasting = false;
        velocity = 0;
        Adjustment adj = view.scrolled.getVadjustment();
        if (adj !is null)
            dragStartScroll = adj.value;
        lastDragY = 0;
    }

    void onDragUpdate(double offsetX, double offsetY)
    {
        view.dragged = true;
        velocity = offsetY - lastDragY;
        lastDragY = offsetY;
        view.scrollTo(dragStartScroll - offsetY);
    }

    void onDragEnd(double offsetX, double)
    {
        view.dragged = false;
        if (abs(velocity) > 2.0)
        {
            coasting = true;
            coastTick();
        }
    }


    void coastTick()
    {
        if (!coasting)
            return;
        velocity *= 0.85;
        if (abs(velocity) < 0.5)
        {
            coasting = false;
            return;
        }
        Adjustment adj = view.scrolled.getVadjustment();
        if (adj !is null)
            view.scrollTo(adj.value - velocity);
        timeoutAdd(0, 16, delegate bool() {
            coastTick();
            return false;
        });
    }

    bool onScroll(double dx, double dy)
    {
        coasting = false;
        scrollVelocity += dy * 15.0;
        if (!scrollCoasting)
        {
            scrollCoasting = true;
            scrollCoastTick();
        }
        return true;
    }

    void scrollCoastTick()
    {
        if (!scrollCoasting)
            return;
        Adjustment adj = view.scrolled.getVadjustment();
        if (adj !is null)
            view.scrollTo(adj.value + scrollVelocity);
        scrollVelocity *= 0.80;
        if (abs(scrollVelocity) < 0.3)
        {
            scrollCoasting = false;
            scrollVelocity = 0;
            return;
        }
        timeoutAdd(0, 16, delegate bool() {
            scrollCoastTick();
            return false;
        });
    }
}
