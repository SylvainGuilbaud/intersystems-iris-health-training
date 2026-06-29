Class adm.py.utils Extends %RegisteredObject
{

Parameter NAMESPACESLISTQUERY =   "SELECT Nsp FROM %SYS.Namespace_List() WHERE remote = 0 AND status = 1";

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
    
    set tGlobalDB="",isSystem=0
    do ##class(%SYS.Namespace).GetNSInfo(pNamespace, .tInfo, 1)

    Set tGlobalDB = $Get(tInfo("Directory"))

    if tGlobalDB'="" {
        set ns = $NAMESPACE
        zn "%SYS"
        If ##class(SYS.Database).IsSystemDB(tGlobalDB) {
            set isSystem = 1
        }
        zn ns
    }

    Quit isSystem
}
ClassMethod IsExcludedInteropNamespace(pNamespace As %String) As %Boolean
{
    Set pNamespace = $ZCONVERT(pNamespace, "U")

    // Explicit exclusions for HealthShare / Health Connect
    If $ListFind($ListBuild("HSCUSTOM","HSSYS","HSLIB"), pNamespace) {
        Quit 1
    }

    // Optional: exclude all technical namespaces starting with HS
    // Warning: use only if application namespaces never start with HS
    If $Extract(pNamespace,1,2)="HS" {
        Quit 1
    }

    Quit 0
}

/// Retrieve all Interop namespaces and execute a Recover
/// on those that have "need recover" status
ClassMethod RecoverAllProductions() As %Status
{
    Set tSC = $$$OK
    
    Try {
        // Get all namespaces
        Set tSQL = ..#NAMESPACESLISTQUERY
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, tSQL)
        
        While tRS.%Next() {
            Set tNamespace = tRS.%Get("Nsp")
            Continue:(..IsExcludedInteropNamespace(tNamespace) || ..IsSystemNamespace(tNamespace))
            
            // Check if this is an Interop namespace
            If ##class(%EnsembleMgr).IsEnsembleNamespace(tNamespace){
                write !,$INCREMENT(i)," Checking namespace: ",tNamespace,!
                Set tProductionStatus = ..GetProductionStatus(tNamespace)
                write !,"[",tNamespace,"] Status: ",tProductionStatus,!
                If tProductionStatus = "need recover" {
                    Write !,"[",tNamespace,"] Status: NEED RECOVER - Executing Recover..."
                    
                    // Execute the Recover
                    Set tRecoverSC = ..RecoverProduction(tNamespace)
                    If $$$ISERR(tRecoverSC) {
                        Write !,"ERROR during Recover on ",tNamespace,": ",$System.Status.GetErrorText(tRecoverSC)
                        Set tSC = $$$ADDSC(tSC, tRecoverSC)
                    } Else {
                        Write !,"[",tNamespace,"] Recover executed successfully"
                    }
                } Else {
                    Write !,"[",tNamespace,"] Status: OK (no Recover needed)"
                }
            }
        }
    }
    Catch tException {
        Set tSC = tException.AsStatus()
    }
    
    Return tSC
}

/// Retrieve the Recover status of a namespace
ClassMethod GetProductionStatus(pNamespace As %String) As %String
{
    Set tStatus = "unknown"
    
    Try {
        // Connect to the namespace
        Set tCurrentNS = $Namespace
        New $Namespace
        Set $Namespace = pNamespace
        
        // Get production status using Ens.Director.GetProductionStatus()
        // Returns status via output parameters: pProductionName and pState
        Set tSC = ##class(Ens.Director).GetProductionStatus(.tProductionName, .tProductionState)
        write !,"[",pNamespace,"] Production Name: ",tProductionName," State: ",tProductionState,!
        If $$$ISERR(tSC) {
            Set tStatus = "error checking status"
        } Else {
            // Map state values to status strings
            // pState values: 1=Running, 2=Stopped, 3=Suspended, 4=Troubled (needs recover)
            If tProductionState = 4 {
                // eProductionStateTroubled = production needs recover
                Set tStatus = "need recover"
            } ElseIf tProductionState = 1 {
                // eProductionStateRunning
                Set tStatus = "running"
            } ElseIf tProductionState = 2 {
                // eProductionStateStopped
                Set tStatus = "stopped"
            } ElseIf tProductionState = 3 {
                // eProductionStateSuspended
                Set tStatus = "suspended"
            } Else {
                Set tStatus = "unknown state"
            }
        }
        
        // Restore to initial namespace
        Set $Namespace = tCurrentNS
    }
    Catch tException {
        Write !,"ERROR GetProductionStatus [",pNamespace,"]: ",$System.Status.GetErrorText(tException.AsStatus())
    }
    
    Return tStatus
}

