open Hdf5_caml
open Type

module Record = struct
  [%%h5struct
    sf64 "sf64" Float64     Seek;
    si   "si"   Int         Seek;
    si64 "si64" Int64       Seek;
    ss   "ss"   (String 14) Seek;
    f64  "f64"  Float64;
    i    "i"    Int;
    i64  "i64"  Int64;
    s    "s"    (String 16)]
end

module Subset = struct
  [%%h5struct
    f64 "f64" Float64;
  ]
end

module Simple = struct
  [%%h5struct f "F" Float64 Seek]
end

let () =
  let len = 1000 in
  let a = Record.Array.init len (fun i e ->
    let si = i * 2 in
    Record.set e
      ~sf64:(float_of_int si) ~si ~si64:(Int64.of_int si) ~ss:(Printf.sprintf "%14d" si)
      ~f64:(float_of_int i) ~i ~i64:(Int64.of_int i) ~s:(Printf.sprintf "%14d" i)) in
  let assert_val e i =
    let si = i * 2 in
    assert(Record.sf64 e = float_of_int si);
    assert(Record.si   e = si);
    assert(Record.si64 e = Int64.of_int si);
    assert(Record.ss   e = Printf.sprintf "%14d" si);
    assert(Record.f64  e = float_of_int i);
    assert(Record.i    e = i);
    assert(Record.i64  e = Int64.of_int i);
    assert(Record.s    e = Printf.sprintf "%14d" i);
    assert(Record.pos  e = i);
    Array.iteri (fun j (Record.Accessors.T acc) ->
      let i = if j < 4 then i * 2 else i in
      match acc.field.type_ with
      | Int      -> assert (acc.get e = i)
      | Int64    -> assert (acc.get e = Int64.of_int i)
      | Float64  -> assert (acc.get e = float_of_int i)
      | String _ -> assert (acc.get e = Printf.sprintf "%14d" i)
      | _        -> ()) Record.Accessors.all
  in
  for i = 0 to len - 1 do
    let e = Record.Array.get a i in
    assert_val e i
  done;
  let e = Record.Array.get a 0 in
  for i = 0 to len - 2 do
    assert_val e i;
    Record.next e
  done;
  assert_val e (len - 1);
  for i = len - 1 downto 1 do
    assert_val e i;
    Record.prev e
  done;
  assert_val e 0;
  for i = 0 to len - 1 do
    Record.move e i;
    assert_val e i
  done;
  let a =
    Record.Array.init len (fun i e ->
      Array.iteri (fun j (Record.Accessors.T acc) ->
        let i = if j < 4 then i * 2 else i in
        match acc.field.type_ with
        | Int -> acc.set e i
        | Int64 -> acc.set e (Int64.of_int i)
        | Float64 -> acc.set e (float_of_int i)
        | String _ -> acc.set e (Printf.sprintf "%14d" i)
        | _ -> assert false) Record.Accessors.all) in
  let e = Record.Array.get a 0 in
  for i = 0 to len - 1 do
    Record.move e i;
    assert_val e i
  done;

  let r = Array.init len (fun i -> i) in
  for i = 0 to len - 2 do
    let j = i + Random.int (len - i) in
    let r_i = r.(i) in
    r.(i) <- r.(j);
    r.(j) <- r_i
  done;

  for i = 0 to len - 1 do
    Record.seek_sf64 e (float_of_int (r.(i) * 2));
    assert_val e r.(i);
    Record.seek_sf64 e (float_of_int (r.(i) * 2 + 1));
    assert_val e r.(i)
  done;
  for i = 0 to len - 1 do
    Record.seek_si e (r.(i) * 2);
    assert_val e r.(i);
    Record.seek_si e (r.(i) * 2 + 1);
    assert_val e r.(i)
  done;
  for i = 0 to len - 1 do
    Record.seek_si64 e (Int64.of_int (r.(i) * 2));
    assert_val e r.(i);
    Record.seek_si64 e (Int64.of_int (r.(i) * 2 + 1));
    assert_val e r.(i)
  done;
  for i = 0 to len - 1 do
    Record.seek_ss e (Printf.sprintf "%14d" (r.(i) * 2));
    assert_val e r.(i);
    Record.seek_ss e (Printf.sprintf "%14d" (r.(i) * 2 + 1));
    assert_val e r.(i)
  done;
  for _ = 0 to len - 1 do
    let f = Random.float (float_of_int len) in
    Record.seek_sf64 e f;
    assert (Record.sf64 e <= f);
    assert (Record.sf64 e +. 2. > f);
    Record.seek_sf64 e f;
    assert (Record.sf64 e <= f);
    assert (Record.sf64 e +. 2. > f);
  done;
  for _ = 0 to len - 1 do
    let i = Random.int (len * 2) in
    Record.seek_si e i;
    assert (Record.si e <= i);
    assert (Record.si e + 2 > i);
    Record.seek_si e i;
    assert (Record.si e <= i);
    assert (Record.si e + 2 > i);
  done;
  for _ = 0 to len - 1 do
    let i = Int64.of_int (Random.int len) in
    Record.seek_si64 e i;
    assert (Record.si64 e <= i);
    assert (Int64.add (Record.si64 e) 2L > i);
    Record.seek_si64 e i;
    assert (Record.si64 e <= i);
    assert (Int64.add (Record.si64 e) 2L > i);
  done;

  let v = Record.Vector.create () in
  begin
    try
      let _ = Record.Vector.get v 0 in
      assert false
    with Invalid_argument _ -> ()
  end;
  let _ = Record.Vector.append v in
  let e = Record.Vector.get v 0 in
  for i = 0 to len - 1 do
    let e' = Record.Vector.append v in
    Record.next e;
    Record.set_i e' i;
    assert (Record.i e = i);
    assert (Record.Vector.end_ v |> Record.i = i)
  done;

  let h5 = H5.create_trunc "test.h5" in
  Record.Array.make_table a h5 "f\\o/o";
  Record.Array.write a h5 "b\\a/r";
  H5.close h5;

  let h5 = H5.open_rdonly "test.h5" in
  assert (H5.ls ~order:INC h5 = ["b\\a/r"; "f\\o/o"]);
  Record.Array.read_table h5 "f\\o/o"
  |> Record.Array.iteri ~f:(fun i e ->
    assert_val e i);
  Record.Array.read h5 "b\\a/r"
  |> Record.Array.iteri ~f:(fun i e -> assert_val e i);
  Record.Array.read_records h5 ~start:0 ~nrecords:(len / 2) "f\\o/o"
  |> Record.Array.iteri ~f:(fun i e -> assert_val e i);
  Subset.Array.read_fields_name h5 "f\\o/o"
  |> Subset.Array.iteri ~f:(fun i e -> assert (Subset.f64 e = float_of_int i));
  H5.close h5;

  let slen = 1024 * 1024 in
  let s = Simple.Array.make slen in
  let h5 = H5.create_trunc "test.h5" in
  let a = Record.Array.make 0 in
  Record.Array.make_table a h5 "a";
  Record.Array.write a h5 "b";
  Simple.Array.make_table s h5 "c";
  Simple.Array.write s h5 "d";
  H5.close h5;

  let h5 = H5.open_rdonly "test.h5" in
  let a = Record.Array.read_table h5 "a" in
  assert (Record.Array.length a = 0);
  let a = Record.Array.read h5 "b" in
  assert (Record.Array.length a = 0);
  let s = Simple.Array.read_table h5 "c" in
  assert (Simple.Array.length s = slen);
  let s = Simple.Array.read h5 "d" in
  assert (Simple.Array.length s = slen);
  H5.close h5;

  (* This test used to trigger a segfault when [Ext.t] leaked in [Struct.set_string] and
     [Struct.Vector.realloc]. *)
  for _ = 0 to 7 do
    let v = Record.Vector.create () in
    let s = "" in
    for i = 0 to 16 * 1024 * 1024 - 1 do
      let f = float i in
      let i64 = Int64.of_int i in
      Record.set (Record.Vector.append v) ~sf64:f ~si:i ~si64:i64 ~ss:s ~f64:f ~i ~i64 ~s;
      let _ = Record.Vector.get v (Record.Vector.length v - 1) in ()
    done;
    Gc.full_major ()
  done;

  (* This test used to trigger a segmentation fault when [Vector.capacity] showed bigger
     size than was actually alloced in [Vector.mem]. *)
  let v = Record.Vector.create () in
  let _ = Record.Vector.append v in
  Struct.reset_serialize ();
  let s = Marshal.to_string v [Closures] in
  Gc.full_major ();
  Struct.reset_deserialize ();
  let v = Marshal.from_string s 0 in
  Record.Vector.append v
  |> Record.set ~sf64:0. ~si:0 ~si64:0L ~ss:"              " ~f64:0. ~i:0 ~i64:0L
    ~s:"                ";

  let _ = Marshal.to_string (module Record : Hdf5_caml.Struct_intf.S) [Closures] in

  let v = Simple.Vector.create () in
  for _ = 0 to 15 do
    Simple.Vector.append v
    |> Simple.set ~f:0.
  done;
  Simple.Vector.clear v;
  let e = Simple.Vector.append v in
  Simple.seek_f e 3.;
  assert (Simple.pos e = 0)

