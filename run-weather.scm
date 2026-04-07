(import (chicken load)
        (chicken process-context))

;; Load the language layer, then the weather app.
(load-relative "cluck-init.scm")
(load-relative "cluck/weather.clk")

(main (command-line-arguments))
