
FUNCTION qcmsrmt_LaunchEvent(sessionID as String, userhash, appInstallId AS String, apiKey AS String, labels) AS OBJECT
   
    manifest = qcmsrmt_ReadManifest()
    deviceInfo = CreateObject("roDeviceInfo")
    'time zone offset calcualtion
    nowDate = CreateObject("roDateTime")
    UTCDateHour = nowDate.AsSeconds()
    nowDate.toLocalTime()
    localDateHour = nowDate.AsSeconds()
    timeZoneOffset = (UTCDateHour - localDateHour) / 60

    event = {
        sid     : sessionID
        et      : UTCDateHour
        aid     : appInstallId
        did     : deviceInfo.GetDeviceUniqueId()
        event   : "load"
        nsr     : "launch"
        apiKey  : apiKey
        media   : "app"
        ct      : "wifi" 
        aname   : manifest["title"]
        pkid    : manifest["title"]
        aver    : manifest["major_version"] + "." +  manifest["minor_version"] + "." + manifest["build_version"]
        iver    : manifest["major_version"] + "." +  manifest["minor_version"] + "." + manifest["build_version"]
        dmod    : deviceInfo.GetModel()
        dos     : "Roku OS"
        dosv    : deviceInfo.GetVersion()
        dm      : "Roku" 
        tzo     : timeZoneOffset
    }
    
    'check user hash
    IF userhash <> INVALID
       event.uh = userhash
    END IF 
    
    'screen size
    IF qcmsrmt_IsVersionSupported(2.6, deviceInfo)
        display = deviceInfo.GetDisplaySize()
        event.sr = STR(display["w"]).Trim() + "x" + STR(display["h"]).Trim() + "x32"
    END IF
    
    'check if locale is supported 
    IF qcmsrmt_IsVersionSupported(4.3, deviceInfo)
        locale = deviceInfo.GetCurrentLocale().Tokenize("_")
        event.lc = locale[0]
        event.ll = locale[1]
        event.icc = deviceInfo.GetCountryCode()
    END IF
    
    IF qcmsrmt_IsVersionSupported(4.8, deviceInfo)
        event.dtype = deviceInfo.GetModelDisplayName()
    ELSE
        event.dtype = "Roku"
    END IF
    
    qcmsrmt_AddLabels(event, labels)
    return event

END FUNCTION

Function qcmsrmt_EndEvent(sessionID as String, appInstallId AS String, labels) as OBJECT
    nowDate = CreateObject("roDateTime")
    
    event = {
        sid     : sessionID
        et      : nowDate.AsSeconds()
        aid     : appInstallId
        event   : "finished"
    }
    qcmsrmt_AddLabels(event, labels)
    return event
END FUNCTION

Function qcmsrmt_LogEventEvent(name as String, sessionID as String, appInstallId AS String, labels) AS OBJECT
    nowDate = CreateObject("roDateTime")
    
    event = {
        sid     : sessionID
        et      : nowDate.AsSeconds()
        aid     : appInstallId
        event   : "appevent"
        appevent: name
    }
    qcmsrmt_AddLabels(event, labels)
    return event
END FUNCTION

FUNCTION qcmsrmt_ReadManifest() AS Object
    manifest = {}
    lines = ReadASCIIFile("pkg:/manifest").Tokenize(Chr(10))
    FOR EACH line IN lines
        bits = line.Tokenize("=")
        if bits.Count() > 1
          manifest.AddReplace(bits[0], bits[1])
        end if
    END FOR
    return manifest
END FUNCTION

SUB qcmsrmt_AddLabels(event AS Object, labels AS Object)
    
    labelType = type(labels)
    IF labelType = "roString" OR labelType = "String"
        IF labels.Len() > 0
            event["labels"] = labels
        END IF
    ELSE IF labelType = "roArray"
        labelStr = ""
        FOR EACH label IN labels
            labelType = type(label)
            IF (labelType = "roString" OR labelType = "String") AND label.Len() > 0
                labelStr = labelStr + label + ","
            END IF
        END FOR 
        IF labelStr.Len() > 0
            event["labels"] = labelStr.Left(labelStr.Len()-1)
        END IF
    END IF    
    
END SUB

FUNCTION qcmsrmt_IsVersionSupported(version AS DOUBLE, deviceInfo AS OBJECT) AS BOOLEAN
    deviceVersion = deviceInfo.GetVersion().Mid(2, 4).ToFloat()
    RETURN deviceVersion >= version
END FUNCTION