module Big = struct
  [%%h5struct
    id   "ID"   Int;
    big  "Big"  Bigstring;
    f32  "F32"  Array_float32;
    f64  "F64"  Array_float64;
    si8  "SI8"  Array_sint8;
    ui8  "UI8"  Array_uint8;
    si16 "SI16" Array_sint16;
    ui16 "UI16" Array_uint16;
    i32  "I32"  Array_int32;
    i64  "I64"  Array_int64;
    i    "I"    Array_int;
    ni   "NI"   Array_nativeint;
    c    "C"    Array_char;
  ]
end

open Bigarray

let create_array len =
  Big.Array.init len (fun i b ->
    let f32 = Array1.create float32 c_layout i in
    for j = 0 to i - 1 do
      f32.{j} <- float j
    done;
    let f64 = Array1.create float64 c_layout i in
    for j = 0 to i - 1 do
      f64.{j} <- float j
    done;
    let si8 = Array1.create int8_signed c_layout i in
    for j = 0 to i - 1 do
      si8.{j} <- j
    done;
    let ui8 = Array1.create int8_unsigned c_layout i in
    for j = 0 to i - 1 do
      ui8.{j} <- j
    done;
    let si16 = Array1.create int16_signed c_layout i in
    for j = 0 to i - 1 do
      si16.{j} <- j
    done;
    let ui16 = Array1.create int16_unsigned c_layout i in
    for j = 0 to i - 1 do
      ui16.{j} <- j
    done;
    let i32 = Array1.create int32 c_layout i in
    for j = 0 to i - 1 do
      i32.{j} <- Int32.of_int j
    done;
    let i64 = Array1.create int64 c_layout i in
    for j = 0 to i - 1 do
      i64.{j} <- Int64.of_int j
    done;
    let ai = Array1.create int c_layout i in
    for j = 0 to i - 1 do
      ai.{j} <- j
    done;
    let ni = Array1.create nativeint c_layout i in
    for j = 0 to i - 1 do
      ni.{j} <- Nativeint.of_int j
    done;
    let c = Array1.create char c_layout i in
    for j = 0 to i - 1 do
      c.{j} <- Char.chr (j land 0xff)
    done;
    Big.set b ~id:i ~big:(string_of_int i |> Bigstring.of_string) ~f32 ~f64 ~si8
      ~ui8 ~si16 ~ui16 ~i32 ~i64 ~i:ai ~ni ~c)

