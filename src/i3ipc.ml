open Stdint
module Json = Yojson.Safe

[@@@warning "-32"]

let (|?) o x =
  match o with
  | None -> x
  | Some y -> y

type protocol_error =
  | No_IPC_socket
  | Bad_magic_string of string
  | Unexpected_eof
  | Unknown_type of Uint32.t
  | Bad_reply of string

exception Protocol_error of protocol_error

(******************************************************************************)

module Reply = struct

  type command_outcome = {
    success: bool;
    error: (string option [@default None]);
  } [@@deriving of_yojson { strict = false }, show]

  type command_outcome_list =
    command_outcome list [@@deriving of_yojson, show]

  type rect = {
    x: int;
    y: int;
    width: int;
    height: int;
  } [@@deriving of_yojson { strict = false }, show]

  type workspace = {
    num: int;
    name: string;
    visible: bool;
    focused: bool;
    urgent: bool;
    rect: rect;
    output: string;
  } [@@deriving of_yojson { strict = false }, show]

  type workspace_list =
    workspace list [@@deriving of_yojson]

  type output = {
    name: string;
    active: bool;
    current_workspace: string option;
    rect: rect;
  } [@@deriving of_yojson { strict = false }, show]

  type output_list =
    output list [@@deriving of_yojson, show]

  type node_type =
    | Root
    | Output
    | Con
    | Floating_con
    | Workspace
    | Dockarea
  [@@deriving show]

  let node_type_of_yojson = function
    | `String "root" -> Result.Ok Root
    | `String "output" -> Result.Ok Output
    | `String "con" -> Result.Ok Con
    | `String "floating_con" -> Result.Ok Floating_con
    | `String "workspace" -> Result.Ok Workspace
    | `String "dockarea" -> Result.Ok Dockarea
    | j -> Result.Error ("Reply.node_type_of_yojson: " ^ Json.to_string j)

  type node_border =
    | Border_normal
    | Border_none
    | Border_pixel
  [@@deriving show]

  let node_border_of_yojson = function
    | `String "normal" -> Result.Ok Border_normal
    | `String "none" -> Result.Ok Border_none
    | `String "pixel" -> Result.Ok Border_pixel
    | j -> Result.Error ("Reply.node_border_of_yojson: " ^ Json.to_string j)

  type node_layout =
    | SplitH
    | SplitV
    | Stacked
    | Tabbed
    | Dockarea
    | Output
    | Unknown of string
  [@@deriving show]

  let node_layout_of_yojson = function
    | `String "splith" -> Result.Ok SplitH
    | `String "splitv" -> Result.Ok SplitV
    | `String "stacked" -> Result.Ok Stacked
    | `String "tabbed" -> Result.Ok Tabbed
    | `String "dockarea" -> Result.Ok Dockarea
    | `String "output" -> Result.Ok Output
    | `String s -> Result.Ok (Unknown s)
    | j -> Result.Error ("Reply.node_layout_of_yojson: " ^ Json.to_string j)

  type node = {
    nodes : (node list [@default []]);
    id: int32;
    name: string option;
    nodetype: node_type [@key "type"];
    border: node_border;
    current_border_width: int;
    layout: node_layout;
    percent: float option;
    rect: rect;
    window_rect: rect;
    deco_rect: rect;
    geometry: rect;
    window: int option;
    urgent: bool;
    focused: bool;
  } [@@deriving of_yojson { strict = false }, show]

  type mark = string [@@deriving yojson, show]
  type mark_list = mark list [@@deriving yojson, show]

  type bar_id = string [@@deriving yojson, show]
  type bar_id_list = bar_id list [@@deriving yojson, show]

  type colorable_bar_part =
    | Background
    | Statusline
    | Separator
    | FocusedBackground
    | FocusedStatusline
    | FocusedSeparator
    | FocusedWorkspaceText
    | FocusedWorkspaceBackground
    | FocusedWorkspaceBorder
    | ActiveWorkspaceText
    | ActiveWorkspaceBackground
    | ActiveWorkspaceBorder
    | InactiveWorkspaceText
    | InactiveWorkspaceBackground
    | InactiveWorkspaceBorder
    | UrgentWorkspaceText
    | UrgentWorkspaceBackground
    | UrgentWorkspaceBorder
    | BindingModeText
    | BindingModeBackground
    | BindingModeBorder
    | Undocumented of string
  [@@deriving show]

  module Bar_parts_map = Map.Make (struct
      type t = colorable_bar_part
      let compare = compare
    end)

  type bar_colors = string Bar_parts_map.t

  let pp_bar_colors fmt colors =
    Format.pp_print_string fmt "{";
    let first = ref true in
    Bar_parts_map.iter
      (fun k v ->
         if !first then first := false
         else (
           Format.pp_print_string fmt "; ";
           Format.pp_print_cut fmt ()
         );
         pp_colorable_bar_part fmt k;
         Format.pp_print_string fmt ":";
         Format.pp_print_string fmt v)
      colors;
    Format.pp_print_string fmt "}"

  let colorable_bar_part_of_string = function
    | "background" -> Background
    | "statusline" -> Statusline
    | "separator" -> Separator
    | "focused_background" -> FocusedBackground
    | "focused_statusline" -> FocusedStatusline
    | "focused_separator" -> FocusedSeparator
    | "focused_workspace_text" -> FocusedWorkspaceText
    | "focused_workspace_background" -> FocusedWorkspaceBackground
    | "focused_workspace_border" -> FocusedWorkspaceBorder
    | "active_workspace_text" -> ActiveWorkspaceText
    | "active_workspace_background" -> ActiveWorkspaceBackground
    | "active_workspace_border" -> ActiveWorkspaceBorder
    | "inactive_workspace_text" -> InactiveWorkspaceText
    | "inactive_workspace_background" -> InactiveWorkspaceBackground
    | "inactive_workspace_border" -> InactiveWorkspaceBorder
    | "urgent_workspace_text" -> UrgentWorkspaceText
    | "urgent_workspace_background" -> UrgentWorkspaceBackground
    | "urgent_workspace_border" -> UrgentWorkspaceBorder
    | "binding_mode_text" -> BindingModeText
    | "binding_mode_background" -> BindingModeBackground
    | "binding_mode_border" -> BindingModeBorder
    | s -> Undocumented s

  let bar_colors_of_yojson = function
    | `Assoc l as j ->
      begin try
          Result.Ok (
            List.fold_left (fun m (k, v) ->
              match v with
              | `String s ->
                Bar_parts_map.add
                  (colorable_bar_part_of_string k) s
                  m
              | _ -> raise Exit
            ) Bar_parts_map.empty l
          )
        with Exit ->
          Result.Error ("Reply.bar_colors_of_yojson: " ^ Json.to_string j)
      end
    | j -> Result.Error ("Reply.bar_colors_of_yojson: " ^ Json.to_string j)

  type bar_config = {
    id: string;
    mode: string;
    position: string;
    status_command: string;
    font: string;
    workspace_buttons: bool;
    binding_mode_indicator: bool;
    verbose: bool;
    colors: bar_colors;
  } [@@deriving of_yojson { strict = false }, show]

  type version = {
    major: int;
    minor: int;
    patch: int;
    human_readable: string;
    loaded_config_file_name: string;
  } [@@deriving of_yojson { strict = false }, show]

  let handle_error = function
    | Result.Ok x -> x
    | Result.Error s -> raise (Protocol_error (Bad_reply s))

  let result_of_command_outcome { success; error } =
    if success then Result.Ok () else Result.Error (error |? "")

  type binding_modes = string list
    [@@deriving of_yojson, show]

  type config = {
    config : string
  } [@@deriving of_yojson, show]

  let pp_config fmt config =
    Format.pp_print_string fmt config

  type tick = {
    tick_success : bool [@key "success"]
  } [@@deriving of_yojson, show]

  let pp_tick fmt tick =
    Format.pp_print_bool fmt tick
