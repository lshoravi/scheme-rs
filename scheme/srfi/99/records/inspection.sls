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

  (define (field-name-index rtd name)
    (let ((all (rtd-all-field-names rtd)))
      (let loop ((i 0))
        (cond
          ((= i (vector-length all))
           (assertion-violation 'rtd-field-mutable?
                                "no such field" name))
          ((eq? name (vector-ref all i)) i)
          (else (loop (+ i 1)))))))

  (define (rtd-field-mutable? rtd name)
    (record-field-mutable? rtd (field-name-index rtd name))))
