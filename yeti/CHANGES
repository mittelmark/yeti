# ChangeLog 

## version 0.5 (October 2, 2021)

- maintainer changed to D. Groth
- ylex, yflex fixed version mismatches in package description
- temporary disabled tcl++ support
- bugfix in ylex fixed 

## version 0.4.1 (July 5, 2004)

- ylex: fix backwards-compatibility bug when using Tcl 8.4 or greater
- yeti: don't emit an empty switch statement when there is no rule with
  user-defined code
- yeti: make compatible with struct package version 2.0
- yeti: report shift/reduce conflicts when verbose>=1

## version 0.4 (Feb 16, 2002)

- ylex: move to separate file; "package require ylex" now necessary
- ylex/yeti: don't do the scanning/parsing by itself, but rather generate
  a new scanner/parser class with the "dump" method
- ylex/yeti: allow all sorts of customization for the generated code, e.g.
  adding variables, methods, constructor, error handling etc.

## version 0.3 (Dec 21, 2001)

- yeti: use lookahead to arbitrate between different reductions
- yeti: support left recursion
- yeti: allow `|' as a repetition of the last lhs, and `-' as "no code"

## version 0.2 (Dec 04, 2001)

- yeti: allow multiple rules to be added at once
- ylex: add verbosity
- ylex: use second list element of code's return value (instead of yytext)
  as data
- ylex: for flex compatibility: use the rule that matches the most text
- ylex: allow multiple macros and rules to be added at once
- yeti: cache an array of $state,$token -> newstate, because going through
  all outgoing arcs and checking their token is expensive
- ylex and yeti: new "namespace" option (public variable) so that scripts
  are executed in that namespace, and not always in the global namespace
  (support for multiple scanners and parsers running in parallel)
- ylex: provide access to subexpression matches
- ylex: macro support
- ylex: support for -nocase upon individual rules and as a global variable
- ylex: support for multiple states
- Rewrote yeti to use ::struct::graph from tcllib

## version 0.1 (Nov 17, 2001)

- initial version
