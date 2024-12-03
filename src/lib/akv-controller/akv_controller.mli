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

val kind_of_yojson : Yojson.Safe.t -> Yojson.Safe.t -> (kind, string) result
val kind_to_yojson : kind -> Yojson.Safe.t * Yojson.Safe.t

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
[@@deriving yojson { strict = false }]

type watch =
  | ADDED of crd
  | DELETED of crd
  | MODIFIED of crd

val watch_of_yojson : Yojson.Safe.t -> (watch, [> `Msg of string ]) result
val key_of_crd : crd -> string
val name_of_crd : crd -> string
