# Dependency Mapper

[dependency-mapper] command line tool. This tool finds the usage based dependencies between java
files by utilizing byte-code and java file analysis.

# Getting Started

## Inputs
* rsp file, containing list of java files separated by whitespace.
* jar file, containing class files generated after compiling the contents of rsp file.

## Output
* proto file, representing the list of dependencies for each java file present in input rsp file,
represented by [proto/usage.proto]

## Usage
```
dependency-mapper --src-path [src-list.rsp] --jar-path [classes.jar] --usage-map-path [usage-map.proto]"
```

# Notes
## Dependencies enlisted are only within the java files present in input.
## Ensure that [SourceFile] is present in the classes present in the jar.
## To ensure dependencies are listed correctly
* Classes jar should only contain class files generated from the source rsp files.
* Classes jar should not exclude any class file that was generated from source rsp files.