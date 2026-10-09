(in-package #:cl-tidyr.tests)

(in-suite :cl-tidyr)

(test drop-na-basic
  "Test drop-na functionality"
  (let* ((df (cl-tibble:tibble :x (vector 1 2 nil 4)
                               :y (vector "a" nil "b" "d")))
         ;; Drop rows where ANY column is missing
         (res1 (drop-na df))
         ;; Drop rows where X is missing
         (res2 (drop-na df :x)))
    
    ;; res1: should keep rows 1 (1,"a") and 4 (4,"d"). Dropped 2 and 3.
    (let ((col-x (cl-tibble:tbl-col res1 :X)))
      (is (= 2 (length col-x)))
      (is (= 1 (elt col-x 0)))
      (is (= 4 (elt col-x 1))))
    
    ;; res2: should keep rows 1, 2, 4. Dropped 3 (x=nil).
    (let ((col-x2 (cl-tibble:tbl-col res2 :X)))
      (is (= 3 (length col-x2)))
      (is (= 2 (elt col-x2 1))))))

(test replace-na-basic
  "Test replace-na functionality"
  (let* ((df (cl-tibble:tibble :x (vector 1 nil 3)
                               :y (vector "a" nil "b")))
         (res (replace-na df (list :x 0 :y "unknown"))))
    
    (let ((xs (cl-tibble:tbl-col res :X))
          (ys (cl-tibble:tbl-col res :Y)))
      (is (= 1 (elt xs 0)))
      (is (= 0 (elt xs 1))) ;; Replaced
      (is (= 3 (elt xs 2)))
      
      (is (equal "a" (elt ys 0)))
      (is (equal "unknown" (elt ys 1))) ;; Replaced
      (is (equal "b" (elt ys 2))))))

(test fill-basic
  "Test fill functionality (down)"
  (let* ((df (cl-tibble:tibble :x (vector 1 nil nil 4)))
         (res (fill df :x :direction :down)))
    (let ((xs (cl-tibble:tbl-col res :X)))
      (is (= 1 (elt xs 0)))
      (is (= 1 (elt xs 1))) ;; Filled
      (is (= 1 (elt xs 2))) ;; Filled
      (is (= 4 (elt xs 3))))))

(test fill-on-sequences-behaves-like-cl-fill
  "cl-tidyr:fill shadows cl:fill; on plain sequences it must be cl:fill."
  (is (equal '(0 0 0) (fill (list 1 2 3) 0)))
  (is (equalp #(1 9 9) (fill (vector 1 2 3) 9 :start 1))))
