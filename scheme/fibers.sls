(library (fibers)
  (export run-fibers spawn-fiber sleep)
  (import (rnrs) (srfi :88)
          (fibers builtins)
          (fibers internal)
          (fibers timers))

  (define (run-fibers thunk . kwargs)
    (let ((drain? (keyword-ref kwargs #:drain? #f)))
      (%run-fibers thunk)))

  (define (spawn-fiber thunk . kwargs)
    (let ((parallel? (keyword-ref kwargs #:parallel? #f)))
      (%spawn-fiber thunk))))
