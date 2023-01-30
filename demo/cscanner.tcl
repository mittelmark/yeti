# cscanner.tcl

package require ylex

# Create the object used to assemble the scanner.
yeti::ylex CScannerGenerator -name CScanner

# On error, print the filename, line number, and column number.
CScannerGenerator code error {
    if {$file ne {}} {
        puts -nonewline $verbout $file:
    }
    puts $verbout "$line:$column: $yyerrmsg"
}

# Define public variables and methods.
CScannerGenerator code public {
    variable file {}        ;# Current file name, or empty string if none.
    variable line 1         ;# Current line number.
    variable column 1       ;# Current column number.
    variable typeNames {}   ;# List of TYPE_NAME tokens.

    # addTypeName --
    # Adds a typedef name to the list of names treated as TYPE_NAME.
    method addTypeName {name} {
        lappend typeNames $name
    }
}

# Define internal methods.
CScannerGenerator code private {
    # result --
    # Common result handler for matches.  Updates the line and column counts,
    # and (if provided) returns the arguments to the caller's caller.
    method result {args} {
        set text [string map {\r {}} $yytext]
        set start 0
        while {$start < [string length $text]} {
            regexp -start $start {([^\n\t]*)([\n\t]?)} $text chunk body space
            incr column [string length $body]
            if {$space eq "\n"} {
                set column 1
                incr line
            } elseif {$space eq "\t"} {
                set column [expr {(($column + 7) & ~3) + 1}]
            }
            incr start [string length $chunk]
        }
        if {[llength $args]} {
            return -level 2 $args
        }
    }

    # lineDirective --
    # Processes #line directives.
    method lineDirective {} {
        if {[regexp -expanded {
            ^[\ \t\v\f]*\#[\ \t\v\f]*(?:line[\ \t\v\f]+)?
            (\d+)(?:[\ \t\v\f]+"((?:[^\\"]|\\.)+)")?
        } $yytext _ line newFile] && $newFile ne ""} {
            set file [subst -nocommands -novariables $newFile]
        }
    }

    # tokenType --
    # Decides if a token is TYPE_NAME or IDENTIFIER according to $typeNames.
    method tokenType {} {
        if {$yytext in $typeNames} {
            return TYPE_NAME
        } else {
            return IDENTIFIER
        }
    }
}

# Define useful abbreviations for upcoming regular expressions.
CScannerGenerator macro {
    EXP             {[eE][+-]?\d+}
    INT_SUFFIX      {[uU]?[lL]{0,2}|[lL]{0,2}[uU]?}
    WHITESPACE      {[ \t\v\n\f]}
    C_COMMENT       {/\*.*?\*/}
    C99_COMMENT     {//(?:\\.|[^\n\\])*(?:\n|$)}
    IGNORE          {<WHITESPACE>|<C_COMMENT>|<C99_COMMENT>}
    DECIMAL         {\d+<INT_SUFFIX>\M}
    OCTAL           {0[0-7]+<INT_SUFFIX>\M}
    HEXADECIMAL     {0x[[:xdigit:]]+<INT_SUFFIX>\M}
    CHAR_LITERAL    {L?'(?:[^\\']|\\.)+'}
    INTEGER         {<DECIMAL>|<OCTAL>|<HEXADECIMAL>|<CHAR_LITERAL>}
    REAL            {(?:\d+<EXP>|\d*\.\d+<EXP>?|\d+\.\d*<EXP>?)[fFlL]?\M}
    STRING_LITERAL  {L?"(?:[^\\"]|\\.)+"}
    CONSTANT        {<INTEGER>|<REAL>}
}

# Generate a regular expression matching any simple token.  The value of such
# tokens is the uppercase version of the token string itself.
foreach token {
    auto bool break case char const continue default do double else enum extern
    float for goto if int long register return short signed sizeof static struct
    switch typedef union unsigned void volatile while ... >>= <<= += -= *= /= %=
    &= ^= |= >> << ++ -- -> && || <= >= == != ; \{ \} , : = ( ) [ ] . & ! ~ - +
    * / % < > ^ | ?
} {
    lappend pattern [regsub -all {[][*+?{}()<>|.^$\\]} $token {\\&}]
}
set pattern [join $pattern |]

# Match simple tokens.
CScannerGenerator add $pattern {result [string toupper $yytext]}

# Match and decode more complex tokens.
CScannerGenerator add {
    {<IGNORE>}              {result}
    {(?n)^[ \t\v\f]*#.*$\n} {lineDirective}
    {[a-zA-Z_]\w*\M}        {result [tokenType] $yytext}
    {<CONSTANT>}            {return CONSTANT}
    {<STRING_LITERAL>}      {result STRING_LITERAL}
    {.}                     {error "invalid character \"$yytext\""}
}
