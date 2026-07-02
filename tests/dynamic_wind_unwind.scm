(import (rnrs) (test))

;; An exception unwinding through a dynamic-wind must reach the handler
;; unchanged even when the after thunk returns a value (R6RS 11.15:
;; after-thunk results are ignored).
;; Regression: the unwind path gave the after thunk a strict 0-arity
;; continuation, so returning a value raised wrong-number-of-args and
;; replaced the original condition.

(assert-equal?
 (guard (e (#t (condition-message e)))
   (dynamic-wind
       (lambda () #f)
       (lambda () (error 'inner "the real error"))
       (lambda () #f)))
 "the real error")
