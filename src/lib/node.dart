/// Abstract Syntax Tree (AST) node definitions and LLVM IR generation for Balbismo.
///
/// This library defines the complete AST node hierarchy for the Balbismo programming
/// language, along with LLVM Intermediate Representation (IR) code generation.
/// Each AST node represents a construct in the Balbismo language and knows how
/// to generate the corresponding LLVM IR code.
///
/// The AST nodes are organized into several categories:
/// - **Expressions**: Literals, identifiers, binary/unary operations, function calls
/// - **Statements**: Variable declarations, assignments, control flow (if/while)
/// - **Types**: Type representations and casting operations
/// - **I/O Operations**: Print and scanf statements
///
/// Key features of this AST implementation:
/// - **Type Safety**: All nodes are strongly typed with compile-time type checking
/// - **LLVM IR Generation**: Each node generates optimized LLVM IR code
/// - **Symbol Resolution**: Integration with the symbol table for variable/function lookup
/// - **Error Handling**: Comprehensive error checking and meaningful error messages
/// - **Memory Management**: Proper stack allocation and pointer handling
///
/// The code generation process transforms high-level Balbismo constructs into
/// low-level LLVM IR instructions that can be compiled to machine code by LLVM tools.

import 'package:balbismo/SymbolTable.dart';
import 'package:balbismo/vars.dart';
/// Generates an LLVM constant string definition from a Dart string.
///
/// This utility function converts a Dart string into the LLVM IR format for
/// string constants. LLVM requires special encoding for certain characters
/// and needs explicit null termination.
///
/// The conversion process:
/// 1. Escapes null characters (`\0` → `\00`)
/// 2. Escapes newlines (`\n` → `\0A`)
/// 3. Escapes quotes (`"` → `\22`)
/// 4. Adds null terminator (`\00`) at the end
/// 5. Calculates array size including null terminator
/// 6. Formats as LLVM constant array declaration
///
/// Parameters:
/// - [variableName]: The LLVM variable name for the constant (e.g., "@str.0")
/// - [content]: The original string content to be converted
///
/// Returns:
///   LLVM IR constant declaration string in the format:
///   `@variable = private constant [size x i8] c"escaped_content\\00"`
///
/// Example:
/// ```dart
/// final llvmConst = generateLLVMConstant("@str.0", "Hello\nWorld");
/// // Results in: @str.0 = private constant [12 x i8] c"Hello\0AWorld\00"
/// ```
String generateLLVMConstant(String variableName, String content) {
  // Convert the content into a format suitable for LLVM constant
  final escapedContent = content
      .replaceAll('\0', '\\00') // Ensure null terminators are represented
      .replaceAll('\n', '\\0A')
      .replaceAll("\"", "\\22"); // Replace newlines with LLVM encoding

  // Add null terminator to the end of the string
  final llvmContent = '$escapedContent\\00';

  // Calculate the size of the array
  final size = content.runes.length+1;

  // Format as LLVM constant string
  return '$variableName = private constant [$size x i8] c"$llvmContent"';
}

/// Abstract base class for all AST nodes in the Balbismo compiler.
///
/// This class defines the fundamental structure and behavior that all AST nodes
/// must implement. Each node represents a construct in the Balbismo language
/// and is responsible for generating the corresponding LLVM IR code.
///
/// The generic type parameters provide type safety:
/// - [T]: The type of the node's value (e.g., String for identifiers, int for literals)
/// - [E]: The type returned by the evaluate method (typically [void] for statements, [LangVal] for expressions)
///
/// Key responsibilities of AST nodes:
/// - **Code Generation**: Generate LLVM IR instructions via the [evaluate] method
/// - **Type Checking**: Ensure type safety during compilation
/// - **Symbol Resolution**: Interact with the symbol table for variable/function lookup
/// - **Error Reporting**: Provide meaningful error messages for invalid constructs
///
/// All nodes automatically receive a unique ID for LLVM register naming and
/// participate in the global LLVM IR generation process.
abstract class Node<T, E> {
  /// The primary value associated with this node (varies by node type).
  ///
  /// Examples:
  /// - For [IdentifierNode]: the variable name as a String
  /// - For [IntVal]: the numeric value as an int
  /// - For [BinOp]: the operator as a [MathOp] enum value
  final T nodeValue;

  /// Child nodes that form the structure of this node.
  ///
  /// The children represent sub-expressions, sub-statements, or other
  /// syntactic elements that make up this node. For example:
  /// - Binary operations have two children (left and right operands)
  /// - If statements have condition, then-block, and optionally else-block children
  /// - Function calls have the function identifier and argument list children
  final List<Node> children;

  /// Unique identifier for this node, used for LLVM register naming.
  ///
  /// Each node gets a unique ID to ensure LLVM register names don't conflict.
  /// This ID is automatically assigned during node construction.
  int id = 0;

  /// Global counter for generating unique string constant names.
  ///
  /// Used to create unique LLVM global variable names for string constants
  /// in the format "@str.N" where N is an incrementing counter.
  static int strCount = 0;

  /// Adds a string constant to the LLVM IR and returns its global name.
  ///
  /// This method manages string constant deduplication by checking if the
  /// string has already been defined. If not, it generates the LLVM constant
  /// declaration and adds it to the header section of the IR.
  ///
  /// Parameters:
  /// - [value]: The string content to be added as a constant
  ///
  /// Returns:
  ///   The LLVM global variable name for this string constant (e.g., "@str.0")
  ///
  /// Example:
  /// ```dart
  /// final strName = Node.addConstantString("Hello World");
  /// // Results in LLVM IR: @str.0 = private constant [12 x i8] c"Hello World\00"
  /// ```
  static String addConstantString(String value) {
    if (SymbolTable.strings.containsKey(value)) {
      return SymbolTable.strings[value]!;
    }
    final strName = "@str.${strCount++}";
    SymbolTable.strings[value] = strName;
    String content  = generateLLVMConstant(strName, value);
    Node.addHeaderIrLine(content);
    return strName;

  }

  /// Constructs a new AST node with the given value and children.
  ///
  /// Automatically assigns a unique ID to the node for LLVM register generation.
  ///
  /// Parameters:
  /// - [nodeValue]: The primary value for this node
  /// - [children]: List of child nodes (can be empty)
  Node(this.nodeValue, this.children) {
    id = newId();
  }
  /// Global LLVM IR code accumulator.
  ///
  /// This string accumulates all generated LLVM IR code during the compilation
  /// process. Each node appends its generated IR to this global string.
  /// The final result contains the complete LLVM IR program.
  static String ir = "";

  /// Global counter for generating unique node IDs.
  ///
  /// Used by [newId()] to ensure each AST node gets a unique identifier
  /// for LLVM register naming. This prevents naming conflicts in the generated IR.
  static int i = 0;

  /// Generates a new unique ID for node identification.
  ///
  /// Returns:
  ///   A unique integer ID that increments with each call
  ///
  /// This ID is used for generating unique LLVM register names and labels
  /// to avoid conflicts in the generated IR code.
  static int newId() {
    return i++;
  }

  /// Current indentation level for LLVM IR formatting.
  ///
  /// Controls the indentation of generated LLVM IR code for better readability.
  /// Increased when entering labeled blocks (like functions, if statements, loops)
  /// and decreased when exiting them.
  static int irIndent = 0;

  /// Adds a line to the LLVM IR header section.
  ///
  /// Header lines are inserted at the beginning of the IR (before function definitions).
  /// This is used for:
  /// - String constant declarations
  /// - External function declarations (like printf, scanf)
  /// - Global variable declarations
  ///
  /// Parameters:
  /// - [line]: The LLVM IR line to add to the header
  static addHeaderIrLine(String line) {
    ir  = "${line.trim()}\n$ir";
  }

  /// Adds a line to the LLVM IR with current indentation.
  ///
  /// Appends an LLVM IR instruction or directive with proper indentation
  /// based on the current [irIndent] level. This ensures readable formatting
  /// of the generated IR code.
  ///
  /// Parameters:
  /// - [line]: The LLVM IR instruction or directive to add
  static addIrLine(String line) {
    ir += "${"  " * irIndent}${line.trim()}\n";
  }

