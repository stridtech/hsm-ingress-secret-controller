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

let base_headers = [ "User-Agent", "k8s-akv-client/1.0"; "Accept", "*/*" ]

let request ~env ~sw akv name =
  let open Piaf in
  let open Result in
  let akv_uri = Azure_akv.Akv.Certificate.make_uri ~akv ~name () in
  let* client =
    Client.create
      env
      ~sw
      ~config:
        { Config.default with
          follow_redirects = true
        ; allow_insecure = false
        ; flush_headers_immediately = false
        }
      akv_uri
  in
  let token = Sys.getenv "AKV_ACCESS_TOKEN" in
  let* response =
    Client.get
      ~headers:(("Authorization", "Bearer " ^ token) :: base_headers)
      client
    @@ Uri.path_and_query akv_uri
  in

  let+ body = Body.to_string response.body in
  Logs.info (fun m -> m "body: %s" body);
  let ret =
    body |> Yojson.Safe.from_string |> Azure_akv.Akv.Certificate.of_yojson
  in
  match ret with
  | Ok json ->
    Logs.info (fun m -> m "%a" Azure_akv.Akv.Certificate.pp json);
    Client.shutdown client
  | Error error ->
    Format.eprintf "error: %s@." error;
    Client.shutdown client

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
