module Result = struct
  include Result

  let ( let+ ) result f = map f result
  let ( let* ) = bind
end

let setup_log ?style_renderer level =
  Fmt_tty.setup_std_outputs ?style_renderer ();
  Logs.set_level level;
  Logs.set_reporter (Logs_fmt.reporter ());
  ()

let get_certificate ~env ~sw ~token crd : (string, [> Piaf.Error.t ]) result =
  let open Result in
  match crd.Akv_controller.kind with
  | Hsm spec ->
    let* client = Akv.Client.make ~env ~sw spec.akv in
    let akv_uri = Akv.Secret.make_uri ~akv:spec.akv ~name:spec.secret () in
    let* response =
      Piaf.Client.get ~headers:(Akv.Client.make_headers token) client
      @@ Uri.path_and_query akv_uri
    in

    let* body = Piaf.Body.to_string response.body in
    Logs.info (fun m -> m "body: %s" body);
    let* ret =
      body
      |> Yojson.Safe.from_string
      |> Akv.Secret.of_yojson
      |> Result.map_error (fun e -> `Msg e)
    in
    Ok ret.value
  | Akv spec ->
    let* client = Akv.Client.make ~env ~sw spec.akv in
    let akv_uri = Akv.Secret.make_uri ~akv:spec.akv ~name:spec.secret () in
    let* response =
      Piaf.Client.get ~headers:(Akv.Client.make_headers token) client
      @@ Uri.path_and_query akv_uri
    in

    let* body = Piaf.Body.to_string response.body in
    Logs.info (fun m -> m "body: %s" body);
    let* ret =
      body
      |> Yojson.Safe.from_string
      |> Akv.Secret.of_yojson
      |> Result.map_error (fun e -> `Msg e)
    in
    Ok ret.value
  | Cert spec ->
    let* client = Akv.Client.make ~env ~sw spec.akv in
    let akv_uri = Akv.Certificate.make_uri ~akv:spec.akv ~name:spec.cert () in
    let* response =
      Piaf.Client.get ~headers:(Akv.Client.make_headers token) client
      @@ Uri.path_and_query akv_uri
    in

    let* body = Piaf.Body.to_string response.body in
    Logs.info (fun m -> m "body: %s" body);
    let* ret =
      body
      |> Yojson.Safe.from_string
      |> Akv.Certificate.of_yojson
      |> Result.map_error (fun e -> `Msg e)
    in
    Ok ret.cer

let handle ~env ~sw ~kube_client (watch : Akv_controller.watch) =
  let open Result in
  let* token =
    Msal_piaf.get_access_token
      ~env
      ~sw
      ~scope:"https://vault.azure.net/.default"
      ()
    |> Result.map_error (fun e -> `Msg (Msal.Error.to_string e))
  in
  let token = Msal.token_of_response token in
  match watch with
  | ADDED crd ->
    let certificate = get_certificate ~env ~sw ~token crd in
    (match certificate with
    | Ok certificate ->
      Kubernetes.Secret.make_payload
        ~name:(Akv_controller.name_of_crd crd)
        ~namespace:crd.metadata.namespace
        Kubernetes.Secret.(
          TLS
            { crt = Base64.encode_string certificate
            ; key = Akv_controller.key_of_crd crd |> Base64.encode_string
            })
      |> Kubernetes.Secret.create_secret ~env ~client:kube_client
    | Error e ->
      let () =
        Logs.warn (fun m -> m "Secret creation error: %a" Piaf.Error.pp_hum e)
      in
      Error e)
  | MODIFIED crd ->
    let certificate = get_certificate ~env ~sw ~token crd in
    (match certificate with
    | Ok certificate ->
      Kubernetes.Secret.make_payload
        ~name:(Akv_controller.name_of_crd crd)
        ~namespace:crd.metadata.namespace
        Kubernetes.Secret.(
          TLS
            { crt = Base64.encode_string certificate
            ; key = Akv_controller.key_of_crd crd |> Base64.encode_string
            })
      |> Kubernetes.Secret.update_secret ~env ~client:kube_client
    | Error e ->
      let () =
        Logs.warn (fun m -> m "Secret creation error: %a" Piaf.Error.pp_hum e)
      in
      Error e)
  | DELETED crd ->
    Kubernetes.Secret.delete_secret
      ~env
      ~client:kube_client
      ~name:(Akv_controller.name_of_crd crd)
      ~namespace:crd.metadata.namespace

let run ~env ~sw =
  let open Result in
  let* kube_client = Kubernetes.Client.make ~sw ~env () in

  let get_crd ~plural ?watch () =
    let f json =
      match watch with
      | Some true ->
        Logs.info (fun m ->
          m "Watching: true\nData: %s" (Yojson.Safe.to_string json));
        Akv_controller.watch_of_yojson json |> ( function
         | Ok watch ->
           let _ = handle ~env ~sw ~kube_client watch in
           ()
         | Error (`Msg err) -> prerr_endline err )
      | _ ->
        Logs.info (fun m ->
          m "Watching: false\nData: %s" (Yojson.Safe.to_string json));
        Akv_controller.crd_of_yojson json |> ( function
         | Ok watch ->
           let _ = handle ~env ~sw ~kube_client (MODIFIED watch) in
           ()
         | Error err -> Logs.warn (fun m -> m "CRD parse error: %s" err) )
    in

    Kubernetes.get_crd
      ~env
      ~client:kube_client
      ~group:"strid.tech"
      ~version:"v1alpha"
      ~f
      ~plural
      ?watch
      ()
    |> Result.get_ok
  in
  let () =
    [ "cert-keys"; "akv-keys"; "hsm-keys" ]
    |> List.map (fun plural -> get_crd ~plural ~watch:false)
    |> Eio.Fiber.all
  in
  [ "cert-keys"; "akv-keys"; "hsm-keys" ]
  |> List.map (fun plural -> get_crd ~plural ~watch:true)
  |> Eio.Fiber.all
  |> Result.ok

let () =
  setup_log (Some Logs.Info);
  Eio_main.run (fun env ->
    Eio.Switch.run (fun sw ->
      match run ~sw ~env with
      | Ok () -> ()
      | Error e -> failwith (Piaf.Error.to_string e)))
