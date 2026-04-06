;; Small demo program for scm-clj.
;; Load this after scm-clj-init.scm or via run-demo.scm.

(def backlog
  [{:id 101 :title "bootstrap reader" :status :done :priority 1 :tags #{:core :docs}}
   {:id 102 :title "record printers" :status :done :priority 1 :tags #{:core :repl}}
   {:id 103 :title "namespace support" :status :doing :priority 2 :tags #{:core}}
   {:id 104 :title "destructuring" :status :todo :priority 2 :tags #{:core}}
   {:id 105 :title "demo program" :status :doing :priority 1 :tags #{:docs :example}}
   {:id 106 :title "package metadata" :status :todo :priority 3 :tags #{:docs}}])

(def settings
  (read-string "{:project \"scm-clj\" :owners #{:andreas} :mode :demo}"))

(defn title-of [item]
  (get item :title))

(defn status-of [item]
  (get item :status))

(defn tags-of [item]
  (get item :tags))

(defn unfinished? [item]
  (not (equal? (status-of item) :done)))

(defn items-with-tag [items tag]
  (filter (fn [item] (contains? (tags-of item) tag)) items))

(defn status-counts [items]
  (reduce
   (fn [counts item]
     (let [status (status-of item)
           current (get counts status 0)]
       (assoc counts status (inc current))))
   {}
   items))

(defn title-list [items]
  (->> items
       (map title-of)))

(defn demo-report []
  (let [open-items (filter unfinished? backlog)
        docs-items (items-with-tag backlog :docs)
        high-priority (filter (fn [item] (< (get item :priority) 3)) open-items)]
    (println "scm-clj demo")
    (println "Project settings:" settings)
    (println "Total items:" (count backlog))
    (println "Status counts:" (status-counts backlog))
    (println "Open items:" (title-list open-items))
    (println "Docs items:" (title-list docs-items))
    (println "High priority open items:" (title-list high-priority))
    (println "Raw EDN:" (read-string "{:release \"0.1.0\" :targets #{:geiser :cli}}"))
    nil))

(demo-report)
