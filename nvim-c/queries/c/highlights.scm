;; extends

; Like Emacs: the names a declaration introduces get their own colour
; (colors/emacs.lua), later uses of them don't. Neovim's own C queries,
; which this adds to, give every identifier @variable at a lower priority.

(declaration
  declarator: (identifier) @variable.declaration)

(init_declarator
  declarator: (identifier) @variable.declaration)

(array_declarator
  declarator: (identifier) @variable.declaration)

(pointer_declarator
  declarator: (identifier) @variable.declaration)

(field_declaration
  declarator: (field_identifier) @variable.declaration)

(array_declarator
  declarator: (field_identifier) @variable.declaration)

(pointer_declarator
  declarator: (field_identifier) @variable.declaration)

(enumerator
  name: (identifier) @variable.declaration)
