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

  private Gtk.TextTag[] heading_tags = new Gtk.TextTag[7]; // index 0 is not used
  private Gtk.TextTag? paragraph_tag = null;
  private Gtk.TextTag? list_tag = null;
  private Gtk.TextTag? bold_tag = null;
  private Gtk.TextTag? italic_tag = null;
  private Gtk.TextTag? bold_italic_tag = null;
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

    heading_tags[1] = buffer.create_tag ("h1", "weight", Pango.Weight.BOLD, "scale", 2.0);
    heading_tags[2] = buffer.create_tag ("h2", "weight", Pango.Weight.BOLD, "scale", 1.6);
    heading_tags[3] = buffer.create_tag ("h3", "weight", Pango.Weight.BOLD, "scale", 1.35);
    heading_tags[4] = buffer.create_tag ("h4", "weight", Pango.Weight.BOLD, "scale", 1.2);
    heading_tags[5] = buffer.create_tag ("h5", "weight", Pango.Weight.BOLD, "scale", 1.1);
    heading_tags[6] = buffer.create_tag ("h6", "weight", Pango.Weight.BOLD, "scale", 1.0);

    paragraph_tag = buffer.create_tag ("paragraph");
    list_tag = buffer.create_tag ("list", "left-margin", 20);
    bold_tag = buffer.create_tag ("bold", "weight", Pango.Weight.BOLD);
    italic_tag = buffer.create_tag ("italic", "style", Pango.Style.ITALIC);
    bold_italic_tag = buffer.create_tag ("bold-italic", "weight", Pango.Weight.BOLD, "style", Pango.Style.ITALIC);

    // Hidden tag for markdown markers
    hidden_tag = buffer.create_tag ("hidden", "foreground", "#00000000", "size", 1);
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

      // Save cursor position
      Gtk.TextMark insert_mark = buffer.get_insert ();
      Gtk.TextIter cursor_pos;
      buffer.get_iter_at_mark (out cursor_pos, insert_mark);
      int cursor_offset = cursor_pos.get_offset ();

      // Remove all existing tags
      Gtk.TextIter start, end;
      buffer.get_bounds (out start, out end);
      buffer.remove_all_tags (start, end);

      var valamark = new Valamark.from_text (text);
      ParsedElement[] elements = valamark.value ();

      // Track position in text
      int text_position = 0;

      foreach (var element in elements) {
        Gtk.TextIter elem_start, elem_end;
        int content_start = text.index_of (element.content, text_position);

        if (content_start < 0)
          continue;

        int element_start = content_start - element.offset_start;

        int total_len = element.offset_start
          + element.content_offset
          + element.offset_end;

        buffer.get_iter_at_offset (out elem_start, element_start);
        buffer.get_iter_at_offset (out elem_end, element_start + total_len);
        Gtk.TextTag? tag = null;

        switch (element.token) {
        case TokenType.HASH :
          // Use level to get the right heading tag 1..6
          if (element.level >= 1 && element.level <= 6) {
            tag = heading_tags[element.level];

            var line_start = elem_start;
            line_start.set_line_offset (0);
            var marker_end = line_start;
            marker_end.forward_chars (element.level + 1); // ### + space
            buffer.apply_tag (hidden_tag, line_start, marker_end);
          }
          break;

        case TokenType.STRING :
          tag = paragraph_tag;
          break;

        case TokenType.LIST :
          tag = list_tag;

          if (element.offset_start > 0) {
            Gtk.TextIter marker_begin = elem_start;
            Gtk.TextIter marker_end = elem_start;
            marker_end.forward_chars (element.offset_start);
            buffer.apply_tag (hidden_tag, marker_begin, marker_end);
          }

          Gtk.TextIter content_begin = elem_start;
          content_begin.forward_chars (element.offset_start);
          Gtk.TextIter content_end = elem_start;
          content_end.forward_chars (element.offset_start + element.content_offset);
          buffer.apply_tag (list_tag, content_begin, content_end);

          break;

        case TokenType.BOLD :
          tag = bold_tag;

          Gtk.TextIter start_marker_begin = elem_start;
          Gtk.TextIter start_marker_end = elem_start;
          start_marker_end.forward_chars (element.offset_start);

          buffer.apply_tag (hidden_tag,
                            start_marker_begin,
                            start_marker_end);

          Gtk.TextIter text_begin = elem_start;
          text_begin.forward_chars (element.offset_start);

          Gtk.TextIter text_end = elem_start;
          text_end.forward_chars (element.offset_start
                                  + element.content_offset);

          buffer.apply_tag (bold_tag,
                            text_begin,
                            text_end);

          if (element.offset_end > 0) {
            Gtk.TextIter end_marker_begin = elem_start;
            end_marker_begin.forward_chars (total_len - element.offset_end);

            Gtk.TextIter end_marker_end = elem_start;
            end_marker_end.forward_chars (total_len);

            buffer.apply_tag (hidden_tag,
                              end_marker_begin,
                              end_marker_end);
          }

          break;

        case TokenType.ITALIC :
          tag = italic_tag;

          Gtk.TextIter start_marker_begin_i = elem_start;
          Gtk.TextIter start_marker_end_i = elem_start;
          start_marker_end_i.forward_chars (element.offset_start);

          buffer.apply_tag (hidden_tag,
                            start_marker_begin_i,
                            start_marker_end_i);

          Gtk.TextIter text_begin_i = elem_start;
          text_begin_i.forward_chars (element.offset_start);

          Gtk.TextIter text_end_i = elem_start;
          text_end_i.forward_chars (element.offset_start
                                    + element.content_offset);

          buffer.apply_tag (italic_tag,
                            text_begin_i,
                            text_end_i);

          if (element.offset_end > 0) {
            Gtk.TextIter end_marker_begin_i = elem_start;
            end_marker_begin_i.forward_chars (total_len - element.offset_end);

            Gtk.TextIter end_marker_end_i = elem_start;
            end_marker_end_i.forward_chars (total_len);

            buffer.apply_tag (hidden_tag,
                              end_marker_begin_i,
                              end_marker_end_i);
          }

          break;

        case TokenType.BOLD_ITALIC :
          tag = bold_italic_tag;

          Gtk.TextIter start_marker_begin_bi = elem_start;
          Gtk.TextIter start_marker_end_bi = elem_start;
          start_marker_end_bi.forward_chars (element.offset_start);

          buffer.apply_tag (hidden_tag,
                            start_marker_begin_bi,
                            start_marker_end_bi);

          Gtk.TextIter text_begin_bi = elem_start;
          text_begin_bi.forward_chars (element.offset_start);

          Gtk.TextIter text_end_bi = elem_start;
          text_end_bi.forward_chars (element.offset_start
                                     + element.content_offset);

          buffer.apply_tag (bold_italic_tag,
                            text_begin_bi,
                            text_end_bi);

          if (element.offset_end > 0) {
            Gtk.TextIter end_marker_begin_bi = elem_start;
            end_marker_begin_bi.forward_chars (total_len - element.offset_end);

            Gtk.TextIter end_marker_end_bi = elem_start;
            end_marker_end_bi.forward_chars (total_len);

            buffer.apply_tag (hidden_tag,
                              end_marker_begin_bi,
                              end_marker_end_bi);
          }

          break;
        }

        if (tag != null &&
            element.token != TokenType.BOLD &&
            element.token != TokenType.ITALIC &&
            element.token != TokenType.BOLD_ITALIC &&
            element.token != TokenType.LIST) {
          buffer.apply_tag (tag, elem_start, elem_end);
        }

        // Update position for next search
        text_position = element_start + total_len;
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
