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
  private bool updating_preview = false;
  private uint preview_timeout = 0;
  private Gtk.TextTag? heading1_tag = null;
  private Gtk.TextTag? heading2_tag = null;
  private Gtk.TextTag? heading3_tag = null;
  private Gtk.TextTag? heading4_tag = null;
  private Gtk.TextTag? heading5_tag = null;
  private Gtk.TextTag? heading6_tag = null;
  private Gtk.TextTag? hidden_tag = null;

  [GtkChild]
  private unowned Gtk.TextView preview_text_view;

  private uint autosave_timeout = 0;

  public Window (Gtk.Application app) {
    Object (application : app);
  }

  construct {
    var buffer = preview_text_view.get_buffer ();
    setup_preview_tags ();

    buffer.changed.connect (() => {
      on_text_changed ();

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
    if (updating_preview) {
      return;
    }

    var buffer = preview_text_view.get_buffer ();
    Gtk.TextIter start, end;
    buffer.get_bounds (out start, out end);

    string text = buffer.get_text (start, end, false);
    print ("Current live text: %s\n", text);

    if (preview_timeout != 0) {
      Source.remove (preview_timeout);
    }

    preview_timeout = Timeout.add (300, () => {
      preview_timeout = 0;
      apply_inline_styles (text);

      return Source.REMOVE;
    });
  }

  private void autosave () {
    var buffer = preview_text_view.get_buffer ();
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

  private void setup_preview_tags () {
    var preview_buffer = preview_text_view.get_buffer ();

    heading1_tag = preview_buffer.create_tag ("heading1", "weight", Pango.Weight.BOLD, "scale", 2.0);
    heading2_tag = preview_buffer.create_tag ("heading2", "weight", Pango.Weight.BOLD, "scale", 1.6);
    heading3_tag = preview_buffer.create_tag ("heading3", "weight", Pango.Weight.BOLD, "scale", 1.35);
    heading4_tag = preview_buffer.create_tag ("heading4", "weight", Pango.Weight.BOLD, "scale", 1.2);
    heading5_tag = preview_buffer.create_tag ("heading5", "weight", Pango.Weight.BOLD, "scale", 1.1);
    heading6_tag = preview_buffer.create_tag ("heading6", "weight", Pango.Weight.BOLD, "scale", 1.0);
    hidden_tag = preview_buffer.create_tag ("hidden", "invisible", true);
  }

  private void apply_inline_styles (string text) {
    updating_preview = true;

    try {
      var buffer = preview_text_view.get_buffer ();

      buffer.begin_user_action ();

      Gtk.TextIter start, end;
      buffer.get_bounds (out start, out end);
      buffer.remove_all_tags (start, end);

      int total_lines = buffer.get_line_count ();

      for (int line_num = 0; line_num < total_lines; line_num++) {
        Gtk.TextIter line_start, line_end;
        buffer.get_iter_at_line (out line_start, line_num);
        line_end = line_start;

        if (!line_end.ends_line ()) {
          line_end.forward_to_line_end ();
        }

        string line = buffer.get_text (line_start, line_end, false);

        if (line.has_prefix ("#")) {
          int hash_count = 0;
          int char_pos = 0;

          while (char_pos < line.length && line[char_pos] == '#') {
            hash_count++;
            char_pos++;
          }

          int first_non_hash = char_pos;

          while (first_non_hash < line.length && line[first_non_hash].isspace ()) {
            first_non_hash++;
          }

          bool valid_heading = hash_count > 0 && hash_count <= 6;

          if (valid_heading && first_non_hash == char_pos && first_non_hash < line.length) {
            valid_heading = false;
          }

          if (valid_heading) {
            Gtk.TextTag? tag = null;

            switch (hash_count) {
            case 1 :
              tag = heading1_tag;
              break;
            case 2 :
              tag = heading2_tag;
              break;
            case 3 :
              tag = heading3_tag;
              break;
            case 4 :
              tag = heading4_tag;
              break;
            case 5 :
              tag = heading5_tag;
              break;
            case 6 :
              tag = heading6_tag;
              break;
            }

            if (tag != null) {
              Gtk.TextIter marker_end = line_start;
              marker_end.forward_chars (first_non_hash);
              buffer.apply_tag (hidden_tag, line_start, marker_end);

              if (first_non_hash < line.length) {
                Gtk.TextIter text_start = line_start;
                text_start.forward_chars (first_non_hash);
                buffer.apply_tag (tag, text_start, line_end);
                print ("  Applied heading%d tag\n", hash_count);
              }
            }
          }
        }
      }

      buffer.end_user_action ();
    } finally {
      updating_preview = false;
    }
  }
}
