namespace Music {

    public class LruCache<V> : Object {
        private static uint MAX_SIZE = 50 * 1024 * 1024;

        private size_t _size = 0;
        private List<string> _accessed = new List<string> ();
        private HashTable<string, V> _cache = new HashTable<string, V> (str_hash, str_equal);

        public V? find (string key) {
            var value = _cache.get (key);
            if (value != null) {
                access_order (key);
            }
            return value;
        }

        public void put (string key, V value) {
            var size = size_of_value (value);
            while (_size + size > MAX_SIZE && _accessed.length () > 0) {
                unowned var first = _accessed.first ();
                remove (first.data);
                _accessed.remove_link (first);
            }

            var cur = _cache.get (key);
            if (cur != null) {
                _size -= size_of_value (cur);
            }
            _cache.set (key, value);
            _size += size;
            access_order (key);
            //  print (@"cache size: $(_size)\n");
        }

        public bool remove (string key) {
            var value = _cache.get (key);
            if (value != null) {
                _size -= size_of_value (value);
            }
            return _cache.remove (key);
        }

        protected virtual size_t size_of_value (V value) {
            return 1;
        }

        private void access_order (string key) {
            _accessed.remove_link (_accessed.find_custom (key, strcmp));
            _accessed.append (key);
        }
    }

    public class Thumbnailer : LruCache<Gdk.Paintable> {
        private Gnome.DesktopThumbnailFactory _factory = 
            new Gnome.DesktopThumbnailFactory (Gnome.DesktopThumbnailSize.LARGE);

        private GenericSet<string> _loading = new GenericSet<string> (str_hash, str_equal);

        public async Gdk.Paintable? load_async (Song? song) {
            var url = song?.url;
            if (url == null || _loading.contains (url))
                return null;

            _loading.add (url);
            var texture = yield load_directly_async (song, 96);
            _loading.remove (url);
            if (texture != null) {
                put (url, texture);
                return texture;
            }

            string text = parse_abbreviation (song.album);
            var paintable = new TextPaintable (text);
            put (url, paintable);
            return paintable;
        }

        protected Gdk.Pixbuf? load_directly (Song song, int size = 0) {
            var url = song.url;
            try {
                var path = Gnome.DesktopThumbnail.path_for_uri (url, Gnome.DesktopThumbnailSize.LARGE);
                var stream = File.new_for_path (path).read ();
                var bis = new BufferedInputStream (stream);
                var pixbuf = new Gdk.Pixbuf.from_stream (bis, null);
                if (pixbuf != null) {
                    song.thumbnail = path;
                    //  print ("Load thumbnail: %s\n", song.title);
                    return create_clamp_pixbuf (pixbuf, size);
                }
            } catch (Error e) {
                //  warning ("Load %s: %s\n", song.thumbnail, e.message);
            }

            if (song.mtime == 0) try {
                var file = File.new_for_uri (url);
                var info = file.query_info ("time::modified", FileQueryInfoFlags.NOFOLLOW_SYMLINKS);
                song.mtime = (long) (info.get_modification_date_time ()?.to_unix () ?? 0);
                if (!_factory.has_valid_failed_thumbnail (url, song.mtime)) {
                    var pixbuf = _factory.generate_thumbnail (url, song.type);
                    if (pixbuf != null) {
                        var pixbuf2 = create_clamp_pixbuf (pixbuf, size);
                        //  print ("Generate thumbnail: %s\n", song.title);
                        _factory.save_thumbnail (pixbuf, url, song.mtime);
                        return pixbuf2;
                    } else {
                        _factory.create_failed_thumbnail (url, song.mtime);
                    }
                }
            } catch (Error e) {
                //  warning ("Generate %s: %s\n", url, e.message);
            }
            return null;
        }

        public async Gdk.Paintable? load_directly_async (Song song, int size = 0) {
            var pixbuf = yield run_task_async<Gdk.Pixbuf?> (() => {
                return load_directly (song, size);
            });
            return pixbuf != null ? Gdk.Texture.for_pixbuf (pixbuf) : null;
        }

        public void update_text_paintable (Song song) {
            var url = song.url;
            var paintable = find (url);
            if (paintable is TextPaintable) {
                string text = parse_abbreviation (song.album);
                paintable = new TextPaintable (text);
                remove (url);
                put (url, paintable);
            }
        }

        protected override size_t size_of_value (Gdk.Paintable paintable) {
            if (paintable is TextPaintable) {
                return (paintable as TextPaintable)?.text?.length ?? 0;
            }
            return paintable.get_intrinsic_width () * paintable.get_intrinsic_height () * 4;
        }
    }

    public static Gdk.Pixbuf create_clamp_pixbuf (Gdk.Pixbuf pixbuf, int size) {
        var width = pixbuf.width;
        var height = pixbuf.height;
        if (size > 0 && width > size && height > size) {
            var scale = width > height ? (size / (double) height) : (size / (double) width);
            var dx = (int) (width * scale + 0.5);
            var dy = (int) (height * scale + 0.5);
            var newbuf = pixbuf.scale_simple (dx, dy, Gdk.InterpType.TILES);
            if (newbuf != null)
                return newbuf;
        }
        return pixbuf;
    }

    public static Gdk.Pixbuf? load_clamp_pixbuf (Bytes image, int size) {
        try {
            var stream = new MemoryInputStream.from_bytes (image);
            var pixbuf = new Gdk.Pixbuf.from_stream (stream);
            return create_clamp_pixbuf (pixbuf, size);
        } catch (Error e) {
        }
        return null;
    }
}