# cparser.tcl

package require yeti

# Create the object used to assemble the parser.
yeti::yeti CParserGenerator -name CParser -start translation_unit

# Define internal variables and methods.
CParserGenerator code private {
    # Database of global symbols and types.  This value is returned as the
    # result of the parse method.
    #
    # The top-level keys are core, enum, struct, union, typedef, and variable.
    # enum, struct, and union only describe explicitly tagged types, not those
    # used anonymously in a field, variable, or typedef.
    #
    # The second-level keys are the tag names of the types or variables being
    # described.  Anonymous types are not present at this level of the database.
    # For core types, the names are sorted lists of type specifiers, e.g. "int
    # short unsigned" or "int long long", and int is automatically added to the
    # list if none of char, int, float, or double are explicitly given by the
    # source code.
    #
    # The third-level keys describe type-/variable-wide data, and different
    # keys will be present depending on the category or other particulars of the
    # data being described, though several keys are common.
    #
    # Further nesting below the third level is possible.  For example, anonymous
    # types are defined at point of use, not at the top level.
    #
    # The caller is invited to augment data at and below the third level with
    # information such as enumerator values, array size, and memory layout.
    #
    # Elements in all nested lists and dicts are in the order they are found in
    # the source file.
    #
    # Two keys will always appear at the third (type-/variable-wide) level.
    # These simply repeat the first and second level keys.  This makes it easy
    # to operate on extracts from the overall data structure, and it facilitates
    # recursive use of the third-level structure within nested type dicts.
    #
    # - category: Type category.  Repeats the first level key.  Can be core,
    #   enum, struct, union, typedef, or variable.
    #
    # - name: enum/struct/union type tag or typedef/variable name.  Repeats the
    #   second level key.
    #
    # The core category has no additional keys because the source code being
    # parsed uses but does not define the core types.
    #
    # The enum category has one more key, enumerators, giving the enumerator
    # list.  Each element in the enumerator list is a dict containing the name
    # subkey which supplies the symbolic name for the enumerator.
    #
    # The struct and union categories provide a fields key which gives the list
    # of fields in the aggregate.  Each element of the field list is a dict with
    # the following keys:
    #
    # - name: Name of the field.
    #
    # - type: Type of the field.  Defined the same as any other third-level dict
    #   in the database.  It always has the category subkey, and the presence of
    #   other subkeys depends on whether or not the field type is an anonymous
    #   enum/struct/union.  If anonymous, the name subkey is omitted, and the
    #   type-specific subkeys (enumerators, fields, type, index) are present.
    #   If not anonymous, or if this field is a core type or typedef, the name
    #   subkey is present, and the type-specific subkeys are omitted.
    #
    # - reuse: Facility for using an anonymous struct, union, or enum to
    #   declare more than one variable, typedef, or aggregate field.  If this
    #   key is present, the type key is omitted.  Its value gives the name of
    #   the prior entry in the same list of variables, typedefs, or fields as
    #   the current entry which has the type key.  Reuse is distinct from simply
    #   repeating the type definition because C considers identical anonymous
    #   types to be incompatible, whereas C allows an anonymous type definition
    #   to be used several times in a row to produce variables, typedefs, or
    #   fields with compatible types.  It's quite possible for reused types to
    #   have different indexing.
    #
    # - index: List of indirections used to access the field.  Each element of
    #   the list is a dict with the method subkey whose value is either pointer
    #   or array.  The first element in the list corresponds to the innermost
    #   indirection, the index value of "int (*x)[]" would be the two-element
    #   list: {{method pointer} {method array}}.  This list does not include any
    #   indirections which may additionally be applied by typedefs.  This key is
    #   omitted if no indirections are being used.
    #
    # The typedef and variable categories include the type, reuse, and index
    # keys, which have the same definition as the like-named keys inside the
    # struct and union field list elements.
    #
    # Here is an example showing C code and its corresponding database dict:
    #
    # typedef struct {int a; enum T {E1, E2} *b;} S, (*P)[3];
    # P x, *y[5];
    #
    # core {
    #   int {category core name int}
    # } enum {
    #   T {category enum name T enumerators {{name E1} {name E2}}}
    # } typedef {
    #   S {
    #     category typedef name S
    #     type {category struct fields {
    #       {name a type {category core name int}}
    #       {name b type {category enum name T} index {{method pointer}}}
    #     }}
    #   } P {
    #     category typedef name P reuse S
    #     index {{method pointer} {method array}}
    #   }
    # } variable {
    #   x {
    #     category variable name x
    #     type {category typedef name P}
    #   } y {
    #     category variable name y
    #     type {category typedef name P}
    #     index {{method array} {method pointer}}
    #   }
    # }
    variable database {}

    # Nonzero if the typedef storage class specifier was encountered within the
    # current declaration.
    variable typedef 0

    # registerTypedef --
    # If this declarator is part of a typedef, register the identifier as a type
    # name.  This must be done as early as possible because the parser maintains
    # one token of lookhead.  If this processing were to be deferred until the
    # declaration is complete, the next token, which could be this new type
    # name, will have already been read and miscategorized as an identifier.
    method registerTypedef {declarator} {
        if {$typedef} {
            $scanner addTypeName [dict get $declarator name]
        }
    }

    # registerDecl --
    # Save the current variable or typedef declaration in the database, and
    # prepare for the next.
    method registerDecl {decls} {
        foreach decl $decls {
            if {[dict exists $decl name]} {
                set category [lindex {variable typedef} $typedef]
                dict set decl category $category
                dict set database $category [dict get $decl name] $decl
            }
        }
        set typedef 0
    }

    # appendArray --
    # Append one level of array indexing to an index list in a declarator.
    method appendArray {decl} {
        dict lappend decl index [dict create method array]
    }

    # mergeType --
    # Combine two type specifiers, concatenating their name lists and merging
    # all other dict keys.
    method mergeType {lhs rhs} {
        if {[dict exists $lhs name] && [dict exists $rhs name]} {
            dict set rhs name [lsort [concat\
                    [dict get $lhs name] [dict get $rhs name]]]
        }
        dict merge $lhs $rhs
    }

    # mergeDeclType --
    # Merge declaration specifiers with a list of initial declarators.
    # Specially handle the case of an anonymous type being used to declare
    # multiple fields, variables, or typedefs.
    method mergeDeclType {type decls} {
        # Default to int if no type given.
        if {![dict size $type]} {
            set type [newCore int]
        }

        # Assemble the declarators, complete with type.
        if {[dict exists $type name] || [llength $decls] < 2} {
            # Normal situation: merge the specifiers into each declarator.
            lmap decl $decls {dict replace $decl type $type}
        } else {
            # Complex situation: merge the specifiers only into the first
            # declarator, then omit type specifier data from each subsequent
            # merged declarator, instead referring back to the first.
            set decls [lassign $decls first]
            dict set first type $type
            set name [dict get $first name]
            list $first {*}[lmap decl $decls {dict replace $decl reuse $name}]
        }
    }

    # newCore --
    # Create a core type given its name list, and store it into the database if
    # not already present.
    method newCore {name} {
        if {![dict exists database core $name]} {
            dict set database core $name category core
            dict set database core $name name $name
        }
        dict create category core name $name
    }

    # newAgg --
    # Create a struct or union given its category, name, and field list.  Either
    # name or fields can be empty string if not directly specified.  Store the
    # struct or union in the database if it has both a name and a field list.
    method newAgg {category name fields} {
        if {$name eq {}} {
            dict create category $category fields $fields
        } else {
            if {[llength $fields]} {
                dict set database $category $name name $name
                dict set database $category $name category $category
                dict set database $category $name fields $fields
            }
            dict create category $category name $name
        }
    }

    # newEnum --
    # Create an enumeration given its name and enumerator list.  Either can be
    # empty string if not directly specified.  Store the enum in the database if
    # it has both a name and an enumerator list.
    method newEnum {name enumerators} {
        if {$name eq {}} {
            dict create category enum enumerators $enumerators
        } else {
            if {[llength $enumerators]} {
                dict set database enum $name name $name
                dict set database enum $name category enum
                dict set database enum $name enumerators $enumerators
            }
            dict create category enum name $name
        }
    }
}

