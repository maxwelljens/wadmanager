# Program written by Maxwell Jensen (c) 2022
# Licensed under European Union Public Licence 1.2.
# For more information, consult README.md or man page

import cligen, config, parsetoml, sequtils, strformat, strutils, os, osproc, tables

const Version = """
gibman 0.1.0
Program written by Maxwell Jensen (c) 2022
Licensed under European Union Public Licence 1.2.
For more information, consult README.md or man page"""
const ConfigPath = getConfigDir() / "gibman"
const ConfigFile = ConfigPath / "config.toml"

# Error codes
const miError = """
IWAD entry in config missing, check that your IWAD information is correct"""
const ipwError = """
file in IWAD entry does not seem to exist; double check path name"""
const meError = """
engine at specified location does not seem to exist"""
const npError = """
specified preset not found in config; double check preset name"""
var
  missingIwad: ref KeyError
  iwadPathWrong: ref IOError
  missingEngine: ref IOError
  noPreset: ref KeyError

template error(e: ref CatchableError, s: string) =
  ## Common error handling, put in template to prevent redundancy
  new(e)
  e.msg = s
  raise e

proc confirm(prompt: string, default = false): bool =
  ## Simple yes/no user prompt
  ## `prompt` is the question that is presented to the user
  ## `default` is whether no input means "no" (`false`) or "yes" (`true`)

  var yn: string
  case default
  of false: yn = "(y/N)"
  of true: yn = "(Y/n)"
  echo &"{prompt} {yn}"
  let userInput = readLine(stdin)
  if userInput == "":
    return default
  elif userInput[0] in ['y', 'Y']:
    return true
  else:
    return false

proc initConfig(): TomlValueRef =
  ## If a configuration already exists, try to read from it when running
  ## GibMan. Otherwise, start procedures for creating a new one from default
  ## configuration info.

  case fileExists(ConfigFile)
  of true: return parseFile(ConfigFile)
  of false:
    echo &"Configuration file at {ConfigPath} does not exist."
    case confirm("Would you like to create one right now?")
    of true:
      createDir(ConfigPath)
      writeFile(ConfigFile, config.config)
      echo "config.toml successfully created. You can now edit the file."
      quit(1)
    of false: quit(1)

proc findIwad(config, search: TomlValueRef): string =
  ## Validate IWAD search and give a useful error message if there is an issue
  ## This function checks paths in the config file under iwad_paths if user
  ## relies on a common IWAD directory
  ## `config` is the config file
  ## `search` is the IWAD to look for

  if getStr(search) == "":
    error(missingIwad, miError)
  # First check if the IWAD is defined as an absolute path in config
  # then check if there is a key that matches `search`
  for key, val in pairs(getTable(config["iwad"]["list"])):
    if isAbsolute($config["iwad"]["list"][key]) and key == $search:
      # Check that the IWAD even exists, throw a useful error otherwise
      if fileExists($config["iwad"]["list"][key]):
        return $val
      else:
        error(iwadPathWrong, ipwError)
  # If nothing turns up, try to search paths outlined in iwad_paths and
  # compare them against the entries in iwad.list
  # Throws an IOError if an entry in iwad_paths is invalid
  if getElems(config["iwad"]["iwad_paths"]) == []:
    echo "Error: no valid absolute paths for default IWAD found, and no entries in iwad_paths. Exiting."
    quit(2)
  # Add ".wad" to search if it doesn't have it already
  let searchWithExt = addFileExt($search, "wad")
  for x in getElems(config["iwad"]["iwad_paths"]):
    case getBool(config["iwad"]["recursive_search"])
    of true:
      for y in walkDirRec($x, checkDir = true):
        if toLower(searchWithExt) in toLower(y):
          return y
    of false:
      for y in walkDir($x, checkDir = true):
        if fileExists(y.path) and toLower(searchWithExt) in toLower(y.path):
          return y.path
  # If procedure has gotten here, no IWAD was found
  echo "Warning: no IWAD has been found. Maybe recursive search is off?"

