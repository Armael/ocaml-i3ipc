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

- See the [API documentation](https://armael.github.io/ocaml-i3ipc/dev/I3ipc.html)
- As an example, [examples/i3_msg.ml](examples/i3_msg.ml) is a 60 lines
  reimplementation of `i3-msg` using this library.

Running `make` at the root of the project should build the examples (as well as
the library itself).