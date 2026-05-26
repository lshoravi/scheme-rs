(library (fibers internal)
  (export keyword-ref random-integer)
  (import (rnrs) (srfi :88) (fibers internal builtins))

  (define (random-integer n)
    (%random-integer n))

  (define (keyword-ref kwargs kw default)
    (let loop ((rest kwargs))
      (cond
        ((null? rest) default)
        ((and (keyword? (car rest))
              (equal? (car rest) kw)
              (not (null? (cdr rest))))
         (cadr rest))
        (else
         (if (null? (cdr rest))
             default
             (loop (cddr rest))))))))
