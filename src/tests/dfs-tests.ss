(library (dfs-tests)
  (export run-dfs-tests)
  (import (chezscheme) (test-runner) (aikanren) (utils))

  (define (run-dfs-tests)
    (tassert "dfs ==" (run1*-dfs (x1) (== x1 1)) 1)
    (tassert "dfs == & ==" (run1*-dfs (x1 x2) (== x1 1) (== x2 2)) '(1 2))
    (tassert "dfs == & == depth 1" (run1-dfs 1 (x1 x2) (== x1 1) (== x2 2)) '(1 2))
    (tassert "dfs == | ==" (run**-dfs (x1) (conde [(== x1 1)] [(== x1 2)])) '(1 2))
    (tassert "dfs == | == answers 1" (run1*-dfs (x1) (conde [(== x1 1)] [(== x1 2)])) 1)
    (tassert "dfs (|) | (|) depth 2" (run*-dfs 2 (x1) (conde [(conde [(== x1 1)] [(== x1 2)])] [(== x1 2)])) '(2))
    (tassert "dfs exist" (run1*-dfs (x1) (exist (x2) (== x1 x2) (== x2 1))) 1)
    (tassert "dfs fresh" (run1*-dfs (x1) (fresh (x2) (== x1 x2) (== x2 1))) 1)
    (tassert "dfs matcho" (run1*-dfs (x1) (matcho ([x1 (a . d)]) (== a 1) (== d 2))) '(1 . 2))
))