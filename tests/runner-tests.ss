(library (runner-tests)
  (export run-runner-tests)
  (import (chezscheme) (ui) (test-runner))

  (define (run-runner-tests)
    (tassert "run unify free-ground" (run 1 (q) (== q 1)) '(1))
    (tassert "run unify free-ground take all" (run 2 (q) (== q 1)) '(1))
    (tassert "run conj no-ops" (run 1 (q) (== 2 2) (== q q) (== q 1) (== 2 2)) '(1))
    (tassert "run conj two bindings" (run 1 (q r) (== q 1) (== r 2)) '((1 2)))
    (tassert "run disj 2 empty states" (run* () (conde [(== 1 1)] [(== 2 2)])) '(() ()))
    (tassert "run disj 3 empty states" (run* () (conde [(== 1 1)] [(== 2 2)] [(== 3 3)])) '(() () ()))
    (tassert "run disj 3 unifications" (run* (q) (conde [(== q 1)] [(== q 2)] [(== q 3)])) '(1 2 3)) 
    
    ))