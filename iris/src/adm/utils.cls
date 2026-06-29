Class adm.utils Extends %RegisteredObject
{

Parameter NAMESPACESLISTQUERY = "SELECT Nsp FROM %SYS.Namespace_List() WHERE remote = 0 AND status = 1";

/// Generic interoperability role names (suffixed so they never collide with the test user names)
Parameter VIEWERROLE = "Interop_Viewer_Role";

Parameter OPERATORROLE = "Interop_Operator_Role";

/// Interoperability resource grants for the read-only viewer profile (USE only).
Parameter ENSVIEWERRESOURCES = "%Ens_Portal:U,%Ens_MessageHeader:U,%Ens_MessageContent:U,%Ens_Alerts:U,%Ens_Queues:U,%Ens_ProductionConfig:U";

/// Interoperability resource grants for the operator profile:
/// viewer rights + start/stop business hosts (BS/BP/BO/routers) + job control + lookup table editing.
/// %Ens_ConfigItemRun grants start/stop/enable/disable of individual config items from the
/// Production Configuration page (%Ens_ProductionRun only covers the whole production).
Parameter ENSOPERATORRESOURCES = "%Ens_Portal:U,%Ens_MessageHeader:U,%Ens_MessageContent:U,%Ens_Alerts:U,%Ens_Queues:U,%Ens_ProductionConfig:U,%Ens_ProductionRun:U,%Ens_ConfigItemRun:U,%Ens_Jobs:U,%Ens_LookupTables:U";

/// Database that stores the Ens.LookupTable global (mapped to every namespace in this repo).
Parameter LOOKUPTABLEDB = "COMMON_DATA";

/// Read access to the non-public code databases that hold the Management Portal and
/// HealthShare interoperability pages. Without these the portal returns "ERROR #822: Access Denied"
/// because /csp/sys carries no MatchRoles to auto-grant them. (ENSLIB/HSLIB/IRISLIB are already public.)
Parameter PORTALRESOURCES = "%DB_IRISSYS:R,%DB_HSSYS:R,%DB_HSCUSTOM:R";

/// Temporary password assigned to freshly created test users (must be changed on first use).
Parameter DEFAULTTESTPASSWORD = "Interop@Train2026!";

ClassMethod ListInteropNamespaces() As %Status
{
    Set tSC = $$$OK

    Try {
        Set tSQL = ..#NAMESPACESLISTQUERY
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, tSQL)

        While tRS.%Next() {
            Set tNamespace = tRS.%Get("Nsp")
            Continue:..IsExcludedInteropNamespace(tNamespace)
            Continue:'##class(%EnsembleMgr).IsEnsembleNamespace(tNamespace)
            Write !,"[",tNamespace,"] Status: interop namespace",!
        }
    }
    Catch tException {
        Set tSC = tException.AsStatus()
    }

    Return tSC
}

ClassMethod IsSystemNamespace(pNamespace As %String) As %Boolean
{
    Set isSystem = 0
    
    Do ##class(%SYS.Namespace).GetNSInfo(pNamespace, .tInfo, 1)
    Set tGlobalDB = $Get(tInfo("Directory"))

    If tGlobalDB '= "" {
        Set ns = $NAMESPACE
        ZN "%SYS"
        If ##class(SYS.Database).IsSystemDB(tGlobalDB) {
            Set isSystem = 1
        }
        ZN ns
    }
    
    Quit isSystem
}

ClassMethod IsExcludedInteropNamespace(pNamespace As %String) As %Boolean
{
    // Explicit exclusions for HealthShare / Health Connect
    If $ListFind($ListBuild("HSCUSTOM","HSSYS","HSLIB"), pNamespace) {
        Quit 1
    }

    // Optional: exclude all technical namespaces starting with HS
    If $Extract(pNamespace,1,2) = "HS" {
        Quit 1
    }

    Quit 0
}

