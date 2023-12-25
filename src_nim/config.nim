# Program written by Maxwell Jensen (c) 2022
# Licensed under European Union Public Licence 1.2.
# For more information, consult README.md or man page
#
# This is the default configuration for config.toml, which is loaded into the
# file system of the user, if one does not already exist.

const config* = """
# This is the default config file for GibMan. Refer to README.md or man page
# for further information on how to configure your instance of GibMan.

[iwad]
# You can specify path(s) for all IWADs, which will allow you to use
# relative paths for IWAD entries, instead of absolute paths.
iwad_paths = [
"/path/to/iwads"
]
# Whether search for contents in path(s) specified in iwad_paths should be
# recursive. Can make GibMan very slow to launch if specified path(s) contains
# many files and directories.
recursive_search = false
# Default IWAD to use when running GibMan with no arguments or a preset that
# does not specify an engine to use. The name refers to an entry in iwad.list,
# not the file on the system.
default_iwad = "doom"

[iwad.list]
# Relative paths do not need to be exact and are case insensitive, so "doom2"
# should work just as fine as "DOOM2.WAD". Absolute paths, on the other hands,
# must be exact.
doom = "doom"
doom2 = "/path/to/DOOM2.WAD"
tnt = ""
plutonia = ""
heretic = ""
hexen = ""
strife = ""

[engine]
# Default engine to use when running GibMan with no arguments or a preset that
# does not specify an engine to use.
default_engine = "gzdoom"
# You do not need to change anything here if your engine is already in PATH on
# your system. If not, write down the exact path to it.
gzdoom = ""
zdoom = ""
boom = "/path/to/boom"

[wad]
# You can specify path(s) for all WADs, which will allow you to use
# relative paths for WAD entries, instead of absolute paths, just like with
# IWADs, as specified in [iwad].
wad_paths = [
  "/home/Games/DOOM/",
]
# Same as in [iwad], but for WADs
recursive_search = false

[wad.list]
# Specify WAD names and where they reside
# The path can be absolute, like so (as always, must be exact):
wad1 = "/path/to/foobar.wad"
# Or relative, if you have specified a WAD directory (wad_paths in [wad], see
# above):
wad2 = "wad2"

[preset]
# Non-functional example preset outlined below, which you can invoke by
# running 'gibman -p example'
# You can omit iwad and engine values if you specified default_iwad and
# default_engine in [preset] (see above)
# Preset names can be anything as long as they are only alphanumeric
# characters, underscores, and hyphens
[preset.example]
iwad = "doom2"
engine = "gzdoom"
note = "If you got a lot of presets, you can write notes to help yourself"
wads = [
  # You can use paths for anonymous WADs, or names in [wad.list].
  # Load order is top to bottom.
  "wad1",
  "wad2",
  "/path/to/example.wad"
]"""
