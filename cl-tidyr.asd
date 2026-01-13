(defsystem "cl-tidyr"
  :version "0.1.0"
  :author "Antigravity"
  :license "MIT"
  :description "Tidy data reshaping for Common Lisp"
  :depends-on (:cl-tibble
               :cl-dplyr
               :cl-vctrs-lite
               :cl-ppcre
               :alexandria
               :serapeum)
  :components ((:module "src"
                :components
                ((:file "packages")
                 (:file "string-verbs" :depends-on ("packages"))
                 (:file "pivoting" :depends-on ("packages" "string-verbs"))
                 (:file "missing-values" :depends-on ("packages"))
                 (:file "rectification" :depends-on ("packages"))
                 (:file "nesting" :depends-on ("packages"))
                 (:file "dsl" :depends-on ("packages")))))
  :in-order-to ((test-op (test-op "cl-tidyr/tests"))))

(defsystem "cl-tidyr/tests"
  :depends-on (:cl-tidyr
               :fiveam)
  :components ((:module "tests"
                :components
                ((:file "packages")
                 (:file "main" :depends-on ("packages"))
                 (:file "test-string-verbs" :depends-on ("packages" "main"))
                 (:file "test-pivoting" :depends-on ("packages" "main"))
                 (:file "test-pivot-wider" :depends-on ("packages" "main"))
                 (:file "test-missing-values" :depends-on ("packages" "main"))
                 (:file "test-rectification" :depends-on ("packages" "main"))
                 (:file "test-nesting" :depends-on ("packages" "main"))
                 (:file "test-dsl" :depends-on ("packages" "main")))))
  :perform (test-op (o c) (symbol-call :fiveam :run! :cl-tidyr)))
