class DarkSky {

    // This class allows you to make one of two possible calls to DarkSky’s
    // Dark Sky API, ie. forecast requests and time-machine requests. For
    // more information, see https://darksky.net/dev/docs
    // Access to the API is controlled by key. Register for developer access
    // here: https://darksky.net/dev/register

    // Note: this class does not parse the incoming data, which is highly complex.
    // It is up to your application to extract the data you require

    // Written by Tony Smith (@smittytone)
    // Copyright Electric Imp, Inc. 2016-18
    // License: MIT

    static VERSION = "2.0.0";
    static FORECAST_URL = "https://api.darksky.net/forecast/";

    _apikey = null;
    _units = null;
    _lang = null;
    _debug = false;

    constructor (key = null, debug = false) {
        // Object constructor
        // PARAMETERS
        //   1. DarkSky API Key as a string (required)
        //   2. Debugging flag (optional; default: false)
        // RETURNS
        //   DarkSky instance, or throws on error

        /// Check for instantiation parameter errors
        if (imp.environment() != ENVIRONMENT_AGENT) throw "DarkSky class must be instantiated by the agent";
        if (key == "" || key = null) throw "DarkSky class requires an API key";
        if (typeof key != "string") throw "DarkSky class requires an API key supplied as a string";

        // Set instance properties
        if (typeof debug != "bool") debug = false;
        _debug = debug;
        _units = "auto";
        _apikey = key;
    }

    function forecastRequest(longitude = 999.0, latitude = 999.0, callback = null) {
        // Make a request for future weather data
        // PARAMETERS
        //   1. Longitude of location for which a forecast is required
        //   2. Latitude of location for which a forecast is required
        //   3. Optional synchronous operation callback
        // RETURNS
        //   If callback is null, the function returns a table with key 'response'
        //   If callback is not null, the function returns nothing
        //   If there is an error, the function returns a table with key 'err'

        // Check the supplied co-ordinates
        if (!_checkCoords(longitude, latitude, "forecastRequest")) {
            if (callback) {
                callback("Co-ordinate error", null);
                return null;
            } else {
                return {"err": "Co-ordinate error"};
            }
        }

        // Co-ordinates good, so get a forecast
        local url = FORECAST_URL + _apikey + "/" + format("%.6f", latitude) + "," + format("%.6f", longitude);
        url = _addOptions(url);
        return _sendRequest(http.get(url), callback);
    }

    function timeMachineRequest(longitude = 999.0, latitude = 999.0, time = null, callback = null) {
        // Make a request for historical weather data
        // PARAMETERS
        //   1. Longitude of location for which a forecast is required
        //   2. Latitude of location for which a forecast is required
        //   3. A Unix time or ISO 1601-formatted string
        //   4. Optional synchronous operation callback
        // RETURNS
        //   If callback is null, the function returns a table with key 'response'
        //   If callback is not null, the function returns nothing
        //   If there is an error, the function returns a table with key 'err'

        // Check the supplied co-ordinates
        if (!_checkCoords(longitude, latitude, "timeMachineRequest")) {
            if (callback) {
                callback("Co-ordinate error", null);
                return null;
            } else {
                return {"err": "Co-ordinate error"};
            }
        }

        // Check the supplied co-ordinates
        if (time == null || time.tostring().len() == 0) {
            if (_debug) server.error("DarkSky.timeMachineRequest() requires a valid time parameter");
            return {"err": "Timestamp error"};
        }

        local timeString;
        if (typeof time == "integer" || typeof time == "float") {
            timeString = time.tostring();
        } else if (typeof time == "string") {
            timeString = time;
        } else {
            if (_debug) server.error("DarkSky.timeMachineRequest() requires a valid time parameter");
            return {"err": "Timestamp error"};
        }

        // Co-ordinates good, so get the historical data
        local url = FORECAST_URL + _apikey + "/" + format("%.6f", latitude) + "," + format("%.6f", longitude) + "," + timeString;
        url = _addOptions(url);
        return _sendRequest(http.get(url), callback);
    }

