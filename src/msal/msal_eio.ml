module Result = struct
  include Result

  let[@warning "-32"] ( let+ ) result f = map f result
  let ( let* ) = bind
end

(* Eio stuff *)
let get_access_token_request_description ~env ~scope () =
  let open Result in
  let* client_id = Msal.get_client_id () in
  let* tenant_id = Msal.get_tenant_id () in
  let* token_path = Msal.get_token_path () in

  let fs = Eio.Stdenv.fs env in
  let federated_token = Eio.Path.load Eio.Path.(fs / token_path) in

  Ok
    (Msal.get_access_token_request_description
       ~tenant_id
       ~client_id
       ~federated_token
       ~scope)
