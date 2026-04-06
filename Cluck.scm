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

(load-relative "syntax-bootstrap.scm")

(define (Cluck-empty-seq? x)
  (or (nil? x) (null? x)))

(define (Cluck-insert-sorted x xs less?)
  (cond
    ((null? xs) (list x))
    ((less? x (car xs)) (cons x xs))
    (else (cons (car xs) (Cluck-insert-sorted x (cdr xs) less?)))))

(define (Cluck-sort-list xs less?)
  (let loop ((rest xs) (acc '()))
    (if (null? rest)
        acc
        (loop (cdr rest)
              (Cluck-insert-sorted (car rest) acc less?)))))

(define *ns* 'user)
(define *Cluck-ns-registry* (make-hash-table))
(define *Cluck-ns-imports* (make-hash-table))
(define *Cluck-loaded-namespaces* (make-hash-table))
(define *Cluck-loading-namespaces* (make-hash-table))
(define *Cluck-ns-aliases* (make-hash-table))

(define (Cluck-ensure-ns! ns)
  (let ((existing (hash-table-ref/default *Cluck-ns-registry* ns #f)))
    (if existing
        existing
        (let ((table (make-hash-table)))
          (hash-table-set! *Cluck-ns-registry* ns table)
          table))))

(define (Cluck-set-current-ns! ns)
  (if (symbol? ns)
      (begin
        (set! *ns* ns)
        (Cluck-ensure-ns! ns)
        ns)
      (error "ns expects a symbol" ns)))

(define (current-ns)
  *ns*)

(define (find-ns ns)
  (hash-table-ref/default *Cluck-ns-registry* ns #f))

(define (Cluck-ensure-ns-imports! ns)
  (let ((existing (hash-table-ref/default *Cluck-ns-imports* ns #f)))
    (if existing
        existing
        (let ((table (make-hash-table)))
          (hash-table-set! *Cluck-ns-imports* ns table)
          table))))

(define (Cluck-reset-ns-imports! ns)
  (let ((table (make-hash-table)))
    (hash-table-set! *Cluck-ns-imports* ns table)
    table))

(define (Cluck-reset-ns-aliases! ns)
  (let ((table (make-hash-table)))
    (hash-table-set! *Cluck-ns-aliases* ns table)
    table))

(define (Cluck-ensure-ns-aliases! ns)
  (let ((existing (hash-table-ref/default *Cluck-ns-aliases* ns #f)))
    (if existing
        existing
        (let ((table (make-hash-table)))
          (hash-table-set! *Cluck-ns-aliases* ns table)
          table))))

(define (Cluck-register-ns-alias! ns alias target)
  (hash-table-set! (Cluck-ensure-ns-aliases! ns) alias target)
  target)

(define (Cluck-resolved-ns-name ns)
  (let ((direct (find-ns ns)))
    (if direct
        ns
        (let ((aliases (hash-table-ref/default *Cluck-ns-aliases*
                                                (current-ns)
                                                #f)))
          (if aliases
              (let ((target (hash-table-ref/default aliases ns #f)))
                (if target
                    target
                    #f))
              #f)))))

(define (Cluck-resolve-ns-table ns)
  (let ((resolved (Cluck-resolved-ns-name ns)))
    (if resolved
        (find-ns resolved)
        #f)))

(define (Cluck-resolve-ns-imports-table ns)
  (let ((resolved (Cluck-resolved-ns-name ns)))
    (if resolved
        (hash-table-ref/default *Cluck-ns-imports* resolved #f)
        #f)))

(define (Cluck-ns-form->symbol form)
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
     *Cluck-ns-registry*
     (lambda (k v)
       (set! items (cons k items))))
    (reverse items)))

(define (ns-publics ns)
  (let ((table (Cluck-resolve-ns-table ns)))
    (if table
        (let ((m (Cluck-make-map)))
          (hash-table-for-each
           table
           (lambda (k v)
             (hash-table-set! (map-hash m) k v)))
          m)
        (Cluck-make-map))))

(define (ns-resolve ns sym)
  (let ((table (Cluck-resolve-ns-table ns)))
    (if table
        (let ((value (hash-table-ref/default table sym #f)))
          (if value
              value
              (let ((imports (Cluck-resolve-ns-imports-table ns)))
                (if imports
                    (hash-table-ref/default imports sym #f)
                    #f))))
        #f)))

(define (Cluck-intern! ns sym value)
  (hash-table-set! (Cluck-ensure-ns! ns) sym value)
  value)

(define (Cluck-import! ns sym value)
  (hash-table-set! (Cluck-ensure-ns-imports! ns) sym value)
  value)

(define (Cluck-namespace->path ns)
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

(define (Cluck-last-path-segment path)
  (let loop ((i (- (string-length path) 1)))
    (cond
      ((< i 0) path)
      ((char=? (string-ref path i) #\/)
       (substring path (+ i 1) (string-length path)))
      (else
       (loop (- i 1))))))

(define (Cluck-root-candidates root)
  (let prefix-loop ((prefixes '("" "src/")) (acc '()))
    (if (null? prefixes)
        (reverse acc)
        (let ((prefix (car prefixes)))
          (let suffix-loop ((suffixes '(".clj.scm" ".scm" ".clj")) (acc acc))
            (if (null? suffixes)
                (prefix-loop (cdr prefixes) acc)
                (suffix-loop (cdr suffixes)
                             (cons (string-append prefix root (car suffixes))
                                   acc))))))))

(define (Cluck-module-candidates ns)
  (let* ((path (Cluck-namespace->path ns))
         (base (Cluck-last-path-segment path))
         (roots (if (string=? path base)
                    (list path)
                    (list path base))))
    (let root-loop ((rs roots) (acc '()))
      (if (null? rs)
          (reverse acc)
          (root-loop (cdr rs)
                     (append (Cluck-root-candidates (car rs)) acc))))))

(define (Cluck-locate-module-file ns)
  (let loop ((xs (Cluck-module-candidates ns)))
    (cond
      ((null? xs) #f)
      ((file-exists? (car xs)) (car xs))
      (else (loop (cdr xs))))))

(define (Cluck-namespace-loaded? ns)
  (hash-table-exists? *Cluck-loaded-namespaces* ns))

(define (Cluck-namespace-loading? ns)
  (hash-table-exists? *Cluck-loading-namespaces* ns))

(define (Cluck-load-namespace-file! ns path)
  (let ((saved-ns (current-ns)))
    (hash-table-set! *Cluck-loading-namespaces* ns #t)
    (load path)
    (hash-table-delete! *Cluck-loading-namespaces* ns)
    (Cluck-set-current-ns! saved-ns)
    (hash-table-set! *Cluck-loaded-namespaces* ns path)
    ns))

(define (Cluck-require-namespace! ns)
  (cond
    ((Cluck-namespace-loaded? ns) ns)
    ((Cluck-namespace-loading? ns)
     (error "circular require detected" ns))
    (else
     (let ((path (Cluck-locate-module-file ns)))
       (if path
           (Cluck-load-namespace-file! ns path)
           (error "cannot locate namespace source file" ns))))))

(define (Cluck-symbol-list-form->list x)
  (cond
    ((vector? x) (vector->list x))
    ((and (pair? x) (eq? (car x) 'vector)) (cdr x))
    ((pair? x) x)
    ((symbol? x) (list x))
    ((string? x) (list (string->symbol x)))
    (else #f)))

(define (Cluck-keyword-form-name x)
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

(define (Cluck-all-marker? x)
  (let ((name (Cluck-keyword-form-name x)))
    (or (and name (string=? name "all"))
        (and (symbol? x) (string=? (symbol->string x) "all")))))

(define (Cluck-hash-table-keys table)
  (let ((items '()))
    (hash-table-for-each
     table
     (lambda (k v)
       (set! items (cons k items))))
    (reverse items)))

(define (Cluck-namespace-public-symbols ns)
  (let ((table (find-ns ns)))
    (if table
        (Cluck-hash-table-keys table)
        '())))

(define (Cluck-unique-symbols xs)
  (let loop ((rest xs) (acc '()))
    (if (null? rest)
        (reverse acc)
        (let ((sym (car rest)))
          (if (memq sym acc)
              (loop (cdr rest) acc)
              (loop (cdr rest) (cons sym acc)))))))

(define (Cluck-symbol-list-diff xs exclude)
  (let loop ((rest xs) (acc '()))
    (if (null? rest)
        (reverse acc)
        (let ((sym (car rest)))
          (if (memq sym exclude)
              (loop (cdr rest) acc)
              (loop (cdr rest) (cons sym acc)))))))

(define (Cluck-refer-core! exclude)
  (let ((current (current-ns)))
    (Cluck-reset-ns-imports! current)
    (let loop ((xs (Cluck-core-public-bindings)))
      (if (null? xs)
          current
          (let ((pair (car xs)))
            (if (memq (car pair) exclude)
                (loop (cdr xs))
                (begin
                  (Cluck-import! current (car pair) (cdr pair))
                  (loop (cdr xs)))))))))

(define (Cluck-refer-selected! target-ns names)
  (let ((current (current-ns)))
    (let loop ((xs names))
      (if (null? xs)
          current
          (let ((sym (car xs)))
            (let ((value (ns-resolve target-ns sym)))
              (if value
                  (begin
                    (Cluck-import! current sym value)
                    (loop (cdr xs)))
                  (error "cannot refer missing var" target-ns sym))))))))

(define (Cluck-refer-all! target-ns)
  (let ((table (find-ns target-ns)))
    (if table
        (let ((current (current-ns)))
          (hash-table-for-each
           table
           (lambda (sym value)
             (Cluck-import! current sym value)))
          current)
        (error "cannot refer missing namespace" target-ns))))

(define (Cluck-import-selected! target-ns names rename exclude)
  (let ((current (current-ns)))
    (let loop ((xs names))
      (if (null? xs)
          current
          (let ((source (car xs)))
            (if (memq source exclude)
                (loop (cdr xs))
                (let ((value (ns-resolve target-ns source)))
                  (if value
                      (let ((renamed (Cluck-alist-ref-pair source rename)))
                        (Cluck-import! current
                                       (if renamed (cdr renamed) source)
                                       value)
                        (loop (cdr xs)))
                      (error "cannot refer missing var" target-ns source)))))))))

(define (Cluck-require-vector-spec! spec)
  (##core#let ((xs (Cluck-vector-form->list spec)))
    (##core#if (not xs)
               (error "require spec must be a vector" spec)
               (##core#let ((target (Cluck-ns-form->symbol (car xs))))
                 (Cluck-require-namespace! target)
                 (##core#let loop ((rest (cdr xs))
                                   (alias #f)
                                   (refs '())
                                   (refer-all? #f)
                                   (exclude '())
                                   (rename '()))
                   (##core#if (or (null? rest) (not (pair? rest)))
                              (begin
                                (if alias
                                    (Cluck-register-ns-alias! (current-ns)
                                                               alias
                                                               target)
                                    #f)
                                (##core#let ((selected (if refer-all?
                                                           (Cluck-namespace-public-symbols target)
                                                           (Cluck-unique-symbols
                                                            (append refs (map car rename))))))
                                  (##core#let ((selected (Cluck-symbol-list-diff selected exclude)))
                                    (if (null? selected)
                                        target
                                        (Cluck-import-selected! target selected rename exclude))))
                                target)
                              (##core#let ((option (car rest))
                                            (kw (Cluck-keyword-form-name (car rest))))
                                (##core#if (and kw (string=? kw "as"))
                                           (if (null? (cdr rest))
                                               (error "require :as expects an alias" spec)
                                               (loop (cddr rest)
                                                     (Cluck-ns-form->symbol (cadr rest))
                                                     refs
                                                     refer-all?
                                                     exclude
                                                     rename))
                                           (##core#if (and kw (string=? kw "refer"))
                                                      (if (null? (cdr rest))
                                                          (error "require :refer expects a symbol vector or :all" spec)
                                                          (##core#let ((value (cadr rest)))
                                                            (if (Cluck-all-marker? value)
                                                                (loop (cddr rest)
                                                                      alias
                                                                      refs
                                                                      #t
                                                                      exclude
                                                                      rename)
                                                                (##core#let ((syms (Cluck-symbol-list-form->list value)))
                                                                  (if syms
                                                                      (loop (cddr rest)
                                                                            alias
                                                                            (append refs syms)
                                                                            refer-all?
                                                                            exclude
                                                                            rename)
                                                                      (error "require :refer expects a symbol vector or :all"
                                                                             value))))))
                                                      (##core#if (and kw (string=? kw "exclude"))
                                                                 (if (null? (cdr rest))
                                                                     (error "require :exclude expects a symbol vector or list" spec)
                                                                     (##core#let ((syms (Cluck-symbol-list-form->list (cadr rest))))
                                                                       (if syms
                                                                           (loop (cddr rest)
                                                                                 alias
                                                                                 refs
                                                                                 refer-all?
                                                                                 (append exclude syms)
                                                                                 rename)
                                                                           (error ":exclude expects a symbol vector or list"
                                                                                  (cadr rest))))))
                                                                 (error "unsupported require option" option))))))))))

(define (Cluck-require-spec! spec)
  (cond
    ((Cluck-vector-form->list spec) (Cluck-require-vector-spec! spec))
    ((symbol? spec) (Cluck-require-namespace! spec))
    ((string? spec) (Cluck-require-namespace! (string->symbol spec)))
    ((and (pair? spec)
          (eq? (car spec) 'quote)
          (pair? (cdr spec))
          (null? (cddr spec)))
     (Cluck-require-spec! (cadr spec)))
    (else
     (error "require expects a namespace symbol or vector spec" spec))))

(define (Cluck-refer-clojure-directive->exclude directive)
  (let loop ((rest (cdr directive)) (exclude '()))
    (cond
      ((null? rest) (reverse exclude))
      ((null? (cdr rest))
       (error "refer-clojure directive expects option/value pairs" directive))
      (else
       (let ((kw (Cluck-keyword-form-name (car rest))))
         (cond
           ((and kw (string=? kw "exclude"))
            (let ((syms (Cluck-symbol-list-form->list (cadr rest))))
              (if syms
                  (loop (cddr rest) (append syms exclude))
                  (error ":exclude expects a symbol vector or list" (cadr rest)))))
           (else
            (error "unsupported refer-clojure option" (car rest)))))))))

(define (Cluck-ns-directive->forms directive)
  (cond
    ((and (pair? directive)
          (let ((kw (Cluck-keyword-form-name (car directive))))
            (and kw (string=? kw "require"))))
     (map (lambda (spec)
            `(Cluck-require-spec! ',spec))
          (cdr directive)))
    (else
     (error "ns directives are not yet supported" directive))))

(define (Cluck-collect-hash-pairs table)
  (let ((pairs '()))
    (hash-table-for-each
     table
     (lambda (k v)
       (set! pairs (cons (cons k v) pairs))))
    pairs))

(define (Cluck-map-items m)
  (let ((items '()))
    (hash-table-for-each
     (map-hash m)
     (lambda (k v)
       (set! items (cons (vector k v) items))))
    items))

(define (Cluck-set-items s)
  (let ((items '()))
    (hash-table-for-each
     (set-hash s)
     (lambda (k v)
       (set! items (cons k items))))
    items))

(define (Cluck-sorted-map-pairs m)
  (Cluck-sort-list
   (Cluck-collect-hash-pairs (map-hash m))
   (lambda (a b)
     (string<? (pr-str (car a))
               (pr-str (car b))))))

(define (Cluck-sorted-set-items s)
  (Cluck-sort-list
   (let ((items '()))
     (hash-table-for-each
      (set-hash s)
      (lambda (k v)
        (set! items (cons k items))))
     items)
   (lambda (a b)
     (string<? (pr-str a)
               (pr-str b)))))

(define (Cluck-map-entry->vector pair)
  (vector (car pair) (cdr pair)))

(define (Cluck-vector-append-list vec items)
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

(define (Cluck-vector-append-vector vec items)
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

(define (Cluck-vector-append vec items)
  (Cluck-vector-append-list vec items))

(define (Cluck-vector-assoc vec idx value)
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

(define (Cluck-seq-list x)
  (cond
    ((Cluck-empty-seq? x) nil)
    ((null? x) nil)
    ((pair? x) x)
    ((map? x)
     (let ((items (Cluck-map-items x)))
       (if (null? items) nil items)))
    ((set? x)
     (let ((items (Cluck-set-items x)))
       (if (null? items) nil items)))
    ((vector? x)
     (let ((items (vector->list x)))
       (if (null? items) nil items)))
    ((string? x)
     (let ((items (string->list x)))
       (if (null? items) nil items)))
    (else nil)))

(define (Cluck-write-pr x port)
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
     (let loop ((pairs (Cluck-sorted-map-pairs x)) (first? #t))
       (if (null? pairs)
           (display "}" port)
           (begin
             (if (not first?) (write-char #\space port))
             (Cluck-write-pr (caar pairs) port)
             (write-char #\space port)
             (Cluck-write-pr (cdar pairs) port)
             (loop (cdr pairs) #f)))))
    ((set? x)
     (display "#{" port)
     (let loop ((items (Cluck-sorted-set-items x)) (first? #t))
       (if (null? items)
           (display "}" port)
           (begin
             (if (not first?) (write-char #\space port))
             (Cluck-write-pr (car items) port)
             (loop (cdr items) #f)))))
    ((vector? x)
     (display "[" port)
     (let loop ((i 0))
       (if (= i (vector-length x))
           (display "]" port)
           (begin
             (if (> i 0) (write-char #\space port))
             (Cluck-write-pr (vector-ref x i) port)
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
          (Cluck-write-pr (car xs) port)
          (loop (cdr xs) #f))
         (else
          (display " . " port)
          (Cluck-write-pr xs port)
          (display ")" port)))))
    (else
     (write x port))))

(set-record-printer! Cluck-keyword
  (lambda (kw out)
    (Cluck-write-pr kw out)))

(set-record-printer! Cluck-map
  (lambda (m out)
    (Cluck-write-pr m out)))

(set-record-printer! Cluck-set
  (lambda (s out)
    (Cluck-write-pr s out)))

(define (pr-str . xs)
  (let ((p (open-output-string)))
    (let loop ((items xs) (first? #t))
      (if (null? items)
          (get-output-string p)
          (begin
            (if (not first?) (write-char #\space p))
            (Cluck-write-pr (car items) p)
            (loop (cdr items) #f))))))

(define (Cluck-str-piece x)
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
            (display (Cluck-str-piece (car items)) p)
            (loop (cdr items)))))))

(define (println . xs)
  (display (apply pr-str xs))
  (newline)
  nil)

(define prn println)

(define (read-string s)
  (Cluck-read-one s))

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
  (= (count x) 0))

(define (seq x)
  (Cluck-seq-list x))

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

(define (Cluck-hash-ref/default table key default)
  (hash-table-ref/default table key default))

(define (Cluck-hash-exists? table key)
  (hash-table-exists? table key))

(define (Cluck-hash-set! table key value)
  (hash-table-set! table key value))

(define (Cluck-hash-delete! table key)
  (hash-table-delete! table key))

(define (Cluck-get coll key . maybe-default)
  (let ((default (if (null? maybe-default) nil (car maybe-default))))
    (cond
      ((map? coll)
       (Cluck-hash-ref/default (map-hash coll) key default))
      ((set? coll)
       (if (Cluck-hash-exists? (set-hash coll) key) key default))
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
       (Cluck-get c k)))
    ((_ coll key default)
     (##core#let ((c coll)
                  (k key)
                  (d default))
       (Cluck-get c k d)))))

(define (Cluck-contains? coll key)
  (cond
    ((map? coll) (Cluck-hash-exists? (map-hash coll) key))
    ((set? coll) (Cluck-hash-exists? (set-hash coll) key))
    ((vector? coll)
     (and (integer? key) (>= key 0) (< key (vector-length coll))))
    (else #f)))

(define-syntax contains?
  (syntax-rules ()
    ((_ coll key)
     (##core#let ((c coll)
                  (k key))
       (Cluck-contains? c k)))))

(define (Cluck-map-entry? x)
  (or (and (vector? x) (= (vector-length x) 2))
      (and (pair? x) (pair? (cdr x)) (null? (cddr x)))))

(define (Cluck-map-entry-key x)
  (if (vector? x) (vector-ref x 0) (car x)))

(define (Cluck-map-entry-val x)
  (if (vector? x) (vector-ref x 1) (cadr x)))

(define (Cluck-assoc coll . kvs)
  (cond
    ((map? coll)
     (let loop ((xs kvs))
       (cond
         ((null? xs) coll)
         ((null? (cdr xs)) (error "assoc expects key/value pairs"))
         (else
          (Cluck-hash-set! (map-hash coll) (car xs) (cadr xs))
          (loop (cddr xs))))))
    ((vector? coll)
     (let loop ((xs kvs) (out coll))
       (cond
         ((null? xs) out)
         ((null? (cdr xs)) (error "assoc expects index/value pairs"))
         (else
          (let ((idx (car xs))
                (value (cadr xs)))
            (set! out (Cluck-vector-assoc out idx value))
            (loop (cddr xs) out))))))
    (else
     (error "assoc only supports maps and vectors"))))

(define-syntax assoc
  (syntax-rules ()
    ((_ coll)
     (Cluck-assoc coll))
    ((_ coll key val)
     (##core#let ((c coll)
                  (k key)
                  (v val))
       (Cluck-assoc c k v)))
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
             (Cluck-hash-delete! (map-hash coll) (car xs))
             (loop (cdr xs))))))
    ((set? coll)
     (let loop ((xs keys))
       (if (null? xs)
           coll
           (begin
             (Cluck-hash-delete! (set-hash coll) (car xs))
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
                   (Cluck-hash-set! (map-hash result) k v))))
            (loop (cdr xs)))))))

(define (Cluck-conj-map! m item)
  (cond
    ((map? item)
     (hash-table-for-each
      (map-hash item)
      (lambda (k v)
        (Cluck-hash-set! (map-hash m) k v)))
     m)
    ((Cluck-map-entry? item)
     (Cluck-hash-set! (map-hash m)
                        (Cluck-map-entry-key item)
                        (Cluck-map-entry-val item))
     m)
    (else
     (error "conj expects map entries or maps when target is a map" item))))

(define (conj coll . items)
  (cond
    ((map? coll)
     (let loop ((xs items) (acc coll))
       (if (null? xs)
           acc
           (loop (cdr xs) (Cluck-conj-map! acc (car xs))))))
    ((set? coll)
     (let loop ((xs items) (acc coll))
       (if (null? xs)
           acc
           (begin
             (Cluck-hash-set! (set-hash acc) (car xs) #t)
             (loop (cdr xs) acc)))))
    ((vector? coll)
     (Cluck-vector-append coll items))
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
             (Cluck-hash-delete! (set-hash coll) (car xs))
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
    (if (Cluck-empty-seq? xs)
        (reverse acc)
        (loop (cdr xs) (cons (f (car xs)) acc)))))

(define (Cluck-mapv-vector f vec)
  (let* ((len (vector-length vec))
         (out (make-vector len)))
    (let loop ((i 0))
      (if (= i len)
          out
          (begin
            (vector-set! out i (f (vector-ref vec i)))
            (loop (+ i 1)))))))

(define (Cluck-filterv-vector pred vec)
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
    ((vector? coll) (Cluck-mapv-vector f coll))
    (else (list->vector (map f (seq coll))))))

(define (filter pred coll)
  (let loop ((xs (seq coll)) (acc '()))
    (if (Cluck-empty-seq? xs)
        (reverse acc)
        (let ((item (car xs)))
          (if (pred item)
              (loop (cdr xs) (cons item acc))
              (loop (cdr xs) acc))))))

(define (filterv pred coll)
  (cond
    ((vector? coll) (Cluck-filterv-vector pred coll))
    (else (list->vector (filter pred (seq coll))))))

(define (remove pred coll)
  (filter (lambda (x) (if (pred x) #f #t)) coll))

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
            (if (Cluck-empty-seq? xs)
                (error "reduce of empty collection with no initial value")
                (let loop ((acc (car xs)) (rest-xs (cdr xs)))
                  (if (Cluck-empty-seq? rest-xs)
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
            (if (Cluck-empty-seq? xs)
                acc
                (loop (f acc (car xs)) (cdr xs))))))))))

(define (some pred coll)
  (let loop ((xs (seq coll)))
    (if (Cluck-empty-seq? xs)
        nil
        (let ((value (pred (car xs))))
          (if (truthy? value)
              value
              (loop (cdr xs)))))))

(define (every? pred coll)
  (let loop ((xs (seq coll)))
    (if (Cluck-empty-seq? xs)
        #t
        (if (truthy? (pred (car xs)))
            (loop (cdr xs))
            #f))))

(define (identity x) x)

(define (inc x) (+ x 1))

(define (dec x) (- x 1))

(define (Cluck-into-vector to from)
  (cond
    ((vector? from)
     (Cluck-vector-append-vector to from))
    ((or (null? from) (pair? from))
     (Cluck-vector-append-list to from))
    (else
     (Cluck-vector-append-list to (seq from)))))

(define (into to from)
  (cond
    ((vector? to) (Cluck-into-vector to from))
    (else
     (let loop ((xs (seq from)) (acc to))
       (if (Cluck-empty-seq? xs)
           acc
           (loop (cdr xs) (conj acc (car xs))))))))

(define (not x)
  (if (truthy? x) #f #t))

(define (Cluck-core-public-bindings)
  (list
   (cons 'current-ns current-ns)
   (cons 'find-ns find-ns)
   (cons 'all-ns all-ns)
   (cons 'ns-publics ns-publics)
   (cons 'ns-resolve ns-resolve)
   (cons 'read-string read-string)
   (cons 'pr-str pr-str)
   (cons 'str str)
   (cons 'println println)
   (cons 'prn prn)
   (cons 'keyword keyword)
   (cons 'nil? nil?)
   (cons 'false? false?)
   (cons 'vector? vector?)
   (cons 'map? map?)
   (cons 'set? set?)
   (cons 'keyword? keyword?)
   (cons 'assoc Cluck-assoc)
   (cons 'dissoc dissoc)
   (cons 'conj conj)
   (cons 'get Cluck-get)
   (cons 'contains? Cluck-contains?)
   (cons 'count count)
   (cons 'seq seq)
   (cons 'first first)
   (cons 'rest rest)
   (cons 'nth nth)
   (cons 'map map)
   (cons 'mapv mapv)
   (cons 'filter filter)
   (cons 'filterv filterv)
   (cons 'reduce reduce)
   (cons 'some some)
   (cons 'every? every?)
   (cons 'empty? empty?)
   (cons 'into into)
   (cons 'identity identity)
   (cons 'inc inc)
   (cons 'dec dec)
   (cons 'not not)))

(define (Cluck-vector-form->list x)
  (cond
    ((vector? x) (vector->list x))
    ((and (pair? x) (eq? (car x) 'vector)) (cdr x))
    (else #f)))

(define (Cluck-seq-drop x n)
  (let loop ((i 0) (xs (seq x)))
    (if (or (Cluck-empty-seq? xs) (>= i n))
        xs
        (loop (+ i 1) (cdr xs)))))

(define (Cluck-map-form->pairs x)
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

(define (Cluck-alist-ref-pair key alist)
  (let loop ((xs alist))
    (cond
      ((or (null? xs) (not (pair? xs))) #f)
      ((and (pair? (car xs))
            (eq? (caar xs) key))
       (car xs))
      (else (loop (cdr xs))))))

(define (Cluck-destructure-key-expr key)
  (let ((kw (Cluck-keyword-form-name key)))
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

(define (Cluck-destructure-defaults-alist defaults)
  (let ((pairs (Cluck-map-form->pairs defaults)))
    (if pairs
        (let loop ((xs pairs) (acc '()))
          (if (null? xs)
              (reverse acc)
              (let* ((pair (car xs))
                     (key (car pair))
                     (sym (cond
                            ((symbol? key) key)
                            ((Cluck-keyword-form-name key)
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

(define (Cluck-destructure-symbol-binding sym source defaults)
  (let ((default (Cluck-alist-ref-pair sym defaults)))
    (if default
        (let ((tmp (gensym "destruct")))
          (list (list sym
                      `(let ((,tmp ,source))
                         (if (nil? ,tmp) ,(cdr default) ,tmp)))))
        (list (list sym source)))))

(define (Cluck-bindings-from-symbol-list syms key-expr-fn defaults)
  (let loop ((xs syms) (acc '()))
    (if (null? xs)
        (reverse acc)
        (let ((sym (car xs)))
          (loop (cdr xs)
                (cons (Cluck-destructure-symbol-binding sym (key-expr-fn sym) defaults)
                      acc))))))

(define (Cluck-destructure-vector-pattern form source defaults)
  (let ((items (Cluck-vector-form->list form)))
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
                             (list (list rest-binding `(Cluck-seq-drop ,tmp ,idx)))
                             '()))))
              (seen-rest?
               (let ((kw (Cluck-keyword-form-name (car rest))))
                 (cond
                   ((and kw (string=? kw "as"))
                    (if as-binding
                        (error "duplicate :as in vector destructuring" form)
                        (if (null? (cdr rest))
                            (error ":as expects a symbol" form)
                            (let ((sym (Cluck-ns-form->symbol (cadr rest))))
                              (loop (cddr rest) idx groups rest-binding sym seen-rest?)))))
                   (else
                    (error "only :as may follow & in vector destructuring" form)))))
              (else
               (let* ((item (car rest))
                      (kw (Cluck-keyword-form-name item)))
                 (cond
                   ((and kw (string=? kw "as"))
                    (if as-binding
                        (error "duplicate :as in vector destructuring" form)
                        (if (null? (cdr rest))
                            (error ":as expects a symbol" form)
                            (let ((sym (Cluck-ns-form->symbol (cadr rest))))
                              (loop (cddr rest) idx groups rest-binding sym seen-rest?)))))
                   ((eq? item '&)
                    (if rest-binding
                        (error "duplicate & in vector destructuring" form)
                        (if (null? (cdr rest))
                            (error "& expects a symbol" form)
                            (let ((sym (Cluck-ns-form->symbol (cadr rest))))
                              (loop (cddr rest) idx groups sym as-binding #t)))))
                   (else
                    (loop (cdr rest)
                          (+ idx 1)
                          (cons (Cluck-destructure-binding item `(nth ,tmp ,idx) defaults)
                                groups)
                          rest-binding as-binding seen-rest?))))))))
        (error "vector destructuring pattern must be a vector" form))))

(define (Cluck-destructure-map-pattern form source defaults)
  (let ((pairs (Cluck-map-form->pairs form)))
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
                                     (Cluck-destructure-binding (car spec)
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
                       (kw (Cluck-keyword-form-name key)))
                  (cond
                    ((and kw (string=? kw "as"))
                     (if as-binding
                         (error "duplicate :as in map destructuring" form)
                         (let ((sym (Cluck-ns-form->symbol value)))
                           (loop (cdr rest) sym defaults specs))))
                    ((and kw (string=? kw "or"))
                     (let ((extra (Cluck-destructure-defaults-alist value)))
                       (loop (cdr rest) as-binding (append extra defaults) specs)))
                    ((and kw (string=? kw "keys"))
                     (let ((syms (Cluck-symbol-list-form->list value)))
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
                     (let ((syms (Cluck-symbol-list-form->list value)))
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
                     (let ((syms (Cluck-symbol-list-form->list value)))
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
                                               `(get ,tmp ,(Cluck-destructure-key-expr key) nil)))))))))))
        (error "map destructuring pattern must be a map" form))))

(define (Cluck-destructure-binding pattern source defaults)
  (let ((vector-items (Cluck-vector-form->list pattern))
        (map-pairs (Cluck-map-form->pairs pattern)))
    (cond
      ((symbol? pattern)
       (Cluck-destructure-symbol-binding pattern source defaults))
      (vector-items
       (Cluck-destructure-vector-pattern pattern source defaults))
      (map-pairs
       (Cluck-destructure-map-pattern pattern source defaults))
      (else
       (error "unsupported destructuring pattern" pattern)))))

(define (Cluck-parse-fn-arg pattern)
  (if (symbol? pattern)
      (cons pattern '())
      (let ((tmp (gensym "arg")))
        (cons tmp (Cluck-destructure-binding pattern tmp '())))))

(define (Cluck-build-dotted-args fixed tail)
  (let build ((rev fixed))
    (if (null? rev)
        tail
        (cons (car rev) (build (cdr rev))))))

(define (Cluck-parse-fn-args args)
  (let ((xs (Cluck-vector-form->list args)))
    (if xs
        (let loop ((rest xs) (params '()) (bindings '()) (tail #f))
          (cond
            ((null? rest)
             (cons (if tail
                       (Cluck-build-dotted-args (reverse params) tail)
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
             (let* ((parsed (Cluck-parse-fn-arg (car rest)))
                    (param (car parsed))
                    (more-bindings (cdr parsed)))
               (loop (cdr rest)
                     (cons param params)
                     (append bindings more-bindings)
                     tail)))))
        (error "fn expects an argument vector or arity clauses"))))

(define (Cluck-wrap-body bindings body)
  (if (null? bindings)
      body
      (list `(let* ,bindings ,@body))))

(define (Cluck-parse-let-bindings bindings)
  (let ((xs (Cluck-vector-form->list bindings)))
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
                           (Cluck-destructure-binding (car rest) (cadr rest) '()))))))
        (error "let bindings must be a vector"))))

(define (Cluck-fn-clauses clauses)
  (let loop ((xs clauses) (acc '()))
    (if (null? xs)
        (reverse acc)
        (let ((clause (car xs)))
          (let ((args (and (pair? clause)
                           (Cluck-vector-form->list (car clause)))))
            (if args
                (let* ((parsed (Cluck-parse-fn-args (car clause)))
                       (params (car parsed))
                       (bindings (cdr parsed)))
                  (loop (cdr xs)
                        (cons (cons params (Cluck-wrap-body bindings (cdr clause)))
                              acc)))
                (error "fn arity clauses must start with an argument vector")))))))

(define-syntax def
  (er-macro-transformer
   (lambda (form rename compare)
     (##core#let ((name (cadr form))
                  (value (caddr form)))
       `(begin
          (define ,name ,value)
          (Cluck-intern! (current-ns) ',name ,name))))))

(define-syntax fn
  (er-macro-transformer
   (lambda (form rename compare)
     (##core#let ((parts (cdr form)))
       (cond
         ((null? parts)
          (error "fn expects an argument vector or arity clauses"))
         ((Cluck-vector-form->list (car parts))
          (let* ((parsed (Cluck-parse-fn-args (car parts)))
                 (params (car parsed))
                 (bindings (cdr parsed)))
            `(lambda ,params
               ,@(Cluck-wrap-body bindings (cdr parts)))))
         ((and (pair? (car parts))
               (Cluck-vector-form->list (caar parts)))
          `(case-lambda
             ,@(map (lambda (clause)
                      (let* ((parsed (Cluck-parse-fn-args (car clause)))
                             (params (car parsed))
                             (bindings (cdr parsed)))
                        (cons params (Cluck-wrap-body bindings (cdr clause)))))
                    parts)))
         (else
          (error "fn expects an argument vector or arity clauses")))))))

(define-syntax defn
  (er-macro-transformer
   (lambda (form rename compare)
     (##core#let ((name (cadr form))
                  (body (cddr form)))
       (##core#if (and (pair? body) (string? (car body)))
           `(def ,name (fn ,@(cdr body)))
           `(def ,name (fn ,@body)))))))

(define-syntax ns
  (er-macro-transformer
   (lambda (form rename compare)
     (##core#let ((parts (cdr form)))
       (##core#if (null? parts)
                  (error "ns expects a namespace name")
                  (##core#let ((name (Cluck-ns-form->symbol (car parts)))
                               (rest (cdr parts)))
                    (Cluck-set-current-ns! name)
                    (Cluck-reset-ns-aliases! name)
                    (let loop ((xs rest)
                               (forms '())
                               (saw-docstring? #f)
                               (core-excludes '()))
                      (cond
                        ((null? xs)
                         `(begin
                            (Cluck-set-current-ns! ',name)
                            (Cluck-reset-ns-aliases! ',name)
                            (Cluck-refer-core! ',(reverse core-excludes))
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
                           (let ((kw (Cluck-keyword-form-name (car directive))))
                             (cond
                               ((and kw (string=? kw "refer-clojure"))
                                (loop (cdr xs)
                                      forms
                                      saw-docstring?
                                      (append core-excludes
                                              (Cluck-refer-clojure-directive->exclude
                                               directive))))
                               (else
                                (loop (cdr xs)
                                      (append forms
                                              (Cluck-ns-directive->forms directive))
                                      saw-docstring?
                                      core-excludes))))))))))))))

(define-syntax require
  (syntax-rules ()
    ((_ )
     (begin))
    ((_ spec ...)
     (begin
       (Cluck-require-spec! 'spec)
       ...))))

(define-syntax in-ns
  (er-macro-transformer
   (lambda (form rename compare)
     (##core#let ((parts (cdr form)))
       (##core#if (null? parts)
                  (error "in-ns expects a namespace name")
                  (##core#let ((name (Cluck-ns-form->symbol (car parts))))
                    (Cluck-set-current-ns! name)
                    `(Cluck-set-current-ns! ',name)))))))

(define (Cluck-cond-else? x)
  (or (and (symbol? x) (string=? (symbol->string x) "else"))
      (and (keyword? x) (string=? (name x) "else"))))

(define (Cluck-inline-truthy-form test then else-part temp)
  `(##core#let ((,temp ,test))
     (##core#if (eq? ,temp false)
                ,else-part
                (##core#if (eq? ,temp nil)
                           ,else-part
                           ,then))))

(define (Cluck-expand-cond clauses rename)
  (let loop ((rest clauses))
    (cond
      ((null? rest) 'nil)
      ((null? (cdr rest))
       (error "cond expects test/expression pairs"))
      ((Cluck-cond-else? (car rest))
       (if (null? (cddr rest))
           (cadr rest)
           (error "cond else clause must be last")))
      (else
       (let ((tail (loop (cddr rest)))
             (value (rename 'Cluck-cond-value)))
         `(##core#let ((,value ,(car rest)))
            (##core#if (eq? ,value false)
                       ,tail
                       (##core#if (eq? ,value nil)
                                  ,tail
                                  ,(cadr rest)))))))))

(define-syntax if
  (er-macro-transformer
   (lambda (form rename compare)
     (##core#let ((test (cadr form))
                  (then (caddr form))
                  (else-part (##core#if (pair? (cdddr form)) (cadddr form) 'nil)))
       (Cluck-inline-truthy-form test then else-part (rename 'Cluck-if-value))))))

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
     (Cluck-expand-cond (cdr form) rename))))

(define (Cluck-thread-first-step x step)
  (##core#if (pair? step)
             (cons (car step) (cons x (cdr step)))
             (list step x)))

(define (Cluck-thread-last-step x step)
  (##core#if (pair? step)
             (append step (list x))
             (list step x)))

(define (Cluck-thread-chain x steps stepper)
  (##core#if (null? steps)
             x
             (Cluck-thread-chain (stepper x (car steps))
                                   (cdr steps)
                                   stepper)))

(define-syntax ->
  (er-macro-transformer
   (lambda (form rename compare)
     (Cluck-thread-chain (cadr form)
                           (cddr form)
                           Cluck-thread-first-step))))

(define-syntax ->>
  (er-macro-transformer
   (lambda (form rename compare)
     (Cluck-thread-chain (cadr form)
                           (cddr form)
                           Cluck-thread-last-step))))

(define (Cluck-repl-print-results . results)
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

(define (Cluck-repl-evaluator expr)
  (call-with-values
   (lambda ()
     (default-evaluator expr))
   Cluck-repl-print-results))

(define (Cluck-repl)
  (repl-prompt (lambda () "Cluck> "))
  (repl Cluck-repl-evaluator))

(define-syntax let
  (er-macro-transformer
   (lambda (form rename compare)
     (##core#let ((bindings (cadr form))
                  (body (cddr form)))
       `(let* ,(Cluck-parse-let-bindings bindings)
          ,@body)))))
