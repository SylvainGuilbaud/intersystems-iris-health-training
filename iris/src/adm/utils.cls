Class adm.utils Extends %RegisteredObject
{

Parameter NAMESPACESLISTQUERY = "SELECT Nsp FROM %SYS.Namespace_List() WHERE remote = 0 AND status = 1";

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
            Write tNamespace,!
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
            Set tStartSC = ..StartProduction(tNamespace)
            If $$$ISERR(tStartSC) {
                Write !,"ERROR starting production on ",tNamespace,!
                Set tSC = $$$ADDSC(tSC, tStartSC)
            } Else {
                Write !,"[",tNamespace,"] Started successfully",!
            }
        }
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

ClassMethod ListUsersLastAudit() As %Status
{
    Set tSC = $$$OK

    Try {
        Set tCurrentNS = $Namespace
        New $Namespace
        Set $Namespace = "%SYS"

        // Last audit action timestamp per user defined in Security.Users
        Set tQuery = "SELECT u.Name AS Name, MAX(a.UTCTimeStamp) AS LastAction "
            _"FROM Security.Users u "
            _"LEFT JOIN %SYS.Audit a ON a.UserName = u.Name "
            _"GROUP BY u.Name ORDER BY u.Name"

        Set tStmt = ##class(%SQL.Statement).%New()
        Set tStatus = tStmt.%Prepare(tQuery)
        If $$$ISOK(tStatus) {
            Set tRS = tStmt.%Execute()
            While tRS.%Next() {
                Set tUser = tRS.%Get("Name")
                Set tLast = tRS.%Get("LastAction")
                If tLast = "" { Set tLast = "never" }
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

}
