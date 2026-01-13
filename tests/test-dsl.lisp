(in-package #:cl-tidyr.tests)

(in-suite :cl-tidyr)

(test tidy-macro-basic
  "Test tidy macro threading"
  (let* ((df (cl-tibble:tibble :id (vector 1 2)
                               :x (vector "x1" "x2")
                               :y (vector "y1" "y2")))
         ;; Chain: pivot-longer -> unite
         (res (tidy df
                (pivot-longer (list :x :y) :names-to "key" :values-to "val")
                (unite "joined" :key :val :sep "-"))))
    
    ;; Expectations:
    ;; pivot-longer makes 4 rows.
    ;; unite combines key and val.
    ;; Result cols: ID, JOINED.
    (is (= 4 (length (cl-tibble:tbl-col res :ID))))
    (is (cl-tibble:tbl-col res :JOINED))
    
    (let ((joined (cl-tibble:tbl-col res :JOINED)))
      ;; x-x1, y-y1, etc. - order depends on implementation
      ;; Just check one exists
      (is (or (find "x-x1" joined :test #'equal)
              (find "X-x1" joined :test #'equal) ;; Case sensitivity check
              (find "x-x2" joined :test #'equal))))))