end

(******************************************************************************)

module Event = struct
  type workspace_change =
    | Focus
    | Init
    | Empty
    | Urgent
  [@@deriving show]

  let workspace_change_of_yojson = function
    | `String "focus" -> Result.Ok Focus
    | `String "init" -> Result.Ok Init
    | `String "empty" -> Result.Ok Empty
    | `String "urgent" -> Result.Ok Urgent
    | j -> Result.Error ("Event.workspace_change_of_yojson: " ^ Json.to_string j)

  type workspace_event_info = {
    change: workspace_change;
    current: Reply.node option;
    old: Reply.node option;
  } [@@deriving of_yojson { strict = false }, show]

  type output_change =
    | Unspecified
  [@@deriving show]

  let output_change_of_yojson = function
    | `String "unspecified" -> Result.Ok Unspecified
    | j -> Result.Error ("Event.output_change_of_yojson: " ^ Json.to_string j)

  type output_event_info = {
    change: output_change;
  } [@@deriving of_yojson { strict = false }, show]

  type mode_event_info = {
    change: string;
    pango_markup: bool;
  } [@@deriving of_yojson { strict = false }, show]

  type window_change =
    | New
    | Close
    | Focus
    | Title
    | FullscreenMode
    | Move
    | Floating
    | Urgent
    | Mark
  [@@deriving show]

  let window_change_of_yojson = function
    | `String "new" -> Result.Ok New
    | `String "close" -> Result.Ok Close
    | `String "focus" -> Result.Ok Focus
    | `String "title" -> Result.Ok Title
    | `String "fullscreen_mode" -> Result.Ok FullscreenMode
    | `String "move" -> Result.Ok Move
    | `String "floating" -> Result.Ok Floating
    | `String "urgent" -> Result.Ok Urgent
    | `String "mark" -> Result.Ok Mark
    | j -> Result.Error ("Event.window_change_of_yojson: " ^ Json.to_string j)

  type window_event_info = {
    change: window_change;
    container: Reply.node;
  } [@@deriving of_yojson { strict = false }, show]

  type bar_config_event_info = {
    bar_config: Reply.bar_config;
  } [@@deriving of_yojson { strict = false }, show]

  type binding_change =
    | Run
  [@@deriving show]

  let binding_change_of_yojson = function
    | `String "run" -> Result.Ok Run
    | j -> Result.Error ("Event.binding_change_of_yojson: " ^ Json.to_string j)

  type input_type =
    | Keyboard
    | Mouse
  [@@deriving show]

  let input_type_of_yojson = function
    | `String "keyboard" -> Result.Ok Keyboard
    | `String "mouse" -> Result.Ok Mouse
    | j -> Result.Error ("Event.input_type_of_yojson: " ^ Json.to_string j)

  type binding = {
    command: string;
    event_state_mask: string list;
    input_code: int;
    mods: string list option;
    symbol: string option;
    input_type: input_type;
  } [@@deriving of_yojson { strict = false }, show]

  type binding_event_info = {
    change: binding_change;
    binding: binding;
  } [@@deriving of_yojson { strict = false }, show]

  type shutdown_reason =
    | Restart
    | Exit
  [@@deriving show]

  type shutdown_event_info = {
    change : string
  } [@@deriving of_yojson, show]

  type t =
    | Workspace of workspace_event_info
    | Output of output_event_info
    | Mode of mode_event_info
    | Window of window_event_info
    | BarConfig of bar_config_event_info
    | Binding of binding_event_info
    | Shutdown of shutdown_reason
  [@@deriving show]

  let unfold_shut_info sev =
    sev.change
end

(******************************************************************************)

type connection = {
  fd : Lwt_unix.file_descr;
  mutable replies : (Uint32.t * string) list;
  mutable events : (Uint32.t * string) list;
}

let connect () =
  try%lwt
    let%lwt socketpath = Lwt_process.pread ("i3", [|"i3"; "--get-socketpath"|]) in
    let socketpath = String.trim socketpath in
    let fd = Lwt_unix.socket Lwt_unix.PF_UNIX Lwt_unix.SOCK_STREAM 0 in
    let%lwt () = Lwt_unix.connect fd (Lwt_unix.ADDR_UNIX socketpath) in
    Lwt.return { fd; replies = []; events = [] }
  with _ -> raise (Protocol_error No_IPC_socket)

let disconnect conn =
  Lwt_unix.close conn.fd

let magic_bytes = Bytes.of_string "i3-ipc"

let int32_of_bytes =
  match Lwt_sys.byte_order with
  | Lwt_sys.Little_endian -> Uint32.of_bytes_little_endian
  | Lwt_sys.Big_endian -> Uint32.of_bytes_big_endian

let int32_to_bytes =
  match Lwt_sys.byte_order with
  | Lwt_sys.Little_endian -> Uint32.to_bytes_little_endian
  | Lwt_sys.Big_endian -> Uint32.to_bytes_big_endian

let rec bytes_eq ~pos ~len b1 b2 =
  if len = 0 then true
  else if Bytes.get b1 pos <> Bytes.get b2 pos then false
  else bytes_eq ~pos:(pos + 1) ~len:(len - 1) b1 b2

let rec read fd buf ~pos ~len =
  let%lwt n = Lwt_unix.read fd buf pos len in
  if n < len then (
    if n = 0 then raise (Protocol_error Unexpected_eof);
    read fd buf ~pos:(pos + n) ~len:(len - n)
 ) else
    Lwt.return ()

let rec write fd buf ~pos ~len =
  let%lwt n = Lwt_unix.write fd buf pos len in
  if n < len then
    write fd buf ~pos:(pos + n) ~len:(len - n)
  else
    Lwt.return ()

let read_raw_msg conn =
  let header = Bytes.create (6 (* magic *) + 4 (* len *) + 4 (* ty *)) in
  let%lwt () = read conn.fd header ~pos:0 ~len:6 in
  if not (bytes_eq ~pos:0 ~len:6 header magic_bytes) then
    raise (Protocol_error (Bad_magic_string (StdLabels.Bytes.(to_string @@ sub ~pos:0 ~len:6 header))));
  let%lwt () = read conn.fd header ~pos:6 ~len:4 in
  let%lwt () = read conn.fd header ~pos:10 ~len:4 in
  let len = int32_of_bytes header 6 |> Uint32.to_int in
  let ty = int32_of_bytes header 10 in
  let payload = Bytes.create len in
  let%lwt () = read conn.fd payload ~pos:0 ~len:len in
  Lwt.return (ty, Bytes.to_string payload)

let write_raw_msg conn (ty, payload) =
  let payload_len = String.length payload in
  let msg_buf = Bytes.create (6 + 4 + 4 + payload_len) in
  StdLabels.Bytes.blit ~src:magic_bytes ~src_pos:0 ~dst:msg_buf ~dst_pos:0 ~len:6;
  int32_to_bytes (Uint32.of_int payload_len) msg_buf 6;
  int32_to_bytes ty msg_buf 10;
  Bytes.blit_string payload 0 msg_buf 14 payload_len;
  write conn.fd msg_buf ~pos:0 ~len:(Bytes.length msg_buf)

(******************************************************************************)

let event_bit = Uint32.(shift_left one 31)
let ty_mask = Uint32.(lognot event_bit)

let read_next_message conn =
  let%lwt (ty, msg) = read_raw_msg conn in
  (if Uint32.(logand ty event_bit <> zero) then
     conn.events <- (ty, msg) :: conn.events
   else
     conn.replies <- (ty, msg) :: conn.replies);
  Lwt.return ()

let rec next_raw_event conn =
  match conn.events with
  | e::es ->
    conn.events <- es;
    Lwt.return e
  | [] ->
    let%lwt () = read_next_message conn in
    next_raw_event conn

let rec next_reply conn p =
  let rec take_first p = function
    | [] -> None
    | x :: xs ->
      if p x then Some (x, xs)
      else match take_first p xs with
        | None -> None
        | Some (y, ys) -> Some (y, x :: ys)
  in
  match take_first p conn.replies with
  | Some (r, rs) ->
    conn.replies <- rs;
    Lwt.return r
  | None ->
    let%lwt () = read_next_message conn in
    next_reply conn p

let next_reply_with_ty conn ty =
  next_reply conn (fun (ty', _) -> ty = ty')

let send_cmd_with_ty conn ty payload =
  let%lwt () = write_raw_msg conn (ty, payload) in
  let%lwt (_, r) = next_reply_with_ty conn ty in
  Lwt.return r

(******************************************************************************)

let command_ty = Uint32.of_int 0
let workspaces_ty = Uint32.of_int 1
let subscribe_ty = Uint32.of_int 2
let outputs_ty = Uint32.of_int 3
let tree_ty = Uint32.of_int 4
let marks_ty = Uint32.of_int 5
let bar_config_ty = Uint32.of_int 6
let version_ty = Uint32.of_int 7
let binding_modes_ty = Uint32.of_int 8
let config_ty = Uint32.of_int 9
let send_tick_ty = Uint32.of_int 10

let ignore_error = function
  | Result.Ok x -> x
  | Result.Error msg -> raise (Protocol_error (Bad_reply msg))

let handle_reply r of_yojson =
  let%lwt s = r in
  Json.from_string s
  |> of_yojson
  |> ignore_error
  |> Lwt.return

let command conn c =
  handle_reply
    (send_cmd_with_ty conn command_ty c)
    Reply.command_outcome_list_of_yojson

let get_workspaces conn =
  handle_reply
    (send_cmd_with_ty conn workspaces_ty "")
    Reply.workspace_list_of_yojson

let get_outputs conn =
  handle_reply
    (send_cmd_with_ty conn outputs_ty "")
    Reply.output_list_of_yojson

let get_tree conn =
  handle_reply
    (send_cmd_with_ty conn tree_ty "")
    Reply.node_of_yojson

let get_marks conn =
  handle_reply
    (send_cmd_with_ty conn marks_ty "")
    Reply.mark_list_of_yojson

let get_bar_ids conn =
  let%lwt () = write_raw_msg conn (bar_config_ty, "") in
  let%lwt (_, r) = next_reply conn
      (fun (ty, raw) ->
         ty = bar_config_ty &&
         (match Json.from_string raw with
          | `List _ -> true
          | _ -> false
          | exception _ -> false))
  in
  handle_reply (Lwt.return r) Reply.bar_id_list_of_yojson