  /// Adds a labeled block to the LLVM IR and increases indentation.
  ///
  /// Used for creating labeled blocks in LLVM IR (functions, basic blocks, etc.).
  /// Automatically increases the indentation level for subsequent instructions.
  ///
  /// Parameters:
  /// - [label]: The label name (e.g., "entry", "then.0", "loop.1")
  ///
  /// Example:
  /// ```dart
  /// Node.addIrlLabel("entry");  // Creates: "entry:"
  /// Node.addIrLine("ret i64 0"); // Indented under the label
  /// ```
  static addIrlLabel(String label) {
    ir += "${"  " * irIndent}${label.trim()}:\n";
    irIndent++;
  }

  /// Ends a labeled block by decreasing indentation.
  ///
  /// Should be called after completing instructions within a labeled block
  /// to restore the previous indentation level.
  static endIrLabel() {
    irIndent--;
  }

  /// Evaluates this AST node and generates corresponding LLVM IR code.
  ///
  /// This is the main method that each AST node must implement to:
  /// 1. Perform semantic analysis (type checking, symbol resolution)
  /// 2. Generate LLVM IR instructions for the node's operation
  /// 3. Return the result value (if this is an expression)
  ///
  /// Parameters:
  /// - [table]: The current symbol table for variable and function lookups
  ///
  /// Returns:
  ///   The result of evaluating this node (type depends on node type)
  ///
  /// Throws:
  /// - [Exception] for semantic errors (undefined variables, type mismatches, etc.)
  /// - Various specific exceptions for different error conditions
  ///
  /// Note: The base implementation throws "Not implemented" - concrete subclasses
  /// must override this method with their specific evaluation logic.
  E evaluate(SymbolTable table) {
    throw Exception("Not implemented");
  }
}

/// Represents a block of statements in Balbismo.
///
/// A block node contains a sequence of statements or expressions that are executed
/// in order. Blocks create a new scope for variable declarations, allowing local
/// variables that are only accessible within the block.
///
/// In LLVM IR, blocks are translated to a sequence of instructions within the
/// current function or scope. Each child node generates its own IR instructions
/// in the order they appear.
///
/// Example Balbismo code:
/// ```balbismo
/// {
///   int x = 5;
///   printf("Value: %d", x);
/// }
/// ```
///
/// This creates a new scope where `x` is only accessible within the braces.
class BlockNode extends Node<void, void> {
  /// Constructs a block node with the given child statements.
  ///
  /// Parameters:
  /// - [children]: List of statements or expressions to execute in this block
  BlockNode(List<Node> children) : super(null, children);

  /// Evaluates all child nodes in order within a new scope.
  ///
  /// Creates a child symbol table to represent the block's scope, then evaluates
  /// each child node sequentially. This ensures that variable declarations within
  /// the block don't affect the parent scope.
  ///
  /// Parameters:
  /// - [table]: The parent symbol table
  ///
  /// The method doesn't return a value as blocks are statements, not expressions.
  @override
  void evaluate(SymbolTable table) {
    final newTable = table.createChild();
    for (var child in children) {
      child.evaluate(newTable);
    }
  }
}

/// Represents a type specification in Balbismo.
///
/// A type node wraps a [LangType] instance and is used wherever a type
/// specification is needed in the language, such as function return types,
/// variable declarations, and parameter types.
///
/// This node doesn't generate any LLVM IR itself - it serves as a container
/// for type information that's used by other nodes during evaluation.
///
/// Example Balbismo code:
/// ```balbismo
/// int x = 5;      // 'int' is represented by a TypeNode
/// float y = 3.14; // 'float' is represented by a TypeNode
/// ```
class TypeNode extends Node<LangType, void> {
  /// Constructs a type node with the specified language type.
  ///
  /// Parameters:
  /// - [value]: The language type this node represents
  TypeNode(LangType value) : super(value, []);
}

/// Represents an array type specification in Balbismo.
///
/// An array type node combines a primitive type with an array size specification
/// to create a complete array type. Arrays in Balbismo are dynamically sized
/// at runtime and are allocated on the stack.
///
/// Example Balbismo code:
/// ```balbismo
/// int[10] arr;        // Fixed size array
/// int[size] dynamic;  // Runtime-sized array
/// ```
class ArrayTypeNode extends Node<LangType, void> {
  /// Constructs an array type node with a primitive type and size specification.
  ///
  /// Parameters:
  /// - [primitiveTypeNode]: The primitive element type (int or float)
  /// - [size]: The array size specification (can be a constant or expression)
  ArrayTypeNode(TypeNode primitiveTypeNode, ArraySpecification size)
      : super(ArrayType(primitiveTypeNode.nodeValue.primitiveType), [size]);

  /// Gets the array size specification from the children.
  ArraySpecification get size => children[0] as ArraySpecification;
}

/// Represents an array size specification in Balbismo.
///
/// Array specifications can be either:
/// - A constant integer literal for fixed-size arrays
/// - An expression that evaluates to an integer at runtime for dynamic arrays
/// - Null for arrays with unspecified size (not currently supported)
///
/// Example Balbismo code:
/// ```balbismo
/// int[5] arr1;      // Constant size specification
/// int[size] arr2;   // Expression size specification
/// ```
class ArraySpecification extends Node<void, LangVal?> {
  /// Constructs an array size specification with an optional size expression.
  ///
  /// Parameters:
  /// - [expr]: The expression that determines the array size, or null for unspecified size
  ArraySpecification(Node<dynamic, LangVal>? expr)
      : super(null, [if (expr != null) expr]);

  /// Gets the size expression from the children, or null if no expression provided.
  Node<dynamic, LangVal>? get childExpr =>
      children.firstOrNull as Node<dynamic, LangVal>?;
  /// Evaluates the array size expression if present.
  ///
  /// If a size expression is provided, this method evaluates it to determine
  /// the actual array size at runtime. If no expression is provided (null),
  /// this returns null.
  ///
  /// Parameters:
  /// - [table]: The symbol table for expression evaluation
  ///
  /// Returns:
  ///   The evaluated size value, or null if no size expression was provided
  ///
  /// Throws:
  ///   Exceptions from the size expression evaluation if it fails
  @override
  LangVal? evaluate(SymbolTable table) {
    return childExpr?.evaluate(table);
  }
}

/// Represents a variable identifier reference in Balbismo.
///
/// An identifier node represents a reference to a variable by name. When evaluated,
/// it looks up the variable in the symbol table and generates the appropriate LLVM
/// IR to load the variable's value.
///
/// For regular variables, this generates a `load` instruction to get the value
/// from memory. For arrays, it returns the array pointer directly since arrays
/// are accessed via indexing operations.
///
/// Example Balbismo code:
/// ```balbismo
/// int x = 5;
/// printf("%d", x);  // 'x' is an IdentifierNode
/// ```
///
/// This generates LLVM IR like:
/// ```llvm
/// %var0 = load i64, ptr %ptr.x.0
/// ```
class IdentifierNode extends Node<String, LangVal> {
  /// Constructs an identifier node with the variable name.
  ///
  /// Parameters:
  /// - [value]: The name of the variable being referenced
  IdentifierNode(String value) : super(value, []);

  /// Evaluates the identifier by looking up and loading the variable's value.
  ///
  /// Looks up the variable in the symbol table and generates LLVM IR to load
  /// its value. For arrays, returns the array pointer. For primitive types,
  /// generates a load instruction.
  ///
  /// Parameters:
  /// - [table]: The symbol table to look up the variable
  ///
  /// Returns:
  ///   A [LangVal] containing the loaded value or array pointer
  ///
  /// Throws:
  /// - [Exception] if the variable is not found in the symbol table
  @override
  LangVal evaluate(SymbolTable table) {
    var varData = table.get(nodeValue);
    if (varData == null) {
      throw Exception("Variable $nodeValue not found");
    }
    if (varData.type is ArrayType) {
      return LangVal(varData.ptrName, varData.type);
    }
    Node.addIrLine(
        "%var$id = load ${varData.type.primitiveType.irType}, ptr ${varData.ptrName}");
    return LangVal("%var$id", varData.type);
  }
}