let () =
  let check a =
    Big.Array.iteri a ~f:(fun i a ->
      Array.iter (fun (Big.Accessors.T acc) ->
        match acc.field.type_ with
        | Int -> assert (acc.get a = i)
        | Int64 -> assert false
        | Float64 -> assert false
        | String _ -> assert false
        | Bigstring -> assert (acc.get a |> Bigstring.to_string = string_of_int i)
        | Array_float32 ->
          let a = acc.get a in
          assert (Array1.dim a = i);
          for j = 0 to i - 1 do
            assert (a.{j} = float j)
          done
        | Array_float64 ->
          let a = acc.get a in
          assert (Array1.dim a = i);
          for j = 0 to i - 1 do
            assert (a.{j} = float j)
          done
        | Array_sint8 ->
          let a = acc.get a in
          assert (Array1.dim a = i);
          for j = 0 to i - 1 do
            assert (a.{j} = (j lsl 55) asr 55)
          done
        | Array_uint8 ->
          let a = acc.get a in
          assert (Array1.dim a = i);
          for j = 0 to i - 1 do
            assert (a.{j} = j land 0xff)
          done
        | Array_sint16 ->
          let a = acc.get a in
          assert (Array1.dim a = i);
          for j = 0 to i - 1 do
            assert (a.{j} = j)
          done
        | Array_uint16 ->
          let a = acc.get a in
          assert (Array1.dim a = i);
          for j = 0 to i - 1 do
            assert (a.{j} = j)
          done
        | Array_int32 ->
          let a = acc.get a in
          assert (Array1.dim a = i);
          for j = 0 to i - 1 do
            assert (a.{j} = Int32.of_int j)
          done
        | Array_int64 ->
          let a = acc.get a in
          assert (Array1.dim a = i);
          for j = 0 to i - 1 do
            assert (a.{j} = Int64.of_int j)
          done
        | Array_int ->
          let a = acc.get a in
          assert (Array1.dim a = i);
          for j = 0 to i - 1 do
            assert (a.{j} = j)
          done
        | Array_nativeint ->
          let a = acc.get a in
          assert (Array1.dim a = i);
          for j = 0 to i - 1 do
            assert (a.{j} = Nativeint.of_int j)
          done
        | Array_char ->
          let a = acc.get a in
          assert (Array1.dim a = i);
          for j = 0 to i - 1 do
            assert (a.{j} = Char.chr (j land 0xff))
          done) Big.Accessors.all) in
  let a = create_array 1024 in
  check a;
  let p = Big.Array.get a 0 in
  Big.Array.init 1024 (fun i b ->
    Big.move p i;
    Array.iter (fun (Big.Accessors.T acc) ->
      match acc.field.type_ with
      | Int -> acc.set b i
      | Int64 -> assert false
      | Float64 -> assert false
      | String _ -> assert false
      | Bigstring -> acc.set b (acc.get p)
      | Array_float32 -> acc.set b (acc.get p)
      | Array_float64 -> acc.set b (acc.get p)
      | Array_sint8 -> acc.set b (acc.get p)
      | Array_uint8 -> acc.set b (acc.get p)
      | Array_sint16 -> acc.set b (acc.get p)
      | Array_uint16 -> acc.set b (acc.get p)
      | Array_int32 -> acc.set b (acc.get p)
      | Array_int64 -> acc.set b (acc.get p)
      | Array_int -> acc.set b (acc.get p)
      | Array_nativeint -> acc.set b (acc.get p)
      | Array_char -> acc.set b (acc.get p)) Big.Accessors.all)
  |> check

