/// Balbismo Compiler Executable Entry Point
///
/// This is the main executable entry point for the Balbismo programming language compiler.
/// It serves as a thin wrapper that delegates all compilation work to the main library
/// while providing the standard Dart command-line application interface.
///
/// The executable supports all compilation modes and options documented in the main
/// library, including:
/// - LLVM IR generation (`gen-ir`)
/// - Optimized IR generation (`opt-ir`)
/// - Assembly code generation (`gen-asm`)
/// - Binary compilation (`compile`)
/// - Direct execution (`run`)
///
/// Usage:
/// ```bash
/// dart run balbismo <mode> <file> [args]
/// ```
///
/// Parameters:
/// - [arguments]: Command line arguments passed from the operating system
///
/// See also:
/// - [main] in `lib/main.dart` for detailed compilation pipeline documentation
import 'package:balbismo/main.dart' as entrypoint;

/// Main executable entry point that delegates to the core compilation logic.
///
/// This function is called when the `balbismo` command is executed.
/// It simply forwards all command line arguments to the main compilation
/// pipeline in the balbismo library.
///
/// Parameters:
/// - [arguments]: List of command line arguments provided to the executable
void main(List<String> arguments) async {
  await entrypoint.main(arguments);
}
