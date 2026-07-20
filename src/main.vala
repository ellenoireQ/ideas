/* main.vala
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

using Gtk;
int main (string[] args) {
  var app = new Ideas.Application ();

  Intl.bindtextdomain (Config.GETTEXT_PACKAGE, Config.LOCALEDIR);
  Intl.bind_textdomain_codeset (Config.GETTEXT_PACKAGE, "UTF-8");
  Intl.textdomain (Config.GETTEXT_PACKAGE);

  var css_provider = new CssProvider ();
  try {
    css_provider.load_from_resource ("/com/ellenoireq/ideas/style.css");

    StyleContext.add_provider_for_display (
                                           Gdk.Display.get_default (),
                                           css_provider,
                                           Gtk.STYLE_PROVIDER_PRIORITY_USER
    );
  } catch (Error e) {
    stderr.printf ("Failed to load CSS: %s\n", e.message);
  }

  string cache = Path.build_filename (
                                      Environment.get_user_cache_dir (),
                                      UtilsVersion.app_pkg_name,
                                      "autosave"
  );


  if (FileUtils.test (cache, FileTest.IS_DIR)) {
    print ("Folder already exists\n");
    app.config.has_folder = true;
    app.config.cache_path = cache;
  } else {
    if (DirUtils.create_with_parents (cache, 0700) == 0) {
      app.config.has_folder = true;
      app.config.cache_path = cache;
      print ("Folder created\n");
    } else {
      app.config.has_folder = false;

      warning ("Failed to create cache directory: %s", cache);
    }
  }

  return app.run (args);
}
