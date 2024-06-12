(defpackage 1brc
  (:use :cl :iterate)
  (:local-nicknames (:jzon :com.inuoe.jzon)))
(in-package :1brc)

(defstruct weather-data
  (min 0.0 :type float)
  (mean 0.0 :type float)
  (max 0.0 :type float)
  (total 0 :type integer))

(defun make-first-weather-data (value)
  (make-weather-data :min value
                     :mean value
                     :max value
                     :total 1))

(defun update-weather (value ow)
  "update the values of a weather record with a value"
  (setf (weather-data-min ow) (min (weather-data-min ow) value))
  (setf (weather-data-mean ow) (+ (weather-data-mean ow) value))
  (setf (weather-data-max ow) (max (weather-data-max ow) value))
  (setf (weather-data-total ow) (1+ (weather-data-total ow)))
  ow)

(defun merge-weather (w1 w2)
  "merge two weather structs together"
  (setf (weather-data-min w1) (min
                               (weather-data-min w1)
                               (weather-data-min w2)))
  (setf (weather-data-mean w1) (+
                                (weather-data-mean w1)
                                (weather-data-mean w2)))
  (setf (weather-data-max w1) (max
                               (weather-data-max w1)
                               (weather-data-max w2)))
  (setf (weather-data-total w1) (+
                                 (weather-data-total w1)
                                 (weather-data-total w2)))
  w1)

(defun save-value (results country value)
  "save the weather struct into a hashtable by country"
  (declare (optimize (speed 3) (safety 0)))
  (declare (type string country)
           (type float value))
  (let ((val (gethash country results)))
    (if (null val)
        (setf (gethash country results) (make-first-weather-data value))
        (setf (gethash country results) (update-weather value val)))))

(defun parse-int (seq)
  "takes a vector of bytes and turns it into an integer"
  (declare (optimize (speed 3) (safety 0)))
  (declare (type (simple-array (unsigned-byte 8)) seq))
  (float
   (loop for mul in '(1 10 100 1000 10000)
         for i from (1- (length seq)) downto 0
         for v = (elt seq i)
         sum (* (- v 48) mul))))

(defun parse-float (seq)
  "takes a vector of bytes and turns it into a float"
  (declare (optimize (speed 3) (safety 0)))
  (declare (type (simple-array (unsigned-byte 8)) seq))
  (let* ((neg (if (= (elt seq 0) 45) 1 0))
         (dot (position 46 seq))
         (int (parse-int (subseq seq neg dot)))
         (fra-seq (subseq seq (1+ dot) (length seq)))
         (fra (/ (parse-int fra-seq) (expt 10 (length fra-seq)))))
    (if (= neg 1)
        (* -1 (+ int fra))
        (+ int fra))))

(defun fast-process-line (seq)
  "i was trying to make the parsing faster by calculating everything in one pass, did not work"
  (let ((found-colon nil)
        (found-dot nil)
        (country (make-array 32 :fill-pointer 0 :element-type '(unsigned-byte 8)))
        (is-neg nil)
        (int-part 0)
        (fra-part 0)
        (mul 10))
    (iter
      (for c in-vector seq)
      (cond
        ;; Find colon
        ((= c 59) (progn (setf found-colon t) (next-iteration)))
        ;; Find minus
        ((and found-colon (= c 45)) (progn (setf is-neg t) (next-iteration)))
        ;; Find dot
        ((and found-colon (= c 46)) (progn (setf found-dot t) (next-iteration)))
        ;; Before colon, collect country
        ((not found-colon) (progn (vector-push c country)
                                  (next-iteration)))
        ;; Before dot, collect int part
        ((and found-colon (not found-dot))
         (setf int-part (+ (* 10 int-part) (- c 48))))
        ;; After dot, collect fractional part
        ((and found-colon found-dot)
         (progn
           (setf fra-part (+ fra-part (/ (- c 48) mul)))
           (setf mul (* mul 10)))))
      (finally (return (values (babel:octets-to-string country)
                               (if is-neg
                                   (* -1 (+ int-part fra-part))
                                   (+ int-part fra-part))))))))

(defun process-line (seq)
  "take a vector of bytes and turn it into a country and a float"
  (let* ((middle (position 59 seq :from-end t))
         (country (subseq seq 0 middle))
         (value (subseq seq (1+ middle) (length seq))))
    (values (babel:octets-to-string country)
            (parse-float value))))

(defun process-chunk (addr chunk-start chunk-end)
  "take an address and extract lines and process them"
  (let ((results (make-hash-table :test #'equal))
        (line (make-array 128 :fill-pointer 0 :element-type '(unsigned-byte 8))))
    (loop for i from chunk-start below chunk-end
          for char = (cffi:mem-aref addr :unsigned-char i)
          if (not (= char 10))
            do (vector-push char line)
          else
            do (multiple-value-bind (country value)
                   (process-line line)
                 (save-value results country value))
            and do (setf (fill-pointer line) 0))
    results))

(defun merge-chunks (h1 h2)
  "take two hash-tables with country: weather-data and merge them"
  (loop for k being the hash-keys in h2 using (hash-value v2)
        for v1 = (gethash k h1)
        do (if v1
               (setf (gethash k h1) (merge-weather v1 v2))
               (setf (gethash k h1) v2))))

(defun chunk-file (addr size threads)
  "turn an mmapped file into a list of chunks with starting an ending address"
  (let ((chunk-size (truncate (/ size threads))))
    (loop
      for chunk-start = 0 then (1+ chunk-end)
      while (< chunk-start size)
      for chunk-end = (let* ((ini-chunk-end (min size (+ chunk-start chunk-size))))
                        (loop for i from ini-chunk-end to size
                              for char = (cffi:mem-aref addr :unsigned-char i)
                              if (or (= char 10) (= i size))
                                return i))
      collect (cons chunk-start chunk-end))))

(defun main ()
  "chunk the file and process the chunks in parallel"
  (setf lparallel:*kernel*
        (lparallel:make-kernel 12 :name "custom-kernel"))
  (mmap:with-mmap (addr fd size #p"data/measurements.txt")
    (let ((result (make-hash-table :test #'equal)))
      (loop for next in (lparallel:pmap
                         'list
                         (lambda (x) (process-chunk addr (car x) (cdr x)))
                         (chunk-file addr size 12))
            do (merge-chunks result next))
      (format t "{")
      (loop for k being the hash-keys in result using (hash-value v)
            do (format t "~a=~,4f/~,4f/~,4f, " k
                       (weather-data-min v)
                       (/ (weather-data-mean v) (weather-data-total v))
                       (weather-data-max v)))
      (write-char #\Backspace)
      (write-char #\Backspace)
      (format t "}"))))

(defun main-debug ()
  (flamegraph:save-flame-graph ("data/1brc.stack")
    (main)))
