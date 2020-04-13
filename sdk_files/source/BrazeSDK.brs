function BrazeConstants() as object
  SDK_DATA = {
    SDK_VERSION : "0.0.1"
  }

  SCENE_GRAPH_EVENTS = {
    BRAZE_API_INVOCATION : "BrazeApiInvocation"
  }

  BRAZE_CONFIG_FIELDS = {
    API_KEY : "api-key",
    ENDPOINT : "endpoint",
    HEARTBEAT_FREQ_IN_SECONDS : "hbfreq"
  }

  BRAZE_STORAGE = {
    CONFIG_SECTION : "braze.section.config",
    CONFIG_TIME_KEY : "config_time",
    CONFIG_ATTRIBUTES_BLACKLIST_KEY: "attributes_blacklist",
    CONFIG_EVENTS_BLACKLIST_KEY: "events_blacklist",
    CONFIG_PURCHASES_BLACKLIST_KEY: "purchases_blacklist",
    CONFIG_MESSAGING_SESSION_TIMEOUT_KEY: "messaging_session_timeout",
    DEVICE_ID_SECTION : "braze.section.device_id",
    DEVICE_ID_KEY : "device_id"
    USER_ID_SECTION : "braze.section.user_id",
    USER_ID_KEY : "user_id"
    SESSION_SECTION : "braze.section.session",
    SESSION_UUID_KEY : "uuid"
    SESSION_START_KEY : "start"
    SESSION_END_KEY : "end"
  }

  BRAZE_EVENT_API_FIELDS = {
    CUSTOM_EVENT_NAME : "n",
    SESSION_END_EVENT_PROPERTIES : "d",
    CUSTOM_EVENT_PROPERTIES : "p",
    PURCHASE_EVENT_PROPERTIES : "pr",
    PRODUCT_ID : "pid",
    CURRENCY_CODE : "c",
    PRICE : "p",
    QUANTITY : "q"
  }

  SUBSCRIPTION_STATES = {
    OPTED_IN : "opted_in",
    SUBSCRIBED : "subscribed",
    UNSUBSCRIBED : "unsubscribed"
  }

  EVENT_TYPES = {
    CUSTOM_EVENT : "ce",
    PURCHASE : "p",
    SESSION_START : "ss",
    SESSION_END : "se",
    ADD_CUSTOM_ATTRIBUTE_ARRAY : "add",
    REMOVE_CUSTOM_ATTRIBUTE_ARRAY : "rem",
    INCREMENT_CUSTOM_ATTRIBUTE : "inc",
    LOCATION_CUSTOM_ATTRIBUTE_ADD: "lcaa"
  }

  return {
    SCENE_GRAPH_EVENTS : SCENE_GRAPH_EVENTS
    SDK_DATA : SDK_DATA
    BRAZE_CONFIG_FIELDS : BRAZE_CONFIG_FIELDS
    BRAZE_STORAGE : BRAZE_STORAGE
    BRAZE_EVENT_API_FIELDS : BRAZE_EVENT_API_FIELDS
    EVENT_TYPES : EVENT_TYPES
    SUBSCRIPTION_STATES : SUBSCRIPTION_STATES
  }
end function

