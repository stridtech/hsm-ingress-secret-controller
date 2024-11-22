module Result = struct
  include Result

  let ( let+ ) result f = map f result
  let ( let* ) = bind

  (* let ( and* ) r1 r2 = match r1, r2 with | Ok x, Ok y -> Ok (x, y) | Ok _,
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

let printer (watch : Akv_controller.watch) =
  let a = Printf.sprintf "%s secret: %s in namespace: %s" in
  match watch with
  | ADDED crd -> a "ADDED" crd.spec.secret_name crd.metadata.namespace
  | DELETED crd -> a "DELETED" crd.spec.secret_name crd.metadata.namespace

let handle ~env ~client (watch : Akv_controller.watch) =
  match watch with
  | ADDED crd ->
    Kubernetes.Secret.make_payload
      ~name:crd.spec.secret_name
      ~namespace:crd.metadata.namespace
      Kubernetes.Secret.(TLS { crt = "test"; key = "test" })
    |> Kubernetes.Secret.create_secret ~env ~client
  | _ -> failwith "Can't delete"

let request ~env ~sw _akv _name =
  let open Result in
  let* client = Kubernetes.Client.make ~sw ~env () in
  Kubernetes.watch_crd
    ~env
    ~client
    ~group:"strid.tech"
    ~version:"v1alpha"
    ~namespace:"*"
    ~plural:"hsm-keys"
    ~f:(fun json ->
      Akv_controller.watch_of_yojson json |> function
      | Ok watch ->
        print_endline (printer watch);
        let _ = handle ~env ~client watch in
        ()
      | Error (`Msg err) -> prerr_endline err)
    ()

let () =
  setup_log (Some Logs.Debug);
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
      | Ok () -> ()
      | Error e -> failwith (Piaf.Error.to_string e)))
