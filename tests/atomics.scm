(import (rnrs) (srfi :230) (test))

;; Basic ref/set
(let ((box (make-atomic-box 42)))
  (assert-equal? (atomic-box-ref box) 42)
  (atomic-box-set! box 99)
  (assert-equal? (atomic-box-ref box) 99))

;; Swap
(let ((box (make-atomic-box 'a)))
  (let ((old (atomic-box-swap! box 'b)))
    (assert-equal? old 'a)
    (assert-equal? (atomic-box-ref box) 'b)))

;; CAS success
(let ((box (make-atomic-box 'W)))
  (let ((prev (atomic-box-compare-and-swap! box 'W 'S)))
    (assert-equal? prev 'W)
    (assert-equal? (atomic-box-ref box) 'S)))

;; CAS failure
(let ((box (make-atomic-box 'S)))
  (let ((prev (atomic-box-compare-and-swap! box 'W 'C)))
    (assert-equal? prev 'S)
    (assert-equal? (atomic-box-ref box) 'S)))

;; CAS with booleans
(let ((box (make-atomic-box #f)))
  (let ((prev (atomic-box-compare-and-swap! box #f #t)))
    (assert-equal? prev #f)
    (assert-equal? (atomic-box-ref box) #t)))
