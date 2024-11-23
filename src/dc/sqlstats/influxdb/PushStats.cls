/// curl -XPOST "localhost:8086/api/v2/write?bucket=db&precision=s&org=dc" \
///  --data-raw "mem,host=host1 used_percent=23.43234543 1556896326"
Class dc.sqlstats.influxdb.PushStats Extends %SYS.Task.Definition
{

Parameter TaskName = "Influx DB - Push SQL Stats";

Parameter HistoryTaskName = "Influx DB - Push SQL Stats History";

Parameter WRITE = "/api/v2/write?bucket=${BucketName}&precision=s&org=${Org}";

/// InfluxDB address, <protocol>://<host>:<port>
Property Host As %String(MAXLEN = 1024) [ InitialExpression = "http://influxdb2:8086" ];

/// InfluxDB bucket name
Property BucketName As %String [ InitialExpression = "IRIS_SQL_STATS" ];

/// Organization name
Property Org As %String(MAXLEN = 1024) [ InitialExpression = "dc" ];

/// Influx DB Token
/// If you let it empty, it will try to get the token from ^influx("token") global and then environment variable INFLUX_TOKEN
Property Token As %String(MAXLEN = 1024);

/// If https is used, fill in the SSL configuration name
Property SSLConfig As %String(MAXLEN = 1024);

/// If true, it will send the history otherwise it will send the data from the last successful send
/// It should be set to true for an on demand task.
Property SendHistory As %Boolean [ InitialExpression = 0 ];

Method OnTask() As %Status
{
    Set tSc = $$$OK
    
    Try {
        If ..SendHistory {
            Set tSc = ..SendData($ZdateTime("1,0", 3, 1))
        } Else {
            Set tSc = ..SendData()
        }
    } Catch ex {
        Set tSc = ex.AsStatus()
    }

    Return tSc
}

ClassMethod CreateOnDemandTask() As %Status
{
	Set sc = $$$OK
	Return:..getTaskId()'="" $$$ERROR($$$GeneralError,"Task already exist")
	Set task = ##class(%SYS.Task).%New()
	Set task.Name=..#HistoryTaskName
	Set task.Description="Push SQL Stats History to Influx DB."
	Set task.NameSpace=$namespace
	Set task.RunAsUser="_system"
	Set task.TaskClass=..%ClassName(1)
	
	Set task.TimePeriod=5	; On demand
    
	
	Set task.Priority=1

    Set def = ..%New()
    Set def.SendHistory = 1
    Do task.AssignSettings(def)

  	Set sc = task.%Save()

	Return sc
}

ClassMethod getTaskId(ByRef sc As %Status = {$$$OK}, className As %String = {..%ClassName(1)}) As %String
{
	Set id = "", tStatement = ##class(%SQL.Statement).%New()

	$$$ThrowOnError(tStatement.%PrepareClassQuery("%SYS.Task","TaskListDetail"))
	
	Set tResult = tStatement.%Execute()
	
	While (tResult.%Next(.sc)) {
		
		If $$$ISERR(sc) $$$ThrowStatus(sc)

		If tResult.%Get("TaskClass") = className {
			Set id = tResult.%Get("ID")
			Quit
		}
	}
	Quit id
}

Method SendData(from As %TimeStamp = {$Get(^influx("last-to-success"), $ZDateTime("1,0", 3,1 ))}) As %Status
{
    Set sc = $$$OK

    ; - 1 day to be sure to complete not calculated previous data
    Set dailyFrom = ##class(%SYSTEM.SQL.Functions).DATEADD("dd", -1, from)
    ; - 1 hour to be sure to complete not calculated previous data
    Set hourlyFrom = ##class(%SYSTEM.SQL.Functions).DATEADD("hh", -1, from)

    Set filter = ##class(dc.sqlstats.dto.FilterStatsDTO).%New()
    Set filter.to = $ZDateTime($Horolog, 3, 1)
    
    Set namespaces = ##class(dc.sqlstats.services.SQLStats).GetListNamespaces()

    Set timeUnit = "s"

    Set ptr = 0, stream = ##class(%Stream.GlobalCharacter).%New()

    While $ListNext(namespaces, ptr, namespace) {
        Set filter.namespace = namespace
        Set filter.from = dailyFrom
        Set results = ##class(dc.sqlstats.services.SQLStats).DailyStats(filter)
        Set sc = ##class(dc.sqlstats.services.SQLStats).ConvertToLineProtocol(results, .stream, timeUnit)
        
        If $$$ISERR(sc) {
            Return sc
        }
        
        Set filter.from = hourlyFrom
        Set results = ##class(dc.sqlstats.services.SQLStats).HourlyStats(filter)
        Set sc = ##class(dc.sqlstats.services.SQLStats).ConvertToLineProtocol(results, .stream, timeUnit)
        
        If $$$ISERR(sc) {
            Return sc
        }

    }

    If stream.Size = 0 {
        ; Nothing to send ...
        Return sc
    }

    /* 
    Components is an array like this : 
    
    Components("host")="www.intersystems.com"
    Components("netloc")="user:pass@www.intersystems.com:80"
    Components("password")="pass"
    Components("path")="/path/"
    Components("port")=80
    Components("scheme")="http"
    Components("username")="user"
    */
    
    Do ##class(%Net.URLParser).Decompose(..Host, .Components)

    Set httpRequest = ##class(%Net.HttpRequest).%New()
    Set httpRequest.Server = Components("host")
    Set httpRequest.Port = Components("port")
    Set httpRequest.Https = Components("scheme") = "https"
    
    If httpRequest.Https {
        Set httpRequest.SSLConfiguration = ..SSLConfig
    }

    Set token = ..Token
    If token = "" {
        Set token = $Get(^influx("token"))
    }

    If token = "" {
        Set token = $System.Util.GetEnviron("INFLUX_TOKEN")
    }

    Do httpRequest.SetHeader("Authorization", "Token "_ token)
    Do httpRequest.SetHeader("Content-Type", "text/plain; charset=utf-8")
    Do httpRequest.EntityBody.CopyFrom(stream)

    Set endPoint = $Replace(..#WRITE, "${BucketName}", ..BucketName)
    Set endPoint = $Replace(endPoint, "${Org}", ..Org)

    Set sc = httpRequest.Post(endPoint)

    If $$$ISERR(sc) {
        Set ^influx("last-error") = $ZDateTime($Horolog, 3, 1) _ " - " _ $System.Status.GetErrorText(sc)
        Return sc
    }

    Set response = httpRequest.HttpResponse

    Set ^influx("last-status-code") = $ZDateTime($Horolog, 3, 1) _ " " _ response.StatusCode

    If response.StatusCode '= 204 {
        Set ^influx("last-error") = $ZDateTime($Horolog, 3, 1) _ " - " _ "HTTP response: "_ response.Data.Read()
        
        Set sc = $$$ERROR($$$GeneralError, "HTTP response: "_ response.StatusCode)

        Return sc
    }

    Set ^influx("last-to-success") = filter.to

    Return sc
}

}
