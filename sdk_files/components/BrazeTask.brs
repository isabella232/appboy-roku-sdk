sub init()
  m.port = createObject("roMessagePort")
  m.top.observeField(BrazeConstants().SCENE_GRAPH_EVENTS.BRAZE_API_INVOCATION, m.port)
  m.top.functionName = "setupBrazeSdk"
  m.top.control = "RUN"
end sub

sub setupBrazeSdk()
  config = m.global.brazeConfig
  BrazeInit(config, m.port)
  m.braze = Braze()
  heartbeat_timer = CreateObject("roDateTime")
  heartbeat_start = heartbeat_timer.asseconds()
  heartbeat_timeout = m.global.brazeconfig[BrazeConstants().braze_config_fields.heartbeat_freq_in_seconds]
  while true
    heartbeat_timer.mark()
    heartbeat_current_time = heartbeat_timer.asseconds()
    if heartbeat_current_time - heartbeat_start > heartbeat_timeout
      heartbeat_start = heartbeat_current_time
      m.braze.sessionheartbeat({})
    end if
    msg = wait(0, m.port)
    if msg <> invalid
      msg_type = type(msg)
      if msg_type = "roSGNodeEvent"
        payload = msg.getData()
        method_name = payload.methodName
        method_arguments = payload.arguments
        m.braze[method_name](method_arguments)
      end if
    end if
  end while
end sub
