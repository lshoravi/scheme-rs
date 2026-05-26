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

  (define (global-field-index rtd name)
    (let ((all (rtd-all-field-names rtd)))
      (let loop ((i 0))
        (cond
          ((= i (vector-length all))
           (assertion-violation 'global-field-index "no such field" name))
          ((eq? name (vector-ref all i)) i)
          (else (loop (+ i 1)))))))

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
           (assertion-violation 'find-field-rtd-and-index
                                "no such field" name))))))

  (define (rtd-accessor rtd field-name)
    (let ((result (find-field-rtd-and-index rtd field-name)))
      (record-accessor (car result) (cdr result))))

  (define (rtd-mutator rtd field-name)
    (let ((result (find-field-rtd-and-index rtd field-name)))
      (record-mutator (car result) (cdr result))))

  (define (make-field-constructor rtd fieldspecs full-constructor)
    (let ((all (rtd-all-field-names rtd)))
      (let ((n (vector-length all)))
        (let ((indices
               (let loop ((i 0) (result '()))
                 (if (= i (vector-length fieldspecs))
                     (reverse result)
                     (loop (+ i 1)
                           (cons (global-field-index rtd (vector-ref fieldspecs i))
                                 result))))))
          (lambda args
            (apply full-constructor
                   (place-args n indices args)))))))

  (define (place-args n indices args)
    (let ((pairs (map cons indices args)))
      (let build ((i 0))
        (if (= i n)
            '()
            (cons (cond ((assv i pairs) => cdr)
                        (else #f))
                  (build (+ i 1)))))))

  (define rtd-constructor
    (case-lambda
      ((rtd)
       (let ((rcd (make-record-constructor-descriptor rtd #f #f)))
         (record-constructor rcd)))
      ((rtd fieldspecs)
       (make-field-constructor rtd fieldspecs (rtd-constructor rtd))))))
