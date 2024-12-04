val get_access_token :
   sw:Eio.Switch.t
  -> env:Eio_unix.Stdenv.base
  -> scope:string
  -> unit
  -> (string, Msal.Error.t) result
