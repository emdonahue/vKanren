(begin

  (bench "quine" 100
	 ;; Greedily consume ground terms without extending the substitution/store
	 (run 1 (q) (quine-evalo q q)))

    )