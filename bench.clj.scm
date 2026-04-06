;; Benchmark / CLI demo for scm-clj.
;; Load this after scm-clj-init.scm or via run-bench.scm.

(ns scm-clj.cli)

(def default-count 50000)

(defn parse-count-from [raw]
  (if raw
      (if (string->number raw)
          (string->number raw)
          default-count)
      default-count))

(defn parse-count [args]
  (parse-count-from (first args)))

(defn status-of [n]
  (cond
    (= (modulo n 3) 0) :done
    (= (modulo n 3) 1) :doing
    :else :todo))

(defn priority-of [n]
  (if (= (modulo n 5) 0)
      1
      2))

(defn tags-for [n]
  (if (even? n)
      #{:bench :core}
      #{:bench :docs}))

(defn make-item [n]
  {:id n
   :title (str "item-" n)
   :status (status-of n)
   :priority (priority-of n)
   :tags (tags-for n)})

(defn make-items-aux [i n acc]
  (if (> i n)
      acc
      (make-items-aux (+ i 1)
                      n
                      (conj acc (make-item i)))))

(defn make-items [n]
  (reverse (make-items-aux 1 n '())))

(defn summarize-item-with-fields [stats item status tags priority]
  (assoc
   (assoc
    (assoc
     (assoc
      (assoc stats :total (inc (get stats :total 0)))
      status
      (inc (get stats status 0)))
     :checksum
     (+ (get stats :checksum 0)
        (get item :id)))
    :high-priority
    (if (< priority 3)
        (inc (get stats :high-priority 0))
        (get stats :high-priority 0)))
   :docs
   (if (contains? tags :docs)
       (inc (get stats :docs 0))
       (get stats :docs 0))))

(defn summarize-item [stats item]
  (summarize-item-with-fields stats
                              item
                              (get item :status)
                              (get item :tags)
                              (get item :priority)))

(defn summarize-aux [stats items]
  (if (null? items)
      stats
      (summarize-aux (summarize-item stats (first items))
                     (rest items))))

(defn summarize [items]
  (summarize-aux {:total 0 :done 0 :doing 0 :todo 0 :high-priority 0 :docs 0 :checksum 0}
                 items))

(defn bench-main-with-summary [n items summary]
  (println "scm-clj benchmark")
  (println "Namespace:" (current-ns))
  (println "Requested items:" n)
  (println "Actual items:" (count items))
  (println "Open items:" (count (filter (fn [item] (not (equal? (get item :status) :done)))
                                         items)))
  (println "Summary:" summary)
  summary)

(defn bench-main-with-items [n items]
  (bench-main-with-summary n items (summarize items)))

(defn bench-main-with-count [n]
  (bench-main-with-items n (make-items n)))

(defn bench-main [args]
  (bench-main-with-count (parse-count args)))
