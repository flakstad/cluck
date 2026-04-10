;; Compile-time helpers for standalone Cluck builds.
;;
;; This file is intended to be included inside `begin-for-syntax` before
;; `cluck.scm` and any Cluck source files that rely on its macro layer.

(define (cluck-standalone-trim-trailing-slash path)
  (let ((len (string-length path)))
    (if (and (> len 0)
             (char=? (string-ref path (- len 1)) #\/))
        (substring path 0 (- len 1))
        path)))

(define (cluck-standalone-normalize-directory dir)
  (if (and dir (> (string-length dir) 0))
      (let ((len (string-length dir)))
        (if (char=? (string-ref dir (- len 1)) #\/)
            dir
            (string-append dir "/")))
      #f))

(define (cluck-standalone-path-directory path)
  (let loop ((i (- (string-length path) 1)))
    (cond
      ((< i 0) #f)
      ((char=? (string-ref path i) #\/)
       (substring path 0 (+ i 1)))
      (else
       (loop (- i 1))))))

(define (cluck-standalone-parent-directory path)
  (cluck-standalone-path-directory
   (cluck-standalone-trim-trailing-slash path)))

(define (cluck-standalone-find-project-root dir)
  (let loop ((current (cluck-standalone-normalize-directory dir)))
    (cond
      ((not current) #f)
      ((file-exists? (string-append current "examples/cluck/bootstrap.scm"))
       current)
      ((string=? current "/")
       #f)
      (else
       (loop (cluck-standalone-parent-directory current))))))

(define (cluck-standalone-absolute-path path)
  (if (and (> (string-length path) 0)
           (char=? (string-ref path 0) #\/))
      path
      (let ((cwd (cluck-standalone-normalize-directory (current-directory))))
        (if cwd
            (string-append cwd path)
            path))))

(define (cluck-standalone-namespace->path ns)
  (let* ((s (symbol->string ns))
         (len (string-length s))
         (p (open-output-string)))
    (let loop ((i 0))
      (if (= i len)
          (get-output-string p)
          (begin
            (write-char (if (char=? (string-ref s i) #\.) #\/ (string-ref s i))
                        p)
            (loop (+ i 1)))))))

(define (cluck-standalone-last-path-segment path)
  (let loop ((i (- (string-length path) 1)))
    (cond
      ((< i 0) path)
      ((char=? (string-ref path i) #\/)
       (substring path (+ i 1) (string-length path)))
      (else
       (loop (- i 1))))))

(define (cluck-standalone-root-candidates root)
  (let prefix-loop ((prefixes '("" "src/" "examples/")) (acc '()))
    (if (null? prefixes)
        (reverse acc)
        (let ((prefix (car prefixes)))
          (let suffix-loop ((suffixes '(".clk" ".clj" ".clj.scm" ".scm")) (acc acc))
            (if (null? suffixes)
               (prefix-loop (cdr prefixes) acc)
                (suffix-loop (cdr suffixes)
                             (cons (string-append prefix root (car suffixes))
                                   acc))))))))

(define (cluck-standalone-string-prefix? prefix s)
  (let ((plen (string-length prefix))
        (slen (string-length s)))
    (and (<= plen slen)
         (string=? prefix (substring s 0 plen)))))

(define (cluck-standalone-example-module-candidates ns)
  (let* ((path (cluck-standalone-namespace->path ns))
         (prefix "cluck/examples/"))
    (if (cluck-standalone-string-prefix? prefix path)
        (let* ((name (substring path (string-length prefix) (string-length path)))
               (base (string-append "examples/cluck/" name))
               (slash-pos
                (let loop ((i 0) (found #f))
                  (if (= i (string-length name))
                      found
                      (loop (+ i 1)
                            (if (char=? (string-ref name i) #\/) i found)))))
               (example-src-candidates
                (if slash-pos
                    (let* ((example-root (substring name 0 slash-pos))
                           (module-path (substring name (+ slash-pos 1) (string-length name)))
                           (example-base (string-append "examples/cluck/"
                                                        example-root
                                                        "/src/"
                                                        module-path)))
                      (list (string-append example-base ".clk")
                            (string-append example-base ".clj")
                            (string-append example-base ".clj.scm")
                            (string-append example-base ".scm")))
                    '())))
          (append example-src-candidates
                  (list (string-append base "/main.clk")
                        (string-append base ".clk")
                        (string-append base "/main.clj")
                        (string-append base ".clj")
                        (string-append base "/main.clj.scm")
                        (string-append base ".clj.scm")
                        (string-append base "/main.scm")
                        (string-append base ".scm"))))
        '())))

(define (cluck-standalone-module-candidates ns)
  (let* ((path (cluck-standalone-namespace->path ns))
         (base (cluck-standalone-last-path-segment path))
         (example-candidates (cluck-standalone-example-module-candidates ns))
         (roots (if (string=? path base)
                    (list path)
                    (list path base))))
    (let root-loop ((rs roots) (acc example-candidates))
      (if (null? rs)
          (reverse acc)
          (root-loop (cdr rs)
                     (append (cluck-standalone-root-candidates (car rs)) acc))))))

(define (cluck-standalone-locate-module-file ns)
  (let ((candidates (cluck-standalone-module-candidates ns)))
    (let root-loop ((roots *cluck-module-search-roots*))
      (cond
        ((null? roots) #f)
        (else
         (let ((root (or (cluck-standalone-normalize-directory (car roots))
                         "")))
           (let candidate-loop ((xs candidates))
             (cond
               ((null? xs) (root-loop (cdr roots)))
               (else
                (let ((path (string-append root (car xs))))
                  (if (file-exists? path)
                      path
                      (candidate-loop (cdr xs)))))))))))))

(define (cluck-standalone-vector-form->list x)
  (cond
    ((vector? x) (vector->list x))
    ((and (pair? x) (eq? (car x) 'vector)) (cdr x))
    (else #f)))

(define (cluck-standalone-map-form->pairs x)
  (cond
    ((map? x)
     (cluck-map-alist x))
    ((and (pair? x) (eq? (car x) 'hash-map))
     (let loop ((xs (cdr x)) (acc '()))
       (cond
         ((null? xs) (reverse acc))
         ((null? (cdr xs))
          (error "map destructuring form must contain an even number of forms" x))
         (else
          (loop (cddr xs) (cons (cons (car xs) (cadr xs)) acc))))))
    (else #f)))

(define (cluck-standalone-keyword-form-name x)
  (cond
    ((keyword? x) (name x))
    ((and (pair? x)
          (eq? (car x) 'keyword)
          (pair? (cdr x))
          (null? (cddr x))
          (string? (cadr x)))
     (cadr x))
    ((and (pair? x)
          (eq? (car x) 'quote)
          (pair? (cdr x))
          (null? (cddr x))
          (keyword? (cadr x)))
     (name (cadr x)))
    (else #f)))

(define (cluck-standalone-ns-form->symbol form)
  (cond
    ((symbol? form) form)
    ((pair? form)
     (if (and (eq? (car form) 'quote)
              (pair? (cdr form))
              (null? (cddr form))
              (symbol? (cadr form)))
         (cadr form)
         (error "namespace name must be a symbol or quoted symbol" form)))
    (else
     (error "namespace name must be a symbol or quoted symbol" form))))

(define (cluck-standalone-symbol-list-form->list x)
  (let ((xs (cluck-standalone-vector-form->list x)))
    (cond
      ((and xs (every symbol? xs)) xs)
      ((and xs (not (every symbol? xs))) #f)
      ((pair? x)
       (let loop ((rest x) (acc '()))
         (if (null? rest)
             (reverse acc)
             (if (symbol? (car rest))
                 (loop (cdr rest) (cons (car rest) acc))
                 #f))))
      ((symbol? x) (list x))
      ((string? x) (list (string->symbol x)))
      (else #f))))

(define (cluck-standalone-all-marker? x)
  (let ((name (cluck-standalone-keyword-form-name x)))
    (or (and name (string=? name "all"))
        (and (symbol? x) (string=? (symbol->string x) "all")))))

(define *cluck-standalone-ns* 'user)
(define *cluck-module-search-roots*
  (let* ((cwd (or (cluck-standalone-normalize-directory (current-directory)) ""))
         (project-root (cluck-standalone-find-project-root cwd)))
    (cond
      ((and project-root (string=? cwd project-root))
       (list cwd))
      (project-root
       (list cwd project-root ""))
      (else
       (list cwd "")))))

(define (cluck-set-current-ns! ns)
  (set! *cluck-standalone-ns* ns)
  ns)

(define (cluck-reset-ns-aliases! ns)
  ns)

(define (cluck-standalone-cond-else? x)
  (and (keyword? x) (string=? (name x) "else")))

(define (cluck-standalone-if-thunks test then-thunk else-thunk)
  (if (truthy? test)
      (then-thunk)
      (else-thunk)))

(define (cluck-standalone-inline-truthy-form test then else-part temp)
  `(##core#let ((,temp ,test))
     (cluck-if-thunks ,temp
                      (lambda () ,then)
                      (lambda () ,else-part))))

(define (cluck-standalone-expand-and clauses rename)
  (cond
    ((null? clauses) 'true)
    ((null? (cdr clauses)) (car clauses))
    (else
     (let ((temp (rename 'cluck-and-value)))
       `(##core#let ((,temp ,(car clauses)))
          (cluck-if-thunks ,temp
                           (lambda () ,(cluck-standalone-expand-and (cdr clauses) rename))
                           (lambda () ,temp)))))))

(define (cluck-standalone-expand-or clauses rename)
  (cond
    ((null? clauses) 'false)
    ((null? (cdr clauses)) (car clauses))
    (else
     (let ((temp (rename 'cluck-or-value)))
       `(##core#let ((,temp ,(car clauses)))
          (cluck-if-thunks ,temp
                           (lambda () ,temp)
                           (lambda () ,(cluck-standalone-expand-or (cdr clauses) rename))))))))

(define (cluck-standalone-rewrite-keyword-calls form)
  (cond
    ((pair? form)
     (let ((head (car form)))
       (if (or (eq? head 'quote)
               (eq? head 'quasiquote)
               (eq? head 'ns)
               (eq? head 'comment))
           form
           (let ((rewritten (map cluck-standalone-rewrite-keyword-calls form)))
             (let ((kw-name (cluck-standalone-keyword-form-name (car rewritten))))
               (if kw-name
                   (let ((kw (car rewritten))
                         (args (cdr rewritten)))
                     (cond
                       ((null? args) rewritten)
                       ((null? (cdr args))
                        `(get ,(car args) ,kw))
                       ((null? (cddr args))
                        `(get ,(car args) ,kw ,(cadr args)))
                       (else rewritten)))
                   rewritten))))))
    ((vector? form)
     (list->vector
      (map cluck-standalone-rewrite-keyword-calls (vector->list form))))
    (else form)))

(define (cluck-standalone-expand-cond clauses rename)
  (let loop ((rest clauses))
    (cond
      ((null? rest) '(seq '()))
      ((null? (cdr rest))
       (error "cond expects test/expression pairs"))
      ((cluck-standalone-cond-else? (car rest))
       (if (null? (cddr rest))
           (cadr rest)
           (error "cond :else clause must be last")))
      (else
       (let ((tail (loop (cddr rest)))
             (value (rename 'cluck-cond-value)))
         `(cluck-if-thunks ,(car rest)
                           (lambda () ,(cadr rest))
                           (lambda () ,tail)))))))

(define (cluck-standalone-thread-step-form x step last?)
  (cluck-standalone-rewrite-keyword-calls
   (if (cluck-standalone-keyword-form-name step)
       (list step x)
       (if (and (pair? step)
                (cluck-standalone-keyword-form-name (car step)))
           (cons (car step) (cons x (cdr step)))
           (if last?
               (if (pair? step)
                   (append step (list x))
                   (list step x))
               (if (pair? step)
                   (cons (car step) (cons x (cdr step)))
                   (list step x)))))))

(define (cluck-standalone-thread-first-step x step)
  (cluck-standalone-thread-step-form x step #f))

(define (cluck-standalone-thread-last-step x step)
  (cluck-standalone-thread-step-form x step #t))

(define (cluck-standalone-thread-chain x steps stepper)
  (if (null? steps)
      x
      (cluck-standalone-thread-chain (stepper x (car steps))
                                     (cdr steps)
                                     stepper)))

(define (cluck-standalone-cond-thread-first-step x step)
  (cluck-standalone-thread-step-form x step #f))

(define (cluck-standalone-cond-thread-last-step x step)
  (cluck-standalone-thread-step-form x step #t))

(define (cluck-standalone-expand-cond-> x clauses rename stepper)
  (if (null? clauses)
      x
      (if (null? (cdr clauses))
          (error "cond-> and cond->> expect test/expression pairs" clauses)
          (let ((temp (rename 'cluck-cond-thread-value)))
            `(##core#let ((,temp ,x))
               (cluck-if-thunks ,(car clauses)
                                (lambda () ,(cluck-standalone-expand-cond-> (stepper temp (cadr clauses))
                                                                             (cddr clauses)
                                                                             rename
                                                                             stepper))
                                (lambda () ,(cluck-standalone-expand-cond-> temp
                                                                             (cddr clauses)
                                                                             rename
                                                                             stepper))))))))

(define (cluck-standalone-expand-some-thread x clauses rename stepper)
  (if (null? clauses)
      x
      (let ((temp (rename 'cluck-some-value))
            (next (rename 'cluck-some-next)))
        `(##core#let ((,temp ,x))
           (if (nil? ,temp)
               nil
               (##core#let ((,next ,(stepper temp (car clauses))))
                 (if (nil? ,next)
                     nil
                     ,(cluck-standalone-expand-some-thread next
                                                            (cdr clauses)
                                                            rename
                                                            stepper))))))))

(define (cluck-standalone-case-key->expr key)
  (cond
    ((symbol? key) `(quote ,key))
    ((and (pair? key)
          (eq? (car key) 'quote)
          (pair? (cdr key))
          (null? (cddr key)))
     key)
    (else key)))

(define (cluck-standalone-expand-case-clauses temp clauses)
  (if (null? clauses)
      `(error "No matching clause:" ,temp)
      (if (null? (cdr clauses))
          (car clauses)
          `(if (cluck-value=? ,temp ,(cluck-standalone-case-key->expr (car clauses)))
               ,(cadr clauses)
               ,(cluck-standalone-expand-case-clauses temp (cddr clauses))))))

(define (cluck-standalone-expand-case test clauses rename)
  (if (null? clauses)
      (error "case expects at least one clause" test)
      (let ((temp (rename 'cluck-case-value)))
        `(##core#let ((,temp ,test))
           ,(cluck-standalone-expand-case-clauses temp clauses)))))

(define (cluck-standalone-destructure-key-expr key)
  (let ((kw (cluck-standalone-keyword-form-name key)))
    (cond
      (kw `(keyword ,kw))
      ((and (pair? key)
            (eq? (car key) 'quote)
            (pair? (cdr key))
            (null? (cddr key))
            (symbol? (cadr key)))
       key)
      ((symbol? key) `(quote ,key))
      ((string? key) key)
      (else key))))

(define (cluck-standalone-destructure-defaults-alist defaults)
  (let ((pairs (cluck-standalone-map-form->pairs defaults)))
    (if pairs
        (let loop ((xs pairs) (acc '()))
          (if (null? xs)
              (reverse acc)
              (let* ((pair (car xs))
                     (key (car pair))
                     (sym (cond
                            ((symbol? key) key)
                            ((cluck-standalone-keyword-form-name key)
                             => string->symbol)
                            ((and (pair? key)
                                  (eq? (car key) 'quote)
                                  (pair? (cdr key))
                                  (null? (cddr key))
                                  (symbol? (cadr key)))
                             (cadr key))
                            (else
                             (error ":or keys must be symbols" key)))))
                (loop (cdr xs) (cons (cons sym (cdr pair)) acc)))))
        (error ":or expects a map" defaults))))

(define (cluck-standalone-destructure-symbol-binding sym source defaults)
  (let ((default (assoc sym defaults)))
    (if default
        (let ((tmp (gensym "destruct")))
          (list (list sym
                      `(let ((,tmp ,source))
                         (if (nil? ,tmp) ,(cdr default) ,tmp)))))
        (list (list sym source)))))

(define (cluck-standalone-bindings-from-symbol-list syms key-expr-fn defaults)
  (let loop ((xs syms) (acc '()))
    (if (null? xs)
        (reverse acc)
        (let ((sym (car xs)))
          (loop (cdr xs)
                (cons (cluck-standalone-destructure-symbol-binding sym (key-expr-fn sym) defaults)
                      acc))))))

(define (cluck-standalone-destructure-vector-pattern form source defaults)
  (let ((items (cluck-standalone-vector-form->list form)))
    (if items
        (let ((tmp (gensym "vec")))
          (let loop ((rest items)
                     (idx 0)
                     (groups (list (list (list tmp source))))
                     (rest-binding #f)
                     (as-binding #f)
                     (seen-rest? #f))
            (cond
              ((null? rest)
               (let ((body-bindings (apply append (reverse groups))))
                 (append body-bindings
                         (if as-binding
                             (list (list as-binding tmp))
                             '())
                         (if rest-binding
                             (list (list rest-binding `(cluck-seq-drop ,tmp ,idx)))
                             '()))))
              (seen-rest?
               (let ((kw (cluck-standalone-keyword-form-name (car rest))))
                 (cond
                   ((and kw (string=? kw "as"))
                    (if as-binding
                        (error "duplicate :as in vector destructuring" form)
                        (if (null? (cdr rest))
                            (error ":as expects a symbol" form)
                            (let ((sym (cluck-standalone-ns-form->symbol (cadr rest))))
                              (loop (cddr rest) idx groups rest-binding sym seen-rest?)))))
                   (else
                    (error "only :as may follow & in vector destructuring" form)))))
              (else
               (let* ((item (car rest))
                      (kw (cluck-standalone-keyword-form-name item)))
                 (cond
                   ((and kw (string=? kw "as"))
                    (if as-binding
                        (error "duplicate :as in vector destructuring" form)
                        (if (null? (cdr rest))
                            (error ":as expects a symbol" form)
                            (let ((sym (cluck-standalone-ns-form->symbol (cadr rest))))
                              (loop (cddr rest) idx groups rest-binding sym seen-rest?)))))
                   ((eq? item '&)
                    (if rest-binding
                        (error "duplicate & in vector destructuring" form)
                        (if (null? (cdr rest))
                            (error "& expects a symbol" form)
                            (let ((sym (cluck-standalone-ns-form->symbol (cadr rest))))
                              (loop (cddr rest) idx groups sym as-binding #t)))))
                   (else
                    (loop (cdr rest)
                          (+ idx 1)
                          (cons (cluck-standalone-destructure-binding item `(nth ,tmp ,idx) defaults)
                                groups)
                          rest-binding as-binding seen-rest?))))))))
        (error "vector destructuring pattern must be a vector" form))))

(define (cluck-standalone-destructure-map-pattern form source defaults)
  (let ((pairs (cluck-standalone-map-form->pairs form)))
    (if pairs
        (let ((tmp (gensym "map")))
          (let loop ((rest pairs)
                     (as-binding #f)
                     (defaults defaults)
                     (specs '()))
            (if (null? rest)
                (let ((spec-bindings
                       (apply append
                              (map (lambda (spec)
                                     (cluck-standalone-destructure-binding (car spec)
                                                                           (cdr spec)
                                                                           defaults))
                                   specs))))
                  (append (list (list tmp source))
                          spec-bindings
                          (if as-binding
                              (list (list as-binding tmp))
                              '())))
                (let* ((pair (car rest))
                       (key (car pair))
                       (value (cdr pair))
                       (kw (cluck-standalone-keyword-form-name key)))
                  (cond
                    ((and kw (string=? kw "as"))
                     (if as-binding
                         (error "duplicate :as in map destructuring" form)
                         (let ((sym (cluck-standalone-ns-form->symbol value)))
                           (loop (cdr rest) sym defaults specs))))
                    ((and kw (string=? kw "or"))
                     (let ((extra (cluck-standalone-destructure-defaults-alist value)))
                       (loop (cdr rest) as-binding (append extra defaults) specs)))
                    ((and kw (string=? kw "keys"))
                     (let ((syms (cluck-standalone-symbol-list-form->list value)))
                       (if syms
                           (loop (cdr rest)
                                 as-binding
                                 defaults
                                 (append specs
                                         (map (lambda (sym)
                                                (cons sym `(get ,tmp (keyword ,(name sym)) nil)))
                                              syms)))
                           (error ":keys expects a vector or list of symbols" value))))
                    ((and kw (string=? kw "strs"))
                     (let ((syms (cluck-standalone-symbol-list-form->list value)))
                       (if syms
                           (loop (cdr rest)
                                 as-binding
                                 defaults
                                 (append specs
                                         (map (lambda (sym)
                                                (cons sym `(get ,tmp ,(name sym) nil)))
                                              syms)))
                           (error ":strs expects a vector or list of symbols" value))))
                    ((and kw (string=? kw "syms"))
                     (let ((syms (cluck-standalone-symbol-list-form->list value)))
                       (if syms
                           (loop (cdr rest)
                                 as-binding
                                 defaults
                                 (append specs
                                         (map (lambda (sym)
                                                (cons sym `(get ,tmp (quote ,sym) nil)))
                                              syms)))
                           (error ":syms expects a vector or list of symbols" value))))
                    (else
                     (loop (cdr rest)
                           as-binding
                           defaults
                           (append specs
                                   (list (cons value
                                               `(get ,tmp ,(cluck-standalone-destructure-key-expr key) nil)))))))))))
        (error "map destructuring pattern must be a map" form))))

(define (cluck-standalone-destructure-binding pattern source defaults)
  (let ((vector-items (cluck-standalone-vector-form->list pattern))
        (map-pairs (cluck-standalone-map-form->pairs pattern)))
    (cond
      ((symbol? pattern)
       (cluck-standalone-destructure-symbol-binding pattern source defaults))
      (vector-items
       (cluck-standalone-destructure-vector-pattern pattern source defaults))
      (map-pairs
       (cluck-standalone-destructure-map-pattern pattern source defaults))
      (else
       (error "unsupported destructuring pattern" pattern)))))

(define (cluck-standalone-parse-fn-arg pattern)
  (if (symbol? pattern)
      (cons pattern '())
      (let ((tmp (gensym "arg")))
        (cons tmp (cluck-standalone-destructure-binding pattern tmp '())))))

(define (cluck-standalone-build-dotted-args fixed tail)
  (let build ((rev fixed))
    (if (null? rev)
        tail
        (cons (car rev) (build (cdr rev))))))

(define (cluck-standalone-parse-fn-args args)
  (let ((xs (cluck-standalone-vector-form->list args)))
    (if xs
        (let loop ((rest xs) (params '()) (bindings '()) (tail #f))
          (cond
            ((null? rest)
             (cons (if tail
                       (cluck-standalone-build-dotted-args (reverse params) tail)
                       (reverse params))
                   bindings))
            ((eq? (car rest) '&)
             (if tail
                 (error "fn vector can contain only one &" args)
                 (if (null? (cdr rest))
                     (error "variadic fn/vector must end with & rest")
                     (let ((tail-name (cadr rest)))
                       (if (symbol? tail-name)
                           (loop (cddr rest) params bindings tail-name)
                           (error "variadic fn/vector rest must be a symbol" tail-name))))))
            (else
             (let* ((parsed (cluck-standalone-parse-fn-arg (car rest)))
                    (param (car parsed))
                    (more-bindings (cdr parsed)))
               (loop (cdr rest)
                     (cons param params)
                     (append bindings more-bindings)
                     tail)))))
        (error "fn expects an argument vector or arity clauses"))))

(define (cluck-standalone-wrap-body bindings body)
  (if (null? bindings)
      body
      (list `(let* ,bindings ,@body))))

(define (cluck-standalone-split-docstring parts)
  (if (and (pair? parts)
           (pair? (cdr parts))
           (string? (car parts)))
      (cons (car parts) (cdr parts))
      (cons #f parts)))

(define (cluck-standalone-def-expansion name value doc)
  (if doc
      `(begin
         (define ,name ,value)
         (cluck-intern! (current-ns) ',name ,name)
         (cluck-put-doc! (current-ns) ',name ,doc)
         ,name)
      `(begin
         (define ,name ,value)
         (cluck-intern! (current-ns) ',name ,name)
         ,name)))

(define (cluck-standalone-let-binding-pair-list? bindings)
  (if (null? bindings)
      #t
      (if (and (pair? (car bindings))
               (pair? (cdr (car bindings)))
               (null? (cddr (car bindings))))
          (cluck-standalone-let-binding-pair-list? (cdr bindings))
          #f)))

(define (cluck-standalone-let-binding-pair-names bindings)
  (let loop ((xs bindings) (acc '()))
    (if (null? xs)
        (reverse acc)
        (let ((binding (car xs)))
          (loop (cdr xs) (cons (car binding) acc))))))

(define (cluck-standalone-let-binding-pair-values bindings)
  (let loop ((xs bindings) (acc '()))
    (if (null? xs)
        (reverse acc)
        (let ((binding (car xs)))
          (loop (cdr xs) (cons (cadr binding) acc))))))

(define (cluck-standalone-expand-named-let name bindings body)
  (let* ((names (cluck-standalone-let-binding-pair-names bindings))
         (values (cluck-standalone-let-binding-pair-values bindings))
         (params (list->vector names)))
    `(letrec ((,name (fn ,params ,@body)))
       (,name ,@values))))

(define (cluck-standalone-parse-let-bindings bindings)
  (let ((xs (cluck-standalone-vector-form->list bindings)))
    (if xs
        (let loop ((rest xs) (acc '()))
          (cond
            ((null? rest) acc)
            ((eq? (car rest) '&)
             (error "let bindings do not support &"))
            ((null? (cdr rest))
             (error "let bindings must contain an even number of forms"))
            (else
             (loop (cddr rest)
                   (append acc
                           (cluck-standalone-destructure-binding (car rest) (cadr rest) '()))))))
        (error "let bindings must be a vector"))))

(define (cluck-standalone-ns-require-spec->forms spec)
  (cond
    ((cluck-standalone-vector-form->list spec)
     (let* ((xs (cluck-standalone-vector-form->list spec))
            (target (cluck-standalone-ns-form->symbol (car xs)))
            (path (cluck-standalone-locate-module-file target)))
       (if path
           (list `(cluck-require-spec! ',spec))
           (let ((rest (cdr xs)))
             (if (and (pair? rest)
                      (pair? (cdr rest))
                      (null? (cddr rest))
                      (let ((kw (cluck-standalone-keyword-form-name (car rest))))
                        (and kw (string=? kw "as"))))
                 (list `(import (prefix ,target ,(string->symbol
                                                  (string-append (symbol->string
                                                                  (cluck-standalone-ns-form->symbol
                                                                   (cadr rest)))
                                                                 ":")))))
                 (error "egg imports require [module :as prefix]" spec))))))
    ((symbol? spec)
     (list `(cluck-require-spec! ',spec)))
    ((string? spec)
     (list `(cluck-require-spec! ',spec)))
    ((and (pair? spec)
          (eq? (car spec) 'quote)
          (pair? (cdr spec))
          (null? (cddr spec)))
     (cluck-standalone-ns-require-spec->forms (cadr spec)))
    (else
     (error "require expects a namespace symbol or vector spec" spec))))

(define (cluck-standalone-refer-clojure-directive->exclude directive)
  (let loop ((rest (cdr directive)) (exclude '()))
    (cond
      ((null? rest) (reverse exclude))
      ((null? (cdr rest))
       (error "refer-clojure directive expects option/value pairs" directive))
      (else
       (let ((kw (cluck-standalone-keyword-form-name (car rest))))
         (cond
           ((and kw (string=? kw "exclude"))
            (let ((syms (cluck-standalone-symbol-list-form->list (cadr rest))))
              (if syms
                  (loop (cddr rest) (append syms exclude))
                  (error ":exclude expects a symbol vector or list" (cadr rest)))))
           (else
            (error "unsupported refer-clojure option" (car rest)))))))))

(define (cluck-standalone-ns-directive->forms directive)
  (cond
    ((and (pair? directive)
          (let ((kw (cluck-standalone-keyword-form-name (car directive))))
            (and kw (string=? kw "require"))))
     (apply append
            (map cluck-standalone-ns-require-spec->forms
                 (cdr directive))))
    (else
     (error "ns directives are not yet supported" directive))))

;; Export the helper names that `cluck.scm` expects during macro expansion.
(define cluck-trim-trailing-slash cluck-standalone-trim-trailing-slash)
(define cluck-normalize-directory cluck-standalone-normalize-directory)
(define cluck-path-directory cluck-standalone-path-directory)
(define cluck-parent-directory cluck-standalone-parent-directory)
(define cluck-absolute-path cluck-standalone-absolute-path)
(define cluck-namespace->path cluck-standalone-namespace->path)
(define cluck-last-path-segment cluck-standalone-last-path-segment)
(define cluck-root-candidates cluck-standalone-root-candidates)
(define cluck-module-candidates cluck-standalone-module-candidates)
(define cluck-locate-module-file cluck-standalone-locate-module-file)
(define cluck-vector-form->list cluck-standalone-vector-form->list)
(define cluck-map-form->pairs cluck-standalone-map-form->pairs)
(define cluck-keyword-form-name cluck-standalone-keyword-form-name)
(define cluck-ns-form->symbol cluck-standalone-ns-form->symbol)
(define cluck-symbol-list-form->list cluck-standalone-symbol-list-form->list)
(define cluck-all-marker? cluck-standalone-all-marker?)
(define cluck-cond-else? cluck-standalone-cond-else?)
(define cluck-if-thunks cluck-standalone-if-thunks)
(define cluck-inline-truthy-form cluck-standalone-inline-truthy-form)
(define cluck-expand-and cluck-standalone-expand-and)
(define cluck-expand-or cluck-standalone-expand-or)
(define cluck-expand-cond cluck-standalone-expand-cond)
(define cluck-thread-first-step cluck-standalone-thread-first-step)
(define cluck-thread-last-step cluck-standalone-thread-last-step)
(define cluck-thread-chain cluck-standalone-thread-chain)
(define cluck-thread-step-form cluck-standalone-thread-step-form)
(define cluck-cond-thread-first-step cluck-standalone-cond-thread-first-step)
(define cluck-cond-thread-last-step cluck-standalone-cond-thread-last-step)
(define cluck-expand-cond-> cluck-standalone-expand-cond->)
(define cluck-expand-some-thread cluck-standalone-expand-some-thread)
(define cluck-case-key->expr cluck-standalone-case-key->expr)
(define cluck-expand-case cluck-standalone-expand-case)
(define cluck-destructure-key-expr cluck-standalone-destructure-key-expr)
(define cluck-destructure-defaults-alist cluck-standalone-destructure-defaults-alist)
(define cluck-destructure-symbol-binding cluck-standalone-destructure-symbol-binding)
(define cluck-bindings-from-symbol-list cluck-standalone-bindings-from-symbol-list)
(define cluck-destructure-vector-pattern cluck-standalone-destructure-vector-pattern)
(define cluck-destructure-map-pattern cluck-standalone-destructure-map-pattern)
(define cluck-destructure-binding cluck-standalone-destructure-binding)
(define cluck-parse-fn-arg cluck-standalone-parse-fn-arg)
(define cluck-build-dotted-args cluck-standalone-build-dotted-args)
(define cluck-parse-fn-args cluck-standalone-parse-fn-args)
(define cluck-wrap-body cluck-standalone-wrap-body)
(define cluck-split-docstring cluck-standalone-split-docstring)
(define cluck-def-expansion cluck-standalone-def-expansion)
(define cluck-let-binding-pair-list? cluck-standalone-let-binding-pair-list?)
(define cluck-let-binding-pair-names cluck-standalone-let-binding-pair-names)
(define cluck-let-binding-pair-values cluck-standalone-let-binding-pair-values)
(define cluck-expand-named-let cluck-standalone-expand-named-let)
(define cluck-parse-let-bindings cluck-standalone-parse-let-bindings)
(define cluck-ns-require-spec->forms cluck-standalone-ns-require-spec->forms)
(define cluck-refer-clojure-directive->exclude
  cluck-standalone-refer-clojure-directive->exclude)
(define cluck-ns-directive->forms cluck-standalone-ns-directive->forms)
