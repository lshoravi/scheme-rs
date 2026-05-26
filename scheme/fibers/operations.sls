(library (fibers operations)
  (export make-base-operation wrap-operation choice-operation perform-operation)
  (import (rnrs) (srfi :230) (fibers operations builtins))

  (define (make-base-operation wrap-fn try-fn block-fn)
    (vector 'base wrap-fn try-fn block-fn))

  (define (base-operation? op)
    (and (vector? op) (eq? (vector-ref op 0) 'base)))

  (define (base-wrap op) (vector-ref op 1))
  (define (base-try op) (vector-ref op 2))
  (define (base-block op) (vector-ref op 3))

  (define (choice-operation? op)
    (and (vector? op) (eq? (vector-ref op 0) 'choice)))

  (define (choice-alternatives op) (vector-ref op 1))

  (define (wrap-operation op f)
    (cond
      ((base-operation? op)
       (let ((old-wrap (base-wrap op)))
         (vector 'base
                 (if old-wrap
                     (lambda args
                       (call-with-values
                         (lambda () (apply old-wrap args))
                         f))
                     f)
                 (base-try op)
                 (base-block op))))
      ((choice-operation? op)
       (vector 'choice
               (map (lambda (alt) (wrap-operation alt f))
                    (choice-alternatives op))))
      (else (assertion-violation 'wrap-operation "not an operation" op))))

  (define (choice-operation . ops)
    (vector 'choice (apply append (map flatten-op ops))))

  (define (flatten-op op)
    (cond
      ((choice-operation? op)
       (apply append (map flatten-op (choice-alternatives op))))
      ((base-operation? op) (list op))
      (else (assertion-violation 'choice-operation "not an operation" op))))

  (define (apply-wrap wrap-fn thunk)
    (if wrap-fn
        (call-with-values thunk wrap-fn)
        (thunk)))

  (define (perform-operation op)
    (cond
      ((base-operation? op) (perform-base op))
      ((choice-operation? op) (perform-choice (choice-alternatives op)))
      (else (assertion-violation 'perform-operation "not an operation" op))))

  (define (perform-base op)
    (let ((result ((base-try op))))
      (if result
          (apply-wrap (base-wrap op) result)
          (let ((flag (make-atomic-box 'W)))
            (let ((vals (%perform-operation-block
                          (lambda (flag sched resume)
                            ((base-block op) flag sched resume))
                          flag)))
              (apply-wrap (base-wrap op)
                          (lambda () (apply values vals))))))))

  (define (perform-choice ops)
    (let ((flag (make-atomic-box 'W)))
      (let try-loop ((remaining ops))
        (if (null? remaining)
            (let ((op (car ops)))
              (let ((vals (%perform-operation-block
                            (lambda (flag sched resume)
                              ((base-block op) flag sched resume))
                            flag)))
                (apply-wrap (base-wrap op)
                            (lambda () (apply values vals)))))
            (let* ((op (car remaining))
                   (result ((base-try op))))
              (if result
                  (begin
                    (atomic-box-set! flag 'S)
                    (apply-wrap (base-wrap op) result))
                  (try-loop (cdr remaining)))))))))
