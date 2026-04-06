;; Small application namespace that depends on scm-clj.math.

(ns scm-clj.app
  (:require [scm-clj.math :as math :refer [square sum-of-squares]]))

(defn report [xs]
  (let [first-value (first xs)
        math-square (ns-resolve 'math 'square)]
    {:count (count xs)
     :sum (reduce + 0 xs)
     :sum-of-squares (sum-of-squares xs)
     :first-square (square first-value)
     :alias-square (math-square first-value)}))
