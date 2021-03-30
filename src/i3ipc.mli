(** A pure OCaml implementation of the i3 IPC protocol. *)

(** The different errors that may be raised. *)
type protocol_error =
  | No_IPC_socket
  | Bad_magic_string of string
  | Unexpected_eof
  | Unknown_type of Stdint.Uint32.t
  | Bad_reply of string

val pp_protocol_error : Format.formatter -> protocol_error -> unit

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
    primary: bool;
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
    | Border_csd

  type node_layout =
    | SplitH
    | SplitV
    | Stacked
    | Tabbed
    | Dockarea
    | Output
    | Unknown of string

  type x11_window_id = int

  type window_properties = {
    class_: string option;
    instance: string option;
    title: string option;
    transient_for: x11_window_id option;
    window_role: string option;
  }

  type node_id = string

  type fullscreen_mode =
    | No_fullscreen
    | Fullscreened_on_output
    | Fullscreened_globally

  type node = {
    nodes: node list;
    floating_nodes: node list;
    id: node_id;
    name: string option;
    num: int option;
    nodetype: node_type;
    border: node_border;
    current_border_width: int;
    layout: node_layout;
    percent: float option;
    rect: rect;
    window_rect: rect;
    deco_rect: rect;
    geometry: rect;
    window: x11_window_id option;
    window_properties: window_properties option;
    urgent: bool;
    focused: bool;
    focus: node_id list;
    fullscreen_mode: fullscreen_mode;
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

  type binding_modes = string list

  type config = {
    config : string
  }

  (** {3 Pretty-printing} *)

  val pp_command_outcome : Format.formatter -> command_outcome -> unit
  val pp_rect : Format.formatter -> rect -> unit
  val pp_workspace : Format.formatter -> workspace -> unit
  val pp_output : Format.formatter -> output -> unit
  val pp_node_type : Format.formatter -> node_type -> unit
  val pp_node_border : Format.formatter -> node_border -> unit
  val pp_node_layout : Format.formatter -> node_layout -> unit
  val pp_node : Format.formatter -> node -> unit
  val pp_colorable_bar_part : Format.formatter -> colorable_bar_part -> unit
  val pp_bar_colors : Format.formatter -> bar_colors -> unit
  val pp_bar_config : Format.formatter -> bar_config -> unit
  val pp_version : Format.formatter -> version -> unit
  val pp_binding_modes : Format.formatter -> binding_modes -> unit
  val pp_config : Format.formatter -> config -> unit
end

(** Type definitions for the events that can be subscribed to. *)
module Event : sig
  type workspace_change =
    | Focus
    | Init
    | Empty
    | Urgent
    | Reload
    | Rename
    | Restored
    | Move

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

  type shutdown_reason =
    | Restart (** i3 is shutting down due to a restart requested by the user *)
    | Exit    (** i3 is shutting down due to an exit requested by the user *)

  type tick_event_info = {
    first : bool;
    payload : string
  }

  type t =
    | Workspace of workspace_event_info
    (** Sent when the user switches to a different workspace, when a new
        workspace is initialized or when a workspace is removed
        (because the last client vanished). *)

    | Output of output_event_info
    (** Sent when RandR issues a change notification (of either screens,
        outputs, CRTCs or output properties). *)

    | Mode of mode_event_info
    (** Sent whenever i3 changes its binding mode. *)

    | Window of window_event_info
    (** Sent when a client’s window is successfully reparented (that is when i3
        has finished fitting it into a container), when a window received input
        focus or when certain properties of the window have changed. *)

    | BarConfig of bar_config_event_info
    (** Sent when the hidden_state or mode field in the barconfig of any bar
        instance was updated and when the config is reloaded. *)

    | Binding of binding_event_info
    (** Sent when a configured command binding is triggered with the keyboard or
        mouse *)

    | Shutdown of shutdown_reason
    (** Sent when the ipc shuts down because of a restart or exit by user
        command.

      {b Important note:} immediately after the client program receives a
        [Shutdown] event i3 wil close the socket with the client and an
        exception [Protocol_error] will be raised by this library: if you want
        your program survive an i3 restart, you must subscribe to this event and
        handle the subsequent exception. *)

    | Tick of tick_event_info
    (** This event is triggered by a subscription to tick events or by a
        SEND_TICK message. *)

  (** {3 Pretty-printing} *)

  val pp_workspace_change : Format.formatter -> workspace_change -> unit
  val pp_workspace_event_info : Format.formatter -> workspace_event_info -> unit
  val pp_output_change : Format.formatter -> output_change -> unit
  val pp_output_event_info : Format.formatter -> output_event_info -> unit
  val pp_mode_event_info : Format.formatter -> mode_event_info -> unit
  val pp_window_change : Format.formatter -> window_change -> unit
  val pp_window_event_info : Format.formatter -> window_event_info -> unit
  val pp_bar_config_event_info : Format.formatter -> bar_config_event_info -> unit
  val pp_binding_change : Format.formatter -> binding_change -> unit
  val pp_input_type : Format.formatter -> input_type -> unit
  val pp_binding : Format.formatter -> binding -> unit
  val pp_binding_event_info : Format.formatter -> binding_event_info -> unit
  val pp_shutdown_reason : Format.formatter -> shutdown_reason -> unit
  val pp_tick_event_info : Format.formatter -> tick_event_info -> unit
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
  | Shutdown
  | Tick

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

(** Get binding modes of i3. *)
val get_binding_modes : connection -> Reply.binding_modes Lwt.t

(** Get the config file as loaded by i3 most recently. *)
val get_config : connection -> Reply.config Lwt.t

(** Sends a tick event with the specified payload. *)
val send_tick : connection -> string -> bool Lwt.t