/// Represents an array element access using indexing in Balbismo.
///
/// An indexed identifier represents accessing a specific element of an array
/// using square bracket notation. It combines an array identifier with an
/// index expression to generate the appropriate LLVM IR for array element access.
///
/// Example Balbismo code:
/// ```balbismo
/// int[10] arr;
/// arr[5] = 42;      // 'arr[5]' is an IndexedIdentifierNode
/// int x = arr[i];   // 'arr[i]' is an IndexedIdentifierNode
/// ```
///
/// This generates LLVM IR like:
/// ```llvm
/// %arrayPtr.0 = getelementptr i64, i64* %ptr.arr.0, i64 %index
/// %var0 = load i64, ptr %arrayPtr.0
/// ```
class IndexedIdentifierNode extends IdentifierNode {
  /// Constructs an indexed identifier with an array name and index expression.
  ///
  /// Parameters:
  /// - [value]: The name of the array variable
  /// - [index]: The expression that evaluates to the array index
  IndexedIdentifierNode(super.value, Node<dynamic, LangVal> index) {
    children.add(index);
  }

  /// Gets the index expression used to access the array element.
  Node<dynamic, LangVal> get index => children[0] as Node<dynamic, LangVal>;

  /// Evaluates the array element access by computing the element address and loading its value.
  ///
  /// First verifies that the identifier refers to an array, then evaluates the index
  /// expression, and finally generates LLVM IR to compute the element address using
  /// getelementptr and load the element value.
  ///
  /// Parameters:
  /// - [table]: The symbol table for variable lookup
  ///
  /// Returns:
  ///   A [LangVal] containing the loaded array element value
  ///
  /// Throws:
  /// - [Exception] if the variable is not found
  /// - [Exception] if the variable is not an array type
  /// - [Exception] if the index expression doesn't evaluate to an integer
  @override
  LangVal evaluate(SymbolTable table) {
    final varData = table.get(nodeValue);
    if (varData == null) {
      throw Exception("Variable $nodeValue not found");
    }
    if (varData.type is! ArrayType) {
      throw Exception("Variable $nodeValue is not an array");
    }
    final indexResult = index.evaluate(table);
    if (indexResult.type.primitiveType != PrimitiveTypes.int) {
      throw Exception("Index must be int");
    }
    Node.addIrLine(
        "%arrayPtr.$id = getelementptr ${varData.type.primitiveType.irType}, ${varData.type.irType} ${varData.ptrName}, i64 ${indexResult.regName}");
    Node.addIrLine(
        "%var$id = load ${varData.type.primitiveType.irType}, ptr %arrayPtr.$id");
    return LangVal("%var$id", PrimitiveType(varData.type.primitiveType));
  }
}

/// Represents an integer literal value in Balbismo.
///
/// An integer value node represents a constant integer literal in the source code.
/// When evaluated, it generates LLVM IR to create the integer value using an `add`
/// instruction with 0 (a common LLVM idiom for creating constants).
///
/// Example Balbismo code:
/// ```balbismo
/// int x = 42;       // '42' is an IntVal node
/// int y = x + 10;   // '10' is an IntVal node
/// ```
///
/// This generates LLVM IR like:
/// ```llvm
/// %val0 = add i64 0, 42
/// ```
class IntVal extends Node<int, LangVal> {
  /// Constructs an integer value node by parsing the string representation.
  ///
  /// Parameters:
  /// - [value]: String representation of the integer value (e.g., "42")
  ///
  /// Throws:
  /// - [FormatException] if the string cannot be parsed as an integer
  IntVal(String value) : super(int.parse(value), []);

  /// Evaluates the integer literal by generating LLVM IR to create the constant value.
  ///
  /// Uses the LLVM idiom of adding 0 to create a constant value, which allows
  /// the optimizer to recognize and optimize constant expressions.
  ///
  /// Parameters:
  /// - [table]: The symbol table (not used for literals)
  ///
  /// Returns:
  ///   A [LangVal] containing the generated LLVM register and integer type
  @override
  LangVal evaluate(SymbolTable table) {
    Node.addIrLine("%val$id = add i64 0, $nodeValue");
    return LangVal("%val$id", const PrimitiveType(PrimitiveTypes.int));
  }
}

/// Represents a list of function parameters in Balbismo.
///
/// A parameter list contains the formal parameters of a function declaration.
/// Each parameter is represented as a [DeclareNode] that specifies the parameter's
/// type and name. Parameter lists are used during function definition and call
/// validation.
///
/// Example Balbismo code:
/// ```balbismo
/// int add(int x, int y) {  // 'int x, int y' is a ParameterList
///   return x + y;
/// }
/// ```
class ParameterList extends Node<void, void> {
  /// Constructs a parameter list from declaration nodes.
  ///
  /// Parameters:
  /// - [children]: List of parameter declarations
  ParameterList(List<DeclareNode> children) : super(null, children);

  /// Gets the list of parameter declarations.
  List<DeclareNode> get params => children.cast<DeclareNode>();
}

/// Represents a collection of function declarations in Balbismo.
///
/// A function list contains all the functions defined in a program. This is
/// typically the root node of a Balbismo program's AST, containing all
/// function definitions that need to be compiled.
///
/// Example Balbismo code:
/// ```balbismo
/// int add(int x, int y) {
///   return x + y;
/// }
///
/// int main() {
///   return add(5, 3);
/// }
/// ```
///
/// The entire program above would be contained in a FunctionList.
class FunctionList extends Node<void, void> {
  /// Constructs a function list from function declaration nodes.
  ///
  /// Parameters:
  /// - [children]: List of function declarations to include
  FunctionList(List<FuncDec> children) : super(null, children);

  /// Gets the list of function declarations.
  List<FuncDec> get funcs => children.cast<FuncDec>();

  /// Evaluates all function declarations in the list.
  ///
  /// Iterates through each function declaration and evaluates it, which
  /// generates the LLVM IR for that function's implementation.
  ///
  /// Parameters:
  /// - [table]: The global symbol table for function registration
  @override
  void evaluate(SymbolTable table) {
    for (var func in funcs) {
      func.evaluate(table);
    }
  }
}

/// Represents a return statement in Balbismo.
///
/// A return statement terminates function execution and optionally returns
/// a value to the caller. The return value expression is evaluated and then
/// a `ret` instruction is generated in LLVM IR.
///
/// Example Balbismo code:
/// ```balbismo
/// int add(int x, int y) {
///   return x + y;  // This is a ReturnStatement
/// }
///
/// void printHello() {
///   return;        // This is a ReturnStatement with no value
/// }
/// ```
///
/// Generates LLVM IR like:
/// ```llvm
/// ret i64 %result
/// ```
class ReturnStatement extends Node<void, void> {
  /// Constructs a return statement with an optional return value.
  ///
  /// Parameters:
  /// - [value]: The expression to return, or null for void returns
  ReturnStatement(Node<dynamic, LangVal> value) : super(null, [value]);

  /// Gets the return value expression.
  Node<dynamic, LangVal> get value => children[0] as Node<dynamic, LangVal>;

  /// Evaluates the return statement by generating a `ret` instruction.
  ///
  /// First evaluates the return value expression, then generates an LLVM
  /// `ret` instruction with the appropriate type and register name.
  ///
  /// Parameters:
  /// - [table]: The symbol table for expression evaluation
  ///
  /// This method doesn't return a value as return statements terminate execution.
  @override
  void evaluate(SymbolTable table) {
    final valueResult = value.evaluate(table);

    Node.addIrLine("ret ${valueResult.type.irType} ${valueResult.regName}");
  }
}

/// Represents a function declaration in Balbismo.
///
/// A function declaration defines a named function with parameters, a return type,
/// and a body. When evaluated, it generates the complete LLVM function definition
/// including parameter handling, local variables, and the function body.
///
/// Example Balbismo code:
/// ```balbismo
/// int add(int x, int y) {  // This is a FuncDec
///   return x + y;
/// }
///
/// int main() {
///   return add(5, 3);
/// }
/// ```
///
/// This generates LLVM IR like:
/// ```llvm
/// define i64 @add(i64 %x, i64 %y) {
/// entry:
///   %ptr.x.0 = alloca i64
///   store i64 %x, ptr %ptr.x.0
///   ; ... function body ...
///   ret i64 %result
/// }
/// ```
class FuncDec extends Node<void,void> {
  /// Constructs a function declaration with all its components.
  ///
  /// Parameters:
  /// - [returnType]: The function's return type (int, float, or void)
  /// - [identifier]: The function name
  /// - [params]: The parameter list
  /// - [block]: The function body block
  FuncDec(TypeNode returnType, IdentifierNode identifier,ParameterList params, BlockNode block)
      : super(null, [returnType, identifier, params, block]);

