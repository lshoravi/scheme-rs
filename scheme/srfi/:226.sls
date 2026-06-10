(library (srfi :226)
  (export make-fluid fluid? fluid-ref fluid-set! with-fluids %with-fluids
          make-parameter parameter? parameterize)
  (import (rnrs))

  (define-syntax with-fluids
    (syntax-rules ()
      ((_ ((fluid val) ...) body ...)
       (%with-fluids (list fluid ...) (list val ...) (lambda () body ...)))))

  (define %parameter-sentinel (gensym))

  (define (make-parameter init . args)
    (let* ((converter (if (null? args) (lambda (x) x) (car args)))
           (fluid (make-fluid (converter init))))
      (case-lambda
        (() (fluid-ref fluid))
        ((val)
         (if (eq? val %parameter-sentinel)
             (cons fluid converter)
             (let ((prev (fluid-ref fluid)))
               (fluid-set! fluid (converter val))
               prev))))))

  (define (parameter? obj)
    (and (procedure? obj)
         (guard (exn (#t #f))
           (let ((result (obj %parameter-sentinel)))
             (and (pair? result)
                  (fluid? (car result)))))))

  (define-syntax parameterize
    (syntax-rules ()
      ((_ () body ...)
       (begin body ...))
      ((_ ((param val) ...) body ...)
       (let ((p (list (param %parameter-sentinel) ...))
             (v (list val ...)))
         (let ((fluids (map car p))
               (vals (map (lambda (pc v) ((cdr pc) v)) p v)))
           (%with-fluids fluids vals (lambda () body ...))))))))
