type t =
  { hi : int64
  ; lo : int64
  }

let zero = { hi = 0L; lo = 0L }
let one = { hi = 0L; lo = 1L }
let max_value = { hi = -1L; lo = -1L }

let of_int value =
  if value < 0 then invalid_arg "U128.of_int: negative value";
  { hi = 0L; lo = Int64.of_int value }
;;

let of_int64 lo = { hi = 0L; lo }
let of_int64_pair ~hi ~lo = { hi; lo }
let to_int64_pair value = value.hi, value.lo
let to_int64_opt value = if Int64.equal value.hi 0L then Some value.lo else None

let to_int_opt value =
  if Int64.equal value.hi 0L
     && Int64.compare value.lo 0L >= 0
     && Int64.compare value.lo (Int64.of_int max_int) <= 0
  then Some (Int64.to_int value.lo)
  else None
;;

let compare a b =
  let high = Int64.unsigned_compare a.hi b.hi in
  if high <> 0 then high else Int64.unsigned_compare a.lo b.lo
;;

let equal a b = compare a b = 0
let is_zero value = Int64.equal value.hi 0L && Int64.equal value.lo 0L
let min a b = if compare a b <= 0 then a else b
let max a b = if compare a b >= 0 then a else b

let add a b =
  let lo = Int64.add a.lo b.lo in
  let carry = if Int64.unsigned_compare lo a.lo < 0 then 1L else 0L in
  let hi_without_carry = Int64.add a.hi b.hi in
  let hi = Int64.add hi_without_carry carry in
  let overflow =
    Int64.unsigned_compare hi_without_carry a.hi < 0
    || (Int64.equal carry 1L && Int64.unsigned_compare hi hi_without_carry < 0)
  in
  if overflow then Error `Overflow else Ok { hi; lo }
;;

let sub a b =
  if compare a b < 0
  then Error `Underflow
  else (
    let borrow = if Int64.unsigned_compare a.lo b.lo < 0 then 1L else 0L in
    Ok { hi = Int64.sub (Int64.sub a.hi b.hi) borrow; lo = Int64.sub a.lo b.lo })
;;

let shift_left value bits =
  if bits <= 0
  then value
  else if bits >= 128
  then zero
  else if bits >= 64
  then { hi = Int64.shift_left value.lo (bits - 64); lo = 0L }
  else
    { hi =
        Int64.logor
          (Int64.shift_left value.hi bits)
          (Int64.shift_right_logical value.lo (64 - bits))
    ; lo = Int64.shift_left value.lo bits
    }
;;

let shift_right value bits =
  if bits <= 0
  then value
  else if bits >= 128
  then zero
  else if bits >= 64
  then { hi = 0L; lo = Int64.shift_right_logical value.hi (bits - 64) }
  else
    { hi = Int64.shift_right_logical value.hi bits
    ; lo =
        Int64.logor
          (Int64.shift_right_logical value.lo bits)
          (Int64.shift_left value.hi (64 - bits))
    }
;;

let logor a b = { hi = Int64.logor a.hi b.hi; lo = Int64.logor a.lo b.lo }
let logand a b = { hi = Int64.logand a.hi b.hi; lo = Int64.logand a.lo b.lo }

let bit value index =
  if index < 64
  then Int64.equal (Int64.logand (Int64.shift_right_logical value.lo index) 1L) 1L
  else Int64.equal (Int64.logand (Int64.shift_right_logical value.hi (index - 64)) 1L) 1L
;;

let bit_length value =
  let rec loop index =
    if index < 0 then 0 else if bit value index then index + 1 else loop (index - 1)
  in
  loop 127
;;

(* Splits a 64-bit word into 32-bit halves so partial products fit in [int64]. *)
let low32 word = Int64.logand word 0xffff_ffffL
let high32 word = Int64.shift_right_logical word 32

(* Full 64x64 -> 128 product of two unsigned words. *)
let mul_words a b =
  let a0 = low32 a
  and a1 = high32 a in
  let b0 = low32 b
  and b1 = high32 b in
  let p00 = Int64.mul a0 b0 in
  let p01 = Int64.mul a0 b1 in
  let p10 = Int64.mul a1 b0 in
  let p11 = Int64.mul a1 b1 in
  let middle = Int64.add (high32 p00) (low32 p01) in
  let middle = Int64.add middle (low32 p10) in
  let lo = Int64.logor (Int64.shift_left (low32 middle) 32) (low32 p00) in
  let hi =
    Int64.add (Int64.add (Int64.add p11 (high32 p01)) (high32 p10)) (high32 middle)
  in
  { hi; lo }
;;

let mul a b =
  if (not (Int64.equal a.hi 0L)) && not (Int64.equal b.hi 0L)
  then Error `Overflow
  else (
    let low = mul_words a.lo b.lo in
    let cross_a = mul_words a.hi b.lo in
    let cross_b = mul_words a.lo b.hi in
    if not (Int64.equal cross_a.hi 0L && Int64.equal cross_b.hi 0L)
    then Error `Overflow
    else (
      match add low { hi = cross_a.lo; lo = 0L } with
      | Error `Overflow -> Error `Overflow
      | Ok partial -> add partial { hi = cross_b.lo; lo = 0L }))
;;

let div_rem dividend divisor =
  if is_zero divisor
  then Error `Division_by_zero
  else if compare dividend divisor < 0
  then Ok (zero, dividend)
  else (
    let quotient = ref zero in
    let remainder = ref zero in
    for index = bit_length dividend - 1 downto 0 do
      remainder := shift_left !remainder 1;
      if bit dividend index then remainder := logor !remainder one;
      if compare !remainder divisor >= 0
      then (
        (match sub !remainder divisor with
         | Ok value -> remainder := value
         | Error `Underflow -> assert false);
        quotient := logor !quotient (shift_left one index))
    done;
    Ok (!quotient, !remainder))
;;

let ten = of_int 10

let to_string value =
  if Int64.equal value.hi 0L
  then Printf.sprintf "%Lu" value.lo
  else (
    let digits = Buffer.create 40 in
    let rec loop value =
      if not (is_zero value)
      then (
        match div_rem value ten with
        | Ok (quotient, remainder) ->
          Buffer.add_char digits (Char.chr (Char.code '0' + Int64.to_int remainder.lo));
          loop quotient
        | Error `Division_by_zero -> assert false)
    in
    loop value;
    let length = Buffer.length digits in
    String.init length (fun index -> Buffer.nth digits (length - 1 - index)))
;;

let to_hex_string value = Printf.sprintf "0x%016Lx%016Lx" value.hi value.lo

let of_string_opt text =
  let length = String.length text in
  if length = 0
  then None
  else (
    let rec loop index accumulator =
      if index = length
      then Some accumulator
      else (
        match text.[index] with
        | '0' .. '9' as digit ->
          let digit = of_int (Char.code digit - Char.code '0') in
          (match mul accumulator ten with
           | Error `Overflow -> None
           | Ok scaled ->
             (match add scaled digit with
              | Error `Overflow -> None
              | Ok next -> loop (index + 1) next))
        | _ -> None)
    in
    loop 0 zero)
;;

let of_string text =
  match of_string_opt text with
  | Some value -> value
  | None -> invalid_arg (Printf.sprintf "U128.of_string: %S" text)
;;

let hash value = Hashtbl.hash (value.hi, value.lo)