  /// Gets the function name identifier.
  IdentifierNode get identifier => children[1] as IdentifierNode;

  /// Gets the function body block.
  BlockNode get block => children.last as BlockNode;

  /// Gets the list of function parameters.
  List<DeclareNode> get params => (children[2] as ParameterList).params;

  /// Gets the function's return type.
  TypeNode get returnType => children[0] as TypeNode;

  /// Evaluates the function declaration by generating the complete LLVM function definition.
  ///
  /// This method performs the complete function compilation process:
  /// 1. Registers the function in the global symbol table
  /// 2. Generates the LLVM function signature with parameters
  /// 3. Sets up parameter handling (alloca and store for non-arrays, direct for arrays)
  /// 4. Evaluates the function body in a new scope
  /// 5. Generates the return instruction with default value
  ///
  /// Parameters:
  /// - [table]: The global symbol table for function registration
  ///
  /// The generated LLVM IR includes proper parameter handling where each parameter
  /// gets its own stack allocation and store operation, allowing the function body
  /// to modify parameter values without affecting the caller's variables.
  @override
  void evaluate(SymbolTable table) {
    final funcName = identifier.nodeValue;
    final returnType = this.returnType.nodeValue;
    final func = LangFunc(funcName, this);
    SymbolTable.createFunction(funcName, func);
    final String paramsStr = params.map((e) => "${e.type.nodeValue.irType} %${e.identifier.nodeValue} ").join(", ");
    Node.addIrLine("define ${returnType.irType} @$funcName($paramsStr) {");
    Node.addIrlLabel("entry");
    final newTable = SymbolTable();
    for (var param in params) {
      if (param.type.nodeValue is ArrayType) {
        newTable.create(param.identifier.nodeValue, LangVar("%${param.identifier.nodeValue}", param.type.nodeValue));
        continue;
      }

    final ptrName = "%ptr.${param.identifier.nodeValue}.$id";
      Node.addIrLine("$ptrName = alloca ${param.type.nodeValue.irType}");
      Node.addIrLine("store ${param.type.nodeValue.irType} %${param.identifier.nodeValue}, ptr $ptrName");
      newTable.create(param.identifier.nodeValue, LangVar(ptrName, param.type.nodeValue));
    }
    block.evaluate(newTable);
    Node.addIrLine("ret ${returnType.irType} ${returnType.primitiveType == PrimitiveTypes.int ? "0" : "0.0"}");
    Node.endIrLabel();
    Node.addIrLine("}");
  }
}

/// Represents a list of function call arguments in Balbismo.
///
/// An argument list contains the expressions that are passed as arguments
/// to a function call. Each argument is evaluated and its value is passed
/// to the function. The arguments are evaluated in order from left to right.
///
/// Example Balbismo code:
/// ```balbismo
/// int add(int x, int y) {
///   return x + y;
/// }
///
/// int main() {
///   int result = add(5 + 1, 3 * 2);  // '5 + 1, 3 * 2' is an ArgumentList
///   return result;
/// }
/// ```
///
/// The argument expressions are evaluated and their results are passed to the function.
class ArgumentList extends Node<void, List<LangVal>> {
  /// Constructs an argument list from argument expression nodes.
  ///
  /// Parameters:
  /// - [children]: List of argument expressions to evaluate
  ArgumentList(List<Node<dynamic,LangVal>> children) : super(null, children);

  List<Node<dynamic, LangVal>> get args => children.cast<Node<dynamic, LangVal>>();

  @override
  List<LangVal> evaluate(SymbolTable table) {
    return args.map((e) => e.evaluate(table)).toList();
  }
}

/// Represents a function call expression in Balbismo.
///
/// A function call invokes a previously declared function with the specified
/// arguments. The function must be declared before it can be called, and the
/// argument types must match the function's parameter types.
///
/// Example Balbismo code:
/// ```balbismo
/// int add(int x, int y) {
///   return x + y;
/// }
///
/// int main() {
///   int result = add(5, 3);  // 'add(5, 3)' is a FuncCall
///   return result;
/// }
/// ```
///
/// This generates LLVM IR like:
/// ```llvm
/// %call.0 = call i64 @add(i64 %arg1, i64 %arg2)
/// ```
class FuncCall extends Node<void, LangVal> {
  /// Constructs a function call with the function name and arguments.
  ///
  /// Parameters:
  /// - [identifier]: The name of the function to call
  /// - [args]: The list of arguments to pass to the function
  FuncCall(IdentifierNode identifier, ArgumentList args)
      : super(null, [identifier, args]);

  IdentifierNode get identifier => children[0] as IdentifierNode;
  ArgumentList get args => children[1] as ArgumentList;

  @override
  LangVal evaluate(SymbolTable table) {
    final func = SymbolTable.getFunction(identifier.nodeValue);
    if (func == null) {
      throw Exception("Function ${identifier.nodeValue} not found");
    }
    final argValues = args.evaluate(table);
    final argTypes = func.funcDec.params.map((e) => e.type.nodeValue).toList();
    if (argValues.length != argTypes.length) {
      throw Exception("Argument count mismatch");
    }
    for (var i = 0; i < argValues.length; i++) {
      if (argValues[i].type != argTypes[i]) {
        throw Exception("Argument type mismatch");
      }
    }
    final argStr = argValues.map((e) => "${e.type.irType} ${e.regName}").join(", ");
    Node.addIrLine("%call.$id = call ${func.funcDec.returnType.nodeValue.irType} @${func.name}($argStr)");
    return LangVal("%call.$id", func.funcDec.returnType.nodeValue);
  }
}
/// Represents a floating-point literal value in Balbismo.
///
/// A floating-point value node represents a constant floating-point literal
/// in the source code. When evaluated, it generates LLVM IR to create the
/// floating-point value using an `fadd` instruction with 0.0 (a common LLVM
/// idiom for creating floating-point constants).
///
/// Example Balbismo code:
/// ```balbismo
/// float x = 3.14;       // '3.14' is a FloatVal node
/// float y = x + 2.71;   // '2.71' is a FloatVal node
/// ```
///
/// This generates LLVM IR like:
/// ```llvm
/// %val0 = fadd double 0.0, 3.14
/// ```
class FloatVal extends Node<double, LangVal> {
  /// Constructs a floating-point value node by parsing the string representation.
  ///
  /// Parameters:
  /// - [value]: String representation of the floating-point value (e.g., "3.14")
  ///
  /// Throws:
  /// - [FormatException] if the string cannot be parsed as a double
  FloatVal(String value) : super(double.parse(value), []);

  @override
  LangVal evaluate(SymbolTable table) {
    Node.addIrLine("%val$id = fadd double 0.0, $nodeValue");
    return LangVal("%val$id", const PrimitiveType(PrimitiveTypes.float));
  }
}

class DeclareNode extends Node<void, void> {
  DeclareNode(Node<LangType, dynamic> type, IdentifierNode identifier,
      [Node? value])
      : super(null, [type, identifier, if (value != null) value]);

  IdentifierNode get identifier => children[1] as IdentifierNode;
  Node<LangType, dynamic> get type => children[0] as Node<LangType, dynamic>;

  @override
  void evaluate(SymbolTable table) {
    var ptrName = '%ptr.${identifier.nodeValue}.$id';
    final varType = type.nodeValue;
    final langVar = LangVar(ptrName, varType);
    table.create(identifier.nodeValue, langVar);
    if (varType is PrimitiveType) {
      Node.addIrLine("$ptrName = alloca ${varType.primitiveType.irType}");
      if (children.length > 2) {
        var value = children[2].evaluate(table);
        if (varType.primitiveType != value.type.primitiveType) {
          throw Exception("Type mismatch");
        }

        Node.addIrLine(
            "store ${varType.primitiveType.irType} ${value.regName}, ptr $ptrName");
      }
    } else if (varType is ArrayType) {
      var arrayTypeNode = type as ArrayTypeNode;
      var size = arrayTypeNode.size.evaluate(table);
      if (size != null) {
        Node.addIrLine(
            "%arrayptr.$id = alloca ${varType.primitiveType.irType}, i64 ${size.regName}");
            

        Node.addIrLine(
            "$ptrName = getelementptr ${varType.primitiveType.irType}, ${varType.irType} %arrayptr.$id, i64 0");
      } else {
        //need size
        throw Exception("Array size not found"); 
      }


      if (children.length > 2) {
        //cant assign to array
        throw Exception("Cannot assign to array");
      }
    }
  }
}

