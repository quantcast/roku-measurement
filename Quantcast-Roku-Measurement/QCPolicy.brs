Function qcmsrmt_PolicyInit(apiKey AS STRING)

this = {
    'member vars
    ApiKey     : apiKey
    IsLoaded   : FALSE
    PolicyDict : {}
    FailureCount : 0
    
    'member fuctions
    updatePolicy       : qcmsrmt_UpdatePolicy
    isBlacklistedParam : qcmsrmt_IsBlacklisted 'here is my comment
    isBlackedOut       : qcmsrmt_IsBlackedOut
    saltValue          : qcmsrmt_SaltedValue
    sessionTimeout     : qcmsrmt_SessionTime 
    HandleUrlEvent     : qcmsrmt_HandleUrlEvent
}

return this
END FUNCTION

FUNCTION qcmsrmt_UpdatePolicy()
    countryCode = "XX"
    deviceInfo = CreateObject("roDeviceInfo")
    IF qcmsrmt_IsVersionSupported(4.3, deviceInfo)
        countryCode = deviceInfo.GetCountryCode()
    END IF
    osString = "ROKU"
    version = GetGlobalAA().Lookup("QuantcastSDKVersion")

    policyURLStr = "http://m.quantcount.com/policy.json?a=" + m.ApiKey + "&v=" + version + "&t=" + osString + "&c=" + countryCode

    request = CreateObject("roUrlTransfer")
    request.SetUrl(policyURLStr)

    qcmsrmt_SendPolicyRequest(m, request)   
    
END FUNCTION

FUNCTION qcmsrmt_IsBlacklisted(paramKey AS String) AS BOOLEAN
    blacklist = m.PolicyDict["blacklist"]
    IF blacklist <> INVALID
        FOR EACH item IN blacklist
           IF item = paramKey THEN RETURN TRUE
        END FOR
    END IF
    RETURN FALSE
END FUNCTION

FUNCTION qcmsrmt_IsBlackedOut() AS BOOLEAN
    blackedOut = FALSE
    blackoutTime = m.PolicyDict["blackout"]
    blackoutTime = box(blackoutTime)
    IF blackoutTime <> INVALID
        nowSeconds = CreateObject("roDateTime").AsSeconds()
        blackoutType = type(blackoutTime)
        time = 0
        IF blackoutType = "roString" OR blackoutType = "String"
            time = blackoutTime.ToFloat() /1000.0
        ELSE IF blackoutType = "roInt" OR blackoutType = "roFloat"
            time = blackoutTime / 1000.0
        END IF
        blackedOut = time > nowSeconds
    
    END IF
    
    RETURN blackedOut
END FUNCTION

FUNCTION qcmsrmt_SaltedValue() AS Dynamic
    salt = m.PolicyDict["salt"]
    
    IF salt = INVALID OR salt = "MSG"
        salt = INVALID
    END IF

    RETURN salt
END FUNCTION

FUNCTION qcmsrmt_SessionTime() AS INTEGER
    time = 1800
    timeoutVal = m.PolicyDict["sessionTimeOutSeconds"]
    timeoutVal = box(timeoutVal)
    IF timeoutVal <> INVALID
        timeoutType = type(timeoutVal)
        IF timeoutType = "roString" OR timeoutType = "String"
            time = timeoutVal.ToInt()
        ELSE IF timeoutType = "roInt" OR timeoutType = "roFloat"
            time = timeoutVal
        END IF
    END IF 
    return time
END FUNCTION

SUB qcmsrmt_HandleUrlEvent(msg AS OBJECT, context AS OBJECT)
    IF msg.GetInt() = 1 AND msg.GetResponseCode() = 200
        json = ParseJson(msg.GetString())
        m.PolicyDict = json
        m.FailureCount = 0
        m.IsLoaded = TRUE
    ELSE
        Print "Policy failed to download: " msg.getFailureReason()
        m.IsLoaded = FALSE
        m.PolicyData = {}
        'failed? try again
        m.updatePolicy()
    END IF
END SUB

SUB qcmsrmt_SendPolicyRequest(m AS OBJECT, request AS Object)
 
    network = getQuantcastInstance().Networking

    IF network <> INVALID
        started = network.StartRequest(request, m)
        IF NOT started THEN PRINT "Policy request failed to send"
    ELSE 
       port = CreateObject( "roMessagePort" )
       request.SetPort( port ) 
       started = request.AsyncGetToString()
       If started
          count = 0
          msg = INVALID
          WHILE msg = INVALID AND count < 5
              msg = Wait( 50, request.GetPort() )
              count = count + 1
          END WHILE
          m.HandleUrlEvent(msg, INVALID)
       END IF    
    END IF

END SUB
