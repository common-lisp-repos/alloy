#|
 This file is a part of Alloy
 (c) 2019 Shirakumo http://tymoon.eu (shinmera@tymoon.eu)
 Author: Nicolas Hafner <shinmera@tymoon.eu>
|#

(in-package #:org.shirakumo.alloy)

(defgeneric allocate (renderer))
(defgeneric deallocate (renderer))
(defgeneric allocated-p (renderer))
(defgeneric register (renderable renderer))

(defgeneric render-needed-p (renderable))
(defgeneric mark-for-render (renderable))
(defgeneric render (renderer renderable))
(defgeneric maybe-render (renderer renderable))
(defgeneric call-with-constrained-visibility (function extent renderer))
(defgeneric extent-visible-p (extent renderer))

(defclass renderer ()
  ((allocated-p :initform NIL :reader allocated-p)
   (visible-bounds :initform (px-extent) :accessor visible-bounds)))

(defmethod call-with-constrained-visibility (function (extent extent) (renderer renderer))
  (let ((old (visible-bounds renderer)))
    (setf (visible-bounds renderer) (extent-intersection extent old))
    (unwind-protect
         (funcall function)
      (setf (visible-bounds renderer) old))))

(defmacro with-constrained-visibility ((extent renderer) &body body)
  `(call-with-constrained-visibility (lambda () ,@body) ,extent ,renderer))

(defmethod extent-visible-p ((extent extent) (renderer renderer))
  (overlapping-p extent (visible-bounds renderer)))

(defmethod allocate :after ((renderer renderer))
  (setf (slot-value renderer 'allocated-p) T))

(defmethod deallocate :after ((renderer renderer))
  (setf (slot-value renderer 'allocated-p) NIL))

(defmethod suggest-bounds :before (extent (renderer renderer))
  (setf (visible-bounds renderer) extent))

(defclass renderable ()
  ((render-needed-p :initform T :reader render-needed-p)))

(defmethod mark-for-render ((renderable renderable))
  (setf (slot-value renderable 'render-needed-p) T))

(defmethod render :after ((renderer renderer) (renderable renderable))
  (setf (slot-value renderable 'render-needed-p) NIL))

(defmethod maybe-render :around ((renderer renderer) (renderable renderable))
  (if (render-needed-p renderable)
      (render renderer renderable)
      (call-next-method)))