class AssignmentNode extends Node<void, void> {
  AssignmentNode(IdentifierNode identifier, Node value)
      : super(null, [identifier, value]);

  IdentifierNode get identifier => children[0] as IdentifierNode;

  @override
  Node get nodeValue => children[1];

  @override
  void evaluate(SymbolTable table) {
    final identifierNode = identifier;

    var varData = table.get(identifier.nodeValue);
    
    
    
    if (varData == null) {
      throw Exception("Variable ${identifier.nodeValue} not found");
    }

    if (varData.type is ArrayType && identifierNode is !IndexedIdentifierNode) {
      throw Exception("Cannot assign to array");
      
    }
    if (varData.type is! ArrayType && identifierNode is IndexedIdentifierNode) {
      throw Exception("Cannot index non-array");
    }
    var value = nodeValue.evaluate(table);

    var ptrName = varData.ptrName;
    if (varData.type is ArrayType) {
      if (varData.type.primitiveType != value.type.primitiveType) {
        throw Exception("Type mismatch");
      }
      final IndexedIdentifierNode indexedIdentifierNode = identifierNode as IndexedIdentifierNode;
      final indexResult = indexedIdentifierNode.index.evaluate(table);
      if (indexResult.type.primitiveType != PrimitiveTypes.int) {
        throw Exception("Index must be int");
      }
      Node.addIrLine(
          "%arrayPtr.$id = getelementptr ${varData.type.primitiveType.irType}, ${varData.type.irType} ${varData.ptrName}, i64 ${indexResult.regName}");
      ptrName = "%arrayPtr.$id";
    } else if (varData.type != value.type) {
      throw Exception("Type mismatch");
    }
    Node.addIrLine(
        "store ${varData.type.primitiveType.irType} ${value.regName}, ptr $ptrName");
  }
}

/// Represents a scanf statement for input in Balbismo.
///
/// A scanf node handles formatted input using scanf-style format strings.
/// It takes a format string and a list of variables to read values into.
/// The format string uses standard C-style format specifiers like %d, %f.
///
/// Example Balbismo code:
/// ```balbismo
/// int x;
/// float y;
/// scanf("%d %f", x, y);  // This is a ScanfNode
/// ```
///
/// This generates LLVM IR like:
/// ```llvm
/// call i32 (i8*, ...) @scanf(i8* @str.0, i64* %ptr.x.0, double* %ptr.y.0)
/// ```
class ScanfNode extends Node<void,void> {
  /// Constructs a scanf statement with format string and target variables.
  ///
  /// Parameters:
  /// - [literal]: The format string literal containing scanf format specifiers
  /// - [children]: List of identifier nodes representing variables to read into
  ScanfNode(StringLiteral literal, List<IdentifierNode> children) : super(null, [literal, ...children]);

  StringLiteral get literal => children[0] as StringLiteral;
  List<IdentifierNode> get identifiers => children.sublist(1).cast<IdentifierNode>();

  @override
  void evaluate(SymbolTable table) {
    final strLiteral = literal.evaluate(table);
      List<(String, String)> irLines = [];
    
    for (var identifier in identifiers) {
      var varData = table.get(identifier.nodeValue);
      if (varData == null) {
        throw Exception("Variable ${identifier.nodeValue} not found");
      }
      String ptr = varData.ptrName;
      if (varData.type is ArrayType && identifier is !IndexedIdentifierNode) {
        throw Exception("Cannot scan into array");
      }
      if (varData.type is! ArrayType && identifier is IndexedIdentifierNode) {
        throw Exception("Cannot index non-array");
      }
      if (varData.type is ArrayType) {
        final indexedId = identifier as IndexedIdentifierNode;
        final indexResult = indexedId.index.evaluate(table);
        if (indexResult.type.primitiveType != PrimitiveTypes.int) {
          throw Exception("Index must be int");
        }
        Node.addIrLine(
            "%arrayPtr.${identifier.id} = getelementptr ${varData.type.primitiveType.irType}, ${varData.type.irType} ${varData.ptrName}, i64 ${indexResult.regName}");
        ptr = "%arrayPtr.${identifier.id}";
      } 
      irLines.add((ptr, varData.type.primitiveType.irType));
      
    }
    final childrenStr = irLines.map((e) => "${e.$2}* ${e.$1}").join(", ");
    Node.addIrLine(
        "call i32 (i8*, ...) @scanf(i8* $strLiteral, $childrenStr)");
  }
}
/// Represents a string literal constant in Balbismo.
///
/// A string literal node represents a constant string value in the source code.
/// When evaluated, it adds the string to the LLVM IR as a global constant and
/// returns the LLVM global variable name for use in other operations.
///
/// Example Balbismo code:
/// ```balbismo
/// printf("Hello World\n");  // '"Hello World\n"' is a StringLiteral
/// ```
///
/// This generates LLVM IR like:
/// ```llvm
/// @str.0 = private constant [13 x i8] c"Hello World\0A\00"
/// ```
///
/// The string is stored as a null-terminated byte array in LLVM IR.
class StringLiteral extends Node<String,String> {
  /// Constructs a string literal with the string content.
  ///
  /// Parameters:
  /// - [value]: The string content (without quotes)
  StringLiteral(String value) : super(value, []);

  @override
  String evaluate(SymbolTable table) {
    return Node.addConstantString(nodeValue);
  }

}

/// Enumeration of mathematical operators supported in Balbismo expressions.
///
/// These operators represent the basic arithmetic operations that can be performed
/// on integer and floating-point values. The operators are mapped from their
/// string representations in the source code to enum values for internal processing.
///
/// Example Balbismo code:
/// ```balbismo
/// int result = a + b * c - d / e % f;  // Uses add, mul, sub, div, mod
/// ```
enum MathOp {
  /// Addition operator (+)
  add,

  /// Subtraction operator (-)
  sub,

  /// Multiplication operator (*)
  mul,

  /// Division operator (/)
  div,

  /// Modulo operator (%)
  mod;

  /// Converts a string operator representation to the corresponding enum value.
  ///
  /// Parameters:
  /// - [op]: String representation of the operator ("+", "-", "*", "/", "%")
  ///
  /// Returns:
  ///   The corresponding [MathOp] enum value
  ///
  /// Throws:
  /// - [Exception] if the operator string is not recognized
  static MathOp fromString(String op) {
    switch (op) {
      case "+":
        return MathOp.add;
      case "-":
        return MathOp.sub;
      case "*":
        return MathOp.mul;
      case "/":
        return MathOp.div;
      case "%":
        return MathOp.mod;
      default:
        throw Exception("Unknown operator: $op");
    }
  }
}

/// Represents a mathematical unary operation in Balbismo.
///
/// A unary operation applies a mathematical operator to a single operand.
/// Currently supports unary plus (+) which returns the operand unchanged,
/// and unary minus (-) which negates the operand.
///
/// Example Balbismo code:
/// ```balbismo
/// int x = 5;
/// int positive = +x;  // '+' is a UnOp (unary plus)
/// int negative = -x;  // '-' is a UnOp (unary minus)
/// ```
///
/// This generates LLVM IR like:
/// ```llvm
/// %unOp.0 = sub i64 0, %x  // For unary minus
/// ```
class UnOp extends Node<MathOp, LangVal> {
  /// Constructs a unary mathematical operation with the operator and operand.
  ///
  /// Parameters:
  /// - [value]: String representation of the operator ("+" or "-")
  /// - [child]: The operand expression to apply the operation to
  UnOp(String value, Node<dynamic, LangVal> child)
      : super(MathOp.fromString(value), [child]);

  Node<dynamic, LangVal> get child => children[0] as Node<dynamic, LangVal>;
  @override
  LangVal evaluate(SymbolTable table) {
    final childResult = child.evaluate(table);
    //cant be array
    if (childResult.type is ArrayType) {
      throw Exception("Cannot apply unary operator to array");
    }

    switch (nodeValue) {
      case MathOp.add:
        return childResult;
      case MathOp.sub:
        Node.addIrLine(
            "%unOp.$id = sub ${childResult.type.irType} 0, ${childResult.regName}");
        return LangVal("%unOp.$id", childResult.type);
      default:
        throw Exception("Unknown operator: $nodeValue");
    }
  }
}