/// Execute Recover on a namespace
ClassMethod RecoverProduction(pNamespace As %String) As %Status
{
    Set tSC = $$$OK
    
    Try {
        Set tCurrentNS = $Namespace
        New $Namespace
        Set $Namespace = pNamespace
        
        // Execute Recover via Ens.Director
        Set tSC = ##class(Ens.Director).RecoverProduction()
        
        Set $Namespace = tCurrentNS
    }
    Catch tException {
        Set tSC = tException.AsStatus()
    }
    
    Return tSC
}


/// Start Production on a namespace
ClassMethod StartProduction(pNamespace As %String) As %Status
{
    Set tSC = $$$OK
    
    Try {
        Set tCurrentNS = $Namespace
        New $Namespace
        Set $Namespace = pNamespace
        
        // Execute Start Production via Ens.Director
        Set tSC = ##class(Ens.Director).StartProduction()
        
        Set $Namespace = tCurrentNS
    }
    Catch tException {
        Set tSC = tException.AsStatus()
    }
    
    Return tSC
}

/// Stop Production on a namespace
ClassMethod StopProduction(pNamespace As %String, timeout as %Integer=1, force as %Boolean=1) As %Status
{
    Set tSC = $$$OK
    
    Try {
        Set tCurrentNS = $Namespace
        New $Namespace
        Set $Namespace = pNamespace
        
        // Execute Stop Production via Ens.Director
        Set tSC = ##class(Ens.Director).StopProduction(timeout, force)
        
        Set $Namespace = tCurrentNS
    }
    Catch tException {
        Set tSC = tException.AsStatus()
    }
    
    Return tSC
}

/// Clean Production on a namespace
ClassMethod CleanProduction(pNamespace As %String, killdata as %Boolean=1) As %Status
{
    Set tSC = $$$OK
    
    Try {
        Set tCurrentNS = $Namespace
        New $Namespace
        Set $Namespace = pNamespace
        
        // Execute Clean Production via Ens.Director
        Set tSC = ##class(Ens.Director).CleanProduction(killdata)
        
        Set $Namespace = tCurrentNS
    }
    Catch tException {
        Set tSC = tException.AsStatus()
    }
    
    Return tSC
}

/// Start all productions in all Interop namespaces, executing Recover on those that need it
ClassMethod StartAllProductions() As %Status
{
    Set tSC = $$$OK
    
    Try {
        // Get all namespaces
        Set tSQL = ..#NAMESPACESLISTQUERY
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, tSQL)
        
        While tRS.%Next() {
            Set tNamespace = tRS.%Get("Nsp")
            Continue:(..IsExcludedInteropNamespace(tNamespace) || ..IsSystemNamespace(tNamespace))
            
            // Check if this is an Interop namespace
            If ##class(%EnsembleMgr).IsEnsembleNamespace(tNamespace){
                write !,$INCREMENT(i)," Checking namespace: ",tNamespace,!
                Set tProductionStatus = ..GetProductionStatus(tNamespace)
                write !,"[",tNamespace,"] Status: ",tProductionStatus,!
                If tProductionStatus = "need recover" {
                    Write !,"[",tNamespace,"] Status: NEED RECOVER - Executing Recover..."
                    
                    // Execute the Recover
                    Set tRecoverSC = ..RecoverProduction(tNamespace)
                    If $$$ISERR(tRecoverSC) {
                        Write !,"ERROR during Recover on ",tNamespace,": ",$System.Status.GetErrorText(tRecoverSC)
                        Set tSC = $$$ADDSC(tSC, tRecoverSC)
                    } Else {
                        Write !,"[",tNamespace,"] Recover executed successfully"
                    }
                } elseif tProductionStatus = "running" {
                    Write !,"[",tNamespace,"] Production is already running - no action needed"
                } else {
                    Write !,"[",tNamespace,"] Production is not running - starting production..."
                    Set tStartSC = ..StartProduction(tNamespace)
                    If $$$ISERR(tStartSC) {
                        Write !,"ERROR during Start Production on ",tNamespace,": ",$System.Status.GetErrorText(tStartSC)
                        Set tSC = $$$ADDSC(tSC, tStartSC)
                    } Else {
                        Write !,"[",tNamespace,"] Production started successfully"
                    }
                }
            } 
        }
    }
    Catch tException {
        Set tSC = tException.AsStatus()
    }
    
    Return tSC
}

