# mavryk-snoop
Summary line: Benchmark and inference tool.

## Overview
- The purpose of `mavryk-snoop` is to provide a CLI to the library
  `mavryk-benchmark` and to the various benchmarks defined througout
  the code. It also provides means to display benchmark and inference
  results and to generate reports.

## Implementation Details
- The entrypoint is in the file `main_snoop.ml`.
- The modules `Cmdline` and `Commands` contain respectively type
  definitions and `mavryk-clic` command definitions.
- The module `Display` allows to construct plots.
- The module `Report` allows to generate reports in the `latex` language.
- The `latex` sub-library is a think abstraction over latex documents.
