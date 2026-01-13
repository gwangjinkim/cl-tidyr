(defpackage #:cl-tidyr.tests
  (:use #:cl #:fiveam #:cl-tidyr)
  (:shadowing-import-from #:cl-tidyr #:fill)
  (:export #:run!
           #:all-tests))
