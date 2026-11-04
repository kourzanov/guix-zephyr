(define-module (zephyr packages zephyr-riscv32-elf)
  #:use-module (srfi srfi-26)
  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:use-module (guix build utils)
  #:use-module (guix build-system gnu)
  #:use-module (guix build-system trivial)
  #:use-module (guix build-system copy)
  #:use-module (guix build-system python)
  #:use-module (guix download)
  #:use-module (guix git-download)
  #:use-module ((guix licenses) :prefix license:)
  #:use-module (guix utils)
  #:use-module (gnu packages)
  #:use-module (gnu packages base)
  #:use-module (gnu packages virtualization)
  #:use-module (gnu packages gcc)
  #:use-module (gnu packages gdb)
  #:use-module (gnu packages cross-base)
  #:use-module (gnu packages multiprecision)
  #:use-module (gnu packages python)
  #:use-module (gnu packages python-xyz)
  #:use-module (gnu packages python-crypto)
  #:use-module (gnu packages check)
  #:use-module (gnu packages autotools)
  #:use-module (gnu packages texinfo)
  #:use-module (gnu packages compiler-tools)
  #:use-module (gnu packages dejagnu)
  #:use-module (gnu packages perl)
  #:use-module (gnu packages autogen)
  #:use-module (gnu packages compression)
  #:use-module (gnu packages embedded)
  #:use-module (gnu packages bootloaders)
  #:use-module (gnu packages bison)
  #:use-module (zephyr packages zephyr)
  #:use-module (zephyr packages python-xyz)
  )

