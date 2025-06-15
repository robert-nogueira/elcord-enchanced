;;; elcord.el --- Integrates Discord Rich Presence with extra theme customizations  -*- lexical-binding: t; -*-

;; Copyright (C) 2017 heatingdevice

;; Author: heatingdevice
;;  Wilfredo Velázquez-Rodríguez <zulu.inuoe@gmail.com>
;; Forked and modified by: robert-nogueira
;; Created: 21 Nov 2017
;; Version: 1.1.0-weeb
;; Keywords: games, discord, rich-presence
;; Homepage: https://github.com/Robert-Nogueira/elcord-weeb
;; Package-Requires: ((emacs "25.1"))
;; License: MIT

;;; Commentary:
;; Fork of elcord adding support a custom theme and icon set.
;; Shows buffer info on Discord with personalized icons.
;; Enable `elcord-mode` to activate.
;; Updates 'Playing a Game' status with Emacs title, major mode icon,
;; buffer name, and cursor position.
;; Customize `elcord-display-buffer-details` to hide buffer name and line numbers.

;;; Code:

(require 'bindat)
(require 'cl-lib)
(require 'json)
(require 'subr-x)

(defgroup elcord nil
  "Options for elcord."
  :prefix "elcord-"
  :group 'external)

(defcustom elcord-client-id "1382406746445709412"
  "ID of elcord client (Application ID).
See <https://discordapp.com/developers/applications/me>."
  :type '(choice (const :tag "'Native' Application ID" "1382406746445709412")
                 (string :tag "Use the specified ID")
                 (function :tag "Call the function with no args to get the ID."))
  :group 'elcord)

(defcustom elcord-switch-icons nil
  "When non-nil, swap the large and small icons.
This makes the mode icon appear as the large icon
and the editor icon as the small one."
  :type 'boolean
  :group 'elcord)

(defcustom elcord-use-original-icons nil
  "If non-nil, use the original elcord icons."
  :type 'boolean
  :group 'elcord)

(defcustom elcord-icon-base
  (if elcord-use-original-icons
      "https://raw.githubusercontent.com/Mstrodl/elcord/master/icons/"
    "https://raw.githubusercontent.com/robert-nogueira/elcord-enchanced/master/icons/")
  "Base URL for icon images.
Mode icons will be loaded from this URL + icon name + '.png'"
  :type '(choice (const :tag "Elcord GitHub Repository"
			"https://raw.githubusercontent.com/Mstrodl/elcord/master/icons/")
                 (const :tag "Elcord-Weeb GitHub Repository"
			"https://raw.githubusercontent.com/Robert-Nogueira/elcord-weeb/master/icons/")
                 (string :tag "Use the specified URL base")
                 (function :tag "Call the function with icon name as an arg to get the URL base."))
  :group 'elcord)

(defun elcord--make-buttons (&optional button1 button2)
  "Create Discord Rich Presence buttons list.
BUTTON1 and BUTTON2 are cons cells of the form (LABEL . URL)."
  (let ((buttons ()))
    (when button1
      (push `((:label . ,(car button1))
              (:url . ,(cdr button1))) buttons))
    (when button2
      (push `((:label . ,(car button2))
              (:url . ,(cdr button2))) buttons))
    (when buttons
      `(("buttons" . ,(vconcat buttons))))))

(defcustom elcord-buttons nil
  "List of buttons to display in Discord Rich Presence.
Each button is a cons cell of the form (LABEL . URL).
Maximum of 2 buttons allowed."
  :type '(repeat (cons (string :tag "Label")
                       (string :tag "URL")))
  :group 'elcord)

(defcustom elcord-refresh-rate 15
  "How often to send updates to Discord, in seconds."
  :type 'integer
  :group 'elcord)

(defcustom elcord-idle-timer 300
  "How long to wait before setting the status to idle."
  :type 'integer
  :group 'elcord)

(defcustom elcord-idle-message "Getting something to drink..."
  "Message to show when elcord status is idle."
  :type 'string
  :group 'elcord)

(defcustom elcord-quiet nil
  "Whether or not to supress elcord messages.
This includes connecting, disconnecting, etc."
  :type 'boolean
  :group 'elcord)

(defcustom elcord-mode-icon-alist '((agda-mode . "agda-mode_icon")
                                    (assembly-mode . "assembly-mode_icon")
                                    (bqn-mode . "bqn-mode_icon")
                                    (c-mode . "c-mode_icon")
                                    (c++-mode . "cpp-mode_icon")
                                    (clojure-mode . "clojure-mode_icon")
                                    (csharp-mode . "csharp-mode_icon")
                                    (comint-mode . "comint-mode_icon")
                                    (cperl-mode . "cperl-mode_icon")
                                    (dockerfile-mode . "dockerfile-mode_icon")
                                    (elixir-mode . "elixir-mode_icon")
                                    (emacs-lisp-mode . (elcord--editor-icon))
                                    (enh-ruby-mode . "ruby-mode_icon")
				    (conf-mode . "conf-mode_icon")
                                    (erc-mode . "irc-mode_icon")
                                    (erlang-mode . "erlang-mode_icon")
                                    (forth-mode . "forth-mode_icon")
                                    (fortran-mode . "fortran-mode_icon")
                                    (fsharp-mode . "fsharp-mode_icon")
                                    (gdscript-mode . "gdscript-mode_icon")
                                    (haskell-mode . "haskell-mode_icon")
                                    (haskell-interactive-mode . "haskell-mode_icon")
                                    (hy-mode . "hy-mode_icon")
                                    (java-mode . "java-mode_icon")
                                    (julia-mode . "julia-mode_icon")
                                    (js-mode . "javascript-mode_icon")
                                    (kotlin-mode . "kotlin-mode_icon")
                                    (go-mode . "go-mode_icon")
                                    (latex-mode . "latex-mode_icon")
                                    (lisp-mode . "lisp-mode_icon")
                                    (lua-mode . "lua-mode_icon")
                                    (magit-mode . "magit-mode_icon")
                                    (markdown-mode . "markdown-mode_icon")
                                    (meson-mode . "meson-mode_icon")
                                    (nasm-mode . "nasm-mode_icon")
                                    (nim-mode . "nim-mode_icon")
                                    (nix-mode . "nix-mode_icon")
                                    (ocaml-mode . "ocaml-mode_icon")
                                    (octave-mode . "octave-mode_icon")
                                    (org-mode . "org-mode_icon")
                                    (pascal-mode . "pascal-mode_icon")
                                    (php-mode . "php-mode_icon")
                                    (prolog-mode . "prolog-mode_icon")
                                    (puml-mode . "puml-mode_icon")
                                    (puppet-mode . "puppet-mode_icon")
                                    (python-mode . "python-mode_icon")
                                    (racket-mode . "racket-mode_icon")
                                    (ruby-mode . "ruby-mode_icon")
                                    (rust-mode . "rust-mode_icon")
                                    (rustic-mode . "rust-mode_icon")
                                    (scala-mode . "scala-mode_icon")
                                    (solidity-mode . "solidity-mode_icon")
                                    (sh-mode . "comint-mode_icon")
                                    (terraform-mode . "terraform-mode_icon")
                                    (typescript-mode . "typescript-mode_icon")
                                    (zig-mode . "zig-mode_icon")
                                    (janet-mode . "janet-mode_icon")
                                    ("^slime-.*" . "lisp-mode_icon")
                                    ("^sly-.*$" . "lisp-mode_icon"))
  "Mapping alist of major modes to icon names to have elcord use.
Note, these icon names must be available as 'small_image' in Discord."
  :type '(alist :key-type (choice (symbol :tag "Mode name")
                                  (regexp :tag "Regex"))
                :value-type (choice (string :tag "Icon name")
                                    (function :tag "Mapping function")))
  :group 'elcord)

(defcustom elcord-mode-text-alist '((agda-mode . "Agda")
                                   (assembly-mode . "Assembly")
                                   (bqn-mode . "BQN")
                                   (c-mode . "C  ")
                                   (c++-mode . "C++")
                                   (csharp-mode . "C#")
                                   (cperl-mode . "Perl")
                                   (elixir-mode . "Elixir")
                                   (enh-ruby-mode . "Ruby")
                                   (erlang-mode . "Erlang")
                                   (fsharp-mode . "F#")
                                   (gdscript-mode . "GDScript")
                                   (java-mode . "Java")
                                   (julia-mode . "Julia")
                                   (lisp-mode . "Common Lisp")
                                   (markdown-mode . "Markdown")
                                   (magit-mode . "It's Magit!")
                                   ("mhtml-mode" . "HTML")
                                   (nasm-mode . "NASM")
                                   (nim-mode . "Nim")
                                   (ocaml-mode . "OCaml")
                                   (pascal-mode . "Pascal")
                                   (prolog-mode . "Prolog")
                                   (puml-mode . "UML")
                                   (scala-mode . "Scala")
                                   (sh-mode . "Shell")
                                   (slime-repl-mode . "SLIME-REPL")
                                   (sly-mrepl-mode . "Sly-REPL")
                                   (solidity-mode . "Solidity")
                                   (terraform-mode . "Terraform")
                                   (typescript-mode . "Typescript")
                                   (php-mode "PHP"))
  "Mapping alist of major modes to text labels to have elcord use."
  :type '(alist :key-type (choice (symbol :tag "Mode name")
                                  (regexp :tag "Regex"))
                :value-type (choice (string :tag "Text label")
                                   (function :tag "Mapping function")))
  :group 'elcord)

(defcustom elcord-display-elapsed t
  "When enabled, Discord status will display the elapsed time.
This shows how long Emacs has been started."
  :type 'boolean
  :group 'elcord)

(defvar elcord--startup-time (string-to-number (format-time-string "%s" (current-time))))

(defcustom elcord-display-buffer-details t
  "When enabled, Discord status will display buffer name and line numbers:
\"Editing <buffer-name>\"
\"Line <line-number> (<line-number> of <line-count>)\"

Otherwise, it will display:
\"Editing\"
\"<elcord-mode-text>\""
  :type 'boolean
  :group 'elcord)

(defcustom elcord-display-line-numbers t
  "When enabled, shows the total line numbers of current buffer.
Including the position of the cursor in the buffer."
  :type 'boolean
  :group 'elcord)

(defcustom elcord-buffer-details-format-function 'elcord-buffer-details-format
  "Function to return the buffer details string shown on discord.
Swap this with your own function if you want a custom buffer-details message."
  :type 'function
  :group 'elcord)

(defcustom elcord-use-major-mode-as-main-icon nil
  "When enabled, the major mode determines the main icon.
Rather than it being the editor."
  :type 'boolean
  :group 'elcord)

(defcustom elcord-show-small-icon t
  "When enabled, show the small icon as well as the main icon."
  :type 'boolean
  :group 'elcord)

(defcustom elcord-editor-icon nil
  "Icon to use for the text editor.
When nil, use the editor's native icon."
  :type '(choice (const :tag "Editor Default" nil)
                 (const :tag "Emacs" "emacs_icon")
                 (const :tag "Emacs (Pen)" "emacs_pen_icon")
                 (const :tag "Emacs (Material)" "emacs_material_icon")
                 (const :tag "Emacs (Legacy)" "emacs_legacy_icon")
                 (const :tag "Emacs (Dragon)" "emacs_dragon_icon")
                 (const :tag "Spacemacs" "spacemacs_icon")
                 (const :tag "Doom" "doom_icon")
                 (const :tag "Doom Cute" "doom_cute_icon"))
  :group 'elcord)

(defcustom elcord-boring-buffers-regexp-list '("^ " "\\\\*Messages\\\\*")
  "A list of regexp's to match boring buffers.
When visiting a boring buffer, it will not show in the elcord presence."
  :type '(repeat regexp)
  :group 'elcord)

(defcustom elcord-discord-ipc-path nil
  "Path to the Discord IPC pipe.
When nil, the default path is used."
  :type 'string
  :group 'elcord)

;;;###autoload
(define-minor-mode elcord-mode
  "Global minor mode for displaying Rich Presence in Discord."
  nil nil nil
  :require 'elcord
  :global t
  :group 'elcord
  :after-hook
  (progn
    (cond
     (elcord-mode
      (elcord--enable))
     (t
      (elcord--disable)))))

(defvar elcord--editor-name
  (cond
   ((boundp 'spacemacs-version) "Spacemacs")
   ((boundp 'doom-version) "DOOM Emacs")
   (t "Emacs"))
  "The name to use to represent the current editor.")

(defvar elcord--discord-ipc-pipe-format "discord-ipc-%d"
  "The name of the discord IPC pipe.")

(defvar elcord--update-presence-timer nil
  "Timer which periodically updates Discord Rich Presence.
nil when elcord is not active.")

(defvar elcord--reconnect-timer nil
  "Timer used by elcord to attempt connection periodically.
When active but disconnected.")

(defvar elcord--sock nil
  "The process used to communicate with Discord IPC.")

(defvar elcord--last-known-position (count-lines (point-min) (point))
  "Last known position (line number) recorded by elcord.")

(defvar elcord--last-known-buffer-name (buffer-name)
  "Last known buffer recorded by elcord.")

(defvar elcord--stdpipe-path (expand-file-name
                             "stdpipe.ps1"
                             (file-name-directory (file-truename load-file-name)))
  "Path to the 'stdpipe' script.
On Windows, this script is used as a proxy for the Discord named pipe.
Unused on other platforms.")

(defvar elcord--idle-status nil
  "Current idle status.")

(defun elcord--set-presence ()
  "Set presence with optional buttons."
  (let* ((buttons (when elcord-buttons
                   (elcord--make-buttons
                    (nth 0 elcord-buttons)
                    (nth 1 elcord-buttons))))
         (activity
          `(("assets" . (,@(elcord--mode-icon-and-text)))
            ,@(elcord--details-and-state)
            ,@buttons))
         (nonce (format-time-string "%s%N"))
         (presence
          `(("cmd" . "SET_ACTIVITY")
            ("args" . (("activity" . ,activity)
                       ("pid" . ,(emacs-pid))))
            ("nonce" . ,nonce))))
    (elcord--send-packet 1 presence)))

(defun elcord--find-discord-ipc-pipe ()
  "Find the path to the Discord IPC pipe."
  (if elcord-discord-ipc-path
      elcord-discord-ipc-path
    (let ((candidates
           (mapcan
            (lambda (dir)
              (mapcar
               (lambda (num)
                 (expand-file-name (format elcord--discord-ipc-pipe-format num) dir))
               (number-sequence 0 9)))
            (list (expand-file-name "app/com.discordapp.Discord"
                                    (getenv "XDG_RUNTIME_DIR"))
                  (getenv "XDG_RUNTIME_DIR")
                  (getenv "TMPDIR")
                  (getenv "TMP")
                  (getenv "TEMP")
                  "/tmp"))))
      (cl-loop for candidate in candidates
               until (file-exists-p candidate)
               finally return candidate))))

(defun elcord--make-process ()
  "Make the asynchronous process that communicates with Discord IPC."
  (let ((default-directory "~/"))
    (cl-case system-type
      (windows-nt
       (make-process
        :name "*elcord-sock*"
        :command (list
                  "PowerShell"
                  "-NoProfile"
                  "-ExecutionPolicy" "Bypass"
                  "-Command" elcord--stdpipe-path "." (format elcord--discord-ipc-pipe-format 0))
        :connection-type 'pipe
        :sentinel 'elcord--connection-sentinel
        :filter 'elcord--connection-filter
        :noquery t))
      (t
       (make-network-process
        :name "*elcord-sock*"
        :remote (elcord--find-discord-ipc-pipe)
        :service nil
        :sentinel 'elcord--connection-sentinel
        :filter 'elcord--connection-filter
        :noquery t)))))

(defun elcord--enable ()
  "Called when variable 'elcord-mode' is enabled."
  (setq elcord--startup-time (string-to-number (format-time-string "%s" (current-time))))
  (unless (elcord--resolve-client-id)
    (warn "elcord: no elcord-client-id available"))
  (when (eq system-type 'windows-nt)
    (unless (executable-find "powershell")
      (warn "elcord: powershell not available"))
    (unless (file-exists-p elcord--stdpipe-path)
      (warn "elcord: 'stdpipe' script does not exist (%s)" elcord--stdpipe-path)))
  (when elcord-idle-timer
    (run-with-idle-timer
     elcord-idle-timer t 'elcord--start-idle))
  (elcord--start-reconnect))

(defun elcord--disable ()
  "Called when variable 'elcord-mode' is disabled."
  (elcord--cancel-updates)
  (elcord--cancel-reconnect)
  (when elcord--sock
    (elcord--empty-presence))
  (cancel-function-timers 'elcord--start-idle)
  (elcord--disconnect))

(defun elcord--empty-presence ()
  "Sends an empty presence for when elcord is disabled."
  (let* ((nonce (format-time-string "%s%N"))
         (presence
          `(("cmd" . "SET_ACTIVITY")
            ("args" . (("activity" . nil)
                       ("pid" . ,(emacs-pid))))
            ("nonce" . ,nonce))))
    (elcord--send-packet 1 presence)))

(defun elcord--resolve-client-id ()
  "Evaluate 'elcord-client-id' and return the client ID to use."
  (cl-typecase elcord-client-id
    (null nil)
    (string elcord-client-id)
    (function (funcall elcord-client-id))))

(defun elcord--resolve-icon-base (icon)
  "Evaluate 'elcord-icon-base' and return the URL to use.
Argument ICON the name of the icon we're resolving."
  (cl-typecase elcord-icon-base
    (null nil)
    (string (concat elcord-icon-base icon ".png"))
    (function (funcall elcord-icon-base icon))))

(defun elcord--connection-sentinel (process evnt)
  "Track connection state change on Discord connection."
  (cl-case (process-status process)
    ((closed exit) (elcord--handle-disconnect))
    (t nil)))

(defun elcord--connection-filter (process evnt)
  "Track incoming data from Discord connection."
  (elcord--start-updates))

(defun elcord--connect ()
  "Connects to the Discord socket."
  (or elcord--sock
      (ignore-errors
        (unless elcord-quiet
          (message "elcord: attempting reconnect.."))
        (setq elcord--sock (elcord--make-process))
        (condition-case nil
            (elcord--send-packet 0 `(("v" . 1) ("client_id" . ,(elcord--resolve-client-id))))
          (error
           (delete-process elcord--sock)
           (setq elcord--sock nil)))
        elcord--sock)))

(defun elcord--disconnect ()
  "Disconnect elcord."
  (when elcord--sock
    (delete-process elcord--sock)
    (setq elcord--sock nil)))

(defun elcord--reconnect ()
  "Attempt to reconnect elcord."
  (when (elcord--connect)
    (unless (or elcord--update-presence-timer elcord-quiet)
      (message "elcord: connecting..."))
    (elcord--cancel-reconnect)))

(defun elcord--start-reconnect ()
  "Start attempting to reconnect."
  (unless (or elcord--sock elcord--reconnect-timer)
    (setq elcord--reconnect-timer (run-at-time 0 15 'elcord--reconnect))))

(defun elcord--cancel-reconnect ()
  "Cancels any ongoing reconnection attempt."
  (when elcord--reconnect-timer
    (cancel-timer elcord--reconnect-timer)
    (setq elcord--reconnect-timer nil)))

(defun elcord--handle-disconnect ()
  "Handles reconnecting when socket disconnects."
  (unless elcord-quiet
    (message "elcord: disconnected by remote host"))
  (elcord--cancel-updates)
  (setq elcord--sock nil)
  (when elcord-mode
    (elcord--start-reconnect)))

(defun elcord--send-packet (opcode obj)
  "Packs and sends a packet to the IPC server."
  (let* ((jsonstr (encode-coding-string (json-encode obj) 'utf-8))
         (datalen (length jsonstr))
         (message-spec `((:op u32r) (:len u32r) (:data str ,datalen)))
         (packet (bindat-pack message-spec
                             `((:op . ,opcode)
                               (:len . ,datalen)
                               (:data . ,jsonstr)))))
    (when elcord--sock
      (process-send-string elcord--sock packet))))

(defun elcord--test-match-p (test mode)
  "Test 'MODE' against 'TEST'."
  (cl-typecase test
    (symbol (eq test mode))
    (string (string-match-p test (symbol-name mode)))))

(defun elcord--entry-value (entry mode)
  "Test 'ENTRY' against 'MODE'. Return the value of 'ENTRY'."
  (when (elcord--test-match-p (car entry) mode)
    (let ((mapping (cdr entry)))
      (cl-typecase mapping
        (string mapping)
        (function (funcall mapping mode))))))

(defun elcord--find-mode-entry (alist mode)
  "Get the first entry in 'ALIST' matching 'MODE'."
  (let ((cell alist) (result nil))
    (while cell
      (setq result (elcord--entry-value (car cell) mode)
            cell (if result nil (cdr cell))))
    result))

(defun elcord--editor-icon ()
  "The icon to use to represent the current editor."
  (elcord--resolve-icon-base
   (cond
    (elcord-editor-icon elcord-editor-icon)
    ((boundp 'spacemacs-version) "spacemacs_icon")
    ((boundp 'doom-version) "doom_icon")
    (t "emacs_icon"))))

(defun elcord--mode-icon ()
  "Figure out what icon to use for the current major mode."
  (let ((mode major-mode)
        (ret (elcord--editor-icon)))
    (while mode
      (if-let ((icon (elcord--find-mode-entry elcord-mode-icon-alist mode)))
          (setq ret (elcord--resolve-icon-base icon)
                mode nil)
        (setq mode (get mode 'derived-mode-parent))))
    ret))

(defun elcord--mode-text ()
  "Figure out what text to use for the current major mode."
  (let ((mode major-mode)
        (ret mode-name))
    (while mode
      (if-let ((text (elcord--find-mode-entry elcord-mode-text-alist mode)))
          (setq ret text
                mode nil)
        (setq mode (get mode 'derived-mode-parent))))
    (unless (stringp ret)
      (setq ret (format-mode-line ret)))
    ret))

(defun elcord--mode-icon-and-text ()
  "Obtain the icon & text to use for the current major mode."
  (let ((text (elcord--mode-text))
        (icon (elcord--mode-icon))
        large-text large-image
        small-text small-image)
    (cond
     ((or elcord-use-major-mode-as-main-icon elcord-switch-icons)
      (setq large-text text
            large-image icon
            small-text elcord--editor-name
            small-image (elcord--editor-icon)))
     (t
      (setq large-text elcord--editor-name
            large-image (elcord--editor-icon)
            small-text text
            small-image icon)))
    (cond
     (elcord-show-small-icon
      (list
       (cons "large_text" large-text)
       (cons "large_image" large-image)
       (cons "small_text" small-text)
       (cons "small_image" small-image)))
     (t
      (list
       (cons "large_text" large-text)
       (cons "large_image" large-image)
       (cons "small_text" small-text))))))

(defun elcord-buffer-details-format ()
  "Return the buffer details string shown on discord."
  (format "Editing %s" (buffer-name)))

(defun elcord--details-and-state ()
  "Obtain the details and state to use for Discord's Rich Presence."
  (let ((activity (if elcord-display-buffer-details
                      (if elcord-display-line-numbers
                          (list
                           (cons "details" (funcall elcord-buffer-details-format-function))
                           (cons "state" (format "Line %s of %S"
                                                 (format-mode-line "%l")
                                                 (+ 1 (count-lines (point-min) (point-max))))))
                        (list
                         (cons "details" (funcall elcord-buffer-details-format-function))))
                    (list
                     (cons "details" "Editing")
                     (cons "state" (elcord--mode-text))))))
    (when elcord-display-elapsed
      (push (list "timestamps" (cons "start" elcord--startup-time)) activity))
    activity))

(defun elcord--buffer-boring-p (buffer-name)
  "Return non-nil if 'BUFFER-NAME' is non-boring."
  (let ((cell elcord-boring-buffers-regexp-list) (result nil))
    (while cell
      (if (string-match-p (car cell) buffer-name)
          (setq result t
                cell nil)
        (setq cell (cdr cell))))
    result))

(defun elcord--find-non-boring-window ()
  "Try to find a live window displaying a non-boring buffer."
  (let ((cell (window-list)) (result nil))
    (while cell
      (let ((window (car cell)))
        (if (not (elcord--buffer-boring-p (buffer-name (window-buffer window))))
            (setq result window
                  cell nil)
          (setq cell (cdr cell)))))
    result))

(defun elcord--try-update-presence (new-buffer-name new-buffer-position)
  "Try updating presence with new buffer info."
  (setq elcord--last-known-buffer-name new-buffer-name
        elcord--last-known-position new-buffer-position)
  (condition-case err
      (elcord--set-presence)
    (error
     (message "elcord: error setting presence: %s" (error-message-string err))
     (elcord--cancel-updates)
     (elcord--disconnect)
     (elcord--start-reconnect))))

(defun elcord--update-presence ()
  "Conditionally update presence by testing current buffer/line."
  (if (= elcord--last-known-position -1)
      (when-let ((window (elcord--find-non-boring-window)))
        (with-current-buffer (window-buffer window)
          (elcord--try-update-presence (buffer-name) (count-lines (point-min) (point)))))
    (let ((new-buffer-name (buffer-name (current-buffer))))
      (unless (elcord--buffer-boring-p new-buffer-name)
        (let ((new-buffer-position (count-lines (point-min) (point))))
          (unless (and (string= new-buffer-name elcord--last-known-buffer-name)
                       (= new-buffer-position elcord--last-known-position))
            (elcord--try-update-presence new-buffer-name new-buffer-position)))))))

(defun elcord--start-updates ()
  "Start sending periodic update to Discord Rich Presence."
  (unless elcord--update-presence-timer
    (unless elcord-quiet
      (message "elcord: connected. starting updates"))
    (setq elcord--last-known-position -1
          elcord--last-known-buffer-name ""
          elcord--update-presence-timer (run-at-time 0 elcord-refresh-rate 'elcord--update-presence))))

(defun elcord--cancel-updates ()
  "Stop sending periodic update to Discord Rich Presence."
  (when elcord--update-presence-timer
    (cancel-timer elcord--update-presence-timer)
    (setq elcord--update-presence-timer nil)))

(defun elcord--start-idle ()
  "Set presence to idle, pause update and timer."
  (unless elcord--idle-status
    (unless elcord-quiet
      (message (format "elcord: %s" elcord-idle-message)))
    (cancel-timer elcord--update-presence-timer)
    (setq elcord--startup-time (string-to-number (format-time-string "%s" (time-subtract nil elcord--startup-time)))
          elcord--idle-status t)
    (let* ((activity `(("assets" . (,@(elcord--mode-icon-and-text)))
                       ("timestamps" ("start" ,(string-to-number (format-time-string "%s" (current-time)))))
                       ("details" . "Idle")
                       ("state" . ,elcord-idle-message)))
           (nonce (format-time-string "%s%N"))
           (presence `(("cmd" . "SET_ACTIVITY")
                       ("args" . (("activity" . ,activity)
                                  ("pid" . ,(emacs-pid))))
                       ("nonce" . ,nonce))))
      (elcord--send-packet 1 presence))
    (add-hook 'pre-command-hook 'elcord--cancel-idle)))

(defun elcord--cancel-idle ()
  "Resume presence update and timer."
  (when elcord--idle-status
    (remove-hook 'pre-command-hook 'elcord--cancel-idle)
    (setq elcord--startup-time (string-to-number (format-time-string "%s" (time-subtract nil elcord--startup-time)))
          elcord--idle-status nil
          elcord--update-presence-timer nil)
    (elcord--start-updates)
    (unless elcord-quiet
      (message "elcord: welcome back"))))

(provide 'elcord)
;;; elcord.el ends here