let stress_test_bigarray num_arrays num_elements =
  let create_array () =
    Big.Array.get (create_array (1 + Random.int num_arrays)) 0 in
  let a = Array.init num_arrays (fun _ -> create_array ()) in
  let create_element () =
    let a = a.(Random.int num_arrays) in
    let pos = Big.mem a |> Big.Array.length |> Random.int in
    Big.move a pos;
    let big = Big.big a in
    assert (Bigstring.to_string big = string_of_int pos);
    let f32 = Big.f32 a in
    assert (Array1.dim f32 = pos);
    for i = 0 to pos - 1 do
      assert (f32.{i} = float_of_int i)
    done;
    let si16 = Big.si16 a in
    assert (Array1.dim si16 = pos);
    for i = 0 to pos - 1 do
      assert (si16.{i} = i)
    done;
    big in
  let e = Array.init num_elements (fun _ -> create_element ()) in
  Struct.reset_serialize ();
  let marshalled = ref (Marshal.to_string a.(Random.int num_arrays) []) in
  let create_simple () =
    let h5 = H5.create_trunc "simple.h5" in
    Big.Array.write (Big.mem a.(Random.int num_arrays)) h5 "a";
    H5.close h5 in
  create_simple ();
  let create_table () =
    let h5 = H5.create_trunc "table.h5" in
    Big.Array.make_table (Big.mem a.(Random.int num_arrays)) h5 "a";
    H5.close h5 in
  create_table ();
  for _ = 0 to num_arrays - 1 do
    for _ = 0 to num_elements - 1 do
      match Random.int 32 with
      | 0 -> a.(Random.int num_arrays) <- create_array ()
      | 1 ->
        Struct.reset_serialize ();
        marshalled := Marshal.to_string a.(Random.int num_arrays) []
      | 2 ->
        Struct.reset_deserialize ();
        a.(Random.int num_arrays) <- Marshal.from_string !marshalled 0
      | 3 -> create_simple ()
      | 4 ->
        let h5 = H5.open_rdonly "simple.h5" in
        a.(Random.int num_arrays) <- Big.Array.(get (read h5 "a") 0);
        H5.close h5
      | 5 -> create_table ()
      | 6 ->
        let h5 = H5.open_rdonly "table.h5" in
        a.(Random.int num_arrays) <- Big.Array.(get (read_table h5 "a") 0);
        H5.close h5
      | _ -> e.(Random.int num_elements) <- create_element ()
    done;
    Gc.full_major ()
  done

let () =
  stress_test_bigarray 128 128

