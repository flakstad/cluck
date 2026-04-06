;; Small math namespace for require/ns smoke coverage.

(ns Cluck.math)

(defn square [x]
  (* x x))

(defn sum-of-squares [xs]
  (reduce + 0 (mapv square xs)))

(defn report [xs]
  {:count (count xs)
   :sum (reduce + 0 xs)
   :sum-of-squares (sum-of-squares xs)})