let get_bar_config conn bar_id =
  let%lwt () = write_raw_msg conn (bar_config_ty, bar_id) in
  let%lwt (_, r) = next_reply conn
      (fun (ty, raw) ->
         ty = bar_config_ty &&
         (match Json.from_string raw with
          | `Assoc _ -> true
          | _ -> false
          | exception _ -> false))
  in
  handle_reply (Lwt.return r) Reply.bar_config_of_yojson

let get_version conn =
  handle_reply
    (send_cmd_with_ty conn version_ty "")
    Reply.version_of_yojson

let get_binding_modes conn =
  handle_reply
    (send_cmd_with_ty conn binding_modes_ty "")
    Reply.binding_modes_of_yojson

let get_config conn =
  let%lwt protocol_reply =
    handle_reply
      (send_cmd_with_ty conn config_ty "")
      Reply.config_of_yojson in
  Lwt.return protocol_reply.Reply.config

let send_tick conn payload =
  let%lwt protocol_reply =
    handle_reply
      (send_cmd_with_ty conn send_tick_ty payload)
      Reply.tick_of_yojson in
  Lwt.return protocol_reply.Reply.tick_success

(******************************************************************************)

type subscription =
  | Workspace
  | Output
  | Mode
  | Window
  | BarConfig
  | Binding
  | Shutdown

let subscription_to_yojson = function
  | Workspace -> `String "workspace"
  | Output -> `String "output"
  | Mode -> `String "mode"
  | Window -> `String "window"
  | BarConfig -> `String "barconfig_update"
  | Binding -> `String "binding"
  | Shutdown -> `String "shutdown"

type subscription_list =
  subscription list [@@deriving to_yojson]

let subscribe conn subs =
  let subs_bytes = Json.to_string (subscription_list_to_yojson subs) in
  handle_reply
    (send_cmd_with_ty conn subscribe_ty subs_bytes)
    Reply.command_outcome_of_yojson

(******************************************************************************)

let event_of_raw_event (ty, payload) =
  let j = Json.from_string payload in
  match Uint32.(logand ty ty_mask |> to_int) with
  | 0 -> Event.Workspace (Event.workspace_event_info_of_yojson j |> ignore_error)
  | 1 -> Event.Output (Event.output_event_info_of_yojson j |> ignore_error)
  | 2 -> Event.Mode (Event.mode_event_info_of_yojson j |> ignore_error)
  | 3 -> Event.Window (Event.window_event_info_of_yojson j |> ignore_error)
  | 4 -> Event.BarConfig (Event.bar_config_event_info_of_yojson j |> ignore_error)
  | 5 -> Event.Binding (Event.binding_event_info_of_yojson j |> ignore_error)
  | 6 -> Event.Shutdown (
    let shutdown_event_info =
      Event.shutdown_event_info_of_yojson j
      |> ignore_error
      |> Event.unfold_shut_info in
    match shutdown_event_info with
    | "restart" -> Restart
    | "exit" -> Exit
    | v -> raise (Protocol_error (Bad_reply v))
  )
  | _ -> raise (Protocol_error (Unknown_type ty))

let next_event conn =
  let%lwt e = next_raw_event conn in
  Lwt.return (event_of_raw_event e)