(define-public riscv32-zephyr-elf-binutils-old
  (let ((xbinutils (cross-binutils "riscv32-zephyr-elf")))
    (package
      (inherit xbinutils)
      (name "riscv32-zephyr-elf-binutils")
      (version "2.38")
      (source
       (origin (method git-fetch)
	       (uri (git-reference
		     (url "https://github.com/zephyrproject-rtos/binutils-gdb")
		     (commit "6a1be1a6a571957fea8b130e4ca2dcc65e753469")))
	       (file-name (git-file-name name version))
	       (sha256 (base32 "0ylnl48jj5jk3jrmvfx5zf8byvwg7g7my7jwwyqw3a95qcyh0isr"))))
      (arguments
       (substitute-keyword-arguments (package-arguments xbinutils)
	 ((#:tests? tests '()) #f)
	 ((#:configure-flags flags)
	  #~(cons* "--enable-multilib"
		   "--disable-gdb"
		   "--disable-sim"
		   #$flags))))
      (native-inputs (modify-inputs
	(package-native-inputs xbinutils)
        (append texinfo bison flex gmp dejagnu)))
      (home-page "https://zephyrproject.org")
      (synopsis "binutils for zephyr RTOS"))))

(define-public riscv32-zephyr-elf-binutils
  (let ((xbinutils (cross-binutils "riscv32-zephyr-elf")))
    (package
      (inherit xbinutils)
      (name "riscv32-zephyr-elf-binutils")
      (version "2.43.1")
      (source
       (origin (method git-fetch)
	       (uri (git-reference
		     (url "https://github.com/zephyrproject-rtos/binutils-gdb")
		     (commit "471493f6b7f688d9fa570403b7a08db73bfdfcde")))
	       (file-name (git-file-name name version))
	       (sha256 (base32 "09y52x4gfklsw66l70p129n9m1mw764xyfqpsyahn9c28g83fsng"))))
      (arguments
       (substitute-keyword-arguments (package-arguments xbinutils)
	 ((#:tests? tests '()) #f)
	 ((#:configure-flags flags)
	  #~(cons* "--enable-multilib"
		   "--disable-gdb"
		   "--disable-sim"
		   #$flags))))
      (native-inputs (modify-inputs
	(package-native-inputs xbinutils)
        (append texinfo bison flex gmp dejagnu)))
      (home-page "https://zephyrproject.org")
      (synopsis "binutils for zephyr RTOS"))))

(define-public gcc-riscv32-zephyr-elf-12
  (let ((xgcc (cross-gcc "riscv32-zephyr-elf"
			 #:xgcc gcc-12
			 #:xbinutils riscv32-zephyr-elf-binutils)))
    (package
      (inherit xgcc)
      (name "gcc-riscv32-zephyr-elf")
      (version "12.1.0")
      (source (origin (method git-fetch)
		      (uri (git-reference
			    (url "https://github.com/zephyrproject-rtos/gcc")
			    (commit "0218469df050c33479a1d5be3e5239ac0eb351bf")))
		      (file-name (git-file-name (package-name xgcc) version))
		      (sha256
		       (base32 "1s409qmidlvzaw1ns6jaanigh3azcxisjplzwn7j2n3s33b76zjk"))
		      (patches
		       (search-patches "gcc-12-cross-environment-variables.patch"
				       "gcc-cross-gxx-include-dir.patch"))))
      (native-inputs
       (modify-inputs (package-native-inputs xgcc)
	 (delete "isl")
	 (prepend flex
		  isl-0.15)
         (prepend flex which)))
      (arguments
       (substitute-keyword-arguments (package-arguments xgcc)
	 ((#:phases phases)
	  #~(modify-phases #$phases
	      (add-after 'unpack 'fix-genmultilib
		(lambda _
		  (substitute* "gcc/genmultilib"
		    (("#!/bin/sh") (string-append "#!" (which "sh"))))
		  #t))
	      (add-after 'set-paths 'augment-CPLUS_INCLUDE_PATH
		(lambda* (#:key inputs #:allow-other-keys)
		  (let ((gcc (assoc-ref inputs  "gcc")))
		    ;; Remove the default compiler from CPLUS_INCLUDE_PATH to
		    ;; prevent header conflict with the GCC from native-inputs.
		    (setenv "CPLUS_INCLUDE_PATH"
			    (string-join
			     (delete (string-append gcc "/include/c++")
				     (string-split (getenv "CPLUS_INCLUDE_PATH")
						   #\:))
			     ":"))
		    (format #t
			    "environment variable `CPLUS_INCLUDE_PATH' changed to ~a~%"
			    (getenv "CPLUS_INCLUDE_PATH"))
		    #t)))))
	 ((#:configure-flags flags)
	  #~(append (list "--enable-multilib"
			  "--with-newlib"
			  ;"--with-multilib-list=rmprofile"
			  "--with-host-libstdcxx=-static-libgcc -Wl,-Bstatic,-lstdc++,-Bdynamic -lm"
			  "--enable-plugins"
			  "--disable-libatomic"
			  "--disable-libgomp"
			  "--disable-libmudflap"
			  "--disable-libquadmath"
			  "--disable-libssp"
			  "--disable-nls"
			  "--disable-shared"
			  "--disable-threads"
			  "--disable-tls"
			  "--with-gnu-ld"
			  "--with-gnu-as"
			  "--enable-initfini-array")
		    (delete "--disable-multilib" #$flags)))
	 ((#:make-flags flags)
	  #~(append '("CFLAGS_FOR_TARGET=-g -O2")
		    #$flags))))
      (native-search-paths
       (list (search-path-specification
	      (variable "CROSS_C_INCLUDE_PATH")
	      (files '("riscv32-zephyr-elf/include")))
	     (search-path-specification
	      (variable "CROSS_CPLUS_INCLUDE_PATH")
	      (files '("riscv32-zephyr-elf/include"
		       "riscv32-zephyr-elf/c++"
		       "riscv32-zephyr-elf/c++/riscv32-zephyr-elf")))
	     (search-path-specification
	      (variable "CROSS_LIBRARY_PATH")
	      (files '("riscv32-zephyr-elf/lib")))))
      (home-page "https://zephyrproject.org")
      (synopsis "GCC for zephyr RTOS"))))

(define-public gcc-riscv32-zephyr-elf-14
  (let ((xgcc (cross-gcc "riscv32-zephyr-elf"
			 #:xgcc gcc-14
			 #:xbinutils riscv32-zephyr-elf-binutils)))
    (package
      (inherit xgcc)
      (name "gcc-riscv32-zephyr-elf")
      (version "14.3.0")
      (source (origin (method git-fetch)
		      (uri (git-reference
			    (url "https://github.com/zephyrproject-rtos/gcc")
			    (commit "35930988cbdc3c8dbf577372e5c567acb749ac4d")))
		      (file-name (git-file-name (package-name xgcc) version))
		      (sha256
		       (base32 "0n4r2b1viwq77d7r2qd8fars62jyckk6zrc4w676zq58rs85dsik"))
		      (patches
		       (search-patches "gcc-12-cross-environment-variables.patch"
				       "gcc-cross-gxx-include-dir.patch"))))
      (native-inputs
       (modify-inputs (package-native-inputs xgcc)
	 (delete "isl")
	 (prepend flex
		  isl-0.15)
         (prepend flex which)))
      (arguments
       (substitute-keyword-arguments (package-arguments xgcc)
	 ((#:phases phases)
	  #~(modify-phases #$phases
	      (delete 'pre-x86-configure)
	      (add-after 'unpack 'fix-genmultilib
		(lambda _
		  (substitute* "gcc/genmultilib"
		    (("#!/bin/sh") (string-append "#!" (which "sh"))))
		  #t))
	      (add-after 'set-paths 'augment-CPLUS_INCLUDE_PATH
		(lambda* (#:key inputs #:allow-other-keys)
		  (let ((gcc (assoc-ref inputs  "gcc")))
		    ;; Remove the default compiler from CPLUS_INCLUDE_PATH to
		    ;; prevent header conflict with the GCC from native-inputs.
		    (setenv "CPLUS_INCLUDE_PATH"
			    (string-join
			     (delete (string-append gcc "/include/c++")
				     (string-split (getenv "CPLUS_INCLUDE_PATH")
						   #\:))
			     ":"))
		    (format #t
			    "environment variable `CPLUS_INCLUDE_PATH' changed to ~a~%"
			    (getenv "CPLUS_INCLUDE_PATH"))
		    #t)))
		))
	 ((#:configure-flags flags)
	  #~(append (list "--enable-multilib"
			  "--with-newlib"
			  ;"--with-multilib-list=rmprofile"
			  "--with-host-libstdcxx=-static-libgcc -Wl,-Bstatic,-lstdc++,-Bdynamic -lm"
			  "--enable-plugins"
			  "--disable-libatomic"
			  "--disable-libgomp"
			  "--disable-libmudflap"
			  "--disable-libquadmath"
			  "--disable-libssp"
			  "--disable-nls"
			  "--disable-shared"
			  "--disable-threads"
			  "--disable-tls"
			  "--with-gnu-ld"
			  "--with-gnu-as"
			  "--enable-initfini-array")
		    (delete "--disable-multilib" #$flags)))
	 ((#:make-flags flags)
	  #~(append '("CFLAGS_FOR_TARGET=-g -O2")
		    #$flags))))
      (native-search-paths
       (list (search-path-specification
	      (variable "CROSS_C_INCLUDE_PATH")
	      (files '("riscv32-zephyr-elf/include")))
	     (search-path-specification
	      (variable "CROSS_CPLUS_INCLUDE_PATH")
	      (files '("riscv32-zephyr-elf/include"
		       "riscv32-zephyr-elf/c++"
		       "riscv32-zephyr-elf/c++/riscv32-zephyr-elf")))
	     (search-path-specification
	      (variable "CROSS_LIBRARY_PATH")
	      (files '("riscv32-zephyr-elf/lib")))))
      (home-page "https://zephyrproject.org")
      (synopsis "GCC for zephyr RTOS"))))

(define-public riscv32-zephyr-elf-newlib-old
  (package
    (name "newlib-riscv32")
    (version "3.3")
    (source (origin
	      (method git-fetch)
	      (uri (git-reference
		    (url "https://github.com/zephyrproject-rtos/newlib-cygwin")
		    ;(commit "4e150303bcc1e44f4d90f3489a4417433980d5ff")
		    (commit "fc14a1b4c2fb7ccb860e323bd22faca0b2735b2a")
		    ))
	      (sha256
	       (base32 "08qwjpj5jhpc3p7a5mbl7n6z7rav5yqlydqanm6nny42qpa8kxij"))))
    (build-system gnu-build-system)
    (arguments
     `(#:out-of-source? #t
       #:configure-flags '("--target=riscv32-zephyr-elf"
			   "--enable-headers"
			   "--enable-newlib-io-long-long"
			   "--enable-newlib-io-float"
			   "--enable-newlib-io-c99-formats"
			   "--enable-newlib-retargetable-locking"
			   "--enable-newlib-lite-exit"
			   "--enable-newlib-multithread"
			   "--enable-newlib-register-fini"
			   "--enable-newlib-extra-sections"
			   "--disable-newlib-nano-malloc"
			   "--disable-newlib-nano-formatted-io"
			   "--disable-newlib-wide-orient"
			   "--disable-newlib-fseek-optimization"
			   "--disable-newlib-supplied-syscalls"
			   "--disable-newlib-target-optspace"
			   "--disable-nls")
       #:make-flags '("CFLAGS_FOR_TARGET=\"-O2 -Wno-implicit-function-declaration\"")
       #:phases
       (modify-phases %standard-phases
	 (add-after 'unpack 'fix-references-to-/bin/sh
	   (lambda _
	     (substitute* '("libgloss/libnosys/Makefile.in"
			    "libgloss/Makefile.in")
	       (("/bin/sh") (which "sh")))
	     #t)))))
    (native-inputs
     `(("xbinutils" ,riscv32-zephyr-elf-binutils)
       ("xgcc" ,gcc-riscv32-zephyr-elf-12)
       ("texinfo" ,texinfo)))
    (home-page "https://www.sourceware.org/newlib/")
    (synopsis "C library for use on embedded systems")
    (description "Newlib is a C library intended for use on embedded
systems.  It is a conglomeration of several library parts that are easily
usable on embedded products.")
    (license (license:non-copyleft
	      "https://www.sourceware.org/newlib/COPYING.NEWLIB"))))

(define-public riscv32-zephyr-elf-newlib
  (package
    (name "newlib-riscv32")
    (version "4.1.0")
    (source (origin
	      (method git-fetch)
	      (uri (git-reference
		    (url "https://github.com/zephyrproject-rtos/newlib-cygwin")
		    ;(commit "4e150303bcc1e44f4d90f3489a4417433980d5ff")
		    (commit "415fdd4279b85eeec9d54775ce13c5c412451e08")
		    ))
	      (sha256
	       (base32 "0mzz81k4nm9kcryky6l1zxjdl4rzz2ybqa8412d467icygbvkqay"))))
    (build-system gnu-build-system)
    (arguments
     `(#:out-of-source? #t
       #:configure-flags '("--target=riscv32-zephyr-elf"
			   "--enable-headers"
			   "--enable-newlib-io-long-long"
			   "--enable-newlib-io-float"
			   "--enable-newlib-io-c99-formats"
			   "--enable-newlib-retargetable-locking"
			   "--enable-newlib-lite-exit"
			   "--enable-newlib-multithread"
			   "--enable-newlib-register-fini"
			   "--enable-newlib-extra-sections"
			   "--disable-newlib-nano-malloc"
			   "--disable-newlib-nano-formatted-io"
			   "--disable-newlib-wide-orient"
			   "--disable-newlib-fseek-optimization"
			   "--disable-newlib-supplied-syscalls"
			   "--disable-newlib-target-optspace"
			   "--disable-nls")
       #:make-flags '("CFLAGS_FOR_TARGET=\"-O2 -Wno-implicit-function-declaration -Wno-prio-ctor-dtor\"")
       #:phases
       (modify-phases %standard-phases
	 (add-after 'unpack 'fix-references-to-/bin/sh
	   (lambda _
	     (substitute* '("libgloss/libnosys/Makefile.in"
			    "libgloss/Makefile.in")
	       (("/bin/sh") (which "sh")))
	     #t)))))
    (native-inputs
     `(("xbinutils" ,riscv32-zephyr-elf-binutils)
       ("xgcc" ,gcc-riscv32-zephyr-elf-14)
       ("texinfo" ,texinfo)))
    (home-page "https://www.sourceware.org/newlib/")
    (synopsis "C library for use on embedded systems")
    (description "Newlib is a C library intended for use on embedded
systems.  It is a conglomeration of several library parts that are easily
usable on embedded products.")
    (license (license:non-copyleft
	      "https://www.sourceware.org/newlib/COPYING.NEWLIB"))))

(define-public riscv32-zephyr-elf-newlib-new
  (package
    (name "newlib-riscv32")
    (version "4.5.0")
    (source (origin
	      (method git-fetch)
	      (uri (git-reference
		    (url "https://github.com/zephyrproject-rtos/newlib-cygwin")
		    ;(commit "4e150303bcc1e44f4d90f3489a4417433980d5ff")
		    (commit "5e5e51f1dc56a99eb4648c28e00d73b6ea44a8b0")
		    ))
	      (sha256
	       (base32 "1jfj9dwcz1my43h2q8nbph5zn624gqv49aairhszgxc6jqqbn77m"))))
    (build-system gnu-build-system)
    (arguments
     `(#:out-of-source? #t
       #:configure-flags '("--target=riscv32-zephyr-elf"
			   "--enable-headers"
			   "--enable-newlib-io-long-long"
			   "--enable-newlib-io-float"
			   "--enable-newlib-io-c99-formats"
			   "--enable-newlib-retargetable-locking"
			   "--enable-newlib-lite-exit"
			   "--enable-newlib-multithread"
			   "--enable-newlib-register-fini"
			   "--enable-newlib-extra-sections"
			   "--disable-newlib-nano-malloc"
			   "--disable-newlib-nano-formatted-io"
			   "--disable-newlib-wide-orient"
			   "--disable-newlib-fseek-optimization"
			   "--disable-newlib-supplied-syscalls"
			   "--disable-newlib-target-optspace"
			   "--disable-nls")
       #:make-flags '("CFLAGS_FOR_TARGET=\"-O2 -Wno-implicit-function-declaration\"")
       #:phases
       (modify-phases %standard-phases
		(add-after 'install 'remove-info-pages
	     (lambda* (#:key outputs #:allow-other-keys)
	       (let ((out (assoc-ref outputs "out")))
              (let ((info (string-append out "/share/info")))
                (when (file-exists? info)
                  (delete-file-recursively info))))))
	 #;(add-after 'unpack 'fix-references-to-/bin/sh
	   (lambda _
	     (substitute* '("libgloss/libnosys/Makefile.in"
			    "libgloss/Makefile.in")
	       (("/bin/sh") (which "sh")))
	     #t))
		)))
    (native-inputs
     `(("xbinutils" ,riscv32-zephyr-elf-binutils)
       ("xgcc" ,gcc-riscv32-zephyr-elf-14)
       ("texinfo" ,texinfo)))
    (home-page "https://www.sourceware.org/newlib/")
    (synopsis "C library for use on embedded systems")
    (description "Newlib is a C library intended for use on embedded
systems.  It is a conglomeration of several library parts that are easily
usable on embedded products.")
    (license (license:non-copyleft
	      "https://www.sourceware.org/newlib/COPYING.NEWLIB"))))

(define-public riscv32-zephyr-elf-newlib-nano-old
  (package (inherit riscv32-zephyr-elf-newlib-old)
    (name "newlib-nano-riscv32")
    (arguments
     (substitute-keyword-arguments (package-arguments riscv32-zephyr-elf-newlib-old)
       ((#:configure-flags flags)
	''("--target=riscv32-zephyr-elf"
	   "--enable-multilib"
	   "--enable-newlib-reent-small"
	   "--enable-lite-exit"
	   "--enable-newlib-global-atexit"
	   "--enable-newlib-gcc-libstdcxx"
	   "--enable-newlib-install-in-target"
	   "--enable-newlib-io-float"
	   "--enable-newlib-fvwrite-in-streamio"
	   "--enable-newlib-atexit-dynamic-alloc"
	   "--enable-newlib-global-atexit"
	   "--enable-newlib-multithread"
	   "--enable-newlib-retargetable-locking"
	   "--enable-newlib-extra-sections"
	   "--enable-newlib-target-optspace"
	   "--enable-newlib-nano-malloc"
	   "--enable-newlib-nano-formatted-io"
	   "--enable-newlib-io-c99-formats"
	   "--disable-newlib-io-long-long"
	   "--disable-newlib-supplied-syscalls"
	   "--disable-newlib-fseek-optimization"
	   "--disable-newlib-wide-orient"
	   "--disable-newlib-unbuf-stream-opt"
	   "--disable-lto"
	   "--disable-nls"))
       ;((#:make-flags flags) ''("CFLAGS_FOR_TARGET=\"-mthumb-interwork\""))
       ((#:phases phases)
	`(modify-phases ,phases
	   (add-after 'install 'hardlink-newlib
	     (lambda* (#:key outputs #:allow-other-keys)
	       (let ((out (assoc-ref outputs "out")))
		 ;; The nano.specs file says that newlib-nano files should end
		 ;; in "_nano.a" instead of just ".a".  Note that this applies
		 ;; to all the multilib folders too.
		 (for-each
		  (lambda (file)
		    (link file
			  (string-append
			   ;; Strip ".a" off the end
			   (substring file 0 (- (string-length file) 2))
			   ;; Add "_nano.a" onto the end
			   "_nano.a")))
		  (find-files
		   out
		   "^(libc.a|libg.a|librdimon.a|libstdc\\+\\+.a|libsupc\\+\\+.a)$"))

		 ;; newlib.h is usually in this location instead so both
		 ;; newlib and newlib-nano can be in the toolchain at the same
		 ;; time
		 (mkdir (string-append out "/riscv32-zephyr-elf/include/newlib-nano"))
		 (symlink
		  "../newlib.h"
		  (string-append out "/riscv32-zephyr-elf/include/newlib-nano/newlib.h"))
		 #t)))))))
    (synopsis "Newlib variant for small systems with limited memory")))

(define-public riscv32-zephyr-elf-newlib-nano
  (package (inherit riscv32-zephyr-elf-newlib)
    (name "newlib-nano-riscv32")
    (arguments
     (substitute-keyword-arguments (package-arguments riscv32-zephyr-elf-newlib)
       ((#:configure-flags flags)
	''("--target=riscv32-zephyr-elf"
	   "--enable-multilib"
	   "--enable-newlib-reent-small"
	   "--enable-lite-exit"
	   "--enable-newlib-global-atexit"
	   "--enable-newlib-gcc-libstdcxx"
	   "--enable-newlib-install-in-target"
	   "--enable-newlib-io-float"
	   "--enable-newlib-fvwrite-in-streamio"
	   "--enable-newlib-atexit-dynamic-alloc"
	   "--enable-newlib-global-atexit"
	   "--enable-newlib-multithread"
	   "--enable-newlib-retargetable-locking"
	   "--enable-newlib-extra-sections"
	   "--enable-newlib-target-optspace"
	   "--enable-newlib-nano-malloc"
	   "--enable-newlib-nano-formatted-io"
	   "--enable-newlib-io-c99-formats"
	   "--disable-newlib-io-long-long"
	   "--disable-newlib-supplied-syscalls"
	   "--disable-newlib-fseek-optimization"
	   "--disable-newlib-wide-orient"
	   "--disable-newlib-unbuf-stream-opt"
	   "--disable-lto"
	   "--disable-nls"))
       ;((#:make-flags flags) ''("CFLAGS_FOR_TARGET=\"-mthumb-interwork\""))
       ((#:phases phases)
	`(modify-phases ,phases
	   (add-after 'install 'hardlink-newlib
	     (lambda* (#:key outputs #:allow-other-keys)
	       (let ((out (assoc-ref outputs "out")))
		 ;; The nano.specs file says that newlib-nano files should end
		 ;; in "_nano.a" instead of just ".a".  Note that this applies
		 ;; to all the multilib folders too.
		 (for-each
		  (lambda (file)
		    (link file
			  (string-append
			   ;; Strip ".a" off the end
			   (substring file 0 (- (string-length file) 2))
			   ;; Add "_nano.a" onto the end
			   "_nano.a")))
		  (find-files
		   out
		   "^(libc.a|libg.a|librdimon.a|libstdc\\+\\+.a|libsupc\\+\\+.a)$"))

		 ;; newlib.h is usually in this location instead so both
		 ;; newlib and newlib-nano can be in the toolchain at the same
		 ;; time
		 (mkdir (string-append out "/riscv32-zephyr-elf/include/newlib-nano"))
		 (symlink
		  "../newlib.h"
		  (string-append out "/riscv32-zephyr-elf/include/newlib-nano/newlib.h"))
		 #t)))))))
    (synopsis "Newlib variant for small systems with limited memory")))

(define-public riscv32-zephyr-elf-newlib-nano-new
  (package (inherit riscv32-zephyr-elf-newlib-new)
    (name "newlib-nano-riscv32")
    (arguments
     (substitute-keyword-arguments (package-arguments riscv32-zephyr-elf-newlib-new)
       ((#:configure-flags flags)
	''("--target=riscv32-zephyr-elf"
	   "--enable-multilib"
	   "--enable-newlib-reent-small"
	   "--enable-lite-exit"
	   "--enable-newlib-global-atexit"
	   "--enable-newlib-gcc-libstdcxx"
	   "--enable-newlib-install-in-target"
	   "--enable-newlib-io-float"
	   "--enable-newlib-fvwrite-in-streamio"
	   "--enable-newlib-atexit-dynamic-alloc"
	   "--enable-newlib-global-atexit"
	   "--enable-newlib-multithread"
	   "--enable-newlib-retargetable-locking"
	   "--enable-newlib-extra-sections"
	   "--enable-newlib-target-optspace"
	   "--enable-newlib-nano-malloc"
	   "--enable-newlib-nano-formatted-io"
	   "--enable-newlib-io-c99-formats"
	   "--disable-newlib-io-long-long"
	   "--disable-newlib-supplied-syscalls"
	   "--disable-newlib-fseek-optimization"
	   "--disable-newlib-wide-orient"
	   "--disable-newlib-unbuf-stream-opt"
	   "--disable-lto"
	   "--disable-nls"))
       ;((#:make-flags flags) ''("CFLAGS_FOR_TARGET=\"-mthumb-interwork\""))
       ((#:phases phases)
	`(modify-phases ,phases
	   (add-after 'install 'hardlink-newlib
	     (lambda* (#:key outputs #:allow-other-keys)
	       (let ((out (assoc-ref outputs "out")))
		 ;; The nano.specs file says that newlib-nano files should end
		 ;; in "_nano.a" instead of just ".a".  Note that this applies
		 ;; to all the multilib folders too.
		 (for-each
		  (lambda (file)
		    (link file
			  (string-append
			   ;; Strip ".a" off the end
			   (substring file 0 (- (string-length file) 2))
			   ;; Add "_nano.a" onto the end
			   "_nano.a")))
		  (find-files
		   out
		   "^(libc.a|libg.a|librdimon.a|libstdc\\+\\+.a|libsupc\\+\\+.a)$"))

		 ;; newlib.h is usually in this location instead so both
		 ;; newlib and newlib-nano can be in the toolchain at the same
		 ;; time
		 (mkdir (string-append out "/riscv32-zephyr-elf/include/newlib-nano"))
		 (symlink
		  "../newlib.h"
		  (string-append out "/riscv32-zephyr-elf/include/newlib-nano/newlib.h"))
		 #t)))))))
    (synopsis "Newlib variant for small systems with limited memory")))

(define (make-libstdc++-riscv32-zephyr-elf xgcc newlib)
  (let ((libstdc++ (make-libstdc++ xgcc)))
    (package (inherit libstdc++)
      (name "libstdc++-riscv32-zephyr-elf")
      (arguments
       (substitute-keyword-arguments (package-arguments libstdc++)
	 ((#:configure-flags flags)
	  #~(append `("--host=riscv32-none-elf"
		      "--target=riscv32-zephyr-elf"
		      "--disable-libstdcxx-pch"
		      "--enable-multilib"
		      "--with-multilib-list=rmprofile"
		      "--disable-shared"
		      "--disable-tls"
		      "--disable-plugin"
		      "--with-newlib"
		      "--with-gnu-ld"
		      "--with-gnu-as"
		      ,(string-append "--with-gxx-include-dir="
				      #$output
				      "/riscv32-zephyr-elf/include/c++"))))))
      (native-inputs
       `(("newlib" ,newlib)
	 ("xgcc" ,xgcc)
	 ,@(package-native-inputs libstdc++))))))

(define (riscv32-zephyr-elf-toolchain xgcc newlib)
  "Produce a cross-compiler zephyr toolchain package with the compiler XGCC and the C
library variant NEWLIB."
  (let ((newlib-with-xgcc (package (inherit newlib)
			    (native-inputs
			     (alist-replace "xgcc" (list xgcc)
					    (package-native-inputs newlib))))))
    (package
      (name (string-append "riscv32-zephyr-elf"
			   (if (string=? (package-name newlib-with-xgcc)
					 "newlib-nano-riscv32")
			       "-nano" "")
			   "-toolchain"))
      (version (package-version xgcc))
      (source #f)
      (build-system trivial-build-system)
      (arguments
       '(#:modules ((guix build union)
		    (guix build utils))
	 #:builder
	 (begin
	   (use-modules (ice-9 match)
			(guix build union)
			(guix build utils))
	   (let ((out (assoc-ref %outputs "out")))
	     (mkdir-p out)
	     (match %build-inputs
	       (((names . directories) ...)
		(union-build (string-append out "/riscv32-zephyr-elf")
			     directories)
		#t))))))
      (propagated-inputs
       `(("binutils" ,riscv32-zephyr-elf-binutils)
	 ("gcc" ,xgcc)
	 ("newlib" ,newlib-with-xgcc)))
      (synopsis "Complete GCC tool chain for RISC-V zephyrRTOS development")
      (description "This package provides a complete GCC tool chain for RISC-V
bare metal development with zephyr rtos.  This includes the GCC riscv32-zephyr-elf cross compiler
and newlib (or newlib-nano) as the C library.  The supported programming
language is C.")
      (home-page (package-home-page xgcc))
      (license (package-license xgcc)))))

(define-public riscv32-zephyr-elf-toolchain-12
  (riscv32-zephyr-elf-toolchain
   gcc-riscv32-zephyr-elf-12
   riscv32-zephyr-elf-newlib-old))

(define-public riscv32-zephyr-elf-nano-toolchain-12
  (riscv32-zephyr-elf-toolchain
   gcc-riscv32-zephyr-elf-12
   riscv32-zephyr-elf-newlib-nano-old))

(define-public riscv32-zephyr-elf-toolchain-14
  (riscv32-zephyr-elf-toolchain
   gcc-riscv32-zephyr-elf-14
   riscv32-zephyr-elf-newlib-new))

(define-public riscv32-zephyr-elf-nano-toolchain-14
  (riscv32-zephyr-elf-toolchain
   gcc-riscv32-zephyr-elf-14
   riscv32-zephyr-elf-newlib-nano-new))

(define-public gdb-riscv32-zephyr-elf-old
  (package
    (inherit gdb)
    (name "gdb-riscv32-zephyr-elf")
    (version "12.1")
    (source
     (origin (method git-fetch)
	     (uri (git-reference
		   (url "https://github.com/zephyrproject-rtos/binutils-gdb")
		   (commit "db8bd068edeaac983273727d9322fc1867702d15")))
	     (file-name (git-file-name name version))
	     (sha256 (base32 "082lh9p3jcqnmk31yr7zmd1yrpp4z49xljg06rrfipk8x0z2sv23"))))
    (native-inputs (modify-inputs
       (package-native-inputs gdb)
       (append bison flex)))
    (arguments
     (substitute-keyword-arguments (package-arguments gdb)
       ((#:configure-flags flags)
	`(cons* "--target=riscv32-zephyr-elf"
		"--enable-multilib"
		"--enable-interwork"
		"--enable-languages=c"
		"--disable-nls"
		(delete "--enable-languages=" #$flags)))))))

(define-public gdb-riscv32-zephyr-elf
  (package
    (inherit gdb)
    (name "gdb-riscv32-zephyr-elf")
    (version "16.2")
    (source
     (origin (method git-fetch)
	     (uri (git-reference
		   (url "https://github.com/zephyrproject-rtos/binutils-gdb")
		   (commit "0952b9d52545c7f3ab26d1b9bc348149a2a897e4")))
	     (file-name (git-file-name name version))
	     (sha256 (base32 "1jdc5id9h2a81fbfgi5hibzvjpx25rn8slr3c4fn2q4xrspj7sd0"))))
    (native-inputs (modify-inputs
       (package-native-inputs gdb)
		 (append bison flex perl)))
    (arguments
     (substitute-keyword-arguments (package-arguments gdb)
       ((#:configure-flags flags)
	#~(cons* "--target=riscv32-zephyr-elf"
		 "--enable-multilib"
		 "--enable-interwork"
		 "--enable-languages=c"
		 "--disable-nls"
		 (delete "--enable-languages=" #$flags)))))))

(define-public riscv32-zephyr-elf-sdk-old
  (package
    (name "riscv32-zephyr-elf-sdk")
    (version "0.16.4")
    (home-page "https://zephyrproject.org")
    (source (origin (method git-fetch)
		    (uri (git-reference
			  (url "https://github.com/zephyrproject-rtos/sdk-ng")
			  (commit "v0.16.4")))
		    (file-name (git-file-name name version))
		    (sha256 (base32 "0n11a12k4gyhgkmwggdxlnnsbc9lp6f012pzz6pdgk8fz1bsms37"))))
    (build-system trivial-build-system)
    (arguments
     `(#:modules ((guix build union)
		  (guix build utils))
       #:builder
       (begin
	 (use-modules (guix build union)
		      (ice-9 match)
		      (guix build utils))
	 (let* ((out (assoc-ref %outputs "out"))
		(cmake-scripts (string-append (assoc-ref %build-inputs "source")
					      "/cmake"))
		(sdk-out (string-append out "/zephyr-sdk-0.16.4")))
	   (mkdir-p out)

	   (match (assoc-remove! %build-inputs "source")
	     (((names . directories) ...)
	      (union-build sdk-out directories)))

	   (copy-recursively cmake-scripts
			     (string-append sdk-out "/cmake"))

	   (with-directory-excursion sdk-out
	     (call-with-output-file "sdk_version"
	       (lambda (p)
		 (format p "0.16.4")))
	     #t)))))
    (propagated-inputs
     (list
      riscv32-zephyr-elf-nano-toolchain-12
      dtc))
    (native-search-paths
     (list (search-path-specification
	    (variable "ZEPHYR_SDK_INSTALL_DIR")
	    (files '("zephyr-sdk-0.16.4")))))
    (synopsis "SDK for zephyrRTOS")
    (description "zephyr-sdk contains bundles a complete gcc toolchain as well
as host tools like dtc, openocd, and qemu.")
    (license license:apsl2)))

(define-public riscv32-zephyr-elf-sdk
  (package
    (name "riscv32-zephyr-elf-sdk")
    (version "1.0.1")
    (home-page "https://zephyrproject.org")
    (source (origin (method git-fetch)
		    (uri (git-reference
			  (url "https://github.com/zephyrproject-rtos/sdk-ng")
			  (commit "v1.0.1")))
		    (file-name (git-file-name name version))
		    (sha256 (base32 "1h6lmf0s59issjg2s49mpjwivy56jv95m8f098fbhbz85xcsqq35"))))
    (build-system trivial-build-system)
    (arguments
     `(#:modules ((guix build union)
		  (guix build utils))
       #:builder
       (begin
	 (use-modules (guix build union)
		      (ice-9 match)
		      (guix build utils))
	 (let* ((out (assoc-ref %outputs "out"))
		(cmake-scripts (string-append (assoc-ref %build-inputs "source")
					      "/cmake"))
		(sdk-out (string-append out "/zephyr-sdk-1.0.1")))
	   (mkdir-p out)

	   (match (assoc-remove! %build-inputs "source")
	     (((names . directories) ...)
	      (union-build sdk-out directories)))

	   (copy-recursively cmake-scripts
			     (string-append sdk-out "/cmake"))

	   (with-directory-excursion sdk-out
	     (call-with-output-file "sdk_version"
	       (lambda (p)
		 (format p "1.0.1")))
	     #t)))))
    (propagated-inputs
     (list
      riscv32-zephyr-elf-nano-toolchain-14
      dtc))
    (native-search-paths
     (list (search-path-specification
	    (variable "ZEPHYR_SDK_INSTALL_DIR")
	    (files '("zephyr-sdk-1.0.1")))))
    (synopsis "SDK for zephyrRTOS")
    (description "zephyr-sdk contains bundles a complete gcc toolchain as well
as host tools like dtc, openocd, and qemu.")
    (license license:apsl2)))
