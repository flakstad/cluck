(import (chicken load)
        (chicken process-context))

(load-relative "scm-clj-init.scm")
(load-relative "collections-bench.clj.scm")

(collections-bench-main (command-line-arguments))