ClassMethod RecoverAllProductions() As %Status
{
    Set tSC = $$$OK
    
    Try {
        Set tSQL = ..#NAMESPACESLISTQUERY
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, tSQL)
        Set i = 0
        
        While tRS.%Next() {
            Set tNamespace = tRS.%Get("Nsp")
            Continue:..IsExcludedInteropNamespace(tNamespace)
            Continue:'##class(%EnsembleMgr).IsEnsembleNamespace(tNamespace)
            
            Set i = i + 1
            Write !,i," Checking namespace: ",tNamespace,!
            Set tProductionStatus = ..GetProductionStatus(tNamespace)
            Write !,"[",tNamespace,"] Status: ",tProductionStatus,!
            
            If tProductionStatus = "need recover" {
                Write !,"[",tNamespace,"] Status: NEED RECOVER - Executing Recover...",!
                Set tRecoverSC = ..RecoverProduction(tNamespace)
                If $$$ISERR(tRecoverSC) {
                    Write !,"ERROR during Recover on ",tNamespace,": ",$System.Status.GetErrorText(tRecoverSC),!
                    Set tSC = $$$ADDSC(tSC, tRecoverSC)
                } Else {
                    Write !,"[",tNamespace,"] Recover executed successfully",!
                }
            } Else {
                Write !,"[",tNamespace,"] Status: OK (no Recover needed)",!
            }
        }
    }
    Catch tException {
        Set tSC = tException.AsStatus()
    }

    Return tSC
}

ClassMethod GetProductionStatus(pNamespace As %String) As %String
{
    Set tStatus = "unknown"
    
    Try {
        Set tCurrentNS = $Namespace
        New $Namespace
        Set $Namespace = pNamespace
        
        Set tSC = ##class(Ens.Director).GetProductionStatus(.tProductionName, .tProductionState)
        Write !,"[",pNamespace,"] Production Name: ",tProductionName," State: ",tProductionState,!
        
        // Map state integer to status string
        // 1=Running, 2=Stopped, 3=Suspended, 4=Troubled(needs recover)
        If tProductionState = 1 {
            Set tStatus = "running"
        } ElseIf tProductionState = 2 {
            Set tStatus = "stopped"
        } ElseIf tProductionState = 3 {
            Set tStatus = "suspended"
        } ElseIf tProductionState = 4 {
            Set tStatus = "need recover"
        } Else {
            Set tStatus = "unknown"
        }
        
        Set $Namespace = tCurrentNS
    }
    Catch tException {
        Set $Namespace = tCurrentNS
    }
    
    Return tStatus
}

ClassMethod GetProductionState(pNamespace As %String) As %Integer
{
    Set tState = 0

    Try {
        Set tCurrentNS = $Namespace
        New $Namespace
        Set $Namespace = pNamespace

        Do ##class(Ens.Director).GetProductionStatus(.tProductionName, .tProductionState)
        Set tState = +tProductionState

        Set $Namespace = tCurrentNS
    }
    Catch tException {
        Set $Namespace = tCurrentNS
    }

    Return tState
}

ClassMethod RecoverProduction(pNamespace As %String) As %Status
{
    Set tSC = $$$OK
    
    Try {
        Set tCurrentNS = $Namespace
        New $Namespace
        Set $Namespace = pNamespace
        
        Set tSC = ##class(Ens.Director).RecoverProduction()
        
        Set $Namespace = tCurrentNS
    }
    Catch tException {
        Set tSC = tException.AsStatus()
    }
    
    Return tSC
}

ClassMethod StartProduction(pNamespace As %String) As %Status
{
    Set tSC = $$$OK
    
    Try {
        Set tCurrentNS = $Namespace
        New $Namespace
        Set $Namespace = pNamespace
        
        Set tSC = ##class(Ens.Director).StartProduction()
        
        Set $Namespace = tCurrentNS
    }
    Catch tException {
        Set tSC = tException.AsStatus()
    }
    
    Return tSC
}

ClassMethod StopProduction(pNamespace As %String, pTimeout As %Integer = 0, pForce As %Boolean = 1) As %Status
{
    Set tSC = $$$OK
    
    Try {
        Set tCurrentNS = $Namespace
        New $Namespace
        Set $Namespace = pNamespace
        
        Set tSC = ##class(Ens.Director).StopProduction(pTimeout, pForce)
        
        Set $Namespace = tCurrentNS
    }
    Catch tException {
        Set tSC = tException.AsStatus()
    }
    
    Return tSC
}

