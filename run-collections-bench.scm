(import (chicken load)
        (chicken process-context))

(load-relative "Cluck-init.scm")
(load-relative "collections-bench.clj")

(collections-bench-main (command-line-arguments))
