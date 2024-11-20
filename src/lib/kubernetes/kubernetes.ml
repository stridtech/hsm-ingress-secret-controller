module ServiceAccount = struct
  let get_token ~env () =
    let fs = Eio.Stdenv.fs env in
    let token =
      Eio.Path.load
        Eio.Path.(fs / "/var/run/secrets/kubernetes.io/serviceaccount/token")
    in
    token
end

module Client = struct
  let make ~sw ~stdenv () =
    Piaf.Client.create
      ~sw
      stdenv
      (Uri.of_string "https://kubernetes.default.svc")
end

module Secret = struct
  type tls_secret =
    { crt : string [@key "tls.crt"]
    ; key : string [@key "tls.key"]
    }
  [@@deriving show, yojson]

  type t =
    | Opaque of Yojson.Safe.t
    | TLS of tls_secret
  [@@deriving show]

  let to_yojson t =
    match t with
    | Opaque p -> p
    | TLS tls_secret -> tls_secret_to_yojson tls_secret

  let of_yojson t =
    Result.ok
    @@
    try
      let _ = Yojson.Safe.Util.member "tls.crt" t in
      TLS (tls_secret_of_yojson t |> Result.get_ok)
    with
    | _ -> Opaque t

  type payload_metadata =
    { name : string
    ; namespace : string
    }
  [@@deriving yojson]

  type payload =
    { apiVersion : string
    ; kind : string
    ; metadata : payload_metadata
    ; typ : string [@key "type"]
    ; data : t
    }
  [@@deriving yojson]

  let make_payload ~name ~namespace t =
    let typ =
      match t with Opaque _ -> "Opaque" | TLS _ -> "kubernetes.io/tls"
    in
    let data =
      { apiVersion = "v1"
      ; kind = "Secret"
      ; metadata = { name; namespace }
      ; typ
      ; data = t
      }
    in
    data

  let create_secret ~env ~(client : Piaf.Client.t) payload =
    let token = ServiceAccount.get_token ~env () in
    let string_body = payload_to_yojson payload |> Yojson.Safe.to_string in
    Piaf.Client.post
      client
      ~headers:
        [ "Authorization", Printf.sprintf "Bearer %s" token
        ; "Content-Type", "application/json"
        ]
      ~body:(Piaf.Body.of_string string_body)
    @@ Printf.sprintf "/api/v1/namesapce/%s/secrets" payload.metadata.namespace
end