ClassMethod CleanProduction(pNamespace As %String, pKillData As %Boolean = 0) As %Status
{
    Set tSC = $$$OK
    
    Try {
        Set tCurrentNS = $Namespace
        New $Namespace
        Set $Namespace = pNamespace
        
        Set tSC = ##class(Ens.Director).CleanProduction(pKillData)
        
        Set $Namespace = tCurrentNS
    }
    Catch tException {
        Set tSC = tException.AsStatus()
    }
    
    Return tSC
}

ClassMethod StartAllProductions() As %Status
{
    Set tSC = $$$OK
    
    Try {
        Set tSQL = ..#NAMESPACESLISTQUERY
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, tSQL)
        Set i = 0
        
        While tRS.%Next() {
            Set tNamespace = tRS.%Get("Nsp")
            Continue:..IsExcludedInteropNamespace(tNamespace)
            Continue:'##class(%EnsembleMgr).IsEnsembleNamespace(tNamespace)
            
            Set i = i + 1
            Write !,i," Starting namespace: ",tNamespace,!
            // Check if a production is already running before attempting start
            Set tPriorState = ..GetProductionState(tNamespace)
            If tPriorState = 1 {
                Write !,"[",tNamespace,"] Already running (start not needed)",!
                Continue
            }
            Set tStartSC = ..StartProduction(tNamespace)
            If $$$ISERR(tStartSC) {
                Write !,"ERROR starting production on ",tNamespace,!
                Set tSC = $$$ADDSC(tSC, tStartSC)
            } Else {
                Write !,"[",tNamespace,"] Started successfully",!
            }        }
    }
    Catch tException {
        Set tSC = tException.AsStatus()
    }

    Return tSC
}

ClassMethod StopAllProductions(pTimeout As %Integer = 0, pForce As %Boolean = 1) As %Status
{
    Set tSC = $$$OK
    
    Try {
        Set tSQL = ..#NAMESPACESLISTQUERY
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, tSQL)
        Set i = 0
        
        While tRS.%Next() {
            Set tNamespace = tRS.%Get("Nsp")
            Continue:..IsExcludedInteropNamespace(tNamespace)
            Continue:'##class(%EnsembleMgr).IsEnsembleNamespace(tNamespace)
            
            Set i = i + 1
            Write !,i," Stopping namespace: ",tNamespace,!
            // Check if a production is already stopped before attempting stop
            Set tPriorState = ..GetProductionState(tNamespace)
            If tPriorState '= 1 {
                Write !,"[",tNamespace,"] Already stopped (stop not needed)",!
                Continue
            }
            Set tStopSC = ..StopProduction(tNamespace, pTimeout, pForce)
            If $$$ISERR(tStopSC) {
                Write !,"ERROR stopping production on ",tNamespace,!
                Set tSC = $$$ADDSC(tSC, tStopSC)
            } Else {
                Write !,"[",tNamespace,"] Stopped successfully",!
            }
        }
    }
    Catch tException {
        Set tSC = tException.AsStatus()
    }

    Return tSC
}

ClassMethod CleanAllProductions(pKillData As %Boolean = 0) As %Status
{
    Set tSC = $$$OK
    
    Try {
        Set tSQL = ..#NAMESPACESLISTQUERY
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, tSQL)
        Set i = 0
        
        While tRS.%Next() {
            Set tNamespace = tRS.%Get("Nsp")
            Continue:..IsExcludedInteropNamespace(tNamespace)
            Continue:'##class(%EnsembleMgr).IsEnsembleNamespace(tNamespace)
            
            Set i = i + 1
            Write !,i," Cleaning namespace: ",tNamespace,!
            Set tCleanSC = ..CleanProduction(tNamespace, pKillData)
            If $$$ISERR(tCleanSC) {
                Write !,"ERROR cleaning production on ",tNamespace,!
                Set tSC = $$$ADDSC(tSC, tCleanSC)
            } Else {
                Write !,"[",tNamespace,"] Cleaned successfully",!
            }
        }
    }
    Catch tException {
        Set tSC = tException.AsStatus()
    }

    Return tSC
}

