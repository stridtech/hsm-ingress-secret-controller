module Error : sig
  type t =
    [ `Msg of string
    | `Missing_client_id
    | `Missing_tenant_id
    | `Missing_federated_token_path
    ]

  val to_string : t -> string
  val pp_hum : Format.formatter -> t -> unit
end

type meth =
  | Post
  | Get

type request_description =
  { uri : Uri.t
  ; headers : (string * string) list
  ; body : string option
  ; meth : meth
  }

val get_token_path : unit -> (string, Error.t) result
val get_client_id : unit -> (string, Error.t) result
val get_tenant_id : unit -> (string, Error.t) result

val get_access_token_request_description :
   tenant_id:string
  -> client_id:string
  -> federated_token:string
  -> scope:string
  -> request_description

val token_of_response : string -> string