/// Represents a mathematical binary operation in Balbismo.
///
/// A binary operation applies a mathematical operator to two operands.
/// Supports all basic arithmetic operations: addition, subtraction,
/// multiplication, division, and modulo. The operation handles type
/// promotion automatically when mixing int and float operands.
///
/// Example Balbismo code:
/// ```balbismo
/// int a = 10;
/// int b = 3;
/// int result = a + b * 2 - b / 2 % 3;  // Multiple BinOp nodes
/// ```
///
/// This generates LLVM IR like:
/// ```llvm
/// %binOp.0 = add i64 %a, %b
/// %binOp.1 = mul i64 %binOp.0, 2
/// ; ... etc for other operations
/// ```
class BinOp extends Node<MathOp, LangVal> {
  /// Constructs a binary mathematical operation with the operator and operands.
  ///
  /// Parameters:
  /// - [value]: String representation of the operator ("+", "-", "*", "/", "%")
  /// - [left]: The left operand expression
  /// - [right]: The right operand expression
  BinOp(String value, Node left, Node right)
      : super(MathOp.fromString(value), [left, right]);

  Node<dynamic, LangVal> get left => children[0] as Node<dynamic, LangVal>;
  Node<dynamic, LangVal> get right => children[1] as Node<dynamic, LangVal>;

  @override
  LangVal evaluate(SymbolTable table) {
    var leftResult = left.evaluate(table);
    var rightResult = right.evaluate(table);
    // cant be array
    if (leftResult.type is ArrayType || rightResult.type is ArrayType) {
      throw Exception("Cannot apply binary operator to array");
    }

    if (leftResult.type != rightResult.type) {
      if (leftResult.type.primitiveType == PrimitiveTypes.float) {
        Node.addIrLine(
            "%conv.$id = sitofp i64 ${rightResult.regName} to double");
        rightResult =
            LangVal("%conv.$id", const PrimitiveType(PrimitiveTypes.float));
      } else {
        Node.addIrLine(
            "%conv.$id = sitofp i64 ${leftResult.regName} to double");
        leftResult =
            LangVal("%conv.$id", const PrimitiveType(PrimitiveTypes.float));
      }
    }
    if (leftResult.type.primitiveType == PrimitiveTypes.float) {
      switch (nodeValue) {
        case MathOp.add:
          Node.addIrLine(
              "%binOp.$id = fadd double ${leftResult.regName}, ${rightResult.regName}");
          return LangVal("%binOp.$id", leftResult.type);
        case MathOp.sub:
          Node.addIrLine(
              "%binOp.$id = fsub double ${leftResult.regName}, ${rightResult.regName}");
          return LangVal("%binOp.$id", leftResult.type);
        case MathOp.mul:
          Node.addIrLine(
              "%binOp.$id = fmul double ${leftResult.regName}, ${rightResult.regName}");
          return LangVal("%binOp.$id", leftResult.type);
        case MathOp.div:
          Node.addIrLine(
              "%binOp.$id = fdiv double ${leftResult.regName}, ${rightResult.regName}");
          return LangVal("%binOp.$id", leftResult.type);
        default:
          throw Exception("Unknown operator: $nodeValue");
      }
    }

    switch (nodeValue) {
      case MathOp.add:
        Node.addIrLine(
            "%binOp.$id = add ${leftResult.type.irType} ${leftResult.regName}, ${rightResult.regName}");
        return LangVal("%binOp.$id", leftResult.type);
      case MathOp.sub:
        Node.addIrLine(
            "%binOp.$id = sub ${leftResult.type.irType} ${leftResult.regName}, ${rightResult.regName}");
        return LangVal("%binOp.$id", leftResult.type);
      case MathOp.mul:
        Node.addIrLine(
            "%binOp.$id = mul ${leftResult.type.irType} ${leftResult.regName}, ${rightResult.regName}");
        return LangVal("%binOp.$id", leftResult.type);
      case MathOp.div:
        Node.addIrLine(
            "%binOp.$id = sdiv ${leftResult.type.irType} ${leftResult.regName}, ${rightResult.regName}");
        return LangVal("%binOp.$id", leftResult.type);
      case MathOp.mod:
        Node.addIrLine(
            "%binOp.$id = srem ${leftResult.type.irType} ${leftResult.regName}, ${rightResult.regName}");
        return LangVal("%binOp.$id", leftResult.type);
      default:
        throw Exception("Unknown operator: $nodeValue");
    }
  }
}

/// Represents a printf statement for output in Balbismo.
///
/// A print node handles formatted output using printf-style format strings.
/// It takes a format string and a list of values to be formatted and printed.
/// The format string uses standard C-style format specifiers like %d, %f, %s.
///
/// Example Balbismo code:
/// ```balbismo
/// int x = 42;
/// float y = 3.14;
/// printf("Integer: %d, Float: %f\n", x, y);  // This is a PrintNode
/// ```
///
/// This generates LLVM IR like:
/// ```llvm
/// call i32 (i8*, ...) @printf(i8* @str.0, i64 %x, double %y)
/// ```
class PrintNode extends Node<void, void> {
  /// Constructs a print statement with format string and values.
  ///
  /// Parameters:
  /// - [literal]: The format string literal containing printf format specifiers
  /// - [children]: List of expressions whose values will be formatted
  PrintNode(StringLiteral literal, List<Node<dynamic, LangVal>> children) : super(null, [literal, ...children]);

  
  StringLiteral get literal => children[0] as StringLiteral;
  List<Node<dynamic, LangVal>> get values => children.sublist(1).cast<Node<dynamic, LangVal>>();

  @override
  void evaluate(SymbolTable table) {
    final strLiteral = literal.evaluate(table);
    var childResults = values.map((e) => e.evaluate(table)).toList();
    //print using printf
    final childrenStr = childResults.map((e) => "${e.type.irType} ${e.regName}").join(", ");
    Node.addIrLine(
        "call i32 (i8*, ...) @printf(i8* $strLiteral ${childResults.isNotEmpty ? "," : ""} $childrenStr)");
  }
}

/// Enumeration of relational operators for comparison expressions in Balbismo.
///
/// These operators are used for comparing values and return boolean results
/// (represented as integers 0 or 1 in LLVM IR). The operators support both
/// integer and floating-point comparisons with appropriate LLVM instructions.
///
/// Example Balbismo code:
/// ```balbismo
/// if (x == y && a < b || c >= d) {  // Uses eq, lt, ge operators
///   // ...
/// }
/// ```
enum RelOperator {
  /// Equality operator (==)
  eq,

  /// Inequality operator (!=)
  ne,

  /// Less than operator (<)
  lt,

  /// Greater than operator (>)
  gt,

  /// Less than or equal operator (<=)
  le,

  /// Greater than or equal operator (>=)
  ge;

  /// Converts a string operator representation to the corresponding enum value.
  ///
  /// Parameters:
  /// - [op]: String representation of the operator ("==", "!=", "<", ">", "<=", ">=")
  ///
  /// Returns:
  ///   The corresponding [RelOperator] enum value
  ///
  /// Throws:
  /// - [Exception] if the operator string is not recognized
  static RelOperator fromString(String op) {
    switch (op) {
      case "==":
        return RelOperator.eq;
      case "!=":
        return RelOperator.ne;
      case "<":
        return RelOperator.lt;
      case ">":
        return RelOperator.gt;
      case "<=":
        return RelOperator.le;
      case ">=":
        return RelOperator.ge;
      default:
        throw Exception("Unknown operator: $op");
    }
  }
}

/// Represents a relational comparison operation in Balbismo.
///
/// A relational operation compares two values and returns an integer result
/// (0 for false, 1 for true). Supports all standard comparison operators
/// for both integer and floating-point values with appropriate LLVM instructions.
///
/// Example Balbismo code:
/// ```balbismo
/// int a = 5;
/// int b = 10;
/// int result = a < b && a != 0;  // Multiple RelOp nodes
/// ```
///
/// This generates LLVM IR comparison instructions:
/// ```llvm
/// %temp.0 = icmp slt i64 %a, %b     // signed less than for integers
/// %temp.1 = fcmp olt double %x, %y  // ordered less than for floats
/// %relOp.0 = zext i1 %temp.0 to i64  // convert boolean to integer
/// ```
class RelOp extends Node<RelOperator, LangVal> {
  /// Constructs a relational operation with the operator and operands.
  ///
  /// Parameters:
  /// - [value]: String representation of the operator ("==", "!=", "<", ">", "<=", ">=")
  /// - [left]: The left operand expression
  /// - [right]: The right operand expression
  RelOp(String value, Node<dynamic, LangVal> left, Node<dynamic, LangVal> right)
      : super(RelOperator.fromString(value), [left, right]);

