module Result = struct
  include Result

  let ( let+ ) result f = map f result
  let ( let* ) = bind

  let both = function
    | Ok x, Ok y -> Ok (x, y)
    | Ok _, Error e | Error e, Ok _ | Error e, Error _ -> Error e

  (*
     let ( and* ) r1 r2 = match r1, r2 with | Ok x, Ok y -> Ok (x, y) | Ok _,
     Error e | Error e, Ok _ | Error e, Error _ -> Error e
  *)
end

let setup_log ?style_renderer level =
  Fmt_tty.setup_std_outputs ?style_renderer ();
  Logs.set_level level;
  Logs.set_reporter (Logs_fmt.reporter ());
  ()

let _get_akv_certificate ~env ~sw akv name =
  let open Result in
  let akv_uri = Akv.Certificate.make_uri ~akv ~name () in
  let* client = Akv.Client.make ~env ~sw akv in
  let token = Sys.getenv "AKV_ACCESS_TOKEN" in
  let* response =
    Piaf.Client.get ~headers:(Akv.Client.make_headers token) client
    @@ Uri.path_and_query akv_uri
  in

  let+ body = Piaf.Body.to_string response.body in
  Logs.info (fun m -> m "body: %s" body);
  let ret = body |> Yojson.Safe.from_string |> Akv.Certificate.of_yojson in
  match ret with
  | Ok json ->
    Logs.info (fun m -> m "%a" Akv.Certificate.pp json);
    Piaf.Client.shutdown client
  | Error error ->
    Format.eprintf "error: %s@." error;
    Piaf.Client.shutdown client

let get_certificate ~env ~sw ~token crd : (string, [> Piaf.Error.t ]) result =
  let open Result in
  match crd.Akv_controller.kind with
  | Hsm _spec -> failwith "hsm not supported"
  | Akv _spec -> failwith "akv not supported"
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
  let token = Sys.getenv "AKV_ACCESS_TOKEN" in
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
  | DELETED crd ->
    Kubernetes.Secret.delete_secret
      ~env
      ~client:kube_client
      ~name:(Akv_controller.name_of_crd crd)
      ~namespace:crd.metadata.namespace

let request ~env ~sw _akv _name =
  let open Result in
  let* kube_client = Kubernetes.Client.make ~sw ~env () in
  let f json =
    Logs.info (fun m -> m "Watch data: %s" (Yojson.Safe.to_string json));
    Akv_controller.watch_of_yojson json |> function
    | Ok watch ->
      let _ = handle ~env ~sw ~kube_client watch in
      ()
    | Error (`Msg err) -> prerr_endline err
  in
  let watch_crd =
    Kubernetes.watch_crd
      ~env
      ~client:kube_client
      ~group:"strid.tech"
      ~version:"v1alpha"
      ~namespace:"*"
      ~f
  in
  Eio.Fiber.pair (watch_crd ~plural:"cert-keys") (watch_crd ~plural:"akv-keys")
  |> Result.both

let () =
  setup_log (Some Logs.Info);
  let akv = ref "" in
  let name = ref "" in
  Arg.parse
    [ "--akv", Arg.Set_string akv, "AKV name"
    ; "--name", Arg.Set_string name, "Certificate name"
    ]
    (fun _ -> ())
    "akv_cert_secret --akv AKV --name CERT_NAME";
  Eio_main.run (fun env ->
    Eio.Switch.run (fun sw ->
      match request ~sw ~env !akv !name with
      | Ok ((), ()) -> ()
      | Error e -> failwith (Piaf.Error.to_string e)))
