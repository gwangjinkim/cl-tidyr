(in-package #:cl-tidyr)

(defmacro tidy (data &body body)
  "Thread-first macro for cl-tidyr operations.
   Equivalent to -> in other lisps/libraries.
   
   (tidy df
     (op1 arg1)
     (op2 arg2))
   
   Becomes:
   (op2 (op1 df arg1) arg2)
  "
  (let ((result data))
    (dolist (form body)
      (if (listp form)
          (setf result (append (list (car form) result) (cdr form)))
          (setf result (list form result))))
    result))