function BrazeInit(config as object, messagePort as object)
  StorageManager = {
    braze_save_data: function(key As String, section As String, value As Dynamic, flush=true as Boolean) as Void
      sec = CreateObject("roRegistrySection", section)
      sec.Write(key, value.ToStr())
      if flush then
        sec.Flush()
      end if
    end function,

    braze_delete_data: function(key As String, section As String, flush=true as Boolean) as Void
      sec = CreateObject("roRegistrySection", section)
      sec.Delete(key)
      if flush then
        sec.Flush()
      end if
    end function,

    braze_read_data: function(key As String, section As String, default=invalid as Dynamic) as Dynamic
      sec = CreateObject("roRegistrySection", section)
      if sec.Exists(key) then
        return sec.Read(key)
      end if
      return default
    end Function,

    braze_read_data_int: function(key As String, section As String, default=0 as Integer) as Integer
      result = m.braze_read_data(key, section, default)
      if type(result) <> "Integer"
        result = result.toInt()
      end if
      return result
    end function,

    braze_read_data_boolean: function(key As String, section As String, default=false as Boolean) as Boolean
      return m.braze_read_data(key, section, default) = true.ToStr()
    end function
  }

  DataProvider = {
    DeviceDataProvider : function() as object
      if m.cachedDeviceInfo = invalid then
        di = CreateObject("roDeviceInfo")
        m.cachedDeviceInfo = {
          model : di.GetModel(),
          ad_tracking_enabled : not di.IsRIDADisabled(),
          roku_ad_id : di.GetRIDA(),
          ' roku_channel_client_id : di.GetChannelClientId(),
          time_zone : di.GetTimeZone(),
          locale : di.GetCurrentLocale(),
          os_version : di.GetVersion()
        }

        ' Add the resolution
        display_size = di.GetDisplaySize()
        if display_size <> invalid then
          heightByWidth = display_size.w.ToStr() + "x" + display_size.h.ToStr()
          m.cachedDeviceInfo["resolution"] = heightByWidth
        end if
      end if
      return m.cachedDeviceInfo
    end function,

    AppDataProvider : function() as object
      if m.cachedAppInfo = invalid then
        m.cachedAppInfo = {
          sdk_version : BrazeConstants().SDK_DATA.SDK_VERSION
          api_key : Braze()._privateApi.config[BrazeConstants().BRAZE_CONFIG_FIELDS.API_KEY]
          endpoint : Braze()._privateApi.config[BrazeConstants().BRAZE_CONFIG_FIELDS.ENDPOINT]
        }
      end if
      return m.cachedAppInfo
    end function,

    DeviceIdProvider : function() as object
      if m.cachedDeviceId = invalid then
        storage = Braze()._privateApi.storage
        stored_device_id = storage.braze_read_data(BrazeConstants().BRAZE_STORAGE.DEVICE_ID_KEY, BrazeConstants().BRAZE_STORAGE.DEVICE_ID_SECTION)
        if stored_device_id = invalid then
          di = CreateObject("roDeviceInfo")
          stored_device_id = di.GetRandomUUID()
          storage.braze_save_data(BrazeConstants().BRAZE_STORAGE.DEVICE_ID_KEY, BrazeConstants().BRAZE_STORAGE.DEVICE_ID_SECTION, stored_device_id)
          logger = Braze()._privateApi.brazeLogger
          logger.debug("Generated Device ID", stored_device_id)
        end if
        m.cachedDeviceId = stored_device_id
      end if
      return m.cachedDeviceId
    end function,

    UserIdProvider : function() as object
      if m.cachedUserId = invalid then
        storage = Braze()._privateApi.storage
        stored_user_id = storage.braze_read_data(BrazeConstants().BRAZE_STORAGE.USER_ID_KEY, BrazeConstants().BRAZE_STORAGE.USER_ID_SECTION)
        if stored_user_id = invalid then
          stored_user_id = ""
        end if
        m.cachedUserId = stored_user_id
      end if
      return m.cachedUserId
    end function,

    SessionIdProvider : function() as object
      if m.cachedSessionId = invalid then
        di = CreateObject("roDeviceInfo")
        session_id = di.GetRandomUUID()
        m.cachedSessionId = session_id
      end if
      return m.cachedSessionId
    end function,

    ConfigProvider : function() as object
      if m.cachedConfig = invalid then
        eventHandler = Braze()._privateApi.eventHandler
        storage = Braze()._privateApi.storage
        utils = Braze()._privateApi.brazeUtils
        m.cachedConfig = {}
        stored_config_time = storage.braze_read_data_int(BrazeConstants().BRAZE_STORAGE.CONFIG_TIME_KEY, BrazeConstants().BRAZE_STORAGE.CONFIG_SECTION)
        config_object = eventHandler.createConfigObject(stored_config_time)
        config_response = parsejson(eventHandler.requestConfig(config_object))
        if config_response = invalid or config_response.config = invalid or config_response.config.time = invalid
          m.cachedConfig.config_time = stored_config_time
          stored_attributes_blacklist = storage.braze_read_data(BrazeConstants().BRAZE_STORAGE.CONFIG_ATTRIBUTES_BLACKLIST_KEY, BrazeConstants().BRAZE_STORAGE.CONFIG_SECTION)
          stored_attributes_blacklist = utils.setToEmptyJSONArrayIfInvalid(stored_attributes_blacklist)
          stored_events_blacklist = storage.braze_read_data(BrazeConstants().BRAZE_STORAGE.CONFIG_EVENTS_BLACKLIST_KEY, BrazeConstants().BRAZE_STORAGE.CONFIG_SECTION)
          stored_events_blacklist = utils.setToEmptyJSONArrayIfInvalid(stored_events_blacklist)
          stored_purchases_blacklist = storage.braze_read_data(BrazeConstants().BRAZE_STORAGE.CONFIG_PURCHASES_BLACKLIST_KEY, BrazeConstants().BRAZE_STORAGE.CONFIG_SECTION)
          stored_purchases_blacklist = utils.setToEmptyJSONArrayIfInvalid(stored_purchases_blacklist)
          m.cachedConfig.attributes_blacklist = parsejson(stored_attributes_blacklist)
          m.cachedConfig.events_blacklist = parsejson(stored_events_blacklist)
          m.cachedConfig.purchases_blacklist = parsejson(stored_purchases_blacklist)
          m.cachedConfig.messaging_session_timeout = storage.braze_read_data_int(BrazeConstants().BRAZE_STORAGE.CONFIG_MESSAGING_SESSION_TIMEOUT_KEY, BrazeConstants().BRAZE_STORAGE.CONFIG_SECTION)
        else
          config_time = config_response.config.time
          storage.braze_save_data(BrazeConstants().BRAZE_STORAGE.CONFIG_TIME_KEY, BrazeConstants().BRAZE_STORAGE.CONFIG_SECTION, config_time)
          config_attributes_blacklist = utils.ifInvalidSetToDefault(config_response.config.attributes_blacklist, [])
          config_events_blacklist = utils.ifInvalidSetToDefault(config_response.config.events_blacklist, [])
          config_purchases_blacklist = utils.ifInvalidSetToDefault(config_response.config.purchases_blacklist, [])
          if config_response.config.messaging_session_timeout <> invalid
            config_messaging_session_timeout = config_response.config.messaging_session_timeout
          else
            config_messaging_session_timeout = 0
          end if
          storage.braze_save_data(BrazeConstants().BRAZE_STORAGE.CONFIG_ATTRIBUTES_BLACKLIST_KEY, BrazeConstants().BRAZE_STORAGE.CONFIG_SECTION, FormatJson(config_attributes_blacklist))
          storage.braze_save_data(BrazeConstants().BRAZE_STORAGE.CONFIG_EVENTS_BLACKLIST_KEY, BrazeConstants().BRAZE_STORAGE.CONFIG_SECTION, FormatJson(config_events_blacklist))
          storage.braze_save_data(BrazeConstants().BRAZE_STORAGE.CONFIG_PURCHASES_BLACKLIST_KEY, BrazeConstants().BRAZE_STORAGE.CONFIG_SECTION, FormatJson(config_purchases_blacklist))
          storage.braze_save_data(BrazeConstants().BRAZE_STORAGE.CONFIG_MESSAGING_SESSION_TIMEOUT_KEY, BrazeConstants().BRAZE_STORAGE.CONFIG_SECTION, FormatJson(config_messaging_session_timeout))
          m.cachedConfig.config_time = config_time
          m.cachedConfig.attributes_blacklist = config_attributes_blacklist
          m.cachedConfig.events_blacklist = config_events_blacklist
          m.cachedConfig.purchases_blacklist = config_purchases_blacklist
          m.cachedConfig.messaging_session_timeout = config_messaging_session_timeout
        end if
      end if
      return m.cachedConfig
    end function
  }

  TimeUtils = {
    getCurrentTimeSeconds : function() as object
      date = CreateObject("roDateTime")
      return date.AsSeconds()
    end function
  }

  BrazeUtils = {
    inArray : function(needle as dynamic, haystack as object) as boolean
      for each thing in haystack
        if thing = needle
            return true
        end if
      end for
      return false
    end function,

    isString : function(input as object) as boolean
      return input <> invalid and GetInterface(input, "ifString") <> invalid
    end function,

    truncateBrazeField : function(input as string) as string
      if not m.isString(input) then
        return invalid
      end if
      if Len(input) > 255 then
        return Left(input, 255)
      end if
      return input
    end function,

    isBool : function(input as object) as boolean
      return input <> invalid and GetInterface(input, "ifBoolean") <> invalid
    end function,

    isFloat : function(input as object) as boolean
      return input <> invalid and (GetInterface(input, "ifFloat") <> invalid or (Type(input) = "roFloat" or Type(input) = "Float"))
    end function,

    isArrayOfStrings : function(input as object) as boolean
      isArray = input <> invalid and (GetInterface(input, "ifArray") <> invalid or Type(input) = "roArray")
      if not isArray then
        return false
      end if
      for each item in input
        if not m.isString(item) then
          return false
        end if
      end for
      return true
    end function,

    isInt : function(input as object) as boolean
      return input <> invalid and (GetInterface(input, "ifInt") <> invalid or Type(input) = "roInt")
    end function,

    setToEmptyJSONArrayIfInvalid: function(input as dynamic) as string
      if input = invalid
        return "[]"
      else
        return input
      end if
    end function,

    ifInvalidSetToDefault: function(input as dynamic, defaultVal as dynamic) as dynamic
      if input = invalid
        return defaultVal
      else
        return input
      end if
    end function
  }

  Logger = {
    debug : function(tag as string, message as dynamic) as void
      m.logMessage(tag, message.ToStr())
    end function,

    logMessage : function(tag as string, message as string) as void
      print "Braze Roku SDK v" + BrazeConstants().SDK_DATA.SDK_VERSION + " - " + tag + " - " + message
    end function
  }

  EventHandler = {
    createEventObject : function(name as string, data={} as object)
      event_payload = {
        "name" : name,
        "data" : data,
        "time" : Braze()._privateApi.timeUtils.getCurrentTimeSeconds(),
        "session_id" : Braze()._privateApi.dataProvider.SessionIdProvider()
      }
      user_id = Braze()._privateApi.dataProvider.UserIdProvider()
      if user_id <> "" then
        event_payload["user_id"] = user_id
      end if
      return event_payload
    end function,

    createCustomEventEvent : function(name as string, properties as object) as object
      event_data = {}
      event_data[BrazeConstants().BRAZE_EVENT_API_FIELDS.CUSTOM_EVENT_NAME] = name
      if properties <> invalid then
        event_data[BrazeConstants().BRAZE_EVENT_API_FIELDS.CUSTOM_EVENT_PROPERTIES] = properties
      end if
      event_object = m.createEventObject(BrazeConstants().EVENT_TYPES.CUSTOM_EVENT, event_data)
      return event_object
    end function,

    createPurchaseEvent : function(product_id as string, currency_code as string, price as double, quantity as integer, properties as object) as object
      event_data = {}
      event_data[BrazeConstants().BRAZE_EVENT_API_FIELDS.PRODUCT_ID] = product_id
      event_data[BrazeConstants().BRAZE_EVENT_API_FIELDS.CURRENCY_CODE] = currency_code
      event_data[BrazeConstants().BRAZE_EVENT_API_FIELDS.PRICE] = price
      event_data[BrazeConstants().BRAZE_EVENT_API_FIELDS.QUANTITY] = quantity
      if properties <> invalid then
        event_data[BrazeConstants().BRAZE_EVENT_API_FIELDS.PURCHASE_EVENT_PROPERTIES] = properties
      end if
      event_object = m.createEventObject(BrazeConstants().EVENT_TYPES.PURCHASE, event_data)
      return event_object
    end function,

    createAttributeObject : function(name as string, properties) as object
      attribute_object = {}
      attribute_object[name] = properties
      user_id = Braze()._privateApi.dataProvider.UserIdProvider()
      if user_id <> "" then
        attribute_object["user_id"] = user_id
      end if
      return attribute_object
    end function,

    createConfigObject : function(config_time as Integer) as object
      config_object = {}
      config_object["config"] = {config_time: config_time}
      return config_object
    end function,

    createIncrementCustomAttributeEvent: function(key as string, value as Integer) as object
      event_data = {}
      event_data.key = key
      event_data.value = value
      event_object = m.createEventObject(BrazeConstants().EVENT_TYPES.INCREMENT_CUSTOM_ATTRIBUTE, event_data)
      return event_object
    end function,

    createSetLocationCustomAttributeEvent: function(key as string, lat as Double, lon as Double) as object
      event_object = m.createEventObject(BrazeConstants().EVENT_TYPES.LOCATION_CUSTOM_ATTRIBUTE_ADD, { key : key, latitude : lat, longitude : lon})
      return event_object
    end function,

    createAddToCustomAttributeArrayEvent: function(key as string, value as string) as object
      event_data = {}
      event_data.key = key
      event_data.value = value
      event_object = m.createEventObject(BrazeConstants().EVENT_TYPES.ADD_CUSTOM_ATTRIBUTE_ARRAY, event_data)
      return event_object
    end function,

    createRemoveFromCustomAttributeArrayEvent: function(key as string, value as string) as object
      event_data = {}
      event_data.key = key
      event_data.value = value
      event_object = m.createEventObject(BrazeConstants().EVENT_TYPES.REMOVE_CUSTOM_ATTRIBUTE_ARRAY, event_data)
      return event_object
    end function,

    logEvent : function(event_object as object) as void
      json = {
        "events": [event_object]
      }
      required_fields = Braze()._privateApi.networkUtil.generateRequiredRequestFields()
      json.append(required_fields)
      endpoint = Braze()._privateApi.config[BrazeConstants().BRAZE_CONFIG_FIELDS.ENDPOINT] + "api/v3/data"
      server_response = Braze()._privateApi.networkUtil.postToUrl(endpoint, json)
    end function,

    logAttribute : function(attribute_object as object) as void
      json = {
        "attributes": [attribute_object]
      }
      required_fields = Braze()._privateApi.networkUtil.generateRequiredRequestFields()
      json.append(required_fields)
      endpoint = Braze()._privateApi.config[BrazeConstants().BRAZE_CONFIG_FIELDS.ENDPOINT] + "api/v3/data"
      server_response = Braze()._privateApi.networkUtil.postToUrl(endpoint, json)
    end function,

    requestConfig : function(config_object as object)
      json = {
        "respond_with": config_object
      }
      required_fields = Braze()._privateApi.networkUtil.generateRequiredRequestFields()
      json.append(required_fields)
      endpoint = Braze()._privateApi.config[BrazeConstants().BRAZE_CONFIG_FIELDS.ENDPOINT] + "api/v3/data"
      server_response = Braze()._privateApi.networkUtil.postToUrl(endpoint, json)
      return server_response
    end function
  }

  NetworkUtil = {
    postToUrl : function(url as string, postJson as object) as object
      request = CreateObject("roUrlTransfer")
      port = CreateObject("roMessagePort")
      request.SetPort(port)
      request.SetCertificatesFile("common:/certs/ca-bundle.crt")
      request.InitClientCertificates()
      request.SetUrl(url)
      request.AddHeader("Content-Type", "application/json")
      request.AddHeader("Accept-Encoding", "deflate/gzip")
      request.enableEncodings(true)
      request.AddHeader("X-Braze-Api-Key", Braze()._privateApi.config[BrazeConstants().BRAZE_CONFIG_FIELDS.API_KEY])
      if (request.AsyncPostFromString(FormatJson(postJson)))
          while (true)
              msg = wait(0, port)
              if (type(msg) = "roUrlEvent")
                code = msg.GetResponseCode()
                return msg.getString()
              end if
              if (msg = invalid)
                request.AsyncCancel()
                return invalid
              end if
          end while
      end if
      return invalid
    end function,


    generateRequiredRequestFields : function() as object
      request_fields = {}
      device_object = Braze()._privateApi.dataProvider.DeviceDataProvider()
      app_object = Braze()._privateApi.dataProvider.AppDataProvider()
      current_time = Braze()._privateApi.timeUtils.getCurrentTimeSeconds()
      device_id = Braze()._privateApi.dataProvider.DeviceIdProvider()
      request_fields.append(app_object)
      request_fields.append({
        "time" : current_time,
        "device_id" : device_id,
        "device" : device_object
      })
      return request_fields
    end function
  }

  brazePublicApi = {
    logEvent:function(args as object) as void
      m._privateApi.brazeLogger.debug("logging args", FormatJson(args))
      event_name = m._privateApi.brazeUtils.truncateBrazeField(args[BrazeConstants().BRAZE_EVENT_API_FIELDS.CUSTOM_EVENT_NAME])
      events_blacklist = m._privateApi.dataProvider.configprovider().events_blacklist
      if m._privateApi.brazeUtils.inArray(event_name, events_blacklist)
        m._privateApi.brazeLogger.debug("blacklist", event_name)
        return
      end if
      event_properties = args[BrazeConstants().BRAZE_EVENT_API_FIELDS.CUSTOM_EVENT_PROPERTIES]
      event_object = m._privateApi.eventHandler.createCustomEventEvent(event_name, event_properties)
      m._privateApi.eventHandler.logEvent(event_object)
    end function,

    logPurchase:function(args as object) as void
      m._privateApi.brazeLogger.debug("logging args for purchase", FormatJson(args))
      product_id = Braze()._privateApi.brazeUtils.truncateBrazeField(args[BrazeConstants().BRAZE_EVENT_API_FIELDS.PRODUCT_ID])
      purchases_blacklist = m._privateApi.dataProvider.configprovider().purchases_blacklist
      if m._privateApi.brazeUtils.inArray(product_id, purchases_blacklist)
        m._privateApi.brazeLogger.debug("blacklist", product_id)
        return
      end if
      currency_code = args[BrazeConstants().BRAZE_EVENT_API_FIELDS.CURRENCY_CODE]
      price = args[BrazeConstants().BRAZE_EVENT_API_FIELDS.PRICE]
      quantity = args[BrazeConstants().BRAZE_EVENT_API_FIELDS.QUANTITY]
      event_properties = args[BrazeConstants().BRAZE_EVENT_API_FIELDS.PURCHASE_EVENT_PROPERTIES]
      event_object = m._privateApi.eventHandler.createPurchaseEvent(product_id, currency_code, price, quantity, event_properties)
      m._privateApi.eventHandler.logEvent(event_object)
    end function,

    setLocationCustomAttribute:function(args as object) as void
      m._privateApi.brazeLogger.debug("logging args for location custom attribute", FormatJson(args))
      key = Braze()._privateApi.brazeUtils.truncateBrazeField(args.key)
      if m._privateApi.brazeUtils.inArray(key, m._privateApi.dataProvider.configprovider().attributes_blacklist)
        m._privateApi.brazeLogger.debug("blacklist", key)
        return
      end if
      lat = args.lat
      lon = args.lon
      if key <> invalid and lat <> invalid and lon <> invalid and lat >= -90 and lat <= 90 and lon >= -180 and lon <= 180
        event_object = m._privateApi.eventHandler.createSetLocationCustomAttributeEvent(key, lat, lon)
        m._privateApi.eventHandler.logEvent(event_object)
      end if
    end function,

    incrementCustomUserAttribute:function(args as object) as void
      m._privateApi.brazeLogger.debug("logging args", FormatJson(args))
      key = Braze()._privateApi.brazeUtils.truncateBrazeField(args.key)
      if m._privateApi.brazeUtils.inArray(key, m._privateApi.dataProvider.configprovider().attributes_blacklist)
        m._privateApi.brazeLogger.debug("blacklist", key)
        return
      end if
      value = args.value
      if key <> invalid and value <> invalid
        event_object = m._privateApi.eventHandler.createIncrementCustomAttributeEvent(key, value)
        m._privateApi.eventHandler.logEvent(event_object)
      end if
    end function,

    addToCustomAttributeArray:function(args as object) as void
      m._privateApi.brazeLogger.debug("logging args", FormatJson(args))
      key = Braze()._privateApi.brazeUtils.truncateBrazeField(args.key)
      if m._privateApi.brazeUtils.inArray(key, m._privateApi.dataProvider.configprovider().attributes_blacklist)
        m._privateApi.brazeLogger.debug("blacklist", key)
        return
      end if
      value = Braze()._privateApi.brazeUtils.truncateBrazeField(args.value)
      if key <> invalid and value <> invalid
        event_object = m._privateApi.eventHandler.createAddToCustomAttributeArrayEvent(key, value)
        m._privateApi.eventHandler.logEvent(event_object)
      end if
    end function,

    removeFromCustomAttributeArray:function(args as object) as void
      m._privateApi.brazeLogger.debug("logging args for remove from custom attribute array", FormatJson(args))
      key = Braze()._privateApi.brazeUtils.truncateBrazeField(args.key)
      if m._privateApi.brazeUtils.inArray(key, m._privateApi.dataProvider.configprovider().attributes_blacklist)
        m._privateApi.brazeLogger.debug("blacklist", key)
        return
      end if
      value = Braze()._privateApi.brazeUtils.truncateBrazeField(args.value)
      if key <> invalid and value <> invalid
        event_object = m._privateApi.eventHandler.createRemoveFromCustomAttributeArrayEvent(key, value)
        m._privateApi.eventHandler.logEvent(event_object)
      end if
    end function,

    setCustomAttribute:function(args as object) as void
      m._privateApi.brazeLogger.debug("logging args", FormatJson(args))
      key = Braze()._privateApi.brazeUtils.truncateBrazeField(args.key)
      if m._privateApi.brazeUtils.inArray(key, m._privateApi.dataProvider.configprovider().attributes_blacklist)
        m._privateApi.brazeLogger.debug("blacklist", key)
        return
      end if
      value = args.value
      if key <> invalid and (value = invalid or Braze()._privateApi.brazeUtils.isString(value) or Braze()._privateApi.brazeUtils.isInt(value) or Braze()._privateApi.brazeUtils.isFloat(value) or Braze()._privateApi.brazeUtils.isBool(value) or Braze()._privateApi.brazeUtils.isArrayOfStrings(value))
        properties = {}
        if Braze()._privateApi.brazeUtils.isString(value) then
          value = Braze()._privateApi.brazeUtils.truncateBrazeField(args.value)
        end if
        if Braze()._privateApi.brazeUtils.isArrayOfStrings(value) then
          stringArray = createObject("roArray", value.Count(), true)
          for each item in value
            stringArray.Push(Braze()._privateApi.brazeUtils.truncateBrazeField(item))
          end for
          value = stringArray
        end if
        properties[key] = value
        attribute_object = m._privateApi.eventHandler.createAttributeObject("custom", properties)
        m._privateApi.eventHandler.logAttribute(attribute_object)
      end if
    end function,

    setStringAttribute:function(args as object) as void
      m._privateApi.brazeLogger.debug("logging args for string attribute", FormatJson(args))
      key = args.key
      value = Braze()._privateApi.brazeUtils.truncateBrazeField(args.value)
      if value <> invalid
        attribute_object = m._privateApi.eventHandler.createAttributeObject(key, value)
        m._privateApi.eventHandler.logAttribute(attribute_object)
      end if
    end function,

    sessionStart:function(args as object) as void
      m._privateApi.brazeLogger.debug("session starting", FormatJson(args))
      storage = Braze()._privateApi.storage
      session_uuid = m._privateapi.dataprovider.sessionidprovider()
      storage.braze_save_data(BrazeConstants().BRAZE_STORAGE.SESSION_UUID_KEY, BrazeConstants().BRAZE_STORAGE.SESSION_SECTION, session_uuid)
      storage.braze_save_data(BrazeConstants().BRAZE_STORAGE.SESSION_START_KEY, BrazeConstants().BRAZE_STORAGE.SESSION_SECTION, m._privateapi.timeutils.getcurrenttimeseconds())
      event_object = m._privateApi.eventHandler.createEventObject(BrazeConstants().EVENT_TYPES.SESSION_START)
      m._privateApi.eventHandler.logEvent(event_object)
      m._privateapi.dataprovider.configprovider()
    end function,

    sessionHeartBeat:function(args as object) as void
      m._privateApi.brazeLogger.debug("session heart beat", FormatJson(args))
      storage = Braze()._privateApi.storage
      storage.braze_save_data(BrazeConstants().BRAZE_STORAGE.SESSION_END_KEY, BrazeConstants().BRAZE_STORAGE.SESSION_SECTION, m._privateapi.timeutils.getcurrenttimeseconds())
    end function,

    sessionEnd:function(args as object) as void
      storage = m._privateApi.storage
      previous_session = storage.braze_read_data(BrazeConstants().BRAZE_STORAGE.SESSION_UUID_KEY, BrazeConstants().BRAZE_STORAGE.SESSION_SECTION)
      if previous_session <> invalid
        m._privateApi.brazeLogger.debug("ending session", FormatJson(args))
        start_time = storage.braze_read_data_int(BrazeConstants().BRAZE_STORAGE.SESSION_START_KEY, BrazeConstants().BRAZE_STORAGE.SESSION_SECTION)
        end_time = storage.braze_read_data_int(BrazeConstants().BRAZE_STORAGE.SESSION_END_KEY, BrazeConstants().BRAZE_STORAGE.SESSION_SECTION)
        duration = 0
        if start_time <> invalid and end_time <> invalid
          duration = end_time - start_time
        end if
        data = {}
        data[BrazeConstants().BRAZE_EVENT_API_FIELDS.SESSION_END_EVENT_PROPERTIES] = duration
        event_object = m._privateApi.eventHandler.createEventObject(BrazeConstants().EVENT_TYPES.SESSION_END, data)
        m._privateApi.eventHandler.logEvent(event_object)
        'delete UUID key and times
        storage.braze_delete_data(BrazeConstants().BRAZE_STORAGE.SESSION_UUID_KEY, BrazeConstants().BRAZE_STORAGE.SESSION_SECTION)
        storage.braze_delete_data(BrazeConstants().BRAZE_STORAGE.SESSION_START_KEY, BrazeConstants().BRAZE_STORAGE.SESSION_SECTION)
        storage.braze_delete_data(BrazeConstants().BRAZE_STORAGE.SESSION_END_KEY, BrazeConstants().BRAZE_STORAGE.SESSION_SECTION)
      else
        m._privateApi.brazeLogger.debug("no previous session to end", FormatJson(args))
      end if
    end function,

    setUserId:function(args as object) as void
      m._privateApi.brazeLogger.debug("setting user id", FormatJson(args))
      user_id = args["user_id"]
      storage = m._privateApi.storage
      storage.braze_save_data(BrazeConstants().BRAZE_STORAGE.USER_ID_KEY, BrazeConstants().BRAZE_STORAGE.USER_ID_SECTION, user_id)
      m._privateapi.dataprovider.cachedUserId = user_id
    end function
  }

  brazePrivateApi = {
    config : config
    storage : StorageManager
    dataProvider : DataProvider
    timeUtils : TimeUtils
    networkUtil : NetworkUtil
    brazeLogger : Logger
    eventHandler : eventHandler
    brazeUtils : BrazeUtils
  }

  brazePublicApi.append({_privateApi : brazePrivateApi})
  getGlobalAA().brazeInstance = brazePublicApi