proc findWads(config: TomlValueRef, preset: string): seq[string] =
  ## Validate WAD search and give a useful error message if there is an issue
  ## This function checks paths in the config file under wad_paths if user
  ## relies on a common WAD directory, and rifles through absolute paths
  ## otherwise.
  ## `config` is the config file
  ## `preset` is the preset name to invoke information from

  # Leaving out the WAD list is not an error
  if hasKey(getTable(config["preset"][preset]), "wads") == false:
    return @[]

  proc addWadArg(wad: string): seq[string] =
    return @["-file", wad]

  let presetWads = getElems(config["preset"][preset]["wads"])
  let wadList = getTable(config["wad"]["list"])
  let wadPaths = getElems(config["wad"]["wad_paths"])
  let extensions = ["wad", "pk3", "zip", "pak"]
  for entry in presetWads:
    # If entry is an absolute path and exists, add it, and move onto the next
    if isAbsolute($entry) and fileExists($entry):
      insert(result, addWadArg($entry))
      continue
  # If entry is not an absolute path, compare it to wad.list in config
  for key, val in wadList:
    # Skip if the item in wad.list is not in presetWads
    if key in $presetWads == false:
      continue
    # First check if the value is an absolute path and exists
    if isAbsolute($val) and fileExists($val):
      insert(result, addWadArg($val))
      continue
    # Otherwise search val in directories in [wad]wad_paths in the config
    for ext in extensions:
      let searchWithExt = addFileExt($val, ext)
      for dir in wadPaths:
        case getBool(config["wad"]["recursive_search"])
        of true:
          for x in walkDirRec($dir, checkDir = true):
            if toLower(searchWithExt) in toLower(x):
              insert(result, addWadArg($x))
              continue
        of false:
          for x in walkDir($dir, checkDir = true):
            if fileExists(x.path) and toLower(searchWithExt) in toLower(x.path):
              insert(result, addWadArg($x.path))
              continue

proc launchDoom(config: TomlValueRef, engine, iwad: string, wads, args: seq[string]) =
  ## This function finds the executable for the engine and launches the
  ## DOOM process. Only information about config, engine, IWAD, WAD(s) and
  ## optional arguments are needed, the rest of the process is handled.
  ## `config` is the configuration file
  ## `engine` is the engine binary to execute
  ## `iwad` is the IWAD to use
  ## `wads` are the list of WADs to use, formatted as command line arguments
  ## `args` are optional additional arguments to pass to the process

  let engineFile = $config["engine"][engine]
  # If no IWAD has been found by `findIwad()`, return an empty array, so
  # that no loose -iwad argument is passed to the process. I do this because
  # I do not know how engines outside of GZDoom/ZDoom react to an empty
  # -iwad argument.
  var iwadArgs: seq[string]
  if iwad == "":
    iwadArgs = @[]
  else:
    iwadArgs = @["-iwad", &"{iwad}"]
  # See if engine is in PATH
  case findExe(engine)
  of "":
  # If engine is not in PATH, we gotta look into the config file and
  # play around with absolute paths
    if not fileExists(engineFile):
      error(missingEngine, meError)
    let (dir, file, ext) = splitFile(engineFile)
    var theExe = file & ext
    normalizeExe(theExe) # If POSIX, add `./`
    discard startProcess(&"{theExe}", &"{dir}", args=concat(iwadArgs, wads, args), options={poUsePath})
  else:
    discard startProcess(&"{engine}", args=concat(iwadArgs, wads, args), options={poUsePath})

proc loadPreset(config: TomlValueRef, preset: string, args: seq[string] = @[]) =
  ## This function loads DOOM from a preset specified in the config file
  ## `config` is the config file
  ## `preset` is the name of the preset that is loaded from the config file
  ## `arguments` are optional additional arguments to pass to the process

  var
    iwad: string
    engine: string
    userPreset: TomlTableRef
  let presetTable = getTable(config["preset"])
  # Give a useful error to user if preset is not found
  if not hasKey(presetTable, preset):
    error(noPreset, npError)
  else:
    userPreset = getTable(presetTable[preset])
  if not hasKey(userPreset, "iwad"):
    iwad = findIwad(config, config["iwad"]["default_iwad"])
  else:
    iwad = findIwad(config, userPreset["iwad"])
  if not hasKey(userPreset, "engine"):
    engine = $config["engine"]["default_engine"]
  else:
    engine = $userPreset["engine"]
  launchDoom(config, engine, iwad, findWads(config, preset), args)

proc startDoom(config: TomlValueRef, args: seq[string] = @[]) =
  ## This function is run when no arguments are passed to GibMan. It will
  ## start the default IWAD with default engine, if set in config file, or in
  ## the command line arguments.
  ## `config` is the config file
  ## `arguments` are optional additional arguments to pass to the process

  let iwad = findIwad(config, config["iwad"]["default_iwad"])
  let engine = $config["engine"]["default_engine"]
  launchDoom(config, engine, iwad, @[], args)

proc argParser(arguments: seq[string] = @[], preset = "", version = false) =
  ## Entry point to the program. All the argument parsing is done here before
  ## anything else in the program is.

  if version:
    echo Version
    return
  if preset != "":
    loadPreset(initConfig(), preset, arguments)
    return
  startDoom(initConfig(), arguments)

dispatch argParser,
  cmdName="gibman",
  doc="A WAD manager for DOOM",
  help={
  "help": "Print this information",
  "help-syntax": "Program interface details",
  "arguments": "Pass additional arguments to engine",
  "preset": "Specify preset to run DOOM with",
  "version": "Print version information"}
