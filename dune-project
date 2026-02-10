(lang dune 3.10)

(name tigerocaml)

(generate_opam_files true)

(package
 (name tigerocaml)
 (synopsis "TigerBeetle-inspired financial database in OCaml")
 (depends
  (ocaml
   (>= 5.1.1))
  eio
  eio_main
  cstruct
  digestif
  cmdliner
  (qcheck :with-test)
  (qcheck-alcotest :with-test)
  (alcotest :with-test)))
