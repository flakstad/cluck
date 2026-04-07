(import (chicken load)
        (chicken process-context))

;; Load the weather bootstrap first, then the Cluck weather app.
(load-relative "weather-bootstrap.scm")
(load-relative "cluck/weather.clk")

(main (command-line-arguments))
