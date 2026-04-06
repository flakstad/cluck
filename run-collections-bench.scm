(import (chicken load)
        (chicken process-context))

(load-relative "cluck-init.scm")
(load-relative "collections-bench.clk")

(collections-bench-main (command-line-arguments))
