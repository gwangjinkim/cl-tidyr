(in-package #:cl-tidyr)

;;; R 4.6.1's base character ordering uses ICU 76.1 root collation in the
;;; pinned C.UTF-8 conformance environment. Stringr's independent ICU 71.1
;;; handle has a different contract and must not resolve these symbols.
(defvar *tr-collation-library* nil)
(defvar *tr-collation-symbols* (make-hash-table :test #'equal))

(defun %tr-close-collation ()
  (unwind-protect
       (when *tr-collation-library*
         (cffi:foreign-funcall "dlclose" :pointer *tr-collation-library* :int))
    (setf *tr-collation-library* nil)
    (clrhash *tr-collation-symbols*)))

(defun %tr-collation-symbol (name)
  (or (gethash name *tr-collation-symbols*)
      (setf (gethash name *tr-collation-symbols*)
            (let ((pointer (cffi:foreign-funcall "dlsym"
                             :pointer *tr-collation-library*
                             :string (concatenate 'string name "_76") :pointer)))
              (when (cffi:null-pointer-p pointer)
                (%tr-error "ICU 76.1 symbol ~A is unavailable." name))
              pointer))))

(defmacro %tr-collation-call (name &rest arguments)
  `(cffi:foreign-funcall-pointer (%tr-collation-symbol ,name) () ,@arguments))

(defun %tr-collation-version ()
  (cffi:with-foreign-object (version :uint8 4)
    (%tr-collation-call "u_getVersion" :pointer version :void)
    (map 'vector (lambda (i) (cffi:mem-aref version :uint8 i)) #(0 1 2 3))))

(defun %tr-load-collation (&optional (configured (uiop:getenv "CL_TIDYR_ICU_LIBRARY")))
  (unless *tr-collation-library*
    (handler-case
        (progn
          (let ((paths
                  (if configured (list configured)
                      (append
                       (mapcar (lambda (name)
                                 (namestring (asdf:system-relative-pathname
                                              :cl-tidyr (concatenate 'string ".native/icu-76.1/lib/" name))))
                               '("libicui18n.dylib" "libicui18n.so"))
                       '("/opt/homebrew/opt/icu4c@76/lib/libicui18n.76.dylib"
                         "/usr/local/opt/icu4c@76/lib/libicui18n.76.dylib"
                         "libicui18n.so.76" "libicui18n.76.dylib")))))
            (setf *tr-collation-library*
                  (loop for path in paths
                        for handle = (cffi:foreign-funcall "dlopen" :string path :int 2 :pointer)
                        unless (cffi:null-pointer-p handle) return handle
                        finally (%tr-error "Independent ICU 76.1 is required for character ordering. Run scripts/bootstrap-icu.sh or set CL_TIDYR_ICU_LIBRARY."))))
          (dolist (name '("u_getVersion" "ucol_open" "ucol_close" "ucol_strcollUTF8"))
            (%tr-collation-symbol name))
          (let ((version (%tr-collation-version)))
            (unless (and (= 76 (aref version 0)) (= 1 (aref version 1)))
              (%tr-error "ICU ~D.~D differs from required 76.1." (aref version 0) (aref version 1)))))
      (error (condition)
        (%tr-close-collation)
        (error condition))))
  *tr-collation-library*)

(defun %tr-string< (left right)
  "Compare strings with pinned R's ICU 76.1 root collation; no global locale changes."
  (when (or (find (code-char 0) left) (find (code-char 0) right))
    (%tr-error "R strings cannot contain NUL."))
  (%tr-load-collation)
  (cffi:with-foreign-object (status :int32)
    (setf (cffi:mem-ref status :int32) 0)
    (let ((collator (%tr-collation-call "ucol_open" :string "root" :pointer status :pointer)))
      ;; Close any allocated collator even if a positive status reports failure.
      (unwind-protect
           (progn
             (when (or (cffi:null-pointer-p collator) (plusp (cffi:mem-ref status :int32)))
               (%tr-error "Unable to open ICU root collator (status ~D)." (cffi:mem-ref status :int32)))
             (setf (cffi:mem-ref status :int32) 0)
             (cffi:with-foreign-string ((left-bytes left-size) left :encoding :utf-8)
               (cffi:with-foreign-string ((right-bytes right-size) right :encoding :utf-8)
                 (let ((result (%tr-collation-call "ucol_strcollUTF8"
                                  :pointer collator :pointer left-bytes :int32 (1- left-size)
                                  :pointer right-bytes :int32 (1- right-size) :pointer status :int)))
                   (when (plusp (cffi:mem-ref status :int32))
                     (%tr-error "ICU collation failed (status ~D)." (cffi:mem-ref status :int32)))
                   (minusp result)))))
        (unless (cffi:null-pointer-p collator)
          (%tr-collation-call "ucol_close" :pointer collator :void))))))
