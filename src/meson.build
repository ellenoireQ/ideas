window_ui = custom_target(
  'window-ui',
  input: 'window.blp',
  output: 'window.ui',
  command: [
    'sh',
    '-c', 'blueprint-compiler compile "$1" > "$2"',
    'sh',
    '@INPUT@',
    '@OUTPUT@',
  ],
)

shortcuts_dialog_ui = custom_target(
  'shortcuts-dialog-ui',
  input: 'shortcuts-dialog.blp',
  output: 'shortcuts-dialog.ui',
  command: [
    'sh',
    '-c', 'blueprint-compiler compile "$1" > "$2"',
    'sh',
    '@INPUT@',
    '@OUTPUT@',
  ],
)

ideas_sources = [
  'main.vala',
  'application.vala',
  'window.vala',
  'utils/version.vala',
  'utils/environment.vala',
]

ideas_deps = [
  config_dep,
  dependency('gtk4'),
  dependency('libadwaita-1', version: '>= 1.4'),
]

ideas_sources += gnome.compile_resources(
  'ideas-resources',
  'ideas.gresource.xml',
  c_name: 'ideas',
  dependencies: [window_ui, shortcuts_dialog_ui],
)

executable(
  'ideas',
  ideas_sources,
  dependencies: ideas_deps,
  include_directories: config_inc,
  install: true,
)
