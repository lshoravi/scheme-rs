(import (rnrs) (test))

;; R6RS 8.1: top-level body forms evaluate in textual order. An expression
;; interleaved between defines must not be deferred until after them --
;; the later define's right-hand side sees its effect.
(define x 'a)
(set! x 'b)
(define y x)
(assert-equal? y 'b)
