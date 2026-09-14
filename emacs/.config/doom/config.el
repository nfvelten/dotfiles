;;; $DOOMDIR/config.el -*- lexical-binding: t; -*-

;; Place your private configuration here! Remember, you do not need to run 'doom
;; sync' after modifying this file!


;; Some functionality uses this to identify you, e.g. GPG configuration, email
;; clients, file templates and snippets. It is optional.
;; (setq user-full-name "John Doe"
;;       user-mail-address "john@doe.com")

;; Doom exposes five (optional) variables for controlling fonts in Doom:
;;
;; - `doom-font' -- the primary font to use
;; - `doom-variable-pitch-font' -- a non-monospace font (where applicable)
;; - `doom-big-font' -- used for `doom-big-font-mode'; use this for
;;   presentations or streaming.
;; - `doom-symbol-font' -- for symbols
;; - `doom-serif-font' -- for the `fixed-pitch-serif' face
;;
;; See 'C-h v doom-font' for documentation and more examples of what they
;; accept. For example:
;;
;;(setq doom-font (font-spec :family "Fira Code" :size 12 :weight 'semi-light)
;;      doom-variable-pitch-font (font-spec :family "Fira Sans" :size 13))
;;
;; If you or Emacs can't find your font, use 'M-x describe-font' to look them
;; up, `M-x eval-region' to execute elisp code, and 'M-x doom/reload-font' to
;; refresh your font settings. If Emacs still can't find your font, it likely
;; wasn't installed correctly. Font issues are rarely Doom issues!

;; There are two ways to load a theme. Both assume the theme is installed and
;; available. You can either set `doom-theme' or manually load a theme with the
;; `load-theme' function. This is the default:
(add-to-list 'custom-theme-load-path "~/.config/emacs/themes")
(setq doom-theme
      (if (let ((hour (string-to-number (format-time-string "%H"))))
            (and (>= hour 7) (< hour 18)))
          'terere
        'yerba-mate))

(defun nf/tty-colors (frame)
  "Keep terminal Emacs readable when the TTY cannot render theme hex colors."
  (unless (display-graphic-p frame)
    (set-face-attribute 'default frame :background "color-236" :foreground "color-188")
    (set-face-attribute 'mode-line frame :background "color-137" :foreground "color-236")
    (set-face-attribute 'mode-line-inactive frame :background "color-239" :foreground "color-188")
    (set-face-attribute 'header-line frame :background "color-236" :foreground "color-137")
    (set-face-attribute 'region frame :background "color-239")
    (set-face-attribute 'font-lock-comment-face frame :foreground "color-65")
    (set-face-attribute 'font-lock-keyword-face frame :foreground "color-109")
    (set-face-attribute 'font-lock-function-name-face frame :foreground "color-108")
    (set-face-attribute 'font-lock-variable-name-face frame :foreground "color-137")
    (set-face-attribute 'font-lock-string-face frame :foreground "color-107")
    (set-face-attribute 'font-lock-constant-face frame :foreground "color-137")
    (set-face-attribute 'font-lock-type-face frame :foreground "color-109")
    (set-face-attribute 'link frame :foreground "color-109" :underline t)))

(add-hook 'after-make-frame-functions #'nf/tty-colors)
;; Specify both a dark and light theme, like so and Doom will choose which one
;; to load based on your system light/dark setting:
;;
;;   (setq doom-theme '(doom-one   . doom-one-light))   ; (DARK . LIGHT)
;;
;; If you want more pro-active theme switching based on OS light/dark mode, look
;; up the `auto-dark' package.

;; This determines the style of line numbers in effect. If set to `nil', line
;; numbers are disabled. For relative line numbers, set this to `relative'.
(setq display-line-numbers-type 'relative)

;; If you use `org' and don't want your org files in the default location below,
;; change `org-directory'. It must be set before org loads!
;; org-agenda-files is rebuilt on every agenda call — see `nf/agenda-files'.
(setq org-directory "~/org/")

(setq doom-font (font-spec :family "JetBrainsMono Nerd Font" :size 15)
      doom-variable-pitch-font (font-spec :family "iA Writer Quattro S" :size 16)
      doom-serif-font (font-spec :family "iA Writer Quattro S" :size 16))

(setq confirm-kill-emacs nil
      delete-by-moving-to-trash t
      save-interprogram-paste-before-kill t
      scroll-margin 4
      evil-want-fine-undo t
      which-key-idle-delay 0.35)

(defun nf/org-file (name)
  (expand-file-name name org-directory))

(defun nf/find-org-file (name)
  (find-file (nf/org-file name)))

(defun nf/org-agenda-command (key)
  (org-agenda nil key))

(defvar nf/agenda-daily-days 14
  "How many days of daily notes feed the agenda.")

(defun nf/agenda-files ()
  "Task sources: recent daily notes plus personal and active work projects.
Daily notes are picked by the date in their filename (dd-mm-yyyy.org), not mtime."
  (let ((cutoff (time-subtract nil (days-to-time nf/agenda-daily-days))))
    (append
     (seq-filter
      (lambda (f)
        (when (string-match "\\([0-9]\\{2\\}\\)-\\([0-9]\\{2\\}\\)-\\([0-9]\\{4\\}\\)\\.org\\'" f)
          (time-less-p cutoff (encode-time (list 0 0 0
                                                 (string-to-number (match-string 1 f))
                                                 (string-to-number (match-string 2 f))
                                                 (string-to-number (match-string 3 f)))))))
      (directory-files-recursively (nf/org-file "Daily Notes") "\\.org\\'"))
     (directory-files (nf/org-file "Pessoal/Projetos") t "\\.org\\'")
     (directory-files (nf/org-file "Trabalho/Air/Demandas/Em Desenvolvimento") t "\\.org\\'"))))

(defun nf/refresh-agenda-files (&rest _)
  (setq org-agenda-files (nf/agenda-files)))

(advice-add 'org-agenda :before #'nf/refresh-agenda-files)

(defconst nf/pt-months
  ["Janeiro" "Fevereiro" "Março" "Abril" "Maio" "Junho"
   "Julho" "Agosto" "Setembro" "Outubro" "Novembro" "Dezembro"])

(defun nf/daily-note ()
  "Open today's daily note, creating it from the vault template."
  (interactive)
  (require 'org-capture)
  (let* ((month (aref nf/pt-months (1- (decoded-time-month (decode-time)))))
         (file (nf/org-file (format-time-string
                             (format "Daily Notes/%%Y/%s/%%d-%%m-%%Y.org" month))))
         (new (not (file-exists-p file))))
    (make-directory (file-name-directory file) t)
    (find-file file)
    (when new
      (insert (org-capture-fill-template
               (with-temp-buffer
                 (insert-file-contents (nf/org-file "Templates/Daily Notes.org"))
                 (buffer-string)))))))

(after! org
  (setq org-ellipsis "..."
        org-hide-emphasis-markers t
        org-startup-indented t
        org-startup-folded 'content
        org-pretty-entities t
        org-log-done 'time
        org-log-into-drawer t
        org-return-follows-link t
        org-cycle-separator-lines 1
        org-use-speed-commands t
        org-todo-keywords
        '((sequence "TODO(t)" "NEXT(n)" "WAIT(w@/!)" "HOLD(h@/!)" "|" "DONE(d!)" "KILL(k@)"))
        org-todo-keyword-faces
        '(("TODO" . warning)
          ("NEXT" . success)
          ("WAIT" . font-lock-doc-face)
          ("HOLD" . font-lock-comment-face)
          ("KILL" . error))
        org-tag-alist
        '((:startgroup)
          ("work" . ?w)
          ("personal" . ?p)
          ("study" . ?s)
          ("setup" . ?u)
          ("code" . ?c)
          (:endgroup)
          ("ai" . ?a)
          ("unix" . ?x)
          ("emacs" . ?e))
        org-refile-targets
        '((nil :maxlevel . 3)
          (org-agenda-files :maxlevel . 3))
        org-outline-path-complete-in-steps nil
        org-refile-use-outline-path 'file
        org-agenda-window-setup 'current-window
        org-agenda-span 'day
        org-agenda-start-on-weekday nil
        org-agenda-skip-scheduled-if-done t
        org-agenda-skip-deadline-if-done t
        org-agenda-custom-commands
        '(("o" "Open checkboxes"
           ((search "{^[ \t]*- \\[ \\]}"
                    ((org-agenda-overriding-header
                      "Open [ ] — recent dailies, Pessoal/Projetos, Demandas em desenvolvimento")))))))

  (map! :map org-mode-map
        :localleader
        "a" #'org-agenda
        "r" #'org-refile
        "s" #'org-schedule
        "d" #'org-deadline
        "t" #'org-todo))

(after! org-agenda
  (setq org-agenda-prefix-format
        '((agenda . " %i %-12:c%?-12t% s")
          (todo . " %i %-12:c")
          (tags . " %i %-12:c")
          (search . " %i %-12:c"))))

(map! :leader
      :desc "Find files" "SPC" #'projectile-find-file
      :desc "Buffers" "," #'consult-buffer
      :desc "Grep project" "/" #'+default/search-project
      :desc "Command" ":" #'execute-extended-command
      (:prefix ("f" . "file")
       :desc "Find file" "f" #'projectile-find-file
       :desc "Find file cwd" "F" #'find-file
       :desc "Find config" "c" (cmd! (doom-project-find-file doom-user-dir))
       :desc "Recent files" "r" #'consult-recent-file
       :desc "Buffers" "b" #'consult-buffer
       :desc "Projects" "p" #'projectile-switch-project)
      (:prefix ("g" . "git")
       :desc "Git status" "s" #'magit-status
       :desc "Git status" "g" #'magit-status
       :desc "Git diff" "d" #'magit-diff-unstaged
       :desc "Git log" "l" #'magit-log-current)
      (:prefix ("s" . "search")
       :desc "Grep project" "g" #'+default/search-project
       :desc "Grep cwd" "G" #'+default/search-cwd
       :desc "Buffer lines" "b" #'consult-line
       :desc "Help" "h" #'helpful-at-point
       :desc "Keymaps" "k" #'describe-keymap
       :desc "Resume" "R" #'consult-resume)
      (:prefix ("b" . "buffer")
       :desc "Switch buffer" "b" #'consult-buffer
       :desc "Kill buffer" "d" #'kill-current-buffer
       :desc "Next buffer" "n" #'next-buffer
       :desc "Previous buffer" "p" #'previous-buffer)
      (:prefix ("o" . "open")
       :desc "Org agenda" "a" #'org-agenda
       :desc "Elfeed" "e" #'elfeed
       :desc "Daily note" "j" #'nf/daily-note)
      (:prefix ("w" . "window")
       :desc "Window left" "h" #'evil-window-left
       :desc "Window down" "j" #'evil-window-down
       :desc "Window up" "k" #'evil-window-up
       :desc "Window right" "l" #'evil-window-right
       :desc "Split below" "s" #'evil-window-split
       :desc "Split right" "v" #'evil-window-vsplit
       :desc "Delete window" "d" #'evil-window-delete))

(map! :after org
      :map org-mode-map
      :n "," nil
      :n ",a" #'org-agenda
      :n ",r" #'org-refile
      :n ",s" #'org-schedule
      :n ",d" #'org-deadline
      :n ",t" #'org-todo
      :n ",j" #'nf/daily-note)

(add-hook! 'org-mode-hook
  #'visual-line-mode
  #'variable-pitch-mode)

(defun nf/elfeed-play-at-point ()
  "Play the Elfeed entry at point in mpv."
  (interactive)
  (let* ((entry (if (derived-mode-p 'elfeed-search-mode)
                    (elfeed-search-selected :single)
                  elfeed-show-entry))
         (url (and entry (elfeed-entry-link entry))))
    (unless url
      (user-error "No Elfeed entry selected"))
    (start-process "elfeed-mpv" nil "mpv" "--force-window=yes" url)
    (message "Playing in mpv: %s" url)))

(after! elfeed
  (setq elfeed-search-filter "@6-months-ago")
  (map! :map elfeed-search-mode-map
        :localleader
        "u" #'elfeed-update
        "p" #'nf/elfeed-play-at-point
        "f" #'elfeed-tube-fetch)
  (map! :map elfeed-show-mode-map
        :localleader
        "p" #'nf/elfeed-play-at-point
        "f" #'elfeed-tube-fetch)
  ;; Keep the common action one key away in Evil normal mode.
  (map! :map elfeed-search-mode-map :n "p" #'nf/elfeed-play-at-point)
  (map! :map elfeed-show-mode-map :n "p" #'nf/elfeed-play-at-point))

(after! elfeed-org
  (setq rmh-elfeed-org-files (list (expand-file-name "elfeed.org" org-directory)))
  (elfeed-org))

(after! elfeed-tube
  (elfeed-tube-setup))

(after! elfeed-tube-mpv
  (define-key elfeed-show-mode-map (kbd "C-c C-f") #'elfeed-tube-mpv-follow-mode)
  (define-key elfeed-show-mode-map (kbd "C-c C-w") #'elfeed-tube-mpv-where))

(custom-set-faces!
  '(org-document-title :height 1.25 :weight bold)
  '(org-level-1 :height 1.18 :weight bold)
  '(org-level-2 :height 1.10 :weight bold)
  '(org-level-3 :height 1.05 :weight semi-bold)
  '(org-block :inherit fixed-pitch)
  '(org-code :inherit fixed-pitch)
  '(org-table :inherit fixed-pitch)
  '(org-verbatim :inherit fixed-pitch))


;; Whenever you reconfigure a package, make sure to wrap your config in an
;; `with-eval-after-load' block, otherwise Doom's defaults may override your
;; settings. E.g.
;;
;;   (with-eval-after-load 'PACKAGE
;;     (setq x y))
;;
;; The exceptions to this rule:
;;
;;   - Setting file/directory variables (like `org-directory')
;;   - Setting variables which explicitly tell you to set them before their
;;     package is loaded (see 'C-h v VARIABLE' to look them up).
;;   - Setting doom variables (which start with 'doom-' or '+').
;;
;; Here are some additional functions/macros that will help you configure Doom.
;;
;; - `load!' for loading external *.el files relative to this one
;; - `add-load-path!' for adding directories to the `load-path', relative to
;;   this file. Emacs searches the `load-path' when you load packages with
;;   `require' or `use-package'.
;; - `map!' for binding new keys
;;
;; To get information about any of these functions/macros, move the cursor over
;; the highlighted symbol at press 'K' (non-evil users must press 'C-c c k').
;; This will open documentation for it, including demos of how they are used.
;; Alternatively, use `C-h o' to look up a symbol (functions, variables, faces,
;; etc).
;;
;; You can also try 'gd' (or 'C-c c d') to jump to their definition and see how
;; they are implemented.