  Node<dynamic, LangVal> get left => children[0] as Node<dynamic, LangVal>;
  Node<dynamic, LangVal> get right => children[1] as Node<dynamic, LangVal>;
  @override
  LangVal evaluate(SymbolTable table) {
    var leftResult = left.evaluate(table);
    var rightResult = right.evaluate(table);

    //cant be array
    if (leftResult.type is ArrayType || rightResult.type is ArrayType) {
      throw Exception("Cannot apply binary operator to array");
    }
    if (leftResult.type != rightResult.type) {
      if (leftResult.type.primitiveType == PrimitiveTypes.float) {
        Node.addIrLine(
            "%conv.$id = sitofp i64 ${rightResult.regName} to double");
        rightResult =
            LangVal("%conv.$id", const PrimitiveType(PrimitiveTypes.float));
      } else {
        Node.addIrLine(
            "%conv.$id = sitofp i64 ${leftResult.regName} to double");
        leftResult =
            LangVal("%conv.$id", const PrimitiveType(PrimitiveTypes.float));
      }
    }
    if (leftResult.type.primitiveType == PrimitiveTypes.float) {
      switch (nodeValue) {
        case RelOperator.eq:
          Node.addIrLine(
              "%temp.$id = fcmp oeq double ${leftResult.regName}, ${rightResult.regName}");
          break;
        case RelOperator.ne:
          Node.addIrLine(
              "%temp.$id = fcmp one double ${leftResult.regName}, ${rightResult.regName}");
          break;
        case RelOperator.lt:
          Node.addIrLine(
              "%temp.$id = fcmp olt double ${leftResult.regName}, ${rightResult.regName}");
          break;
        case RelOperator.gt:
          Node.addIrLine(
              "%temp.$id = fcmp ogt double ${leftResult.regName}, ${rightResult.regName}");
          break;
        case RelOperator.le:
          Node.addIrLine(
              "%temp.$id = fcmp ole double ${leftResult.regName}, ${rightResult.regName}");
          break;
        case RelOperator.ge:
          Node.addIrLine(
              "%temp.$id = fcmp oge double ${leftResult.regName}, ${rightResult.regName}");
          break;
        default:
          throw Exception("Unknown operator: $nodeValue");
      }
    } else {
      switch (nodeValue) {
        case RelOperator.eq:
          Node.addIrLine(
              "%temp.$id = icmp eq ${leftResult.type.irType} ${leftResult.regName}, ${rightResult.regName}");
          break;
        case RelOperator.ne:
          Node.addIrLine(
              "%temp.$id = icmp ne ${leftResult.type.irType} ${leftResult.regName}, ${rightResult.regName}");
          break;
        case RelOperator.lt:
          Node.addIrLine(
              "%temp.$id = icmp slt ${leftResult.type.irType} ${leftResult.regName}, ${rightResult.regName}");
          break;
        case RelOperator.gt:
          Node.addIrLine(
              "%temp.$id = icmp sgt ${leftResult.type.irType} ${leftResult.regName}, ${rightResult.regName}");
          break;
        case RelOperator.le:
          Node.addIrLine(
              "%temp.$id = icmp sle ${leftResult.type.irType} ${leftResult.regName}, ${rightResult.regName}");
          break;
        case RelOperator.ge:
          Node.addIrLine(
              "%temp.$id = icmp sge ${leftResult.type.irType} ${leftResult.regName}, ${rightResult.regName}");
          break;
        default:
          throw Exception("Unknown operator: $nodeValue");
      }
    }
    Node.addIrLine("%relOp.$id = zext i1 %temp.$id to i64");
    return LangVal("%relOp.$id", const PrimitiveType(PrimitiveTypes.int));
  }
}

/// Enumeration of boolean operators for logical expressions in Balbismo.
///
/// These operators handle logical operations on boolean values (represented as
/// integers 0 or 1). The operators support short-circuit evaluation and are
/// used in conditional expressions and control flow statements.
///
/// Example Balbismo code:
/// ```balbismo
/// if (!x && (y || z)) {  // Uses not, and, or operators
///   // ...
/// }
/// ```
enum BoolOperator {
  /// Logical NOT operator (!)
  not,

  /// Logical AND operator (&&)
  and,

  /// Logical OR operator (||)
  or;

  /// Converts a string operator representation to the corresponding enum value.
  ///
  /// Parameters:
  /// - [op]: String representation of the operator ("&&", "||", "!")
  ///
  /// Returns:
  ///   The corresponding [BoolOperator] enum value
  ///
  /// Throws:
  /// - [Exception] if the operator string is not recognized
  static BoolOperator fromString(String op) {
    switch (op) {
      case "&&":
        return BoolOperator.and;
      case "||":
        return BoolOperator.or;
      case "!":
        return BoolOperator.not;
      default:
        throw Exception("Unknown operator: $op");
    }
  }
}

/// Represents a boolean unary operation in Balbismo.
///
/// A boolean unary operation applies a logical NOT operation to a boolean value.
/// Currently, only the logical NOT operator (!) is supported for unary boolean operations.
///
/// Example Balbismo code:
/// ```balbismo
/// int x = 0;
/// int result = !x;  // '!' is a BoolUnOp
/// ```
///
/// This generates LLVM IR like:
/// ```llvm
/// %boolIsZero.0 = icmp eq i64 %x, 0
/// %boolUnOp.0 = zext i1 %boolIsZero.0 to i64
/// ```
class BoolUnOp extends Node<BoolOperator, LangVal> {
  /// Constructs a boolean unary operation with the operator and operand.
  ///
  /// Parameters:
  /// - [value]: String representation of the operator ("!")
  /// - [child]: The operand expression to apply the operation to
  BoolUnOp(String value, Node<dynamic, LangVal> child)
      : super(BoolOperator.fromString(value), [child]);

  Node<dynamic, LangVal> get child => children[0] as Node<dynamic, LangVal>;

  @override
  LangVal evaluate(SymbolTable table) {
    if (nodeValue != BoolOperator.not) {
      throw Exception("Invalid operator for BoolUnOp");
    }
    final childResult = child.evaluate(table);
    //cant be array
    //has to be int
    if (childResult.type is! PrimitiveType ||
        childResult.type.primitiveType != PrimitiveTypes.int) {
      throw Exception("Not operantion can only be applied to int");
    }

    //if child is not 0 convert to 0 else convert to 1
    Node.addIrLine("%boolIsZero.$id = icmp eq i64 ${childResult.regName}, 0");
    Node.addIrLine("%boolUnOp.$id = zext i1 %boolIsZero.$id to i64");
    return LangVal("%boolUnOp.$id", const PrimitiveType(PrimitiveTypes.int));
  }
}

/// Represents a boolean binary operation in Balbismo.
///
/// A boolean binary operation applies logical AND (&&) or OR (||) operations
/// to two boolean values. These operations work with integer values where
/// 0 represents false and any non-zero value represents true.
///
/// Example Balbismo code:
/// ```balbismo
/// int x = 1;
/// int y = 0;
/// int result = x && y;  // '&&' is a BoolBinOp
/// int result2 = x || y; // '||' is a BoolBinOp
/// ```
///
/// This generates LLVM IR like:
/// ```llvm
/// %and.0 = and i64 %x, %y
/// %logic.0 = icmp ne i64 %and.0, 0
/// %boolBinOp.0 = zext i1 %logic.0 to i64
/// ```
class BoolBinOp extends Node<BoolOperator, LangVal> {
  /// Constructs a boolean binary operation with the operator and operands.
  ///
  /// Parameters:
  /// - [value]: String representation of the operator ("&&" or "||")
  /// - [left]: The left operand expression
  /// - [right]: The right operand expression
  BoolBinOp(
      String value, Node<dynamic, LangVal> left, Node<dynamic, LangVal> right)
      : super(BoolOperator.fromString(value), [left, right]);

