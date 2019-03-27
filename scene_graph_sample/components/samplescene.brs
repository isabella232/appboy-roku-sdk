sub init()
  m.BrazeTask = createObject("roSGNode", "BrazeTask")
  m.Braze = getBrazeInstance(m.BrazeTask)
  m.buttonGroup = m.top.findNode("sampleButtonGroup")
  m.buttonGroup.buttons = [ "Set User ID", "Send Custom Events and Purchases", "Set Custom and Default Attributes", "Increment Custom Attribute", "Add To Custom Attribute Array"]
  m.buttonGroup.observeField("buttonSelected", "onButtonSelected")
  examplerect = m.buttonGroup.boundingRect()
  centerx = (1280 - examplerect.width) / 2
  centery = (720 - examplerect.height) / 2
  m.buttonGroup.translation = [ centerx, centery ]
  m.buttonGroup.setFocus(true)
  m.userIdLabel = m.top.findNode("userIdLabel")
end sub

sub onButtonSelected()
  button_selected_string = m.buttonGroup.buttons[m.buttonGroup.buttonSelected]
  if button_selected_string = "Set User ID"
    userId = "testroku" + mid(str(rnd(100000)),2)
    m.Braze.setUserId(userId)
    m.userIdLabel.text = "User ID Changed to: " + userId
    m.userIdLabel.visible = true
  else if button_selected_string = "Send Custom Events and Purchases"
    m.Braze.logEvent("event1")
    m.Braze.logEvent("event2", {"stringPropKey1" : "stringPropValue1", "intProp" : 9001})
    m.Braze.logEvent("event3", {"stringPropKey1" : "stringPropValue1", "intProp" : 9001})
    m.Braze.logPurchase("purchase1", "USD", 5.0, 2)
    m.Braze.logPurchase("purchase2", "USD", 5.0, 2, {"stringPropKey1" : "stringPropValue1", "intProp" : 9001})
    m.Braze.logPurchase("purchase3", "USD", 5.0, 2, {"stringPropKey1" : "stringPropValue1", "intProp" : 9001})
  else if button_selected_string = "Set Custom and Default Attributes"
    stringArray = createObject("roArray", 3, true)
    stringArray.Push("string1")
    stringArray.Push("string2")
    stringArray.Push("string3")
    m.Braze.setCustomAttribute("arrayAttribute", stringArray)
    m.Braze.setCustomAttribute("favoriteFood", "lasagna")
    m.Braze.setCustomAttribute("coolness", "high")
    m.Braze.setCustomAttribute("coolness2", "high")
    m.Braze.setCustomAttribute("intAttribute", 5)
    m.Braze.setCustomAttribute("intAttribute2", 25)
    m.Braze.setCustomAttribute("floatAttribute", 3.5)
    m.Braze.setCustomAttribute("floatAttribute2", 4.5)
    m.Braze.setCustomAttribute("boolAttribute", true)
    m.Braze.setCustomAttribute("boolAttribute2", false)
    dateAttribute = CreateObject("roDateTime")
    dateAttribute.fromISO8601String("1992-11-29 00:00:00.000")
    m.Braze.setCustomAttribute("dateAttribute", dateAttribute)
    m.Braze.unsetCustomAttribute("coolness")
    m.Braze.unsetCustomAttribute("coolness2")
    m.Braze.setLocationCustomAttribute("location", 40.25, 50.22)
    m.Braze.setLocationCustomAttribute("location2", 43.25, 53.22)
    m.Braze.setFirstName("First")
    m.Braze.setLastName("Last")
    m.Braze.setEmail("email@mail.com")
    dob = CreateObject("roDateTime")
    dob.fromISO8601String("1990-04-13 00:00:00.000")
    m.Braze.setDateOfBirth(dob)
    m.Braze.setCountry("Mexico")
    m.Braze.setLanguage("es")
    m.Braze.setHomeCity("Manilla")
    m.Braze.setGender("o")
    m.Braze.setPhoneNumber("123456789")
    m.Braze.setEmailSubscriptionState(BrazeConstants().SUBSCRIPTION_STATES.OPTED_IN)
    m.Braze.setPushNotificationSubscriptionState(BrazeConstants().SUBSCRIPTION_STATES.OPTED_IN)
    m.Braze.setAvatarImageUrl("https://pbs.twimg.com/profile_images/1017436259462139904/LeAx7u5v_400x400.jpg")
  else if button_selected_string = "Increment Custom Attribute"
    m.Braze.incrementCustomUserAttribute("numberOfSocks", 3)
  else if button_selected_string = "Add To Custom Attribute Array"
    m.Braze.addToCustomAttributeArray("favoriteColor", "blue")
    m.Braze.addToCustomAttributeArray("favoriteColor", "yellow")
    m.Braze.addToCustomAttributeArray("favoriteColor", "red")
    m.Braze.addToCustomAttributeArray("favoriteColor2", "red")
    m.Braze.removeFromCustomAttributeArray("favoriteColor", "yellow")
    m.Braze.removeFromCustomAttributeArray("favoriteColor2", "red")
  end if
end sub
