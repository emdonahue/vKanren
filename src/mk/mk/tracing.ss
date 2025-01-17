(library (mk tracing)
  (export trace-run trace-run*
          trace-goal trace-conde trace-goals          
          printfo displayo noopo walk-substitution
          prove state-proof
          org-trace)
  (import (chezscheme) (mk core streams) (mk core goals) (mk core solver) (mk core utils) (mk core state) (mk core sbral) (mk core search) (mk core running) (mk core state) (mk core reifier))

  ;; === PARAMETERS ===

  (define trace-goals (make-parameter #t)) ; External flag to enable or disable trace printing.
  (define tracing (make-parameter #f)) ; Internal flag that signals the trace system is running.

  ;; === SIMPLE DEBUG PRINTING ===
  
  (define (printfo . args) ; A no-op goal that prints its arguments as part of the debug logging system.
    (noopo (apply org-printf args) (org-printf "~%")))

  (define-syntax displayo ; A no-op goal that reifies and displays its arguments as part of the debug logging system.
    (syntax-rules ()
      [(_ expr ...)
       (let ([displayo (lambda (s p c) (org-display (reify s expr) ...) (values succeed s p c))]) displayo)]))

  (define-syntax noopo ; A no-op goal that executes arbitrary code when called as part of the search.
    (syntax-rules ()
      [(_ body ...)
       (let ([noopo (lambda (s p c) body ... (values succeed s p c))]) noopo)]))

  (define (walk-substitution s)
    (cert (state? s))
    (org-untrace
     (let ([bindings (reverse (sbral->list (state-substitution s)))])
       (map (lambda (i b) (cons (fx1+ i) b)) (enumerate bindings) bindings))))

  ;; === DATA STRUCTURES ===

  (define-structure (trace-data theorem proof)) ; Tracing data records the path of trace-goal names taken by a specific state and is stored in the state in a trace-data structure.

  (define (state-theorem s) ; The theorem is the (potentially partial) path of trace-goal names the search is constrained to follow. Once this path has been satisfied (assuming it ends with the wildcard __ path), the search can continue as normal. Useful for constraining the search to explore a particular part of the space without changing the search itself.
    (cert (state? s))
    (trace-data-theorem (state-attr s trace-data?)))

  (define (state-proof s) ; The proof is the current path through trace-goal names a given state has followed to this point in the search. Used in debug printing understand what path this state has taken, as well as to compare with the current theorem to determine if the state should be discarded.
    (cert (state? s))
    (trace-data-proof (state-attr s trace-data?)))

  (define (set-state-trace s theorem proof)
    (cert (state? s))
    (state-attr s trace-data? (make-trace-data theorem proof)))


  ;; === INTERFACE ===

  (define-syntax trace-goal ; Wraps one or more goals and adds a level of nesting to the trace output.
    ;; (trace-goal name goals...)
    ;; When the trace is printing, goals wrapped in trace-goal will print within a nested hierarchy under a new heading titled <name>. States also carry "proofs," corresponding to the tree of names of trace goals they have encountered.
    (syntax-rules ()
      [(_ name goals ...)
       (if (tracing) ; If we are not inside a trace call, don't even render the trace goal.
           (dfs-goal (lambda (s p n answers c)
                       (run-trace-goal (conj* goals ...) s p n answers 'name '(goals ...) c)))
           (conj* goals ...))]))

  (define-syntax trace-conde ; Equivalent to conde but each branch begins with a name and implicitly instantiates a trace-goal.
    ;; (trace-conde [name1 g1 ...] [name2 g2 ...] ...)
    (syntax-rules ()
      [(_ (name g ...)) (trace-goal name g ...)]
      [(_ c0 c ...) (conde-disj (trace-conde c0) (trace-conde c ...))]))

  (define-syntax prove ; Asks the tracing interpreter to prove a particular path through the program.
    ;; (trace-run (q) (prove <(partial) proof generated by previous trace-run> g ...))
    ;; During tracing, each trace-goal encountered prints a proof that records what program path through other trace goals was taken to arrive at that goal. At intermediate trace-goals, the path is open ended (ending in a __). The trace-run interpreter also returns complete proofs with its final answers. Any of these proofs can be copied verbatim and pasted into the prove goal to enforce that any wrapped goals will fail if they deviate from this proof path. The purpose of this goal is to allow the user to incrementally constrain paths through the search so as to debug deep parts of the search space by skipping searches in other parts of the space.
    (syntax-rules ()
      [(_ theorem g ...)
       (lambda (s p c)
         (values (conj* g ...) (set-state-trace s 'theorem (state-proof s)) p c))]))

  (define-syntax trace-run ; Equivalent to run, but activates tracing system.
    ;; (trace-run num-answers (q) g ...)
    ;; The tracing system prints nested debugging information including which trace-goals have been encountered, and various views of the substitution and constraints at each trace-goal. Output is formatted with line-initial asterisks, and is intended to be viewed in a collapsible outline viewer such as Emacs org mode.
    (syntax-rules ()
      [(_ n q g ...)
       (parameterize ([tracing #t] ; Signal that trace-goals should not optimize themselves away.
                      [search-strategy search-strategy/dfs]
                      [org-tracing (trace-goals)])
         (run n q
           (conj* (lambda (s p c) (values c (set-state-trace s open-proof open-proof) p succeed)) ; First goal opens a new proof and theorem
                  g ...
                  ;; Last gaol closes the proof.
                  (lambda (s p c) (values c (set-state-trace s (state-theorem s) (close-proof (state-proof s))) p succeed)))))]))

  (define-syntax trace-run* ; Equivalent to run*, but activates tracing.
    (syntax-rules ()
      [(_ q g ...) (trace-run -1 q g ...)]))


  ;; === STREAMS ===


  (define (run-trace-goal g s p n answers name source ctn)
    (if (theorem-contradiction? (state-theorem s) name) ; If this trace-goal name diverges from the required proof,
        (run-goal-dfs fail s p n answers ctn) ; fail immediately.
        (let ([s (set-state-trace
                  s (subtheorem (state-theorem s))
                  (open-subproof (state-proof s) name))])
          (print-trace-header s name source)
          (parameterize ([org-depth (fx1+ (org-depth))])
            (let-values ([(ans-remaining child-answers p)
                          (run-goal-dfs
                           g s p n '()
                              (lambda (s p c) ; Encountering the ctn => we have finished with this trace-goal's children, and must clean up the proof before proceeding to the next ctn conjuncts.
                                (if (theorem-contradiction? (state-theorem s) '()) ; When returning from a trace-goal's children, we should have exactly matched the proof of that trace-goal.
                                    (values fail failure p fail) ; If there are unproven terms in our theorem, we fail.
                                    ;; Otherwise, trim the theorem and close the proof before moving on.
                                    (values ctn (set-state-trace s (subtheorem (state-theorem s)) (close-subproof (state-proof s))) p c))))])
              (print-trace-answers s child-answers)
              (values ans-remaining (append child-answers answers) p))))))


  ;; === PRINTING ===

  (define (print-trace-header s name source)
    (when (trace-goals)
      (org-print-header name)
      (parameterize ([org-depth (fx1+ (org-depth))])
        (org-print-header "<state>")
        (org-print-header "<goal>")
        (org-print-item source)
        (parameterize ([org-depth (fx1+ (org-depth))])
          (print-trace-answer s)))))

  (define (print-trace-answers s answers) ; Prints one nested tree in the org outline corresponding to the current trace-goal.
    (when (trace-goals)
      (if (null? answers) (org-print-header "<failure>")
          (begin (org-print-header "<answers>")
                 (for-each (lambda (i s)
                             (parameterize ([org-depth (fx1+ (org-depth))])
                               (org-print-header (number->string i))
                               (parameterize ([org-depth (fx1+ (org-depth))])
                                 (print-trace-answer s)))) (enumerate answers) answers)))))

  (define (print-trace-answer s) ; Prints all the relevant details of a state
    (when (trace-goals)
      (org-print-header "proof")
      (org-print-item (reverse-proof (state-proof s)))
      (org-print-header "query")
      (org-print-item (reify-var s (query)))
      (let* ([substitution (walk-substitution s)] ;TODO print unbound variables in substitution debugging by checking var id in state
             [constraints (filter (lambda (b) (and (goal? (cdr b)) (not (succeed? (cdr b))))) substitution)])
        (unless (null? constraints)
          (org-print-header "constraints")
          (for-each (lambda (b) (org-print-item (car b) (cdr b))) constraints))
        (unless (null? substitution)
          (org-print-header "substitution")
          (for-each (lambda (b) (org-print-item (car b) (cdr b))) substitution)))))

  ;; === PROOFS ===

  (define cursor '__) ; The cursor represents the 'current' location in the proof tree. It will be replaced by the next trace-goal name encountered and a new cursor will be inserted.

  (define (cursor? c) (eq? c cursor))

  (define open-proof (list cursor)) ; Creates a new, empty proof.

  (define (close-proof proof)
    (reverse-proof (cdr proof))) ; Removes the cursor from a partial proof and declares it complete and closed. Closed proofs represent final returned answers.

  (define (open-subproof proof name) ; Opens a nested proof for describing the path through the children of a trace-goal.
    (if (cursor? (car proof)) (cons (list cursor name) (cdr proof))
        (cons (open-subproof (car proof) name) (cdr proof))))

  (define (close-subproof proof) ; Closes a subproof on returning from a trace-goal.
    (if (cursor? (caar proof)) (cons* cursor (cdar proof) (cdr proof))
        (cons (close-subproof (car proof)) (cdr proof))))

  (define (reverse-proof proof) ; Because proofs are built in reverse order, they must be reversed in order to be used in-order as inputs to constrain a subsequent search.
    (if (pair? proof) (reverse (map reverse-proof proof)) proof))

  (define (theorem-contradiction? theorem term) ; Checks for a contradiction between the head of the theorem and the current name/term.
    (if (pair? theorem) (theorem-contradiction? (car theorem) term) (not (or (eq? theorem cursor) (eq? theorem term)))))

  (define (subtheorem theorem) ; Trims the first term off a theorem so we can continue to check the remainder.
    (if (pair? theorem)
        (if (pair? (car theorem)) (cons (subtheorem (car theorem)) (cdr theorem))
            (if (cursor? (car theorem)) cursor (cdr theorem))) theorem))

  (define (theorem-trivial? theorem) ; A theorem is trivial when its head is the cursor, meaning that the proof is entirely unconstrained.
    (if (pair? theorem) (theorem-trivial? (car theorem)) (cursor? theorem))))