ClassMethod ListRecentMLLPHTTPMessages(pMinDays As %Integer = 0, pMaxDays As %Integer = 0) As %Status
{
    Set tSC = $$$OK

    Try {
        Set tSQL = ..#NAMESPACESLISTQUERY
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, tSQL)
        Set i = 0

        While tRS.%Next() {
            Set tNamespace = tRS.%Get("Nsp")
            Continue:..IsExcludedInteropNamespace(tNamespace)
            Continue:'##class(%EnsembleMgr).IsEnsembleNamespace(tNamespace)

            Set i = i + 1
            Write !,i," Checking namespace: ",tNamespace,!
            Set tCount = ..GetRecentMLLPHTTPMessages(tNamespace, pMinDays, pMaxDays)
            Write !,"[",tNamespace,"] Status: ",tCount," recent MLLP/HTTP messages",!
        }
    }
    Catch tException {
        Set tSC = tException.AsStatus()
    }

    Return tSC
}

ClassMethod GetRecentMLLPHTTPMessages(pNamespace As %String, pMinDays As %Integer = 0, pMaxDays As %Integer = 0) As %Integer
{
    Set tCount = 0

    Try {
        Set tCurrentNS = $Namespace
        New $Namespace
        Set $Namespace = pNamespace

        // Count MLLP (TCP) or HTTP messages within a day-window.
        // pMinDays: most recent bound (0=today). pMaxDays: oldest bound.
        // A value of -1 means unbounded on that side.
        Set tWhere = ""
        If (pMaxDays '= -1) {
            Set tWhere = tWhere_"AND TimeCreated >= DATEADD('day', -"_(+pMaxDays)_", CURRENT_DATE) "
        }
        If (pMinDays '= -1) {
            Set tWhere = tWhere_"AND TimeCreated < DATEADD('day', "_(1-pMinDays)_", CURRENT_DATE) "
        }

        Set tQuery = "SELECT COUNT(*) AS Cnt FROM Ens.MessageHeader "
            _"WHERE 1=1 "_tWhere
            _"AND SourceConfigName IN ("
            _"SELECT Name FROM Ens_Config.Item "
            _"WHERE UPPER(ClassName) [ 'TCP' OR UPPER(ClassName) [ 'MLLP' OR UPPER(ClassName) [ 'HTTP')"

        Set tStmt = ##class(%SQL.Statement).%New()
        Set tStatus = tStmt.%Prepare(tQuery)
        If $$$ISOK(tStatus) {
            Set tMsgRS = tStmt.%Execute()
            If tMsgRS.%Next() {
                Set tCount = tMsgRS.%Get("Cnt")
            }
        }

        Set $Namespace = tCurrentNS
    }
    Catch tException {
        Set $Namespace = tCurrentNS
    }

    Return tCount
}

