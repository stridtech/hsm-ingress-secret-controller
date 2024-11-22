type spec =
  { akv : string
  ; secret : string
  ; key : string
  ; secret_name : string [@key "secretName"]
  }
[@@deriving yojson, json_schema]

type kind = string [@@deriving yojson, json_schema]

type metadata =
  { name : string
  ; namespace : string
  ; generation : int
  }
[@@deriving yojson { strict = false }]

type crd =
  { apiVersion : string
  ; kind : kind
  ; spec : spec
  ; metadata : metadata
  }
[@@deriving yojson { strict = false }]

type watch =
  | ADDED of crd
  | DELETED of crd

let watch_of_yojson json =
  let module Json = Yojson.Safe.Util in
  let typ = Json.member "type" json |> Json.to_string in
  let crd = Json.member "object" json |> crd_of_yojson in
  match typ, crd with
  | "ADDED", Ok crd -> Ok (ADDED crd)
  | "DELETED", Ok crd -> Ok (DELETED crd)
  | _, Ok crd -> Error (`Msg "unknown watch")
  | _, Error e -> Error (`Msg ("Yojson parse error: " ^ e))
