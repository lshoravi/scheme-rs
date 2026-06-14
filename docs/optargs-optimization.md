# Optional/Keyword Argument Optimization

## Current state

`lambda*`/`define*` are implemented as macros in `scheme/lang.sls`. They desugar into `lambda` with a rest arg + runtime keyword scanning via `%keyword-ref` (linear scan per keyword, O(N*M) total).

Missing: `#:optional` (not used yet), `#:allow-other-keys`.

## Future optimization: extend Formals on Lambda

Instead of a separate AST node, extend `Formals` to carry optional/keyword arity metadata:

```rust
enum Formals {
    FixedArgs(Vec<Local>),
    VarArgs { fixed: Vec<Local>, rest: Local },
    OptArgs {
        required: Vec<Local>,
        optional: Vec<(Local, Expression)>,  // name + default expr
        keyword: Vec<(Keyword, Local, Expression)>,  // kw + name + default
        rest: Option<Local>,
    },
}
```

During CPS lowering, `OptArgs` emits ordinary branching — no new CPS nodes:

1. Accept all args as required + rest
2. For each optional: `if (undefined? slot) → evaluate default`
3. For each keyword: single-pass extraction from rest list

This is the Guile approach. Guile also has dedicated VM instructions (`bind-optionals`, `bind-kwargs`) for stack-level arg handling, but the CPS representation is the same — just `$branch` on `undefined?` for defaults, with arity metadata in `$kclause`.

## Why not now

The macro approach is correct, simple, and the keyword lists are small (3-8 args). Optimize when profiling shows it matters. The macro is the spec; the compiler version is the fast path.

## References

- Guile: `module/ice-9/psyntax.scm` (core transformer), `module/language/cps/compile-cps.scm` (`init-default-value`)
- Chez: no keyword support; optional args via `case-lambda` (compiler-supported dispatch)
- Racket: full compiler/ABI support for keywords, sorted keyword vectors
- Chibi/SRFI-89: pure macro, rest-arg parsing (same as our current approach)
