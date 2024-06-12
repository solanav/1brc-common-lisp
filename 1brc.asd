(asdf:defsystem "1brc"
  :version "0.0.1"
  :author ""
  :license ""
  :depends-on ("mmap"
               "lparallel"
               "babel"
               "com.inuoe.jzon"
               "flamegraph"
               "iterate")
  :components ((:module "src"
                :components
                ((:file "main"))))
  :description "Calc"
  :defsystem-depends-on (:deploy)
  :build-operation "deploy-op"
  :build-pathname "1brc"
  :entry-point "1brc::main")

;; Deploy may not find libcrypto on your system.
;; But anyways, we won't ship it to rely instead
;; on its presence on the target OS.
(require :cl+ssl)  ; sometimes necessary.
#+linux (deploy:define-library cl+ssl::libssl :dont-deploy T)
#+linux (deploy:define-library cl+ssl::libcrypto :dont-deploy T)

;; ASDF wants to update itself and fails.
;; Yeah, it does that even when running the binary on my VPS O_o
;; Please, don't.
(deploy:define-hook (:deploy asdf) (directory)
  #+asdf (asdf:clear-source-registry)
  #+asdf (defun asdf:upgrade-asdf () NIL))
