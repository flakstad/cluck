(with-eval-after-load 'clojure-mode
  (define-derived-mode cluck-mode clojure-mode "cluck"
    "Major mode for editing cluck source files."
    (setq-local clojure-align-forms-automatically nil)
    (setq-local clojure-indent-style 'align-arguments))

  (add-to-list 'auto-mode-alist '("\\.clk\\'" . cluck-mode))

  (add-hook 'cluck-mode-hook #'yas-minor-mode)
  (add-hook 'cluck-mode-hook #'hs-minor-mode)
  (add-hook 'cluck-mode-hook #'flycheck-mode)
  (add-hook 'cluck-mode-hook #'paredit-mode))

(provide 'setup-cluck-mode)
