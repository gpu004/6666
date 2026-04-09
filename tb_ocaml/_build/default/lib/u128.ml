type t = {
  hi : int64;
  lo : int64;
}

let zero = { hi = 0L; lo = 0L }
let one = { hi = 0L; lo = 1L }
let max_value = { hi = Int64.minus_one; lo = Int64.minus_one }

let min_int64 = Int64.min_int

let compare_u64 a b =
  Int64.compare (Int64.logxor a min_int64) (Int64.logxor b min_int64)

let equal a b = a.hi = b.hi && a.lo = b.lo

let compare a b =
  let c = compare_u64 a.hi b.hi in
  if c <> 0 then c else compare_u64 a.lo b.lo

let is_zero t = equal t zero
let of_int n = { hi = 0L; lo = Int64.of_int n }
let of_int64 n = { hi = 0L; lo = n }

let add a b =
  let lo = Int64.add a.lo b.lo in
  let carry = if compare_u64 lo a.lo < 0 then 1L else 0L in
  let hi = Int64.add (Int64.add a.hi b.hi) carry in
  { hi; lo }

let sub a b =
  let lo = Int64.sub a.lo b.lo in
  let borrow = if compare_u64 a.lo b.lo < 0 then 1L else 0L in
  let hi = Int64.sub (Int64.sub a.hi b.hi) borrow in
  { hi; lo }

let of_u32_parts a3 a2 a1 a0 =
  let open Int64 in
  let lo =
    logor (shift_left (logand (of_int32 a1) 0xFFFF_FFFFL) 32)
      (logand (of_int32 a0) 0xFFFF_FFFFL)
  in
  let hi =
    logor (shift_left (logand (of_int32 a3) 0xFFFF_FFFFL) 32)
      (logand (of_int32 a2) 0xFFFF_FFFFL)
  in
  { hi; lo }

let to_u32_parts t =
  let open Int64 in
  let mask = 0xFFFF_FFFFL in
  let a0 = to_int32 (logand t.lo mask) in
  let a1 = to_int32 (logand (shift_right_logical t.lo 32) mask) in
  let a2 = to_int32 (logand t.hi mask) in
  let a3 = to_int32 (logand (shift_right_logical t.hi 32) mask) in
  (a3, a2, a1, a0)

let mul_u32 t n =
  let n64 = Int64.logand (Int64.of_int32 n) 0xFFFF_FFFFL in
  let a3, a2, a1, a0 = to_u32_parts t in
  let limbs = [| a0; a1; a2; a3 |] in
  let out = Array.make 4 Int32.zero in
  let carry = ref 0L in
  for i = 0 to 3 do
    let v =
      Int64.add
        (Int64.mul (Int64.logand (Int64.of_int32 limbs.(i)) 0xFFFF_FFFFL) n64)
        !carry
    in
    out.(i) <- Int64.to_int32 (Int64.logand v 0xFFFF_FFFFL);
    carry := Int64.shift_right_logical v 32
  done;
  of_u32_parts out.(3) out.(2) out.(1) out.(0)

let add_small t n = add t (of_int n)

let of_decimal_string s =
  let len = String.length s in
  if len = 0 then invalid_arg "U128.of_decimal_string";
  let acc = ref zero in
  for i = 0 to len - 1 do
    match s.[i] with
    | '0' .. '9' as ch ->
        acc := mul_u32 !acc 10l;
        acc := add_small !acc (Char.code ch - Char.code '0')
    | '_' -> ()
    | _ -> invalid_arg "U128.of_decimal_string"
  done;
  !acc

let divmod_10 t =
  let a3, a2, a1, a0 = to_u32_parts t in
  let limbs = [| a3; a2; a1; a0 |] in
  let out = Array.make 4 Int32.zero in
  let rem = ref 0L in
  for i = 0 to 3 do
    let cur =
      Int64.add
        (Int64.shift_left !rem 32)
        (Int64.logand (Int64.of_int32 limbs.(i)) 0xFFFF_FFFFL)
    in
    out.(i) <- Int64.to_int32 (Int64.div cur 10L);
    rem := Int64.rem cur 10L
  done;
  (of_u32_parts out.(0) out.(1) out.(2) out.(3), Int64.to_int !rem)

let to_string t =
  if is_zero t then "0"
  else
    let cur = ref t in
    let digits = Buffer.create 40 in
    while not (is_zero !cur) do
      let q, r = divmod_10 !cur in
      Buffer.add_char digits (Char.chr (Char.code '0' + r));
      cur := q
    done;
    let s = Buffer.contents digits in
    String.init (String.length s) (fun i -> s.[String.length s - 1 - i])

let of_le_bytes bytes off =
  let open Int64 in
  let rec load64 o =
    let v = ref 0L in
    for i = 0 to 7 do
      let b = of_int (Char.code (Bytes.get bytes (o + i))) in
      v := logor !v (shift_left b (8 * i))
    done;
    !v
  in
  let lo = load64 off in
  let hi = load64 (off + 8) in
  { hi; lo }

let to_le_bytes t =
  let out = Bytes.make 16 '\x00' in
  let write64 off v =
    for i = 0 to 7 do
      let b = Int64.(to_int (logand (shift_right_logical v (8 * i)) 0xFFL)) in
      Bytes.set out (off + i) (Char.chr b)
    done
  in
  write64 0 t.lo;
  write64 8 t.hi;
  out

let pp fmt t = Format.pp_print_string fmt (to_string t)
