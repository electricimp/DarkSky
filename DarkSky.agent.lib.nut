/**
 * This class allows you to make one of two possible calls to DarkSky’s
 * Dark Sky API, ie. forecast requests and time-machine requests. For
 * more information, see https://darksky.net/dev/docs
 * Access to the API is controlled by key. Register for developer access
 * here: https://darksky.net/dev/register
 *
 * NOTE this class does not parse the incoming data, which is highly complex.
 *      It is up to your application to extract the data you require
 *
 * @author    Tony Smith (@smittytone)
 * @copyright Electric Imp, Inc. 2016-18
 * @license   MIT
 *
 * @class
 *
*/

class DarkSky {

    static VERSION = "2.0.0";
    static FORECAST_URL = "https://api.darksky.net/forecast/";

    /**
     *
     * A running count API accesses as returned by Dark Sky
     *
     * @property
     *
     */
    callCount = -1;
    
    // ********** Private Properties **********

    _apikey = null;
    _units = null;
    _lang = null;
    _debug = false;

    /**
     * The Dark Sky construtor
     *
     * @constructor
     *
     * @param {string} apiKey  - Your Dark Sky service API key.
     * @param {bool}   [debug] - Whether to log extra debugging info (true) or not (false). Default: false.
     *
    */
    constructor (key = null, debug = false) {
        // Check for instantiation parameter errors
        if (imp.environment() != ENVIRONMENT_AGENT) throw "DarkSky() must be instantiated by the agent";
        if (key == "" || key = null) throw "DarkSky() requires an API key";
        if (typeof key != "string") throw "DarkSky() requires an API key supplied as a string";

        // Set private properties
        if (typeof debug != "bool") debug = false;
        _debug = debug;
        _units = "auto";
        _apikey = key;
    }

    /**
     * Make a request for future weather data
     *
     * @param {float}    longitude  - Longitude of location for which a forecast is required.
     * @param {float}    latitude   - Latitude of location for which a forecast is required. 
     * @param {function} [callback] - Optional asynchronous operation callback.
     *
     * @returns {table|string|null} If 'callback' is null, the function returns a table with key 'response';
     *                              if there was an error, the function returns a table with key 'error'.
     *                              If 'callback' is not null, the function returns nothing;
     *                              
    */
    function forecastRequest(longitude = 999.0, latitude = 999.0, callback = null) {
        // Check the supplied co-ordinates
        if (!_checkCoords(longitude, latitude, "forecastRequest")) {
            if (callback) {
                callback("Co-ordinate error", null);
                return;
            } else {
                return {"error": "Co-ordinate error"};
            }
        }

        // Co-ordinates good, so get a forecast
        local url = FORECAST_URL + _apikey + "/" + format("%.6f", latitude) + "," + format("%.6f", longitude);
        url = _addOptions(url);
        return _sendRequest(http.get(url), callback);
    }

    /**
     * Make a request for historical weather data
     *
     * @param {float}    longitude  - Longitude of location for which a forecast is required.
     * @param {float}    latitude   - Latitude of location for which a forecast is required. 
     * @param {string}   time       - A Unix time or ISO 1601-formatted string.
     * @param {function} [callback] - Optional asynchronous operation callback.
     *
     * @returns {table|string|null} If 'callback' is null, the function returns a table with key 'response';
     *                              if there was an error, the function returns a table with key 'error'.
     *                              If 'callback' is not null, the function returns nothing;
     *                              
    */
    function timeMachineRequest(longitude = 999.0, latitude = 999.0, time = null, callback = null) {
        // Check the supplied co-ordinates
        if (!_checkCoords(longitude, latitude, "timeMachineRequest")) {
            if (callback) {
                callback("Co-ordinate error", null);
                return null;
            } else {
                return {"error": "Co-ordinate error"};
            }
        }

        // Check the supplied co-ordinates
        if (time == null || time.tostring().len() == 0) {
            if (_debug) server.error("DarkSky.timeMachineRequest() requires a valid time parameter");
            return {"error": "Timestamp error"};
        }

        local timeString;
        if (typeof time == "integer" || typeof time == "float") {
            timeString = time.tostring();
        } else if (typeof time == "string") {
            timeString = time;
        } else {
            if (_debug) server.error("DarkSky.timeMachineRequest() requires a valid time parameter");
            return {"error": "Timestamp error"};
        }

        // Co-ordinates good, so get the historical data
        local url = FORECAST_URL + _apikey + "/" + format("%.6f", latitude) + "," + format("%.6f", longitude) + "," + timeString;
        url = _addOptions(url);
        return _sendRequest(http.get(url), callback);
    }

