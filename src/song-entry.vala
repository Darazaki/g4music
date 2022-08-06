namespace Music {

    public class SongEntry : Gtk.Box {

        private Gtk.Image _cover = new Gtk.Image ();
        private Gtk.Label _title = new Gtk.Label (null);
        private Gtk.Label _subtitle = new Gtk.Label (null);
        private Gtk.Image _playing = new Gtk.Image ();
        private CoverPaintable _paintable = new CoverPaintable ();
        private Song? _song = null;

        public SongEntry () {
            margin_top = 4;
            margin_bottom = 4;

            _cover.pixel_size = 48;
            _cover.paintable = new RoundPaintable (_paintable, 5);
            _paintable.queue_draw.connect (_cover.queue_draw);
            append (_cover);

            var vbox = new Gtk.Box (Gtk.Orientation.VERTICAL, 8);
            vbox.hexpand = true;
            vbox.margin_start = 16;
            vbox.margin_end = 4;
            vbox.append (_title);
            vbox.append (_subtitle);
            append (vbox);

            _title.halign = Gtk.Align.START;
            _title.margin_top = 4;
            _title.ellipsize = Pango.EllipsizeMode.END;
            _title.add_css_class ("caption-heading");

            _subtitle.halign = Gtk.Align.START;
            _subtitle.valign = Gtk.Align.CENTER;
            _subtitle.ellipsize = Pango.EllipsizeMode.END;
            _subtitle.add_css_class ("caption");
            _subtitle.add_css_class ("dim-label");

            _playing.valign = Gtk.Align.CENTER;
            _playing.icon_name = "media-playback-start-symbolic";
            _playing.pixel_size = 12;
            _playing.add_css_class ("dim-label");
            append (_playing);

            var long_press = new Gtk.GestureLongPress ();
            long_press.pressed.connect (show_popover);
            var right_click = new Gtk.GestureClick ();
            right_click.button = Gdk.BUTTON_SECONDARY;
            right_click.pressed.connect (show_popover);
            add_controller (long_press);
            add_controller (right_click);
        }

        public Gdk.Paintable? cover {
            set {
                _paintable.paintable = value;
            }
        }

        public bool playing {
            set {
                _playing.visible = value;
            }
        }

        public void update (Song song) {
            _song = song;
            _title.label = song.artist + " - " + song.title;
            _subtitle.label = song.album;
        }

        private void show_popover () {
            var app = (Application) GLib.Application.get_default ();
            var song = _song;
            app.popover_song = song;

            var menu = new Menu ();
            menu.append (_("Show Album"), "app.show-album");
            menu.append (_("Show Artist"), "app.show-artist");
            menu.append (_("_Show In Files"), ACTION_APP + ACTION_OPENDIR);

            var popover = new Gtk.PopoverMenu.from_model (menu);
            popover.autohide = true;
            popover.set_parent (this);
            popover.closed.connect (() => {
                Idle.add (() => {
                    if (app.popover_song == song)
                        app.popover_song = null;
                    return false;
                });
            });
            popover.popup ();
        }
    }
}
