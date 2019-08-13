#|
 This file is a part of Alloy
 (c) 2019 Shirakumo http://tymoon.eu (shinmera@tymoon.eu)
 Author: Nicolas Hafner <shinmera@tymoon.eu>
|#

(in-package #:org.shirakumo.alloy.renderers.opengl)

(defvar *circ-polycount* 100)

(defclass renderer (simple:transformed-renderer
                    simple:styled-renderer
                    simple:look-and-feel-renderer)
  ((resources :initform (make-hash-table :test 'equal) :reader resources))
  (:default-initargs :look-and-feel (make-instance 'simple::gray)))

(defmethod resource (name (renderer renderer) &optional (errorp T))
  (or (gethash name (resources renderer))
      (when errorp
        (error "The name~%  ~s~%is not allocated to any resource."
               name))))

(defmethod (setf resource) (value name (renderer renderer))
  (setf (gethash name (resources renderer)) value))

(defmethod alloy:allocate :before ((renderer renderer))
  ;; Allocate the necessary geometry.
  (flet ((arr (&rest data)
           (make-array (length data) :element-type 'single-float :initial-contents data))
         (make-geometry (vbo vao content &rest buffer-args)
           (setf (resource vbo renderer) (apply #'make-vertex-buffer renderer content buffer-args))
           (setf (resource vao renderer) (make-vertex-array renderer `((,(resource vbo renderer) :size 2 :offset 0 :stride 8))))))
    ;; :lines
    (setf (resource 'line-vao renderer)
          (make-vertex-array renderer ()))
    ;; :triangles
    (make-geometry 'rect-fill-vbo 'rect-fill-vao
                   (arr 0f0 0f0  1f0 1f0  0f0 1f0
                        0f0 0f0  1f0 0f0  1f0 1f0))
    ;; :line-loop
    (make-geometry 'rect-line-vbo 'rect-line-vao
                   (arr 0f0 0f0  0f0 1f0  1f0 1f0  1f0 0f0))
    ;; :line-loop
    (make-geometry 'circ-line-vbo 'circ-line-vao
                   (coerce
                    (loop for i from 0 below *circ-polycount*
                          for tt = (* i (/ *circ-polycount*) 2 PI)
                          collect (float (cos tt) 0f0)
                          collect (float (sin tt) 0f0))
                    '(vector single-float)))
    ;; :triangle-fan
    (make-geometry 'circ-fill-vbo 'circ-fill-vao
                   (coerce
                    (list* 0f0 0f0
                           (loop for i from 0 below *circ-polycount*
                                 for tt = (* i (/ *circ-polycount*) 2 PI)
                                 collect (float (cos tt) 0f0)
                                 collect (float (sin tt) 0f0)))
                    '(vector single-float)))
    ;; :trangle-fan
    (make-geometry 'poly-vbo 'poly-vao (arr)
                   :data-usage :stream-draw))

  ;; Allocate the necessary shaders.
  (flet ((make-shader (name vert frag)
           (setf (resource name renderer) (make-shader renderer :vertex-shader vert :fragment-shader frag))))
    (make-shader 'line-shader
                 "#version 330 core
uniform vec2 line[2];
uniform mat3 transform;

void main(){
  vec2 pos = line[gl_VertexID];
  gl_Position = vec4(transform*vec3(pos, 1), 1);
}"
                 "#version 330 core
uniform vec4 color;
out vec4 out_color;

void main(){
  out_color = color;
}")
    (make-shader 'basic-shader
                 "#version 330 core
layout (location=0) in vec2 pos;
uniform mat3 transform;

void main(){
  gl_Position = vec4(transform*vec3(pos, 1), 1);
}"
                 "#version 330 core
uniform vec4 color;
out vec4 out_color;

void main(){
  out_color = color;
}")
    (make-shader 'image-shader
                 "#version 330 core
layout (location=0) in vec2 pos;
uniform mat3 transform;
out vec2 uv;

void main(){
  gl_Position = vec4(transform*vec3(pos, 1), 1);
  uv = pos;
}"
                 "#version 330 core
uniform sampler2D image;
in vec2 uv;
out vec4 out_color;

void main(){
  out_color = texture(image, uv);
}")))

(defmethod alloy:allocate ((renderer renderer))
  (loop for resource being the hash-values of (resources renderer)
        do (with-simple-restart (continue "Ignore the failed allocation.")
             (alloy:allocate resource))))

(defmethod alloy:deallocate ((renderer renderer))
  (loop for resource being the hash-values of (resources renderer)
        do (with-simple-restart (continue "Ignore the failed deallocation.")
             (alloy:deallocate resource)))
  (clrhash (resources renderer)))

(defmethod alloy:register (renderable (renderer renderer)))

(defmethod simple:clip :before ((renderer renderer) extent)
  ;; Render to the stencil buffer only
  (gl:clear :stencil-buffer)
  (gl:stencil-op :keep :keep :replace)
  (gl:stencil-func :always 1 #xFF)
  (gl:stencil-mask #xFF)
  (gl:color-mask NIL NIL NIL NIL)
  (gl:depth-mask NIL)
  (unwind-protect
       (simple:rectangle renderer extent)
    (gl:stencil-func :equal 1 #xFF)
    (gl:stencil-mask #x00)
    (gl:color-mask T T T T)
    (gl:depth-mask T)))

(defmethod simple:call-with-pushed-transforms (function (renderer renderer))
  (let* ((current (simple:transform renderer))
         (new (make-instance (class-of current) :parent current)))
    (setf (simple:transform renderer) new)
    (unwind-protect
         (funcall function)
      (setf (simple:transform renderer) current)
      (cond ((simple:clip-mask current)
             (unless (and (simple:clip-mask new)
                          (alloy:extent= (simple:clip-mask new)
                                         (simple:clip-mask current)))
               (simple:clip renderer (simple:clip-mask current))))
            (T
             (gl:stencil-func :always 1 #xFF))))))

(defmethod (setf simple:line-width) :before (width (renderer renderer))
  (gl:line-width width))

(defmethod (setf simple:composite-mode) :before (mode (renderer renderer))
  (ecase mode
    ;; FIXME: implement other blending modes
    (:source-over (gl:blend-func :src-alpha :one-minus-src-alpha))))

(defmethod simple:line ((renderer renderer) point-a point-b)
  (let ((shader (resource 'line-shader renderer)))
    (bind shader)
    (setf (uniform shader "line[0]") point-a)
    (setf (uniform shader "line[1]") point-b)
    (setf (uniform shader "transform") (simple:transform-matrix (simple:transform renderer)))
    (setf (uniform shader "color") (simple:fill-color renderer))
    (draw-vertex-array (resource 'line-vao renderer) :lines 2)))

(defmethod simple:rectangle ((renderer renderer) extent)
  (let ((shader (resource 'basic-shader renderer)))
    (bind shader)
    (simple:with-pushed-transforms (renderer)
      (simple:translate renderer extent)
      (simple:scale renderer (alloy:size (alloy:extent-w extent) (alloy:extent-h extent)))
      (setf (uniform shader "transform") (simple:transform-matrix (simple:transform renderer))))
    (setf (uniform shader "color") (simple:fill-color renderer))
    (ecase (simple:fill-mode renderer)
      (:fill (draw-vertex-array (resource 'rect-fill-vao renderer) :triangles 6))
      (:lines (draw-vertex-array (resource 'rect-line-vao renderer) :line-loop 4)))))

(defmethod simple:ellipse ((renderer renderer) extent)
  (let ((shader (resource 'basic-shader renderer)))
    (bind shader)
    (simple:with-pushed-transforms (renderer)
      (let ((w (/ (alloy:extent-w extent) 2))
            (h (/ (alloy:extent-h extent) 2)))
        (simple:translate renderer (alloy:point (+ (alloy:extent-x extent) w)
                                                (+ (alloy:extent-y extent) h)))
        (simple:scale renderer (alloy:size w h)))
      (setf (uniform shader "transform") (simple:transform-matrix (simple:transform renderer))))
    (setf (uniform shader "color") (simple:fill-color renderer))
    (ecase (simple:fill-mode renderer)
      (:fill (draw-vertex-array (resource 'circ-fill-vao renderer) :triangle-fan *circ-polycount*))
      (:lines (draw-vertex-array (resource 'circ-line-vao renderer) :line-loop *circ-polycount*)))))

(defmethod simple:polygon ((renderer renderer) points)
  (let ((shader (resource 'basic-shader renderer))
        (data (make-array (* 2 (1+ (length points))) :element-type 'single-float)))
    ;; Build point vertex data array
    (loop for point in points
          for i from 0 by 2
          do (setf (aref data (+ 0 i)) (alloy:point-x point))
             (setf (aref data (+ 1 i)) (alloy:point-y point)))
    (setf (aref data (- (length data) 1)) (alloy:point-x (first points)))
    (setf (aref data (- (length data) 2)) (alloy:point-y (first points)))
    (update-vertex-buffer (resource 'rect-vbo renderer) data)
    ;; Draw it
    (bind shader)
    (setf (uniform shader "transform") (simple:transform-matrix (simple:transform renderer)))
    (setf (uniform shader "color") (simple:fill-color renderer))
    (ecase (simple:fill-mode renderer)
      (:fill (draw-vertex-array (resource 'poly-vao renderer) :triangle-fan (1+ (length points))))
      (:lines (draw-vertex-array (resource 'poly-vao renderer) :line-strip (1+ (length points)))))))

(defmethod simple:image ((renderer renderer) point image &key (size (simple:size image)))
  (let ((shader (resource 'image-shader renderer)))
    (bind shader)
    (bind image)
    (simple:with-pushed-transforms (renderer)
      (simple:translate renderer point)
      (simple:scale renderer (alloy:size (alloy:size-w size) (alloy:size-h size)))
      (setf (uniform shader "transform") (simple:transform-matrix (simple:transform renderer))))
    (draw-vertex-array (resource 'rect-fill-vao renderer) :triangles 6)))

(defmethod simple:clear ((renderer renderer) extent)
  (gl:blend-func :zero :zero)
  (unwind-protect
       (simple:rectangle renderer extent)
    (setf (simple:composite-mode renderer) (simple:composite-mode renderer))))

(defmethod simple:request-image :around ((renderer renderer) imagespec)
  (or (resource imagespec renderer NIL)
      (let ((image (call-next-method)))
        (when (alloy:allocated-p renderer)
          (alloy:allocate image))
        (setf (resource imagespec renderer) image))))

(defmethod simple:request-font :around ((renderer renderer) fontspec)
  (or (resource fontspec renderer NIL)
      (let ((font (call-next-method)))
        (when (alloy:allocated-p renderer)
          (alloy:allocate font))
        (setf (resource fontspec renderer) font))))