    /**
     * Get the current Dakr Sky API call count
     *
     * @returns {integer} The most recent call count.
     *                              
    */
    function getCallCount() {
        return callCount;
    }

    /**
     * Specify the preferred weather report's units
     *
     * @param {string} [units] - Country code indicating the type of units. Default: automatic, based on location.
     *
     * @returns {instance} The Dark Sky instance (this).
     *                              
    */
    function setUnits(units = "auto") {
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

    /**
     * Specify the preferred weather report's language
     *
     * @param {string} [language] - Country code indicating the language. Default: English.
     *
     * @returns {instance} The Dark Sky instance (this).
     *                              
    */
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
            if (_debug) server.error("DarkSky.setLanguage() incorrect language option selected (" + language + "); using default value (en)");
            language = "en";
        }

        _lang = language;
        if (_debug) server.log("DarkSky language selected: " + _lang);
        return this;
    }

    // ********** PRIVATE FUNCTIONS - DO NOT CALL **********

    /**
     * Specify the preferred weather report's language
     *
     * @private
     *
     * @param {imp::httprequest} req  - The HTTPS request to send.
     * @param {function}         [cb] - Optional callback function.
     *
     * @returns {imp::httpresponse|null} The HTTPS response, or nothing if 'cb' is not null.
     *                              
    */
    function _sendRequest(req, cb = null) {
        local err, data, count;
        if (cb != null) {
            req.sendasync(function(resp) {
                if (resp.statuscode != 200) {
                    err = format("Unable to retrieve forecast data (code: %i)", resp.statuscode);
                } else {
                    try {
                        data = http.jsondecode(resp.body);

                        // Add daily API request count to 'data'
                        count = _getCallCount(resp);
                        if (count != -1) {
                            data.callCount <- count;
                            callCount = count;
                        }
                    } catch(exp) {
                        err = "Unable to decode data received from Dark Sky: " + exp;
                        data = null;
                    }
                }

                cb(err, data);
            }.bindenv(this));
            return null;
        } else {
            local resp = req.sendsync();
            local returnTable;
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
            if (count != -1) {
                data.callCount <- count;
                callCount = count;
            }

            // Create table of returned data
            returnTable.error <- err;
            returnTable.data <- data;
            return returnTable;
        }
    }

    /**
     * Extract daily API request count from Dark Sky response header
     *
     * @private
     *
     * @param {imp::httpresponse} resp - The HTTPS response.
     *
     * @returns {integer} The latest request count, or -1 on error.
     *                              
    */
    function _getCallCount(resp) {
        // 
        if ("headers" in resp) {
            if ("x-forecast-api-calls" in resp.headers) {
                local a = resp.headers["x-forecast-api-calls"];
                try {
                    return a.tointeger();
                } catch(e) {
                    // NOP
                }
            }
        }
        return -1;
    }

    /**
     * Check that valid co-ords have been supplied
     *
     * @private
     *
     * @param {float}  longitude - Longitude of location for which a forecast is required.
     * @param {float}  latitude  - Latitude of location for which a forecast is required.
     * @param {string} caller    - The name of the calling function, for error reporting.
     *
     * @returns {Boolean} Whether the supplied co-ordinates are valid (true) or not (false).
     *                              
    */
    function _checkCoords(longitude = 999.0, latitude = 999.0, caller = "function") {
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
            if (_debug) server.error("DarkSky." + caller + "() requires valid a latitude co-ordinate (value out of range)");
            return false;
        }

        if (longitude > 180.0 || longitude < -180.0) {
            if (_debug) server.error("DarkSky." + caller + "() requires valid a latitude co-ordinate (value out of range)");
            return false;
        }

        return true;
    }

    /**
     * Add URL-encoded options to the request URL
     *
     * Used when assembling HTTPS requests
     *
     * @private
     *
     * @param {string} [baseurl] - Optional base URL.
     *
     * @returns {string} The full URL will added options
     *                              
    */
    function _addOptions(baseurl = "") {
        local opts = "?units=" + _units;
        if (_lang) opts = opts + "&lang=" + _lang;
        return (baseurl + opts);
    }
}
