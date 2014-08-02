Function getQuantcastInstance()
    this = m.Instance
    IF this = INVALID
        this = {
        'member variables
            sessionActive   : FALSE
            sessionID       : INVALID
            appInstallID    : qcmsrmt_GetAppInstallId()
            hashedUserId    : INVALID
            ApiKey          : ""
            Networking      : INVALID
            DataManager     : qcmsrmt_DataManagerInit()            
            
        'Functions
            StartQuantcast       : qcmsrmt_StartQuantcast
            EndQuantcast         : qcmsrmt_EndQuantcast
            LogEvent             : qcmsrmt_LogEvent
            RecordUserIdentifier : qcmsrmt_RecordUserId
            IsQuantcastMsgIdentifier   : qcmsrmt_CheckMessage
            HandleMsg            : qcmsrmt_HandleMessage
            IsOptedOut           : qcmsrmt_IsOptedOut
            SetOptOut            : qcmsrmt_SetOptOut
            GetSessionStatus     : qcmsrmt_SessionStatus
         
        }
        ' singleton
        m.Instance = this
        GetGlobalAA().AddReplace("QuantcastSDKVersion", "1_0_1")
    END IF
    
    return this
    
END FUNCTION

'Starts the Quantcast Session.   This should be done as soon as possible during application startup.  This
'should be outside any run loop.  It returns the one way hash value of the userId if provided
' apiKey - The Quantcast API key this app should be reported under. Obtain this key from the Quantcast website
' msgPort - The message Port to which any quantcast message should be posted
' userIdOrBlank - an optional user identifier string that is meanigful to the app publisher. This is usually a user login name 
'                 or anything that identifies the user (different from a device id), but there is no requirement on format of 
'                 this other than that it is a meaningful user identifier to you. Quantcast will immediately one-way hash this value, 
'                 thus not recording it in its raw form. You should pass nothing or blank string to indicate that there is no user 
'                 identifier available, either at the start of the session or at all.
' labels   - An optional String or Array object containing one or more String objects, each of which are a distinct label to be applied to this event. 
'            A label is any arbitrary string that you want to be ascociated with this event, and will create a second dimension in 
'            Quantcast Measurement reporting. Nominally, this is a "user class" indicator. For example, you might use one of two labels 
'            in your app: one for user who ave not purchased an app upgrade, and one for users who have purchased an upgrade.
Function qcmsrmt_StartQuantcast(apiKey AS STRING, msgPort AS OBJECT, userIdOrBlank="" AS STRING, labels=INVALID) AS OBJECT
   
   'if we have an invalid API key or have already started a session then just return
    IF NOT qcmsrmt_ValidateAPIKey(apiKey) OR m.sessionActive OR qcmsrmt_IsOptedOut()
        PRINT "COULD NOT START QUANTCAST SDK"
        return INVALID
    END IF
   
    m.sessionActive = TRUE
    m.ApiKey = apiKey   
    IF userIdOrBlank.Len() > 0
        m.hashedUserId = qcmsrmt_HashUserID(userIdOrBlank)
    END IF

   'startup networking and grab policy
    IF msgPort <> INVALID 
        m.Networking = QCNetworkingInit(msgPort)
    END IF
 
    m.Policy = qcmsrmt_PolicyInit(apiKey)
    m.Policy.updatePolicy()

    m.sessionID = qcmsrmt_CreateUUID()
    event = qcmsrmt_LaunchEvent(m.sessionID, m.hashedUserId, m.appInstallID, m.ApiKey, labels)
    m.DataManager.postEvent(event, m.Policy)

   return m.hashedUserId
END FUNCTION

'Records the User Identifier.   This should be done as soon as the user identifier is known or changes. It returns the one way hash value of the userId if provided
' userIdOrBlank - an optional user identifier string that is meanigful to the app publisher. This is usually a user login name 
'                 or anything that identifies the user (different from a device id), but there is no requirement on format of 
'                 this other than that it is a meaningful user identifier to you. Quantcast will immediately one-way hash this value, 
'                 thus not recording it in its raw form. You should pass nothing or blank string to indicate that the user has logged out.
' labels   - An optional String or Array object containing one or more String objects, each of which are a distinct label to be applied to this event. 
'            A label is any arbitrary string that you want to be ascociated with this event, and will create a second dimension in 
'            Quantcast Measurement reporting. Nominally, this is a "user class" indicator. For example, you might use one of two labels 
'            in your app: one for user who ave not purchased an app upgrade, and one for users who have purchased an upgrade.
FUNCTION qcmsrmt_RecordUserId(userIdOrBlank AS STRING, labels=INVALID AS OBJECT) AS OBJECT 
    IF NOT m.sessionActive OR qcmsrmt_IsOptedOut()
        RETURN INVALID
    END IF
    
    newUserHash = INVALID
    IF userIdOrBlank.Len() > 0
       newUserHash = qcmsrmt_HashUserID(userIdOrBlank)
    ELSE
       newUserHash = INVALID
    END IF    
    
    IF (m.hashedUserId = INVALID AND newUserHash <> INVALID) OR (m.hashedUserId <> INVALID AND newUserHash = INVALID) OR (m.hashedUserId <> INVALID AND m.hashedUserId <> newUserHash)
        m.hashedUserId = newUserHash
        m.sessionID = qcmsrmt_CreateUUID()
        event = qcmsrmt_LaunchEvent(m.sessionID, m.hashedUserId, m.appInstallID, m.ApiKey, labels)
        m.DataManager.postEvent(event, m.Policy)
    END IF
    
    RETURN m.hashedUserId
