

/// Symbol table management for the Balbismo compiler.
///
/// This library provides the core symbol table functionality that tracks variables,
/// functions, and their scopes during compilation. The symbol table supports nested
/// scopes (lexical scoping) and manages string constants used in the program.
///
/// The symbol table is essential for:
/// - Variable declaration and lookup
/// - Function definition and resolution
/// - Scope management (local vs global variables)
/// - String constant deduplication
/// - Type checking and validation

import 'package:balbismo/vars.dart';



/// Manages symbols (variables and functions) within a scope during compilation.
///
/// The [SymbolTable] class implements a hierarchical symbol table that supports
/// lexical scoping. Each symbol table can have a parent, forming a scope chain
/// that allows variables to be looked up in enclosing scopes.
///
/// The symbol table tracks:
/// - Local variables within the current scope
/// - Function definitions (stored globally)
/// - String constants for deduplication
/// - Parent-child relationships for scope resolution
///
/// Example usage:
/// ```dart
/// final globalScope = SymbolTable();
/// final localScope = globalScope.createChild();
/// ```
class SymbolTable {
  /// Internal storage for variables in this scope.
  final Map<String, LangVar> _table = {};

  /// Global storage for function definitions accessible from all scopes.
  static final Map<String, LangFunc> _functions = {};

  /// Global storage for string constants to enable deduplication.
  ///
  /// Maps string content to LLVM global variable names for efficient
  /// storage and reuse of string literals.
  static Map<String, String> strings = {};

  /// Reference to the parent scope for lexical scoping support.
  SymbolTable? _parent;

  /// Creates a new child symbol table for nested scope management.
  ///
  /// This method implements lexical scoping by creating a new symbol table
  /// that has the current table as its parent. Variables declared in the
  /// child scope can access variables from parent scopes, but not vice versa.
  ///
  /// Returns:
  ///   A new [SymbolTable] instance with this table as its parent.
  ///
  /// Example:
  /// ```dart
  /// final globalScope = SymbolTable();
  /// final functionScope = globalScope.createChild();
  /// final blockScope = functionScope.createChild();
  /// ```
  SymbolTable createChild() {
    final child = SymbolTable();
    child._parent = this;
    return child;
  }

  /// Registers a function definition in the global function table.
  ///
  /// Functions are stored globally and can be accessed from any scope.
  /// This method ensures that function names are unique across the entire program.
  ///
  /// Parameters:
  /// - [key]: The function name (must be unique)
  /// - [value]: The function definition containing the AST and metadata
  ///
  /// Returns:
  ///   The registered [LangFunc] instance
  ///
  /// Throws:
  /// - [Exception] if a function with the same name already exists
  ///
  /// Example:
  /// ```dart
  /// final func = LangFunc("add", funcDeclarationNode);
  /// SymbolTable.createFunction("add", func);
  /// ```
  static LangFunc createFunction(String key, LangFunc value) {
    if (_functions.containsKey(key)) {
      throw Exception("Key already exists");
    }
    _functions[key] = value;
    return value;
  }

  /// Retrieves a function definition by name from the global function table.
  ///
  /// This method is used during function call resolution to find the
  /// function definition and validate the call.
  ///
  /// Parameters:
  /// - [key]: The function name to look up
  ///
  /// Returns:
  ///   The [LangFunc] instance if found, null otherwise
  ///
  /// Example:
  /// ```dart
  /// final func = SymbolTable.getFunction("add");
  /// if (func != null) {
  ///   // Use function for call validation
  /// }
  /// ```
  static LangFunc? getFunction(String key) {
    return _functions[key];
  }


  /// Declares a new variable in the current scope.
  ///
  /// This method is used during variable declaration to register a variable
  /// in the current scope. It ensures that variable names are unique within
  /// the same scope level.
  ///
  /// Parameters:
  /// - [key]: The variable name (must be unique in current scope)
  /// - [value]: The variable definition containing type and memory location
  ///
  /// Returns:
  ///   The registered [LangVar] instance
  ///
  /// Throws:
  /// - [Exception] if a variable with the same name already exists in this scope
  ///
  /// Example:
  /// ```dart
  /// final intVar = LangVar("%ptr.x", PrimitiveType(PrimitiveTypes.int));
  /// symbolTable.create("x", intVar);
  /// ```
  LangVar create(String key, LangVar value) {
    if (_table.containsKey(key)) {
      throw Exception("Key already exists");
    }
    _table[key] = value;
    return value;
  }

  /// Validates that a variable assignment is type-safe and the variable exists.
  ///
  /// This method is used during assignment operations to ensure:
  /// 1. The variable being assigned to actually exists (in current or parent scopes)
  /// 2. The value being assigned is compatible with the variable's type
  ///
  /// Parameters:
  /// - [key]: The variable name to validate
  /// - [value]: The value being assigned (contains type information)
  ///
  /// Throws:
  /// - [Exception] if the variable doesn't exist
  /// - [Exception] if there's a type mismatch between variable and value
  ///
  /// Example:
  /// ```dart
  /// // Before assignment, validate the operation
  /// symbolTable.canSet("x", intValue);
  /// // Then perform the assignment...
  /// ```
  void canSet(String key, LangVal value) {
    final langVar = get(key);
    if (langVar == null) {
      throw Exception("Key does not exist");
    }
    if (langVar.type != value.type) {
      throw Exception("Type mismatch");
    }
  }

  /// Retrieves a variable definition by name, searching through scope hierarchy.
  ///
  /// This method implements lexical scoping by searching for variables in the
  /// current scope first, then recursively searching parent scopes if not found.
  /// This allows inner scopes to access variables from outer scopes.
  ///
  /// Parameters:
  /// - [key]: The variable name to look up
  ///
  /// Returns:
  ///   The [LangVar] instance if found in current or parent scopes, null otherwise
  ///
  /// Example:
  /// ```dart
  /// final x = symbolTable.get("x"); // Searches current and parent scopes
  /// if (x != null) {
  ///   // Variable found, can access its type and pointer
  /// }
  /// ```
  LangVar? get(String key) {
    // return _table[key];
    if (_table.containsKey(key)) {
      return _table[key];
    } else if (_parent != null) {
      return _parent?.get(key);
    } else {
      return null;
    }
  }

  /// Removes a variable from the current scope.
  ///
  /// This method removes a variable definition from the current scope only.
  /// It does not affect variables in parent or child scopes.
  ///
  /// Parameters:
  /// - [key]: The variable name to remove from this scope
  ///
  /// Note: This method silently does nothing if the key doesn't exist
  /// in the current scope.
  void remove(String key) {
    _table.remove(key);
  }

  /// Clears all variables from the current scope.
  ///
  /// This method removes all variable definitions from the current scope,
  /// effectively resetting it to an empty state. Parent and child scopes
  /// are not affected.
  ///
  /// This is primarily used for cleanup and testing purposes.
  void clear() {
    _table.clear();
  }
}


