(* Command-line arguments parsing *)
let message_type = ref "command"
let payload_elts = ref []

let _ = Arg.parse [
  "-t", Arg.Set_string message_type,
  "Type of the message to send. By default, \"command\". \
   Supported types: command, get_workspaces, get_outputs, \
   get_tree, get_marks, get_bar_config, get_version"
]
  (fun s -> payload_elts := s :: !payload_elts)
  "i3-msg: send an IPC message to i3"

(* Use all arguments, separated by whitespace, as payload *)
let payload = String.concat " " !payload_elts

(* A generic printer for lists *)
let pp_list fmt pp l =
  let rec aux = function
    | [] -> ()
    | [x] -> pp x
    | x::y::xs ->
      pp x; Format.fprintf fmt ","; Format.pp_print_space fmt (); aux (y :: xs)
  in
  Format.fprintf fmt "["; aux l; Format.fprintf fmt "]"

(* Dispatch following the message type, and send the corresponding IPC
   message. Then simply output the reply.
*)
let main =
  let fmt = Format.std_formatter in
  let%lwt conn = I3ipc.connect () in
  match !message_type with
  | "command" ->
    let%lwt outcomes = I3ipc.command conn payload in
    List.iter (fun outcome ->
      if not outcome.I3ipc.Reply.success then
        Format.fprintf fmt "ERROR: %s\n\n%!"
          (match outcome.I3ipc.Reply.error with Some s -> s | None -> "")
    ) outcomes;
    pp_list fmt (I3ipc.Reply.pp_command_outcome fmt) outcomes |> Lwt.return
  | "get_workspaces" ->
    let%lwt workspaces = I3ipc.get_workspaces conn in
    pp_list fmt (I3ipc.Reply.pp_workspace fmt) workspaces |> Lwt.return
  | "get_outputs" ->
    let%lwt outputs = I3ipc.get_outputs conn in
    pp_list fmt (I3ipc.Reply.pp_output fmt) outputs |> Lwt.return
  | "get_tree" ->
    let%lwt tree = I3ipc.get_tree conn in
    I3ipc.Reply.pp_node fmt tree |> Lwt.return
  | "get_marks" ->
    let%lwt marks = I3ipc.get_marks conn in
    pp_list fmt (Format.pp_print_string fmt) marks |> Lwt.return
  | "get_bar_ids" ->
    let%lwt bar_ids = I3ipc.get_bar_ids conn in
    pp_list fmt (Format.pp_print_string fmt) bar_ids |> Lwt.return
  | "get_bar_config" ->
    let%lwt bar_cfg = I3ipc.get_bar_config conn payload in
    I3ipc.Reply.pp_bar_config fmt bar_cfg |> Lwt.return
  | "get_version" ->
    let%lwt version = I3ipc.get_version conn in
    I3ipc.Reply.pp_version fmt version |> Lwt.return
  | "get_binding_modes" ->
    let%lwt binding_modes = I3ipc.get_binding_modes conn in
    I3ipc.Reply.pp_binding_modes fmt binding_modes |> Lwt.return
  | _ -> Format.fprintf Format.err_formatter "Unsupported message type"; exit 1

let () = Lwt_main.run main
