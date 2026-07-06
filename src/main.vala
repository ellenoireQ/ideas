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

int main (string[] args) {
  var config = new Env ();

  Intl.bindtextdomain (Config.GETTEXT_PACKAGE, Config.LOCALEDIR);
  Intl.bind_textdomain_codeset (Config.GETTEXT_PACKAGE, "UTF-8");
  Intl.textdomain (Config.GETTEXT_PACKAGE);

  string cache = Path.build_filename (
                                      Environment.get_user_cache_dir (),
                                      UtilsVersion.app_pkg_name,
                                      "autosave"
  );

  if (FileUtils.test (cache, FileTest.IS_DIR)) {
    print ("Folder already exists\n");
    config.set (EVar.CACHE_FOLDER, true);
  } else {
    if (DirUtils.create_with_parents (cache, 0700) == 0) {
      config.set (EVar.CACHE_FOLDER, true);
      print ("Folder created\n");
    } else {
      config.set (EVar.CACHE_FOLDER, false);
      warning ("Failed to create cache directory: %s", cache);
    }
  }

  var app = new Ideas.Application ();
  return app.run (args);
}
