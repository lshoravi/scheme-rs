(library (rnrs parameters)
  (export make-parameter parameter? parameterize)
  (import (rnrs) (rnrs parameters bridge))

  (define (make-parameter init . args)
    (let* ((converter (if (null? args) #f (car args)))
           (converted-init (if converter (converter init) init))
           (param (%make-parameter converted-init (or converter #f))))
      (case-lambda
        (() (%parameter-ref param))
        ((val) (%parameter-set! param (if converter (converter val) val))))))

  ;; Duplicate parameters in one parameterize: the last binding wins (matches Chez).
  (define-syntax parameterize
    (syntax-rules ()
      ((_ () body ...)
       (begin body ...))
      ((_ ((param val) ...) body ...)
       (let* ((ps (map %parameter-extract (list param ...)))
              (vs (map (lambda (rp v)
                         (let ((c (%parameter-converter rp)))
                           (if c (c v) v)))
                       ps
                       (list val ...))))
         (%call-with-parameterization ps vs (lambda () body ...)))))))
