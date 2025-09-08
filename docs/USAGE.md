> **Warning:** Some Balbismo requires external LLVM tools to be installed: `clang`, `llc`, `opt`, and `lli`. Ensure these are available in your system PATH before using the compiler.

# Balbismo Compiler Usage Guide

## Overview
Balbismo is a compiler for the Balbismo language, supporting multiple compilation and execution modes via LLVM tools. This guide explains all available options, parameters, and usage examples.

## Command Syntax

```
balbismo <mode> <file> [args]
```
- `<mode>`: Compilation or execution mode (see below)
- `<file>`: Input `.balbismo` source file
- `[args]`: Extra arguments for underlying tools (optional)

## Modes

### gen-ir
Generates LLVM IR code from the source file.
- Output: `build/main.ll` (default) or as specified with `-o <file>`
- No extra arguments passed to tools

### opt-ir
Generates optimized LLVM IR code using `opt`.
- Output: `build/main.ll` (default) or as specified with `-o <file>`
- Extra arguments passed to `opt`
> [!WARNING]
> This mode requires `opt` to be installed and available in your system PATH.

### gen-asm
Generates assembly code using `llc`.
- Output: `build/main.s` (default) or as specified with `-o <file>`
- Extra arguments passed to `llc`
> [!WARNING]
> This mode requires `llc` to be installed and available in your system PATH.

### compile
Compiles to a native binary using `clang`.
- Output: `build/main` (default) or as specified with `-o <file>`
- Extra arguments passed to `clang`
> [!WARNING]
> This mode requires `clang` to be installed and available in your system PATH.

### run
Generates IR and interprets it using `lli`.
- No output file generated
- Extra arguments passed to `lli`
> [!WARNING]
> This mode requires `lli` to be installed and available in your system PATH.

## Parameters

- `<file>`: Path to the `.balbismo` source file
- `-o <file>`: Specify output file path (optional)
- `[args]`: Additional arguments for the underlying tool (optional)

## Examples

```
balbismo gen-ir program.balbismo
balbismo opt-ir program.balbismo -o optimized.ll
balbismo gen-asm program.balbismo -o main.s
balbismo compile program.balbismo -o main
balbismo run program.balbismo
```

## Notes
- Default output files are placed in the `build/` directory.
- Extra arguments are only passed to the underlying tool for `opt-ir`, `gen-asm`, `compile`, and `run` modes.
- For more details, see the implementation in `src/lib/main.dart`.