end function

' Construct a braze SDK object
function Braze() as object
  if getGlobalAA().brazeInstance = invalid then
    print "BrazeInit not called beforehand"
  end if
  return getGlobalAA().brazeInstance
end function

function getBrazeInstance(task as object) as object
  brazeInstance = {
    brazeTask: task,

    logEvent: function(event_name as string, event_properties = invalid as object) as void
      args = {}
      args[BrazeConstants().BRAZE_EVENT_API_FIELDS.CUSTOM_EVENT_NAME] = event_name
      args[BrazeConstants().BRAZE_EVENT_API_FIELDS.CUSTOM_EVENT_PROPERTIES] = event_properties
      m.callInstanceMethod("logEvent", args)
    end function,

    logPurchase: function(product_id as String, currency_code as String, price as Double, quantity as Integer, event_properties = invalid as object) as void
      args = {}
      args[BrazeConstants().BRAZE_EVENT_API_FIELDS.PRODUCT_ID] = product_id
      args[BrazeConstants().BRAZE_EVENT_API_FIELDS.CURRENCY_CODE] = currency_code
      args[BrazeConstants().BRAZE_EVENT_API_FIELDS.PRICE] = price
      args[BrazeConstants().BRAZE_EVENT_API_FIELDS.QUANTITY] = quantity
      args[BrazeConstants().BRAZE_EVENT_API_FIELDS.PURCHASE_EVENT_PROPERTIES] = event_properties
      m.callInstanceMethod("logPurchase", args)
    end function,

    setCustomAttribute: function(key as String, value as Object) as void
      if value <> invalid and (GetInterface(value, "ifDateTime") <> invalid or Type(value) = "roDateTime") then
        m.callInstanceMethod("setCustomAttribute", { key : key, value : value.ToISOString()})
      else
        m.callInstanceMethod("setCustomAttribute", { key : key, value : value })
      end if
    end function,

    unsetCustomAttribute: function(key as String) as void
      m.callInstanceMethod("setCustomAttribute", { key : key, value : invalid })
    end function,

    setLocationCustomAttribute: function(key as String, lat as Double, lon as Double) as void
      m.callInstanceMethod("setLocationCustomAttribute", { key : key, lat : lat, lon : lon })
    end function,

    incrementCustomUserAttribute: function(key as String, value as Integer) as void
      m.callInstanceMethod("incrementCustomUserAttribute", { key : key, value : value })
    end function,

    addToCustomAttributeArray: function(key as String, value as String) as void
      m.callInstanceMethod("addToCustomAttributeArray", { key : key, value : value })
    end function,

    removeFromCustomAttributeArray: function(key as String, value as String) as void
      m.callInstanceMethod("removeFromCustomAttributeArray", { key : key, value : value })
    end function,

    setUserId: function(userId as String) as void
      m.callInstanceMethod("setUserId", { user_id : userId })
    end function,

    setFirstName: function(name as String) as void
      m.callInstanceMethod("setStringAttribute", { key : "first_name", value : name })
    end function,

    setLastName: function(name as String) as void
      m.callInstanceMethod("setStringAttribute", { key : "last_name", value : name })
    end function,

    setEmail: function(email as String) as void
      m.callInstanceMethod("setStringAttribute", { key : "email", value : email })
    end function,

    setDateOfBirth: function(dob as Object) as void
      if dob <> invalid and (GetInterface(dob, "ifDateTime") <> invalid or Type(dob) = "roDateTime") then
        m.callInstanceMethod("setStringAttribute", { key : "dob", value : dob.ToISOString()})
      end if
    end function,

    setCountry: function(country as String) as void
      m.callInstanceMethod("setStringAttribute", { key : "country", value : country })
    end function,

    setLanguage: function(language as String) as void
      m.callInstanceMethod("setStringAttribute", { key : "language", value : language })
    end function,

    setHomeCity: function(homeCity as String) as void
      m.callInstanceMethod("setStringAttribute", { key : "home_city", value : homeCity })
    end function,

    setGender: function(gender as String) as void
      m.callInstanceMethod("setStringAttribute", { key : "gender", value : gender })
    end function,

    setPhoneNumber: function(number as String) as void
      m.callInstanceMethod("setStringAttribute", { key : "phone", value : number })
    end function,

    setEmailSubscriptionState: function(subscriptionState = BrazeConstants().SUBSCRIPTION_STATES.UNSUBSCRIBED) as void
      m.callInstanceMethod("setStringAttribute", { key : "email_subscribe", value : subscriptionState })
    end function,

    setPushNotificationSubscriptionState: function(subscriptionState = BrazeConstants().SUBSCRIPTION_STATES.UNSUBSCRIBED) as void
      m.callInstanceMethod("setStringAttribute", { key : "push_subscribe", value : subscriptionState })
    end function,

    setAvatarImageUrl: function(avatarImageUrl as String) as void
      m.callInstanceMethod("setStringAttribute", { key : "image_url", value : avatarImageUrl })
    end function,

    callInstanceMethod: function(methodName as String, args as Object) as void
      payload = {}
      payload.methodName = methodName
      payload.arguments = args
      m.brazeTask[BrazeConstants().SCENE_GRAPH_EVENTS.BRAZE_API_INVOCATION] = payload
    end function,
  }

  brazeInstance.callInstanceMethod("sessionEnd", {})
  brazeInstance.callInstanceMethod("sessionStart", {})
  return brazeInstance
end function
