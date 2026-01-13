(in-package #:cl-tidyr.tests)

(in-suite :cl-tidyr)

(test unite-basic
  "Test unite function basics"
  (let* ((df (cl-tibble:tibble :a (vector "a" "b") :b (vector "1" "2")))
         (res (unite df "combined" :a :b :sep "_")))
    (is (equal "a_1" (elt (cl-tibble:tbl-col res :COMBINED) 0)))))

(test separate-basic
  "Test separate function basics"
  (let* ((df (cl-tibble:tibble :x (vector "a_1" "b_2")))
         (res (separate df :x (list "c1" "c2") :sep "_")))
    (is (equal "a" (elt (cl-tibble:tbl-col res :C1) 0)))
    (is (equal "1" (elt (cl-tibble:tbl-col res :C2) 0)))))
