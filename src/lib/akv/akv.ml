module Result = struct
  include Result

  let ( let+ ) result f = map f result
  let ( let* ) = bind

  (* let ( and* ) r1 r2 = match r1, r2 with | Ok x, Ok y -> Ok (x, y) | Ok _,
     Error e | Error e, Ok _ | Error e, Error _ -> Error e
  *)
end

module Client = struct
  let make ~sw ~env akv =
    let akv_uri = Printf.sprintf "https://%s.vault.azure.net" akv in
    let akv_uri = Uri.of_string akv_uri in
    Piaf.Client.create
      env
      ~sw
      ~config:
        { Piaf.Config.default with
          follow_redirects = true
        ; allow_insecure = false
        ; flush_headers_immediately = false
        }
      akv_uri

  let make_headers token =
    let authorization = Printf.sprintf "Bearer %s" token in
    [ "Authorization", authorization
    ; "Content-Type", "application/json"
    ; "Accept", "application/json"
    ; "User-Agent", "ocaml-akv-client/1.0"
    ]
end

module Certificate = struct
  type attributes =
    { enabled : bool
    ; nbf : int
    ; exp : int
    ; created : int
    ; updated : int
    }
  [@@deriving show, yojson { strict = false }]

  type t =
    { id : string
    ; kid : string
    ; sid : string
    ; x5t : string
    ; cer : string
    ; attributes : attributes
    }
  [@@deriving show, yojson { strict = false }]

  let make_uri ~akv ~name ?version () =
    let host = Printf.sprintf "%s.vault.azure.net" akv in
    let path =
      match version with
      | None -> Printf.sprintf "/certificates/%s" name
      | Some version -> Printf.sprintf "/certificates/%s/%s" name version
    in
    let uri =
      Uri.make
        ~scheme:"https"
        ~host
        ~path
        ~query:[ "api-version", [ "7.4" ] ]
        ()
    in

    print_endline @@ Uri.to_string uri;

    uri
end