ClassMethod ListUsersLastAudit(pN As %Integer = 5) As %Status
{
    Set tSC = $$$OK
    If (pN = "") || (pN < 1) { Set pN = 5 }

    Try {
        Set tCurrentNS = $Namespace
        New $Namespace
        Set $Namespace = "%SYS"

        // Iterate users defined in Security.Users
        Set tUserQuery = "SELECT Name FROM Security.Users ORDER BY Name"
        Set tUStmt = ##class(%SQL.Statement).%New()
        Set tUStatus = tUStmt.%Prepare(tUserQuery)
        If $$$ISOK(tUStatus) {
            Set tURS = tUStmt.%Execute()
            While tURS.%Next() {
                Set tUser = tURS.%Get("Name")

                // Last pN audit events for this user (most recent first)
                Set tEvQuery = "SELECT TOP ? UTCTimeStamp, EventSource, EventType, Event, Description "
                    _"FROM %SYS.Audit WHERE UserName = ? ORDER BY UTCTimeStamp DESC"
                Set tEStmt = ##class(%SQL.Statement).%New()
                Set tEStatus = tEStmt.%Prepare(tEvQuery)
                Set tLast = ""
                Set tHasEvents = 0
                If $$$ISOK(tEStatus) {
                    Set tERS = tEStmt.%Execute(pN, tUser)
                    While tERS.%Next() {
                        Set tHasEvents = 1
                        Set tTs = tERS.%Get("UTCTimeStamp")
                        If tLast = "" { Set tLast = tTs }
                        Set tEvtName = tERS.%Get("EventSource")_"/"_tERS.%Get("EventType")_"/"_tERS.%Get("Event")
                        Set tDesc = tERS.%Get("Description")
                        If tDesc = "" { Set tDesc = tEvtName }
                        Else { Set tDesc = tEvtName_" - "_tDesc }
                        // Flatten any line breaks / pipes so report tables stay intact
                        Set tDesc = $Replace($Replace($Replace(tDesc, $Char(13), " "), $Char(10), " "), "|", "/")
                        Write !,"[",tUser,"] Event: ",tTs," :: ",tDesc,!
                    }
                }

                If 'tHasEvents { Set tLast = "never" }
                Write !,"[",tUser,"] Status: ",tLast," last action",!
            }
        }

        Set $Namespace = tCurrentNS
    }
    Catch tException {
        Set $Namespace = tCurrentNS
        Set tSC = tException.AsStatus()
    }

    Return tSC
}

/// List every user defined in Security.Users with their enabled state and roles.
ClassMethod ListUsers() As %Status
{
    Set tSC = $$$OK

    Try {
        Set tCurrentNS = $Namespace
        New $Namespace
        Set $Namespace = "%SYS"

        Set tQuery = "SELECT Name FROM Security.Users ORDER BY Name"
        Set tStmt = ##class(%SQL.Statement).%New()
        Set tStatus = tStmt.%Prepare(tQuery)
        If $$$ISOK(tStatus) {
            Set tRS = tStmt.%Execute()
            While tRS.%Next() {
                Set tUser = tRS.%Get("Name")
                Set tGetSC = ##class(Security.Users).Get(tUser, .tProps)
                Continue:$$$ISERR(tGetSC)

                Set tEnabled = +$Get(tProps("Enabled"))
                Set tRoles = $Replace($Get(tProps("Roles")), "|", "/")
                Set tFull = $Replace($Get(tProps("FullName")), "|", "/")

                Write !,"[",tUser,"] Status: ",$Select(tEnabled:"enabled", 1:"disabled"),!
                Write !,"[",tUser,"] Roles: ",$Select(tRoles="":"(none)", 1:tRoles),!
                Write:tFull'="" !,"[",tUser,"] FullName: ",tFull,!
            }
        }

        Set $Namespace = tCurrentNS
    }
    Catch tException {
        Set $Namespace = tCurrentNS
        Set tSC = tException.AsStatus()
    }

    Return tSC
}

