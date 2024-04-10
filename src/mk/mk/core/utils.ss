;; Utilities for working with multiple value returns
(library (mk core utils)
  (export with-values values-car values->list values-ref
          cert
          comment
          org-define org-lambda org-case-lambda org-trace org-untrace org-cond org-exclusive-cond org-printf org-display org-max-depth org-print-header org-print-item org-depth org-tracing org-if
          nyi)
  (import (chezscheme))

  ;; === VALUES ===
  (define-syntax with-values
    (syntax-rules ()
      [(_ vals proc) (call-with-values (lambda () vals) proc)]))

  (define-syntax values-car
    (syntax-rules ()
      [(_ vals) (with-values vals (lambda (first . rest) first))]))

  (define-syntax values->list
    (syntax-rules ()
      [(_ vals) (with-values vals list)]))

  (define-syntax values-ref
    (syntax-rules ()
      [(_ vals n) (list-ref (values->list vals) n)]))


  (define-syntax nyi
    (syntax-rules ()
      [(_) (nyi nyi)]
      [(_ message ...) (assertion-violation (string-append (string-append (symbol->string 'message) " ") ...) "Not Yet Implemented")]))

  ;; === ASSERTIONS ===
  (define-syntax cert
    (if (zero? (optimize-level)) ; TODO experiment with meta-cond for optimization time hot swaps
        (syntax-rules ()
          [(_ assertion ...) (begin (assert assertion) ...)])
        (syntax-rules ()
          [(_ assertion ...) (void)])))

  ;; === COMMENTING ===
  (define-syntax comment
    (syntax-rules ()
      [(_ comments ...) (void)]))
  
  ;; === ORG-TRACE ===
  ;; Operates like trace-* but prints Emacs org-mode file in which nested calls are collapsible headers

  ;; TODO look at https://github.com/cisco/ChezScheme/issues/128 for discussion of other tracing options
  
  (define org-depth (make-parameter 1))
  (define org-max-depth (make-parameter 0))
  (define org-tracing (make-parameter #f)) ;TODO maybe fold org-tracing boolean into depth 0?
  (define is-logging (make-parameter #f)) ; Flag to determine if we need a new "logging" header for additional logger print outs.
  (define header-id (make-parameter 0)) ; Unique numeric identifier for each header to easily find again on subsequent traces
  
  (define-syntax org-trace
    (syntax-rules ()
      [(_ body ...)
       (parameterize ([org-tracing #t])
         body ...)]))

  (define-syntax org-untrace
    (syntax-rules ()
      [(_ body ...)
       (parameterize ([org-tracing #f])
         body ...)]))

  (define (org-print-header header)
    (when (org-tracing)
      (is-logging #f)
      (printf "~a ~a [~a]~%" (make-string (org-depth) #\*) header (header-id))
      (header-id (fx1+ (header-id)))))

  (define org-print-item
    (case-lambda
      [(value)
       (when (org-tracing)
         (pretty-print value))]
      [(name value)
       (when (org-tracing)
         (printf " - ~a: " name)
         (parameterize ([pretty-initial-indent (+ 4 (string-length (call-with-string-output-port (lambda (port) (write 'name port)))))]
                        [pretty-standard-indent 0])
           (pretty-print value))
         (printf "~%"))]))

  (define (org-printf . args)
    (when (org-tracing)
      (when (not (is-logging)) (org-print-header "logging") (is-logging #t))
      (apply printf args)))
  
  (define-syntax org-display
    (if (zero? (optimize-level))
        (syntax-rules ()
          [(_ expr ...)
           (begin
             (let ([val expr])
               (when (org-tracing)
                 (when (not (is-logging)) (org-print-header "logging") (is-logging #t))
                 (org-print-item 'expr val))
               val) ...)])
        (syntax-rules ()
          [(_ expr ...) (begin expr ...)])))
  
  (define-syntax org-lambda ;TODO make org-lambda check for optimization and remove itself to improve performance with debugging infrastructure in place
    (if (zero? (optimize-level))
     (syntax-rules ()
       [(_ (arg ...) body0 body ...)
        (org-lambda lambda (_ name (arg ...) body0 body ...))]
       [(_ name (arg ...) body0 body ...)
        (lambda (arg ...)
          (org-print-header `name)
          (if (fx= (org-depth) (org-max-depth)) (assertion-violation 'name "org-max-depth reached")
              (parameterize ([org-depth (fx1+ (org-depth))])
                (org-print-header "arguments")
                (org-print-item 'arg arg) ...
                (let ([return (call-with-values (lambda () body0 body ...) list)])
                  (org-print-header "return")
                  (for-each (lambda (i r) (org-print-item (number->string i) r)) (enumerate return) return)
                  (apply values return)))))])
     (syntax-rules ()
       [(_ (arg ...) body0 body ...)
        (lambda (arg ...) body0 body ...)]
       [(_ name (arg ...) body0 body ...)
        (lambda (arg ...) body0 body ...)])))

  (define-syntax org-case-lambda
    (syntax-rules ()
      [(_ [(arg ...) body ...] ...)
       (org-case-lambda case-lambda [(arg ...) body ...] ...)]
      [(_ name [(arg ...) body ...] ...)
       (case-lambda
         [(arg ...) ((org-lambda name (arg ...) body ...) arg ...)] ...)]))
  
  (define-syntax org-cond
    (syntax-rules (else)
      [(_ (head body ...) ...)
       (org-cond cond (head body ...) ...)]
      [(_ name (head body ...) ...)
       (cond
        [head ((org-lambda name (branch) body ...) 'head)] ...)]))

  (define-syntax org-if
    (syntax-rules ()
      [(_ test t f) (org-if if test t f)]
      [(_ name test t f)
       (if test
           ((org-lambda name (branch) t) 'true)
           ((org-lambda name (branch) f) 'false))]))

  (define-syntax org-exclusive-cond (identifier-syntax org-cond))
  
  (define-syntax org-define
    (syntax-rules ()
      [(_ (var . idspec) body ...) (define var (org-lambda var idspec body ...))])))