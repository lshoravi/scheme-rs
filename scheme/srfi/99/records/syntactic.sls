(library (srfi 99 records syntactic)
  (export define-record-type)
  (import (rnrs)
          (srfi 99 records procedural))

  (define-syntax define-record-type
    (lambda (x)
      (define (field->rtd-spec field)
        (syntax-case field ()
          [(name accessor mutator) #'(list 'mutable 'name)]
          [(name accessor) #''name]))

      (define (fields->specs fields)
        (syntax-case fields ()
          [() '()]
          [(f . rest)
           (cons (field->rtd-spec #'f)
                 (fields->specs #'rest))]))

      (define (gen-defs fields rtd-id)
        (syntax-case fields ()
          [() '()]
          [((name accessor) . rest)
           (with-syntax ([rtd rtd-id])
             (cons #'(define accessor (rtd-accessor rtd 'name))
                   (gen-defs #'rest rtd-id)))]
          [((name accessor mutator) . rest)
           (with-syntax ([rtd rtd-id])
             (cons* #'(define accessor (rtd-accessor rtd 'name))
                    #'(define mutator (rtd-mutator rtd 'name))
                    (gen-defs #'rest rtd-id)))]))

      (define (build name parent-expr ctor-name ctor-fields pred-name fields)
        (let ([rtd (datum->syntax name (gensym "rtd"))])
          (with-syntax ([rtd-var rtd]
                        [type-name name]
                        [parent parent-expr]
                        [ctor ctor-name]
                        [pred pred-name]
                        [(spec ...) (fields->specs fields)]
                        [(defs ...) (gen-defs fields rtd)])
            (if ctor-fields
                (with-syntax ([(cf ...) ctor-fields])
                  #'(begin
                      (define rtd-var (make-rtd 'type-name
                                                (vector spec ...)
                                                parent))
                      (define ctor (rtd-constructor rtd-var
                                                    (vector 'cf ...)))
                      (define pred (rtd-predicate rtd-var))
                      defs ...))
                #'(begin
                    (define rtd-var (make-rtd 'type-name
                                              (vector spec ...)
                                              parent))
                    (define ctor (rtd-constructor rtd-var))
                    (define pred (rtd-predicate rtd-var))
                    defs ...)))))

      (syntax-case x ()
        [(_ (name parent-expr) (ctor-name ctor-field ...) pred-name fspec ...)
         (build #'name #'parent-expr #'ctor-name #'(ctor-field ...)
                #'pred-name #'(fspec ...))]
        [(_ name (ctor-name ctor-field ...) pred-name fspec ...)
         (identifier? #'name)
         (build #'name #'#f #'ctor-name #'(ctor-field ...)
                #'pred-name #'(fspec ...))]
        [(_ name ctor-name pred-name fspec ...)
         (and (identifier? #'name) (identifier? #'ctor-name))
         (build #'name #'#f #'ctor-name #f
                #'pred-name #'(fspec ...))]))))