END FUNCTION

' Logs an arbitrary event.  The name can be anything the app developer chooses
' eventName - A string that identifies the event being logged. Hierarchical information can be indicated by using a left-to-right notation 
'             with a period as a seperator. For example, logging one event named "button.left" and another named "button.right" will create 
'             three reportable items in Quantcast App Measurement: "button.left", "button.right", and "button". There is no limit on the cardinality 
'             that this hierarchal scheme can create, though low-frequency events may not have an audience report on due to the lack of a 
'             statistically significant population.
' labels   - An optional String or Array object containing one or more String objects, each of which are a distinct label to be applied to this event. 
'            A label is any arbitrary string that you want to be ascociated with this event, and will create a second dimension in 
'            Quantcast Measurement reporting. Nominally, this is a "user class" indicator. For example, you might use one of two labels 
'            in your app: one for user who ave not purchased an app upgrade, and one for users who have purchased an upgrade.
SUB qcmsrmt_LogEvent(eventName AS STRING, labels=INVALID AS OBJECT)
    IF NOT m.sessionActive OR qcmsrmt_IsOptedOut() THEN RETURN
     
    event = qcmsrmt_LogEventEvent(eventName, m.sessionID, m.appInstallID, labels)
    m.DataManager.postEvent(event, m.Policy)
END SUB

' Ends a user session.   This should be called before the app shuts down
' labels   - An optional String or Array object containing one or more String objects, each of which are a distinct label to be applied to this event. 
'            A label is any arbitrary string that you want to be ascociated with this event, and will create a second dimension in 
'            Quantcast Measurement reporting. Nominally, this is a "user class" indicator. For example, you might use one of two labels 
'            in your app: one for user who ave not purchased an app upgrade, and one for users who have purchased an upgrade.
SUB qcmsrmt_EndQuantcast(labels=INVALID AS OBJECT)
    IF NOT m.sessionActive OR qcmsrmt_IsOptedOut() THEN RETURN

    event = qcmsrmt_EndEvent(m.sessionID, m.appInstallID, labels)
    
   'we are going to try to force this to send before closing 
    m.Networking = INVALID
    m.DataManager.postEvent(event, m.Policy)  
    m.sessionActive = FALSE
END SUB

' Queries the status of the session.   Returns TRUE if the StartQuantcast has been called succesfully 
FUNCTION qcmsrmt_SessionStatus() AS BOOLEAN
    RETURN m.sessionActive
END FUNCTION

' Used to handle any message that might be specific to the Quantcast SDK.  This should be called near the top of the application run loop.
' This method returns TRUE if the message passed was a Quantcast message and FALSE if the message was ignored.  
' Applications may also use the CheckMessage method in order to specifically check messages
' msg - The message object to be checked and handled by Quantcast
FUNCTION qcmsrmt_HandleMessage(msg AS OBJECT) AS BOOLEAN
    IF NOT m.sessionActive OR qcmsrmt_IsOptedOut() THEN RETURN FALSE
    
    handled = m.Networking.HandleRequest(msg)
    'push any events still handing around
    m.DataManager.PostEvent(INVALID, m.Policy)
    
    RETURN handled
END FUNCTION

' A method used to specifically check if a roUrlEvent belongs to Quantcast.  This can optionally be used to check a roUrlEvent sourceIdentity before
' passing the full message to the HandleMessage method. Returns TRUE if the message belongs to Quantcast and FALSE if not
' sourceIdentity  -  The specific sourceIdentity of a roUrlEvent.  It can be retrived by calling msg.GetSourceIdentity() when msg is of roUrlEvent type
FUNCTION qcmsrmt_CheckMessage(sourceIdentity AS INTEGER) AS BOOLEAN
    IF NOT m.sessionActive OR qcmsrmt_IsOptedOut() THEN RETURN FALSE
    RETURN m.Networking.isQCMessage(sourceIdentity)
