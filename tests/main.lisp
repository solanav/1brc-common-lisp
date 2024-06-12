(defpackage 1brc/tests/main
  (:use :cl
        :1brc
        :rove))
(in-package :1brc/tests/main)

;; NOTE: To run this test file, execute `(asdf:test-system :1brc)' in your Lisp.

(deftest test-target-1
  (testing "should (= 1 1) to be true"
    (ok (= 1 1))))
