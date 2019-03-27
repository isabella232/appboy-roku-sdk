sub Main()
  showChannelSGScreen()
end sub

sub showChannelSGScreen()
  screen = CreateObject("roSGScreen")
  m.port = CreateObject("roMessagePort")
  screen.setMessagePort(m.port)
  scene = screen.CreateScene("SampleScene")
  configureBrazeSdk(screen.getGlobalNode())
  screen.show()

  while(true)
    msg = wait(0, m.port)
    msgType = type(msg)
    if msgType = "roSGScreenEvent"
      if msg.isScreenClosed() then return
    end if
  end while
end sub

sub configureBrazeSdk(globalNode as object)
  config = {}
  config_fields = BrazeConstants().BRAZE_CONFIG_FIELDS
  config[config_fields.API_KEY] = "233c80bd-366c-481a-84af-ebc1247dc1af"
  config[config_fields.ENDPOINT] = "https://sondheim.appboy.com/"
  config[config_fields.HEARTBEAT_FREQ_IN_SECONDS] = 5
  globalNode.addFields({brazeConfig: config})
end sub
