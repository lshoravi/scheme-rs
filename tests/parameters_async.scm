(import (rnrs) (rnrs parameters) (test) (async))

;; Task inheritance and isolation through tokio spawn.
(define p (make-parameter 'root))
(p 'before)
(await (spawn (lambda () (assert-equal? (p) 'before))))
(await (spawn (lambda () (p 'task-local) (assert-equal? (p) 'task-local))))
(assert-equal? (p) 'before)

;; future: snapshot at CREATION, not first poll. Create the future, mutate
;; the parameter, then await -- the body must see the creation-time value.
(define q (make-parameter 0))
(q 1)
(define f (future (lambda () (q))))
(q 2)
(assert-equal? (await f) 1)
(assert-equal? (q) 2)

;; parameterize binding visible in a task spawned inside the body.
(define r (make-parameter 'outer))
(parameterize ((r 'inner))
  (await (spawn (lambda () (assert-equal? (r) 'inner)))))
(assert-equal? (r) 'outer)
