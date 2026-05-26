(library (fibers io-wakeup)
  (export wait-until-port-readable-operation
          wait-until-port-writable-operation)
  (import (rnrs) (fibers operations) (fibers io-wakeup builtins))

  (define (wait-until-port-readable-operation port)
    (make-base-operation
      #f
      (lambda () #f)
      (lambda (flag sched resume)
        (%wait-port-readable-then-resume port
          (lambda () (resume values))))))

  (define (wait-until-port-writable-operation port)
    (make-base-operation
      #f
      (lambda () #f)
      (lambda (flag sched resume)
        (%wait-port-writable-then-resume port
          (lambda () (resume values)))))))
