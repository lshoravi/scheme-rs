(library (srfi 99 records procedural)
  (export make-rtd rtd? rtd-constructor rtd-predicate
          rtd-accessor rtd-mutator)
  (import (rnrs)
          (srfi 99 records inspection))

  (define (convert-fieldspecs fieldspecs)
    (let ((n (vector-length fieldspecs)))
      (let loop ((i 0) (result '()))
        (if (= i n)
            (list->vector (reverse result))
            (let ((f (vector-ref fieldspecs i)))
              (loop (+ i 1)
                    (cons (if (symbol? f)
                              (list 'immutable f)
                              f)
                          result)))))))

  (define make-rtd
    (case-lambda
      ((name fieldspecs)
       (make-rtd name fieldspecs #f))
      ((name fieldspecs parent)
       (make-record-type-descriptor
        name parent #f #f #f (convert-fieldspecs fieldspecs)))))

  (define rtd? record-type-descriptor?)

  (define rtd-predicate record-predicate)

  (define (field-name-index rtd name)
    (let ((all (rtd-all-field-names rtd)))
      (let loop ((i 0))
        (cond
          ((= i (vector-length all))
           (assertion-violation 'field-name-index "no such field" name))
          ((eq? name (vector-ref all i)) i)
          (else (loop (+ i 1)))))))

  (define (rtd-accessor rtd field-name)
    (record-accessor rtd (field-name-index rtd field-name)))

  (define (rtd-mutator rtd field-name)
    (record-mutator rtd (field-name-index rtd field-name)))

  (define rtd-constructor
    (case-lambda
      ((rtd)
       (let ((rcd (make-record-constructor-descriptor rtd #f #f)))
         (record-constructor rcd)))
      ((rtd fieldspecs)
       (let* ((all (rtd-all-field-names rtd))
              (full-constructor
               (let ((rcd (make-record-constructor-descriptor rtd #f #f)))
                 (record-constructor rcd)))
              (n (vector-length all))
              (indices
               (let loop ((i 0) (result '()))
                 (if (= i (vector-length fieldspecs))
                     (reverse result)
                     (loop (+ i 1)
                           (cons (field-name-index rtd (vector-ref fieldspecs i))
                                 result))))))
         (lambda args
           (let ((vals (make-vector n (if #f #f))))
             (for-each (lambda (idx arg)
                         (vector-set! vals idx arg))
                       indices args)
             (apply full-constructor (vector->list vals)))))))))
