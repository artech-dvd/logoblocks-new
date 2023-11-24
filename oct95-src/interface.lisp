;;;; Interface for Visual Programming Language. (VPL);;;; Andrew Begel  4/6/95;;; add translation to grid array; objects get placed in array that can be referenced. ;;; update after each move. ;------------------- GLOBALS -----------------------------------(defvar *background*)(defvar *interface-window*)(defun make-interface ()  (when (boundp '*interface-window*)    (when (wptr *interface-window*)      (window-close *interface-window*)))  (setf *interface-window* (make-instance 'interface-window                           :color-p t                           :view-size #@(600 400)                           :window-show nil                           :window-do-first-click t                           :grow-icon-p nil                           :window-title "Brick Logo"))  (let ((main-view          (make-instance 'main            :view-size #@(500 400)           :view-position #@(100 0)))        (palette-view         (make-instance 'palette           :view-size #@(100 400)           :view-position #@(0 0))))    (let ((page1 (make-instance 'page                    :page-container main-view))          (palette-page (make-instance 'page                          :page-container palette-view)))      (setf *background* (make-instance 'background                           :view-size #@(600 400)                           :view-position #@(0 0)                           :view-container *interface-window*                           :main main-view                           :palette palette-view))      (set-view-container (main *background*) *background*)      (set-view-container (palette *background*) *background*)      (setf (page-list main-view) (list page1))      (setf (page-list palette-view) (list palette-page))      (setf (page main-view) page1)      (setf (page palette-view) palette-page)      (setup-offscreens *background*)      (setup-fonts *background*)      (setup-fonts main-view)      (setup-fonts palette-view)      (window-show *interface-window*))))    (defmethod setup-fonts ((view background-view))  (multiple-value-bind (ff ms) (font-codes '("Geneva" 9))    (set-wptr-font-codes (wptr view) ff ms)    (set-wptr-font-codes (buffer1 view) ff ms)    (set-wptr-font-codes (buffer2 view) ff ms)))(defmethod setup-fonts ((View interface-view))  (multiple-value-bind (ff ms) (font-codes '("Geneva" 9))    (set-wptr-font-codes (wptr view) ff ms)))(defmethod setup-offscreens ((view background-view))  (setf (buffer1 view) (make-offscreen-gworld view))  (offscreen (buffer1 view)             (#_eraserect (pref (buffer1 view) :grafport.portrect)))  (setf (buffer2 view) (make-offscreen-gworld view))  (offscreen (buffer2 view)             (#_eraserect (pref (buffer2 view) :grafport.portrect))))(defmethod window-close ((window interface-window))  (loop for page in (page-list (main (car (subviews window))))         do (delete-all-objects page))  (loop for page in (page-list (palette (car (subviews window))))        do (delete-all-objects page))  (kill-interface)  (call-next-method))(defmethod kill-interface ()  (without-interrupts   (kill-offscreen *background*)))(defmethod kill-offscreen ((view background))  (when (buffer1 view)    (#_DisposeGWorld (buffer1 view)))  (setf (buffer1 view) nil)  (when (buffer2 view)    (#_DisposeGWorld (buffer2 view)))  (setf (buffer2 view) nil));;; SAVING OBJECTS(defmethod save-all-objects ((p page))  (loop for obj in (object-list p)        collect (Save-object obj)))(defmethod create-object (obj-type obj-stuff)  (cond ((equal obj-type "ACTION ")          (recreate-action obj-stuff))        ((equal obj-type "ACTION-INPUT ")          (recreate-action-input obj-stuff))        ((equal obj-type "REPEAT ")          (recreate-repeat obj-stuff))        ((equal obj-type "DIGITAL ")          (recreate-digital obj-stuff))        ((equal obj-type "NUMBER-VAR ")          (recreate-number-var obj-stuff))        ((equal obj-type "PROC ")          (recreate-proc obj-stuff))        ((equal obj-type "ANALOG ")         (recreate-analog obj-stuff))));((equal obj-type "ROAD "); (recreate-road obj-stuff))));-------------- TESTING -------------------------------------------------(defun setup ()  (init-action)  (init-digital)  (init-analog)  (init-number-var)  (init-action-input)  (init-action-2input)  (init-proc);  (init-road);  (modem-port)  (unless (find-menu "Brick Logo")    (menu-install (make-brick-logo-menu)))  (unless (find-menu "Page")    (reconstruct-menu-pages 1)    (toggle-page-check-mark 0)))(defun make-test ()  (make-interface)  (add-object-to-interface (page (palette *background*))                           (make-digital "" (list *purple-color* *white-color*)                                          '(|If A| |If B| |If C| |If not A| |If not B| |If not C|)                                          #@(30 10)))  (add-object-to-interface (page (palette *background*))                           (make-analog "" (list *red-color* *white-color*)                                        '(|If A| |If B| |If C| |If D| |If E| |If F|) '(< > =)                                         #@(30 50)))  (add-object-to-interface (page (palette *background*))                            (make-action "" (list *orange-color* *black-color*)                                         '(|A,| |B,| |C,| |D,| |AB,| |BC,| |AC,| |ABC,| |ABCD,|) #@(30 90)))  (add-object-to-interface (page (palette *background*))                           (make-action "" (list *yellow-color* *black-color*) '(|On| |Off|)                                         #@(30 130)))  (add-object-to-interface (page (palette *background*))                           (make-action "" (list *green-color* *black-color*) '(|RD| |ThisWay| |ThatWay|)                                         #@(30 170)))  (add-object-to-interface (page (palette *background*))                           (make-repeat "" (list *blue-color* *white-color*) '(|Repeat|)                                         #@(30 210)))  (add-object-to-interface (page (palette *background*))                           (make-action-input "" (list (make-color 44000 0 65535) *white-color*) '(|OnFor| |Wait|)                                               #@(30 280) 'right))  (add-object-to-interface (page (palette *background*))                           (make-number-var "" (list *light-blue-color* *black-color*) 1                                            #@(30 320) 'left))  (add-object-to-interface (page (palette *background*))                           (make-proc '(|Spider| |Snake| |Cow| |Elephant| |Leopard| |Zebra| |Camel|)                                      '(0 1 2 3 4 5 6) nil #@(30 355))));------------ ADDING and DELETING OBJECTS from the INTERFACE ------------(defmethod add-object-to-interface ((p page) (obj object))  (setf (object-list p) (cons obj (object-list p)))  (when (equal p (page (page-container p)))  ;when you're the visible page    (intelligent-snap-objects (page-container p) (list obj))    (draw (page-container p) (list obj))    (view-draw-contents (page-container p))))(defmethod delete-objects ((p page) list-of-objs)  (when (equal p (page (page-container p)))    (erase (page-container p) list-of-objs))  (loop for obj in list-of-objs do        (setf (object-list p) (reverse (set-difference                                         (object-list p)                                         (list obj))))        (delete-object obj)) ;specialized on each type of object  (when (equal p (page (page-container p)))    (draw (page-container p) (object-list p))    (view-draw-contents (page-container p))))(defmethod delete-all-selected-objects ((p page))  (delete-objects p (loop for obj in (object-list p)                          when (Selected? obj)                          collect obj)))(defmethod delete-all-objects ((p page))  (delete-objects p (object-list p)));----------- ORDERING OBJECTS within the INTERFACE ----------------(defmethod bring-to-front ((p page) (obj object))  (unless (equal (first (object-list p)) obj)    (setf (object-list p) (cons obj                                 (reverse (set-difference                                           (object-list p)                                          (list obj)))))))(defmethod push-to-back ((p page) (obj object))  (unless (equal (last (object-list p)) obj)    (setf (object-list p) (append (reverse (set-difference                                             (object-list p)                                             (list obj)))                                   (list obj)))))(defmethod bring-many-to-front ((p page) list-of-objects)  (setf (object-list p) (append list-of-objects                                 (reverse                                  (set-difference (object-list p)                                                 list-of-objects)))))(defmethod push-many-to-back ((p page) list-of-objects)  (setf (object-list p) (append (reverse (set-difference                                           (object-list p)                                           list-of-objects))                                list-of-objects)));------------------- DRAWING methods on INTERFACE ----------------------(defmethod view-draw-contents ((view background))  (call-next-method))(defmethod view-draw-contents ((view interface-view))  (rlet ((dstrect :rect :topleft #@(0 0)                  :botright (view-size view))         (srcrect :Rect :topleft (view-position view)                  :botright (Add-points (view-position view) (view-size view))))    (copy-from-offscreen view (buffer1 (view-container view))                          srcrect :rect2 dstrect)))(defmethod view-draw-contents :before ((view interface-view))  (rlet ((rect :rect :topleft (view-position view)               :botright (add-points (view-position view) (view-size view))))    (offscreen (buffer1 (view-container view))                (#_framerect rect))))(defmethod draw ((view interface-view) list-of-objs)  (let ((origin (view-position view))        (oinverse (make-point (- (point-h (view-position view)))                              (- (point-v (view-position view))))))    (rlet ((viewrect :rect :topleft (view-position view)                       :botright (add-points (view-position view) (view-size view))))      (offscreen (buffer1 (view-container view))                 (#_cliprect viewrect)                 (loop for obj in list-of-objs do                       (offset-rect (boundrect obj) origin)                       (offset-region (boundrgn obj) origin)                       (draw-object obj (buffer1 (view-container view)))                       (offset-rect (boundrect obj) oinverse)                       (offset-region (boundrgn obj) oinverse))                 (#_cliprect (pref (buffer1 (view-container view)) :grafport.portrect))))))(defmethod erase ((view interface-view) list-of-objs)  (let ((origin (view-position view))        (oinverse (make-point (- (point-h (view-position view)))                              (- (point-v (view-position view))))))    (offscreen (buffer1 (view-container view))               (loop for obj in list-of-objs do                     (offset-rect (boundrect obj) origin)                     (offset-region (boundrgn obj) origin)                     (erase-object obj (buffer1 (view-container view)))                     (offset-rect (boundrect obj) oinverse)                     (offset-region (boundrgn obj) oinverse)))))(defmethod erase-buffer1 ((view interface-view))  (rlet ((rect :rect :topleft (view-position view)               :botright (add-points (View-position view) (view-size view))))    (offscreen (buffer1 (view-container view))               (#_eraserect rect)               (#_framerect rect))))(defmethod erase-buffer2 ((view interface-view))  (rlet ((rect :rect :topleft (view-position view)               :botright (add-points (view-position view) (view-size view))))    (offscreen (buffer2 (view-container view))               (#_eraserect rect)               (#_framerect rect))));------------------- SELECTION of OBJECTS in INTERFACE ---------------------(defmethod select-objects ((view interface-view) list-of-objects)  (loop for obj in list-of-objects        do (setf (selected? obj) t))  (draw view (reverse list-of-objects))  (view-draw-contents view))(defmethod deselect-objects ((view interface-view) list-of-objects)  (loop for obj in (reverse list-of-objects)        when (selected? obj)        do (setf (selected? obj) nil)        (draw view (list obj)))  (view-draw-contents view))(defmethod select-all-objects ((View interface-view))  (loop for obj in (object-list (page view))        do (Setf (Selected? obj) t))  (draw view (reverse (object-list (page view))))  (view-draw-contents view))(defmethod deselect-all-objects ((View interface-view))  (loop for obj in (object-list (page view))        do (Setf (Selected? obj) nil))  (draw view (reverse (object-list (page view))))  (view-draw-contents view))(defmethod get-selected-objects ((view interface-view))  (loop for obj in (object-list (page view))        when (selected? obj)        collect obj));------------------- CLICKING in the INTERFACE ---------------------;;; ok, here are the clicking rules.; click, run the object's cluster on the brick.; double-click, run cluster of code (maybe highlight code first); shift-click, change definition of object; drag, drag object; drag on background; pull open rectangle. ;;; objects are referenced in global coordinates(defmethod find-clicked-object ((view interface-view) where)  (loop for obj in (object-list (page view))        when (point-in-rect-p (boundrect obj) where)        do (when (point-in-region-p (boundrgn obj) where)             (return obj))))(defmethod view-click-event-handler ((view interface-view) where)  (let ((obj (find-clicked-object view where)))    (if obj      (object-click view obj where)      (background-click view where))))(defmethod object-click ((view interface-view) (obj object) where)  (let ((click-or-drag (click-or-drag? view where)))    (if (equal click-or-drag 'drag)      (if (shift-key-p)         (progn ;shift-drag          (bring-to-front (page view) obj) ;; just drag the clicked object          (move-objects view (list obj) where))        (if (selected? obj) ;drag          (let ((list-of-objects (get-selected-objects view)))            (bring-many-to-front (page view) list-of-objects)            (move-objects view list-of-objects where))          (progn ; drag a non-selected object            (deselect-all-objects view)            (bring-to-front (page view) obj)            (move-objects view (list obj) where))))      (unless (equal view (palette *background*)) ;it's a click        (if (shift-key-p) ; shift key?          (if (selected? obj)            (deselect-objects view (list obj)) ; shift-click on selected to deselect            (select-objects view (list obj))) ; shift-click on deselected to select          (if (selected? obj) ; no shift key            (progn               (deselect-all-objects view)              (select-objects view (list obj))) ;click on selected, deselect everyone else            (progn               (deselect-all-objects view)              (bring-to-front (page view) obj)              (if (control-key-p) ;click                (change-definition view obj where)                (if (option-key-p)                  (case (class-name (class-of obj))                    (number-var (change-definition-byten view obj)) ;option click to change by +10                    (proc (change-definition-define view obj))                    (analog (change-definition-rel view obj)))                  ;(road (change-definition-off view obj where)))                  (when (double-click-p)                    (run-cluster view obj)))))))))))(defmethod background-click ((view interface-view) where)  (unless (equal view (palette *background*))    (let ((click-or-drag (click-or-drag? view where)))      (if (equal click-or-drag 'drag)        (rlet ((select-position-rect :rect :topleft where :botright where))          (drag-resize-gray-rect view where select-position-rect (list 'topleft where) t t)          (if (empty-rect-p select-position-rect)            (unless (shift-key-p) (deselect-all-objects view))            (let ((list-of-selected-objects (find-all-objects-inside-rect                                              (object-list (page view))                                             select-position-rect)))              (select-objects view list-of-selected-objects)              (unless (shift-key-p)                (deselect-objects view (set-difference (object-list (page view)) list-of-selected-objects))))))        (unless (shift-key-p) (deselect-all-objects view)))))) ;we just clicked(defun find-all-objects-inside-rect (all-objects select-position-rect)  (rlet ((temp-rect :rect :topleft #@(0 0) :botright #@(0 0)))    (loop for obj in all-objects           do (intersect-rect select-position-rect (boundrect obj) temp-rect)          unless (empty-rect-p temp-rect)          when (rect-in-region-p (boundrgn obj) temp-rect)           collect obj)));------------------- MOVING OBJECTS in INTERFACE --------------------;;; there are a few ways to move things.;;; You can move an object from the main view to the main view;;; and you can move and object from the palette to the main view;; move objects within the main view(defmethod move-objects ((view main) list-of-objs where)  (if (or (> (length (object-list (page view))) 10)          (> (length list-of-objs) 5))    (progn    ;outline move routine      (pre-move-method view list-of-objs)      (move-outline-objects view list-of-objs where)      (intelligent-snap-objects view list-of-objs)      (erase-buffer1 view)      (after-move-method view list-of-objs)      (draw view (reverse (object-list (page view))))      (view-draw-contents view))    (progn    ;real bitmap move routine      (pre-move-method view list-of-objs)      (erase-moving-objs-from-buffer1 view list-of-objs)      (move-draw-objects view list-of-objs where)      (intelligent-snap-objects view list-of-objs)      (erase-buffer1 view)      (after-move-method view list-of-objs)      (draw view (reverse (object-list (page view))))      (view-draw-contents view))))(defmethod pre-move-method ((View main) list-of-objs)  (loop for obj in list-of-objs        do (pre-move view obj)))(defmethod after-move-method ((view main) list-of-objs)  (loop for obj in list-of-objs        do (After-move view obj)))(defmethod move-outline-objects ((view main) list-of-objs where)  (with-focused-view view    (rlet ((limit-rect :rect :topleft #@(0 0) :botright (view-size view))           (slope-rect :rect :topleft #@(0 0) :botright (view-size view)))      (let ((moving-region (new-region)))        (loop for obj in list-of-objs do               (union-region moving-region (boundrgn obj) moving-region))        (let ((dest-point                (#_DragGrayRgn moving-region where                limit-rect slope-rect 0 (%null-ptr))))          (dispose-region moving-region)          (if (eql dest-point #@(-32768 -32768))            'error            (progn              (loop for obj in list-of-objs do                    (offset-rect (boundrect obj) dest-point)                    (offset-region (boundrgn obj) dest-point))              dest-point)))))))(defmethod erase-moving-objs-from-buffer1 ((view main) list-of-objs)  (erase-buffer1 view)  (draw view (set-difference (object-list (page view)) list-of-objs)));;; move objects within that view only. where is referenced in that view;;; returns the final-point where the objects landed (mouse-point);;; objects are destructively modified to appear in new place.(defmethod move-draw-objects ((view interface-view) list-of-objs where)  (let ((old-mouse where)        (new-mouse (view-mouse-position view)))    (let ((final-point new-mouse))      (without-interrupts       (loop while (mouse-down-p) do             (setf new-mouse                    (limit-point-to-view view (view-mouse-position view)))             (unless (equal new-mouse old-mouse)               (let ((diff-mouse (subtract-points new-mouse old-mouse)))                 (displace-objects view list-of-objs diff-mouse))               (setf old-mouse new-mouse)               ;(move-function view list-of-objs)               )             finally (setf final-point new-mouse)))      final-point)))  ;;; way to do this. We have buffer1 with the objects that aren't moving.;;; then we copy that buffer1 to buffer2, draw the objects that are moving in their;;; new places and then blit it to the main screen.(defmethod displace-objects ((view vpl-view) list-of-objs diff-mouse)  (let ((origin (view-position view))        (oinverse (make-point (- (point-h (view-position view)))                              (- (point-v (view-position view)))))        (bigview (View-container view)))    (erase-buffer2 view)    (rlet ((srcrect :rect :topleft origin                    :botright (add-points origin (view-size view)))           (dstrect :rect :topleft #@(0 0) :botright (view-size view)))      ;copy the background to buffer2      (copy-offscreen-to-offscreen (buffer1 bigview) (buffer2 bigview)                                   srcrect)      (let ((changed-rect (make-record :rect :Topleft #@(0 0) :botright #@(0 0))))              ;changed-region (new-region)))        (if (<= (length list-of-objs) 2)          (progn            (offscreen (buffer2 bigview)                       (loop for obj in (reverse list-of-objs) do                             (union-rect changed-rect (boundrect obj) changed-rect)                             (offset-rect (boundrect obj) (add-points diff-mouse origin))                             (offset-region (boundrgn obj) (add-points diff-mouse origin))                             (draw-object obj (buffer2 bigview))                             (offset-rect (boundrect obj) oinverse)                             (offset-region (boundrgn obj) oinverse)                             (union-rect changed-rect (boundrect obj) changed-rect)))            (let ((Dest-rect (copy-rect changed-rect)))              (offset-rect dest-rect (- 0 origin))              (copy-from-offscreen view (buffer2 bigview) srcrect :rect2 dstrect)              (dispose-record dest-rect)              (dispose-record changed-rect)))            ;:rgn changed-region))          (progn             (offscreen (buffer2 bigview)                       (loop for obj in (reverse list-of-objs) do                             (offset-rect (boundrect obj) (add-points diff-mouse origin))                             (offset-region (boundrgn obj) (add-points diff-mouse origin))                             (draw-object obj (buffer2 bigview))                             (offset-rect (boundrect obj) oinverse)                             (offset-region (boundrgn obj) oinverse)))            (copy-from-offscreen view (buffer2 bigview) srcrect :rect2 dstrect)))))))        ;(dispose-region changed-region)))))(defmethod move-objects ((View palette) list-of-objs where)  (let ((background (view-container view))        (main (main (View-container view)))        (new-objs (loop for obj in list-of-objs                        collect (copy-obj obj))))    (let ((oinverse (make-point (- (point-h (view-position main)))                                (- (point-v (view-position main))))))      (let ((final-position              (move-draw-objects-background               background new-objs               (convert-coordinates where view background))))        (if (view-contains-point-p main final-position)          (progn             (loop for obj in new-objs do                  (offset-rect (boundrect obj) oinverse)                  (offset-region (boundrgn obj) oinverse)                  (add-object-to-interface (page main) obj))            (view-draw-contents main)            (erase-buffer1 view)            (draw view (reverse (object-list (page view))))            (view-draw-contents view))          (progn            (loop for obj in new-objs do                  (delete-object obj))            (erase-buffer1 view)            (draw view (reverse (object-list (page view))))            (view-draw-contents view)            (view-draw-contents main)))))))(defmethod move-draw-objects-background ((view background) list-of-objs where)  (let ((old-mouse where)        (new-mouse (view-mouse-position view)))    (let ((final-point new-mouse))      (without-interrupts       (loop while (mouse-down-p) do             (setf new-mouse                    (limit-point-to-view view (view-mouse-position view)))             (unless (equal new-mouse old-mouse)               (let ((diff-mouse (subtract-points new-mouse old-mouse)))                 (displace-objects-background view list-of-objs diff-mouse))               (setf old-mouse new-mouse)               (move-function view list-of-objs))             finally (setf final-point new-mouse)))      final-point)))(defmethod displace-objects-background ((view background) list-of-objs diff-mouse)    (erase-buffer2 (palette view))    (erase-buffer2 (main view))    (rlet ((rect :rect :topleft #@(0 0) :botright (view-size view)))      (copy-offscreen-to-offscreen (buffer1 view) (buffer2 view)                                   rect)      (let ((changed-region (new-region)))        (offscreen (buffer2 view)                   (loop for obj in list-of-objs do                         (union-region (boundrgn obj) changed-region changed-region)                         (offset-rect (boundrect obj) diff-mouse)                         (offset-region (boundrgn obj) diff-mouse)                         (union-region (boundrgn obj) changed-region changed-region)                         (draw-object obj (buffer2 view))))        (copy-from-offscreen view (buffer2 view) rect :rgn changed-region)        (dispose-region changed-region))))(defmethod limit-point-to-view ((view vpl-view) mouse-point)  (let ((topleft #@(0 0))        (botright (view-size view)))    (if (> (point-h mouse-point) (point-h botright))      (setf mouse-point (make-point (point-h botright)                                    (point-v mouse-point)))      (when (< (point-h mouse-point) (point-h topleft))        (setf mouse-point (make-point (point-h topleft)                                      (point-v mouse-point)))))    (if (> (point-v mouse-point) (point-v botright))      (setf mouse-point (make-point (point-h mouse-point)                                    (point-v botright)))      (when (< (point-v mouse-point) (point-v topleft))        (setf mouse-point (make-point (point-h mouse-point)                                      (point-v topleft)))))    mouse-point))             (defmethod move-function ((view vpl-view) list-of-objs)  ());------------- GRID FUNCTIONS --------------------------(defmethod snap-objects-to-grid ((view interface-view) list-of-objs)  (let ((grid-x (grid-space-x view))        (grid-y (Grid-space-y view)))    (loop for obj in list-of-objs do          (let ((left-offset (mod (left (boundrect obj)) grid-x))                (top-offset (mod (top (boundrect obj)) grid-y)))            (let ((x-offset (if (>= left-offset (/ grid-x 2))                             (- grid-x left-offset)                             (- left-offset)))                  (y-offset (if (>= top-offset (/ grid-y 2))                            (- grid-y top-offset)                            (- top-offset))))              (move-object obj (make-point (+ (left (boundrect obj))                                              x-offset)                                           (+ (top (boundrect obj))                                              y-offset)))))))) ;;; each object has a specific method for what it wants to snap to (defmethod intelligent-snap-objects ((view interface-view) list-of-objs)  (loop for obj in list-of-objs do        (snap-objs obj (object-list (page view)))))(defun top? (angle)  (or (>= angle 335) (< angle 25))) (defun botleft? (angle)  (and (> angle 210) (< angle 260)))(defun left? (angle)  (and (> angle 245) (< angle 295)))(defun topleft? (angle)  (and (> angle 260) (< angle 330)))(defun bottom? (angle)  (and (>= angle 155) (< angle 205)))(defun botright? (angle)  (and (> angle 80) (< angle 150))) (defun right? (angle)  (and (>= angle 65) (< angle 115)))(defun topright? (angle)  (and (> angle 30) (< angle 80)))(defmethod snap-box ((moveobj object) (toobj object) angle)  (if (top? angle)    (snap-to moveobj toobj (bot-target toobj))    (if (left? angle)      (snap-to moveobj toobj (right-target toobj))      (if (right? angle)        (snap-to moveobj toobj (left-target toobj))        (if (bottom? angle)          (snap-to moveobj toobj (top-target toobj)))))))(defmethod snap-box-proc ((moveobj object) (toobj object) angle)  (if (top? angle)    (snap-to moveobj toobj (bot-proc-target toobj))    (if (left? angle)      (snap-to moveobj toobj (right-target toobj))      (if (right? angle)        (snap-to moveobj toobj (left-proc-target toobj))        (if (bottom? angle)          (snap-to moveobj toobj (top-proc-target toobj)))))))(defmethod snap-box-proc-not-left ((moveobj proc) (toobj object) angle)  (if (top? angle)    (snap-to moveobj toobj (bot-proc-target toobj))    (if (right? angle)      (snap-to moveobj toobj (left-proc-target toobj))      (if (bottom? angle)        (snap-to moveobj toobj (top-proc-target toobj))))))(defmethod snap-box-proc-not-right ((moveobj object) (toobj object) angle)  (if (top? angle)    (snap-to moveobj toobj (bot-repeat-target toobj))    (if (left? angle)      (snap-to moveobj toobj (right-target toobj))      (if (bottom? angle)        (snap-to moveobj toobj (top-action-target toobj))))))(defmethod snap-box-proc-all ((moveobj object) (toobj object) angle)  (if (top? angle)    (snap-to moveobj toobj (bot-repeat-target toobj))    (if (left? angle)      (snap-to moveobj toobj (right-target toobj))      (if (bottom? angle)        (snap-to moveobj toobj (top-action-target toobj))        (if (right? angle)          (snap-to moveobj toobj (left-target toobj)))))))(defmethod snap-box-not-left ((moveobj object) (toobj object) angle)  (if (top? angle)    (snap-to moveobj toobj (bot-target toobj))    (if (right? angle)      (snap-to moveobj toobj (left-target toobj))      (if (bottom? angle)        (snap-to moveobj toobj (top-target toobj))))))(defmethod snap-box-not-right ((moveobj object) (toobj object) angle)  (if (top? angle)    (snap-to moveobj toobj (bot-target toobj))    (if (left? angle)      (snap-to moveobj toobj (right-target toobj))      (if (bottom? angle)        (snap-to moveobj toobj (top-target toobj))))))(defmethod snap-box-not-right-or-left ((moveobj object) (toobj object) angle)  (if (top? angle)    (snap-to moveobj toobj (bot-target toobj))    (if (bottom? angle)      (snap-to moveobj toobj (top-target toobj)))))(defmethod snap-to ((moveobj object) (toobj object) target)  (let ((offset (subtract-points (add-points (topleft (boundrect toobj))                                             target)                                 (topleft (boundrect moveobj)))))    (snap-move-object moveobj offset)))(defmethod snap-move-object ((obj object) offset)  (offset-rect (boundrect obj) offset)  (offset-region (boundrgn obj) offset));------------------------ KEY EVENTS ------------------------------------;;; if you press delete, delete all selected objects(defmethod view-key-event-handler ((window interface-window) char)  (when (equal char #\Delete)    (delete-all-selected-objects (page (main (car (subviews window)))))    (call-next-method)))