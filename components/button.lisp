#|
 This file is a part of Alloy
 (c) 2019 Shirakumo http://tymoon.eu (shinmera@tymoon.eu)
 Author: Nicolas Hafner <shinmera@tymoon.eu>
|#

(in-package #:org.shirakumo.alloy)

(defclass button (component)
  ((pressed :initform NIL :accessor pressed)))

(defmethod (setf pressed) :after (value (button button))
  (mark-for-render button))

(defmethod handle ((event pointer-down) (button button) ctx)
  (setf (pressed button) T))

(defmethod handle ((event pointer-up) (button button) ctx)
  (setf (pressed button) NIL)
  (setf (focus-for button ctx) :weak))

(defmethod handle ((event button-down) (button button) ctx)
  (case (button event)
    (:a (setf (pressed button) T))
    (T (call-next-method))))

(defmethod handle ((event button-up) (button button) ctx)
  (case (button event)
    (:a (setf (pressed button) NIL))
    (T (call-next-method))))

(defmethod (setf focus) :after (value (button button))
  (unless (eql value :strong)
    (setf (pressed button) NIL)))
