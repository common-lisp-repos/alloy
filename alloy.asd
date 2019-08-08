#|
This file is a part of Alloy
(c) 2019 Shirakumo http://tymoon.eu (shinmera@tymoon.eu)
Author: Nicolas Hafner <shinmera@tymoon.eu>
|#

(asdf:defsystem alloy
  :version "0.0.0"
  :license "zlib"
  :author "Nicolas Hafner <shinmera@tymoon.eu>"
  :maintainer "Nicolas Hafner <shinmera@tymoon.eu>"
  :description ""
  :homepage "https://github.com/Shirakumo/alloy"
  :serial T
  :components ((:file "package")
               (:file "geometry")
               (:file "events")
               (:file "renderer")
               (:file "component")
               (:file "container")
               (:file "focus-tree")
               (:file "layout")
               (:file "ui")
               (:module "layouts"
                :components ((:file "fixed")
                             (:file "linear")))
               (:module "components"
                :components ((:file "base")))
               (:file "documentation"))
  :depends-on (:documentation-utils
               :array-utils)
  :in-order-to ((asdf:test-op (asdf:test-op :alloy-test))))
