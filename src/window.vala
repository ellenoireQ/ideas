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
  private bool updating_preview = false;
  private uint preview_timeout = 0;
  private Gtk.TextTag? heading1_tag = null;
  private Gtk.TextTag? heading2_tag = null;
  private Gtk.TextTag? heading3_tag = null;
  private Gtk.TextTag? heading4_tag = null;
  private Gtk.TextTag? heading5_tag = null;
  private Gtk.TextTag? heading6_tag = null;
  private Gtk.TextTag? paragraph_tag = null;
  private Gtk.TextTag? hidden_tag = null;

  [GtkChild]
  private unowned Gtk.TextView preview_text_view;

  private uint autosave_timeout = 0;

  public Window (Gtk.Application app) {
    Object (application : app);
  }

  construct {
    var buffer = preview_text_view.get_buffer ();
    
    preview_text_view.add_css_class ("markdown-preview");
    
    setup_text_tags ();

    buffer.changed.connect (() => {
      if (updating_preview) {
        return;
      }

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

  private void setup_text_tags () {
    var buffer = preview_text_view.get_buffer ();

    heading1_tag = buffer.create_tag ("heading1", 
      "weight", Pango.Weight.BOLD, 
      "scale", 2.0);
    
    heading2_tag = buffer.create_tag ("heading2", 
      "weight", Pango.Weight.BOLD, 
      "scale", 1.6);
    
    heading3_tag = buffer.create_tag ("heading3", 
      "weight", Pango.Weight.BOLD, 
      "scale", 1.35);
    
    heading4_tag = buffer.create_tag ("heading4", 
      "weight", Pango.Weight.BOLD, 
      "scale", 1.2);
    
    heading5_tag = buffer.create_tag ("heading5", 
      "weight", Pango.Weight.BOLD, 
      "scale", 1.1);
    
    heading6_tag = buffer.create_tag ("heading6", 
      "weight", Pango.Weight.BOLD, 
      "scale", 1.0);
    
    paragraph_tag = buffer.create_tag ("paragraph");
    
    hidden_tag = buffer.create_tag ("hidden", 
      "foreground", "#00000000", 
      "size", 1);
  }

  private void on_text_changed () {
    if (updating_preview) {
      return;
    }

    // Debounce the styling application to prevent blinking
    if (preview_timeout != 0) {
      Source.remove (preview_timeout);
    }

    preview_timeout = Timeout.add (150, () => {
      preview_timeout = 0;

      var buffer = preview_text_view.get_buffer ();
      Gtk.TextIter start, end;
      buffer.get_bounds (out start, out end);
      string text = buffer.get_text (start, end, false);

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

  private void apply_inline_styles (string text) {
    if (updating_preview) {
      return;
    }

    updating_preview = true;

    try {
      var buffer = preview_text_view.get_buffer ();

      // Save cursor position before making changes
      Gtk.TextMark insert_mark = buffer.get_insert ();
      Gtk.TextIter cursor_pos;
      buffer.get_iter_at_mark (out cursor_pos, insert_mark);
      int cursor_offset = cursor_pos.get_offset ();

      // Remove all existing tags
      Gtk.TextIter start, end;
      buffer.get_bounds (out start, out end);
      buffer.remove_all_tags (start, end);

      // Parse with valamark
      var valamark = new Valamark.from_text (text);
      ParsedElement[] elements = valamark.value ();

      // Process each line in the buffer and match with parsed elements
      string[] lines = text.split ("\n");
      int element_idx = 0;

      for (int line_num = 0; line_num < lines.length; line_num++) {
        string line = lines[line_num];
        string trimmed = line.strip ();

        // Skip empty lines
        if (trimmed == "") {
          continue;
        }

        // Get buffer iterators for this line
        Gtk.TextIter line_start, line_end;
        buffer.get_iter_at_line (out line_start, line_num);
        line_end = line_start;
        if (!line_end.ends_line ()) {
          line_end.forward_to_line_end ();
        }

        // Find matching element by content
        ParsedElement? matched_element = null;
        if (element_idx < elements.length) {
          var elem = elements[element_idx];
          print ("%s", elem.to_string ());
          // Check if this line's content matches the element's content
          if (trimmed.contains (elem.content) || elem.content.contains (trimmed.replace ("#", "").strip ())) {
            matched_element = elem;
            element_idx++;
          }
        }

        // Apply styling based on what we find in the line directly
        if (line.has_prefix ("#")) {
          int level = 0;
          int char_pos = 0;

          while (char_pos < line.length && line[char_pos] == '#' && level < 6) {
            level++;
            char_pos++;
          }

          // Skip space after #
          if (char_pos < line.length && line[char_pos] == ' ') {
            char_pos++;
          }

          // Hide the # markers and space
          if (char_pos > 0) {
            Gtk.TextIter marker_end = line_start;
            marker_end.forward_chars (char_pos);
            buffer.apply_tag (hidden_tag, line_start, marker_end);
          }

          // Apply heading style to remaining text
          if (char_pos < line.length) {
            Gtk.TextIter text_start = line_start;
            text_start.forward_chars (char_pos);

            Gtk.TextTag? tag = null;
            switch (level) {
            case 1 : tag = heading1_tag; break;
            case 2 : tag = heading2_tag; break;
            case 3 : tag = heading3_tag; break;
            case 4 : tag = heading4_tag; break;
            case 5 : tag = heading5_tag; break;
            case 6 : tag = heading6_tag; break;
            }

            if (tag != null) {
              buffer.apply_tag (tag, text_start, line_end);
            }
          }
        } else {
          // Regular paragraph
          if (paragraph_tag != null) {
            buffer.apply_tag (paragraph_tag, line_start, line_end);
          }
        }
      }

      // Restore cursor position
      Gtk.TextIter new_cursor_pos;
      buffer.get_iter_at_offset (out new_cursor_pos, cursor_offset);
      buffer.place_cursor (new_cursor_pos);
    } catch (Error e) {
      warning ("Error applying styles: %s", e.message);
    } finally {
      updating_preview = false;
    }
  }
}
