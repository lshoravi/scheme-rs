(library (fibers)
  (export run-fibers spawn-fiber sleep)
  (import (rnrs) (srfi :88)
          (fibers builtins)
          (fibers internal)
          (fibers timers))

  (define *current-fiber-group* #f)

  (define (run-fibers thunk . kwargs)
    (let ((drain? (keyword-ref kwargs #:drain? #f)))
      (if drain?
          (let ((group (%make-fiber-group)))
            (set! *current-fiber-group* group)
            (let ((result (%run-fibers thunk)))
              (set! *current-fiber-group* #f)
              (%drain-fiber-group group)
              result))
          (%run-fibers thunk))))

  (define (spawn-fiber thunk . kwargs)
    (let ((parallel? (keyword-ref kwargs #:parallel? #f)))
      (if *current-fiber-group*
          (%spawn-fiber-in-group *current-fiber-group* thunk)
          (%spawn-fiber thunk)))))
