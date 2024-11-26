type akv_spec =
  { akv : string
  ; secret : string
  ; key : string
  ; secret_name : string [@key "secretName"]
  }
[@@deriving yojson]

type hsm_spec =
  { hsm : string
  ; akv : string
  ; secret : string
  ; key : string
  ; secret_name : string [@key "secretName"]
  }
[@@deriving yojson]

type cert_spec =
  { akv : string
  ; cert : string
  ; secret_name : string [@key "secretName"]
  }
[@@deriving yojson]

type kind =
  | Hsm of hsm_spec
  | Akv of akv_spec
  | Cert of cert_spec

let kind_of_yojson json spec =
  match json with
  | `String "HsmKey" ->
    Result.map (fun hsm_spec -> Hsm hsm_spec) @@ hsm_spec_of_yojson spec
  | `String "AkvKey" ->
    Result.map (fun akv_spec -> Akv akv_spec) @@ akv_spec_of_yojson spec
  | `String "CertKey" ->
    Result.map (fun cert_spec -> Cert cert_spec) @@ cert_spec_of_yojson spec
  | _ -> Error "Not a valid kind"

let kind_to_yojson kind =
  match kind with
  | Hsm spec -> `String "HsmKey", hsm_spec_to_yojson spec
  | Akv spec -> `String "AkvKey", akv_spec_to_yojson spec
  | Cert spec -> `String "CertKey", cert_spec_to_yojson spec

type metadata =
  { name : string
  ; namespace : string
  ; generation : int
  }
[@@deriving yojson { strict = false }]

type crd =
  { apiVersion : string
  ; kind : kind
  ; metadata : metadata
  }

let crd_of_yojson json =
  let module Json = Yojson.Safe.Util in
  let kind =
    kind_of_yojson (Json.member "kind" json) (Json.member "spec" json)
  in
  let metadata = Json.member "metadata" json |> metadata_of_yojson in
  match kind, metadata with
  | Ok kind, Ok metadata ->
    Ok
      { apiVersion = Json.member "apiVersion" json |> Json.to_string
      ; kind
      ; metadata
      }
  | Error e, Ok _ -> Error e
  | Ok _, Error e -> Error e
  | Error e, Error e' -> Error (e ^ " & " ^ e')

let crd_to_yojson crd =
  let kind, spec = kind_to_yojson crd.kind in
  `Assoc
    [ "apiVersion", `String crd.apiVersion
    ; "kind", kind
    ; "spec", spec
    ; "metadata", metadata_to_yojson crd.metadata
    ]

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
  | _, Ok _crd -> Error (`Msg "unknown watch")
  | _, Error e -> Error (`Msg ("Yojson parse error: " ^ e))

let key_of_crd (crd : crd) : string =
  match crd.kind with
  | Hsm spec -> Printf.sprintf "engine:e_akv:hsm:%s:%s" spec.hsm spec.key
  | Akv spec -> Printf.sprintf "engine:e_akv:vault:%s:%s" spec.akv spec.key
  | Cert spec -> Printf.sprintf "engine:e_akv:vault:%s:%s" spec.akv spec.cert

let name_of_crd crd =
  match crd.kind with
  | Akv spec -> spec.secret_name
  | Cert spec -> spec.secret_name
  | Hsm spec -> spec.secret_name
