(** A pure OCaml implementation of the i3 IPC protocol. *)

(** The different errors that may be raised. *)
type protocol_error =
  | No_IPC_socket
  | Bad_magic_string of string
  | Unexpected_eof
  | Unknown_type of Stdint.Uint32.t
  | Bad_reply of string

exception Protocol_error of protocol_error

(** Type definitions for the command replies. *)
module Reply : sig
  type command_outcome = {
    success: bool;
    error: string option;
  }

  type rect = {
    x: int;
    y: int;
    width: int;
    height: int;
  }

  type workspace = {
    num: int;
    name: string;
    visible: bool;
    focused: bool;
    urgent: bool;
    rect: rect;
    output: string;
  }

  type output = {
    name: string;
    active: bool;
    current_workspace: string option;
    rect: rect;
  }

  type node_type =
    | Root
    | Output
    | Con
    | Floating_con
    | Workspace
    | Dockarea

  type node_border =
    | Border_normal
    | Border_none
    | Border_pixel

  type node_layout =
    | SplitH
    | SplitV
    | Stacked
    | Tabbed
    | Dockarea
    | Output
    | Unknown of string

  type node = {
    nodes: node list;
    id: int32;
    name: string option;
    nodetype: node_type;
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
  }

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

  module Bar_parts_map : Map.S
    with type key = colorable_bar_part

  type bar_colors = string Bar_parts_map.t

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
  }

  type version = {
    major: int;
    minor: int;
    patch: int;
    human_readable: string;
    loaded_config_file_name: string;
  }
end

(** Type definitions for the events that can be subscribed to. *)
module Event : sig
  type workspace_change =
    | Focus
    | Init
    | Empty
    | Urgent

  type workspace_event_info = {
    change: workspace_change;
    current: Reply.node option;
    old: Reply.node option;
  }

  type output_change =
    | Unspecified

  type output_event_info = {
    change: output_change;
  }

  type mode_event_info = {
    change: string;
    pango_markup: bool;
  }

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

  type window_event_info = {
    change: window_change;
    container: Reply.node;
  }

  type bar_config_event_info = {
    bar_config: Reply.bar_config;
  }

  type binding_change =
    | Run

  type input_type =
    | Keyboard
    | Mouse

  type binding = {
    command: string;
    event_state_mask: string list;
    input_code: int;
    mods: string list option;
    symbol: string option;
    input_type: input_type;
  }

  type binding_event_info = {
    change: binding_change;
    binding: binding;
  }

  type t =
    | Workspace of workspace_event_info
    | Output of output_event_info
    | Mode of mode_event_info
    | Window of window_event_info
    | BarConfig of bar_config_event_info
    | Binding of binding_event_info
end

(** Type describing a connection to the i3 IPC endpoint. *)
type connection

(** Connect to a running i3 instance. *)
val connect : unit -> connection Lwt.t

(** Close a [connection]. *)
val disconnect : connection -> unit Lwt.t

type subscription =
  | Workspace
  | Output
  | Mode
  | Window
  | BarConfig
  | Binding

(** Subscribe to certain events. *)
val subscribe : connection -> subscription list -> Reply.command_outcome Lwt.t

(** Wait for the next event, among those subscribed to. *)
val next_event : connection -> Event.t Lwt.t

(** Run an i3 command. See {{:
    http://i3wm.org/docs/userguide.html#_list_of_commands }
    http://i3wm.org/docs/userguide.html#_list_of_commands } for a list of valid
    commands. *)
val command : connection -> string -> Reply.command_outcome list Lwt.t

(** Get the list of current workspaces. *)
val get_workspaces : connection -> Reply.workspace list Lwt.t

(** Get the list of current outputs. *)
val get_outputs : connection -> Reply.output list Lwt.t

(** Get the layout tree. i3 uses a tree data-structure to represent the layout
    of windows in a workspace. *)
val get_tree : connection -> Reply.node Lwt.t

(** Get a list of marks (identifiers of containers). *)
val get_marks : connection -> Reply.mark list Lwt.t

(** Get the list of IDs of all configured bars. *)
val get_bar_ids : connection -> Reply.bar_id list Lwt.t

(** Get the configuration of the workspace bar with given ID. *)
val get_bar_config : connection -> Reply.bar_id -> Reply.bar_config Lwt.t

(** Get the version of i3. *)
val get_version : connection -> Reply.version Lwt.t
