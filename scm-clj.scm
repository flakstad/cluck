(import (except scheme assoc)
        (chicken base)
        (chicken csi)
        (chicken load)
        (chicken port)
        (chicken repl)
        (chicken syntax)
        srfi-69)

(load-relative "syntax-bootstrap.scm")

(define (scm-clj-empty-seq? x)
  (or (nil? x) (null? x)))

(define (scm-clj-insert-sorted x xs less?)
  (cond
    ((null? xs) (list x))
    ((less? x (car xs)) (cons x xs))
    (else (cons (car xs) (scm-clj-insert-sorted x (cdr xs) less?)))))

(define (scm-clj-sort-list xs less?)
  (let loop ((rest xs) (acc '()))
    (if (null? rest)
        acc
        (loop (cdr rest)
              (scm-clj-insert-sorted (car rest) acc less?)))))

(define *ns* 'user)
(define *scm-clj-ns-registry* (make-hash-table))

(define (scm-clj-ensure-ns! ns)
  (let ((existing (hash-table-ref/default *scm-clj-ns-registry* ns #f)))
    (if existing
        existing
        (let ((table (make-hash-table)))
          (hash-table-set! *scm-clj-ns-registry* ns table)
          table))))

(define (scm-clj-set-current-ns! ns)
  (if (symbol? ns)
      (begin
        (set! *ns* ns)
        (scm-clj-ensure-ns! ns)
        ns)
      (error "ns expects a symbol" ns)))

(define (current-ns)
  *ns*)

(define (find-ns ns)
  (hash-table-ref/default *scm-clj-ns-registry* ns #f))

(define (scm-clj-ns-form->symbol form)
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
     *scm-clj-ns-registry*
     (lambda (k v)
       (set! items (cons k items))))
    (reverse items)))

(define (ns-publics ns)
  (let ((table (find-ns ns)))
    (if table
        (let ((m (scm-clj-make-map)))
          (hash-table-for-each
           table
           (lambda (k v)
             (hash-table-set! (map-hash m) k v)))
          m)
        (scm-clj-make-map))))

(define (ns-resolve ns sym)
  (let ((table (find-ns ns)))
    (if table
        (hash-table-ref/default table sym #f)
        #f)))

(define (scm-clj-intern! ns sym value)
  (hash-table-set! (scm-clj-ensure-ns! ns) sym value)
  value)

(define (scm-clj-collect-hash-pairs table)
  (let ((pairs '()))
    (hash-table-for-each
     table
     (lambda (k v)
       (set! pairs (cons (cons k v) pairs))))
    pairs))

(define (scm-clj-map-items m)
  (let ((items '()))
    (hash-table-for-each
     (map-hash m)
     (lambda (k v)
       (set! items (cons (vector k v) items))))
    items))

(define (scm-clj-set-items s)
  (let ((items '()))
    (hash-table-for-each
     (set-hash s)
     (lambda (k v)
       (set! items (cons k items))))
    items))

(define (scm-clj-sorted-map-pairs m)
  (scm-clj-sort-list
   (scm-clj-collect-hash-pairs (map-hash m))
   (lambda (a b)
     (string<? (pr-str (car a))
               (pr-str (car b))))))

(define (scm-clj-sorted-set-items s)
  (scm-clj-sort-list
   (let ((items '()))
     (hash-table-for-each
      (set-hash s)
      (lambda (k v)
        (set! items (cons k items))))
     items)
   (lambda (a b)
     (string<? (pr-str a)
               (pr-str b)))))

(define (scm-clj-map-entry->vector pair)
  (vector (car pair) (cdr pair)))

(define (scm-clj-vector-append vec items)
  (list->vector (append (vector->list vec) items)))

(define (scm-clj-vector-assoc vec idx value)
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

(define (scm-clj-seq-list x)
  (cond
    ((scm-clj-empty-seq? x) nil)
    ((null? x) nil)
    ((pair? x) x)
    ((map? x)
     (let ((items (scm-clj-map-items x)))
       (if (null? items) nil items)))
    ((set? x)
     (let ((items (scm-clj-set-items x)))
       (if (null? items) nil items)))
    ((vector? x)
     (let ((items (vector->list x)))
       (if (null? items) nil items)))
    ((string? x)
     (let ((items (string->list x)))
       (if (null? items) nil items)))
    (else nil)))

(define (scm-clj-write-pr x port)
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
     (let loop ((pairs (scm-clj-sorted-map-pairs x)) (first? #t))
       (if (null? pairs)
           (display "}" port)
           (begin
             (if (not first?) (write-char #\space port))
             (scm-clj-write-pr (caar pairs) port)
             (write-char #\space port)
             (scm-clj-write-pr (cdar pairs) port)
             (loop (cdr pairs) #f)))))
    ((set? x)
     (display "#{" port)
     (let loop ((items (scm-clj-sorted-set-items x)) (first? #t))
       (if (null? items)
           (display "}" port)
           (begin
             (if (not first?) (write-char #\space port))
             (scm-clj-write-pr (car items) port)
             (loop (cdr items) #f)))))
    ((vector? x)
     (display "[" port)
     (let loop ((i 0))
       (if (= i (vector-length x))
           (display "]" port)
           (begin
             (if (> i 0) (write-char #\space port))
             (scm-clj-write-pr (vector-ref x i) port)
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
          (scm-clj-write-pr (car xs) port)
          (loop (cdr xs) #f))
         (else
          (display " . " port)
          (scm-clj-write-pr xs port)
          (display ")" port)))))
    (else
     (write x port))))

(set-record-printer! scm-clj-keyword
  (lambda (kw out)
    (scm-clj-write-pr kw out)))

(set-record-printer! scm-clj-map
  (lambda (m out)
    (scm-clj-write-pr m out)))

(set-record-printer! scm-clj-set
  (lambda (s out)
    (scm-clj-write-pr s out)))

(define (pr-str . xs)
  (let ((p (open-output-string)))
    (let loop ((items xs) (first? #t))
      (if (null? items)
          (get-output-string p)
          (begin
            (if (not first?) (write-char #\space p))
            (scm-clj-write-pr (car items) p)
            (loop (cdr items) #f))))))

(define (scm-clj-str-piece x)
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
            (display (scm-clj-str-piece (car items)) p)
            (loop (cdr items)))))))

(define (println . xs)
  (display (apply pr-str xs))
  (newline)
  nil)

(define prn println)

(define (read-string s)
  (scm-clj-read-one s))

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
  (scm-clj-seq-list x))

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

(define (scm-clj-hash-ref/default table key default)
  (hash-table-ref/default table key default))

(define (scm-clj-hash-exists? table key)
  (hash-table-exists? table key))

(define (scm-clj-hash-set! table key value)
  (hash-table-set! table key value))

(define (scm-clj-hash-delete! table key)
  (hash-table-delete! table key))

(define (scm-clj-get coll key . maybe-default)
  (let ((default (if (null? maybe-default) nil (car maybe-default))))
    (cond
      ((map? coll)
       (scm-clj-hash-ref/default (map-hash coll) key default))
      ((set? coll)
       (if (scm-clj-hash-exists? (set-hash coll) key) key default))
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
       (scm-clj-get c k)))
    ((_ coll key default)
     (##core#let ((c coll)
                  (k key)
                  (d default))
       (scm-clj-get c k d)))))

(define (scm-clj-contains? coll key)
  (cond
    ((map? coll) (scm-clj-hash-exists? (map-hash coll) key))
    ((set? coll) (scm-clj-hash-exists? (set-hash coll) key))
    ((vector? coll)
     (and (integer? key) (>= key 0) (< key (vector-length coll))))
    (else #f)))

(define-syntax contains?
  (syntax-rules ()
    ((_ coll key)
     (##core#let ((c coll)
                  (k key))
       (scm-clj-contains? c k)))))

(define (scm-clj-map-entry? x)
  (or (and (vector? x) (= (vector-length x) 2))
      (and (pair? x) (pair? (cdr x)) (null? (cddr x)))))

(define (scm-clj-map-entry-key x)
  (if (vector? x) (vector-ref x 0) (car x)))

(define (scm-clj-map-entry-val x)
  (if (vector? x) (vector-ref x 1) (cadr x)))

(define (scm-clj-assoc coll . kvs)
  (cond
    ((map? coll)
     (let loop ((xs kvs))
       (cond
         ((null? xs) coll)
         ((null? (cdr xs)) (error "assoc expects key/value pairs"))
         (else
          (scm-clj-hash-set! (map-hash coll) (car xs) (cadr xs))
          (loop (cddr xs))))))
    ((vector? coll)
     (let loop ((xs kvs) (out coll))
       (cond
         ((null? xs) out)
         ((null? (cdr xs)) (error "assoc expects index/value pairs"))
         (else
          (let ((idx (car xs))
                (value (cadr xs)))
            (set! out (scm-clj-vector-assoc out idx value))
            (loop (cddr xs) out))))))
    (else
     (error "assoc only supports maps and vectors"))))

(define-syntax assoc
  (syntax-rules ()
    ((_ coll)
     (scm-clj-assoc coll))
    ((_ coll key val)
     (##core#let ((c coll)
                  (k key)
                  (v val))
       (scm-clj-assoc c k v)))
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
             (scm-clj-hash-delete! (map-hash coll) (car xs))
             (loop (cdr xs))))))
    ((set? coll)
     (let loop ((xs keys))
       (if (null? xs)
           coll
           (begin
             (scm-clj-hash-delete! (set-hash coll) (car xs))
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
                   (scm-clj-hash-set! (map-hash result) k v))))
            (loop (cdr xs)))))))

(define (scm-clj-conj-map! m item)
  (cond
    ((map? item)
     (hash-table-for-each
      (map-hash item)
      (lambda (k v)
        (scm-clj-hash-set! (map-hash m) k v)))
     m)
    ((scm-clj-map-entry? item)
     (scm-clj-hash-set! (map-hash m)
                        (scm-clj-map-entry-key item)
                        (scm-clj-map-entry-val item))
     m)
    (else
     (error "conj expects map entries or maps when target is a map" item))))

(define (conj coll . items)
  (cond
    ((map? coll)
     (let loop ((xs items) (acc coll))
       (if (null? xs)
           acc
           (loop (cdr xs) (scm-clj-conj-map! acc (car xs))))))
    ((set? coll)
     (let loop ((xs items) (acc coll))
       (if (null? xs)
           acc
           (begin
             (scm-clj-hash-set! (set-hash acc) (car xs) #t)
             (loop (cdr xs) acc)))))
    ((vector? coll)
     (scm-clj-vector-append coll items))
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
             (scm-clj-hash-delete! (set-hash coll) (car xs))
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
    (if (scm-clj-empty-seq? xs)
        (reverse acc)
        (loop (cdr xs) (cons (f (car xs)) acc)))))

(define (scm-clj-mapv-vector f vec)
  (let* ((len (vector-length vec))
         (out (make-vector len)))
    (let loop ((i 0))
      (if (= i len)
          out
          (begin
            (vector-set! out i (f (vector-ref vec i)))
            (loop (+ i 1)))))))

(define (scm-clj-filterv-vector pred vec)
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
    ((vector? coll) (scm-clj-mapv-vector f coll))
    (else (list->vector (map f (seq coll))))))

(define (filter pred coll)
  (let loop ((xs (seq coll)) (acc '()))
    (if (scm-clj-empty-seq? xs)
        (reverse acc)
        (let ((item (car xs)))
          (if (pred item)
              (loop (cdr xs) (cons item acc))
              (loop (cdr xs) acc))))))

(define (filterv pred coll)
  (cond
    ((vector? coll) (scm-clj-filterv-vector pred coll))
    (else (list->vector (filter pred (seq coll))))))

(define (remove pred coll)
  (filter (lambda (x) (if (pred x) #f #t)) coll))

(define (reduce f . args)
  (cond
    ((null? args)
     (error "reduce expects at least a collection"))
    ((null? (cdr args))
     (let ((xs (seq (car args))))
       (if (scm-clj-empty-seq? xs)
           (error "reduce of empty collection with no initial value")
           (let loop ((acc (car xs)) (rest-xs (cdr xs)))
             (if (scm-clj-empty-seq? rest-xs)
                 acc
                 (loop (f acc (car rest-xs)) (cdr rest-xs)))))))
    (else
     (let ((init (car args))
           (coll (cadr args)))
       (let loop ((acc init) (xs (seq coll)))
         (if (scm-clj-empty-seq? xs)
             acc
             (loop (f acc (car xs)) (cdr xs))))))))

(define (some pred coll)
  (let loop ((xs (seq coll)))
    (if (scm-clj-empty-seq? xs)
        nil
        (let ((value (pred (car xs))))
          (if (truthy? value)
              value
              (loop (cdr xs)))))))

(define (every? pred coll)
  (let loop ((xs (seq coll)))
    (if (scm-clj-empty-seq? xs)
        #t
        (if (truthy? (pred (car xs)))
            (loop (cdr xs))
            #f))))

(define (identity x) x)

(define (inc x) (+ x 1))

(define (dec x) (- x 1))

(define (into to from)
  (let loop ((xs (seq from)) (acc to))
    (if (scm-clj-empty-seq? xs)
        acc
        (loop (cdr xs) (conj acc (car xs))))))

(define (not x)
  (if (truthy? x) #f #t))

(define (scm-clj-vector-form->list x)
  (cond
    ((vector? x) (vector->list x))
    ((and (pair? x) (eq? (car x) 'vector)) (cdr x))
    (else #f)))

(define (scm-clj-parse-fn-args args)
  (let ((xs (scm-clj-vector-form->list args)))
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

(define (scm-clj-parse-let-bindings bindings)
  (let ((xs (scm-clj-vector-form->list bindings)))
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

(define (scm-clj-fn-clauses clauses)
  (let loop ((xs clauses) (acc '()))
    (if (null? xs)
        (reverse acc)
        (let ((clause (car xs)))
          (let ((args (and (pair? clause)
                           (scm-clj-vector-form->list (car clause)))))
            (if args
              (loop (cdr xs)
                    (cons (list (scm-clj-parse-fn-args (car clause))
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
          (scm-clj-intern! (current-ns) ',name ,name))))))

(define-syntax fn
  (er-macro-transformer
   (lambda (form rename compare)
     (##core#let ((parts (cdr form)))
       (cond
         ((null? parts)
          (error "fn expects an argument vector or arity clauses"))
         ((scm-clj-vector-form->list (car parts))
          `(lambda ,(scm-clj-parse-fn-args (car parts))
             ,@(cdr parts)))
         ((and (pair? (car parts))
               (scm-clj-vector-form->list (caar parts)))
          `(case-lambda
             ,@(map (lambda (clause)
                      (list (scm-clj-parse-fn-args (car clause))
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
                  (##core#let ((name (scm-clj-ns-form->symbol (car parts)))
                               (rest (cdr parts)))
                    (##core#if (and (pair? rest) (string? (car rest)))
                               (begin
                                 (set! rest (cdr rest))
                                 (##core#if (pair? rest)
                                            (error "ns directives are not yet supported" rest)
                                            (begin
                                              (scm-clj-set-current-ns! name)
                                              `(scm-clj-set-current-ns! ',name))))
                               (begin
                                 (##core#if (pair? rest)
                                            (error "ns directives are not yet supported" rest)
                                            (begin
                                              (scm-clj-set-current-ns! name)
                                              `(scm-clj-set-current-ns! ',name)))))))))))

(define-syntax in-ns
  (er-macro-transformer
   (lambda (form rename compare)
     (##core#let ((parts (cdr form)))
       (##core#if (null? parts)
                  (error "in-ns expects a namespace name")
                  (##core#let ((name (scm-clj-ns-form->symbol (car parts))))
                    (scm-clj-set-current-ns! name)
                    `(scm-clj-set-current-ns! ',name)))))))

(define (scm-clj-cond-else? x)
  (or (and (symbol? x) (string=? (symbol->string x) "else"))
      (and (keyword? x) (string=? (name x) "else"))))

(define (scm-clj-inline-truthy-form test then else-part temp)
  `(##core#let ((,temp ,test))
     (##core#if (eq? ,temp false)
                ,else-part
                (##core#if (eq? ,temp nil)
                           ,else-part
                           ,then))))

(define (scm-clj-expand-cond clauses rename)
  (let loop ((rest clauses))
    (cond
      ((null? rest) 'nil)
      ((null? (cdr rest))
       (error "cond expects test/expression pairs"))
      ((scm-clj-cond-else? (car rest))
       (if (null? (cddr rest))
           (cadr rest)
           (error "cond else clause must be last")))
      (else
       (let ((tail (loop (cddr rest)))
             (value (rename 'scm-clj-cond-value)))
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
       (scm-clj-inline-truthy-form test then else-part (rename 'scm-clj-if-value))))))

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
     (scm-clj-expand-cond (cdr form) rename))))

(define (scm-clj-thread-first-step x step)
  (##core#if (pair? step)
             (cons (car step) (cons x (cdr step)))
             (list step x)))

(define (scm-clj-thread-last-step x step)
  (##core#if (pair? step)
             (append step (list x))
             (list step x)))

(define (scm-clj-thread-chain x steps stepper)
  (##core#if (null? steps)
             x
             (scm-clj-thread-chain (stepper x (car steps))
                                   (cdr steps)
                                   stepper)))

(define-syntax ->
  (er-macro-transformer
   (lambda (form rename compare)
     (scm-clj-thread-chain (cadr form)
                           (cddr form)
                           scm-clj-thread-first-step))))

(define-syntax ->>
  (er-macro-transformer
   (lambda (form rename compare)
     (scm-clj-thread-chain (cadr form)
                           (cddr form)
                           scm-clj-thread-last-step))))

(define (scm-clj-repl-print-results . results)
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

(define (scm-clj-repl-evaluator expr)
  (call-with-values
   (lambda ()
     (default-evaluator expr))
   scm-clj-repl-print-results))

(define (scm-clj-repl)
  (repl-prompt (lambda () "scm-clj> "))
  (repl scm-clj-repl-evaluator))

(define-syntax let
  (er-macro-transformer
   (lambda (form rename compare)
     (##core#let ((bindings (cadr form))
                  (body (cddr form)))
       `(let* ,(scm-clj-parse-let-bindings bindings)
          ,@body)))))
