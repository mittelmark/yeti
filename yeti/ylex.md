NAME
====

Ylex - Yeti\'s Scanner

SYNOPSIS
========

**package require ylex ?0.4?**

**yeti::ylex** *name*

*name* **macro** *name* *regex* ?*\...?*

*name* **macro** *args*

*name* **add** ?*options*? *regex* *script* ?*\...?*

*name* **add** ?*options*? *args*

*name* **code** *token* *script*

*name* **dump**

*name* **configure** **-name** ?*value*?

*name* **configure** **-start** ?*value*?

*name* **configure** **-case** ?*value*?

SCANNER SYNOPSIS
================

*scannerName* *objName* ?*options*?

*name* **start** *string*

*name* **reset**

*name* **next**

*name* **step**

*name* **run**

*name* **configure** **-case** ?*value*?

*name* **configure** **-yydata** ?*value*?

*name* **configure** **-verbose** ?*value*?

*name* **configure** **-verbout** ?*value*?

DESCRIPTION
===========

This manual page describes **ylex**, a scanner generator that comes with
the **yeti** package. **ylex** is modeled after the standard **lex**
utility, which is used to create scanners in the C programming language.

A scanner consists of a number of rules. Each rule associates a regular
expression with a Tcl script; this script is executed whenever the
regular expression is matched in the input. This code can either act on
its own, or it can generate a stream of tokens that can then be
evaluated outside of the scanner - e.g. in a parser.

**ylex** does not do the scanning by itself, rather it is used, quite
like **lex**, to generate scanners (by way of the **dump** method).
Generated scanners are **\[incr Tcl\]** classes that act independently
of **ylex**, see the **Scanner** section below. These scanners can be
customized; you can use the **code** method to add user variables and
methods to the class.

COMMANDS
========

**yeti::ylex** *name*

:   Creates a new scanner generator by the name of *name*. The new
    scanner generator has an empty set of rules. *options* can be used
    to configure the scanner generator\'s public variables, see the
    *variables* section below.

METHODS
=======

*name* **macro** *name* *regex* ?*\...?*

:   

*name* **macro** *args*

:   

Defines *macros*, which are regular expressions that are stored for
later use. Macros can be used in other macros or rules using their name
in angular brackets, e.g. *\<digit\>* would reference the *digit* macro.
Macro names must be alphanumerical. In the first form, the **macro**
method takes an even number of parameters. The first parameter of each
pair is the name, the second parameter is a regular expression that may
itself contain other macros. In the second form, the method takes a list
as single parameter, where this list is composed as above of alternating
names and regular expressions. The second form may be more convenient to
define multiple macros.

*name* **add** ?*options*? *regex* *script* ?*\...?*

:   

```{=html}
<!-- -->
```

*name* **add** ?*options*? *args*

:   

Adds new rules to the scanner. In the first form, the **add** method
takes an even number of parameters (not counting options). The first
parameter of each pair is a regular expression, the second parameter is
a script. In the second form, the method takes a list as single
parameter (not counting options), where this list is composed as above
of alternating regular expressions and scripts.

> Whenever the regular expression *regex* is matched in the input
> string, its corresponding *script* will be executed by the scanner.
>
> The following options are supported:
>
> -   This option has the same meaning as on **regexp**. In matching
>     this rule, upper-case characters in the input will be treated as
>     lower-case.
>
> -   This rule will only be considered if the scanner is in the state
>     *name*. See below for more information.
>
> -   Same as above, but *names* is a list of state names in which the
>     rule is active.

*name* **code** *token* *script*

:   Adds custom user code to the generated scanner. *token* must be one
    of

    -   Defines the class\'s constructor. The *script* may have any of
        the formats allowed by **\[incr Tcl\]**, without the
        **constructor** keyword.

    -   Defines the body of the class\'s destructor.

    -   Defines the body of the error handler that is called whenever an
        error occurs, e.g. errors executing a rule\'s script. *script*
        has access to the **yyerrmsg** parameter, which contains a
        string with a description of the error and its cause. *script*
        is supposed to inform the user of the problem. The default
        implementations prints the message to the channel set in the
        **verbout** variable. *script* is expected to return normally;
        the parser then returns from the current invocation with the
        original error.

    -   The *script* is added to the body of the scanner\'s *reset*
        method.

    -   

    -   

    -   Defines public, protected or private class members. The *script*
        may contain many different member definitions, like the
        respective keywords in an **\[incr Tcl\]** class definition.

*name* **dump**

:   Returns a script containing the generated scanner. This method is
    called after all configuration options have been set and all rules
    have been added; the scanner generator object is usually deleted
    after this method has been called. The returned script can be passed
    to **eval** for instant usage, or saved to a file, from where it can
    later be sourced without involvement of the scanner generator.

VARIABLES
=========

*name* **configure** **-name** ?*value*?

:   Defines the class name of the generated scanner class. The default
    value is **unnamed**.

*name* **configure** **-start** ?*value*?

:   Defines the initial state for the scanner. Setting this variable is
    only required if your scanner needs multiple states, and you are not
    satisfied with the default of **INITIAL**.

*name* **configure** **-case** ?*value*?