END FUNCTION

' Checks the opt out preference of the user.   If a User is Opted out, the Quantcast SDK will not collect any information pertaining to the device.
FUNCTION qcmsrmt_IsOptedOut() As BOOLEAN
     sec = CreateObject("roRegistrySection", "QCPersistKeys")
     IF sec.Exists("UserOptOut") 
        
         if sec.Read("UserOptOut") = "1"
             return TRUE
         END IF
     END IF
     return FALSE
END FUNCTION
 
' Method to set the devices opt out status to true.  Quantcast recommends application provide some sort of interface to allow the user to opt out of 
' measurement
SUB qcmsrmt_SetOptOut(optOut As BOOLEAN)
    sec = CreateObject("roRegistrySection", "QCPersistKeys")
    optOutStr = "0"
    IF optOut = TRUE 
        optOutStr = "1"
        'opting out then delete the previous aid
        sec.Delete("AppInstallId")
    END IF
    sec.Write("UserOptOut", optOutStr)
    sec.Flush()
End SUB

'
'helper functions.  
'
'
'

Function qcmsrmt_ValidateAPIKey(apiKey as STRING) as BOOLEAN
    IF apiKey = INVALID THEN return FALSE
    
    regexApiKey = CreateObject( "roRegex", "[a-zA-Z0-9]{16}-[a-zA-Z0-9]{16}", "i" )
    return regexApiKey.IsMatch(apiKey)

END FUNCTION

