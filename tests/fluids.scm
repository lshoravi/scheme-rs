(import (rnrs) (srfi :226) (prompts) (test))

;; make-fluid returns a fluid
(define f (make-fluid 42))
(assert-equal? (fluid? f) #t)
(assert-equal? (fluid? 42) #f)
(assert-equal? (fluid? "hello") #f)

;; fluid-ref returns the current value
(assert-equal? (fluid-ref f) 42)

;; fluid-set! mutates the current value
(fluid-set! f 99)
(assert-equal? (fluid-ref f) 99)

;; Reset for subsequent tests
(fluid-set! f 42)

;; with-fluids establishes dynamic binding
(define g (make-fluid 'default))

(assert-equal? (fluid-ref g) 'default)
(assert-equal?
 (with-fluids ((g 'bound))
   (fluid-ref g))
 'bound)
(assert-equal? (fluid-ref g) 'default)

;; Nested with-fluids
(assert-equal?
 (with-fluids ((g 'outer))
   (with-fluids ((g 'inner))
     (fluid-ref g)))
 'inner)

;; Multiple fluids in one form
(define h (make-fluid 'h-default))
(assert-equal?
 (with-fluids ((g 'g-val) (h 'h-val))
   (cons (fluid-ref g) (fluid-ref h)))
 '(g-val . h-val))
(assert-equal? (fluid-ref g) 'default)
(assert-equal? (fluid-ref h) 'h-default)

;; fluid-set! inside with-fluids doesn't leak
(assert-equal?
 (with-fluids ((g 'initial))
   (fluid-set! g 'mutated)
   (fluid-ref g))
 'mutated)
(assert-equal? (fluid-ref g) 'default)

;; Fluid bindings are restored when escaping via call/cc
(define esc-fluid (make-fluid 'outside))
(define esc-k #f)

(with-fluids ((esc-fluid 'inside))
  (call-with-current-continuation
    (lambda (k) (set! esc-k k)))
  (assert-equal? (fluid-ref esc-fluid) 'inside))

;; After escaping, fluid has its outer value
(assert-equal? (fluid-ref esc-fluid) 'outside)

;; Continuation re-entry restores fluid bindings
(define reentry-fluid (make-fluid 'default))
(define saved-k #f)
(define call-count 0)

(with-fluids ((reentry-fluid 'bound))
  (call-with-current-continuation
    (lambda (k) (set! saved-k k)))
  (assert-equal? (fluid-ref reentry-fluid) 'bound)
  (set! call-count (+ call-count 1)))

;; After exiting, fluid has default value
(assert-equal? (fluid-ref reentry-fluid) 'default)

;; Re-enter: fluid should be re-bound
(if (< call-count 2)
    (saved-k))

(assert-equal? (fluid-ref reentry-fluid) 'default)

;; Fluid bindings restored when aborting to prompt
(define prompt-fluid (make-fluid 'outside))

(assert-equal?
 (call-with-prompt 'test-tag
   (lambda ()
     (with-fluids ((prompt-fluid 'inside))
       (abort-to-prompt 'test-tag 'result)))
   (lambda (k val)
     ;; Handler should see outside value
     (cons val (fluid-ref prompt-fluid))))
 '(result . outside))

;; dynamic-wind out thunks see the fluid value before restoration
(define dw-fluid (make-fluid 'default))
(define dw-log '())

(with-fluids ((dw-fluid 'bound))
  (dynamic-wind
    (lambda () (set! dw-log (cons (cons 'in (fluid-ref dw-fluid)) dw-log)))
    (lambda () (set! dw-log (cons (cons 'body (fluid-ref dw-fluid)) dw-log)))
    (lambda () (set! dw-log (cons (cons 'out (fluid-ref dw-fluid)) dw-log)))))

(assert-equal? (reverse dw-log) '((in . bound) (body . bound) (out . bound)))

;; dynamic-wind + fluid + continuation re-entry ordering
(define dw2-fluid (make-fluid 'default))
(define dw2-log '())
(define dw2-k #f)
(define dw2-count 0)

(with-fluids ((dw2-fluid 'bound))
  (dynamic-wind
    (lambda ()
      (set! dw2-log (cons (cons 'in (fluid-ref dw2-fluid)) dw2-log)))
    (lambda ()
      (call-with-current-continuation
        (lambda (k) (set! dw2-k k)))
      (set! dw2-count (+ dw2-count 1)))
    (lambda ()
      (set! dw2-log (cons (cons 'out (fluid-ref dw2-fluid)) dw2-log)))))

;; Re-enter once
(if (< dw2-count 2)
    (dw2-k))

;; in-thunk should see 'bound (the fluid binding is outside the dynamic-wind)
;; out-thunk should also see 'bound
(assert-equal? (fluid-ref dw2-fluid) 'default)
(let ((log (reverse dw2-log)))
  (assert-equal? (length log) 4)
  (assert-equal? (cdar log) 'bound)
  (assert-equal? (cdadr log) 'bound))

;; fluid-set! mutation is lost on continuation re-entry (bound_val wins)
(define mut-fluid (make-fluid 'default))
(define mut-k #f)
(define mut-count 0)

(with-fluids ((mut-fluid 'bound))
  (call-with-current-continuation
    (lambda (k) (set! mut-k k)))
  (if (= mut-count 0)
      (fluid-set! mut-fluid 'mutated))
  (set! mut-count (+ mut-count 1)))

;; Re-enter: should see 'bound, not 'mutated
(if (< mut-count 2)
    (begin
      (assert-equal? (fluid-ref mut-fluid) 'default)
      (mut-k)))

(assert-equal? (fluid-ref mut-fluid) 'default)

;; %with-fluids errors on mismatched list lengths
(assert-equal?
 (guard (exn (#t #t))
   (%with-fluids (list (make-fluid 1) (make-fluid 2)) (list 'only-one) (lambda () #f))
   #f)
 #t)

;; === Parameters ===

;; make-parameter creates a parameter
(define p (make-parameter 10))
(assert-equal? (parameter? p) #t)
(assert-equal? (parameter? 42) #f)
(assert-equal? (parameter? (make-fluid 1)) #f)

;; Reading a parameter
(assert-equal? (p) 10)

;; Writing a parameter returns previous value
(assert-equal? (p 20) 10)
(assert-equal? (p) 20)
;; Reset
(p 10)

;; Parameter with converter
(define q (make-parameter 5 (lambda (x) (* x 2))))
(assert-equal? (q) 10)
(q 3)
(assert-equal? (q) 6)

;; parameterize establishes dynamic binding
(assert-equal? (parameterize ((p 42)) (p)) 42)
(assert-equal? (p) 10)

;; parameterize applies converter
(assert-equal? (parameterize ((q 7)) (q)) 14)
(assert-equal? (q) 6)

;; Nested parameterize
(assert-equal?
 (parameterize ((p 100))
   (parameterize ((p 200))
     (p)))
 200)
(assert-equal? (p) 10)

;; Multiple parameters in one parameterize
(assert-equal?
 (parameterize ((p 1) (q 2))
   (cons (p) (q)))
 '(1 . 4))

;; Mutation inside parameterize doesn't leak
(parameterize ((p 50))
  (p 60))
(assert-equal? (p) 10)

;; parameterize + call/cc
(define param-k #f)
(define param-count 0)
(define cc-param (make-parameter 'outside))

(parameterize ((cc-param 'inside))
  (call-with-current-continuation
    (lambda (k) (set! param-k k)))
  (assert-equal? (cc-param) 'inside)
  (set! param-count (+ param-count 1)))

(assert-equal? (cc-param) 'outside)

;; Re-enter
(if (< param-count 2)
    (param-k))

(assert-equal? (cc-param) 'outside)

;; parameter? on a regular procedure
(assert-equal? (parameter? (lambda () 1)) #f)
(assert-equal? (parameter? car) #f)

;; Empty parameterize
(assert-equal? (parameterize () 42) 42)

;; parameterize + dynamic-wind
(define dw-param (make-parameter 'default))
(define dw-param-log '())

(parameterize ((dw-param 'bound))
  (dynamic-wind
    (lambda () (set! dw-param-log (cons (cons 'in (dw-param)) dw-param-log)))
    (lambda () (set! dw-param-log (cons (cons 'body (dw-param)) dw-param-log)))
    (lambda () (set! dw-param-log (cons (cons 'out (dw-param)) dw-param-log)))))

(assert-equal? (reverse dw-param-log) '((in . bound) (body . bound) (out . bound)))

;; parameterize + abort-to-prompt
(define prompt-param (make-parameter 'outside))

(assert-equal?
 (call-with-prompt 'param-tag
   (lambda ()
     (parameterize ((prompt-param 'inside))
       (abort-to-prompt 'param-tag 'result)))
   (lambda (k val)
     (cons val (prompt-param))))
 '(result . outside))

;; parameterize with converter + call/cc re-entry
(define conv-param (make-parameter 0 (lambda (x) (* x 10))))
(define conv-k #f)
(define conv-count 0)

(assert-equal? (conv-param) 0)  ;; 0 * 10 = 0... wait, converter applied to init

;; Actually: (make-parameter 0 (lambda (x) (* x 10))) applies converter to 0 => 0
(parameterize ((conv-param 3))  ;; converter applied: 3 * 10 = 30
  (call-with-current-continuation
    (lambda (k) (set! conv-k k)))
  (assert-equal? (conv-param) 30)
  (set! conv-count (+ conv-count 1)))

(assert-equal? (conv-param) 0)

;; Re-enter: should see 30 again (bound_val is the converted value)
(if (< conv-count 2)
    (conv-k))

(assert-equal? (conv-param) 0)