let () =
  let s =
    Array.init 128 (fun i ->
      String.init i (fun i -> Char.chr (i + 1))) in
  let b = Array.map Bigstring.of_string s in
  Gc.full_major ();
  Array.iteri (fun i b ->
    assert (Bigstring.to_string b = s.(i))) b

module Bigchar = struct
  [%%h5struct
    id "ID" Int;
    s  "S"  (String 1);
    a  "A"  Bigstring;
    b  "B"  Array_char;
  ]
end

let () =
  let len = 1024 in
  let aa =
    Array.init len (fun i ->
      String.init i (fun i ->
        let i = i land 0xff in
        Char.chr (if i = 0 then 1 else i))) in
  let ab =
    Array.init len (fun i ->
      String.init i (fun i -> Char.chr (i land 0xff))) in
  let v = Bigchar.Vector.create () in
  for i = 0 to len - 1 do
    Bigchar.Vector.append v
    |> Bigchar.set ~id:i ~s:"A"
      ~a:(Bigstring.of_string aa.(i))
      ~b:(Array_char.of_string ab.(i))
  done;
  let a = Bigchar.Vector.to_array v in
  Gc.full_major ();
  Bigchar.Array.iteri a ~f:(fun i t ->
    let a = Bigchar.a t |> Bigstring.to_string in
    let b = Bigchar.b t |> Array_char.to_string in
    assert (a = aa.(i));
    assert (b = ab.(i)));

  let h5 = H5.create_trunc "test.h5" in
  Bigchar.Array.make_table a h5 "a";
  H5.close h5;

  let h5 = H5.open_rdonly "test.h5" in
  for _ = 0 to 255 do
    let _ : Bigchar.Array.t = Bigchar.Array.read_table h5 "a" in
    Gc.full_major ()
  done;
  for _ = 0 to 4 * 1024 do
    let a = Bigchar.Array.read_table h5 "a" in
    let _ : Bigstring.t = Bigchar.a (Bigchar.Array.get a 0) in
    Gc.full_major ()
  done;
  H5.close h5

module Foo = struct
  [%%h5struct
    a "A" Int (Default 0);
    b "B" Float64;
  ]
end

module Bar = struct
  [%%h5struct
    b "B" Float64;
    d "D" (String 16) (Default "NONE");
    a "A" Int;
    c "C" Int (Default 1);
  ]
end

module Ext = struct
  type t = private int
end

module Mem = struct
  module T = struct
    type t = {
      refcount      : int;
      data          : Ext.t;
      capacity      : int; (* The capacity of [data] *)
      mutable nmemb : int; (* The number of records in the table *)
      size          : int; (* The length of a record *)
      nfields       : int; (* The number of fields *)
    }
  end

  type t = {
    ops : Ext.t; (* Custom operations field *)
    t   : T.t;
  }

  let data t : Hdf5_raw.H5tb.Data.t = Obj.magic t.t.data
end

let () =
  let len = 16 in
  let h5 = H5.create_trunc "test.h5" in
  let a = Foo.Array.init len (fun i -> Foo.set ~a:i ~b:(float i *. 0.25)) in
  Foo.Array.make_table a h5 "a";
  H5.close h5;

  let h5 = H5.open_rdonly "test.h5" in
  Bar.Array.read_table h5 "a"
  |> Bar.Array.iteri ~f:(fun i t ->
    assert (Bar.a t = i);
    assert (Bar.b t = (float i *. 0.25));
    assert (Bar.c t = 1);
    assert (Bar.d t = "NONE"));
  H5.close h5

module Short = struct
  [%%h5struct
    a "A" (String 16);
  ]
end

module Shorter = struct
  [%%h5struct
    a "A" (String 8);
  ]
end

module Long = struct
  [%%h5struct
    a "A" Bigstring;
  ]
end

let () =
  let file = "test.h5" in
  let h5 = H5.create_trunc file in
  let a = Short.Array.init 8 (fun i -> Short.set ~a:(Printf.sprintf "%16d" i)) in
  Short.Array.make_table a h5 "a";
  H5.close h5;

  let h5 = H5.open_rdonly file in
  begin
    try
      let _ = Shorter.Array.read_table h5 "a" in
      assert false
    with _ -> ()
  end;
  Long.Array.read_table h5 "a"
  |> Long.Array.iteri ~f:(fun i b ->
    assert(Long.a b |> Type.Bigstring.to_string = Printf.sprintf "%16d" i));
  H5.close h5
