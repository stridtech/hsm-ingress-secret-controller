module Result = struct
  include Result

  let[@warning "-32"] ( let+ ) result f = map f result
  let ( let* ) = bind
end

let piaf_error_to_error (e : Piaf.Error.t) : Msal.Error.t =
  match e with `Msg s -> `Msg s | e -> `Msg (Piaf.Error.to_string e)

let get_access_token ~sw ~env ~scope () : (string, Msal.Error.t) result =
  let open Result in
  match Msal_eio.get_access_token_request_description ~env ~scope () with
  | Ok Msal.{ uri; headers; body; _ } ->
    let body = Option.map Piaf.Body.of_string body in
    let* res =
      Piaf.Client.Oneshot.post ~sw ~headers ?body env uri
      |> Result.map_error piaf_error_to_error
    in
    Piaf.Body.to_string res.body |> Result.map_error piaf_error_to_error
  | Error e -> Error e
