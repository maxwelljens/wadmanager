# ![gibman](/logo.png "gibman")

## What is gibman?

`gibman` is a command line interface (CLI) management tool for WADs to use with
DOOM. Its primary use is for quickly and easily launching DOOM with presets,
managed through an easy TOML configuration file.

## How do I use gibman?

```
Usage:
  gibman [OPTIONS]
Options:
  -h, --help                         Print this information
  --help-syntax                      Program interface details
  -a=, --arguments=  strings  {}     Pass additional arguments to engine
  -p=, --preset=     string   ""     Specify preset to run DOOM with
  -v, --version      bool     false  Print version information
```

Running `gibman` without any arguments launches the default IWAD and engine
specified in the configuration file. `-p, --preset` takes a string, which is
the name of a preset you specify in the configuration file. For example, entry
`[preset.foobar]` in the configuration can be invoked with `gibman -p foobar`.
More information on usage is available in the man page (*doc/gibman.1*) and in
the configuration file.

## Licence

This project is licensed under [European Union Public Licence
1.2](https://joinup.ec.europa.eu/collection/eupl/eupl-text-eupl-12).
