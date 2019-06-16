# I3ipc

A pure OCaml implementation of the [i3](http://i3wm.org) [IPC
protocol](http://i3wm.org/docs/ipc.html).

This library allows you to communicate with a running instance of i3, run
commands, query information about the state of the WM, and subscribe to events.

## Install

```
opam install i3ipc
```

## Documentation

- See the API documentation, version:
  [dev](https://armael.github.io/ocaml-i3ipc/dev/i3ipc/index.html),
  [0.2](https://armael.github.io/ocaml-i3ipc/0.2/i3ipc/index.html),
  [0.1](https://armael.github.io/ocaml-i3ipc/0.1/i3ipc/index.html)
- As an example, [examples/i3_msg.ml](examples/i3_msg.ml) is a 60 lines
  reimplementation of `i3-msg` using this library.

  Run `make examples` to build the examples; they will appear in `_build/default/examples/`.
