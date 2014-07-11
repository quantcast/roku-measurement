FUNCTION qcmsrmt_DataManagerInit()
    this = {
        'member vars
        Events : []
        
        PostEvent  :  qcmsrmt_PostEvent
        
        
    }
    return this

END FUNCTION

SUB qcmsrmt_PostEvent(event, policy, sendImmediately=TRUE AS BOOLEAN)

    IF event <> INVALID
        m.Events.push(event)
    END IF
    
    IF policy.IsLoaded AND m.Events.Count() > 0 AND sendImmediately
        ' if we are blacked out then we don't send and dump our pending events
        IF policy.isBlackedOut()
            m.Events.Clear()
            return
        END IF
        
        fullData = { 
            uplid : qcmsrmt_CreateUUID()
            qcv   : "ROKU_" + GetGlobalAA()["QuantcastSDKVersion"]
            events: m.Events
        }
        'lets create the full Json
        jsonBody = qcmsrmt_SerializeJSON(fullData, policy)
        
        'and send it, if success then delete events
        IF qcmsrmt_SendEvents(jsonBody)
            m.Events.Clear()
        END IF
    END IF

END SUB

FUNCTION qcmsrmt_SerializeJSON(v AS DYNAMIC, policy) AS STRING
    out = ""
    v = box(v)
    vType = type(v)
    IF vType = "roString" OR vType = "String"
        re = CreateObject("roRegex",chr(34),"")
        v = re.replaceall(v, chr(34)+"+chr(34)+"+chr(34) )
        out = out + chr(34) + v + chr(34)
    ELSE IF vType = "roInt" OR vType = "roInteger"
        out = out + v.tostr().Trim()
    ELSE IF vType = "roFloat"
        out = out + str(v).Trim()
    ELSE IF vType = "roBoolean"
        bool = "false"
        IF v THEN bool = "true"
        out = out + bool
    ELSE IF vType = "roList" OR vType = "roArray"
        out = out + "["
        sep = ""
        FOR EACH child IN v
            out = out + sep + qcmsrmt_SerializeJSON(child, policy)
            sep = ","
        END FOR
        out = out + "]"
    ELSE IF vType = "roAssociativeArray"
        out = out + "{"
        sep = ""
        FOR EACH key IN v
            IF NOT policy.isBlacklistedParam(key)
                IF policy.saltValue() <> INVALID  AND (key = "did" OR key = "aid")
                    v[key] = qcmsrmt_HashId(v[key], policy.saltValue())
                END IF
                out = out + sep + chr(34) + key + chr(34) + ":"
                out = out + qcmsrmt_SerializeJSON(v[key], policy)
                sep = ","
            END IF
        END FOR
        out = out + "}"
    ELSE
        out = out + chr(34) + vType + chr(34)
    END IF
    return out
END FUNCTION

FUNCTION qcmsrmt_HashId(value AS STRING, saltValue AS STRING) AS STRING
    saltedString = value + saltValue
    return qcmsrmt_HashUserID(saltedString)
END FUNCTION

FUNCTION qcmsrmt_SendEvents(jsonBody AS STRING) AS BOOLEAN
    success = FALSE
    EventURLStr = "http://m.quantcount.com/mobile"
    
    request = CreateObject("roUrlTransfer")
    request.SetUrl(EventURLStr)

    network = getQuantcastInstance().Networking

    IF network <> INVALID
        success = network.StartRequest(request, INVALID, jsonBody)
    ELSE 
       request.AsyncPostFromString(jsonBody) 
       'give it some time to send
       sleep(500)
    END IF
    return success
END FUNCTION