/// Stop all productions in all Interop namespaces, executing Recover on those that need it
ClassMethod StopAllProductions(timeout as %Integer=0, force as %Boolean=1) As %Status
{
    Set tSC = $$$OK
    
    Try {
        // Get all namespaces
        Set tSQL = ..#NAMESPACESLISTQUERY
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, tSQL)
        
        While tRS.%Next() {
            Set tNamespace = tRS.%Get("Nsp")
            Continue:(..IsExcludedInteropNamespace(tNamespace) || ..IsSystemNamespace(tNamespace))
            
            // Check if this is an Interop namespace
            If ##class(%EnsembleMgr).IsEnsembleNamespace(tNamespace){
                write !,$INCREMENT(i)," Checking namespace: ",tNamespace,!
                Set tProductionStatus = ..GetProductionStatus(tNamespace)
                write !,"[",tNamespace,"] Status: ",tProductionStatus,!
                If tProductionStatus = "need recover" {
                    Write !,"[",tNamespace,"] Status: NEED RECOVER - Executing Recover..."
                    
                    // Execute the Recover
                    Set tRecoverSC = ..RecoverProduction(tNamespace)
                    If $$$ISERR(tRecoverSC) {
                        Write !,"ERROR during Recover on ",tNamespace,": ",$System.Status.GetErrorText(tRecoverSC)
                        Set tSC = $$$ADDSC(tSC, tRecoverSC)
                    } Else {
                        Write !,"[",tNamespace,"] Recover executed successfully"
                    }
                } elseif tProductionStatus = "stopped" || tProductionStatus = "suspended" {
                    Write !,"[",tNamespace,"] Production is already stopped - no action needed"
                } else {
                    Write !,"[",tNamespace,"] Production is not stopped - stopping production..."
                    Set tStopSC = ..StopProduction(tNamespace, timeout, force)
                    If $$$ISERR(tStopSC) {
                        Write !,"ERROR during Stop Production on ",tNamespace,": ",$System.Status.GetErrorText(tStopSC)
                        Set tSC = $$$ADDSC(tSC, tStopSC)
                    } Else {
                        Write !,"[",tNamespace,"] Production stopped successfully"
                    }
                }
            } 
        }
    }
    Catch tException {
        Set tSC = tException.AsStatus()
    }
    
    Return tSC
}

/// Clean all productions in all Interop namespaces, executing Recover on those that need it
ClassMethod CleanAllProductions(killdata as %Boolean=1) As %Status
{
    Set tSC = $$$OK
    
    Try {
        // Get all namespaces
        Set tSQL = ..#NAMESPACESLISTQUERY
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, tSQL)
        
        While tRS.%Next() {
            Set tNamespace = tRS.%Get("Nsp")
            Continue:(..IsExcludedInteropNamespace(tNamespace) || ..IsSystemNamespace(tNamespace))
            
            // Check if this is an Interop namespace
            If ##class(%EnsembleMgr).IsEnsembleNamespace(tNamespace){
                write !,$INCREMENT(i)," Checking namespace: ",tNamespace,!
                Set tProductionStatus = ..GetProductionStatus(tNamespace)
                write !,"[",tNamespace,"] Status: ",tProductionStatus,!
                If tProductionStatus = "need recover" {
                    Write !,"[",tNamespace,"] Status: NEED RECOVER - Executing Recover..."
                    
                    // Execute the Recover
                    Set tRecoverSC = ..RecoverProduction(tNamespace)
                    If $$$ISERR(tRecoverSC) {
                        Write !,"ERROR during Recover on ",tNamespace,": ",$System.Status.GetErrorText(tRecoverSC)
                        Set tSC = $$$ADDSC(tSC, tRecoverSC)
                    } Else {
                        Write !,"[",tNamespace,"] Recover executed successfully"
                    }
                } 
                Write !,"[",tNamespace,"] Cleaning production..."
                Set tCleanSC = ..CleanProduction(tNamespace, killdata)
                If $$$ISERR(tCleanSC) {
                    Write !,"ERROR during Clean Production on ",tNamespace,": ",$System.Status.GetErrorText(tCleanSC)
                    Set tSC = $$$ADDSC(tSC, tCleanSC)
                } Else {
                    Write !,"[",tNamespace,"] Production cleaned successfully"
                }
            } 
        }
    }
    Catch tException {
        Set tSC = tException.AsStatus()
    }
    
    Return tSC
}
}
