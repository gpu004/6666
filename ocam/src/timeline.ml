type 'a t =
  { mutable entries : (int64 * 'a) array
  ; mutable length : int
  }

let create () = { entries = [||]; length = 0 }
let length timeline = timeline.length

let last_timestamp timeline =
  if timeline.length = 0 then None else Some (fst timeline.entries.(timeline.length - 1))
;;

let append timeline timestamp value =
  (match last_timestamp timeline with
   | Some last when Int64.compare timestamp last <= 0 ->
     invalid_arg "Timeline.append: timestamps must strictly increase"
   | _ -> ());
  let capacity = Array.length timeline.entries in
  if timeline.length = capacity
  then (
    let grown = Array.make (max 8 (2 * capacity)) (timestamp, value) in
    Array.blit timeline.entries 0 grown 0 timeline.length;
    timeline.entries <- grown);
  timeline.entries.(timeline.length) <- timestamp, value;
  timeline.length <- timeline.length + 1
;;

let truncate timeline length =
  if length < timeline.length
  then
    if length = 0
    then (
      timeline.entries <- [||];
      timeline.length <- 0)
    else (
      Array.fill timeline.entries length (timeline.length - length) timeline.entries.(0);
      timeline.length <- length)
;;

(* Index of the first entry whose timestamp is [>= timestamp], or [length]. *)
let lower_bound timeline timestamp =
  let rec search low high =
    if low >= high
    then low
    else (
      let middle = (low + high) / 2 in
      if Int64.compare (fst timeline.entries.(middle)) timestamp < 0
      then search (middle + 1) high
      else search low middle)
  in
  search 0 timeline.length
;;

let to_seq_in_range timeline ~minimum ~maximum ~reversed =
  let first = if Int64.equal minimum 0L then 0 else lower_bound timeline minimum in
  let stop =
    if Int64.equal maximum 0L || Int64.equal maximum Int64.max_int
    then timeline.length
    else lower_bound timeline (Int64.succ maximum)
  in
  let entries = timeline.entries in
  if reversed
  then (
    let rec go index () =
      if index < first then Seq.Nil else Seq.Cons (entries.(index), go (index - 1))
    in
    go (stop - 1))
  else (
    let rec go index () =
      if index >= stop then Seq.Nil else Seq.Cons (entries.(index), go (index + 1))
    in
    go first)
;;
