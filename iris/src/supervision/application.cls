Class supervision.application Extends %SYS.Monitor.SAM.Abstract
{

ClassMethod add() As %Status
{
  Try {
    set ns=$NAMESPACE
    zn "%SYS" 
    set status = ##class(SYS.Monitor.SAM.Config).AddApplicationClass(..%ClassName(1),ns)
  }
  Catch ex {
    Set status=ex.AsStatus()
  }

  zn ns

  return status
}

Parameter PRODUCT = "app_monitor";

Method GetSensorsPy() As %Status [ Language = python ]
{
import random
import datetime
import iris

# Simulate collecting metrics
self.SetSensor("random_number", random.randint(1, 100))
self.SetSensor("current_time", datetime.datetime.now().isoformat())

return 1  # Return success status
}

Method GetSensors() As %Status
{
    set ^supervision($INCREMENT(^supervision)) = $zdt($h,3)
    Do ..SetSensor("test",$RANDOM(100))
    Return $$$OK
}

ClassMethod nbMessages(configName As %String = "HL7v2 messages erreurs", nbHours As %Integer = 24) As %Integer
{
   set ns=$NAMESPACE
   zn "IRISAPP"
    set nb = 0
    &sql(
    SELECT count(*) 
    INTO :nb
    FROM Ens.MessageHeader  
    WHERE (TargetConfigName = :configName or SourceConfigName = :configName)
    and TimeCreated >= DATEADD('hour', -:nbHours, sysdate)
    )
    zn ns
    return nb
}

}
