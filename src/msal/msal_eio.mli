val get_access_token_request_description :
   env:< fs : [> Eio.Fs.dir_ty ] Eio.Path.t ; .. >
  -> scope:string
  -> unit
  -> (Msal.request_description, Msal.Error.t) result
