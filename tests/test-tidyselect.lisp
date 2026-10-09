(in-package #:cl-tidyr.tests)
(in-suite :cl-tidyr)

(test tidyselect-runtime-pivot-selector
  (let* ((df (cl-tibble:tibble :id #(1 2) :x_a #(10 20) :x_b #(30 40)))
         (result (pivot-longer df (lambda () (starts-with "x")))))
    (is (= 4 (cl-tibble:tbl-nrows result)))
    (is (equalp (cl-tibble:tbl-col result "name") #("x_a" "x_b" "x_a" "x_b")))
    (is (equalp (cl-tibble:tbl-col result "value") #(10 30 20 40)))
    (is (equalp (cl-tibble:tbl-col result "id") #(1 1 2 2)))))

(test tidyselect-unite-helper-and-empty-selection
  (let ((df (cl-tibble:tibble :x_a #("a" "b") :id #(1 2) :x_b #("c" "d"))))
    (let ((result (unite df "joined" (lambda () (starts-with "x")))))
      (is (equalp (cl-tibble:tbl-names result) #("id" "joined")))
      (is (equalp (cl-tibble:tbl-col result "joined") #("a_c" "b_d"))))
    (let ((empty (cl-tidyr::select-cols df (lambda () (any-of '("missing"))))))
      (is (= 0 (length (cl-tibble:tbl-names empty))))
      (is (= 2 (cl-tibble:tbl-nrows empty))))
    (is (equalp (cl-tibble:tbl-names (cl-tidyr::select-cols df '(2 0))) #("x_b" "x_a")))
    (signals error (pivot-longer df (lambda () (all-of '("missing")))))))

(test tidyselect-reexport-symbol-identity
  (dolist (name '("STARTS-WITH" "ENDS-WITH" "CONTAINS" "MATCHES" "NUM-RANGE"
                  "EVERYTHING" "LAST-COL" "ALL-OF" "ANY-OF" "ONE-OF" "WHERE" "VARS-SELECT-HELPERS"))
    (is (eq (find-symbol name :cl-tidyr) (find-symbol name :cl-tidyselect)))))

(test tidyselect-disallow-renaming-in-reshape
  (let ((df (cl-tibble:tibble :x #(1 2) :y #(3 4))))
    (signals error (pivot-longer df (lambda () (all-of '(("renamed" . "x"))))))
    (signals error (pivot-longer df (lambda () (any-of '(("renamed" . "x"))))))
    (signals error (unite df "joined" (lambda () (all-of '(("renamed" . "x"))))))))
