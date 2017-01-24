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

  val pp_command_outcome : Format.formatter -> command_outcome -> unit

  type rect = {
    x: int;
    y: int;
    width: int;
    height: int;
  }

  val pp_rect : Format.formatter -> rect -> unit

  type workspace = {
    num: int;
    name: string;
    visible: bool;
    focused: bool;
    urgent: bool;
    rect: rect;
    output: string;
  }

  val pp_workspace : Format.formatter -> workspace -> unit

  type output = {
    name: string;
    active: bool;
    current_workspace: string option;
    rect: rect;
  }

  val pp_output : Format.formatter -> output -> unit

  type node_type =
    | Root
    | Output
    | Con
    | Floating_con
    | Workspace
    | Dockarea

  val pp_node_type : Format.formatter -> node_type -> unit

  type node_border =
    | Border_normal
    | Border_none
    | Border_pixel

  val pp_node_border : Format.formatter -> node_border -> unit

  type node_layout =
    | SplitH
    | SplitV
    | Stacked
    | Tabbed
    | Dockarea
    | Output
    | Unknown of string

  val pp_node_layout : Format.formatter -> node_layout -> unit

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

  val pp_node : Format.formatter -> node -> unit

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

  val pp_colorable_bar_part : Format.formatter -> colorable_bar_part -> unit

  module Bar_parts_map : Map.S
    with type key = colorable_bar_part

  type bar_colors = string Bar_parts_map.t

  val pp_bar_colors : Format.formatter -> bar_colors -> unit

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

  val pp_bar_config : Format.formatter -> bar_config -> unit

  type version = {
    major: int;
    minor: int;
    patch: int;
    human_readable: string;
    loaded_config_file_name: string;
  }

  val pp_version : Format.formatter -> version -> unit
end

(** Type definitions for the events that can be subscribed to. *)
module Event : sig
  type workspace_change =
    | Focus
    | Init
    | Empty
    | Urgent

  val pp_workspace_change : Format.formatter -> workspace_change -> unit

  type workspace_event_info = {
    change: workspace_change;
    current: Reply.node option;
    old: Reply.node option;
  }

  val pp_workspace_event_info : Format.formatter -> workspace_event_info -> unit

  type output_change =
    | Unspecified

  val pp_output_change : Format.formatter -> output_change -> unit

  type output_event_info = {
    change: output_change;
  }

  val pp_output_event_info : Format.formatter -> output_event_info -> unit

  type mode_event_info = {
    change: string;
    pango_markup: bool;
  }

  val pp_mode_event_info : Format.formatter -> mode_event_info -> unit

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

  val pp_window_change : Format.formatter -> window_change -> unit

  type window_event_info = {
    change: window_change;
    container: Reply.node;
  }

  val pp_window_event_info : Format.formatter -> window_event_info -> unit

  type bar_config_event_info = {
    bar_config: Reply.bar_config;
  }

  val pp_bar_config_event_info : Format.formatter -> bar_config_event_info -> unit

  type binding_change =
    | Run

  val pp_binding_change : Format.formatter -> binding_change -> unit

  type input_type =
    | Keyboard
    | Mouse

  val pp_input_type : Format.formatter -> input_type -> unit

  type binding = {
    command: string;
    event_state_mask: string list;
    input_code: int;
    mods: string list option;
    symbol: string option;
    input_type: input_type;
  }

  val pp_binding : Format.formatter -> binding -> unit

  type binding_event_info = {
    change: binding_change;
    binding: binding;
  }

  val pp_binding_event_info : Format.formatter -> binding_event_info -> unit

  type t =
    | Workspace of workspace_event_info
    | Output of output_event_info
    | Mode of mode_event_info
    | Window of window_event_info
    | BarConfig of bar_config_event_info
    | Binding of binding_event_info

  val pp : Format.formatter -> t -> unit
end

(** {2 Connection to i3} *)

(** Type describing a connection to the i3 IPC endpoint. *)
type connection

(** Connect to a running i3 instance. *)
val connect : unit -> connection Lwt.t

(** Close a [connection]. *)
val disconnect : connection -> unit Lwt.t

(** {2 Event subscription} *)

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

(** {2 Commands and queries} *)

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
