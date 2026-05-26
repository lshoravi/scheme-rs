(import (except (rnrs) define-record-type) (srfi 99) (test))

;; === Procedural layer ===

(let ()
  (define point-rtd (make-rtd 'point (vector 'x 'y)))
  (define make-point (rtd-constructor point-rtd))
  (define point? (rtd-predicate point-rtd))
  (define point-x (rtd-accessor point-rtd 'x))
  (define point-y (rtd-accessor point-rtd 'y))

  (let ((p (make-point 3 4)))
    (assert-equal? (point? p) #t)
    (assert-equal? (point-x p) 3)
    (assert-equal? (point-y p) 4)
    (assert-equal? (point? 42) #f)))

;; Mutable fields
(let ()
  (define cell-rtd (make-rtd 'cell (vector (list 'mutable 'value))))
  (define make-cell (rtd-constructor cell-rtd))
  (define cell-value (rtd-accessor cell-rtd 'value))
  (define cell-value-set! (rtd-mutator cell-rtd 'value))

  (let ((c (make-cell 10)))
    (assert-equal? (cell-value c) 10)
    (cell-value-set! c 20)
    (assert-equal? (cell-value c) 20)))

;; Inheritance
(let ()
  (define animal-rtd (make-rtd 'animal (vector 'name)))
  (define dog-rtd (make-rtd 'dog (vector 'breed) animal-rtd))
  (define make-dog (rtd-constructor dog-rtd))
  (define animal? (rtd-predicate animal-rtd))
  (define dog? (rtd-predicate dog-rtd))
  (define animal-name (rtd-accessor dog-rtd 'name))
  (define dog-breed (rtd-accessor dog-rtd 'breed))

  (let ((d (make-dog "Rex" "Lab")))
    (assert-equal? (dog? d) #t)
    (assert-equal? (animal? d) #t)
    (assert-equal? (animal-name d) "Rex")
    (assert-equal? (dog-breed d) "Lab")))

;; === Inspection layer ===

(let ()
  (define point-rtd (make-rtd 'point3 (vector 'x (list 'mutable 'y))))

  (assert-equal? (rtd-name point-rtd) 'point3)
  (assert-equal? (rtd-parent point-rtd) #f)
  (assert-equal? (rtd-field-mutable? point-rtd 'x) #f)
  (assert-equal? (rtd-field-mutable? point-rtd 'y) #t))

;; === Syntactic layer ===

(define-record-type point4
  (make-point4 x y)
  point4?
  (x point4-x)
  (y point4-y))

(let ((p (make-point4 10 20)))
  (assert-equal? (point4? p) #t)
  (assert-equal? (point4-x p) 10)
  (assert-equal? (point4-y p) 20)
  (assert-equal? (point4? 42) #f))

;; Syntactic with mutable field
(define-record-type cell2
  (make-cell2 val)
  cell2?
  (val cell2-val cell2-val-set!))

(let ((c (make-cell2 100)))
  (assert-equal? (cell2-val c) 100)
  (cell2-val-set! c 200)
  (assert-equal? (cell2-val c) 200))
