;;; lang/emacs-lisp/config.el -*- lexical-binding: t; -*-

;;
;; elisp-mode deferral hack
;;

;; `elisp-mode' is loaded at startup. In order to lazy load its config we need
;; to pretend it isn't loaded
(delq 'elisp-mode features)
;; ...until the first time `emacs-lisp-mode' runs
(advice-add #'emacs-lisp-mode :before #'+emacs-lisp|init)

(defun +emacs-lisp|init (&rest _)
  ;; Some plugins (like yasnippet) run `emacs-lisp-mode' early, to parse some
  ;; elisp. This would prematurely trigger this function. In these cases,
  ;; `emacs-lisp-mode-hook' is let-bound to nil or its hooks are delayed, so if
  ;; we see either, keep pretending elisp-mode isn't loaded.
  (when (and emacs-lisp-mode-hook (not delay-mode-hooks))
    ;; Otherwise, announce to the world elisp-mode has been loaded, so `after!'
    ;; handlers can respond and configure elisp-mode as expected.
    (provide 'elisp-mode)
    (advice-remove #'emacs-lisp-mode #'+emacs-lisp|init)))


;;
;; Config
;;

(add-to-list 'auto-mode-alist '("\\.Cask\\'" . emacs-lisp-mode))

(after! elisp-mode
  (set-repl-handler! 'emacs-lisp-mode #'+emacs-lisp/repl)
  (set-eval-handler! 'emacs-lisp-mode #'+emacs-lisp-eval)
  (set-lookup-handlers! 'emacs-lisp-mode
    :definition    #'elisp-def
    :documentation #'info-lookup-symbol)
  (set-docset! 'emacs-lisp-mode "Emacs Lisp")
  (set-pretty-symbols! 'emacs-lisp-mode :lambda "lambda")
  (set-rotate-patterns! 'emacs-lisp-mode
    :symbols '(("t" "nil")
               ("let" "let*")
               ("when" "unless")
               ("append" "prepend")
               ("advice-add" "advice-remove")
               ("add-hook" "remove-hook")
               ("add-hook!" "remove-hook!")))

  ;; variable-width indentation is superior in elisp
  (add-to-list 'doom-detect-indentation-excluded-modes 'emacs-lisp-mode nil #'eq)

  (add-hook! 'emacs-lisp-mode-hook
    #'(;; 3rd-party functionality
       auto-compile-on-save-mode
       ;; fontification
       rainbow-delimiters-mode highlight-quoted-mode
       ;; initialization
       +emacs-lisp|extend-imenu))

  ;; Flycheck produces a *lot* of false positives in emacs configs, so disable
  ;; it when you're editing them
  (add-hook 'flycheck-mode-hook #'+emacs-lisp|disable-flycheck-maybe)

  ;; Special fontification for doom
  (font-lock-add-keywords
   'emacs-lisp-mode
   (append `(;; custom Doom cookies
             ("^;;;###\\(autodef\\|if\\)[ \n]" (1 font-lock-warning-face t))
             ;; highlight defined, special variables & functions
             (+emacs-lisp-highlight-vars-and-faces . +emacs-lisp--face))))

  ;; Recenter window after following definition
  (advice-add #'elisp-def :after #'doom*recenter))


;;
;; Plugins
;;

;; `auto-compile'
(setq auto-compile-display-buffer nil
      auto-compile-use-mode-line nil)


;; `macrostep'
(when (featurep! :feature evil)
  (after! macrostep
    (evil-define-key* 'normal macrostep-keymap
      (kbd "RET") #'macrostep-expand
      "e"         #'macrostep-expand
      "u"         #'macrostep-collapse
      "c"         #'macrostep-collapse

      [tab]       #'macrostep-next-macro
      "\C-n"      #'macrostep-next-macro
      "J"         #'macrostep-next-macro

      [backtab]   #'macrostep-prev-macro
      "K"         #'macrostep-prev-macro
      "\C-p"      #'macrostep-prev-macro

      "q"         #'macrostep-collapse-all
      "C"         #'macrostep-collapse-all)

    ;; `evil-normalize-keymaps' seems to be required for macrostep or it won't
    ;; apply for the very first invocation
    (add-hook 'macrostep-mode-hook #'evil-normalize-keymaps)))


;; `overseer'
(autoload 'overseer-test "overseer" nil t)


(def-package! flycheck-cask
  :when (featurep! :feature syntax-checker)
  :defer t
  :init
  (add-hook! 'emacs-lisp-mode-hook
    (add-hook 'flycheck-mode-hook #'flycheck-cask-setup nil t)))


;;
;; Project modes
;;

(def-project-mode! +emacs-lisp-ert-mode
  :modes (emacs-lisp-mode)
  :match "/test[/-].+\\.el$")

(associate! buttercup-minor-mode
  :modes (emacs-lisp-mode)
  :match "/test[/-].+\\.el$")

(after! buttercup
  (set-yas-minor-mode! 'buttercup-minor-mode))

