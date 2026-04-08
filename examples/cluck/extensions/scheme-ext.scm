;; Plain Scheme extension for the Cluck extension registry demo.
;;
;; This file is loaded with `load-file` from the Cluck example app.

(register-extension!
 "scheme"
 (lambda ()
   "Scheme extension loaded"))
