class DarkSky {

    // This class allows you to make one of two possible calls to DarkSky’s
    // Dark Sky API, ie. forecast requests and time-machine requests. For
    // more information, see https://darksky.net/dev/docs
    // Access to the API is controlled by key. Register for developer access
    // here: https://darksky.net/dev/register

    // Note: this class does not parse the incoming data, which is highly complex.
    // It is up to your application to extract the data you require

    // Written by Tony Smith (@smittytone)
    // Copyright Electric Imp, Inc. 2016
    // License: MIT

    static FORECAST_URL = "https://api.darksky.net/forecast/";
    static VERSION = [1,0,0];

    _apikey = null;
    _units = null;
    _lang = null;
    _debug = false;

    constructor (key = null, debug = false) {
        if (imp.environment() != ENVIRONMENT_AGENT) {
            server.error("DarkSky class must be instantiated by the agent");
            return null;
        }

        if (key == "" || key = null) {
            server.error("DarkSky class requires an API key");
            return null;
        }

        _debug = debug;
        _apikey = key;
    }

    function forecastRequest(longitude = 999, latitude = 999, callback = null) {
        // Parameters:
        //  1. Longitude of location for which a forecast is required
        //  2. Latitude of location for which a forecast is required
        //  3. Optional synchronous operation callback
        // Returns:
        //  If callback is null, the function returns a table with key 'response'
        //  If callback is not null, the function returns nothing
        //  If there is an error, the function returns a table with key 'err'

        if (!_checkCoords(longitude, latitude, "forecastRequest")) {
            if (callback) {
                callback("Co-ordinate error", null);
                return null;
            } else {
                return {"err": "Co-ordinate error"};
            }
        }

        local url = FORECAST_URL + _apikey + "/" + format("%.6f", latitude) + "," + format("%.6f", longitude);
        url = _addOptions(url);
        return _sendRequest(http.get(url), callback);
    }

    function timeMachineRequest(longitude = 999, latitude = 999, time = null, callback = null) {
        // Parameters:
        //  1. Longitude of location for which a forecast is required
        //  2. Latitude of location for which a forecast is required
        //  3. A Unix time or ISO 1601-formatted string
        //  4. Optional synchronous operation callback
        // Returns:
        //  If callback is null, the function returns a table with key 'response'
        //  If callback is not null, the function returns nothing
        //  If there is an error, the function returns a table with key 'err'

        if (!_checkCoords(longitude, latitude, "timeMachineRequest")) {
            if (callback) {
                callback("Co-ordinate error", null);
                return null;
            } else {
                return {"err": "Co-ordinate error"};
            }
        }

        if (time == null || time.tostring().len() == 0) {
            if (_debug) server.error("DarkSky.timeMachineRequest() requires a valid time parameter");
            return {"err": "Timestamp error"};
        }

        local timeString;
        if (typeof time == "integer") {
            timeString = time.tostring();
        } else if (typeof time == "string") {
            timeString = time;
        } else {
            if (_debug) server.error("DarkSky.timeMachineRequest() requires a valid time parameter");
            return {"err": "Timestamp error"};
        }

        local url = FORECAST_URL + _apikey + "/" + format("%.6f", latitude) + "," + format("%.6f", longitude) + "," + timeString;
        url = _addOptions(url);
        return _sendRequest(http.get(url), callback);
    }

    function setUnits(units = "us") {
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
            if (_debug) server.error("Incorrect units option selected; using default value");
            units = "us";
        }

        if (units == "uk") units = "uk2";
        _units = units;
        return this;
    }

    function setLanguage(language = "en") {
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
            if (_debug) server.error("Incorrect language option selected; using default value");
            language = "en";
        }

        _lang = language;
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
                        err = "Unable to decode data received from Forecast.io: " + exp;
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
        // Extract daily API request count from Forecast.io response header
        if ("headers" in resp) {
            if ("x-forecast-api-calls" in resp.headers) {
                local a = resp.headers["x-forecast-api-calls"];
                return a.tointeger();
            }
        }

        return -1;
    }

    function _checkCoords(longitude, latitude, caller) {
        // Check that valid co-ords have been supplied
        if (typeof longitude != "float") {
            try {
                longitude = longitude.tofloat();
            } catch (err) {
                if (_debug) server.error("DarkSky." + caller + "() can't convert supplied longitude value");
                return false;
            }
        }

        if (typeof latitude != "float") {
            try {
                latitude = latitude.tofloat();
            } catch (err) {
                if (_debug) server.error("DarkSky." + caller + "() can't convert supplied latitude value");
                return false;
            }
        }

        if (longitude == 999 || latitude == 999) {
            if (_debug) server.error("DarkSky." + caller + "() requires valid latitude/longitude co-ordinates");
            return false;
        }

        if (latitude > 90 || latitude < -90) {
            if (_debug) server.error("DarkSky." + caller + "() requires valid a latitude co-ordinate");
            return false;
        }

        if (longitude > 180 || longitude < -180) {
            if (_debug) server.error("DarkSky." + caller + "() requires valid a latitude co-ordinate");
            return false;
        }

        return true;
    }

    function _addOptions(baseurl) {
        local opts = "?units=" + _units;
        if (_lang) opts = opts + "&lang=" + _lang;
        return (baseurl + opts);
    }
}
