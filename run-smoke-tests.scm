(import (chicken load))

;; The weather bootstrap loads the Cluck runtime, which the smoke tests use.
(load-relative "weather-bootstrap.scm")
(load-relative "smoke.clk")
