let () =
  Openapi.Json_schema.yojson_of_schema Akv_controller.spec_schema
  |> Yojson.Safe.pretty_to_string
  |> print_endline
