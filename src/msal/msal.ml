module Error = struct
  type t =
    [ `Msg of string
    | `Missing_client_id
    | `Missing_tenant_id
    | `Missing_federated_token_path
    ]

  let to_string t =
    match t with
    | `Msg str -> str
    | `Missing_client_id -> "Missing client_id in environment"
    | `Missing_tenant_id -> "Missing tenant_id in environment"
    | `Missing_federated_token_path ->
      "Missing federated token path in environment "

  let pp_hum formatter t = Format.fprintf formatter "%s" (to_string t)
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

let get_token_path () =
  Sys.getenv_opt "AZURE_FEDERATED_TOKEN_FILE" |> function
  | Some client_id -> Ok client_id
  | None -> Error `Missing_federated_token_path

let get_client_id () : (string, Error.t) result =
  Sys.getenv_opt "AZURE_CLIENT_ID" |> function
  | Some client_id -> Ok client_id
  | None -> Error `Missing_client_id

let get_tenant_id () : (string, Error.t) result =
  Sys.getenv_opt "AZURE_TENANT_ID" |> function
  | Some client_id -> Ok client_id
  | None -> Error `Missing_tenant_id

let get_access_token_request_description
      ~tenant_id
      ~client_id
      ~federated_token
      ~scope : request_description
  =
  let uri =
    Printf.sprintf
      "https://login.microsoftonline.com/%s/oauth2/v2.0/token"
      tenant_id
  in
  let uri = Uri.of_string uri in

  (* TODO: Can we use oidc here? *)
  let body =
    [ "scope", [ scope ]
    ; "client_id", [ client_id ]
    ; "client_assertion", [ federated_token ]
    ; "grant_type", [ "client_credentials" ]
    ; ( "client_assertion_type"
      , [ "urn:ietf:params:oauth:client-assertion-type:jwt-bearer" ] )
    ]
    |> Uri.encoded_of_query
  in

  let headers =
    [ "Content-Type", "application/x-www-form-urlencoded"
    ; "User-Agent", "ocaml-msal/1.0"
    ]
  in
  { uri; headers; body = Some body; meth = Post }

let token_of_response body =
  Yojson.Safe.from_string body
  |> Yojson.Safe.Util.member "access_token"
  |> Yojson.Safe.Util.to_string
