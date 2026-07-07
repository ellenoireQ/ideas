/* window.vala
 *
 * Copyright 2026 elle
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

[GtkTemplate (ui = "/com/ellenoireq/ideas/window.ui")]
public class Ideas.Window : Adw.ApplicationWindow {
  private unowned Env app = Ideas.Application.instance ().config;
  private Valamark pd;


  [GtkChild]
  private unowned Gtk.TextView my_text_view;
  private uint autosave_timeout = 0;

  public Window (Gtk.Application app) {
    Object (application: app);
  }

  construct {
    pd = new Valamark (app.cache_path + "/untitled.md");

    var buffer = my_text_view.get_buffer ();

    buffer.changed.connect (() => {
      on_text_changed ();

      foreach (var element in pd.value ()) {
        print ("%s", element.element);
      }

      if (autosave_timeout != 0) {
        Source.remove (autosave_timeout);
      }

      autosave_timeout = Timeout.add (500, () => {
        autosave_timeout = 0;

        autosave ();

        return Source.REMOVE;
      });
    });
  }

  private void on_text_changed () {
    var buffer = my_text_view.get_buffer ();
    Gtk.TextIter start, end;
    buffer.get_bounds (out start, out end);

    string text = buffer.get_text (start, end, false);
    print ("Current live text: %s\n", text);
  }

  private void autosave () {
    var buffer = my_text_view.get_buffer ();

    Gtk.TextIter start, end;
    buffer.get_bounds (out start, out end);

    string text = buffer.get_text (start, end, false);

    try {
      FileUtils.set_contents (app.cache_path + "/untitled.md", text);
      print ("Autosaved: %s\n", app.cache_path);
    } catch (FileError e) {
      warning ("Autosave failed: %s", e.message);
    }
  }
}
