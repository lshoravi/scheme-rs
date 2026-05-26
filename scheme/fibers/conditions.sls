(library (fibers conditions)
  (export make-condition condition? signal-condition! wait-operation wait)
  (import (rnrs) (srfi :230) (fibers operations))

  ;; Condition: #(fibers-condition signalled? waiters)
  ;; signalled? is an atomic-box of #f or #t
  ;; waiters is an atomic-box of a list of (flag . resume) pairs

  (define (make-condition)
    (vector 'fibers-condition
            (make-atomic-box #f)
            (make-atomic-box '())))

  (define (condition? obj)
    (and (vector? obj)
         (= (vector-length obj) 3)
         (eq? (vector-ref obj 0) 'fibers-condition)))

  (define (condition-signalled? cv) (vector-ref cv 1))
  (define (condition-waiters cv) (vector-ref cv 2))

  (define (signal-condition! cv)
    (let ((prev (atomic-box-compare-and-swap!
                  (condition-signalled? cv) #f #t)))
      (when (eq? prev #f)
        (let ((waiters (atomic-box-swap! (condition-waiters cv) '())))
          (for-each
            (lambda (entry)
              (let ((flag (car entry))
                    (resume (cdr entry)))
                (let ((prev (atomic-box-compare-and-swap! flag 'W 'S)))
                  (when (eq? prev 'W)
                    (resume values)))))
            waiters)))
      (not prev)))

  (define (wait-operation cv)
    (make-base-operation
      #f
      (lambda ()
        (if (atomic-box-ref (condition-signalled? cv))
            values
            #f))
      (lambda (flag sched resume)
        (let push ()
          (let* ((old (atomic-box-ref (condition-waiters cv)))
                 (prev (atomic-box-compare-and-swap!
                         (condition-waiters cv)
                         old
                         (cons (cons flag resume) old))))
            (unless (eq? prev old) (push))))
        (when (atomic-box-ref (condition-signalled? cv))
          (let ((prev (atomic-box-compare-and-swap! flag 'W 'S)))
            (when (eq? prev 'W)
              (resume values)))))))

  (define (wait cv)
    (perform-operation (wait-operation cv))))
