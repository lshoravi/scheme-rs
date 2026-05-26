(library (fibers timers)
  (export sleep-operation sleep)
  (import (rnrs) (fibers operations) (fibers timers builtins))

  (define (sleep-operation seconds)
    (make-base-operation
      #f
      (lambda ()
        (if (<= seconds 0) values #f))
      (lambda (flag sched resume)
        (%timer-block-and-resume seconds
          (lambda () (resume values))))))

  (define (sleep seconds)
    (perform-operation (sleep-operation seconds))))
