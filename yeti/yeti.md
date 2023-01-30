# NAME

Yeti - Yet another Tcl Interpreter

# SYNOPSIS

**package require yeti ?0.4?**

**yeti::yeti** *name* ?*options*?

*name* **add** *lhs* *rhs* ?*script*?

*name* **add** *args*

*name* **code** *token* *script*

*name* **dump**

*name* **configure** **-name** ?*value*?

*name* **configure** **-start** ?*value*?

*name* **configure** **-verbose** ?*value*?

*name* **configure** **-verbout** ?*value*?

# PARSER SYNOPSIS

*parserName* *objName* ?*options*?

*objName* **parse**

*objName* **step**

*objName* **reset**

*objName* **configure** **-scanner** ?*object*?

*objName* **configure** **-verbose** ?*value*?

# DESCRIPTION

This manual page describes **yeti**, a parser generator that is modeled
after the standard **yacc** package (and its incarnation as GNU
**bison**), which is used to create parsers in the C programming
language.

Parsers are used to parse an input (a stream of terminals) according to
a *grammar*. This grammar is defined by a number of *rules*. **yeti**
supports a subclass of context-free grammars named LALR(1), which is the
class of context-free grammars that can be parsed using a single
lookahead token.

Rules in **yeti** are written similar to the Backus-Naur Form (BNF).
Rules have a *non-terminal* as left-hand side (LHS) and a list of
non-terminals and *terminals* on the right-hand side (RHS).
Non-terminals are parsed according to these rules, while terminals are
read from the input. This way, all non-terminals are ultimately
decomposed into sequences of terminals. There may be multiple rules with
the same non-terminal on the LHS but different RHSs. The RHS may be
empty.

**yeti** does not do the parsing by itself, rather it is used, quite
like **yacc**, to generate parsers (by way of the **dump** method).
Generated parsers are **\[incr Tcl\]** classes that act independently of
**yeti**, see the **Parser** section below. These parsers can be
customized; you can use the **code** method to add user variables and
methods to the class.

# COMMANDS

**yeti::yeti** *name* ?*options*?

:   Creates a new parser generator by the name of *name*. The new parser
    generator has an empty set of rules. *options* can be used to
    configure the parser generator\'s public variables, see the
    *variables* section below.

# METHODS

*name* **add** *lhs* *rhs* ?*script*?

:   

```{=html}
<!-- -->
```

*name* **add** *args*

:   

Adds new rules to the parser. In the first form, *lhs* is a
non-terminal, *rhs* is a (possibly empty) list of terminals and
non-terminals. If this rule is matched, *script* is executed. In the
second form, *args* is a list consisting of triplets, so the number of
elements must be divisible by three. Each triplet represents a rule. The
first element of each triplet is the *lhs*, the second element is the
*rhs*, and the third element is a *script*, as above. In the second and
following triplets, **\|** (vertical bar, pipe symbol) can be used as
*lhs*, referring to the *lhs* of the previous rule. The minus sign **-**
can be used for *code* to indicate that no script is associated with
this rule. If a rule is matched, its corresponding script is executed,
see the **scripts** section below.

*name* **code** *token* *script*

:   Adds custom user code to the generated parser. *token* must be one
    of

    constructor

    :   Defines the class\'s constructor. The *script* may have any of
        the formats allowed by **\[incr Tcl\]**, without the
        **constructor** keyword.

    destructor

    :   Defines the body of the class\'s destructor.

    error

    :   Defines the body of the error handler that is called whenever an
        error occurs, e.g. parse errors or errors executing a rule\'s
        script. *script* has access to the **yyerrmsg** parameter, which
        contains a string with a description of the error and its cause.
        *script* is supposed to inform the user of the problem. The
        default implementations prints the message to the channel set in
        the **verbout** variable. *script* is expected to return
        normally; the parser then returns from the current invocation
        with the original error.

    reset

    :   The *script* is added to the body of the parser\'s *reset*
        method.

    returndefault

    :   The *script* is executed by the parser whenever the code
        associated with a non-terminal is omitted or does not execute a
        return. The result or return value of *script* is used as the
        value of the non-terminal. The default **returndefault** script
        returns the leftmost item on the RHS (**\$1**). If *script* is
        set to empty string, the result of the code associated with a
        non-terminal is used as its value even if return was not
        executed.

    public

    :   

    protected

    :   

    private

    :   Defines public, protected or private class members. The *script*
        may contain many different member definitions, like the
        respective keywords in an **\[incr Tcl\]** class definition.

*name* **dump**

:   Returns a script containing the generated parser. This method is
    called after all configuration options have been set and all rules
    have been added; the parser generator object is usually deleted
    after this method has been called. The returned script can be passed
    to **eval** for instant usage, or saved to a file, from where it can
    later be sourced without involvement of the parser generator.

# VARIABLES

*name* **configure** **-name** ?*value*?

:   Defines the class name of the generated parser class. The default
    value is **unnamed**.

*name* **configure** **-start** ?*value*?

:   Defines the starting non-terminal for the parser. There must be at
    least one rule with this starting non-terminal as the left hand
    side. The default value is **start**.

*name* **configure** **-verbose** ?*value*?

:   If the value of the **verbose** variable is non-zero, the parser
    prints some debug information about the generated parser, like the
    state machines that are generated from the rule set.

