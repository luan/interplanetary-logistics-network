-- Installed only in the isolated test copy; call the real registered GUI handler.
remote.add_interface("iln-gui-test", {
  open = function(player_index, entity)
    script.get_event_handler(defines.events.on_gui_opened) {
      player_index = player_index,
      entity = entity,
      gui_type = defines.gui_type.entity,
    }
  end,
})
