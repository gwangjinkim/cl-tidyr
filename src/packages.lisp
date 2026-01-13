(defpackage #:cl-tidyr
  (:use #:cl)
  (:shadow #:fill)
  (:import-from #:cl-tibble
                #:tibble
                #:as-tibble
                #:tbl-names
                #:tbl-col
                #:bind-cols)
  (:import-from #:cl-dplyr
                #:select)
  (:export #:unite
           #:separate
           #:pivot-longer
           #:pivot-wider
           #:drop-na
           #:replace-na
           #:fill
           #:expand
           #:complete
           #:tidy))
