open Tigerbeetle_state_machine

let require condition message = if not condition then failwith message

let range timeline ?(reversed = false) minimum maximum =
  Timeline.to_seq_in_range timeline ~minimum ~maximum ~reversed
  |> List.of_seq
  |> List.map snd
;;

let () =
  let timeline = Timeline.create () in
  require (range timeline 0L 0L = []) "empty timeline";
  List.iter
    (fun n -> Timeline.append timeline (Int64.of_int (n * 10)) n)
    [ 1; 2; 3; 4; 5 ];
  require (Timeline.length timeline = 5) "length";
  require (range timeline 0L 0L = [ 1; 2; 3; 4; 5 ]) "unbounded";
  require (range timeline 20L 40L = [ 2; 3; 4 ]) "inclusive bounds";
  require (range timeline 21L 39L = [ 3 ]) "bounds between entries";
  require (range timeline ~reversed:true 20L 40L = [ 4; 3; 2 ]) "reversed";
  require (range timeline 60L 0L = []) "minimum past the end";
  require (range timeline 0L 5L = []) "maximum before the start";
  require (range timeline 0L Int64.max_int = [ 1; 2; 3; 4; 5 ]) "maximum at int64 max";
  require
    (match Timeline.append timeline 50L 6 with
     | () -> false
     | exception Invalid_argument _ -> true)
    "out-of-order append is rejected";
  Timeline.truncate timeline 2;
  require (range timeline 0L 0L = [ 1; 2 ]) "truncate keeps the prefix";
  Timeline.append timeline 25L 7;
  require (range timeline 0L 0L = [ 1; 2; 7 ]) "append after truncate";
  Timeline.truncate timeline 0;
  require (Timeline.length timeline = 0 && range timeline 0L 0L = []) "truncate to empty";
  Timeline.append timeline 1L 8;
  require (range timeline 1L 1L = [ 8 ]) "append after emptying";
  print_endline "timeline tests passed"
;;
