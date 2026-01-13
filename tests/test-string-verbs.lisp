(in-package #:cl-tidyr.tests)

(in-suite :cl-tidyr)

(test unite-basic
  "Test unite function basics"
  (let* ((df (cl-tibble:tibble :a (list "a" "b") :b (list "1" "2")))
         (res (unite df "combined" :a :b :sep "_")))
    ;; Placeholder expectation
    (is (equal "a_1" (first (cl-tibble:pull res "combined"))))))

(test separate-basic
  "Test separate function basics"
  (let* ((df (cl-tibble:tibble :x (list "a_1" "b_2")))
         (res (separate df :x (list "c1" "c2") :sep "_")))
    ;; Placeholder expectation
    (is (equal "a" (first (cl-tibble:pull res "c1"))))
    (is (equal "1" (first (cl-tibble:pull res "c2"))))))
