(* TODO: move to some shared stdlib *)
module Result = struct
  include Result

  let ( let+ ) result f = map f result
  let ( let* ) = bind

  (* let ( and* ) r1 r2 = match r1, r2 with | Ok x, Ok y -> Ok (x, y) | Ok _,
     Error e | Error e, Ok _ | Error e, Error _ -> Error e
  *)
end

module ServiceAccount = struct
  let get_token ~env () =
    let fs = Eio.Stdenv.fs env in
    let token =
      Eio.Path.load
        Eio.Path.(fs / "/var/run/secrets/kubernetes.io/serviceaccount/token")
    in
    token

  let get_namespace ~env () =
    let fs = Eio.Stdenv.fs env in
    let namespace =
      Eio.Path.load
        Eio.Path.(
          fs / "/var/run/secrets/kubernetes.io/serviceaccount/namespace")
    in
    namespace
end

module Client = struct
  let make ~sw ~env () =
    Piaf.Client.create
      ~sw
      env
      ~config:
        { Piaf.Config.default with
          follow_redirects = true
        ; allow_insecure = true
        ; flush_headers_immediately = false
        }
      (Uri.of_string "https://kubernetes.default.svc")

  let make_headers ~env =
    let token = ServiceAccount.get_token ~env () in
    let authorization = Printf.sprintf "Bearer %s" token in
    [ "Authorization", authorization
    ; "Content-Type", "application/json"
    ; "Accept", "application/json"
    ]
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
    let string_body = payload_to_yojson payload |> Yojson.Safe.to_string in
    Logs.debug (fun m -> m "%s" string_body);
    Piaf.Client.post
      client
      ~headers:(Client.make_headers ~env)
      ~body:(Piaf.Body.of_string string_body)
    @@ Printf.sprintf "/api/v1/namespaces/%s/secrets" payload.metadata.namespace

  let update_secret ~env ~(client : Piaf.Client.t) payload =
    let string_body = payload_to_yojson payload |> Yojson.Safe.to_string in
    Logs.debug (fun m -> m "%s" string_body);
    Piaf.Client.put
      client
      ~headers:(Client.make_headers ~env)
      ~body:(Piaf.Body.of_string string_body)
    @@ Printf.sprintf "/api/v1/namespaces/%s/secrets" payload.metadata.namespace

  let delete_secret ~env ~(client : Piaf.Client.t) ~namespace ~name =
    Piaf.Client.delete client ~headers:(Client.make_headers ~env)
    @@ Printf.sprintf "/api/v1/namespaces/%s/secrets/%s" namespace name
end

let get_crd
      ~env
      ~client
      ~group
      ~version
      ~plural
      ~(f : Yojson.Safe.t -> unit)
      ?(watch = false)
      ()
  =
  let open Result in
  let watch = if watch then "true" else "false" in
  let path =
    Printf.sprintf "/apis/%s/%s/%s?watch=%s" group version plural watch
  in
  let headers = Client.make_headers ~env in
  let+ resp = Piaf.Client.get client ~headers path in
  let body = Piaf.Body.to_stream resp.body in

  Piaf_stream.iter
    ~f:(fun Faraday.{ buffer; off; len } ->
      let json =
        Bigstringaf.substring buffer ~off ~len |> Yojson.Safe.from_string
      in
      f json)
    body