  Node<dynamic, LangVal> get left => children[0] as Node<dynamic, LangVal>;
  Node<dynamic, LangVal> get right => children[1] as Node<dynamic, LangVal>;

  @override
  LangVal evaluate(SymbolTable table) {
    final leftResult = left.evaluate(table);
    final rightResult = right.evaluate(table);

    //cant be array
    if (leftResult.type is ArrayType || rightResult.type is ArrayType) {
      throw Exception("Cannot apply binary operator to array");
    }

    if (leftResult.type.primitiveType != PrimitiveTypes.int ||
        rightResult.type.primitiveType != PrimitiveTypes.int) {
      throw Exception("BoolBinOp can only be applied to int");
    }
    //should always return 0 or 1 in i64
    switch (nodeValue) {
      case BoolOperator.and:
        Node.addIrLine(
            "%and.$id = and i64 ${leftResult.regName}, ${rightResult.regName}");
        Node.addIrLine("%logic.$id = icmp ne i64 %and.$id, 0");
        Node.addIrLine("%boolBinOp.$id = zext i1 %logic.$id to i64");

        break;
      case BoolOperator.or:
        Node.addIrLine(
            "%and.$id = or i64 ${leftResult.regName}, ${rightResult.regName}");
        Node.addIrLine("%logic.$id = icmp ne i64 %and.$id, 0");
        Node.addIrLine("%boolBinOp.$id = zext i1 %logic.$id to i64");
        break;
      default:
        throw Exception("Unknown operator: $nodeValue");
    }
    return LangVal("%boolBinOp.$id", const PrimitiveType(PrimitiveTypes.int));
  }
}

/// Represents an if-then-else conditional statement in Balbismo.
///
/// An if node implements conditional execution based on a boolean condition.
/// If the condition evaluates to non-zero (true), the then-block is executed.
/// If an else-block is provided and the condition is zero (false), the else-block
/// is executed instead.
///
/// Example Balbismo code:
/// ```balbismo
/// int x = 10;
/// if (x > 5) {        // This is an IfNode
///   printf("Big\n");
/// } else {
///   printf("Small\n");
/// }
/// ```
///
/// This generates LLVM IR with conditional branches:
/// ```llvm
/// %conditionCast.0 = icmp ne i64 %x, 0
/// br i1 %conditionCast.0, label %then.0, label %else.0
/// then.0:
///   ; then block code
///   br label %end.0
/// else.0:
///   ; else block code
///   br label %end.0
/// end.0:
/// ```
class IfNode extends Node<void, void> {
  /// Constructs an if statement with condition, then-block, and optional else-block.
  ///
  /// Parameters:
  /// - [condition]: Expression that evaluates to the condition (0 = false, non-zero = true)
  /// - [thenBlock]: Block of statements to execute if condition is true
  /// - [elseBlock]: Optional block of statements to execute if condition is false
  IfNode(Node<dynamic, LangVal> condition, BlockNode thenBlock,
      [Node? elseBlock])
      : super(null, [condition, thenBlock, if (elseBlock != null) elseBlock]);

  Node<dynamic, LangVal> get condition => children[0] as Node<dynamic, LangVal>;
  BlockNode get thenBlock => children[1] as BlockNode;
  Node? get elseBlock => children.length > 2 ? children[2] : null;

  @override
  void evaluate(SymbolTable table) {
    var conditionResult = condition.evaluate(table);
    //cant be array
    //has to be int
    if (conditionResult.type is! PrimitiveType ||
        conditionResult.type.primitiveType != PrimitiveTypes.int) {
      throw Exception("Condition must be int");
    }

    Node.addIrLine(
        "%conditionCast.$id = icmp ne i64 ${conditionResult.regName}, 0");
    Node.addIrLine(
        "br i1 %conditionCast.$id, label %then.$id, label %else.$id");
    Node.addIrlLabel("then.$id");
    thenBlock.evaluate(table);
    final elseNode = elseBlock;
    Node.addIrLine("br label %end.$id");
    Node.endIrLabel();
    Node.addIrlLabel("else.$id");
    if (elseNode != null) {
      elseNode.evaluate(table);
    }

    Node.addIrLine("br label %end.$id");
    Node.endIrLabel();
    Node.addIrLine("end.$id:");
  }
}

/// Represents a while loop statement in Balbismo.
///
/// A while node implements iterative execution based on a condition.
/// The loop body is executed repeatedly as long as the condition evaluates
/// to non-zero (true). The condition is checked before each iteration,
/// so the loop may execute zero or more times.
///
/// Example Balbismo code:
/// ```balbismo
/// int i = 0;
/// while (i < 10) {    // This is a WhileNode
///   printf("%d\n", i);
///   i = i + 1;
/// }
/// ```
///
/// This generates LLVM IR with a loop structure:
/// ```llvm
/// br label %while.0
/// while.0:
///   ; evaluate condition
///   %conditionCast.0 = icmp ne i64 %i, 0
///   br i1 %conditionCast.0, label %block.0, label %end.0
/// block.0:
///   ; loop body code
///   br label %while.0
/// end.0:
/// ```
class WhileNode extends Node<void, void> {
  /// Constructs a while loop with condition and body block.
  ///
  /// Parameters:
  /// - [condition]: Expression that evaluates to the loop condition (0 = false, non-zero = true)
  /// - [block]: Block of statements to execute in each iteration
  WhileNode(Node<dynamic, LangVal> condition, BlockNode block)
      : super(null, [condition, block]);

  Node<dynamic, LangVal> get condition => children[0] as Node<dynamic, LangVal>;
  BlockNode get block => children[1] as BlockNode;

  @override
  void evaluate(SymbolTable table) {
    Node.addIrLine("br label %while.$id");
    Node.addIrlLabel("while.$id");
    var conditionResult = condition.evaluate(table);
    if (conditionResult.type is! PrimitiveType ||
        conditionResult.type.primitiveType != PrimitiveTypes.int) {
      throw Exception("Condition must be int");
    }

    Node.addIrLine(
        "%conditionCast.$id = icmp ne i64 ${conditionResult.regName}, 0");
    Node.addIrLine(
        "br i1 %conditionCast.$id, label %block.$id, label %end.$id");
    Node.endIrLabel();
    Node.addIrlLabel("block.$id");
    block.evaluate(table);
    Node.addIrLine("br label %while.$id");
    Node.endIrLabel();
    Node.addIrLine("end.$id:");
  }
}

/// Represents a type cast operation in Balbismo.
///
/// A type cast node converts a value from one primitive type to another.
/// Currently supports casting between int and float types in both directions.
/// If the source and target types are the same, the cast is a no-op.
///
/// Example Balbismo code:
/// ```balbismo
/// int x = 42;
/// float y = (float)x;  // This is a TypeCast from int to float
/// int z = (int)y;      // This is a TypeCast from float to int
/// ```
///
/// This generates LLVM IR conversion instructions:
/// ```llvm
/// %conv.0 = sitofp i64 %x to double    // int to float
/// %conv.1 = fptosi double %y to i64    // float to int
/// ```
class TypeCast extends Node<PrimitiveType, LangVal> {
  /// Constructs a type cast operation with target type and source expression.
  ///
  /// Parameters:
  /// - [type]: The target primitive type to cast to
  /// - [child]: The expression whose value will be cast
  TypeCast(PrimitiveType type, Node<dynamic, LangVal> child)
      : super(type, [child]);
  

  Node<dynamic, LangVal> get child => children[0] as Node<dynamic, LangVal>;

  @override
  LangVal evaluate(SymbolTable table) {
    final childResult = child.evaluate(table);
    if (childResult.type.primitiveType == nodeValue.primitiveType) {
      return childResult;
    }
    if (childResult.type.primitiveType == PrimitiveTypes.int &&
        nodeValue.primitiveType == PrimitiveTypes.float) {
      Node.addIrLine(
          "%conv.$id = sitofp i64 ${childResult.regName} to double");
      return LangVal("%conv.$id", const PrimitiveType(PrimitiveTypes.float));
    } else if (childResult.type.primitiveType == PrimitiveTypes.float &&
        nodeValue.primitiveType == PrimitiveTypes.int) {
      Node.addIrLine(
          "%conv.$id = fptosi double ${childResult.regName} to i64");
      return LangVal("%conv.$id", const PrimitiveType(PrimitiveTypes.int));
    }
    throw Exception("Invalid type cast");
  }

} 