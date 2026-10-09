(defpackage #:cl-tidyr
  (:use #:cl #:cl-vctrs-lite)
  (:nicknames #:tidyr)
  (:shadow #:fill)
  (:import-from #:cl-tibble
                #:tibble
                #:as-tibble
                #:tbl-names
                #:tbl-col
                #:bind-cols)
  (:import-from #:cl-tidyselect
                #:starts-with #:ends-with #:contains #:matches #:num-range
                #:everything #:last-col #:all-of #:any-of #:one-of
                #:where #:vars-select-helpers)
  (:export #:starts-with #:ends-with #:contains #:matches #:num-range
                #:everything #:last-col #:all-of #:any-of #:one-of
                #:where #:vars-select-helpers
           #:unite
           #:separate
           #:pivot-longer
           #:pivot-wider
           #:drop-na
           #:replace-na
           #:fill
           #:expand
           #:complete
           #:nest
           #:unnest
           #:tidy))