:   If set to 0 (zero), the generated scanner will be case-insensitive
    (i.e. **-nocase** will be used on all calls to **regexp**). The
    default value is 1 for a case-sensitive scanner. This setting can be
    overridden on a rule-by-rule basis using the **-nocase** option upon
    adding a rule.

SCANNER USAGE
=============

Scanners are independent of **ylex**, their only dependency is on
**\[incr Tcl\]**.

A scanner reads its input from a string that must be set before scanning
can begin. The regular expressions (rules) are then repeatedly matched
against the current input position within this string. If more than one
regular expression matches text at a certain position, the rule matching
the most text is selected. If more than one regular expression matches
the same amount of text, the rule that was added to the scanner
generator first is selected. If a rule matches, its associated *script*
is executed, and the read pointer is moved beyond the match. Unmatched
text in the input is ignored and skipped.

Scanners are **\[incr Tcl\]** objects, so its usual rules of object
handling (e.g. deletion of scanners) apply.

SCANNER COMMANDS
================

*scannerName* *objName* ?*options*?

:   Creates a new scanner instance by the name of *objName*. *options*
    can be used to configure the scanner\'s public variables, see the
    *scanner variables* section below.

SCANNER METHODS
===============

*objName* **start** *string*

:   Initializes the scanner to scan *string*. Calling **start** implies
    **reset**.

*objName* **reset**

:   Resets the scanner to the beginning of the input string, and resets
    the state to the initial state. If you want to scan a different
    string, you need not call **reset** but only **start**.

*objName* **next**

:   Starts the scanning process. Regular expressions are matched, and
    their scripts are executed. This repeats until a script executes
    **return** or until end of input is reached. If a script executes
    **return**, the script\'s return value is returned. At the end of
    input, an empty string is returned.

*objName* **step**

:   Single-steps the parser. This method returns after a single match
    has been done, regardless of whether its script executed **return**
    or not. **step** returns a list of length three. The first element
    of this list is the number of the rule that was matched or -1 if at
    the end of input. The second element is 1 if the script executed
    **return**, 0 otherwise. The third element is the script\'s return
    value if the script executed **return**, empty otherwise.

*objName* **run**

:   Runs the scanning process to completion. **next** is repeatedly
    called until the end of input has been reached. A list of all the
    results returned from **next** is returned.

SCANNER VARIABLES
=================

*objName* **configure** **-case** ?*value*?

:   If this variable is zero, then the **-nocase** option is implicitly
    set for all rules. The default value is determined by the setting of
    the **case** variable in the scanner generator. Setting this
    variable after scanning has started may yield unexpected results
    because of cached data.

*objName* **configure** **-yydata** ?*value*?

:   This variable holds the input string. This variable is not meant to
    be modified, but it can be conveniently configured upon object
    creation. If that is done, there is no need to call the **start**
    method.

*objName* **configure** **-yyindex** ?*value*?

:   This variable holds the current index into the input string. This
    variable is not meant to be set, but reading it may be useful e.g.
    to determine the position that causes an error in a parser. After an
    invocation **step** or **next**, **yyindex** points to the character
    after the current match.

*objName* **configure** **-verbose** ?*value*?

:   If this value is non-zero, the scanner prints debug information
    about its processing. The larger **verbose** is, the more
    information is printed (sensible values are 0 to 3). By default, no
    debug information is printed.

*objName* **configure** **-verbout** ?*value*?

:   This variable contains the channel that is used for debug output. By
    default, this is **stderr**.

SCRIPTS
=======

Scripts are executed in the context of the scanner. Scripts have access
to the following variables.

**yytext**

:   This variable contains the text that was matched by the regular
    expression.

**yystate**

:   This variable contains the current state of the scanner. The script
    may modify this variable to switch the scanner to a different state.

**yystart**

:   The absolute index of the first character of the current match.

**yyend**

:   The absolute index of the last character of the current match.

*\<i\>*

:   These variables (**\$1**, **\$2** \...) contain any subexpressions
    matched by the regular expression.

**ylex** reserves names with the **yy** prefix, so scripts should not
use or access variables with this prefix other than those documented
here. Also, a scanner\'s public methods and variables as seen above must
be respected.

STATES
======

Initially, a scanner is in the initial state as determined by the
**start** variable of the scanner generator. Scripts can switch to a
different state by modifying the **yystate** variable during execution
of a script. In each state, only a subset of all rules will be
considered, as determined by the **-state** or **-states** options upon
adding rules to the scanner generator; if no such option was used when
adding a rule, it will be active in all states.

NOTES
=====

Unmatched text in the input is ignored. In order to throw an error upon
unmatched text, add a \"catch-all\" rule at the end of the rule set
(usually with the regular expression \".\" that matches any character).

Subexpressions are available in the *\$\<i\>* variables only when using
Tcl 8.3 or above.

It is illegal to have rules that match the empty string.

TODO
====

There should be a means of reading data from elsewhere than a string. It
might be inconvenient to have all the input in memory. However, that is
not possible with the current regexp engine.

Maybe there should be the possibility to read a lex-like input file.

KEYWORDS
========

scanner, parser, token
