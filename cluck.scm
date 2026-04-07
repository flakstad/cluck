(import (except scheme assoc)
        (chicken base)
        (chicken csi)
        (chicken file)
        (chicken load)
        (chicken port)
        (chicken process-context)
        (chicken repl)
        (chicken syntax)
        srfi-69)

(include "syntax-bootstrap.scm")

(define (cluck-empty-seq? x)
  (or (nil? x) (null? x)))

(define (cluck-insert-sorted x xs less?)
  (cond
    ((null? xs) (list x))
    ((less? x (car xs)) (cons x xs))
    (else (cons (car xs) (cluck-insert-sorted x (cdr xs) less?)))))

(define (cluck-sort-list xs less?)
  (let loop ((rest xs) (acc '()))
    (if (null? rest)
        acc
        (loop (cdr rest)
              (cluck-insert-sorted (car rest) acc less?)))))

(define (cluck-trim-trailing-slash path)
  (let ((len (string-length path)))
    (if (and (> len 0)
             (char=? (string-ref path (- len 1)) #\/))
        (substring path 0 (- len 1))
        path)))

(define (cluck-normalize-directory dir)
  (if (and dir (> (string-length dir) 0))
      (let ((len (string-length dir)))
        (if (char=? (string-ref dir (- len 1)) #\/)
            dir
            (string-append dir "/")))
      #f))

(define *ns* 'user)
(define *cluck-ns-registry* (make-hash-table))
(define *cluck-ns-imports* (make-hash-table))
(define *cluck-docstrings* (make-hash-table))
(define *cluck-loaded-namespaces* (make-hash-table))
(define *cluck-loading-namespaces* (make-hash-table))
(define *cluck-ns-aliases* (make-hash-table))
(define *cluck-module-search-roots*
  (list (cluck-normalize-directory (current-directory))))

(define (cluck-ensure-ns! ns)
  (let ((existing (hash-table-ref/default *cluck-ns-registry* ns #f)))
    (if existing
        existing
        (let ((table (make-hash-table)))
          (hash-table-set! *cluck-ns-registry* ns table)
          table))))

(define (cluck-set-current-ns! ns)
  (if (symbol? ns)
      (begin
        (set! *ns* ns)
        (cluck-ensure-ns! ns)
        ns)
      (error "ns expects a symbol" ns)))

(define (current-ns)
  *ns*)

(define (find-ns ns)
  (hash-table-ref/default *cluck-ns-registry* ns #f))

(define (cluck-ensure-ns-imports! ns)
  (let ((existing (hash-table-ref/default *cluck-ns-imports* ns #f)))
    (if existing
        existing
        (let ((table (make-hash-table)))
          (hash-table-set! *cluck-ns-imports* ns table)
          table))))

(define (cluck-reset-ns-imports! ns)
  (let ((table (make-hash-table)))
    (hash-table-set! *cluck-ns-imports* ns table)
    table))

(define (cluck-reset-ns-aliases! ns)
  (let ((table (make-hash-table)))
    (hash-table-set! *cluck-ns-aliases* ns table)
    table))

(define (cluck-ensure-doc-table! ns)
  (let ((existing (hash-table-ref/default *cluck-docstrings* ns #f)))
    (if existing
        existing
        (let ((table (make-hash-table)))
          (hash-table-set! *cluck-docstrings* ns table)
          table))))

(define (cluck-put-doc! ns sym doc)
  (hash-table-set! (cluck-ensure-doc-table! ns) sym doc)
  (void))

(define (cluck-doc-for ns sym)
  (let ((table (hash-table-ref/default *cluck-docstrings* ns #f)))
    (if table
        (hash-table-ref/default table sym #f)
        #f)))

(define *cluck-core-docstrings* (make-hash-table))

(define (cluck-put-core-doc! sym doc)
  (hash-table-set! *cluck-core-docstrings* sym doc)
  (void))

(define (cluck-core-doc-for sym)
  (hash-table-ref/default *cluck-core-docstrings* sym #f))

(define (cluck-copy-doc! source-ns source-sym target-ns target-sym)
  (let ((doc (cluck-doc-for source-ns source-sym)))
    (if doc
        (cluck-put-doc! target-ns target-sym doc)
        #f)))

(define (cluck-doc-search ns sym)
  (let* ((target-sym (cond
                       ((symbol? sym) sym)
                       ((string? sym) (string->symbol sym))
                       (else sym)))
         (target-ns (and (symbol? target-sym)
                         (namespace target-sym)))
         (resolved-ns (and target-ns
                           (cluck-resolved-ns-name (string->symbol target-ns))))
         (resolved-sym (if target-ns
                           (string->symbol (name target-sym))
                           target-sym)))
    (or (and resolved-ns
             (cluck-doc-for resolved-ns resolved-sym))
        (cluck-doc-for ns resolved-sym)
        (cluck-core-doc-for resolved-sym)
        (let loop ((namespaces (all-ns)))
          (cond
            ((null? namespaces) #f)
            ((eq? (car namespaces) ns)
             (loop (cdr namespaces)))
            (else
             (let ((doc (cluck-doc-for (car namespaces) resolved-sym)))
               (if doc
                   doc
                   (loop (cdr namespaces))))))))))

(define (cluck-show-doc sym)
  (let ((doc (cluck-doc-search (current-ns) sym))
        (target (cond
                  ((symbol? sym) sym)
                  ((string? sym) (string->symbol sym))
                  (else sym))))
    (if doc
        (begin
          (display (pr-str target))
          (newline)
          (newline)
          (display doc)
          (newline)
          (void))
        (begin
          (display "No docstring for ")
          (display (pr-str target))
          (newline)
          (void)))))

(define (cluck-ensure-ns-aliases! ns)
  (let ((existing (hash-table-ref/default *cluck-ns-aliases* ns #f)))
    (if existing
        existing
        (let ((table (make-hash-table)))
          (hash-table-set! *cluck-ns-aliases* ns table)
          table))))

(define (cluck-register-ns-alias! ns alias target)
  (hash-table-set! (cluck-ensure-ns-aliases! ns) alias target)
  target)

(define (cluck-resolved-ns-name ns)
  (let ((direct (find-ns ns)))
    (if direct
        ns
        (let ((aliases (hash-table-ref/default *cluck-ns-aliases*
                                                (current-ns)
                                                #f)))
          (if aliases
              (let ((target (hash-table-ref/default aliases ns #f)))
                (if target
                    target
                    #f))
              #f)))))

(define (cluck-resolve-ns-table ns)
  (let ((resolved (cluck-resolved-ns-name ns)))
    (if resolved
        (find-ns resolved)
        #f)))

(define (cluck-resolve-ns-imports-table ns)
  (let ((resolved (cluck-resolved-ns-name ns)))
    (if resolved
        (hash-table-ref/default *cluck-ns-imports* resolved #f)
        #f)))

(define (cluck-ns-form->symbol form)
  (cond
    ((symbol? form) form)
    ((string? form) (string->symbol form))
    ((and (pair? form)
          (eq? (car form) 'quote)
          (pair? (cdr form))
          (null? (cddr form))
          (symbol? (cadr form)))
     (cadr form))
    (else
     (error "namespace name must be a symbol" form))))

(define (all-ns)
  (let ((items '()))
    (hash-table-for-each
     *cluck-ns-registry*
     (lambda (k v)
       (set! items (cons k items))))
    (reverse items)))

(define (ns-publics ns)
  (let ((table (cluck-resolve-ns-table ns)))
    (if table
        (let ((m (cluck-make-map)))
          (hash-table-for-each
           table
           (lambda (k v)
             (hash-table-set! (map-hash m) k v)))
          m)
        (cluck-make-map))))

(define (ns-resolve ns sym)
  (let ((table (cluck-resolve-ns-table ns)))
    (if table
        (let ((value (hash-table-ref/default table sym #f)))
          (if value
              value
              (let ((imports (cluck-resolve-ns-imports-table ns)))
                (if imports
                    (hash-table-ref/default imports sym #f)
                    #f))))
        #f)))

(define (cluck-intern! ns sym value)
  (hash-table-set! (cluck-ensure-ns! ns) sym value)
  value)

(define (cluck-import! ns sym value)
  (hash-table-set! (cluck-ensure-ns-imports! ns) sym value)
  value)

(define (cluck-namespace->path ns)
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

(define (cluck-last-path-segment path)
  (let loop ((i (- (string-length path) 1)))
    (cond
      ((< i 0) path)
      ((char=? (string-ref path i) #\/)
       (substring path (+ i 1) (string-length path)))
      (else
       (loop (- i 1))))))

(define (cluck-root-candidates root)
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

(define (cluck-module-candidates ns)
  (let* ((path (cluck-namespace->path ns))
         (base (cluck-last-path-segment path))
         (roots (if (string=? path base)
                    (list path)
                    (list path base))))
    (let root-loop ((rs roots) (acc '()))
      (if (null? rs)
          (reverse acc)
          (root-loop (cdr rs)
                     (append (cluck-root-candidates (car rs)) acc))))))

(define (cluck-path-directory path)
  (let loop ((i (- (string-length path) 1)))
    (cond
      ((< i 0) #f)
      ((char=? (string-ref path i) #\/)
       (substring path 0 (+ i 1)))
      (else
       (loop (- i 1))))))

(define (cluck-parent-directory path)
  (cluck-path-directory (cluck-trim-trailing-slash path)))

(define (cluck-absolute-path path)
  (if (and (> (string-length path) 0)
           (char=? (string-ref path 0) #\/))
      path
      (let ((cwd (cluck-normalize-directory (current-directory))))
        (if cwd
            (string-append cwd path)
            path))))

(define (cluck-find-project-root path)
  (let loop ((dir (or (cluck-path-directory (cluck-absolute-path path))
                      (cluck-normalize-directory (current-directory)))))
    (cond
      ((not dir) (current-directory))
      ((or (file-exists? (string-append dir "cluck-cli.scm"))
           (file-exists? (string-append dir "cluck.scm")))
       dir)
      (else
       (let ((parent (cluck-parent-directory dir)))
         (if (and parent (not (string=? parent dir)))
             (loop parent)
             dir))))))

(define (cluck-with-module-search-root root thunk)
  (let ((dir (cluck-normalize-directory root)))
    (if dir
        (dynamic-wind
          (lambda ()
            (set! *cluck-module-search-roots*
                  (cons dir *cluck-module-search-roots*)))
          thunk
          (lambda ()
            (set! *cluck-module-search-roots*
                  (cdr *cluck-module-search-roots*))))
        (thunk))))

(define (cluck-with-directory dir thunk)
  (let ((saved (current-directory)))
    (if dir
        (dynamic-wind
          (lambda ()
            (change-directory dir))
          thunk
          (lambda ()
            (change-directory saved)))
        (thunk))))

(define (cluck-rewrite-keyword-calls form)
  (cond
    ((pair? form)
     (let ((head (car form)))
       (if (or (eq? head 'quote)
               (eq? head 'quasiquote)
               (eq? head 'ns)
               (eq? head 'comment))
           form
           (let ((rewritten (map cluck-rewrite-keyword-calls form)))
             (let ((kw-name (cluck-keyword-form-name (car rewritten))))
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
      (map cluck-rewrite-keyword-calls (vector->list form))))
    (else form)))

(define (cluck-eval-source-form form)
  (eval (cluck-rewrite-keyword-calls form) (interaction-environment)))

(define (cluck-eval-form form)
  (cluck-eval-source-form (cluck-source-form form)))

(define (cluck-load-source-file! path)
  (let* ((absolute (cluck-absolute-path path))
         (root (cluck-find-project-root absolute)))
    (cluck-with-module-search-root
     root
     (lambda ()
       (cluck-with-directory
        root
        (lambda ()
          (call-with-input-file
           absolute
           (lambda (port)
             (let loop ()
               (let ((form (read port)))
                 (unless (eof-object? form)
                   (cluck-eval-source-form form)
                   (loop))))))
          (void)))))))

(define (cluck-locate-module-file ns)
  (let ((candidates (cluck-module-candidates ns)))
    (let root-loop ((roots *cluck-module-search-roots*))
      (cond
        ((null? roots) #f)
        (else
         (let ((root (cluck-normalize-directory (car roots))))
           (let candidate-loop ((xs candidates))
             (cond
               ((null? xs) (root-loop (cdr roots)))
               (else
                (let ((path (string-append root (car xs))))
                  (if (file-exists? path)
                      path
                      (candidate-loop (cdr xs)))))))))))))

(define (cluck-namespace-loaded? ns)
  (hash-table-exists? *cluck-loaded-namespaces* ns))

(define (cluck-namespace-loading? ns)
  (hash-table-exists? *cluck-loading-namespaces* ns))

(define (cluck-prefix-symbol sym)
  (string->symbol (string-append (symbol->string sym) ":")))

(define (cluck-qualified-symbol alias sym)
  (string->symbol
   (string-append (symbol->string alias) "/" (symbol->string sym))))

(define (cluck-import-qualified! target-ns alias names)
  (let ((current (current-ns)))
    (let loop ((xs names))
      (if (null? xs)
          current
          (let ((source (car xs)))
            (let ((value (ns-resolve target-ns source)))
              (if value
                  (let ((target (cluck-qualified-symbol alias source)))
                    (cluck-import! current target value)
                    (cluck-copy-doc! target-ns source current target)
                    (eval `(define ,target
                             (lambda args
                               (apply (ns-resolve ',target-ns ',source) args)))
                          (interaction-environment))
                    (loop (cdr xs)))
                  (error "cannot refer missing var" target-ns source))))))))

(define (cluck-load-namespace-file! ns path)
  (let ((saved-ns (current-ns)))
    (hash-table-set! *cluck-loading-namespaces* ns #t)
    (cluck-load-source-file! path)
    (hash-table-delete! *cluck-loading-namespaces* ns)
    (cluck-set-current-ns! saved-ns)
    (hash-table-set! *cluck-loaded-namespaces* ns path)
    ns))

(define (cluck-require-namespace! ns)
  (cond
    ((cluck-namespace-loaded? ns) ns)
    ((cluck-namespace-loading? ns)
     (error "circular require detected" ns))
    (else
     (let ((path (cluck-locate-module-file ns)))
       (if path
           (cluck-load-namespace-file! ns path)
           (error "cannot locate namespace source file" ns))))))

(define (cluck-symbol-list-form->list x)
  (cond
    ((vector? x) (vector->list x))
    ((and (pair? x) (eq? (car x) 'vector)) (cdr x))
    ((pair? x) x)
    ((symbol? x) (list x))
    ((string? x) (list (string->symbol x)))
    (else #f)))

(define (cluck-keyword-form-name x)
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

(define (cluck-all-marker? x)
  (let ((name (cluck-keyword-form-name x)))
    (or (and name (string=? name "all"))
        (and (symbol? x) (string=? (symbol->string x) "all")))))

(define (cluck-hash-table-keys table)
  (let ((items '()))
    (hash-table-for-each
     table
     (lambda (k v)
       (set! items (cons k items))))
    (reverse items)))

(define (cluck-namespace-public-symbols ns)
  (let ((table (find-ns ns)))
    (if table
        (cluck-hash-table-keys table)
        '())))

(define (cluck-unique-symbols xs)
  (let loop ((rest xs) (acc '()))
    (if (null? rest)
        (reverse acc)
        (let ((sym (car rest)))
          (if (memq sym acc)
              (loop (cdr rest) acc)
              (loop (cdr rest) (cons sym acc)))))))

(define (cluck-symbol-list-diff xs exclude)
  (let loop ((rest xs) (acc '()))
    (if (null? rest)
        (reverse acc)
        (let ((sym (car rest)))
          (if (memq sym exclude)
              (loop (cdr rest) acc)
              (loop (cdr rest) (cons sym acc)))))))

(define (cluck-refer-core! exclude)
  (let ((current (current-ns)))
    (cluck-reset-ns-imports! current)
    (let loop ((xs (cluck-core-public-bindings)))
      (if (null? xs)
          current
          (let ((pair (car xs)))
            (if (memq (car pair) exclude)
                (loop (cdr xs))
                (begin
                  (cluck-import! current (car pair) (cdr pair))
                  (loop (cdr xs)))))))))

(define (cluck-refer-selected! target-ns names)
  (let ((current (current-ns)))
    (let loop ((xs names))
      (if (null? xs)
          current
          (let ((sym (car xs)))
            (let ((value (ns-resolve target-ns sym)))
              (if value
                  (begin
                    (cluck-import! current sym value)
                    (cluck-copy-doc! target-ns sym current sym)
                    (loop (cdr xs)))
                  (error "cannot refer missing var" target-ns sym))))))))

(define (cluck-refer-all! target-ns)
  (let ((table (find-ns target-ns)))
    (if table
        (let ((current (current-ns)))
          (hash-table-for-each
           table
           (lambda (sym value)
             (cluck-import! current sym value)
             (cluck-copy-doc! target-ns sym current sym)))
          current)
        (error "cannot refer missing namespace" target-ns))))

(define (cluck-import-selected! target-ns names rename exclude)
  (let ((current (current-ns)))
    (let loop ((xs names))
      (if (null? xs)
          current
          (let ((source (car xs)))
            (if (memq source exclude)
                (loop (cdr xs))
                (let ((value (ns-resolve target-ns source)))
                  (if value
                      (let ((renamed (cluck-alist-ref-pair source rename)))
                        (let ((target (if renamed (cdr renamed) source)))
                          (cluck-import! current target value)
                          (cluck-copy-doc! target-ns source current target))
                        (loop (cdr xs)))
                      (error "cannot refer missing var" target-ns source)))))))))

(define (cluck-ns-require-spec->forms spec)
  (cond
    ((cluck-vector-form->list spec)
     (let* ((xs (cluck-vector-form->list spec))
            (target (cluck-ns-form->symbol (car xs)))
            (path (cluck-locate-module-file target)))
       (if path
           (list `(cluck-require-spec! ',spec))
           (let ((rest (cdr xs)))
             (if (and (pair? rest)
                      (pair? (cdr rest))
                      (null? (cddr rest))
                      (let ((kw (cluck-keyword-form-name (car rest))))
                        (and kw (string=? kw "as"))))
                 (list `(import (prefix ,target ,(cluck-prefix-symbol
                                                  (cluck-ns-form->symbol (cadr rest))))))
                 (error "egg imports require [module :as prefix]" spec))))))
    ((symbol? spec)
     (list `(cluck-require-spec! ',spec)))
    ((string? spec)
     (list `(cluck-require-spec! ',spec)))
    ((and (pair? spec)
          (eq? (car spec) 'quote)
          (pair? (cdr spec))
          (null? (cddr spec)))
     (cluck-ns-require-spec->forms (cadr spec)))
    (else
     (error "require expects a namespace symbol or vector spec" spec))))

(define (cluck-require-vector-spec! spec)
  (let ((xs (cluck-vector-form->list spec)))
    (if (not xs)
        (error "require spec must be a vector" spec)
        (let ((target (cluck-ns-form->symbol (car xs))))
          (cluck-require-namespace! target)
          (let ((publics (cluck-namespace-public-symbols target)))
            (let loop ((rest (cdr xs))
                       (alias #f)
                       (refs '())
                       (refer-all? #f)
                       (exclude '())
                       (rename '()))
              (if (or (null? rest) (not (pair? rest)))
                  (begin
                    (if alias
                        (begin
                          (cluck-register-ns-alias! (current-ns) alias target)
                          (cluck-import-qualified! target alias publics))
                        #f)
                    (let* ((selected (if refer-all?
                                         (cluck-namespace-public-symbols target)
                                         (cluck-unique-symbols (append refs (map car rename)))))
                           (selected (cluck-symbol-list-diff selected exclude)))
                      (if (null? selected)
                          target
                          (cluck-import-selected! target selected rename exclude)))
                    target)
                  (let* ((option (car rest))
                         (kw (cluck-keyword-form-name option)))
                    (cond
                      ((and kw (string=? kw "as"))
                       (if (null? (cdr rest))
                           (error "require :as expects an alias" spec)
                           (loop (cddr rest)
                                 (cluck-ns-form->symbol (cadr rest))
                                 refs
                                 refer-all?
                                 exclude
                                 rename)))
                      ((and kw (string=? kw "refer"))
                       (if (null? (cdr rest))
                           (error "require :refer expects a symbol vector or :all" spec)
                           (let ((value (cadr rest)))
                             (if (cluck-all-marker? value)
                                 (loop (cddr rest)
                                       alias
                                       refs
                                       #t
                                       exclude
                                       rename)
                                 (let ((syms (cluck-symbol-list-form->list value)))
                                   (if syms
                                       (loop (cddr rest)
                                             alias
                                             (append refs syms)
                                             refer-all?
                                             exclude
                                             rename)
                                       (error "require :refer expects a symbol vector or :all"
                                              value)))))))
                      ((and kw (string=? kw "exclude"))
                       (if (null? (cdr rest))
                           (error "require :exclude expects a symbol vector or list" spec)
                           (let ((syms (cluck-symbol-list-form->list (cadr rest))))
                             (if syms
                                 (loop (cddr rest)
                                       alias
                                       refs
                                       refer-all?
                                       (append exclude syms)
                                       rename)
                                 (error ":exclude expects a symbol vector or list"
                                        (cadr rest))))))
                      (else
                       (error "unsupported require option" option)))))))))))

(define (cluck-require-spec! spec)
  (cond
    ((cluck-vector-form->list spec) (cluck-require-vector-spec! spec))
    ((symbol? spec) (cluck-require-namespace! spec))
    ((string? spec) (cluck-require-namespace! (string->symbol spec)))
    ((and (pair? spec)
          (eq? (car spec) 'quote)
          (pair? (cdr spec))
          (null? (cddr spec)))
     (cluck-require-spec! (cadr spec)))
    (else
     (error "require expects a namespace symbol or vector spec" spec))))

(define (cluck-refer-clojure-directive->exclude directive)
  (let loop ((rest (cdr directive)) (exclude '()))
    (cond
      ((null? rest) (reverse exclude))
      ((null? (cdr rest))
       (error "refer-clojure directive expects option/value pairs" directive))
      (else
       (let ((kw (cluck-keyword-form-name (car rest))))
         (cond
           ((and kw (string=? kw "exclude"))
            (let ((syms (cluck-symbol-list-form->list (cadr rest))))
              (if syms
                  (loop (cddr rest) (append syms exclude))
                  (error ":exclude expects a symbol vector or list" (cadr rest)))))
           (else
            (error "unsupported refer-clojure option" (car rest)))))))))

(define (cluck-ns-directive->forms directive)
  (cond
    ((and (pair? directive)
          (let ((kw (cluck-keyword-form-name (car directive))))
            (and kw (string=? kw "require"))))
     (apply append
            (map cluck-ns-require-spec->forms
                 (cdr directive))))
    (else
     (error "ns directives are not yet supported" directive))))

(define (cluck-collect-hash-pairs table)
  (let ((pairs '()))
    (hash-table-for-each
     table
     (lambda (k v)
       (set! pairs (cons (cons k v) pairs))))
    pairs))

(define (cluck-map-items m)
  (let ((items '()))
    (hash-table-for-each
     (map-hash m)
     (lambda (k v)
       (set! items (cons (vector k v) items))))
    items))

(define (cluck-set-items s)
  (let ((items '()))
    (hash-table-for-each
     (set-hash s)
     (lambda (k v)
       (set! items (cons k items))))
    items))

(define (cluck-sorted-map-pairs m)
  (cluck-sort-list
   (cluck-collect-hash-pairs (map-hash m))
   (lambda (a b)
     (string<? (pr-str (car a))
               (pr-str (car b))))))

(define (cluck-sorted-set-items s)
  (cluck-sort-list
   (let ((items '()))
     (hash-table-for-each
      (set-hash s)
      (lambda (k v)
        (set! items (cons k items))))
     items)
   (lambda (a b)
     (string<? (pr-str a)
               (pr-str b)))))

(define (cluck-map-entry->vector pair)
  (vector (car pair) (cdr pair)))

(define (cluck-vector-append-list vec items)
  (let* ((base-len (vector-length vec))
         (add-len (length items))
         (out (make-vector (+ base-len add-len))))
    (let copy-loop ((i 0))
      (if (= i base-len)
          (let fill-loop ((rest items) (j base-len))
            (if (null? rest)
                out
                (begin
                  (vector-set! out j (car rest))
                  (fill-loop (cdr rest) (+ j 1)))))
          (begin
            (vector-set! out i (vector-ref vec i))
            (copy-loop (+ i 1)))))))

(define (cluck-vector-append-vector vec items)
  (let* ((base-len (vector-length vec))
         (add-len (vector-length items))
         (out (make-vector (+ base-len add-len))))
    (let copy-base ((i 0))
      (if (= i base-len)
          (let fill-items ((j 0))
            (if (= j add-len)
                out
                (begin
                  (vector-set! out (+ base-len j) (vector-ref items j))
                  (fill-items (+ j 1)))))
          (begin
            (vector-set! out i (vector-ref vec i))
            (copy-base (+ i 1)))))))

(define (cluck-vector-append vec items)
  (cluck-vector-append-list vec items))

(define (cluck-vector-assoc vec idx value)
  (if (and (integer? idx) (>= idx 0))
      (let ((len (vector-length vec)))
        (if (< idx len)
            (begin
              (vector-set! vec idx value)
              vec)
            (let ((out (make-vector (+ idx 1) nil)))
              (let loop ((i 0))
                (if (= i len)
                    (begin
                      (vector-set! out idx value)
                      out)
                    (begin
                      (vector-set! out i (vector-ref vec i))
                      (loop (+ i 1))))))))
      (error "vector index must be a non-negative integer" idx)))

(define (cluck-seq-list x)
  (cond
    ((cluck-empty-seq? x) nil)
    ((null? x) nil)
    ((pair? x) x)
    ((map? x)
     (let ((items (cluck-map-items x)))
       (if (null? items) nil items)))
    ((set? x)
     (let ((items (cluck-set-items x)))
       (if (null? items) nil items)))
    ((vector? x)
     (let ((items (vector->list x)))
       (if (null? items) nil items)))
    ((string? x)
     (let ((items (string->list x)))
       (if (null? items) nil items)))
    (else nil)))

(define (cluck-write-pr x port)
  (cond
    ((nil? x) (display "nil" port))
    ((eq? x true) (display "true" port))
    ((eq? x false) (display "false" port))
    ((keyword? x)
     (let ((ns (namespace x)))
       (if ns
           (begin
             (display ":" port)
             (display ns port)
             (display "/" port)
             (display (name x) port))
           (begin
             (display ":" port)
             (display (name x) port)))))
    ((string? x) (write x port))
    ((symbol? x) (display (symbol->string x) port))
    ((number? x) (display (number->string x) port))
    ((char? x) (write x port))
    ((map? x)
     (display "{" port)
     (let loop ((pairs (cluck-sorted-map-pairs x)) (first? #t))
       (if (null? pairs)
           (display "}" port)
           (begin
             (if (not first?) (write-char #\space port))
             (cluck-write-pr (caar pairs) port)
             (write-char #\space port)
             (cluck-write-pr (cdar pairs) port)
             (loop (cdr pairs) #f)))))
    ((set? x)
     (display "#{" port)
     (let loop ((items (cluck-sorted-set-items x)) (first? #t))
       (if (null? items)
           (display "}" port)
           (begin
             (if (not first?) (write-char #\space port))
             (cluck-write-pr (car items) port)
             (loop (cdr items) #f)))))
    ((vector? x)
     (display "[" port)
     (let loop ((i 0))
       (if (= i (vector-length x))
           (display "]" port)
           (begin
             (if (> i 0) (write-char #\space port))
             (cluck-write-pr (vector-ref x i) port)
             (loop (+ i 1))))))
    ((null? x)
     (display "()" port))
    ((pair? x)
     (display "(" port)
     (let loop ((xs x) (first? #t))
       (cond
         ((null? xs) (display ")" port))
         ((pair? xs)
          (if (not first?) (write-char #\space port))
          (cluck-write-pr (car xs) port)
          (loop (cdr xs) #f))
         (else
          (display " . " port)
          (cluck-write-pr xs port)
          (display ")" port)))))
    (else
     (write x port))))

(set-record-printer! cluck-keyword
  (lambda (kw out)
    (cluck-write-pr kw out)))

(set-record-printer! cluck-map
  (lambda (m out)
    (cluck-write-pr m out)))

(set-record-printer! cluck-set
  (lambda (s out)
    (cluck-write-pr s out)))

(define (pr-str . xs)
  (let ((p (open-output-string)))
    (let loop ((items xs) (first? #t))
      (if (null? items)
          (get-output-string p)
          (begin
            (if (not first?) (write-char #\space p))
            (cluck-write-pr (car items) p)
            (loop (cdr items) #f))))))

(define (cluck-str-piece x)
  (cond
    ((string? x) x)
    ((char? x)
     (let ((p (open-output-string)))
       (write-char x p)
       (get-output-string p)))
    ((nil? x) "")
    ((eq? x true) "true")
    ((eq? x false) "false")
    ((keyword? x) (pr-str x))
    ((symbol? x) (symbol->string x))
    (else (pr-str x))))

(define (str . xs)
  (let ((p (open-output-string)))
    (let loop ((items xs))
      (if (null? items)
          (get-output-string p)
          (begin
            (display (cluck-str-piece (car items)) p)
            (loop (cdr items)))))))

(define (cluck-println-piece x)
  (cond
    ((string? x) x)
    ((char? x)
     (let ((p (open-output-string)))
       (write-char x p)
       (get-output-string p)))
    ((nil? x) "nil")
    ((eq? x true) "true")
    ((eq? x false) "false")
    ((keyword? x) (pr-str x))
    ((symbol? x) (symbol->string x))
    (else (pr-str x))))

(define (println . xs)
  (let ((p (open-output-string)))
    (let loop ((items xs) (first? #t))
      (if (null? items)
          (begin
            (display (get-output-string p))
            (newline)
            nil)
          (begin
            (if (not first?) (write-char #\space p))
            (display (cluck-println-piece (car items)) p)
            (loop (cdr items) #f))))))

(define (prn . xs)
  (display (apply pr-str xs))
  (newline)
  nil)

(define (cluck-format-piece x)
  (cond
    ((nil? x) "nil")
    ((string? x) x)
    ((char? x)
     (let ((p (open-output-string)))
       (write-char x p)
       (get-output-string p)))
    (else (str x))))

(define (cluck-format-pad-left s width)
  (let ((pad (- width (string-length s))))
    (if (<= pad 0)
        s
        (string-append (make-string pad #\0) s))))

(define (cluck-format-fixed number precision)
  (let* ((prec (if (and (integer? precision) (>= precision 0))
                   precision
                   (error "Invalid format precision" precision)))
         (scale (let loop ((i prec) (acc 1))
                  (if (= i 0)
                      acc
                      (loop (- i 1) (* acc 10)))))
         (rounded (round (* number scale)))
         (rounded-int (if (exact? rounded) rounded (inexact->exact rounded))))
    (if (not (integer? rounded-int))
        (error "Invalid %f argument" number)
        (let* ((negative? (negative? rounded-int))
               (abs-rounded (abs rounded-int))
               (whole (quotient abs-rounded scale))
               (fraction (remainder abs-rounded scale))
               (whole-str (number->string whole))
               (fraction-str (if (= prec 0)
                                 ""
                                 (cluck-format-pad-left
                                  (number->string fraction)
                                  prec))))
          (if (= prec 0)
              (str (if negative? "-" "") whole-str)
              (str (if negative? "-" "")
                   whole-str
                   "."
                   fraction-str))))))

(define (cluck-format-handle-directive fmt i items port)
  (let ((next (string-ref fmt i)))
    (cond
      ((char=? next #\%)
       (write-char #\% port)
       (values (+ i 1) items))
      ((char=? next #\s)
       (cond
         ((null? items) (error "Missing format argument" fmt))
         (else
          (display (cluck-format-piece (car items)) port)
          (values (+ i 1) (cdr items)))))
      ((char=? next #\d)
       (cond
         ((null? items) (error "Missing format argument" fmt))
         ((not (exact-integer? (car items)))
          (error "%d expects an integer" (car items)))
         (else
          (display (number->string (car items)) port)
          (values (+ i 1) (cdr items)))))
      ((char=? next #\f)
       (cond
         ((null? items) (error "Missing format argument" fmt))
         ((not (number? (car items)))
          (error "%f expects a number" (car items)))
         (else
          (display (cluck-format-fixed (car items) 6) port)
          (values (+ i 1) (cdr items)))))
      ((char=? next #\.)
       (let parse ((j (+ i 1)) (precision 0) (seen-digit? #f))
         (if (>= j (string-length fmt))
             (error "Incomplete %.Nf format directive" fmt)
             (let ((c (string-ref fmt j)))
               (cond
                 ((char-numeric? c)
                  (parse (+ j 1)
                         (+ (* precision 10)
                            (- (char->integer c)
                               (char->integer #\0)))
                         #t))
                 ((char=? c #\f)
                  (cond
                    ((not seen-digit?)
                     (error "Precision required for %.Nf" fmt))
                    ((null? items)
                     (error "Missing format argument" fmt))
                    ((not (number? (car items)))
                     (error "%f expects a number" (car items)))
                    (else
                     (display (cluck-format-fixed (car items) precision) port)
                     (values (+ j 1) (cdr items)))))
                 (else
                  (error "Unsupported format directive" fmt)))))))
      (else
       (error "Unsupported format directive" fmt)))))

(define (format template . args)
  "Format TEMPLATE with Clojure-style %s, %d, %% and %.Nf directives."
  (let* ((fmt (str template))
         (len (string-length fmt))
         (port (open-output-string)))
    (let loop ((i 0) (items args))
      (cond
        ((= i len)
         (cond
           ((null? items) (get-output-string port))
           (else (error "Too many arguments for format" fmt))))
        ((not (char=? (string-ref fmt i) #\%))
         (write-char (string-ref fmt i) port)
         (loop (+ i 1) items))
        ((= (+ i 1) len)
         (error "Incomplete format directive" fmt))
        (else
         (call-with-values
             (lambda () (cluck-format-handle-directive fmt (+ i 1) items port))
           (lambda (next-i next-items)
             (loop next-i next-items))))))))

(define (cluck-core-read-string s)
  (cluck-read-one s))

(define (cluck-parse-long s)
  (let ((n (string->number (str s))))
    (if (and n (integer? n) (exact? n))
        n
        (error "Invalid long" s))))

(define (cluck-parse-double s)
  (let ((n (string->number (str s))))
    (if (and n (real? n))
        (exact->inexact n)
        (error "Invalid double" s))))

(define (parse-long s)
  (cluck-parse-long s))

(define (parse-double s)
  (cluck-parse-double s))

(define (count x)
  (cond
    ((nil? x) 0)
    ((null? x) 0)
    ((string? x) (string-length x))
    ((map? x) (hash-table-size (map-hash x)))
    ((set? x) (hash-table-size (set-hash x)))
    ((vector? x) (vector-length x))
    ((pair? x)
     (let loop ((xs x) (n 0))
       (if (pair? xs)
           (loop (cdr xs) (+ n 1))
           n)))
    (else 0)))

(define (empty? x)
  (cond
    ((or (nil? x) (null? x)) #t)
    ((string? x) (= (string-length x) 0))
    ((vector? x) (= (vector-length x) 0))
    ((map? x) (= (hash-table-size (map-hash x)) 0))
    ((set? x) (= (hash-table-size (set-hash x)) 0))
    ((pair? x) #f)
    (else #f)))

(define (seq x)
  (cluck-seq-list x))

(define (first x)
  (cond
    ((or (nil? x) (null? x)) nil)
    ((pair? x) (car x))
    ((map? x) (first (seq x)))
    ((set? x) (first (seq x)))
    ((vector? x)
     (if (> (vector-length x) 0)
         (vector-ref x 0)
         nil))
    (else nil)))

(define (rest x)
  (let ((s (seq x)))
    (cond
      ((or (nil? s) (null? s)) '())
      ((pair? s) (cdr s))
      (else '()))))

(define (nth coll idx . maybe-default)
  (let ((default (if (null? maybe-default) nil (car maybe-default))))
    (cond
      ((not (and (integer? idx) (>= idx 0))) default)
      ((vector? coll)
       (if (< idx (vector-length coll))
           (vector-ref coll idx)
           default))
      ((pair? coll)
       (let loop ((xs coll) (i 0))
         (cond
           ((null? xs) default)
           ((= i idx) (car xs))
           (else (loop (cdr xs) (+ i 1))))))
      ((string? coll)
       (if (< idx (string-length coll))
           (string-ref coll idx)
           default))
      (else default))))

(define (cluck-hash-ref/default table key default)
  (hash-table-ref/default table key default))

(define (cluck-hash-exists? table key)
  (hash-table-exists? table key))

(define (cluck-hash-set! table key value)
  (hash-table-set! table key value))

(define (cluck-hash-delete! table key)
  (hash-table-delete! table key))

(define (cluck-get coll key . maybe-default)
  (let ((default (if (null? maybe-default) nil (car maybe-default))))
    (cond
      ((map? coll)
       (cluck-hash-ref/default (map-hash coll) key default))
      ((set? coll)
       (if (cluck-hash-exists? (set-hash coll) key) key default))
      ((vector? coll)
       (if (and (integer? key) (>= key 0) (< key (vector-length coll)))
           (vector-ref coll key)
           default))
      (else default))))

(define-syntax get
  (syntax-rules ()
    ((_ coll key)
     (##core#let ((c coll)
                  (k key))
       (cluck-get c k)))
    ((_ coll key default)
     (##core#let ((c coll)
                  (k key)
                  (d default))
       (cluck-get c k d)))))

(define (cluck-contains? coll key)
  (cond
    ((map? coll) (cluck-hash-exists? (map-hash coll) key))
    ((set? coll) (cluck-hash-exists? (set-hash coll) key))
    ((vector? coll)
     (and (integer? key) (>= key 0) (< key (vector-length coll))))
    (else #f)))

(define-syntax contains?
  (syntax-rules ()
    ((_ coll key)
     (##core#let ((c coll)
                  (k key))
       (cluck-contains? c k)))))

(define (cluck-map-entry? x)
  (or (and (vector? x) (= (vector-length x) 2))
      (and (pair? x) (pair? (cdr x)) (null? (cddr x)))))

(define (cluck-map-entry-key x)
  (if (vector? x) (vector-ref x 0) (car x)))

(define (cluck-map-entry-val x)
  (if (vector? x) (vector-ref x 1) (cadr x)))

(define (cluck-assoc coll . kvs)
  (cond
    ((map? coll)
     (let loop ((xs kvs))
       (cond
         ((null? xs) coll)
         ((null? (cdr xs)) (error "assoc expects key/value pairs"))
         (else
          (cluck-hash-set! (map-hash coll) (car xs) (cadr xs))
          (loop (cddr xs))))))
    ((vector? coll)
     (let loop ((xs kvs) (out coll))
       (cond
         ((null? xs) out)
         ((null? (cdr xs)) (error "assoc expects index/value pairs"))
         (else
          (let ((idx (car xs))
                (value (cadr xs)))
            (set! out (cluck-vector-assoc out idx value))
            (loop (cddr xs) out))))))
    (else
     (error "assoc only supports maps and vectors"))))

(define-syntax assoc
  (syntax-rules ()
    ((_ coll)
     (cluck-assoc coll))
    ((_ coll key val)
     (##core#let ((c coll)
                  (k key)
                  (v val))
       (cluck-assoc c k v)))
    ((_ coll key val more ...)
     (##core#let ((c coll)
                  (k key)
                  (v val))
       (assoc c more ...)))))

(define (dissoc coll . keys)
  (cond
    ((map? coll)
     (let loop ((xs keys))
       (if (null? xs)
           coll
           (begin
             (cluck-hash-delete! (map-hash coll) (car xs))
             (loop (cdr xs))))))
    ((set? coll)
     (let loop ((xs keys))
       (if (null? xs)
           coll
           (begin
             (cluck-hash-delete! (set-hash coll) (car xs))
             (loop (cdr xs))))))
    (else
     (error "dissoc only supports maps and sets"))))

(define (merge . maps)
  (let ((result (if (null? maps) (hash-map) (car maps))))
    (let loop ((xs maps))
      (if (null? xs)
          result
          (begin
            (if (map? (car xs))
                (hash-table-for-each
                 (map-hash (car xs))
                 (lambda (k v)
                   (cluck-hash-set! (map-hash result) k v))))
            (loop (cdr xs)))))))

(define (merge-with f . maps)
  (let ((result (if (null? maps) (hash-map) (car maps))))
    (if (and (pair? maps) (not (map? result)))
        (error "merge-with expects maps" result)
        (let loop ((xs (cdr maps)))
          (if (null? xs)
              result
              (begin
                (let ((m (car xs)))
                  (if (map? m)
                      (hash-table-for-each
                       (map-hash m)
                       (lambda (k v)
                         (if (cluck-hash-exists? (map-hash result) k)
                             (cluck-hash-set! (map-hash result)
                                              k
                                              (f (cluck-hash-ref/default (map-hash result)
                                                                         k
                                                                         nil)
                                                 v))
                             (cluck-hash-set! (map-hash result) k v))))
                      (error "merge-with expects maps" m)))
                (loop (cdr xs))))))))

(define (cluck-conj-map! m item)
  (cond
    ((map? item)
     (hash-table-for-each
      (map-hash item)
      (lambda (k v)
        (cluck-hash-set! (map-hash m) k v)))
     m)
    ((cluck-map-entry? item)
     (cluck-hash-set! (map-hash m)
                        (cluck-map-entry-key item)
                        (cluck-map-entry-val item))
     m)
    (else
     (error "conj expects map entries or maps when target is a map" item))))

(define (conj coll . items)
  (cond
    ((map? coll)
     (let loop ((xs items) (acc coll))
       (if (null? xs)
           acc
           (loop (cdr xs) (cluck-conj-map! acc (car xs))))))
    ((set? coll)
     (let loop ((xs items) (acc coll))
       (if (null? xs)
           acc
           (begin
             (cluck-hash-set! (set-hash acc) (car xs) #t)
             (loop (cdr xs) acc)))))
    ((vector? coll)
     (cluck-vector-append coll items))
    ((or (null? coll) (pair? coll))
     (let loop ((xs items) (acc coll))
       (if (null? xs)
           acc
           (loop (cdr xs) (cons (car xs) acc)))))
    (else
     (error "conj only supports maps, sets, vectors, and lists"))))

(define (disj coll . items)
  (cond
    ((set? coll)
     (let loop ((xs items))
       (if (null? xs)
           coll
           (begin
             (cluck-hash-delete! (set-hash coll) (car xs))
             (loop (cdr xs))))))
    (else
     (error "disj only supports sets"))))

(define (keys m)
  (if (map? m)
      (let ((items '()))
        (hash-table-for-each
         (map-hash m)
         (lambda (k v)
           (set! items (cons k items))))
        items)
      '()))

(define (vals m)
  (if (map? m)
      (let ((items '()))
        (hash-table-for-each
         (map-hash m)
         (lambda (k v)
           (set! items (cons v items))))
        items)
      '()))

(define (map f coll)
  (let loop ((xs (seq coll)) (acc '()))
    (if (cluck-empty-seq? xs)
        (reverse acc)
        (loop (cdr xs) (cons (f (car xs)) acc)))))

(define (cluck-mapv-vector f vec)
  (let* ((len (vector-length vec))
         (out (make-vector len)))
    (let loop ((i 0))
      (if (= i len)
          out
          (begin
            (vector-set! out i (f (vector-ref vec i)))
            (loop (+ i 1)))))))

(define (cluck-filterv-vector pred vec)
  (let ((len (vector-length vec)))
    (let ((out (make-vector len)))
      (let loop ((i 0) (j 0))
        (if (= i len)
            (vector-resize out j)
            (let ((item (vector-ref vec i)))
              (if (pred item)
                  (begin
                    (vector-set! out j item)
                    (loop (+ i 1) (+ j 1)))
                  (loop (+ i 1) j))))))))

(define (mapv f coll)
  (cond
    ((vector? coll) (cluck-mapv-vector f coll))
    (else (list->vector (map f (seq coll))))))

(define (filter pred coll)
  (let loop ((xs (seq coll)) (acc '()))
    (if (cluck-empty-seq? xs)
        (reverse acc)
        (let ((item (car xs)))
          (if (pred item)
              (loop (cdr xs) (cons item acc))
              (loop (cdr xs) acc))))))

(define (filterv pred coll)
  (cond
    ((vector? coll) (cluck-filterv-vector pred coll))
    (else (list->vector (filter pred (seq coll))))))

(define (cluck-map-indexed-vector f vec)
  (let* ((len (vector-length vec)))
    (let loop ((i 0) (acc '()))
      (if (= i len)
          (reverse acc)
          (loop (+ i 1)
                (cons (f i (vector-ref vec i)) acc))))))

(define (cluck-map-indexed-seq f coll)
  (let loop ((i 0) (xs (seq coll)) (acc '()))
    (if (cluck-empty-seq? xs)
        (reverse acc)
        (loop (+ i 1)
              (cdr xs)
              (cons (f i (car xs)) acc)))))

(define (map-indexed f coll)
  (cond
    ((vector? coll) (cluck-map-indexed-vector f coll))
    (else (cluck-map-indexed-seq f coll))))

(define (cluck-keep-vector f vec)
  (let* ((len (vector-length vec)))
    (let loop ((i 0) (acc '()))
      (if (= i len)
          (reverse acc)
          (let ((value (f (vector-ref vec i))))
            (if (nil? value)
                (loop (+ i 1) acc)
                (loop (+ i 1) (cons value acc))))))))

(define (cluck-keep-seq f coll)
  (let loop ((xs (seq coll)) (acc '()))
    (if (cluck-empty-seq? xs)
        (reverse acc)
        (let ((value (f (car xs))))
          (if (nil? value)
              (loop (cdr xs) acc)
              (loop (cdr xs) (cons value acc)))))))

(define (keep f coll)
  (cond
    ((vector? coll) (cluck-keep-vector f coll))
    (else (cluck-keep-seq f coll))))

(define (remove pred coll)
  (filter (lambda (x) (if (pred x) #f #t)) coll))

(define (cluck-apply-tail x)
  (cond
    ((nil? x) '())
    ((pair? x) x)
    ((vector? x) (vector->list x))
    ((or (map? x) (set? x) (string? x)) (seq x))
    (else
     (error "apply expects a sequence as the last argument" x))))

(define (cluck-apply f . args)
  (cond
    ((null? args) (f))
    (else
     (let loop ((rest args) (prefix '()))
       (if (null? (cdr rest))
           (##sys#apply f (append (reverse prefix)
                                  (cluck-apply-tail (car rest))))
           (loop (cdr rest) (cons (car rest) prefix)))))))

(define apply cluck-apply)

(define (cluck-get-in coll ks . maybe-default)
  (let ((default (if (null? maybe-default) nil (car maybe-default))))
    (let loop ((current coll) (path (seq ks)))
      (if (cluck-empty-seq? path)
          current
          (let ((missing (list 'cluck-get-in-missing)))
            (let ((next (cluck-get current (car path) missing)))
              (if (eq? next missing)
                  default
                  (loop next (cdr path)))))))))

(define get-in cluck-get-in)

(define (cluck-assoc-in coll ks value)
  (let ((path (seq ks)))
    (if (cluck-empty-seq? path)
        value
        (let* ((key (car path))
               (rest (cdr path))
               (container (cond
                            ((map? coll) coll)
                            ((vector? coll) coll)
                            ((nil? coll) (hash-map))
                            (else
                             (error "assoc-in only supports maps and vectors" coll)))))
          (if (cluck-empty-seq? rest)
              (cluck-assoc container key value)
              (let* ((missing (list 'cluck-assoc-in-missing))
                     (child (cluck-get container key missing))
                     (next (if (eq? child missing) (hash-map) child)))
                (cluck-assoc container key
                             (cluck-assoc-in next rest value))))))))

(define assoc-in cluck-assoc-in)

(define (update coll key f . args)
  (cluck-assoc coll key (cluck-apply f (cons (cluck-get coll key nil) args))))

(define (select-keys m ks)
  (let ((result (hash-map)))
    (if (map? m)
        (let loop ((xs (seq ks)))
          (if (cluck-empty-seq? xs)
              result
              (begin
                (let ((k (car xs)))
                  (if (cluck-hash-exists? (map-hash m) k)
                      (cluck-hash-set! (map-hash result)
                                       k
                                       (cluck-hash-ref/default (map-hash m) k nil))
                      #f))
                (loop (cdr xs)))))
        result)))

(define (zipmap ks vs)
  (let ((result (hash-map)))
    (let loop ((keys (seq ks)) (vals (seq vs)))
      (if (or (cluck-empty-seq? keys) (cluck-empty-seq? vals))
          result
          (begin
            (cluck-hash-set! (map-hash result) (car keys) (car vals))
            (loop (cdr keys) (cdr vals)))))))

(define (mapcat f coll)
  (cluck-apply append
               (map (lambda (x)
                      (let ((value (f x)))
                        (if (nil? value)
                            '()
                            (seq value))))
                    coll)))

(define (partial f . args)
  (lambda rest
    (cluck-apply f (append args rest))))

(define (comp . fs)
  (cond
    ((null? fs)
     (lambda args
       (if (cluck-empty-seq? args)
           nil
           (car args))))
    ((null? (cdr fs))
     (car fs))
    (else
     (let ((rev (reverse fs)))
       (lambda args
         (let loop ((rest (cdr rev))
                    (result (cluck-apply (car rev) args)))
           (if (null? rest)
               result
               (let ((next (car rest)))
                 (loop (cdr rest) (next result))))))))))

(define (reduce f . args)
  (cond
    ((null? args)
     (error "reduce expects at least a collection"))
    ((null? (cdr args))
     (let ((coll (car args)))
       (cond
         ((vector? coll)
          (let ((len (vector-length coll)))
            (if (= len 0)
                (error "reduce of empty collection with no initial value")
                (let loop ((i 1) (acc (vector-ref coll 0)))
                  (if (= i len)
                      acc
                      (loop (+ i 1)
                            (f acc (vector-ref coll i))))))))
         (else
          (let ((xs (seq coll)))
            (if (cluck-empty-seq? xs)
                (error "reduce of empty collection with no initial value")
                (let loop ((acc (car xs)) (rest-xs (cdr xs)))
                  (if (cluck-empty-seq? rest-xs)
                      acc
                      (loop (f acc (car rest-xs)) (cdr rest-xs))))))))))
    (else
     (let ((init (car args))
           (coll (cadr args)))
       (cond
         ((vector? coll)
          (let ((len (vector-length coll)))
            (let loop ((i 0) (acc init))
              (if (= i len)
                  acc
                  (loop (+ i 1)
                        (f acc (vector-ref coll i)))))))
         (else
          (let loop ((acc init) (xs (seq coll)))
            (if (cluck-empty-seq? xs)
                acc
                (loop (f acc (car xs)) (cdr xs))))))))))

(define (some pred coll)
  (let loop ((xs (seq coll)))
    (if (cluck-empty-seq? xs)
        nil
        (let ((value (pred (car xs))))
          (if (truthy? value)
              value
              (loop (cdr xs)))))))

(define (every? pred coll)
  (let loop ((xs (seq coll)))
    (if (cluck-empty-seq? xs)
        #t
        (if (truthy? (pred (car xs)))
            (loop (cdr xs))
            #f))))

(define (identity x) x)

(define (inc x) (+ x 1))

(define (dec x) (- x 1))

(define (cluck-into-vector to from)
  (cond
    ((cluck-empty-seq? from) to)
    ((vector? from)
     (cluck-vector-append-vector to from))
    ((or (null? from) (pair? from))
     (cluck-vector-append-list to from))
    (else
     (cluck-vector-append-list to (seq from)))))

(define (into to from)
  (cond
    ((vector? to) (cluck-into-vector to from))
    (else
     (let loop ((xs (seq from)) (acc to))
       (if (cluck-empty-seq? xs)
           acc
           (loop (cdr xs) (conj acc (car xs))))))))

(define (not x)
  (if (truthy? x) #f #t))

(define (unspecified? x)
  (eq? x (void)))

(define (cluck-type-name x)
  (cond
    ((nil? x) 'nil)
    ((boolean? x) 'boolean)
    ((keyword? x) 'keyword)
    ((symbol? x) 'symbol)
    ((string? x) 'string)
    ((char? x) 'char)
    ((number? x)
     (cond
       ((exact-integer? x) 'integer)
       ((integer? x) 'integer)
       ((rational? x) 'rational)
       ((real? x) 'real)
       (else 'number)))
    ((vector? x) 'vector)
    ((pair? x) 'list)
    ((null? x) 'list)
    ((map? x) 'cluck.map)
    ((set? x) 'cluck.set)
    ((procedure? x) 'procedure)
    ((port? x) 'port)
    ((eof-object? x) 'eof-object)
    ((unspecified? x) 'void)
    (else 'unknown)))

(define (type x)
  (cluck-type-name x))

(define (vec coll)
  (if (vector? coll)
      coll
      (into [] coll)))

(define (load-file path)
  (cluck-load-source-file! path))

(define (cluck-core-public-bindings)
  (list
   (cons 'current-ns current-ns)
   (cons 'find-ns find-ns)
   (cons 'all-ns all-ns)
   (cons 'ns-publics ns-publics)
   (cons 'ns-resolve ns-resolve)
   (cons 'read-string cluck-core-read-string)
   (cons 'format format)
   (cons 'parse-long parse-long)
   (cons 'parse-double parse-double)
   (cons 'load-file load-file)
   (cons 'pr-str pr-str)
   (cons 'str str)
   (cons 'println println)
   (cons 'prn prn)
   (cons 'keyword keyword)
   (cons 'hash-map hash-map)
   (cons 'hash-set hash-set)
   (cons 'set set)
   (cons 'nil? nil?)
   (cons 'false? false?)
   (cons 'vector? vector?)
   (cons 'map? map?)
   (cons 'set? set?)
   (cons 'keyword? keyword?)
   (cons 'assoc cluck-assoc)
   (cons 'dissoc dissoc)
   (cons 'disj disj)
   (cons 'merge merge)
   (cons 'merge-with merge-with)
   (cons 'keys keys)
   (cons 'vals vals)
   (cons 'conj conj)
   (cons 'get cluck-get)
   (cons 'get-in get-in)
   (cons 'assoc-in assoc-in)
   (cons 'update update)
   (cons 'contains? cluck-contains?)
   (cons 'count count)
   (cons 'seq seq)
   (cons 'first first)
   (cons 'rest rest)
   (cons 'nth nth)
   (cons 'map map)
   (cons 'mapv mapv)
   (cons 'filter filter)
   (cons 'filterv filterv)
   (cons 'map-indexed map-indexed)
   (cons 'mapcat mapcat)
   (cons 'reduce reduce)
   (cons 'some some)
   (cons 'every? every?)
   (cons 'empty? empty?)
   (cons 'keep keep)
   (cons 'remove remove)
   (cons 'into into)
   (cons 'type type)
   (cons 'vec vec)
   (cons 'select-keys select-keys)
   (cons 'zipmap zipmap)
   (cons 'apply apply)
   (cons 'partial partial)
   (cons 'comp comp)
   (cons 'identity identity)
   (cons 'inc inc)
   (cons 'dec dec)
   (cons 'not not)
   (cons 'unspecified? unspecified?)))

(define (cluck-core-doc-specs)
  (list
   (cons 'current-ns "Return the active namespace symbol.")
   (cons 'find-ns "Return the namespace registry table for NS, or #f.")
   (cons 'all-ns "Return a list of known namespace symbols.")
   (cons 'ns-publics "Return a map of public vars in NS.")
   (cons 'ns-resolve "Resolve SYM in NS, checking public vars and imports.")
   (cons 'read-string "Read one Cluck form from STRING.")
   (cons 'format "Format TEMPLATE with %s, %d, %% and %.Nf directives.")
   (cons 'parse-long "Parse STRING as a long integer.")
   (cons 'parse-double "Parse STRING as an inexact number.")
   (cons 'load-file "Load FILE and resolve nested Cluck namespaces relative to its project root.")
   (cons 'pr-str "Render values as Cluck-readable text.")
   (cons 'str "Concatenate values as plain text.")
   (cons 'println "Print values as plain text with spaces and a trailing newline.")
   (cons 'prn "Print values with Cluck-readable rendering and a trailing newline.")
   (cons 'keyword "Create a keyword from a string or symbol.")
   (cons 'hash-map "Create a mutable map from key/value pairs.")
   (cons 'hash-set "Create a mutable set from items.")
   (cons 'set "Create a mutable set from items.")
   (cons 'nil? "Return true when x is nil.")
   (cons 'false? "Return true when x is false.")
   (cons 'vector? "Return true when x is a vector.")
   (cons 'map? "Return true when x is a Cluck map.")
   (cons 'set? "Return true when x is a Cluck set.")
   (cons 'keyword? "Return true when x is a keyword.")
   (cons 'assoc "Associate KEY with VALUE in MAP or VECTOR.")
   (cons 'dissoc "Remove KEY from MAP.")
   (cons 'disj "Remove items from a set.")
   (cons 'merge "Merge maps from left to right, with later values winning.")
   (cons 'merge-with "Merge maps from left to right, combining duplicates with F.")
   (cons 'keys "Return a list of keys from MAP.")
   (cons 'vals "Return a list of values from MAP.")
   (cons 'conj "Add one item to a collection.")
   (cons 'get "Look up KEY in MAP, SET, VECTOR, or sequence-backed collection.")
   (cons 'get-in "Look up a nested path in a map or vector.")
   (cons 'assoc-in "Associate VALUE at a nested path in a map or vector.")
   (cons 'update "Update KEY in COLL by applying F to the current value.")
   (cons 'contains? "Return true when MAP, SET, or VECTOR contains KEY.")
   (cons 'count "Return the number of items in COLL.")
   (cons 'seq "Return a simple sequence view of COLL.")
   (cons 'first "Return the first item in COLL.")
   (cons 'rest "Return the rest of COLL after the first item.")
   (cons 'nth "Return the item at index N in COLL.")
   (cons 'map "Apply F to each element of COLL and return a list of the results.")
   (cons 'mapv "Apply F to each element of COLL and return a vector.")
   (cons 'filter "Return the items of COLL for which PRED is truthy.")
   (cons 'filterv "Return the matching items of COLL in a vector.")
   (cons 'map-indexed "Apply F to each item in COLL with its index.")
   (cons 'mapcat "Map F across COLL and concatenate the resulting sequences.")
   (cons 'reduce "Reduce COLL with F, optionally starting from INIT.")
   (cons 'some "Return the first truthy result of applying PRED to COLL.")
   (cons 'every? "Return true when PRED is truthy for every item in COLL.")
   (cons 'empty? "Return true when COLL has no items.")
   (cons 'keep "Apply F to COLL and keep the non-nil results.")
   (cons 'remove "Return the items of COLL for which PRED is falsey.")
   (cons 'into "Add all items from FROM into TO.")
   (cons 'select-keys "Return a map containing only the requested keys.")
   (cons 'zipmap "Create a map by pairing keys and values from two collections.")
   (cons 'apply "Apply F to the supplied arguments, flattening the final sequence.")
   (cons 'partial "Return a function with some leading arguments fixed.")
   (cons 'comp "Compose functions from right to left.")
   (cons 'identity "Return x unchanged.")
   (cons 'inc "Add 1 to x.")
   (cons 'dec "Subtract 1 from x.")
   (cons 'not "Return the boolean negation of x.")
   (cons 'unspecified? "Return true when x is CHICKEN's unspecified value.")
   (cons 'type "Return a symbol describing the runtime type of x.")
   (cons 'vec "Return a vector containing the items of COLL.")
   (cons 'def "Define a var and intern it into the current namespace.")
   (cons 'defn "Define a named function and intern it into the current namespace.")
   (cons 'fn "Create an anonymous function.")
   (cons 'let "Bind names, vectors, or maps and evaluate the body.")
   (cons 'and "Evaluate forms left to right and return the last truthy value, or the first falsey value.")
   (cons 'or "Evaluate forms left to right and return the first truthy value, or false.")
   (cons 'comment "Ignore body forms and return the unspecified value.")
   (cons 'if "Evaluate THEN or ELSE based on Cluck truthiness.")
   (cons 'when "Evaluate BODY when TEST is truthy.")
   (cons 'when-not "Evaluate BODY when TEST is falsey.")
   (cons 'if-not "Evaluate ELSE when TEST is truthy, THEN otherwise.")
   (cons 'cond "Evaluate the first clause whose test is truthy, with :else as the final default clause.")
   (cons '-> "Thread x through forms as the second argument.")
   (cons '->> "Thread x through forms as the last argument.")
   (cons 'ns "Set the current namespace and optionally require dependencies.")
   (cons 'require "Load namespace files and import public vars.")
   (cons 'in-ns "Switch to a namespace without loading or importing.")
   (cons 'doc "Print the docstring for a symbol.")))

(define (cluck-install-core-docstrings!)
  (let loop ((xs (cluck-core-doc-specs)))
    (if (null? xs)
        (void)
        (begin
          (cluck-put-core-doc! (caar xs) (cdar xs))
          (loop (cdr xs))))))

(cluck-install-core-docstrings!)

(define (cluck-install-core-namespace!)
  (let ((ns 'cluck.core))
    (cluck-ensure-ns! ns)
    (cluck-reset-ns-imports! ns)
    (cluck-reset-ns-aliases! ns)
    (let loop ((xs (cluck-core-public-bindings)))
      (if (null? xs)
          (void)
          (begin
            (let ((pair (car xs)))
              (cluck-intern! ns (car pair) (cdr pair))
              (let ((doc (cluck-core-doc-for (car pair))))
                (if doc
                    (cluck-put-doc! ns (car pair) doc)
                    #f)))
            (loop (cdr xs)))))))

(cluck-install-core-namespace!)

(define (cluck-vector-form->list x)
  (cond
    ((vector? x) (vector->list x))
    ((and (pair? x) (eq? (car x) 'vector)) (cdr x))
    (else #f)))

(define (cluck-seq-drop x n)
  (let loop ((i 0) (xs (seq x)))
    (if (or (cluck-empty-seq? xs) (>= i n))
        xs
        (loop (+ i 1) (cdr xs)))))

(define (cluck-map-form->pairs x)
  (cond
    ((map? x)
     (let ((pairs '()))
       (hash-table-for-each
        (map-hash x)
        (lambda (k v)
          (set! pairs (cons (cons k v) pairs))))
       (reverse pairs)))
    ((and (pair? x) (eq? (car x) 'hash-map))
     (let loop ((xs (cdr x)) (acc '()))
       (cond
         ((null? xs) (reverse acc))
         ((null? (cdr xs))
          (error "map destructuring form must contain an even number of forms" x))
         (else
          (loop (cddr xs) (cons (cons (car xs) (cadr xs)) acc))))))
    (else #f)))

(define (cluck-alist-ref-pair key alist)
  (let loop ((xs alist))
    (cond
      ((or (null? xs) (not (pair? xs))) #f)
      ((and (pair? (car xs))
            (eq? (caar xs) key))
       (car xs))
      (else (loop (cdr xs))))))

(define (cluck-destructure-key-expr key)
  (let ((kw (cluck-keyword-form-name key)))
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

(define (cluck-destructure-defaults-alist defaults)
  (let ((pairs (cluck-map-form->pairs defaults)))
    (if pairs
        (let loop ((xs pairs) (acc '()))
          (if (null? xs)
              (reverse acc)
              (let* ((pair (car xs))
                     (key (car pair))
                     (sym (cond
                            ((symbol? key) key)
                            ((cluck-keyword-form-name key)
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

(define (cluck-destructure-symbol-binding sym source defaults)
  (let ((default (cluck-alist-ref-pair sym defaults)))
    (if default
        (let ((tmp (gensym "destruct")))
          (list (list sym
                      `(let ((,tmp ,source))
                         (if (nil? ,tmp) ,(cdr default) ,tmp)))))
        (list (list sym source)))))

(define (cluck-bindings-from-symbol-list syms key-expr-fn defaults)
  (let loop ((xs syms) (acc '()))
    (if (null? xs)
        (reverse acc)
        (let ((sym (car xs)))
          (loop (cdr xs)
                (cons (cluck-destructure-symbol-binding sym (key-expr-fn sym) defaults)
                      acc))))))

(define (cluck-destructure-vector-pattern form source defaults)
  (let ((items (cluck-vector-form->list form)))
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
               (let ((kw (cluck-keyword-form-name (car rest))))
                 (cond
                   ((and kw (string=? kw "as"))
                    (if as-binding
                        (error "duplicate :as in vector destructuring" form)
                        (if (null? (cdr rest))
                            (error ":as expects a symbol" form)
                            (let ((sym (cluck-ns-form->symbol (cadr rest))))
                              (loop (cddr rest) idx groups rest-binding sym seen-rest?)))))
                   (else
                    (error "only :as may follow & in vector destructuring" form)))))
              (else
               (let* ((item (car rest))
                      (kw (cluck-keyword-form-name item)))
                 (cond
                   ((and kw (string=? kw "as"))
                    (if as-binding
                        (error "duplicate :as in vector destructuring" form)
                        (if (null? (cdr rest))
                            (error ":as expects a symbol" form)
                            (let ((sym (cluck-ns-form->symbol (cadr rest))))
                              (loop (cddr rest) idx groups rest-binding sym seen-rest?)))))
                   ((eq? item '&)
                    (if rest-binding
                        (error "duplicate & in vector destructuring" form)
                        (if (null? (cdr rest))
                            (error "& expects a symbol" form)
                            (let ((sym (cluck-ns-form->symbol (cadr rest))))
                              (loop (cddr rest) idx groups sym as-binding #t)))))
                   (else
                    (loop (cdr rest)
                          (+ idx 1)
                          (cons (cluck-destructure-binding item `(nth ,tmp ,idx) defaults)
                                groups)
                          rest-binding as-binding seen-rest?))))))))
        (error "vector destructuring pattern must be a vector" form))))

(define (cluck-destructure-map-pattern form source defaults)
  (let ((pairs (cluck-map-form->pairs form)))
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
                                     (cluck-destructure-binding (car spec)
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
                       (kw (cluck-keyword-form-name key)))
                  (cond
                    ((and kw (string=? kw "as"))
                     (if as-binding
                         (error "duplicate :as in map destructuring" form)
                         (let ((sym (cluck-ns-form->symbol value)))
                           (loop (cdr rest) sym defaults specs))))
                    ((and kw (string=? kw "or"))
                     (let ((extra (cluck-destructure-defaults-alist value)))
                       (loop (cdr rest) as-binding (append extra defaults) specs)))
                    ((and kw (string=? kw "keys"))
                     (let ((syms (cluck-symbol-list-form->list value)))
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
                     (let ((syms (cluck-symbol-list-form->list value)))
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
                     (let ((syms (cluck-symbol-list-form->list value)))
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
                                               `(get ,tmp ,(cluck-destructure-key-expr key) nil)))))))))))
        (error "map destructuring pattern must be a map" form))))

(define (cluck-destructure-binding pattern source defaults)
  (let ((vector-items (cluck-vector-form->list pattern))
        (map-pairs (cluck-map-form->pairs pattern)))
    (cond
      ((symbol? pattern)
       (cluck-destructure-symbol-binding pattern source defaults))
      (vector-items
       (cluck-destructure-vector-pattern pattern source defaults))
      (map-pairs
       (cluck-destructure-map-pattern pattern source defaults))
      (else
       (error "unsupported destructuring pattern" pattern)))))

(define (cluck-parse-fn-arg pattern)
  (if (symbol? pattern)
      (cons pattern '())
      (let ((tmp (gensym "arg")))
        (cons tmp (cluck-destructure-binding pattern tmp '())))))

(define (cluck-build-dotted-args fixed tail)
  (let build ((rev fixed))
    (if (null? rev)
        tail
        (cons (car rev) (build (cdr rev))))))

(define (cluck-parse-fn-args args)
  (let ((xs (cluck-vector-form->list args)))
    (if xs
        (let loop ((rest xs) (params '()) (bindings '()) (tail #f))
          (cond
            ((null? rest)
             (cons (if tail
                       (cluck-build-dotted-args (reverse params) tail)
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
             (let* ((parsed (cluck-parse-fn-arg (car rest)))
                    (param (car parsed))
                    (more-bindings (cdr parsed)))
               (loop (cdr rest)
                     (cons param params)
                     (append bindings more-bindings)
                     tail)))))
        (error "fn expects an argument vector or arity clauses"))))

(define (cluck-wrap-body bindings body)
  (if (null? bindings)
      body
      (list `(let* ,bindings ,@body))))

(define (cluck-split-docstring parts)
  (if (and (pair? parts) (string? (car parts)))
      (cons (car parts) (cdr parts))
      (cons #f parts)))

(define (cluck-def-expansion name value doc)
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

(define (cluck-parse-let-bindings bindings)
  (let ((xs (cluck-vector-form->list bindings)))
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
                           (cluck-destructure-binding (car rest) (cadr rest) '()))))))
        (error "let bindings must be a vector"))))

(define (cluck-fn-clauses clauses)
  (let loop ((xs clauses) (acc '()))
    (if (null? xs)
        (reverse acc)
        (let ((clause (car xs)))
          (let ((args (and (pair? clause)
                           (cluck-vector-form->list (car clause)))))
            (if args
                (let* ((parsed (cluck-parse-fn-args (car clause)))
                       (params (car parsed))
                       (bindings (cdr parsed)))
                  (loop (cdr xs)
                        (cons (cons params (cluck-wrap-body bindings (cdr clause)))
                              acc)))
                (error "fn arity clauses must start with an argument vector")))))))

(define-syntax def
  (er-macro-transformer
   (lambda (form rename compare)
     (##core#let ((name (cadr form))
                  (rest (cddr form)))
       (##core#if (null? rest)
                  (error "def expects a value")
                  (##core#let ((doc-and-rest (cluck-split-docstring rest)))
                    (##core#let ((doc (car doc-and-rest))
                                 (value-rest (cdr doc-and-rest)))
                      (##core#if (null? value-rest)
                                 (error "def expects a value")
                                 (##core#let ((value (car value-rest)))
                                   (cluck-def-expansion name value doc))))))))))

(define-syntax fn
  (er-macro-transformer
   (lambda (form rename compare)
     (##core#let ((parts (cdr form)))
       (cond
         ((null? parts)
          (error "fn expects an argument vector or arity clauses"))
         ((cluck-vector-form->list (car parts))
          (let* ((parsed (cluck-parse-fn-args (car parts)))
                 (params (car parsed))
                 (bindings (cdr parsed)))
            `(lambda ,params
               ,@(cluck-wrap-body bindings (cdr parts)))))
         ((and (pair? (car parts))
               (cluck-vector-form->list (caar parts)))
          `(case-lambda
             ,@(map (lambda (clause)
                      (let* ((parsed (cluck-parse-fn-args (car clause)))
                             (params (car parsed))
                             (bindings (cdr parsed)))
                        (cons params (cluck-wrap-body bindings (cdr clause)))))
                    parts)))
         (else
          (error "fn expects an argument vector or arity clauses")))))))

(define-syntax defn
  (er-macro-transformer
   (lambda (form rename compare)
     (##core#let ((name (cadr form))
                  (body (cddr form)))
       (##core#let ((doc-and-body (cluck-split-docstring body)))
         (##core#let ((doc (car doc-and-body))
                      (fn-body (cdr doc-and-body)))
           (if doc
               `(def ,name ,doc (fn ,@fn-body))
               `(def ,name (fn ,@fn-body)))))))))

(define-syntax doc
  (er-macro-transformer
   (lambda (form rename compare)
     (##core#let ((parts (cdr form)))
       (##core#if (null? parts)
                  (error "doc expects a symbol")
                  (##core#let ((target (car parts)))
                    (cond
                      ((and (pair? target)
                            (eq? (car target) 'quote)
                            (pair? (cdr target))
                            (null? (cddr target)))
                       `(cluck-show-doc ',(cadr target)))
                      ((symbol? target)
                       `(cluck-show-doc ',target))
                      ((string? target)
                       `(cluck-show-doc ,target))
                      (else
                       (error "doc expects a symbol" target)))))))))

(define-syntax ns
  (er-macro-transformer
   (lambda (form rename compare)
     (##core#let ((parts (cdr form)))
       (##core#if (null? parts)
                  (error "ns expects a namespace name")
                  (##core#let ((name (cluck-ns-form->symbol (car parts)))
                               (rest (cdr parts)))
                    (cluck-set-current-ns! name)
                    (cluck-reset-ns-aliases! name)
                    (let loop ((xs rest)
                               (forms '())
                               (saw-docstring? #f)
                               (core-excludes '()))
                      (cond
                        ((null? xs)
                         `(begin
                            (cluck-set-current-ns! ',name)
                            (cluck-reset-ns-aliases! ',name)
                            (cluck-refer-core! ',(reverse core-excludes))
                            ,@forms))
                        ((string? (car xs))
                         (if saw-docstring?
                             (error "ns docstring must appear at most once" (car xs))
                             (if (null? forms)
                                 (loop (cdr xs) forms #t core-excludes)
                                 (error "ns docstring must come before directives"
                                        (car xs)))))
                        (else
                         (let ((directive (car xs)))
                           (let ((kw (cluck-keyword-form-name (car directive))))
                             (cond
                               ((and kw (string=? kw "refer-clojure"))
                                (loop (cdr xs)
                                      forms
                                      saw-docstring?
                                      (append core-excludes
                                              (cluck-refer-clojure-directive->exclude
                                               directive))))
                               (else
                                (loop (cdr xs)
                                      (append forms
                                              (cluck-ns-directive->forms directive))
                                      saw-docstring?
                                      core-excludes))))))))))))))

(define-syntax require
  (syntax-rules ()
    ((_ )
     (begin))
    ((_ spec ...)
     (begin
       (cluck-require-spec! 'spec)
       ...))))

(define-syntax in-ns
  (er-macro-transformer
   (lambda (form rename compare)
     (##core#let ((parts (cdr form)))
       (##core#if (null? parts)
                  (error "in-ns expects a namespace name")
                  (##core#let ((name (cluck-ns-form->symbol (car parts))))
                    (cluck-set-current-ns! name)
                    `(cluck-set-current-ns! ',name)))))))

(define (cluck-cond-else? x)
  (and (keyword? x) (string=? (name x) "else")))

(define (cluck-if-thunks test then-thunk else-thunk)
  (if (truthy? test)
      (then-thunk)
      (else-thunk)))

(define (cluck-inline-truthy-form test then else-part temp)
  `(##core#let ((,temp ,test))
     (cluck-if-thunks ,temp
                      (lambda () ,then)
                      (lambda () ,else-part))))

(define (cluck-expand-and clauses rename)
  (cond
    ((null? clauses) 'true)
    ((null? (cdr clauses)) (car clauses))
    (else
     (let ((temp (rename 'cluck-and-value)))
       `(##core#let ((,temp ,(car clauses)))
          (cluck-if-thunks ,temp
                           (lambda () ,(cluck-expand-and (cdr clauses) rename))
                           (lambda () ,temp)))))))

(define (cluck-expand-or clauses rename)
  (cond
    ((null? clauses) 'false)
    ((null? (cdr clauses)) (car clauses))
    (else
     (let ((temp (rename 'cluck-or-value)))
       `(##core#let ((,temp ,(car clauses)))
          (cluck-if-thunks ,temp
                           (lambda () ,temp)
                           (lambda () ,(cluck-expand-or (cdr clauses) rename))))))))

(define-syntax and
  (er-macro-transformer
   (lambda (form rename compare)
     (cluck-expand-and (cdr form) rename))))

(define-syntax or
  (er-macro-transformer
   (lambda (form rename compare)
     (cluck-expand-or (cdr form) rename))))

(define-syntax comment
  (er-macro-transformer
   (lambda (form rename compare)
     '(void))))

(define (cluck-expand-cond clauses rename)
  (let loop ((rest clauses))
    (cond
      ((null? rest) '(seq '()))
      ((null? (cdr rest))
       (error "cond expects test/expression pairs"))
      ((cluck-cond-else? (car rest))
       (if (null? (cddr rest))
           (cadr rest)
           (error "cond :else clause must be last")))
      (else
       (let ((tail (loop (cddr rest)))
             (value (rename 'cluck-cond-value)))
         `(cluck-if-thunks ,(car rest)
                           (lambda () ,(cadr rest))
                           (lambda () ,tail)))))))

(define-syntax if
  (er-macro-transformer
   (lambda (form rename compare)
     (##core#let ((test (cadr form))
                  (then (caddr form))
                  (else-part (##core#if (pair? (cdddr form)) (cadddr form) 'nil)))
       (cluck-inline-truthy-form test then else-part (rename 'cluck-if-value))))))

(define-syntax when
  (syntax-rules ()
    ((_ test body ...)
     (if test (##core#begin body ...) nil))))

(define-syntax when-not
  (syntax-rules ()
    ((_ test body ...)
     (if test nil (##core#begin body ...)))))

(define-syntax if-not
  (syntax-rules ()
    ((_ test then else)
     (if test else then))
    ((_ test then)
     (if test nil then))))

(define-syntax cond
  (er-macro-transformer
   (lambda (form rename compare)
     (cluck-expand-cond (cdr form) rename))))

(define (cluck-thread-first-step x step)
  (##core#if (pair? step)
             (cons (car step) (cons x (cdr step)))
             (list step x)))

(define (cluck-thread-last-step x step)
  (##core#if (pair? step)
             (append step (list x))
             (list step x)))

(define (cluck-thread-chain x steps stepper)
  (##core#if (null? steps)
             x
             (cluck-thread-chain (stepper x (car steps))
                                   (cdr steps)
                                   stepper)))

(define-syntax ->
  (er-macro-transformer
   (lambda (form rename compare)
     (cluck-thread-chain (cadr form)
                           (cddr form)
                           cluck-thread-first-step))))

(define-syntax ->>
  (er-macro-transformer
   (lambda (form rename compare)
     (cluck-thread-chain (cadr form)
                           (cddr form)
                           cluck-thread-last-step))))

(define (cluck-repl-print-results . results)
  (##core#if (null? results)
             (void)
             (##core#if (null? (cdr results))
                        (##core#let ((value (car results)))
                          (##core#if (eq? value (void))
                                     (void)
                                     (begin
                                       (display (pr-str value))
                                       (newline)
                                       (void))))
                        (begin
                          (display (pr-str results))
                          (newline)
                          (void)))))

(define (cluck-repl-evaluator expr)
  (call-with-values
   (lambda ()
     (cluck-eval-form expr))
   cluck-repl-print-results))

(define (cluck-repl)
  (repl-prompt (lambda () "cluck> "))
  (repl cluck-repl-evaluator))

(define-syntax let
  (er-macro-transformer
   (lambda (form rename compare)
     (##core#let ((bindings (cadr form))
                  (body (cddr form)))
       `(let* ,(cluck-parse-let-bindings bindings)
          ,@body)))))
