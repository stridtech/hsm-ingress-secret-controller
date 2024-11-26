(lang dune 3.17)

(name azure)

(generate_opam_files true)

(source
 (github username/reponame))

(authors "Author Name <author@example.com>")

(maintainers "Maintainer Name <maintainer@example.com>")

(license LICENSE)

(documentation https://url/to/documentation)

(package
 (name azure)
 (synopsis "A short synopsis")
 (description "A longer description")
 (depends ocaml dune)
 (tags
  ("add topics" "to describe" your project)))

(package
 (name msal)
 (synopsis "Microsoft authentication library")
 (depends ocaml dune piaf yojson eio jose))

; (package
;  (name kubernetes)
;  (synopsis "Tools for interacting with kubernetes")
;  (depends ocaml dune piaf yojson))

; See the complete stanza docs at https://dune.readthedocs.io/en/stable/reference/dune-project/index.html