'Here are some wonky rules of BrightScript that I will refer back to
' 1)When a number is converted to integer type, it is "rounded down"; 
'    i.e., the largest integer, which is not greater than the number is used. 
'    ex.  2.5 returns 2; -2.5 returns -3; 2^32 return 2^31-1 (MAX INTEGER)
' 2) Floats only keep 7 significant digits which is never enough for hashing.  Also all built in methods demote to float 
FUNCTION qcmsrmt_HashUserID(userId as STRING) AS STRING

    h1 = &H811c9dc5
    h2 = &Hc9dc5118
    
    hash1# = qcmsrmt_HashFunc(h1, userId)
    hash2# = qcmsrmt_HashFunc(h2, userId)
    
    multiply# = hash1#*hash2#
    
    'explict absolute value  because built in ABS returns float which loses precision #2
    if SGN(multiply#)<0 THEN multiply#=multiply#*-1
    
    fullHash# = multiply#/65536.0
    
    'split this full double into two ints so its easier to work with the bits
    topInt% = fullHash# / 4294967296
    bottomInt% = qcmsrmt_Round(fullHash#)
    
    ba = CreateObject("roByteArray")
    ba.setresize(8, false)
    
    qcmsrmt_addIntegerToByteArray(ba, bottomInt%)
    qcmsrmt_addIntegerToByteArray(ba, topInt%)
    
    hexString = LCase(ba.toHexString())
    
    'hash can vary in length, so remove the all leading 0s
    r = CreateObject("roRegex", "[0]{2,}", "i")
    hexString = r.Replace(hexString, "")

    return hexString
END FUNCTION

' Quantcast specific hash function
FUNCTION qcmsrmt_HashFunc(inKey AS INTEGER, inString AS STRING) AS DOUBLE

    inDoub# = inKey
    FOR i = 0 TO inString.Len()-1 STEP 1
        character = ASC(inString.Mid(i, 1))
        h32% = qcmsrmt_doubleToInt(inDoub#)
        h32% = qcmsrmt_BitwiseXOR(h32%, character)
        inDoub# = h32%
        inDoub# = inDoub# + qcmsrmt_ShiftLeft(h32%, 1)+qcmsrmt_ShiftLeft(h32%, 4)+qcmsrmt_ShiftLeft(h32%, 7)+qcmsrmt_ShiftLeft(h32%, 8)+qcmsrmt_ShiftLeft(h32%, 24)

    END FOR

    return inDoub#
END FUNCTION

'casting from floating point to integer does not truncate.  Instead rounds to the largest number that will fit,
'so if it overflows your stuck with the MAX INT value.  This method truncates the double properly
FUNCTION qcmsrmt_doubleToInt(initNum AS DOUBLE) AS INTEGER

    retval% = 0
    sign = SGN(initNum)
 
    'much easier to work with positive bit pattern, we'll also do it manually since ABS demotes me to a float
    IF sign < 0
       initNum = initNum *-1
    END IF
    
    'truncate the upper bits of the double
    initNum = qcmsrmt_removeUpper32Bits(initNum)
    
    'still bigger than max int, ie. the MSB is on so additional work required
    IF(initNum >= 2147483647) 
       'remove the MSB and cast down to integer, again to prevent MAX_INTEGER
        retval% = initNum - 2147483648!
        ' now put the bit back on again
        retval% = retval% OR &H80000000
    ELSE 
        retval% = retval% OR initNum
    END IF
    
    'if it was negavive then twos complement to convert 32-bit number back to negative
    IF(sign < 0)
        'first toggle all the bits
         retval% = not retval%
        'finally add one because two's complement
         retval% = retval% + 1
    END IF

    return retval%
END Function

'progamatically lop off all the top bits if there are any. No shifting and we cant cast a it off so lets brute force it
FUNCTION qcmsrmt_removeUpper32Bits(initNum AS DOUBLE) as DOUBLE
    'short curcuit if we dont need to loop
    IF initNum >= 2.0^32
        FOR i = 63 TO 32 STEP -1
            IF initNum >= 2.0^i  
                initNum = initNum - (2.0^i)
            END IF
        END FOR
    END IF
    return initNum
END FUNCTION

'No built in shifting.  So fake it by multiplying by 2.  WARNING: This wont shift negative numbers properly
FUNCTION qcmsrmt_ShiftLeft(initNum AS INTEGER, shiftAmount AS INTEGER) AS INTEGER
    return (initNum * (2 ^ shiftAmount))
END FUNCTION

'no xor so manually do it using ORs and Ands
FUNCTION qcmsrmt_BitwiseXOR(val1 AS INTEGER, val2 AS INTEGER) AS INTEGER
    bitwiseAnd% = val1 AND val2
    bitwiseOr% = val1 OR val2
    return bitwiseOr% and not bitwiseAnd%
END FUNCTION

'surprise, no rounding either so add .5 which will bump values that should be rounded up to next int
FUNCTION qcmsrmt_Round(initNum AS DOUBLE) as INTEGER    
    IF initNum > 0
        initNum = initNum + 0.5
    ELSE
        initNum = initNum - 0.5
    END IF
    return qcmsrmt_doubleToInt(initNum)
END FUNCTION

'adds an integer to a byte array.  Handles Negative numbers as unsigned
SUB qcmsrmt_addIntegerToByteArray(byteArray AS Object, initNum AS INTEGER)

    sign = SGN(initNum)
    'removing the MSB for now so I can do positive integer math
    IF sign < 0
        initNum = initNum AND &H7FFFFFFF
    END IF
    
    'plus always do double precision math because when .99 happens it really messes things up
    byteArray.Unshift(initNum) : initNum = initNum/256#
    'now we can put the removed bit back but shifted
    if sign < 0
             initNum = initNum OR &H00800000
    END IF
    byteArray.Unshift(initNum) : initNum = initNum/256#
    byteArray.Unshift(initNum) : initNum = initNum/256#
    byteArray.Unshift(initNum) : initNum = initNum/256#
END SUB

'creates a UUID following RFC 4122 version 4
Function qcmsrmt_CreateUUID() AS STRING
'first generate 16 random bytes
    ba = CreateObject("roByteArray")
    ba.setresize(16, false)
    FOR i = 0 TO 16 STEP 1
        random = RND(255)
        ba[i] = random   'only takes the least signnificant byte
    END FOR
    
    'next change the MSBs on the 7th byte to 0100
    ba[6] = &H40 OR (ba[6] AND &HF)
    
    'now change the MSBs on the 9th byte to 10
    ba[8] = &H80 OR (ba[8] AND &H3f)
    
    'change to a Hex String
    hexVal = ba.ToHexString()
    
    'insert the hypens to make 8,4,4,4,12
    retval = hexVal.Left(8) + "-" + hexVal.Mid(8, 4) + "-" + hexVal.Mid(12, 4) + "-" + hexVal.Mid(16, 4) + "-" + hexVal.Mid(20)
    
    return retval
    
END FUNCTION

'create a uuid and store it to disk.
FUNCTION qcmsrmt_GetAppInstallId() AS STRING
    sec = CreateObject("roRegistrySection", "QCPersistKeys")
    IF sec.Exists("AppInstallId")
        appInstallId = sec.Read("AppInstallId")
    ELSE
        appInstallId = qcmsrmt_CreateUUID()
        sec.Write("AppInstallId", appInstallId)
    ENDIF
    sec.Flush()
    return appInstallId
END FUNCTION