/// Create (or update) all interoperability security profiles and their test users.
/// Profiles:
///   - Admin (%All): Sylvain and Training only
///   - Interop_Viewer: generic read-only access (test user: interop_viewer)
///   - Interop_Operator: read + start/stop hosts + edit lookup tables (test user: interop_operator)
/// pPassword is the temporary password assigned to any user that has to be created.
ClassMethod SetupInteropProfiles(pPassword As %String = {..#DEFAULTTESTPASSWORD}) As %Status
{
    Set tSC = $$$OK

    // 1. Generic roles
    Set tSC = $$$ADDSC(tSC, ..CreateInteropViewerRole())
    Set tSC = $$$ADDSC(tSC, ..CreateInteropOperatorRole())

    // 2. Admin accounts (full %All) - Sylvain and Training only
    Set tSC = $$$ADDSC(tSC, ..EnsureAdminUser("Sylvain", pPassword))
    Set tSC = $$$ADDSC(tSC, ..EnsureAdminUser("Training", pPassword))

    // 3. Test users bound to the generic roles
    Set tSC = $$$ADDSC(tSC, ..EnsureUserWithRole("interop_viewer", ..#VIEWERROLE, pPassword))
    Set tSC = $$$ADDSC(tSC, ..EnsureUserWithRole("interop_operator", ..#OPERATORROLE, pPassword))

    Return tSC
}

/// Create/update the read-only viewer role: read access to interop databases + USE on viewing resources.
ClassMethod CreateInteropViewerRole() As %Status
{
    Set tSC = $$$OK
    Try {
        Set tCurrentNS = $Namespace
        New $Namespace
        Set $Namespace = "%SYS"

        Set tRes = ..FilterExistingResources(..BuildInteropDBResources("R", "R"))
        Set tEns = ..FilterExistingResources(..#ENSVIEWERRESOURCES)
        If tEns '= "" { Set tRes = tRes_$Select(tRes="":"", 1:",")_tEns }
        Set tPortal = ..FilterExistingResources(..#PORTALRESOURCES)
        If tPortal '= "" { Set tRes = tRes_$Select(tRes="":"", 1:",")_tPortal }

        Set tSC = ..CreateOrUpdateRole(..#VIEWERROLE, "Interop generic read-only viewer", tRes)

        Set $Namespace = tCurrentNS
    }
    Catch tException {
        Set $Namespace = tCurrentNS
        Set tSC = tException.AsStatus()
    }
    Return tSC
}

/// Create/update the operator role: viewer rights + start/stop hosts + edit lookup tables (write on COMMON_DATA).
ClassMethod CreateInteropOperatorRole() As %Status
{
    Set tSC = $$$OK
    Try {
        Set tCurrentNS = $Namespace
        New $Namespace
        Set $Namespace = "%SYS"

        // RW on the lookup-table database so lookup tables can be edited
        Set tRes = ..FilterExistingResources(..BuildInteropDBResources("R", "RW"))
        Set tEns = ..FilterExistingResources(..#ENSOPERATORRESOURCES)
        If tEns '= "" { Set tRes = tRes_$Select(tRes="":"", 1:",")_tEns }
        Set tPortal = ..FilterExistingResources(..#PORTALRESOURCES)
        If tPortal '= "" { Set tRes = tRes_$Select(tRes="":"", 1:",")_tPortal }

        Set tSC = ..CreateOrUpdateRole(..#OPERATORROLE, "Interop operator: read + start/stop hosts + edit lookup tables", tRes)

        Set $Namespace = tCurrentNS
    }
    Catch tException {
        Set $Namespace = tCurrentNS
        Set tSC = tException.AsStatus()
    }
    Return tSC
}

/// Build a candidate "resource:permission" list granting access to every interop namespace database.
/// pNsPerm    = permission on each interop namespace DATA database (CODE is always read-only)
/// pCommonPerm = permission on the shared COMMON_DATA database (where lookup tables live)
/// The returned list is NOT existence-checked (call FilterExistingResources on it).
ClassMethod BuildInteropDBResources(pNsPerm As %String = "R", pCommonPerm As %String = "R") As %String
{
    // Shared COMMON databases first (Ens.LookupTable global is mapped from COMMON_DATA)
    Set tList = "%DB_COMMON_DATA:"_pCommonPerm_",%DB_COMMON_CODE:R"

    Set tSQL = ..#NAMESPACESLISTQUERY
    Set tRS = ##class(%SQL.Statement).%ExecDirect(, tSQL)
    While tRS.%Next() {
        Set tNamespace = tRS.%Get("Nsp")
        Continue:..IsExcludedInteropNamespace(tNamespace)
        Continue:'##class(%EnsembleMgr).IsEnsembleNamespace(tNamespace)
        Continue:(tNamespace = "COMMON")
        Set tList = tList_",%DB_"_tNamespace_"_DATA:"_pNsPerm_",%DB_"_tNamespace_"_CODE:R"
    }

    Return tList
}

/// Keep only the entries of a "resource:permission,..." list whose resource actually exists.
/// Prevents role creation from failing on a non-existent resource. Must run in %SYS.
ClassMethod FilterExistingResources(pResourceList As %String) As %String
{
    Set tOut = ""
    For i = 1:1:$Length(pResourceList, ",") {
        Set tEntry = $Piece(pResourceList, ",", i)
        Continue:(tEntry = "")
        Set tResource = $Piece(tEntry, ":", 1)
        If ##class(Security.Resources).Exists(tResource) {
            Set tOut = tOut_$Select(tOut="":"", 1:",")_tEntry
        }
    }
    Return tOut
}

/// Create a role if missing, otherwise update its description and resources. Must run in %SYS.
ClassMethod CreateOrUpdateRole(pName As %String, pDescription As %String, pResources As %String) As %Status
{
    If ##class(Security.Roles).Exists(pName) {
        Set tSC = ##class(Security.Roles).Get(pName, .tProps)
        Quit:$$$ISERR(tSC) tSC
        Set tProps("Description") = pDescription
        Set tProps("Resources") = pResources
        Set tSC = ##class(Security.Roles).Modify(pName, .tProps)
        If $$$ISOK(tSC) { Write !,"[",pName,"] Status: role updated",! }
    }
    Else {
        Set tSC = ##class(Security.Roles).Create(pName, pDescription, pResources)
        If $$$ISOK(tSC) { Write !,"[",pName,"] Status: role created",! }
    }
    If $$$ISERR(tSC) {
        Write !,"[",pName,"] Status: ERROR ",$System.Status.GetErrorText(tSC),!
    }
    Return tSC
}

/// Ensure an administrator account exists with the %All role. Creates it with pPassword when missing.
ClassMethod EnsureAdminUser(pUser As %String, pPassword As %String = {..#DEFAULTTESTPASSWORD}) As %Status
{
    Return ..EnsureUserWithRole(pUser, "%All", pPassword, 1)
}

/// Ensure a user exists and carries pRole. Creates it with pPassword when missing, otherwise adds the role.
/// pAdmin marks the account as an administrator (only affects the generated full name / comment).
ClassMethod EnsureUserWithRole(pUser As %String, pRole As %String, pPassword As %String = {..#DEFAULTTESTPASSWORD}, pAdmin As %Boolean = 0) As %Status
{
    Set tSC = $$$OK
    Try {
        Set tCurrentNS = $Namespace
        New $Namespace
        Set $Namespace = "%SYS"

        If ##class(Security.Users).Exists(pUser) {
            Set tSC = ##class(Security.Users).Get(pUser, .tProps)
            If $$$ISOK(tSC) {
                Set tRoles = $Get(tProps("Roles"))
                If '..RoleInList(pRole, tRoles) {
                    Set tProps("Roles") = $Select(tRoles="":pRole, 1:tRoles_","_pRole)
                    Set tSC = ##class(Security.Users).Modify(pUser, .tProps)
                    If $$$ISOK(tSC) { Write !,"[",pUser,"] Status: role ",pRole," added",! }
                }
                Else {
                    Write !,"[",pUser,"] Status: role ",pRole," already present",!
                }
            }
        }
        Else {
            Set tFullName = pUser_$Select(pAdmin:" (Admin)", 1:" (Test)")
            Set tSC = ##class(Security.Users).Create(pUser, pRole, pPassword, tFullName)
            If $$$ISOK(tSC) { Write !,"[",pUser,"] Status: user created with role ",pRole,! }
        }

        If $$$ISERR(tSC) {
            Write !,"[",pUser,"] Status: ERROR ",$System.Status.GetErrorText(tSC),!
        }

        Set $Namespace = tCurrentNS
    }
    Catch tException {
        Set $Namespace = tCurrentNS
        Set tSC = tException.AsStatus()
    }
    Return tSC
}

/// Return 1 if pRole appears in the comma-separated role list pCsv.
ClassMethod RoleInList(pRole As %String, pCsv As %String) As %Boolean
{
    For i = 1:1:$Length(pCsv, ",") {
        Return:($ZStrip($Piece(pCsv, ",", i), "<>W") = pRole) 1
    }
    Return 0
}

}
