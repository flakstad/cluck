(import scheme
        (chicken base)
        (chicken io)
        (chicken port)
        (chicken read-syntax)
        hash-trie
        srfi-69)

(define cluck-nil (list 'cluck-nil))
(define nil cluck-nil)
(define true #t)
(define false #f)

(define-record-type cluck-keyword
  (make-cluck-keyword namespace name)
  cluck-keyword?
  (namespace keyword-namespace)
  (name keyword-name))

(define-record-type cluck-map
  (make-cluck-map table)
  cluck-map?
  (table map-hash))

(define-record-type cluck-set
  (make-cluck-set table)
  cluck-set?
  (table set-hash))

(define (cluck-delimiter-char? c)
  (or (char-whitespace? c)
      (memv c '(#\( #\) #\[ #\] #\{ #\} #\" #\; #\, #\'))))

(define (cluck-string-index-char s needle)
  (let loop ((i 0))
    (cond
      ((= i (string-length s)) #f)
      ((char=? (string-ref s i) needle) i)
      (else (loop (+ i 1))))))

(define (cluck-split-qualified-name s)
  (let ((slash (cluck-string-index-char s #\/)))
    (if slash
        (cons (substring s 0 slash)
              (substring s (+ slash 1) (string-length s)))
        (cons #f s))))

(define (keyword? x)
  (cluck-keyword? x))

(define (map? x)
  (cluck-map? x))

(define (set? x)
  (cluck-set? x))

(define (nil? x)
  (eq? x nil))

(define (false? x)
  (eq? x false))

(define (truthy? x)
  (if (false? x)
      #f
      (if (nil? x) #f #t)))

(define (cluck-make-keyword namespace name)
  (make-cluck-keyword namespace name))

(define (cluck-object->string x)
  (cond
    ((string? x) x)
    ((symbol? x) (symbol->string x))
    ((keyword? x) (keyword-name x))
    ((number? x) (number->string x))
    ((boolean? x) (if x "true" "false"))
    ((nil? x) "nil")
    (else
     (let ((p (open-output-string)))
       (write x p)
       (get-output-string p)))))

(define (keyword . args)
  (cond
    ((null? args)
     (error "keyword expects one or two arguments"))
    ((null? (cdr args))
     (let ((x (car args)))
       (cond
         ((keyword? x) x)
         ((symbol? x)
          (let* ((parts (cluck-split-qualified-name (symbol->string x))))
            (cluck-make-keyword (car parts) (cdr parts))))
         ((string? x)
          (let* ((parts (cluck-split-qualified-name x)))
            (cluck-make-keyword (car parts) (cdr parts))))
         (else
          (cluck-make-keyword #f (cluck-object->string x))))))
    ((null? (cddr args))
     (cluck-make-keyword
      (let ((ns (car args)))
        (if (or (eq? ns #f) (eq? ns nil)) #f (cluck-object->string ns)))
      (let ((name (cadr args)))
        (cluck-object->string name))))
    (else
     (error "keyword expects one or two arguments"))))

(define (name x)
  (cond
    ((keyword? x) (keyword-name x))
    ((symbol? x) (cdr (cluck-split-qualified-name (symbol->string x))))
    ((string? x) x)
    (else (error "name expects a keyword, symbol, or string" x))))

(define (namespace x)
  (cond
    ((keyword? x) (keyword-namespace x))
    ((symbol? x) (car (cluck-split-qualified-name (symbol->string x))))
    ((string? x) (car (cluck-split-qualified-name x)))
    (else #f)))

(define cluck-hash-modulus 536870909)

(define (cluck-hash-normalize n)
  (let ((x (modulo n cluck-hash-modulus)))
    (if (< x 0)
        (+ x cluck-hash-modulus)
        x)))

(define (cluck-hash-add a b)
  (cluck-hash-normalize (+ a b)))

(define (cluck-hash-combine seed value)
  (cluck-hash-normalize (+ (* 16777619 (cluck-hash-normalize seed))
                           (cluck-hash-normalize value)
                           1)))

(define (cluck-optional-string=? a b)
  (cond
    ((and (not a) (not b)) #t)
    ((and (string? a) (string? b)) (string=? a b))
    (else #f)))

(define (cluck-map=? a b)
  (and (= (hash-trie/count (map-hash a))
          (hash-trie/count (map-hash b)))
       (let loop ((entries (hash-trie->alist (map-hash a))))
         (if (null? entries)
             #t
             (let* ((entry (car entries))
                    (key (car entry))
                    (value (cdr entry))
                    (missing (list 'cluck-map-missing))
                    (other (hash-trie/lookup (map-hash b) key missing)))
               (and (not (eq? other missing))
                    (cluck-value=? value other)
                    (loop (cdr entries))))))))

(define (cluck-set=? a b)
  (and (= (hash-trie/count (set-hash a))
          (hash-trie/count (set-hash b)))
       (let loop ((items (hash-trie/key-list (set-hash a))))
         (if (null? items)
             #t
             (and (hash-trie/member? (set-hash b) (car items))
                  (loop (cdr items)))))))

(define (cluck-vector=? a b)
  (let ((len (vector-length a)))
    (and (= len (vector-length b))
         (let loop ((i 0))
           (if (= i len)
               #t
               (and (cluck-value=? (vector-ref a i) (vector-ref b i))
                    (loop (+ i 1))))))))

(define (cluck-pair=? a b)
  (and (cluck-value=? (car a) (car b))
       (cluck-value=? (cdr a) (cdr b))))

(define (cluck-value=? a b)
  (cond
    ((eq? a b) #t)
    ((and (nil? a) (nil? b)) #t)
    ((or (nil? a) (nil? b)) #f)
    ((and (boolean? a) (boolean? b)) (eq? a b))
    ((or (boolean? a) (boolean? b)) #f)
    ((and (number? a) (number? b)) (= a b))
    ((or (number? a) (number? b)) #f)
    ((and (string? a) (string? b)) (string=? a b))
    ((or (string? a) (string? b)) #f)
    ((and (char? a) (char? b)) (char=? a b))
    ((or (char? a) (char? b)) #f)
    ((and (symbol? a) (symbol? b)) (eq? a b))
    ((or (symbol? a) (symbol? b)) #f)
    ((and (keyword? a) (keyword? b))
     (and (cluck-optional-string=? (keyword-namespace a)
                                   (keyword-namespace b))
          (string=? (keyword-name a)
                    (keyword-name b))))
    ((or (keyword? a) (keyword? b)) #f)
    ((and (map? a) (map? b)) (cluck-map=? a b))
    ((or (map? a) (map? b)) #f)
    ((and (set? a) (set? b)) (cluck-set=? a b))
    ((or (set? a) (set? b)) #f)
    ((and (vector? a) (vector? b)) (cluck-vector=? a b))
    ((or (vector? a) (vector? b)) #f)
    ((and (pair? a) (pair? b)) (cluck-pair=? a b))
    ((or (pair? a) (pair? b)) #f)
    (else (eq? a b))))

(define (cluck-vector-hash v tag)
  (let ((len (vector-length v)))
    (let loop ((i 0) (acc tag))
      (if (= i len)
          (cluck-hash-combine acc len)
          (loop (+ i 1)
                (cluck-hash-combine acc
                                    (cluck-value-hash (vector-ref v i))))))))

(define (cluck-pair-hash p tag)
  (let loop ((current p) (acc tag))
    (if (pair? current)
        (loop (cdr current)
              (cluck-hash-combine acc
                                  (cluck-value-hash (car current))))
        (cluck-hash-combine (cluck-hash-combine acc (cluck-value-hash current))
                            tag))))

(define (cluck-map-hash-value m tag)
  (let ((entry-sum
         (hash-trie/fold
          (map-hash m)
          0
          (lambda (k v acc)
            (cluck-hash-add
             acc
             (cluck-hash-combine (cluck-value-hash k)
                                 (cluck-value-hash v)))))))
    (cluck-hash-combine (cluck-hash-combine tag entry-sum)
                        (hash-trie/count (map-hash m)))))

(define (cluck-set-hash-value s tag)
  (let ((entry-sum
         (hash-trie/fold
          (set-hash s)
          0
          (lambda (k v acc)
            (cluck-hash-add acc (cluck-value-hash k))))))
    (cluck-hash-combine (cluck-hash-combine tag entry-sum)
                        (hash-trie/count (set-hash s)))))

(define (cluck-value-hash x)
  (cond
    ((nil? x) (cluck-hash-combine 1 0))
    ((eq? x false) (cluck-hash-combine 2 0))
    ((eq? x true) (cluck-hash-combine 3 0))
    ((number? x) (cluck-hash-combine 4 (equal?-hash x)))
    ((string? x) (cluck-hash-combine 5 (string-hash x)))
    ((char? x) (cluck-hash-combine 6 (char->integer x)))
    ((symbol? x) (cluck-hash-combine 7 (symbol-hash x)))
    ((keyword? x)
     (cluck-hash-combine
      8
      (cluck-hash-combine (if (keyword-namespace x)
                              (string-hash (keyword-namespace x))
                              0)
                          (string-hash (keyword-name x)))))
    ((map? x) (cluck-map-hash-value x 9))
    ((set? x) (cluck-set-hash-value x 10))
    ((vector? x) (cluck-vector-hash x 11))
    ((pair? x) (cluck-pair-hash x 12))
    (else (cluck-hash-combine 13 (object-uid-hash x)))))

(define cluck-hash-trie-type
  (make-hash-trie-type cluck-value=? cluck-value-hash))

(define (cluck-make-map)
  (make-cluck-map (make-hash-trie cluck-hash-trie-type)))

(define (cluck-make-set)
  (make-cluck-set (make-hash-trie cluck-hash-trie-type)))

(define (cluck-map-count m)
  (hash-trie/count (map-hash m)))

(define (cluck-set-count s)
  (hash-trie/count (set-hash s)))

(define (cluck-map-empty? m)
  (hash-trie/empty? (map-hash m)))

(define (cluck-set-empty? s)
  (hash-trie/empty? (set-hash s)))

(define (cluck-map-ref/default m key default)
  (hash-trie/lookup (map-hash m) key default))

(define (cluck-set-member? s key)
  (hash-trie/member? (set-hash s) key))

(define (cluck-map-insert m key value)
  (make-cluck-map (hash-trie/insert (map-hash m) key value)))

(define (cluck-set-insert s key)
  (make-cluck-set (hash-trie/insert (set-hash s) key #t)))

(define (cluck-map-delete m key)
  (make-cluck-map (hash-trie/delete (map-hash m) key)))

(define (cluck-set-delete s key)
  (make-cluck-set (hash-trie/delete (set-hash s) key)))

(define (cluck-map-alist m)
  (hash-trie->alist (map-hash m)))

(define (cluck-set-list s)
  (hash-trie/key-list (set-hash s)))

(define (cluck-map-items m)
  (let loop ((xs (cluck-map-alist m)) (acc '()))
    (if (null? xs)
        (reverse acc)
        (let* ((entry (car xs))
               (k (car entry))
               (v (cdr entry)))
          (loop (cdr xs)
                (cons (vector k v) acc))))))

(define (cluck-set-items s)
  (cluck-set-list s))

(define (cluck-ensure-even-list items who)
  (let loop ((xs items))
    (cond
      ((null? xs) #t)
      ((null? (cdr xs))
       (error who "expects an even number of forms"))
      (else (loop (cddr xs))))))

(define (hash-map . kvs)
  (let ((m (cluck-make-map)))
    (cluck-ensure-even-list kvs 'hash-map)
    (let loop ((xs kvs) (out m))
      (if (null? xs)
          out
          (loop (cddr xs)
                (cluck-map-insert out (car xs) (cadr xs)))))))

(define (set . xs)
  (let ((s (cluck-make-set)))
    (let loop ((items xs) (out s))
      (if (null? items)
          out
          (loop (cdr items)
                (cluck-set-insert out (car items)))))))

(define hash-set set)

(define (cluck-normalize-vector v)
  (let* ((len (vector-length v))
         (out (make-vector len)))
    (let loop ((i 0))
      (if (= i len)
          out
          (begin
            (vector-set! out i (normalize-edn (vector-ref v i)))
            (loop (+ i 1)))))))

(define (cluck-normalize-list x)
  (cond
    ((null? x) '())
    ((pair? x)
     (cons (normalize-edn (car x))
           (cluck-normalize-list (cdr x))))
    (else (normalize-edn x))))

(define (cluck-normalize-map m)
  (hash-trie/fold
   (map-hash m)
   (cluck-make-map)
   (lambda (k v acc)
     (cluck-map-insert acc
                       (normalize-edn k)
                       (normalize-edn v)))))

(define (cluck-normalize-set s)
  (hash-trie/fold
   (set-hash s)
   (cluck-make-set)
   (lambda (k v acc)
     (cluck-set-insert acc
                       (normalize-edn k)))))

(define (normalize-edn x)
  (cond
    ((keyword? x) x)
    ((map? x) (cluck-normalize-map x))
    ((set? x) (cluck-normalize-set x))
    ((vector? x) (cluck-normalize-vector x))
    ((symbol? x)
     (cond
       ((eq? x 'nil) nil)
       ((eq? x 'true) true)
       ((eq? x 'false) false)
       (else x)))
    ((pair? x) (cluck-normalize-list x))
    (else x)))

(define (cluck-string-input-port? port)
  (let ((name (port-name port)))
    (and (string? name)
         (string=? name "(string)"))))

(define (cluck-source-form x)
  (cond
    ((keyword? x)
     (let ((ns (keyword-namespace x))
           (nm (keyword-name x)))
       (if ns
           `(keyword ,(string-append ns "/" nm))
           `(keyword ,nm))))
    ((map? x)
     (let ((pairs '()))
       (for-each
        (lambda (entry)
          (set! pairs
                (cons (cluck-source-form (cdr entry))
                      (cons (cluck-source-form (car entry)) pairs))))
        (cluck-map-alist x))
       `(hash-map ,@(reverse pairs))))
    ((set? x)
     (let ((items '()))
       (for-each
        (lambda (k)
          (set! items (cons (cluck-source-form k) items)))
        (cluck-set-list x))
       `(set ,@(reverse items))))
    ((vector? x)
     (let loop ((i 0) (items '()))
       (if (= i (vector-length x))
           `(vector ,@(reverse items))
           (loop (+ i 1)
                 (cons (cluck-source-form (vector-ref x i)) items)))))
    ((pair? x)
     (cons (cluck-source-form (car x))
           (cluck-source-form (cdr x))))
    (else x)))

(define (edn-clean-string s)
  (let* ((len (string-length s))
         (out (open-output-string)))
    (letrec ((emit
              (lambda (c)
                (write-char c out)))
             (scan-normal
              (lambda (i)
                (if (>= i len)
                    (get-output-string out)
                    (let ((c (string-ref s i)))
                      (cond
                        ((char=? c #\,)
                         (emit #\space)
                         (scan-normal (+ i 1)))
                        ((char=? c #\;)
                         (emit #\space)
                         (scan-comment (+ i 1)))
                        ((char=? c #\")
                         (emit c)
                         (scan-string (+ i 1)))
                        (else
                         (emit c)
                         (scan-normal (+ i 1))))))))
             (scan-string
              (lambda (i)
                (if (>= i len)
                    (error "unexpected EOF in string literal")
                    (let ((c (string-ref s i)))
                      (emit c)
                      (cond
                        ((char=? c #\\)
                         (if (>= (+ i 1) len)
                             (error "unexpected EOF in string escape")
                             (begin
                               (emit (string-ref s (+ i 1)))
                               (scan-string (+ i 2)))))
                        ((char=? c #\")
                         (scan-normal (+ i 1)))
                        (else
                         (scan-string (+ i 1))))))))
             (scan-comment
              (lambda (i)
                (if (>= i len)
                    (get-output-string out)
                    (let ((c (string-ref s i)))
                      (if (char=? c #\newline)
                          (scan-normal i)
                          (scan-comment (+ i 1))))))))
      (scan-normal 0))))

(define (cluck-read-forms s)
  (call-with-input-string
   (edn-clean-string s)
   (lambda (p)
     (let loop ((forms (read-list p)) (acc '()))
       (if (null? forms)
           (reverse acc)
           (loop (cdr forms)
                 (cons (normalize-edn (car forms)) acc)))))))

(define (cluck-read-one s)
  (call-with-input-string
   (edn-clean-string s)
   (lambda (p)
     (normalize-edn (read p)))))

(define (cluck-read-balanced-content port close-char)
  (let ((out (open-output-string))
        (stack (list close-char)))
    (define (emit c)
      (write-char c out))
    (define (top)
      (car stack))
    (define (push! c)
      (set! stack (cons c stack)))
    (define (pop!)
      (set! stack (cdr stack)))
    (letrec ((scan
              (lambda (state)
                (let ((c (read-char port)))
                  (cond
                    ((eof-object? c)
                     (error "unexpected EOF while reading literal"))
                    ((eq? state 'string)
                     (emit c)
                     (cond
                       ((char=? c #\\)
                        (let ((d (read-char port)))
                          (if (eof-object? d)
                              (error "unexpected EOF in string escape")
                              (begin
                                (emit d)
                                (scan 'string)))))
                       ((char=? c #\")
                        (scan 'normal))
                       (else
                        (scan 'string))))
                    ((eq? state 'comment)
                     (if (char=? c #\newline)
                         (scan 'normal)
                         (scan 'comment)))
                    ((char=? c #\")
                     (emit c)
                     (scan 'string))
                    ((char=? c #\;)
                     (scan 'comment))
                    ((char=? c #\#)
                     (let ((n (peek-char port)))
                       (cond
                         ((eof-object? n)
                          (emit c)
                          (scan 'normal))
                         ((char=? n #\{)
                          (emit c)
                          (emit (read-char port))
                          (push! #\})
                          (scan 'normal))
                         ((char=? n #\[)
                          (emit c)
                          (emit (read-char port))
                          (push! #\])
                          (scan 'normal))
                         ((char=? n #\()
                          (emit c)
                          (emit (read-char port))
                          (push! #\))
                          (scan 'normal))
                         (else
                          (emit c)
                          (scan 'normal)))))
                    ((char=? c #\()
                     (emit c)
                     (push! #\))
                     (scan 'normal))
                    ((char=? c #\[)
                     (emit c)
                     (push! #\])
                     (scan 'normal))
                    ((char=? c #\{)
                     (emit c)
                     (push! #\})
                     (scan 'normal))
                    ((char=? c (top))
                     (pop!)
                     (if (null? stack)
                         (get-output-string out)
                         (begin
                           (emit c)
                           (scan 'normal))))
                    ((memv c '(#\) #\] #\}))
                     (error "unexpected closing delimiter" c))
                    (else
                     (emit c)
                     (scan 'normal)))))))
      (scan 'normal))))

(define (read-keyword port)
  (let ((token (read-token
                (lambda (c)
                  (if (cluck-delimiter-char? c) #f #t))
                port)))
    (if token
        (if (string=? token "")
            (error "empty keyword literal")
            (let* ((normalized (if (and (> (string-length token) 0)
                                        (char=? (string-ref token 0) #\:))
                                   (substring token 1 (string-length token))
                                   token))
                   (parts (cluck-split-qualified-name normalized)))
              (if (cluck-string-input-port? port)
                  (keyword (car parts) (cdr parts))
                  `(keyword ,normalized))))
        (error "empty keyword literal"))))

(define (read-vector-literal port)
  (let ((items (cluck-read-forms (cluck-read-balanced-content port #\]))))
    (if (cluck-string-input-port? port)
        (list->vector items)
        (cons 'vector (map cluck-source-form items)))))

(define (read-map-literal port)
  (let ((items (cluck-read-forms (cluck-read-balanced-content port #\}))))
    (cluck-ensure-even-list items 'read-map-literal)
    (if (cluck-string-input-port? port)
        (let ((m (cluck-make-map)))
          (let loop ((xs items) (out m))
            (if (null? xs)
                out
                (loop (cddr xs)
                      (cluck-map-insert out (car xs) (cadr xs))))))
        (let loop ((xs items) (acc '()))
          (if (null? xs)
              (cons 'hash-map acc)
              (loop (cddr xs)
                    (append acc
                            (list (cluck-source-form (car xs))
                                  (cluck-source-form (cadr xs))))))))))

(define (read-set-literal port)
  (let ((items (cluck-read-forms (cluck-read-balanced-content port #\}))))
    (if (cluck-string-input-port? port)
        (let ((s (cluck-make-set)))
          (let loop ((xs items) (out s))
            (if (null? xs)
                out
                (loop (cdr xs)
                      (cluck-set-insert out (car xs))))))
        (cons 'set (map cluck-source-form items)))))

(define (read-discard port)
  (read port)
  (values))