# On error, print the filename, line number, and column number.
CParserGenerator code error {
    if {[set file [$scanner cget -file]] ne {}} {
        puts -nonewline $verbout $file:
    }
    puts $verbout "[$scanner cget -line]:[$scanner cget -column]: $yyerrmsg"
}

# Reset handler.
CParserGenerator code reset {
    set database {}
    set typedef 0
}

# Disable the default {return $1} behavior.
CParserGenerator code returndefault {}

# Define the grammar and parser behavior.
CParserGenerator add {
    optional_comma
    {}  -
  | {,} -

    primary_expression
    {IDENTIFIER}     -
  | {CONSTANT}       -
  | {STRING_LITERAL} -
  | {( expression )} -

    postfix_expression
    {primary_expression}                              -
  | {postfix_expression [ expression ]}               -
  | {postfix_expression ( )}                          -
  | {postfix_expression ( argument_expression_list )} -
  | {postfix_expression . IDENTIFIER}                 -
  | {postfix_expression -> IDENTIFIER}                -
  | {postfix_expression ++}                           -
  | {postfix_expression --}                           -

    argument_expression_list
    {assignment_expression}                            -
  | {argument_expression_list , assignment_expression} -

    unary_expression
    {postfix_expression}             -
  | {++ unary_expression}            -
  | {-- unary_expression}            -
  | {unary_operator cast_expression} -
  | {SIZEOF unary_expression}        -
  | {SIZEOF ( type_name )}           -

    unary_operator
    {&} -
  | {*} -
  | {+} -
  | {-} -
  | {!} -
  | {~} -

    cast_expression
    {unary_expression}              -
  | {( type_name ) cast_expression} -

    multiplicative_expression
    {cast_expression}                             -
  | {multiplicative_expression * cast_expression} -
  | {multiplicative_expression / cast_expression} -
  | {multiplicative_expression % cast_expression} -

    additive_expression
    {multiplicative_expression}                       -
  | {additive_expression + multiplicative_expression} -
  | {additive_expression - multiplicative_expression} -

    shift_expression
    {additive_expression}                     -
  | {shift_expression << additive_expression} -
  | {shift_expression >> additive_expression} -

    relational_expression
    {shift_expression}                          -
  | {relational_expression < shift_expression}  -
  | {relational_expression > shift_expression}  -
  | {relational_expression <= shift_expression} -
  | {relational_expression >= shift_expression} -

    equality_expression
    {relational_expression}                        -
  | {equality_expression == relational_expression} -
  | {equality_expression != relational_expression} -

    and_expression
    {equality_expression}                  -
  | {and_expression & equality_expression} -

    exclusive_or_expression
    {and_expression}                           -
  | {exclusive_or_expression ^ and_expression} -

    inclusive_or_expression
    {exclusive_or_expression}                           -
  | {inclusive_or_expression | exclusive_or_expression} -

    logical_and_expression
    {inclusive_or_expression}                           -
  | {logical_and_expression && inclusive_or_expression} -

    logical_or_expression
    {logical_and_expression}                          -
  | {logical_or_expression || logical_and_expression} -

    conditional_expression
    {logical_or_expression}                                       -
  | {logical_or_expression ? expression : conditional_expression} -

    assignment_expression
    {conditional_expression}                                     -
  | {unary_expression assignment_operator assignment_expression} -

    assignment_operator
    {=}   -
  | {*=}  -
  | {/=}  -
  | {%=}  -
  | {+=}  -
  | {-=}  -
  | {<<=} -
  | {>>=} -
  | {&=}  -
  | {^=}  -
  | {|=}  -

    expression
    {assignment_expression}              -
  | {expression , assignment_expression} -

    constant_expression
    {conditional_expression} -

    declaration
    {declaration_specifiers ;}                      {return $1}
  | {declaration_specifiers init_declarator_list ;} {mergeDeclType $1 $2}

    declaration_specifiers
    {storage_class_specifier}                        -
  | {storage_class_specifier declaration_specifiers} {return $2}
  | {type_specifier}                                 {return $1}
  | {type_specifier declaration_specifiers}          {mergeType $1 $2}
  | {type_qualifier}                                 -
  | {type_qualifier declaration_specifiers}          {return $2}

    init_declarator_list
    {init_declarator}                        {list $1}
  | {init_declarator_list , init_declarator} {concat $1 [list $3]}

    init_declarator
    {declarator}               {registerTypedef $1; return $1}
  | {declarator = initializer} {return $1}

    storage_class_specifier
    {TYPEDEF}  {set typedef 1}
  | {EXTERN}   -
  | {STATIC}   -
  | {AUTO}     -
  | {REGISTER} -

    type_specifier
    {VOID}                      {newCore void}
  | {CHAR}                      {newCore char}
  | {SHORT}                     {newCore short}
  | {INT}                       {newCore int}
  | {LONG}                      {newCore long}
  | {FLOAT}                     {newCore float}
  | {DOUBLE}                    {newCore double}
  | {SIGNED}                    {newCore signed}
  | {UNSIGNED}                  {newCore unsigned}
  | {struct_or_union_specifier} {return $1}
  | {enum_specifier}            {return $1}
  | {TYPE_NAME}                 {dict create category typedef name $1}

    struct_or_union_specifier
    {struct_or_union IDENTIFIER \{ struct_declaration_list \}} {newAgg $1 $2 $4}
  | {struct_or_union \{ struct_declaration_list \}}            {newAgg $1 {} $3}
  | {struct_or_union IDENTIFIER}                               {newAgg $1 $2 {}}

    struct_or_union
    {STRUCT} {return struct}
  | {UNION}  {return union}

    struct_declaration_list
    {struct_declaration}                         {return $1}
  | {struct_declaration_list struct_declaration} {concat $1 $2}

    struct_declaration
    {specifier_qualifier_list struct_declarator_list ;} {mergeDeclType $1 $2}

    specifier_qualifier_list
    {type_specifier specifier_qualifier_list} {mergeType $1 $2}
  | {type_specifier}                          {return $1}
  | {type_qualifier specifier_qualifier_list} {return $2}
  | {type_qualifier}                          -

    struct_declarator_list
    {struct_declarator}                          {list $1}
  | {struct_declarator_list , struct_declarator} {concat $1 [list $3]}

    struct_declarator
    {declarator}                       {return $1}
  | {: constant_expression}            -
  | {declarator : constant_expression} {return $1}

    enum_specifier
    {ENUM \{ enumerator_list optional_comma \}}            {newEnum {} $3}
  | {ENUM IDENTIFIER \{ enumerator_list optional_comma \}} {newEnum $2 $4}
  | {ENUM IDENTIFIER}                                      {newEnum $2 {}}

    enumerator_list
    {enumerator}                   {list [dict create name $1]}
  | {enumerator_list , enumerator} {concat $1 [list [dict create name $3]]}

    enumerator
    {IDENTIFIER}                       {return $1}
  | {IDENTIFIER = constant_expression} {return $1}

    type_qualifier
    {CONST}    -
  | {VOLATILE} -

    declarator
    {pointer direct_declarator} {dict lappend 2 index {*}$1}
  | {direct_declarator}         {return $1}

    direct_declarator
    {IDENTIFIER}                                {dict create name $1}
  | {( declarator )}                            {return $2}
  | {direct_declarator [ constant_expression ]} {appendArray $1}
  | {direct_declarator [ ]}                     {appendArray $1}
  | {direct_declarator ( parameter_type_list )} {return $1}
  | {direct_declarator ( identifier_list )}     {return $1}
  | {direct_declarator ( )}                     {return $1}

    pointer
    {*}                             {list [dict create method pointer]}
  | {* type_qualifier_list}         {list [dict create method pointer]}
  | {* pointer}                     {lappend 2 [dict create method pointer]}
  | {* type_qualifier_list pointer} {lappend 3 [dict create method pointer]}

    type_qualifier_list
    {type_qualifier}                     -
  | {type_qualifier_list type_qualifier} -

    parameter_type_list
    {parameter_list}       -
  | {parameter_list , ...} -

    parameter_list
    {parameter_declaration}                  -
  | {parameter_list , parameter_declaration} -

    parameter_declaration
    {declaration_specifiers declarator}          -
  | {declaration_specifiers abstract_declarator} -
  | {declaration_specifiers}                     -

    identifier_list
    {IDENTIFIER}                   -
  | {identifier_list , IDENTIFIER} -

    type_name
    {specifier_qualifier_list}                     -
  | {specifier_qualifier_list abstract_declarator} -

    abstract_declarator
    {pointer}                            -
  | {direct_abstract_declarator}         -
  | {pointer direct_abstract_declarator} -

    direct_abstract_declarator
    {( abstract_declarator )}                            -
  | {[ ]}                                                -
  | {[ constant_expression ]}                            -
  | {direct_abstract_declarator [ ]}                     -
  | {direct_abstract_declarator [ constant_expression ]} -
  | {( )}                                                -
  | {( parameter_type_list )}                            -
  | {direct_abstract_declarator ( )}                     -
  | {direct_abstract_declarator ( parameter_type_list )} -

    initializer
    {assignment_expression}                 -
  | {\{ initializer_list optional_comma \}} -

    initializer_list
    {initializer}                    -
  | {initializer_list , initializer} -

    statement
    {labeled_statement}    -
  | {compound_statement}   -
  | {expression_statement} -
  | {selection_statement}  -
  | {iteration_statement}  -
  | {jump_statement}       -

    labeled_statement
    {IDENTIFIER : statement}               -
  | {CASE constant_expression : statement} -
  | {DEFAULT : statement}                  -

    compound_statement
    {\{ \}}                                 -
  | {\{ statement_list \}}                  -
  | {\{ declaration_list \}}                -
  | {\{ declaration_list statement_list \}} -

    declaration_list
    {declaration}                  -
  | {declaration_list declaration} -

    statement_list
    {statement}                -
  | {statement_list statement} -

    expression_statement
    {;}            -
  | {expression ;} -

    selection_statement
    {IF ( expression ) statement}                -
  | {IF ( expression ) statement ELSE statement} -
  | {SWITCH ( expression ) statement}            -

    iteration_statement
    {WHILE ( expression ) statement}                                         -
  | {DO statement WHILE ( expression ) ;}                                    -
  | {FOR ( expression_statement expression_statement ) statement}            -
  | {FOR ( expression_statement expression_statement expression ) statement} -

    jump_statement
    {GOTO IDENTIFIER ;}   -
  | {CONTINUE ;}          -
  | {BREAK ;}             -
  | {RETURN ;}            -
  | {RETURN expression ;} -

    translation_unit
    {external_declaration}                  {return $database}
  | {translation_unit external_declaration} {return $database}

    external_declaration
    {;}                   -
  | {function_definition} -
  | {declaration}         {registerDecl $1}

    function_definition
    {declaration_specifiers declarator declaration_list compound_statement} -
  | {declaration_specifiers declarator compound_statement}                  -
  | {declarator declaration_list compound_statement}                        -
  | {declarator compound_statement}                                         -
}

# vim: set sts=4 sw=4 tw=80 et ft=tcl:

