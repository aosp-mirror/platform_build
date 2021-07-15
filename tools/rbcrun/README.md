# Roboleaf configuration files interpreter

Reads and executes Roboleaf product configuration files.

## Usage

`rbcrun` *options* *VAR=value*... [ *file* ]

A Roboleaf configuration file is a Starlark script. Usually it is read from *file*. The option `-c` allows to provide a
script directly on the command line. The option `-f` is there to allow the name of a file script to contain (`=`).
(i.e., `my=file.rbc` sets `my` to `file.rbc`, `-f my=file.rbc` runs the script from `my=file.rbc`).

### Options

`-d` *dir*\
Root directory for load("//path",...)

`-c` *text*\
Read script from *text*

`--perf` *file*\
Gather performance statistics and save it to *file*. Use \
`       go tool prof -top`*file*\
to show top CPU users

`-f` *file*\
File to run.

## Extensions

The runner allows Starlark scripts to use the following features that Bazel's Starlark interpreter does not support:

### Load statement URI

Starlark does not define the format of the load statement's first argument.
The Roboleaf configuration interpreter supports the format that Bazel uses
(`":file"` or `"//path:file"`). In addition, it allows the URI to end with
`"|symbol"` which defines a single variable `symbol` with `None` value if a
module does not exist. Thus,

```
load(":mymodule.rbc|init", mymodule_init="init")
```

will load the module `mymodule.rbc` and export a symbol `init` in it as
`mymodule_init` if `mymodule.rbc` exists. If `mymodule.rbc` is missing,
`mymodule_init` will be set to `None`

### Predefined Symbols

#### rblf_env

A `struct` containing environment variables. E.g., `rblf_env.USER` is the username when running on Unix.

#### rblf_cli

A `struct` containing the variable set by the interpreter's command line. That is, running

```
rbcrun FOO=bar myfile.rbc
```

will have the value of `rblf_cli.FOO` be `"bar"`

### Predefined Functions

#### rblf_file_exists(*file*)

Returns `True`  if *file* exists

#### rblf_wildcard(*glob*, *top* = None)

Expands *glob*. If *top* is supplied, expands "*top*/*glob*", then removes
"*top*/" prefix from the matching file names.

#### rblf_regex(*pattern*, *text*)

Returns *True* if *text* matches *pattern*.

#### rblf_shell(*command*)

Runs `sh -c "`*command*`"`, reads its output, converts all newlines into spaces, chops trailing newline returns this
string. This is equivalent to Make's
`shell` builtin function. *This function will be eventually removed*.
