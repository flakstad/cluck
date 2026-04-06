;; Collections benchmark for scm-clj.
;; Measures map/mapv and filter/filterv on list and vector inputs.

(import (chicken time))

(ns scm-clj.collections-bench)

(def default-count 5000)
(def default-rounds 100)
(def bench-sink nil)

(defn parse-int-or-default [raw default]
  (if raw
      (let [n (string->number raw)]
        (if n n default))
      default))

(defn parse-count [args]
  (parse-int-or-default (first args) default-count))

(defn parse-rounds [args]
  (parse-int-or-default (first (rest args)) default-rounds))

(defn make-integers-aux [i n acc]
  (if (> i n)
      acc
      (make-integers-aux (+ i 1)
                         n
                         (cons i acc))))

(defn make-integers [n]
  (reverse (make-integers-aux 1 n '())))

(defn make-data [n]
  (let [items (make-integers n)]
    {:list items
     :vector (list->vector items)}))

(defn bench-case-aux [i thunk last]
  (if (= i 0)
      last
      (bench-case-aux (- i 1)
                      thunk
                      (thunk))))

(defn bench-case [label rounds thunk]
  (let [start (current-process-milliseconds)]
    (set! bench-sink (bench-case-aux rounds thunk nil))
    (let [elapsed (- (current-process-milliseconds) start)]
      (println label ":" elapsed "ms" "count:" (count bench-sink))
      elapsed)))

(defn run-map-benchmarks [rounds data]
  (let [xs (get data :list)
        xv (get data :vector)]
    (+ (bench-case "map on list" rounds (fn [] (map inc xs)))
       (bench-case "mapv on list" rounds (fn [] (mapv inc xs)))
       (bench-case "map on vector" rounds (fn [] (map inc xv)))
       (bench-case "mapv on vector" rounds (fn [] (mapv inc xv))))))

(defn run-filter-benchmarks [rounds data]
  (let [xs (get data :list)
        xv (get data :vector)]
    (+ (bench-case "filter on list" rounds (fn [] (filter even? xs)))
       (bench-case "filterv on list" rounds (fn [] (filterv even? xs)))
       (bench-case "filter on vector" rounds (fn [] (filter even? xv)))
       (bench-case "filterv on vector" rounds (fn [] (filterv even? xv))))))

(defn collections-bench-main-with [n rounds]
  (let [data (make-data n)]
    (println "scm-clj collections benchmark")
    (println "Namespace:" (current-ns))
    (println "Items:" n)
    (println "Rounds:" rounds)
    (println "Map benchmarks:")
    (let [map-total (run-map-benchmarks rounds data)]
      (println "Map total ms:" map-total))
    (println "Filter benchmarks:")
    (let [filter-total (run-filter-benchmarks rounds data)]
      (println "Filter total ms:" filter-total))
    (println "Done.")
    data))

(defn collections-bench-main [args]
  (collections-bench-main-with (parse-count args)
                               (parse-rounds args)))
