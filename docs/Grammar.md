# mu Language Grammar Specification

This document defines the mu grammar using extended Backus–Naur form (EBNF) as implemented by the stage-0 parser.

---

## 1. Lexical Grammar

### 1.1 Identifiers

```
IDENTIFIER = letter { letter | digit | '_' } ;
```

Identifiers are case-sensitive and may start with a letter or underscore.

### 1.2 Literals

#### Integer

```
INTEGER = digit { digit } ;
```

#### String

```
STRING = '"' { character | ESCAPE } '"' ;
ESCAPE = '\' ( 'n' | 't' | '\\' | '"' ) ;
```

#### Boolean

```
BOOLEAN = 'true' | 'false' ;
```

#### Nil

```
NIL = 'nil' ;
```

---

## 2. Syntactic Grammar

### 2.1 Program Structure

```
PROGRAM = { ( IMPORT_STATEMENT | STATEMENT | FUNCTION_DECL ) [ ';' ] } EOF ;
```

Import statements may only appear at the outermost level; blocks and nested scopes cannot contain an `import` (attempting to place one inside a `fn` or `{ ... }` is a compile-time error). Semicolons are optional when newline or closing delimiters already separate statements, and they may also be used to place multiple statements on a single line.

### 2.2 Function Declarations

```
FUNCTION_DECL = 'fn' IDENTIFIER '(' PARAMS? ')' BLOCK ;
PARAMS = PARAM { ',' PARAM } ;
PARAM = IDENTIFIER [ '...' ] ;
```

Only the final parameter may use `...` to indicate variadic arguments.

### 2.3 Function Literals

```
FUNCTION_LITERAL = 'fn' '(' PARAMS? ')' BLOCK ;
```

### 2.4 Statements

```
STATEMENT =
      BLOCK
    | VAR_DECL
    | ASSIGNMENT
    | UPDATE
    | RETURN
    | BREAK
    | CONTINUE
    | IF_STATEMENT
    | WHILE_STATEMENT
    | EXPR_STATEMENT
    ;
```

#### 2.4.1 Block

```
BLOCK = '{' { STATEMENT [ ';' ] } '}' ;
```

#### 2.4.2 Variable Declaration

```
VAR_DECL = IDENTIFIER ':=' EXPRESSION ;
```

#### 2.4.3 Assignment

```
ASSIGNMENT = ( IDENTIFIER | INDEX_EXPR ) '=' EXPRESSION ;
```

#### 2.4.4 Update

```
UPDATE =
      ( IDENTIFIER | INDEX_EXPR ) '++'
    | ( IDENTIFIER | INDEX_EXPR ) '--'
    | ( IDENTIFIER | INDEX_EXPR ) '+=' EXPRESSION
    | ( IDENTIFIER | INDEX_EXPR ) '-=' EXPRESSION
    ;
```

#### 2.4.4 Return

```
RETURN = 'return' EXPRESSION? ;

BREAK = 'break' ;

CONTINUE = 'continue' ;
```

#### 2.4.5 If Statement

```
IF_STATEMENT = 'if' EXPRESSION BLOCK [ 'else' BLOCK ] ;
```

#### 2.4.6 While Statement

```
WHILE_STATEMENT = 'while' EXPRESSION BLOCK ;
```

#### 2.4.7 Expression Statement

```
EXPR_STATEMENT = EXPRESSION ;
```

#### 2.4.8 Import Statement

```
IMPORT_STATEMENT = 'import' ( STRING | IDENTIFIER ) [ 'as' IDENTIFIER ] ;
```

Import paths may be string literals or bare identifiers, and the optional `.mu` suffix is stripped during resolution. Path normalization removes redundant `/` segments, ignores `.` entries, and processes `..` segments without escaping the embedded standard library root. Every import binds the chosen identifier (optionally renamed with `as alias`) to the imported module’s namespace, and module symbols must be accessed through the namespace (for example `strings.split`). See `Specification.md` for the exact lookup order that uses the `lib/` tree, `MULIB` overrides, and optional filesystem fallbacks.

---

## 3. Expressions

```
EXPRESSION = LOGICAL_OR ;

LOGICAL_OR = LOGICAL_AND { '||' LOGICAL_AND } ;
LOGICAL_AND = EQUALITY { '&&' EQUALITY } ;
EQUALITY = RELATIONAL { ( '==' | '!=' ) RELATIONAL } ;
RELATIONAL = ADDITIVE { ( '<' | '<=' | '>' | '>=' ) ADDITIVE } ;
ADDITIVE = MULTIPLICATIVE { ( '+' | '-' | '|' | '^' ) MULTIPLICATIVE } ;
MULTIPLICATIVE = POWER { ( '*' | '/' | '%' | '<<' | '>>' | '&' ) POWER } ;
POWER = UNARY { '**' UNARY } ;
UNARY = ( '!' | '-' ) UNARY | PRIMARY ;
PRIMARY =
      IDENTIFIER
    | INTEGER
    | STRING
    | BOOLEAN
    | NIL
    | '(' EXPRESSION ')'
    | FUNCTION_LITERAL
    | LIST_LITERAL
    | MAP_LITERAL
    | INDEX_EXPR
    | CALL_EXPR
    ;
```

### 3.1 List Literals

```
LIST_LITERAL = '[' [ EXPRESSION { ',' EXPRESSION } ] ']' ;
```

### 3.2 Map Literals

```
MAP_LITERAL = '{' [ KEYVALUE { ',' KEYVALUE } ] '}' ;
KEYVALUE = STRING ':' EXPRESSION ;
```

### 3.3 Indexing

```
INDEX_EXPR = PRIMARY '[' EXPRESSION ']' ;
```

### 3.4 Function Calls

```
CALL_EXPR = PRIMARY '(' [ EXPRESSION { ',' EXPRESSION } ] ')' ;
```

---

## 4. Operator Precedence Summary

From lowest (binds least) to highest (binds most):

1. `||`
2. `&&`
3. `==`, `!=`
4. `<`, `<=`, `>`, `>=`
5. `+`, `-`, `|`, `^`
6. `*`, `/`, `%`, `<<`, `>>`, `&`
7. `**`
8. Unary `!`, unary `-`, unary `~`
9. Primary expressions (identifiers, literals, parentheses, function literals, list/map literals, indexing, calls)

Operators of the same precedence group associate to the left.

---

## 5. Reserved Keywords

```
fn
if
else
while
continue
break
return
true
false
nil

import
```

## 6. File Extension

```
.mu
```
