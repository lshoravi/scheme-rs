(library (srfi 99 records inspection)
  (export record? record-rtd
          rtd-name rtd-parent rtd-field-names
          rtd-all-field-names rtd-field-mutable?)
  (import (rnrs))

  (define rtd-name record-type-name)
  (define rtd-parent record-type-parent)
  (define rtd-field-names record-type-field-names)

  (define (rtd-all-field-names rtd)
    (let ((parent (rtd-parent rtd)))
      (if parent
          (vector-append (rtd-all-field-names parent)
                         (rtd-field-names rtd))
          (rtd-field-names rtd))))

  (define (find-field-rtd-and-index rtd name)
    (let ((fields (rtd-field-names rtd)))
      (let loop ((i 0))
        (cond
          ((< i (vector-length fields))
           (if (eq? name (vector-ref fields i))
               (cons rtd i)
               (loop (+ i 1))))
          ((rtd-parent rtd)
           (find-field-rtd-and-index (rtd-parent rtd) name))
          (else
           (assertion-violation 'rtd-field-mutable?
                                "no such field" name))))))

  (define (rtd-field-mutable? rtd name)
    (let ((result (find-field-rtd-and-index rtd name)))
      (record-field-mutable? (car result) (cdr result)))))
