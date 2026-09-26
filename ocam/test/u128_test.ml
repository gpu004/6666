open Tigerbeetle_state_machine

let require condition message = if not condition then failwith message
let max_decimal = "340282366920938463463374607431768211455"
let two_pow_64 = U128.of_int64_pair ~hi:1L ~lo:0L

let test_constants () =
  require (U128.to_string U128.max_value = max_decimal) "max_value decimal";
  require (U128.to_string U128.zero = "0") "zero decimal";
  require (U128.to_string two_pow_64 = "18446744073709551616") "2^64 decimal";
  require
    (U128.to_hex_string U128.max_value = "0xffffffffffffffffffffffffffffffff")
    "max_value hex";
  require (U128.equal (U128.of_string max_decimal) U128.max_value) "parse max";
  require (U128.of_string_opt "340282366920938463463374607431768211456" = None) "overflow";
  require (U128.of_string_opt "" = None) "empty";
  require (U128.of_string_opt "12a" = None) "malformed";
  require (U128.to_int_opt (U128.of_int 42) = Some 42) "to_int_opt small";
  require (U128.to_int_opt two_pow_64 = None) "to_int_opt large";
  require (U128.to_int64_opt (U128.of_int64 (-1L)) = Some (-1L)) "to_int64_opt unsigned"
;;

let test_arithmetic_edges () =
  require (U128.add U128.max_value U128.one = Error `Overflow) "add overflow";
  require (U128.sub U128.zero U128.one = Error `Underflow) "sub underflow";
  require
    (U128.add (U128.of_int64 (-1L)) U128.one = Ok two_pow_64)
    "carry into the high word";
  require (U128.sub two_pow_64 U128.one = Ok (U128.of_int64 (-1L))) "borrow from high";
  require (U128.mul two_pow_64 two_pow_64 = Error `Overflow) "mul overflow both high";
  require
    (U128.mul (U128.of_int64 (-1L)) (U128.of_int64 (-1L))
     = Ok (U128.of_int64_pair ~hi:(-2L) ~lo:1L))
    "(2^64-1)^2";
  require (U128.mul U128.max_value U128.one = Ok U128.max_value) "mul identity";
  require (U128.mul U128.max_value (U128.of_int 2) = Error `Overflow) "mul max by two";
  require (U128.div_rem U128.one U128.zero = Error `Division_by_zero) "div by zero";
  require
    (U128.div_rem U128.max_value two_pow_64 = Ok (U128.of_int64 (-1L), U128.of_int64 (-1L))
    )
    "max / 2^64";
  require (U128.shift_left U128.one 64 = two_pow_64) "shift_left 64";
  require (U128.shift_right two_pow_64 64 = U128.one) "shift_right 64";
  require (U128.shift_left U128.one 128 = U128.zero) "shift out";
  require (U128.compare U128.max_value U128.zero > 0) "unsigned compare";
  require (U128.max U128.max_value U128.zero = U128.max_value) "max"
;;

let small = QCheck.Gen.(map (fun n -> abs n) (int_bound (1 lsl 30)))
let u128_small = QCheck.make ~print:string_of_int small

let property name generator property =
  QCheck.Test.make ~count:500 ~name generator property
;;

let properties =
  [ property "add matches int" (QCheck.pair u128_small u128_small) (fun (a, b) ->
      U128.add (U128.of_int a) (U128.of_int b) = Ok (U128.of_int (a + b)))
  ; property "mul matches int" (QCheck.pair u128_small u128_small) (fun (a, b) ->
      U128.mul (U128.of_int a) (U128.of_int b) = Ok (U128.of_int (a * b)))
  ; property "div_rem matches int" (QCheck.pair u128_small u128_small) (fun (a, b) ->
      b = 0
      || U128.div_rem (U128.of_int a) (U128.of_int b)
         = Ok (U128.of_int (a / b), U128.of_int (a mod b)))
  ; property "decimal round trip" (QCheck.pair u128_small u128_small) (fun (hi, lo) ->
      let value = U128.of_int64_pair ~hi:(Int64.of_int hi) ~lo:(Int64.of_int lo) in
      U128.of_string_opt (U128.to_string value) = Some value)
  ; property "div_rem reconstructs" (QCheck.pair u128_small u128_small) (fun (hi, b) ->
      b = 0
      ||
      let a = U128.of_int64_pair ~hi:(Int64.of_int hi) ~lo:(Int64.of_int (hi * 7919)) in
      let divisor = U128.of_int b in
      match U128.div_rem a divisor with
      | Error `Division_by_zero -> false
      | Ok (quotient, remainder) ->
        U128.compare remainder divisor < 0
        &&
          (match U128.mul quotient divisor with
          | Error `Overflow -> false
          | Ok product -> U128.add product remainder = Ok a))
  ]
;;

let () =
  test_constants ();
  test_arithmetic_edges ();
  let failures =
    QCheck_runner.run_tests
      ~verbose:true
      ~rand:(Random.State.make [| 1; 2; 8 |])
      properties
  in
  if failures <> 0 then exit 1;
  print_endline "u128 tests passed"
;;
