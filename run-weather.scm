(import (chicken load)
        (chicken process-context))

(load-relative "cluck-init.scm")
(load-relative "cluck/weather.clk")

(main (command-line-arguments))
