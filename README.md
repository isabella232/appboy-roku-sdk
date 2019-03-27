# Roku SDK

Successful marketing automation is essential to the future of your mobile app. Braze helps you engage your users beyond the download. Visit the following links for details and we'll have you up and running in no time!

- [Developer Guide](https://www.braze.com/docs/developer_guide/home/ "Braze Developer Guide")

## Initial SDK Integration

The Braze Roku SDK will provide you with an API to report information to be used in analytics, segmentation, and engagement,

## Step 1: Add Files

1. Add `BrazeSDK.brs` to your app in the `source` directory.
2. Add `BrazeTask.brs` and `BrazeTask.xml` to your app in the `components` directory.

## Step 2: Add References

Add a reference to `BrazeSDK.brs` in your main scene using the following `script` element:

```
<script type="text/brightscript" uri="pkg:/source/BrazeSDK.brs"/>
```

## Step 3: Configure

Within `main.brs`, set the Braze configuration on the global node:

```
globalNode = screen.getGlobalNode()
config = {}
config_fields = BrazeConstants().BRAZE_CONFIG_FIELDS
config[config_fields.API_KEY] = "YOUR_API_KEY_HERE"
config[config_fields.ENDPOINT] = "YOUR_ENDPOINT_HERE (e.g. https://sdk.iad-01.braze.com/)"
config[config_fields.HEARTBEAT_FREQ_IN_SECONDS] = 5
globalNode.addFields({brazeConfig: config})
```

## Step 4: Initialize Braze

Initialize the Braze instance:

```
m.BrazeTask = createObject("roSGNode", "BrazeTask")
m.Braze = getBrazeInstance(m.BrazeTask)
```

## Basic SDK Integration Complete

Braze should now be collecting data from your application. Please see our public documentation on how to log attributes, events, and purchases to our SDK. Our sample app's scene `samplescene.brs` also contains examples of using the API.

## Additional Reference

The directory `SceneGraphTutorial` contains the sample app (SceneGraphTutorial.zip) from [Roku](https://sdkdocs.roku.com/display/sdkdoc/SceneGraph+Samples "Roku Tutorial App"), with the Braze SDK integrated.
