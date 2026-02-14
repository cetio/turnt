module turnt.settings;

import gtk.box;
import gtk.button;
import gtk.separator;
import gtk.types : Align, Orientation;

import turnt.window;

class SettingsOutline : Box
{
    Button settingsBtn;
    Button turntableBtn;

    this()
    {
        super(Orientation.Vertical, 0);

        addCssClass("settings-outline");
        halign = Align.End;
        valign = Align.Fill;
        vexpand = true;
        widthRequest = 36;
        marginEnd = 4;

        settingsBtn = new Button();
        settingsBtn.setIconName("emblem-system-symbolic");
        settingsBtn.addCssClass("flat");
        settingsBtn.addCssClass("top-btn");
        settingsBtn.halign = Align.Center;
        settingsBtn.marginTop = 8;
        append(settingsBtn);

        Separator rule = new Separator(Orientation.Horizontal);
        rule.addCssClass("outline-rule");
        rule.halign = Align.Fill;
        rule.marginTop = 4;
        rule.marginBottom = 4;
        append(rule);

        // Spacer to push turntable button to the bottom
        Box spacer = new Box(Orientation.Vertical, 0);
        spacer.vexpand = true;
        append(spacer);

        turntableBtn = new Button();
        turntableBtn.setIconName("media-optical-symbolic");
        turntableBtn.addCssClass("flat");
        turntableBtn.addCssClass("top-btn");
        turntableBtn.halign = Align.Center;
        turntableBtn.marginBottom = 12;
        turntableBtn.connectClicked(delegate void() {
            if (window !is null && window.turntableStack !is null)
                window.turntableStack.setVisibleChildName("turntable");
        });
        append(turntableBtn);
    }
}
