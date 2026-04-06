(import (chicken load)
        (chicken process-context))

(load-relative "cluck-init.scm")
(load-relative "bench.clk")

(bench-main (command-line-arguments))