*name* **configure** **-verbout** ?*value*?

:   Sets the target channel for debug information. The default value is
    **stderr**.

# NOTES

No checks are done whether all non-terminals are reachable. Also, no
checks are done to ensure that all non-terminals are defined, i.e. there
is at least one rule with the non-terminal as LHS.

Using uppercase names for terminals and lowercase names for
non-terminals is a common convention that is not enforced, and **yeti**
assumes all undefined tokens to be terminals.

Set the *verbose* variable to a positive value to see warnings about
reduce/reduce conflicts. Shift/reduce conflicts are not reported;
**yeti** always prefers shifts over reductions.

# PARSER USAGE

Parsers are independent of **yeti**, their only dependency is on
**\[incr Tcl\]**.

Parsers read terminals from a *scanner* and try to match them against
the rule set. Starting from the **start** non-terminal, the parser looks
for a rule that accepts the terminal. Whenever a rule is matched, the
script associated with the rule is executed. The values for each element
on the RHS are made available to the script in the variables
**\$***\<i>*, where *\<i>* is the index of the item. The script can use
these values to compute its own result.

Values for terminals are read from the *scanner*, values for
non-terminals are the return values of the code associated with a rule
that produced the non-terminal. If the code does not execute a
**return**, or if there is no code associated with a rule, the
**returndefault** script is executed to obtain the value of the
non-terminal. If the user did not override **returndefault**, the value
of the leftmost item on the RHS (**\$1**) is used as result (see the
example below).

Parsers are **\[incr Tcl\]** objects, so its usual rules of object
handling (e.g. deletion of parsers) apply.

# PARSER COMMANDS

*parserName* *objName* ?*options*?

:   Creates a new parser instance by the name of *objName*. *options*
    can be used to configure the parser\'s public variables, see the
    *parser variables* section below.

# PARSER METHODS

*objName* **parse**

:   Runs the parser. Tokens are read from the scanner as necessary and
    matched against terminals. The parsing process runs to completion,
    i.e. until a rule for the **start** token has been executed and the
    end of input has been reached. The value returned from the last rule
    is returned as result of **parse**, but it is also very common for
    parsers to leave data in variables rather than returning a result.

*objName* **step**

:   Single-steps the parser. One step is either the shifting of a token
    or a reduction. This method may be useful e.g. to do other work in
    parallel to the parsing. The method returns a list of length two;
    the first element is the token just shifted or reduced, and the
    second element is the associated data. Parsing is finished if the
    token **\_\_init\_\_** has been reduced.

*objName* **reset**

:   Resets the parser to the initial state, e.g. to start parsing new
    input. The scanner must be reset or replaced separately.

# PARSER VARIABLES

*objName* **configure** **-scanner** ?*object*?

:   The **scanner** variable holds the scanner from which terminals are
    read. The scanner must be configured before parsing can begin. By
    default, the scanner is not deleted; if desired, this can be done in
    custom destructor code (see the parser generator\'s **code**
    method).

    *object* must be a command; the parser calls this command with
    **next** as parameter whenever a new terminal needs to be read. The
    value returned by the command is expected to be a list of length one
    or two. The first item of this list is considered to be a terminal,
    and the second item is considered to be the value associated with
    this terminal. If the list has only one element, the value is
    assumed to be the empty string. At the end of input, an empty string
    shall be returned as terminal.

    The **ylex** package is designed to provide appropriate scanners for
    parsing, but it is possible to use custom scanners as long as the
    above rules are satisfied.

*objName* **configure** **-verbose** ?*value*?

:   If the value of the **verbose** variable is non-zero, the parser
    prints debug information about the read tokens and matched rules to
    standard output.

*objName* **configure** **-verbout** ?*value*?

:   Sets the target channel for debug information. The default value is
    **stderr**.

# SCRIPTS

If a rule is matched, its corresponding script is executed in the
context of the parser. Scripts have access to the variables
**\$***\<i>*, which are set to the values associated with each item on
the RHS, where *\<i>* is the index of the item. Numbering items is left
to right, starting with 1.

Scripts can execute **return** to set their return value, which will
then be associated with the rule\'s LHS. If a script does not execute
**return**, the value associated with the the leftmost item on the RHS
is used as the rule\'s value. If the RHS is empty, an empty string is
used.

**yeti** reserves names with the **yy** prefix, so scripts should not
use or access variables with this prefix. Also, a parser\'s public
methods and variables as seen above must be respected.

# EXAMPLE

Here\'s one simple but complete example of a parser that can parse
mathematical expressions, albeit limited to multiplications. The scanner
is not shown, but is expected to return the terminals written in
uppercase.

set pgen \[yeti::yeti #auto -name MathParser\]

\$pgen add start {mult} {

> puts \"Result is \$1\"

}

\$pgen add mult {number MULTIPLY number} {

> return \[expr {\$1 \* \$3}\]

}

\$pgen add mult {number}

\$pgen add number {INTEGER}

\$pgen add number {OPEN mult CLOSE} {

> return \$2

}

eval \[\$pgen dump\]

set mp \[MathParser #auto -scanner \$scanner\]

puts \"The result is \[\$mp parse\]\"

# KEYWORDS

parser, scanner
