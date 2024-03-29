# DarkSky 2.0.0 #

**The Dark Sky service is no longer available, and so this library is no longer supported**

This class provides access to the Dark Sky API provided by [Dark Sky](https://darksky.net/).

Please note that the Dark Sky API is a commercial service. Though the first 1000 API calls made under your API key are free of charge, subsequent calls are billed at a rate of $0.0001 per call. You and your application will not be notified by the library if this occurs, so you may wish to add suitable call-counting code to your application. The usage terms also require the addition of a “Powered by Dark Sky” badge that links to `https://darksky.net/poweredby/` wherever data from the API is displayed.

## Class Usage ##

### Constructor: DarkSky(*apiKey[, debug]*) ###

The constructor requires a Dark Sky API key *(see above)*.

#### Parameters ####

| Parameter | Data&nbsp;Type | Required? | Description |
| --- | --- | --- | --- |
| *apiKey* | String | Yes | Your Dark Sky API key |
| *debug* | Boolean | No | Whether to log extra debugging information (`true`) or not (`false`). Default: `false` |

#### Example ####

```squirrel
#require "DarkSky.agent.lib.nut:2.0.0"

const API_KEY = "<YOUR_DARK_SKY_API_KEY>";

fc <- DarkSky(API_KEY);
```

## Class Methods ##

### forecastRequest(*longitude, latitude[, callback]*) ###

This method sends a [forecast request](https://darksky.net/dev/docs/forecast) to the Dark Sky API for the specified co-ordinates. The request can be made to operate asynchronously or synchronously (blocking).

#### Parameters ####

| Parameter | Data&nbsp;Type | Required? | Description |
| --- | --- | --- | --- |
| *longitude* | Integer, float or string | Yes | The longitude of the location for which you’d like a forecast |
| *latitude* | Integer, float or string | Yes | The latitude of the location for which you’d like a forecast |
| *callback* | Function | No | Function called when the forecast has been received (or an error occurred) |

If you provide a callback function, the request will be made asynchronously and the callback executed with the returned data. Your callback function must include the following parameters:

| Parameter | Data&nbsp;Type | Description |
| --- | --- | --- |
| *error* | String | A human-readable error message error message, or `null` if there was no error |
| *data* | Table | The decoded response from Dark Sky |

If you do not provide a callback function, this call will block until the Dark Sky server responds, or the request times out. The call will return a table:

```json
{ "error" : <string|null>,
  "data"  : <table> }
```

The data returned by the Dark Sky API is complex and is not parsed in any way by the library. However, *data* contains an additional key, *callCount*, which is the number of calls you have made to the Dark Sky API. This is decoded by the library and added to the returned data table.

#### Return Value ####

Table &mdash; the decoded response from Dark Sky, or nothing if *forecastRequest()* is performed asynchronously.

#### Example ####

```squirrel
fc.forecastRequest(myLongitude, myLatitude, function(error, data) {
    if (error) server.error(error);

    if (data) {
        server.log("Weather forecast data received from Dark Sky");
        if ("hourly" in data) {
            if ("data" in data.hourly) {
                // Get second item in array: this is the weather one hour from now
                local item = data.hourly.data[1];
                local sendData = {};
                sendData.cast <- item.icon;
                sendData.temp <- item.apparentTemperature;
                device.send("weather.show.forecast", sendData);

                // Log the output
                local celsius = ((sendData.temp.tofloat() - 32.0) * 5.0) / 9.0;
                local message = "Outlook: " + sendData.cast + ". Temperature: " + format("%.1f", celsius) + "ºC";
                server.log(message);
            }
        }

        if ("callCount" in data) server.log("Current Dark Sky API call tally: " + data.callCount + "/1000");
    }
});
```

### timeMachineRequest(*longitude, latitude, time[, callback]*) ###

This method sends a [time machine request](https://darksky.net/dev/docs/time-machine) (ie. historical weather data) to the Dark Sky API for the specified co-ordinates and time.

#### Parameters ####

| Parameter | Data&nbsp;Type | Required? | Description |
| --- | --- | --- | --- |
| *longitude* | Integer, float or string | Yes | The longitude of the location for which you’d like historical forecast data |
| *latitude* | Integer, float or string | Yes | The latitude of the location for which you’d like historical forecast data |
| *time* | Integer or string | Yes | The time for which you’d like historical forecast data, either a Unix timestamp (Integer) or a string formatted according to [ISO 8601](https://en.wikipedia.org/wiki/ISO_8601) |
| *callback* | Function | No | Function called when the forecast has been received (or an error occurred) |

If you provide a callback function, the request will be made asynchronously and the callback executed with the returned data. Your callback function must include the following parameters:

| Parameter | Data Type | Description |
| --- | --- | --- |
| *err* | String | A human-readable error message error message, or `null` if there was no error |
| *data* | Table | The decoded response from Dark Sky |

If you do not provide a callback function, this call will block until the Dark Sky server responds, or the request times out. The call will return a table:

```json
{ "error" : <string|null>,
  "data"  : <table> }
```

The data returned by the Dark Sky API is complex and is not parsed in any way by the library. However, *data* contains an additional key, *callCount*, which is the number of calls you have made to the Dark Sky API. This is decoded by the library and added to the returned data table.

#### Returns ####

Table &mdash; the decoded response from Dark Sky, or nothing if *timeMachineRequest()* is performed asynchronously.

#### Example ####

```squirrel
local monthAgo = time() - 2592000;
fc.timeMachineRequest(myLongitude, myLatitude, monthAgo, function(error, data) {
    if (error) server.error(error);

    if (data) {
        server.log("Weather forecast data received from Dark Sky");
        if ("hourly" in data) {
            if ("data" in data.hourly) {
                local item = data.hourly.data[0];
                local sendData = {};
                sendData.cast <- item.icon;
                sendData.temp <- item.apparentTemperature;
                device.send("weather.show.forecast", sendData);

                // Log the output
                local celsius = ((sendData.temp.tofloat() - 32.0) * 5.0) / 9.0;
                local message = "Outlook: " + sendData.cast + ". Temperature: " + format("%.1f", celsius) + "ºC";
                server.log(message);
            }
        }

        if ("callCount" in data) server.log("Current Dark Sky API call tally: " + data.callCount + "/1000");
    }
});
```

### getCallCount() ###

Responses returned by Dark Sky contain a running total of the API calls made within the current 24-hour period. Dark Sky begins to charge once the number of daily requests exceeds 1000 requests, so the library retains the current tally on your behalf.

Use this method to read back the most recent value returned by Dark Sky.

**Note** This value is also accessible through the instance’s *callCount* property:

```squirrel
local tally = fc.callCount;
if (tally < 1000) getForecast();
```

The value is also added to the table returned by the above request calls.

#### Returns ####

Integer &mdash; the current API call tally.

#### Example ####

```squirrel
local tally = fc.getCallCount();
if (tally < 1000) getForecast();
```

### setUnits(*units*) ###

This methods allows you to specify the category of units in which the Dark Sky API will return data to your code. It returns the *DarkSky* instance, allowing you to chain *setUnits()* with *setLanguage()* (see below).

#### Parameters ####

| Parameter | Data&nbsp;Type | Required? | Description |
| --- | --- | --- | --- |
| *units* | String | No | A country code (see below) to specify what type of units returned data should be supplied in (Default: `"auto"`) |

Available country codes are: `"us"`, `"si"`, `"ca"`, `"uk"` or `"uk2"`, or `"auto"`. The default is `"auto"`, which selects the most appropriate units based on the supplied location co-ordinates. Please see the Dark Sky API documentation for the [meaning of each setting](https://darksky.net/dev/docs/forecast).

**Note** `"uk"` and `"uk2"` are identical; Dark Sky only supports the latter, but the former is included for the convenience of British coders.

#### Returns ####

The *DarkSky* instance (`this`).

#### Example ####

```squirrel
// Select data in SI units, and weather summaries in German
fc.setUnits("si").setLanguage("de");
```

### setLanguage(*language*) ###

This methods allows you to specify the language in which summaries of weather conditions are returned by the Dark Sky API.

#### Parameters ####

| Parameter | Data&nbsp;Type | Required? | Description |
| --- | --- | --- | --- |
| *language* | String | No | A country code (see below) to specify the language returned data should be supplied in (Default: `"en"`) |

Please see the Dark Sky API documentation for the [full list of supported languages](https://darksky.net/dev/docs/forecast).

#### Returns ####

The *DarkSky* instance (`this`).

#### Example ####

See [*setUnits()*](#setunitsunits), above, for an example of *setLanguage()*’s use.

## Release Notes ##

- 2.0.0
    - Adopt current Electric Imp library naming scheme.
    - Version number now a string.
    - Instantiation parameter errors now throw.
    - Bug fixes:
        - Synchronous operation variables now correctly named. 
        - Prevent null string error.
- 1.0.1
    - Fix uninitialized member property.
- 1.0.0
    - Convert Forecastio 1.1.2 to DarkSky 1.0.0 following Dark Sky rebranding.

## License ##

This class is licensed under the [MIT License](https://github.com/electricimp/DarkSky/blob/master/LICENSE)
