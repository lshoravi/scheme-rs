(library (fibers channels)
  (export make-channel channel?
          put-operation get-operation
          put-message get-message)
  (import (rnrs) (srfi :230) (fibers operations))

  ;; Channel: #(fibers-channel getq putq)
  (define (make-channel)
    (vector 'fibers-channel
            (make-atomic-box '())
            (make-atomic-box '())))

  (define (channel? obj)
    (and (vector? obj)
         (= (vector-length obj) 3)
         (eq? (vector-ref obj 0) 'fibers-channel)))

  (define (channel-getq ch) (vector-ref ch 1))
  (define (channel-putq ch) (vector-ref ch 2))

  (define (enqueue! queue entry)
    (let push ()
      (let* ((old (atomic-box-ref queue))
             (prev (atomic-box-compare-and-swap! queue old (cons entry old))))
        (unless (eq? prev old) (push)))))

  (define (filter-live entries)
    (let loop ((rest entries) (acc '()))
      (if (null? rest)
          (reverse acc)
          (let* ((entry (car rest))
                 (flag (vector-ref entry 0)))
            (if (eq? (atomic-box-ref flag) 'W)
                (loop (cdr rest) (cons entry acc))
                (loop (cdr rest) acc))))))

  (define (prune-queue! queue)
    (let retry ()
      (let* ((old (atomic-box-ref queue))
             (new (filter-live old))
             (prev (atomic-box-compare-and-swap! queue old new)))
        (unless (eq? prev old) (retry)))))

  (define (dequeue-match! queue)
    (let ((entries (atomic-box-ref queue)))
      (let loop ((rest entries))
        (if (null? rest)
            #f
            (let* ((entry (car rest))
                   (flag (vector-ref entry 0))
                   (prev (atomic-box-compare-and-swap! flag 'W 'S)))
              (if (eq? prev 'W)
                  entry
                  (loop (cdr rest))))))))

  (define (put-operation ch msg)
    (make-base-operation
      #f
      (lambda ()
        (let ((entry (dequeue-match! (channel-getq ch))))
          (if entry
              (begin
                (prune-queue! (channel-getq ch))
                (let ((resume (vector-ref entry 1)))
                  (resume (lambda () msg))
                  values))
              #f)))
      (lambda (flag sched resume)
        (enqueue! (channel-putq ch)
                  (vector flag resume msg))
        (let ((entry (dequeue-match! (channel-getq ch))))
          (when entry
            (let ((their-resume (vector-ref entry 1)))
              (let ((prev (atomic-box-compare-and-swap! flag 'W 'S)))
                (when (eq? prev 'W)
                  (their-resume (lambda () msg))
                  (resume values)))))))))

  (define (get-operation ch)
    (make-base-operation
      #f
      (lambda ()
        (let ((entry (dequeue-match! (channel-putq ch))))
          (if entry
              (begin
                (prune-queue! (channel-putq ch))
                (let ((their-resume (vector-ref entry 1))
                      (msg (vector-ref entry 2)))
                  (their-resume values)
                  (lambda () msg)))
              #f)))
      (lambda (flag sched resume)
        (enqueue! (channel-getq ch)
                  (vector flag resume))
        (let ((entry (dequeue-match! (channel-putq ch))))
          (when entry
            (let ((their-resume (vector-ref entry 1))
                  (msg (vector-ref entry 2)))
              (let ((prev (atomic-box-compare-and-swap! flag 'W 'S)))
                (when (eq? prev 'W)
                  (their-resume values)
                  (resume (lambda () msg))))))))))

  (define (put-message ch msg)
    (perform-operation (put-operation ch msg)))

  (define (get-message ch)
    (perform-operation (get-operation ch))))
