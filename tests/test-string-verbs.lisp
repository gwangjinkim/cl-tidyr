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

(test separate-pads-short-rows-with-na
  "A row with fewer pieces must not drop the whole extra column."
  (let* ((df (cl-tibble:tibble :id #(1 2) :code #("a-b" "c")))
         (res (separate df :code '("x" "y") :sep "-")))
    (is (equalp #("id" "x" "y") (cl-tibble:tbl-names res)))
    (is (equal "b" (elt (cl-tibble:tbl-col res :y) 0)))
    (is (na-p (elt (cl-tibble:tbl-col res :y) 1)))))

(test separate-na-input-gives-na-pieces
  (let* ((df (cl-tibble:tibble :code (vector "a-b" *na*)))
         (res (separate df :code '("x" "y") :sep "-")))
    (is (na-p (elt (cl-tibble:tbl-col res :x) 1)))
    (is (na-p (elt (cl-tibble:tbl-col res :y) 1)))))

(test unite-keeps-column-order-and-drops-na
  (let* ((df (cl-tibble:tibble :a #(1 2) :b (vector "x" *na*) :c #("p" "q") :d #(9 9)))
         (res (unite df "bc" :b :c :sep "_" :na-rm t)))
    (is (equalp #("a" "d" "bc") (cl-tibble:tbl-names res)))
    (is (equalp #("x_p" "q") (cl-tibble:tbl-col res :bc)))))
