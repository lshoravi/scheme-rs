(library (fibers internal)
  (export keyword-ref)
  (import (rnrs) (srfi :88))

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
