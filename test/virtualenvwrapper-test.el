;; Rudimentary test suite for virtualenvwrapper.el

;; WARNING I am fairly confident these tests are safe to run -- they
;; do everything in a tmp dir and clean up after themselves. However
;; they do modify the filesystem and filesystems are horrible, so use
;; with caution just in case.

(load (expand-file-name "virtualenvwrapper.el" default-directory))
(require 's)
(require 'noflet)
(require 'with-simulated-input)

(setq venv-tmp-env "emacs-venvwrapper-test")

(defmacro with-temp-location (&rest forms)
  `(let ((venv-location temporary-file-directory))
     (unwind-protect
         (progn
           ,@forms))))


(defmacro with-temp-env (name &rest forms)
  `(let ((venv-location temporary-file-directory))
     (unwind-protect
         (progn
           (venv-mkvirtualenv ,name)
           ,@forms)
       (venv-rmvirtualenv ,name))))

(defun assert-venv-activated ()
  "Runs various assertions to check if a venv is activated."
  ;; M-x pdb should ask to run "python -m pdb"
  (should (equal gud-pdb-command-name "python -m pdb"))
  ;; we store the name correctly
  (should (s-contains? venv-tmp-env venv-current-name))
  ;; assert that the current dir exists and is asbolute
  (should (file-name-absolute-p venv-current-dir))
  (should (file-directory-p venv-current-dir))
  ;; we change the path for python mode
  (should (s-contains? venv-tmp-env python-shell-virtualenv-path))
  ;; we set PATH for shell and subprocesses
  (should (s-contains? venv-tmp-env (getenv "PATH")))
  ;; we set VIRTUAL_ENV for jedi and whoever else needs it
  (should (s-contains? venv-tmp-env (getenv "VIRTUAL_ENV")))
  ;; we add our dir to exec-path
  (should (s-contains? venv-tmp-env (car exec-path))))

(ert-deftest venv-mkvirtualenv-works ()
  (with-temp-location
   (venv-mkvirtualenv venv-tmp-env)
   (should (equal venv-current-name venv-tmp-env))
   (venv-deactivate)
   (venv-rmvirtualenv venv-tmp-env)))

(ert-deftest venv-rmvirtualenv-works ()
  (let ((venv-location temporary-file-directory))
    (venv-mkvirtualenv venv-tmp-env)
    (venv-deactivate)
    (venv-rmvirtualenv venv-tmp-env)
    (should-error (venv-workon venv-tmp-env))))

(ert-deftest venv-mkvirtualenv-select-default-interpreter ()
  (with-temp-location
   (let ((current-prefix-arg '(4)))
     (with-simulated-input
      "RET"
      (venv-mkvirtualenv venv-tmp-env))
     (should (equal venv-current-name venv-tmp-env))
     (venv-deactivate)
     (venv-rmvirtualenv venv-tmp-env))))

(ert-deftest venv-mkvirtualenv-select-different-interpreter ()
  (with-temp-location
   (let ((current-prefix-arg '(4)))
     (with-simulated-input
      (concat (executable-find "python") " RET")
      (venv-mkvirtualenv venv-tmp-env))
     (should (equal venv-current-name venv-tmp-env))
     (venv-deactivate)
     (venv-rmvirtualenv venv-tmp-env))))

(ert-deftest venv-mkvirtualenv-using-default-interpreter-works ()
  (with-temp-location
   (venv-mkvirtualenv-using nil venv-tmp-env)
   (should (equal venv-current-name venv-tmp-env))
   (venv-deactivate)
   (venv-rmvirtualenv venv-tmp-env)))

(ert-deftest venv-mkvirtualenv-using-different-interpreter-works ()
  (with-temp-location
   (venv-mkvirtualenv-using (executable-find "python") venv-tmp-env)
   (should (equal venv-current-name venv-tmp-env))
   (venv-deactivate)
   (venv-rmvirtualenv venv-tmp-env)))

(ert-deftest venv-mkvirtualenv-using-select-default-interpreter ()
  (with-temp-location
   (with-simulated-input
    "RET"
   (let ((current-prefix-arg '(4)))
     (venv-mkvirtualenv-using "some invalid interpreter" venv-tmp-env)))
   (should (equal venv-current-name venv-tmp-env))
   (venv-deactivate)
   (venv-rmvirtualenv venv-tmp-env)))

(ert-deftest venv-mkvirtualenv-using-select-different-interpreter ()
  (with-temp-location
   (with-simulated-input
    (concat (executable-find "python") " RET")
    (let ((current-prefix-arg '(4)))
      (venv-mkvirtualenv-using "some invalid interpreter" venv-tmp-env)))
     (should (equal venv-current-name venv-tmp-env))
     (venv-deactivate)
     (venv-rmvirtualenv venv-tmp-env)))

(ert-deftest venv-workon-works ()
  (with-temp-env
   venv-tmp-env
   (venv-deactivate)
   (venv-workon venv-tmp-env)
   (assert-venv-activated)))

(ert-deftest venv-deactivate-works ()
  (with-temp-env
   venv-tmp-env
   (venv-deactivate)
   ;; M-x pdb should ask to run "pdb"
   (should (equal gud-pdb-command-name "pdb"))
   ;; we remove the name correctly
   (should (equal venv-current-name nil))
   ;; we change the python path back
   (should (equal python-shell-virtualenv-path nil)))
   ;; we reset the PATH correctly
   (should (not (s-contains? venv-tmp-env (getenv "PATH"))))
   ;; we reset VIRTUAL_ENV
   (should (equal nil (getenv "VIRTUAL_ENV")))
   ;; we remove out dir to exec-path
   (should (not (s-contains? venv-tmp-env (car exec-path)))))

(ert-deftest venv-workon-errors-for-nonexistence ()
  (should-error (venv-workon "i-hopefully-do-not-exist")))

(ert-deftest venv-list-virtualenvs-works ()
  (with-temp-env
   venv-tmp-env
   (should (s-contains? venv-tmp-env (venv-list-virtualenvs)))))

(ert-deftest venv-cdvirtualenv-works ()
  (with-temp-env
   venv-tmp-env
   (let ((old-wd default-directory))
     (unwind-protect
         (progn
           (venv-cdvirtualenv)
           (should (s-contains? venv-tmp-env default-directory)))
       (cd old-wd)))))

(ert-deftest venv-cpvirtualenv-works ()
  (with-temp-env
   venv-tmp-env
   (unwind-protect
       (progn
         (venv-cpvirtualenv venv-tmp-env "copy-of-tmp-env")
         (should (s-contains? "copy-of-tmp-env" (venv-list-virtualenvs))))
     (venv-rmvirtualenv "copy-of-tmp-env"))))


;; tests for hooks


(ert-deftest venv-activate-hooks ()
  (let ((preactivate nil)
        (postactivate nil)
        (venv-preactivate-hook '((lambda () (setq preactivate "yes"))))
        (venv-postactivate-hook '((lambda () (setq postactivate "yes")))))
  (with-temp-env
   venv-tmp-env
   (should (equal preactivate "yes"))
   (should (equal postactivate "yes")))))

(ert-deftest venv-mkvenv-hooks ()
  (let ((venv-premkvirtualenv-hook '((lambda ()
                                       (setq preactivated "yes"))))
        (venv-postmkvirtualenv-hook '((lambda ()
                                        (setq postactivated "yes")
                                        (setq name venv-current-name)))))
    (with-temp-env
     venv-tmp-env
     (venv-deactivate)
     (should (equal preactivated "yes"))
     (should (equal postactivated "yes"))
     (should (equal name venv-tmp-env)))))

(ert-deftest venv-set-location-works ()
  (let ((expected-venv-location "test location")
        (original-venv-location venv-location))
    (venv-set-location expected-venv-location)
    (should (equal venv-location expected-venv-location))
    (setq venv-location original-venv-location)))

(ert-deftest venv-projectile-auto-workon-works ()
  (with-temp-env
    venv-tmp-env
    ;; the reason for setting a bogus venv-location here is that the
    ;; venv-location shouldn't matter, projectile-auto-workon should happen
    ;; indepedent of it's being set or not
    (let ((venv-location "bogus"))
      (noflet ((projectile-project-root () temporary-file-directory))
        (setq venv-dirlookup-names (list venv-tmp-env))
        (venv-deactivate)
        (venv-projectile-auto-workon)
        (assert-venv-activated)))))
