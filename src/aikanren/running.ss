(library (running)
  (export runner-next runner-step runner-take)
  (import (chezscheme) (runner) (goals) (failure) (state) (datatypes))

  (define (runner-null? r)
    (assert (runner? r))
    (failure? (runner-stream r)))
  
  (define (runner-step r)
    (assert (runner? r))
    (if (answer? (runner-stream r)) (make-runner failure (runner-query r) (runner-package r))
     (let-values ([(s p) (stream-step (runner-stream r) (runner-package r))])
       (make-runner s (runner-query r) p))))
  
  (define (runner-pair? r)
    (assert (runner? r))
    (not (failure? (runner-car r))))
  
  (define (runner-car r)
    (assert (runner? r))
    (cond
     [(answer? (runner-stream r)) (runner-stream r)]
     [(answers? (runner-stream r)) (answers-car (runner-stream r))]
     [else failure]))
  
  (define (runner-next r)
    (assert (runner? r))
    (let ([r (runner-step r)])
      (cond
       [(runner-null? r) (values (void) failure r)]
       [(runner-pair? r) (values (reify (runner-car r) (runner-query r)) (runner-car r) r)]
       [else (runner-next r)])))
  
  (define (runner-take n r)
    (assert (runner? r))
    (if (zero? n) '()
	(let-values ([(reified state r) (runner-next r)])
	  (if (failure? state) '() (cons (cons reified state) (runner-take (fx1- n) r)))))))