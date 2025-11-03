/// Core type system definitions for the Balbismo programming language.
///
/// This library defines the fundamental types used throughout the Balbismo compiler,
/// including primitive types, language types, and value representations that form
/// the foundation of the type system and LLVM IR generation.

import 'package:balbismo/node.dart';
import 'package:equatable/equatable.dart';

/// Enumeration of primitive types supported by the Balbismo language.
///
/// Balbismo supports two fundamental primitive types that map directly to LLVM types:
/// - [int]: 64-bit integer type (`i64` in LLVM)
/// - [float]: Double precision floating point type (`double` in LLVM)
///
/// These types serve as the building blocks for more complex types like arrays.
enum PrimitiveTypes {
  /// 64-bit signed integer type, equivalent to LLVM's `i64`
  int("i64"),

  /// Double precision floating point type, equivalent to LLVM's `double`
  float("double");

  /// The corresponding LLVM IR type string for this primitive type.
  final String _irType;

  /// Returns the LLVM IR type representation for this primitive type.
  ///
  /// Returns:
  /// - `"i64"` for integer types
  /// - `"double"` for floating point types
  String get irType => _irType;

  /// Constructs a primitive type with its LLVM IR representation.
  const PrimitiveTypes(this._irType);

  /// Converts a string representation to the corresponding primitive type.
  ///
  /// Parameters:
  /// - [type]: String representation ("int" or "float")
  ///
  /// Returns:
  ///   The corresponding [PrimitiveTypes] enum value
  ///
  /// Throws:
  /// - [Exception] if the type string is not recognized
  static PrimitiveTypes fromString(String type) {
    switch (type) {
      case "int":
        return PrimitiveTypes.int;
      case "float":
        return PrimitiveTypes.float;
      default:
        throw Exception("Unknown type: $type");
    }
  }

  /// Returns the LLVM IR type string representation of this primitive type.
  ///
  /// This is equivalent to accessing the [irType] getter.
  @override
  toString() => irType;
}

/// Abstract base class for all language types in Balbismo.
///
/// This class serves as the foundation for the type system, providing common
/// functionality for type representation and LLVM IR generation. All concrete
/// types in Balbismo (primitive types, arrays, etc.) inherit from this class.
///
/// The class uses Equatable for proper equality comparison based on the
/// underlying primitive type, ensuring type compatibility checks work correctly.
abstract class LangType extends Equatable {
  /// The underlying primitive type that forms the basis of this language type.
  final PrimitiveTypes primitiveType;

  /// Constructs a language type with the specified primitive type.
  const LangType(this.primitiveType);

  /// Equatable implementation for proper type comparison.
  ///
  /// Two language types are considered equal if they have the same primitive type.
  @override
  List<Object> get props => [primitiveType];

  /// Returns the LLVM IR type representation for this language type.
  ///
  /// For primitive types, this delegates to the primitive type's irType.
  /// For complex types like arrays, this provides the appropriate LLVM syntax.
  String get irType => primitiveType.irType;

  /// Returns the LLVM IR type string representation of this language type.
  ///
  /// This is equivalent to accessing the [irType] getter.
  @override
  String toString() {
    return irType;
  }
}

/// Represents a primitive language type in Balbismo.
///
/// This class wraps primitive types ([PrimitiveTypes.int] and [PrimitiveTypes.float])
/// providing a consistent interface that integrates with the broader type system.
/// Primitive types are the fundamental building blocks of more complex types like arrays.
///
/// Example usage:
/// ```dart
/// final intType = PrimitiveType(PrimitiveTypes.int); // represents 'int' in Balbismo
/// final floatType = PrimitiveType(PrimitiveTypes.float); // represents 'float' in Balbismo
/// ```
class PrimitiveType extends LangType {
  /// Constructs a primitive type from a [PrimitiveTypes] enum value.
  const PrimitiveType(super.primitiveType);
}

/// Represents an array type in Balbismo.
///
/// Arrays in Balbismo are represented as pointers to the element type in LLVM IR.
/// This class extends [LangType] to provide array-specific functionality, including
/// proper LLVM IR type representation with pointer notation.
///
/// Arrays are dynamically sized at runtime and are allocated on the stack.
/// They cannot be resized after creation but can be passed by reference to functions.
///
/// Example usage:
/// ```dart
/// final intArrayType = ArrayType(PrimitiveTypes.int); // represents 'int[]' in Balbismo
/// final floatArrayType = ArrayType(PrimitiveTypes.float); // represents 'float[]' in Balbismo
/// ```
class ArrayType extends LangType {
  /// Constructs an array type for the specified primitive element type.
  const ArrayType(super.primitiveType);

  /// Returns the LLVM IR type representation for this array type.
  ///
  /// Arrays are represented as pointers in LLVM IR (e.g., `i64*` for int arrays).
  ///
  /// Returns:
  /// - `"i64*"` for integer arrays
  /// - `"double*"` for floating point arrays
  @override
  String get irType => "${primitiveType.irType}*";
}

/// Represents a value in the Balbismo language with its type information.
///
/// A [LangVal] encapsulates both the LLVM register name (where the value is stored)
/// and the type information for that value. This is used throughout the compiler
/// to track values during expression evaluation and code generation.
///
/// The generic type parameter [T] ensures type safety by constraining the type
/// to valid Balbismo language types that extend [LangType].
///
/// Example usage:
/// ```dart
/// final intVal = LangVal("%result", PrimitiveType(PrimitiveTypes.int));
/// final floatVal = LangVal("%temp", PrimitiveType(PrimitiveTypes.float));
/// ```
class LangVal<T extends LangType> {
  /// The LLVM register name where this value is stored.
  ///
  /// This is typically an LLVM register like `%reg1`, `%temp`, etc.
  final String regName;

  /// The type of this value.
  ///
  /// This contains both the primitive type information and LLVM IR representation.
  final T type;

  /// Constructs a language value with the specified register name and type.
  const LangVal(this.regName, this.type);
}

/// Represents a variable in the Balbismo language with its type and memory location.
///
/// A [LangVar] encapsulates both the LLVM pointer name (where the variable is allocated
/// in memory) and the type information for that variable. This is used by the symbol
/// table to track variable declarations and their memory locations.
///
/// The generic type parameter [T] ensures type safety by constraining the type
/// to valid Balbismo language types that extend [LangType].
///
/// Example usage:
/// ```dart
/// final intVar = LangVar("%ptr.x", PrimitiveType(PrimitiveTypes.int));
/// final arrayVar = LangVar("%ptr.arr", ArrayType(PrimitiveTypes.float));
/// ```
class LangVar<T extends LangType> {
  /// The LLVM pointer name where this variable is allocated in memory.
  ///
  /// This is typically an LLVM pointer register like `%ptr.x`, `%ptr.arr`, etc.
  final String ptrName;

  /// The type of this variable.
  ///
  /// This contains both the primitive type information and LLVM IR representation.
  final T type;

  /// Constructs a language variable with the specified pointer name and type.
  const LangVar(this.ptrName, this.type);
}

/// Represents a function definition in the Balbismo language.
///
/// A [LangFunc] encapsulates both the function name and its AST declaration node.
/// This is used by the symbol table to track function definitions and enable
/// function calls during compilation.
///
/// Example usage:
/// ```dart
/// final func = LangFunc("addNumbers", funcDeclarationNode);
/// ```
class LangFunc {
  /// The name of the function.
  final String name;

  /// The AST declaration node containing the function's implementation details.
  ///
  /// This includes the function's return type, parameters, and body.
  final FuncDec funcDec;

  /// Constructs a language function with the specified name and declaration.
  LangFunc(this.name, this.funcDec);
}
