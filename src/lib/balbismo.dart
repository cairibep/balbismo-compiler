/// # Balbismo Programming Language Compiler
///
/// **Balbismo** is a simple, efficient programming language designed for educational
/// and research purposes, with a focus on clean syntax and direct LLVM compilation.
///
/// ## 🎯 Language Features
///
/// Balbismo supports essential programming constructs:
///
/// ### 📊 Data Types
/// - **Integer** (`int`): 64-bit signed integers
/// - **Float** (`float`): Double precision floating-point numbers
/// - **Arrays**: Dynamic runtime-sized arrays with stack allocation
///
/// ### 🔧 Expressions & Operators
/// - **Arithmetic**: `+`, `-`, `*`, `/`, `%`
/// - **Comparison**: `==`, `!=`, `<`, `>`, `<=`, `>=`
/// - **Logic**: `&&`, `||`, `!`
/// - **Type casting**: `(int)` and `(float)` conversions
///
/// ### ⚡ Control Flow
/// - **Conditional**: `if-else` statements
/// - **Loops**: `while` loops
/// - **Functions**: User-defined functions with typed parameters
///
/// ### 📝 I/O Operations
/// - **Input**: `scanf()` for formatted input
/// - **Output**: `printf()` for formatted output
///
/// ## 🏗️ Architecture
///
/// The Balbismo compiler consists of several key components:
///
/// ### Frontend (Lexical & Syntax Analysis)
/// - **Flex**: Lexical analysis using regular expressions
/// - **Bison**: Syntax analysis and AST construction
/// - **YAML Parser**: Converts parsed AST to object-oriented representation
///
/// ### Backend (Code Generation)
/// - **Abstract Syntax Tree (AST)**: Hierarchical representation of program structure
/// - **Symbol Table**: Manages variables, functions, and scoping
/// - **LLVM IR Generation**: Direct compilation to LLVM Intermediate Representation
/// - **Optimization**: LLVM's optimization passes for performance
///
/// ### Toolchain Integration
/// - **Clang**: Final compilation to machine code
/// - **LLI**: Just-in-time interpretation for testing
/// - **Opt**: LLVM optimization tools
///
/// ## 📚 Example Program
///
/// ```balbismo
/// // Fibonacci sequence calculation
/// int fib(int n) {
///   if (n <= 1) {
///     return n;
///   }
///   return fib(n - 1) + fib(n - 2);
/// }
///
/// int main() {
///   int result = fib(10);
///   printf("Fibonacci of 10: %d\n", result);
///   return 0;
/// }
/// ```
///
/// ## 🚀 Getting Started
///
/// ### Prerequisites
/// - Dart SDK
/// - LLVM toolchain (clang, opt, lli)
/// - Flex and Bison (for parser generation)
///
/// ### Building
/// ```bash
/// # Generate parser (if needed)
/// cd lex-parse
/// flex balbismo.l
/// bison -d balbismo.y
///
/// # Compile the compiler
/// dart compile exe bin/balbismo.dart
/// ```
///
/// ### Usage
/// ```bash
/// # Generate LLVM IR
/// ./balbismo gen-ir fibonacci.balbismo
///
/// # Compile to executable
/// ./balbismo compile fibonacci.balbismo
///
/// # Run directly
/// ./balbismo run fibonacci.balbismo
/// ```
///
/// ## 📖 Documentation
///
/// This documentation covers:
/// - [Language Reference](node/Node-class.html): Complete AST node documentation
/// - [Type System](vars/vars-library.html): Data types and type checking
/// - [Symbol Management](SymbolTable/SymbolTable-class.html): Variable and function scoping
/// - [Code Generation](main/main-library.html): Compilation pipeline
///
/// ## 🎓 Educational Purpose
///
/// Balbismo was developed as part of a compiler construction course to demonstrate:
/// - **Language Design**: Syntax and semantic choices
/// - **Compiler Architecture**: Modular design principles
/// - **Code Generation**: LLVM IR generation techniques
/// - **Tool Integration**: Working with external tools (Flex, Bison, LLVM)
///
/// ## 🤝 Contributing
///
/// This project serves as an educational example of compiler construction.
/// Contributions and improvements are welcome for:
/// - Language feature additions
/// - Optimization improvements
/// - Documentation enhancements
/// - Educational materials
///
/// ## 📄 License
///
/// Educational and research use encouraged. Please cite appropriately if used
/// in academic or research contexts.
///
/// ---
///
/// *Built with ❤️ for compiler construction education*
