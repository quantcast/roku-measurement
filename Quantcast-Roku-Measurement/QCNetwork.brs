FUNCTION QCNetworkingInit(messagePort AS OBJECT)

    this = {
        'member vars
        MessagePort : messagePort
        PendingRequests : {}
        
        'member functions
        StartRequest  : qcmsrmt_StartRequest
        HandleRequest : qcmsrmt_NetworkHandleMessage
        isQCMessage   : qcmsrmt_isQCMessage
        setMessagePort: qcmsrmt_setNetworkMessagePort
        
    }
    return this

END FUNCTION

FUNCTION qcmsrmt_StartRequest(request AS OBJECT, listener=INVALID, body=invalid) AS BOOLEAN
    request.SetPort(m.MessagePort)
    context = {
        Listener : listener
        Request  : request 
        Body     : body   
    }
    
    if body = invalid then
        started = request.AsyncGetToString()
    else
        started = request.AsyncPostFromString(body)
    end if

    if started
        id = request.GetIdentity().tostr()
        m.PendingRequests[id] = context
    end if
    
    return started
End Function

FUNCTION qcmsrmt_NetworkHandleMessage(msg AS OBJECT) AS BOOLEAN
    handled = FALSE
    'we only check for URL Events
    IF type(msg) = "roUrlEvent"
        id = msg.GetSourceIdentity().tostr()
        'then check if they belong to us
        requestContext = m.PendingRequests[id]
        IF requestContext <> INVALID
            m.PendingRequests.Delete(id)
            IF requestContext.Listener <> INVALID 
                requestContext.Listener.HandleUrlEvent(msg, requestContext)
            END IF
            handled = TRUE
        END IF  
    END IF
    return handled
END FUNCTION

FUNCTION qcmsrmt_isQCMessage(sourceIdentity AS INTEGER) AS BOOLEAN
    return m.PendingRequests[sourceIdentity.toStr()] <> INVALID
END FUNCTION

SUB qcmsrmt_setNetworkMessagePort(port AS OBJECT)
    IF NOT m.PendingRequests.IsEmpty()
        ? "WARNING!: Quantcast is still expecting a message on the previous port.  Be sure all messages are collected before switching ports."
    END IF
    
    m.MessagePort = port
END SUB
