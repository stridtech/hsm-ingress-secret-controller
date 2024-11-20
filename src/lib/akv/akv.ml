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
