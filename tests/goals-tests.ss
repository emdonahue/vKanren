;;TODO delete goal-tests
(library (goals-tests)
  (export)
  (import (chezscheme) (streams) (test-runner))

					;(tassert "unify goal ground-ground" (run-goal (make-unification 1 1) empty-state) empty-state)
;(tassert "fresh unify free-ground" (walk ((fresh (x) (== x 1)) empty-state) (make-var 0)) 1)

(tassert "run unify free-ground" (run 1 (q) (== q 1)) '(1))
(tassert "run unify free-ground take all" (run 2 (q) (== q 1)) '(1)))


