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

(define (Cluck-resolve-ns-table ns)
  (let ((direct (find-ns ns)))
    (if direct
        direct
        (let ((aliases (hash-table-ref/default *Cluck-ns-aliases*
                                                (current-ns)
                                                #f)))
          (if aliases
              (let ((target (hash-table-ref/default aliases ns #f)))
                (if target
                    (find-ns target)
                    #f))
              #f)))))

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
        (hash-table-ref/default table sym #f)
        #f)))

(define (Cluck-intern! ns sym value)
  (hash-table-set! (Cluck-ensure-ns! ns) sym value)
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

(define (Cluck-refer-selected! target-ns names)
  (let ((current (current-ns)))
    (let loop ((xs names))
      (if (null? xs)
          current
          (let ((sym (car xs)))
            (let ((value (ns-resolve target-ns sym)))
              (if value
                  (begin
                    (Cluck-intern! current sym value)
                    (loop (cdr xs)))
                  (error "cannot refer missing var" target-ns sym))))))))

(define (Cluck-refer-all! target-ns)
  (let ((table (find-ns target-ns)))
    (if table
        (let ((current (current-ns)))
          (hash-table-for-each
           table
           (lambda (sym value)
             (Cluck-intern! current sym value)))
          current)
        (error "cannot refer missing namespace" target-ns))))

(define (Cluck-require-vector-spec! spec)
  (let ((xs (Cluck-vector-form->list spec)))
    (if xs
        (let ((target (Cluck-ns-form->symbol (car xs))))
          (Cluck-require-namespace! target)
          (let loop ((rest (cdr xs)) (alias #f) (refs '()) (refer-all? #f))
            (cond
              ((null? rest)
               (if alias
                   (Cluck-register-ns-alias! (current-ns) alias target)
                   #f)
               (cond
                 (refer-all? (Cluck-refer-all! target))
                 ((null? refs) #f)
                 (else (Cluck-refer-selected! target refs)))
               target)
              ((let ((kw (Cluck-keyword-form-name (car rest))))
                 (and kw (string=? kw "as")))
               (if (null? (cdr rest))
                   (error "require :as expects an alias" spec)
                   (loop (cddr rest)
                         (Cluck-ns-form->symbol (cadr rest))
                         refs
                         refer-all?)))
              ((let ((kw (Cluck-keyword-form-name (car rest))))
                 (and kw (string=? kw "refer")))
               (if (null? (cdr rest))
                   (error "require :refer expects a symbol vector or :all" spec)
                   (let ((value (cadr rest)))
                     (cond
                       ((Cluck-all-marker? value)
                        (loop (cddr rest) alias refs #t))
                       (else
                        (let ((syms (Cluck-symbol-list-form->list value)))
                          (if syms
                              (loop (cddr rest) alias (append refs syms) refer-all?)
                              (error "require :refer expects a symbol vector or :all"
                                     value))))))))
              (else
               (error "unsupported require option" (car rest))))))
        (error "require spec must be a vector" spec))))

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

(define (Cluck-vector-form->list x)
  (cond
    ((vector? x) (vector->list x))
    ((and (pair? x) (eq? (car x) 'vector)) (cdr x))
    (else #f)))

(define (Cluck-parse-fn-args args)
  (let ((xs (Cluck-vector-form->list args)))
    (if xs
        (let loop ((rest xs) (fixed '()))
          (cond
            ((null? rest) (reverse fixed))
            ((eq? (car rest) '&)
             (if (null? (cddr rest))
                 (let ((tail (cadr rest)))
                   (let build ((rev fixed) (tail tail))
                     (if (null? rev)
                         tail
                         (build (cdr rev) (cons (car rev) tail)))))
                 (error "variadic fn/vector must end with & rest")))
            (else
             (loop (cdr rest) (cons (car rest) fixed)))))
        (error "fn expects an argument vector or arity clauses"))))

(define (Cluck-parse-let-bindings bindings)
  (let ((xs (Cluck-vector-form->list bindings)))
    (if xs
        (let loop ((rest xs) (acc '()))
          (cond
            ((null? rest) (reverse acc))
            ((eq? (car rest) '&)
             (error "let bindings do not support &"))
            ((null? (cdr rest))
             (error "let bindings must contain an even number of forms"))
            (else
             (loop (cddr rest)
                   (cons (list (car rest) (cadr rest)) acc)))))
        (error "let bindings must be a vector"))))

(define (Cluck-fn-clauses clauses)
  (let loop ((xs clauses) (acc '()))
    (if (null? xs)
        (reverse acc)
        (let ((clause (car xs)))
          (let ((args (and (pair? clause)
                           (Cluck-vector-form->list (car clause)))))
            (if args
              (loop (cdr xs)
                    (cons (list (Cluck-parse-fn-args (car clause))
                                (cdr clause))
                          acc))
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
          `(lambda ,(Cluck-parse-fn-args (car parts))
             ,@(cdr parts)))
         ((and (pair? (car parts))
               (Cluck-vector-form->list (caar parts)))
          `(case-lambda
             ,@(map (lambda (clause)
                      (list (Cluck-parse-fn-args (car clause))
                            (cdr clause)))
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
                    (let loop ((xs rest) (forms '()) (saw-docstring? #f))
                      (cond
                        ((null? xs)
                         `(begin
                            (Cluck-set-current-ns! ',name)
                            ,@forms))
                        ((string? (car xs))
                         (if saw-docstring?
                             (error "ns docstring must appear at most once" (car xs))
                             (if (null? forms)
                                 (loop (cdr xs) forms #t)
                                 (error "ns docstring must come before directives"
                                        (car xs)))))
                        (else
                         (loop (cdr xs)
                               (append forms
                                       (Cluck-ns-directive->forms (car xs)))
                               saw-docstring?))))))))))

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
