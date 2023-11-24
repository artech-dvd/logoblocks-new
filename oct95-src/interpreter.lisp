;;; this will pick an object, and then get the list of its touching objects;;;; then get those objects touching objects until we've gotten no more new objects.;;; then we return that cluster. ;;; returns a list of cons cells, of the object, and the angle to it from the center;;; of the object to the center of the touching object(defmethod list-of-touching-objects ((p page) (obj object))  (let ((temp-reg (copy-region (boundrgn obj)))        (temp-rect (copy-rect (boundrect obj)))        (final-reg (new-region)))    (rlet ((final-rect :rect :topleft 0 :botright 0))      (inset-region temp-reg -1 -1)      (inset-rect temp-rect -1 -1)      (let ((foo             (loop for object in (object-list p)                   do (set-empty-region final-reg)                   (points-to-rect 0 0 final-rect)                   unless (equal object obj)                   do (intersect-rect temp-rect (boundrect object) final-rect)                   and unless (empty-rect-p final-rect)                   do (intersect-region (boundrgn object) temp-reg final-reg)                   and unless (empty-region-p final-reg)                   collect (cons object (point-to-angle                                          (boundrect obj)                                          (center-rect (boundrect object)))))))        (dispose-region final-reg)        (dispose-region temp-reg)        foo))))#|;; this is special cased. a road cares where the objects are inside of it.;; returns a list of conses, (cons object local-coor) where local-coor is the coordinates;; of the touching object with respect to the topleft of the road(defmethod list-of-touching-objects ((p page) (obj road))  (let ((temp-reg (copy-region (boundrgn obj)))        (temp-rect (copy-rect (boundrect obj)))        (final-reg (new-region)))    (rlet ((final-rect :rect :topleft 0 :botright 0))      (inset-region temp-reg -1 -1)      (inset-rect temp-rect -1 -1)      (let ((foo             (loop for object in (object-list p)                   do (set-empty-region final-reg)                   (points-to-rect 0 0 final-rect)                   unless (equal object obj)                   do (intersect-rect temp-rect (boundrect object) final-rect)                   and unless (empty-rect-p final-rect)                   do (intersect-region (boundrgn object) temp-reg final-reg)                   and unless (empty-region-p final-reg)                   collect (cons object (subtract-points (topleft (boundrect object))                                                          (topleft (boundrect obj)))))))        (dispose-region final-reg)        (dispose-region temp-reg)        foo))))|#(defmethod form-clusters ((p page))  (let ((found-objs nil)        (remaining-objects (object-list p))        (cluster nil))    (loop while remaining-objects do          (setf cluster (form-cluster p (list (car remaining-objects))                                      nil (list (car remaining-objects))))          (setf found-objs (append found-objs (car cluster)))          (setf remaining-objects (set-difference remaining-objects found-objs))          collect cluster)))        (defmethod form-cluster ((p page) object-queue final-cluster all-objs)  (if (null object-queue)    final-cluster    (let* ((partial-cluster (Return-partial-cluster p (car object-queue)))           (objects (set-difference (car partial-cluster) all-objs))           (touch-list (cadr partial-cluster))           (cluster (list (append (car final-cluster) (list (car object-queue)))                          (append (cadr final-cluster) (list touch-list)))))      (form-cluster p (cdr (append object-queue objects)) cluster                     (append all-objs objects)))));;; a cluster is a list of;;; a list of objects in the cluster;;; then a cons cell of (object, touching-list)(defmethod return-partial-cluster ((p page) obj)  (let ((touching-list (list-of-touching-objects p obj)))    (list (cons obj (loop for object in touching-list                          collect (car object)))          (cons obj touching-list))))(defun objects (cluster)  (car cluster))(defun mini-clusters (cluster)  (cadr cluster))(defun touching-objects (mini-cluster)  (cdr mini-cluster));;;; ---------------------- INTERFACE to INTERFACE --------------------;;;; -----------------------INTERPRETER ---------------------------;;; Ok, now once I have a cluster, I need to be able to scan it and;;; interpret it. I think each type of object should have a method for ;;; interpreting a mini-cluster. ;;; ie. If I give a "repeat" object its cluster of itself and a number-var,;;; then it can tell me what the translation is. ;;; so, I'm going to start with the object that is the upperleftmost object, ;;; (note this assumption, top down, left to right translation.) ;;; and then work my way down recursively. If I get a repeat object, it will;;; look for the number-var and then for the list-to-run, and then recurse on the;;; translation of that guy. (define-condition repeat-no-num (simple-condition)  ())(define-condition action-input-no-num (simple-condition)  ((name :accessor name :initarg :name)))(define-condition analog-no-num (simple-condition)  ((name :accessor name :initarg :name)))(define-condition translation-error (simple-condition)  ())(defun error-message (text)  (ed-beep)  (message-dialog text))(defmethod translate-cluster ((p page) cluster)  (let ((topleft (view-size (page-container p)))        (topleft-object (car (objects cluster))))    (loop for obj in (objects cluster)          when (< (topleft (boundrect obj)) topleft)          do (setf topleft (topleft (boundrect obj)))          (setf topleft-object obj))    (let ((mc            (loop for mc in (mini-clusters cluster)                  when (equal topleft-object (car mc))                 return mc)))      (handler-case (translate-object topleft-object cluster mc)        (repeat-no-num () (error-message "Repeat needs a number for input.")                       (error (make-condition 'translation-error)))        (action-input-no-num (condition)                              (error-message (format nil "~A needs a number for input."                                                     (name condition)))                             (error (make-condition 'translation-error)))        (analog-no-num (condition)                       (error-message (format nil "~A needs a number for input."                                              (name condition)))                       (error (make-condition 'translation-error)))))));; takes a cons of an object and a direction 0-360, logo style(defun on-top? (tobj)  (let ((dir (cdr tobj)))    (or (> dir 345) (< dir 15))))(defun on-topright? (tobj)  (let ((Dir (cdr tobj)))    (or (> dir 55) (< dir 75))))(defun on-right? (tobj)  (let ((dir (cdr tobj)))    (and (> dir 75) (< dir 105))))(defun on-botright? (tobj)  (let ((dir (cdr tobj)))    (and (> dir 100) (< dir 120))))(defun on-bottom? (tobj)  (let ((dir (cdr tobj)))    (and (> dir 165) (< dir 195))))(defun on-left? (tobj)  (let ((dir (cdr tobj)))    (and (> dir 255) (< dir 285))));----------------------- TRANSLATION ---------------------------;;; repeat wants a number object to its topright, and then a ;;; list of things to do botright it.(defmethod translate-object ((obj repeat) cluster minicluster)  (let ((to (touching-objects minicluster)))    ;;; look for number-var    (let ((num (loop for tobj in to                      when (equal (class-name (class-of (car tobj))) 'number-var)                     when (on-topright? tobj)                     return (car tobj)))          (list-to-run (loop for tobj in to                             when (on-botright? tobj)                             return (car tobj)))          (next-to-run (loop for tobj in to                             when (on-bottom? tobj)                             return (car tobj))))      (let ((mclist (loop for mc in (mini-clusters cluster)                           when (equal list-to-run (car mc))                          return mc))            (mcnext (loop for mc in (mini-clusters cluster)                          when (equal next-to-run (car mc))                          return mc)))        (let ((translist (when list-to-run                           (translate-object list-to-run cluster mclist)))              (nextlist (when next-to-run                          (translate-object next-to-run cluster mcnext))))          (unless num (error (make-condition 'repeat-no-num)))          (append (list (currentdef obj) (when num (currentdef num))                        '[ translist '])                  nextlist))))));;; repeat was sort of a bastardized action-input;;; this one is correct, take a number input, and then ;;; run the next thing(defmethod translate-object ((obj action-input) cluster minicluster)  (let ((to (touching-objects minicluster)))    ;;; look for number-var    (let ((num (loop for tobj in to                      when (equal (class-name (class-of (car tobj))) 'number-var)                     when (on-right? tobj)                     return (car tobj)))          (first-to-run (loop for tobj in to                              when (on-bottom? tobj)                              return (car tobj))))      (let ((mcnum (loop for mc in (mini-clusters cluster)                         when (equal num (car mc))                         return mc))            (mcfirst (loop for mc in (mini-clusters cluster)                            when (equal first-to-run (car mc))                           return mc)))        (let ((numlist (when num                         (translate-object num cluster mcnum)))              (firstlist (when first-to-run                           (translate-object first-to-run cluster mcfirst))))          (unless num (error (make-condition 'action-input-no-num                                              :name (symbol-name (currentdef obj)))))          (append (list (currentdef obj)) numlist firstlist))))))(defmethod translate-object ((obj analog) cluster minicluster)  (let ((to (touching-objects minicluster)))    ;;; look for number-var    (let ((num (loop for tobj in to                      when (equal (class-name (class-of (car tobj))) 'number-var)                     when (on-right? tobj)                     return (car tobj)))          (first-to-run (loop for tobj in to                              when (on-bottom? tobj)                              return (car tobj))))      (let ((mcnum (loop for mc in (mini-clusters cluster)                         when (equal num (car mc))                         return mc))            (mcfirst (loop for mc in (mini-clusters cluster)                            when (equal first-to-run (car mc))                           return mc)))        (let ((numlist (when num                         (translate-object num cluster mcnum)))              (firstlist (when first-to-run                           (translate-object first-to-run cluster mcfirst))))          (unless num (error (make-condition 'analog-no-num                                              :name (concatenate 'string                                                                 (symbol-name (currentdef obj)) " "                                                                (symbol-name (currentrel obj))))))          (append (list (currentdef obj) (currentrel obj)) numlist firstlist))))));return the translate-object of the items on the right(defmethod translate-object ((variable number-var) cluster minicluster)  (let ((to (touching-objects minicluster)))    (let ((list-to-run (loop for tobj in to                             when (on-right? tobj)                             return (car tobj))))      (let ((mclist (loop for mc in (mini-clusters cluster)                          when (equal list-to-run (Car mc))                          return mc)))        (let ((list (when list-to-run                      (translate-object list-to-run cluster mclist))))          (append (list (currentdef variable)) list))))));;; return your definition plus the definition of the objects below you,;;; then those to the right of you.(defmethod translate-object ((obj action) cluster minicluster)  (let ((to (touching-objects minicluster)))    (let ((next-to-run (loop for tobj in to                             when (on-right? tobj)                             return (car tobj)))          (after-to-run (loop for tobj in to                              when (on-bottom? tobj)                              return (car tobj))))      (let ((mcnext (loop for mc in (mini-clusters cluster)                           when (equal next-to-run (car mc))                          return mc))            (mcafter (loop for mc in (mini-clusters cluster)                            when (equal after-to-run (car mc))                           return mc)))        (let ((nextlist (when next-to-run                           (translate-object next-to-run cluster mcnext)))              (afterlist (when after-to-run                            (translate-object after-to-run cluster mcafter))))          (append (list (currentdef obj)) nextlist afterlist))))))  ;;; take this as a trigger and return this definition with a list-to-run(defmethod translate-object ((obj digital) cluster minicluster)  (let ((to (touching-objects minicluster)))    (let ((next-to-run (loop for tobj in to                             when (on-right? tobj)                             return (car tobj)))          (after-to-run (loop for tobj in to                              when (on-bottom? tobj)                              return (car tobj))))      (let ((mcnext (loop for mc in (mini-clusters cluster)                           when (equal next-to-run (car mc))                          return mc))            (mcafter (loop for mc in (mini-clusters cluster)                            when (equal after-to-run (car mc))                           return mc)))        (let ((nextlist (when next-to-run                           (translate-object next-to-run cluster mcnext)))              (afterlist (when after-to-run                            (translate-object after-to-run cluster mcafter))))          (append (list (currentdef obj)) nextlist afterlist)))))) ;; this is a procedure name with a list to run(defmethod translate-object ((obj proc) cluster minicluster)  (let ((to (touching-objects minicluster)))    (let ((next-to-run (loop for tobj in to                             when (on-right? tobj)                             return (car tobj)))          (after-to-run (loop for tobj in to                              when (on-bottom? tobj)                              return (car tobj))))      (let ((mcnext (loop for mc in (mini-clusters cluster)                           when (equal next-to-run (car mc))                          return mc))            (mcafter (loop for mc in (mini-clusters cluster)                            when (equal after-to-run (car mc))                           return mc)))        (let ((nextlist (when next-to-run                           (translate-object next-to-run cluster mcnext)))              (afterlist (when after-to-run                            (translate-object after-to-run cluster mcafter))))          (append (if (define? obj)                     (list 'define (proc-name obj))                    (list (proc-name obj)))                  nextlist afterlist))))))#|(defmethod middle-road? ((obj road) tobj)  (rlet ((rect :rect :topleft (cdr tobj) :botright (Add-points (cdr tobj)                                                         (rect-size (boundrect (car tobj))))))    (intersect-rect (middle-rect obj) rect rect)    (unless (empty-rect-p rect)      (let ((temp-region (copy-region (boundrgn (car tobj))))            (reg (new-region)))        (move-region temp-region (cdr tobj))        (set-rect-region reg (middle-rect obj))        (intersect-region temp-region reg reg)        (let ((result (not (empty-region-p reg))))          (dispose-region temp-region)          (dispose-region reg)          result)))))(defmethod up-road-side? ((obj road) tobj)  (> (point-h (cdr tobj)) (/ (rect-width (boundrect obj)) 2)))    (Defmethod cross-up-edge? ((obj road) tobj)  (rlet ((temprect :rect :topleft 0 :botright 0)         (rect :rect :topleft (cdr tobj)                :botright (Add-points (cdr tobj)                                     (rect-size (boundrect (car tobj))))))    (loop for edge in (up-edge-list obj)          do (intersect-rect (boundrect edge) rect temprect)          unless (empty-rect-p temprect)          return edge)))(Defmethod cross-down-edge? ((obj road) tobj)  (rlet ((temprect :rect :topleft 0 :botright 0)         (rect :rect :topleft (cdr tobj)                :botright (Add-points (cdr tobj)                                     (rect-size (boundrect (car tobj))))))    (loop for edge in (down-edge-list obj)          do (intersect-rect (boundrect edge) rect temprect)          unless (empty-rect-p temprect)          return edge)))(defmethod translate-object ((obj road) cluster minicluster)  (let ((to (touching-objects minicluster)))    (let ((mid-list (loop for tobj in to                          when (middle-road? obj tobj)                          collect tobj)))      (setf to (reverse (set-difference to mid-list)))      (let* ((up-list (loop for tobj in to                           when (up-road-side? obj tobj)                           collect tobj))             (down-list (reverse (set-difference to up-list))))        ;; for now union mid-list with up-list and down-list        (setf up-list (union up-list mid-list))        (setf down-list (union down-list mid-list))        (print up-list)        (print down-list)        (let ((up-edge-list (loop for tobj in up-list                                   with foo = (cross-up-edge? obj tobj)                                  when foo                                  collect (cons tobj foo)))              (down-edge-list (loop for tobj in down-list                                    with foo = (cross-down-edge? obj tobj)                                    when foo                                    collect (cons tobj foo))))          (print up-list)          (print up-edge-list)          (print down-list)          (print down-edge-list))))))|#;;;;; ----------------- Brick Logo to Brick Pseudo-Code Translator;;; takes a parsed Logo statement.;; switches from Brick Logo names to appropriate opcodes(defun translate-def (symbol)  (case symbol    (|On| '<on>)    (|Off| '<off>)    (|A,| '<a>)    (|B,| '<b>)    (|C,| '<c>)    (|D,| '<d>)    (|AB,| '<ab>)    (|AC,| '<ac>)    (|BC,| '<bc>)    (|ABC,| '<abc>)    (|ABCD,| '<abcd>)    (|ThisWay| '<thisway>)    (|ThatWay| '<thatway>)    (|RD| '<rd>)    (|Repeat| '<repeat>)    (|OnFor| '<onfor>)    (|Wait| '<wait>)    (< '<<>)    (> '<>>)    (= '<=>)    (>= '<>=>)    (<= '<<=>)))(defun translate-sensor (symbol digital?)  (if digital?    (case symbol       (|If A| '<switcha>)      (|If B| '<switchb>)      (|If C| '<switchc>)      (|If not A| '('not <switcha>))      (|If not B| '('not <switchb>))      (|If not C| '('not <switchc>)))    (case symbol       (|If A| '<sensora>)      (|If B| '<sensorb>)      (|If C| '<sensorc>)      (|If D| '<sensord>)      (|If E| '<sensore>)      (|If F| '<sensorf>))))(defun high (num)  (floor (/ num 256)))(defun low (num)   (mod num 256))(define-condition bad-define (simple-condition)  ((def :initarg :def :accessor def)))(defvar *code*)(defun parse-logo (logo-code)  (setf *code* logo-code)  (let ((Result nil))    (tail-call?) ;check for tail recursion    (setf result (append result (parse-one (car *code*) -1)))     (loop while *code* do          (setf result (append result (parse-one (car *code*) 0))))     ;;; post processing of procedures        ;;process proc calls into real proc codes    (let ((temp nil))      (loop for item in result            for count from 0 to (length result)            when (equal item '16bit)            do             (setf temp (append temp (list (list item (nth (1+ count) result)))))            (setf (nth (1+ count) result) nil)            else do (unless (null item)                      (setf temp (append temp (list item)))))      (when (equal (car temp) 'define)        (setf temp (append (list 'proc (cadr (caddr temp)) 0 0) (cdddr temp))))      (let ((pos (position 'define temp)))        (when pos           (error (make-condition 'bad-define :def (symbol-name (cadr (nth (+ pos 2) temp)))))))       temp)))(defun parse-one (opcode opcode-num)  (let ((result nil))    (setf *code* (cdr *code*))    (setf opcode-num (1+ opcode-num))    (when (numberp opcode)      (setf result (list '<%num> (high opcode) (low opcode))))    (when (equal opcode '[)   ;lists are embedded      (setf result (parse-list)))    (when (equal opcode '])      (setf result (list '<%eol>)))    (when (member opcode '(|If A| |If B| |If C| |If D| |If E| |If F| |If not A| |If not B| |If not C|))      (setf result (handle-sensor opcode opcode-num)))    (when (equal opcode 'define)      (setf result (list 'define))      (setf result (append result (parse-one (car *code*) opcode-num))) ;get the name      (setf result (append result (parse-one (car *code*) -1)))) ;in case of a sensor    (when (member opcode '(|Spider| |Snake| |Cow| |Elephant| |Leopard| |Zebra| |Camel|))      (setf result (list '<%proc> '16bit opcode)))    (when (equal opcode '<tail>)      (setf result (append result (parse-one (car *code*) opcode-num)))      (setf (nth (- (length result) 3) result) '<%tproc>))    (let ((topcode (translate-def opcode)))      (when (member topcode '(<on> <off> <thisway> <thatway> <rd>))        (setf result (list topcode)))      (when (member topcode '(<a> <b> <c> <d> <ab> <ac> <bc> <abc> <abcd>))        (setf result (list topcode)))      (when (equal topcode '<repeat>)        (setf result (parse-one (car *code*) opcode-num)) ; #times        (setf result (append result (parse-one (car *code*) opcode-num))) ;listtorun        (setf result (append result (parse-one (car *code*) opcode-num))) ;grab the <%eol>        (setf result (append result (list topcode)))) ;repeat      (when (member topcode '(<onfor> <wait>))        (setf result (parse-one (car *code*) opcode-num)) ;#times        (setf result (append result (list topcode))))) ;wait or onfor    result))  (defun handle-sensor (opcode opcode-num)  (let ((Result nil))    (if (zerop opcode-num) ;it's the first one, this should be a when      (if (member (car *code*) '(< > <= >= =)) ; is yes, we're analog        (progn          (setf result (list '<%list> 0 6 (translate-sensor opcode nil)                              '<%num> (high (cadr *code*)) (low (cadr *code*))                             (translate-def (car *code*))                             '<%eolr>))          (setf *code* (cddr *code*))          (setf *code* (append (list '[)                               (list *code*)                               (list '])))          (setf result (append result (parse-one (car *code*) opcode-num))) ;listtorun          (setf result (append result (parse-one (car *code*) opcode-num))) ;grab %eol          (setf result (append result (list '<when>))))        (progn          (let ((topcode (translate-sensor opcode t)))            (if (listp topcode)              (setf result (list '<%list> 0 3 (cadr topcode) '<not> '<%eolr>))              (setf result (list '<%list> 0 2 topcode '<%eolr>))))          (setf *code* (append (list '[)                               (list *code*)                               (list '])))          (setf result (append result (parse-one (car *code*) opcode-num))) ;listtorun          (setf result (append result (parse-one (car *code*) opcode-num))) ;grab %eol          (setf result (append result (list '<when>)))))      (if (member (car *code*) '(< > <= >= =)) ; if yes, we're analog        (progn           (setf result (list '<%list> 0 6 (translate-sensor opcode nil)                              '<%num> (high (cadr *code*)) (low (cadr *code*))                             (translate-def (car *code*))                             '<%eolr> '<waituntil>))          (setf *code* (cddr *code*)))        (progn          (let ((topcode (translate-sensor opcode t)))            (if (listp topcode)              (setf result (list '<%list> 0 3 (cadr topcode) '<not> '<%eolr> '<waituntil>))              (setf result (list '<%list> 0 2 topcode '<%eolr> '<waituntil>)))))))    result));if the last thing in the list is a function, replace with the tail-call version     (defun tail-call? ()  (when (and (not (member (car *code*)                          '(|Spider| |Snake| |Cow| |Elephant| |Leopard| |Zebra| |Camel|)))             (member (car (last *code*))                      '(|Spider| |Snake| |Cow| |Elephant| |Leopard| |Zebra| |Camel|)));             (equal (car (last *code*)) (cadr *code*))) ;only tail recurse if it's you    (setf *code* (append (butlast *code*) '(<tail>) (last *code*)))))(defun parse-list ()  (let ((result nil)        (temp-code (copy-list *code*)))    (setf *code* (car *code*))    (setf result (list '<%list>))    (let ((elements nil))      (loop while *code* do            (setf elements (append elements (parse-one (car *code*) 1))))      (setf result (append result (list (high (1+ (length elements))))                           (list (low (1+ (length elements))))                           elements)))    (setf *code* (cdr temp-code))    result));--------------------- DOWNLOADING -----------------------------------(defun view-code ()  (pprint (make-code (main *background*)))) (defmethod make-code ((view interface-view))  (loop for page in (page-list view)         append         (loop for cluster in (form-clusters page)              collect (let ((translation (handler-case (translate-cluster page cluster)                                           (translation-error () nil))))                        (when translation                           (let ((parse                                  (handler-case (parse-logo translation)                                   (bad-define (condition)                                               (error-message                                                 (Format nil "Define ~A is not at the beginning of a procedure."                                                        (def condition)))                                               nil))))                            parse))))))(defun run-graphic-code (list-of-code)  (serial-tyo-echo (char-code #\4))  (erase1)  (let ((defines (deal-with-procs list-of-code)))    (define-menu-items       (loop for codeseg in defines            collect (cadr codeseg)))    (loop for codeseg in list-of-code          unless (equal (car codeseg) 'proc)          do (run-code (translate-all codeseg)))))(defun deal-with-procs (list-of-code)  (let ((defines          (loop for codeseg in list-of-code                when (equal (car codeseg) 'proc)                collect (append codeseg (list '<stop>)))))    (let ((list-of-lengths (length-code defines)))      (loop for codeseg in defines do             (push (cons (cadr codeseg) this-proc) proc-addresses)            (setf this-proc (+ (cdr (assoc (cadr codeseg) list-of-lengths))                               this-proc)))      (maybe-define-null-procs) ;everything should be defined in proc-addresses now      ;;; the null procs are defined in the brick      ;;; now let's download the real functions      (loop for codeseg in defines do            (download-code (cdr (assoc (cadr codeseg) proc-addresses))                           (translate-all (cddr codeseg)))))    defines))      (defun run-one (codeseg)  (serial-tyo-echo (char-code #\4))  (unless (equal (car codeseg) 'proc) ;if we redefine one we have to redefine them all    (run-code (translate-all codeseg))))(defun length-code (list-of-procs)  (let ((result nil))    (loop for proc in list-of-procs          do (push (cons (cadr proc)                          (loop for item in (cddr proc)                               if (atom item)                               sum 1                               else sum 2))                   result))    result))  (defun maybe-define-null-procs ()  (unless (assoc '|Spider| proc-addresses)    (proc |Spider| 0 0))  (unless (assoc '|Snake| proc-addresses)    (proc |Snake| 0 0))  (unless (assoc '|Cow| proc-addresses)    (proc |Cow| 0 0))  (unless (assoc '|Elephant| proc-addresses)    (proc |Elephant| 0 0))  (unless (assoc '|Leopard| proc-addresses)    (proc |Leopard| 0 0))  (unless (assoc '|Zebra| proc-addresses)    (proc |Zebra| 0 0))  (unless (assoc '|Camel| proc-addresses)    (proc |Camel| 0 0)))(defmethod run-cluster ((view interface-view) (obj object))  (let ((cluster (loop for cluster in (form-clusters (page view))                        when (member obj (objects cluster))                       return cluster)))    (run-one (parse-logo (translate-cluster (page view) cluster)))))(defun define-menu-items (defined-proc-names)  (set-pointer menu-address)  (loop for name in defined-proc-names         do (let ((code (translate-all (list '<%proc> (list '16bit name))))                 (procname (symbol-name name)))             (put-byte (length procname))             (loop for letter across procname                   do (put-byte (char-code letter)))             (put-byte (1+ (length code)))             (loop for bytecode in code                   do (put-byte bytecode))             (put-byte 20)))  (loop for i from 1 to (- 7 (length defined-proc-names))        do (dolist (j '(3 45 45 45 1 20))             (put-byte j))))