(in-package #:cl-tidyr.tests)

(in-suite :cl-tidyr)

(test pivot-longer-basic
  "Test pivot-longer basic functionality"
  (let* ((df (cl-tibble:tibble :id (vector 1 2)
                               :x (vector "x1" "x2")
                               :y (vector "y1" "y2")))
         ;; Longer: id kept, x and y become key/value
         (res (pivot-longer df 
                            (list :x :y) 
                            :names-to "key" 
                            :values-to "val")))
    
    ;; Expect 4 rows (2 cols * 2 rows)
    ;; How to check nrow? length of a column.
    (is (= 4 (length (cl-tibble:tbl-col res :KEY))))
    
    ;; Check keys
    (let ((keys (cl-tibble:tbl-col res :KEY)))
      (is (find "X" keys :test #'string-equal)) ;; keys might be upcased
      (is (find "Y" keys :test #'string-equal)))
    
    ;; Check values
    (let ((vals (cl-tibble:tbl-col res :VAL)))
      (is (find "x1" vals :test #'equal))
      (is (find "y2" vals :test #'equal)))))