    function setUnits(units = "auto") {
        // Specify the preferred weather report's units
        // PARAMETERS
        //   1. Country code indicating the type of units (default: auto)
        // RETURNS
        //   The instance
        local types = ["us", "si", "ca", "uk", "uk2", "auto"];
        local match = false;
        units = units.tolower();
        foreach (type in types) {
            if (units == type) {
                match = true;
                break;
            }
        }

        if (!match) {
            if (_debug) server.error("DarkSky.setUnits() incorrect units option selected (" + units + "); using default value (auto)");
            units = "auto";
        }

        if (units == "uk") units = "uk2";
        _units = units;
        if (_debug) server.log("DarkSky units selected: " + _units);
        return this;
    }

    function setLanguage(language = "en") {
        // Specify the preferred weather report's language
        // PARAMETERS
        //   1. Country code indicating the language (default: English)
        // RETURNS
        //   The instance
        local types = ["ar", "az", "be", "bs", "cs", "de", "el", "en", "es", "fr", "hr",
                       "hu", "id", "it", "is", "kw", "nb", "nl", "pl", "pt", "ru", "sk",
                       "sr", "sv", "tet", "tr", "uk", "x-pig-latin", "zh", "zh-tw"];
        local match = false;
        language = language.tolower();
        foreach (type in types) {
            if (language == type) {
                match = true;
                break;
            }
        }

        if (!match) {
            if (_debug) server.error("DarkSky.setLanguage() incorrect language option selected (" + language + "); using default value (en)");
            language = "en";
        }

        _lang = language;
        if (_debug) server.log("DarkSky language selected: " + _lang);
        return this;
    }

    // ********** PRIVATE FUNCTIONS - DO NOT CALL **********

    function _sendRequest(req, cb) {
        if (cb) {
            req.sendasync(function(resp) {
                local err, data, count;
                if (resp.statuscode != 200) {
                    err = format("Unable to retrieve forecast data (code: %i)", resp.statuscode);
                } else {
                    try {
                        data = http.jsondecode(resp.body);
                    } catch(exp) {
                        err = "Unable to decode data received from Dark Sky: " + exp;
                    }
                }

                // Add daily API request count to 'data'
                count = _getCallCount(resp);
                if (count != -1) data.callCount <- count;

                cb(err, data);
            }.bindenv(this));
            return null;
        } else {
            local resp = req.sendsync();
            local err, data, count, returnTable;
            if (resp.statuscode != 200) {
                err = format("Unable to retrieve forecast data (code: %i)", response.statuscode);
            } else {
                try {
                    data = http.jsondecode(response.body);
                } catch(exp) {
                    err = "Unable to decode data received from Dark Sky: " + exp;
                }
            }

            // Add daily API request count to 'data'
            count = _getCallCount(resp);
            if (count != -1) data.callCount <- count;

            // Create table of returned data
            returnTable.err <- err;
            returnTable.data <- data;
            return returnTable;
        }
    }

    function _getCallCount(resp) {
        // Extract daily API request count from Dark Sky response header
        if ("headers" in resp) {
            if ("x-forecast-api-calls" in resp.headers) {
                local a = resp.headers["x-forecast-api-calls"];
                return a.tointeger();
            }
        }
        return -1;
    }

    function _checkCoords(longitude = 999.0, latitude = 999.0, caller = "function") {
        // Check that valid co-ords have been supplied
        if (typeof longitude != "float") {
            try {
                longitude = longitude.tofloat();
            } catch (err) {
                if (_debug) server.error("DarkSky." + caller + "() can't process supplied longitude value");
                return false;
            }
        }

        if (typeof latitude != "float") {
            try {
                latitude = latitude.tofloat();
            } catch (err) {
                if (_debug) server.error("DarkSky." + caller + "() can't process supplied latitude value");
                return false;
            }
        }

        if (longitude == 999.0 || latitude == 999.0) {
            if (_debug) server.error("DarkSky." + caller + "() requires valid latitude/longitude co-ordinates");
            return false;
        }

        if (latitude > 90.0 || latitude < -90.0) {
            if (_debug) server.error("DarkSky." + caller + "() requires valid a latitude co-ordinate");
            return false;
        }

        if (longitude > 180.0 || longitude < -180.0) {
            if (_debug) server.error("DarkSky." + caller + "() requires valid a latitude co-ordinate");
            return false;
        }

        return true;
    }

    function _addOptions(baseurl = "") {
        // Add URL-encoded options to the request URL
        local opts = "?units=" + _units;
        if (_lang) opts = opts + "&lang=" + _lang;
        return (baseurl + opts);
    }
}
