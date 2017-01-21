open Stdint
module Json = Yojson.Safe

let (|?) o x =
  match o with
  | None -> x
  | Some y -> y

(******************************************************************************)

type conn = {
  fd : Lwt_unix.file_descr;
}

type protocol_error =
  | No_IPC_socket
  | Bad_magic_string of string
  | Unexpected_eof
  | Unknown_type of Int32.t
  | Bad_reply of string

exception Protocol_error of protocol_error

let magic_bytes = Bytes.of_string "i3-ipc"

let int32_of_bytes buf =
  match Lwt_sys.byte_order with
  | Lwt_sys.Little_endian -> Int32.of_bytes_little_endian buf 0
  | Lwt_sys.Big_endian -> Int32.of_bytes_big_endian buf 0

let int32_to_bytes i buf offset =
  match Lwt_sys.byte_order with
  | Lwt_sys.Little_endian -> Int32.to_bytes_little_endian i buf offset
  | Lwt_sys.Big_endian -> Int32.to_bytes_big_endian i buf offset

let rec read fd buf offset len =
  let%lwt n = Lwt_unix.read fd buf offset len in
  if n < len then (
    if n = 0 then raise (Protocol_error Unexpected_eof);
    read fd buf (offset + n) (len - n)
  ) else
    Lwt.return ()

let rec write fd buf offset len =
  let%lwt n = Lwt_unix.write fd buf offset len in
  if n < len then
    write fd buf (offset + n) (len - n)
  else
    Lwt.return ()

let read_raw_msg conn =
  let magic = Bytes.create 6 in
  let len_buf = Bytes.create 4 in
  let ty_buf = Bytes.create 4 in
  let%lwt () = read conn.fd magic 0 6 in
  if magic <> magic_bytes then raise (Protocol_error (Bad_magic_string magic));
  let%lwt () = read conn.fd len_buf 0 4 in
  let%lwt () = read conn.fd ty_buf 0 4 in
  let len = int32_of_bytes len_buf |> Int32.to_int in
  let ty = int32_of_bytes ty_buf in
  let payload = Bytes.create len in
  let%lwt () = read conn.fd payload 0 len in
  Lwt.return (ty, Bytes.to_string payload)
  
let write_raw_msg conn (ty, payload) =
  let payload_len = String.length payload in
  let msg_buf = Bytes.create (6 + 4 + 4 + payload_len) in
  StdLabels.Bytes.blit ~src:magic_bytes ~src_pos:0 ~dst:msg_buf ~dst_pos:0 ~len:6;
  int32_to_bytes (Int32.of_int payload_len) msg_buf 6;
  int32_to_bytes ty msg_buf 10;
  Bytes.blit_string payload 0 msg_buf 14 payload_len;
  write conn.fd msg_buf 0 (Bytes.length msg_buf)

(******************************************************************************)

(* type msg = *)
(*   | Command of string *)
(*   | Get_workspaces *)
(*   | Subscribe of string list *)
(*   | Get_outputs *)
(*   | Get_tree *)
(*   | Get_marks *)
(*   | Get_bar_config of string option *)
(*   | Get_version *)

(* let send_message conn msg = *)
(*   let send conn id payload = *)
(*     write_raw_msg conn (Int32.of_int id, payload) in *)
(*   match msg with *)
(*   | Command c -> send conn 0 c *)
(*   | Get_workspaces -> send conn 1 "" *)
(*   | Subscribe sources -> *)
(*     send conn 2 (Json.to_string (`List (List.map (fun s -> `String s) sources))) *)
(*   | Get_outputs -> send conn 3 "" *)
(*   | Get_tree -> send conn 4 "" *)
(*   | Get_marks -> send conn 5 "" *)
(*   | Get_bar_config id -> send conn 6 (id |? "") *)
(*   | Get_version -> send conn 7 "" *)

let event_bit = Int32.(shift_left one 31)
let ty_mask = Int32.(lognot event_bit)

(******************************************************************************)

module Reply = struct

  type command_outcome = {
    success: bool;
    error: (string option [@default None]);
  } [@@deriving of_yojson]

  type rect = {
    x: int;
    y: int;
    width: int;
    height: int;
  } [@@deriving of_yojson]

  type workspace = {
    num: int;
    name: string;
    visible: bool;
    focused: bool;
    urgent: bool;
    rect: rect;
    output: string;
  } [@@deriving of_yojson]

  type output = {
    name: string;
    active: bool;
    current_workspace: string;
    rect: rect;
  } [@@deriving of_yojson]

  type node_type =
    | Root
    | Output
    | Con
    | Floating_con
    | Workspace
    | Dockarea

  let node_type_of_yojson = function
    | `String "root" -> Result.Ok Root
    | `String "output" -> Result.Ok Output
    | `String "con" -> Result.Ok Con
    | `String "floating_con" -> Result.Ok Floating_con
    | `String "workspace" -> Result.Ok Workspace
    | `String "dockarea" -> Result.Ok Dockarea
    | j -> Result.Error (Json.to_string j)

  type node_border =
    | Border_normal
    | Border_none
    | Border_1pixel

  let node_border_of_yojson = function
    | `String "normal" -> Result.Ok Border_normal
    | `String "none" -> Result.Ok Border_none
    | `String "1pixel" -> Result.Ok Border_1pixel
    | j -> Result.Error (Json.to_string j)

  type node_layout =
    | SplitH
    | SplitV
    | Stacked
    | Tabbed
    | Dockarea
    | Output
    | Unknown of string

  let node_layout_of_yojson = function
    | `String "splith" -> Result.Ok SplitH
    | `String "splitv" -> Result.Ok SplitV
    | `String "stacked" -> Result.Ok Stacked
    | `String "tabbed" -> Result.Ok Tabbed
    | `String "dockarea" -> Result.Ok Dockarea
    | `String "output" -> Result.Ok Output
    | `String s -> Result.Ok (Unknown s)
    | j -> Result.Error (Json.to_string j)

  type node = {
    nodes : (node list [@default []]);
    id: int32;
    name: string;
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
  } [@@deriving of_yojson { strict = false } ]

  type mark = string
  type bar_id = string

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

  module Bar_parts_map = Map.Make (struct
      type t = colorable_bar_part
      let compare = compare
    end)

  type bar_colors = string Bar_parts_map.t

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
          Result.Error (Json.to_string j)
      end
    | j -> Result.Error (Json.to_string j)

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
  } [@@deriving of_yojson { strict = false } ]

  type version = {
    major: int;
    minor: int;
    patch: int;
    human_readable: string;
    loaded_config_file_name: string;
  } [@@deriving of_yojson]

  let handle_error = function
    | Result.Ok x -> x
    | Result.Error s -> raise (Protocol_error (Bad_reply s))

  let result_of_command_outcome { success; error } =
    if success then Result.Ok () else Result.Error (error |? "")
end
  
(******************************************************************************)

module Event = struct

end

