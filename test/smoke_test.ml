let test_version () =
  Alcotest.(check string) "version is set" "0.1.0-dev" Tiger_core.version

let () =
  Alcotest.run "smoke"
    [
      ( "core",
        [
          Alcotest.test_case "version string" `Quick test_version;
        ] );
    ]
