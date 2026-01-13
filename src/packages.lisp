(defpackage #:cl-tidyr
  (:use #:cl)
  (:import-from #:cl-tibble
                #:tibble
                #:as-tibble)
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
           #:complete))
