let () =
  Eio_main.run @@ fun _env ->
  Printf.printf "TigerOCaml server v%s\n" Tiger_core.version;
  Printf.printf "Server starting...\n";
  ()
