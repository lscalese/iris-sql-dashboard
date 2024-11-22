/// curl -XPOST "localhost:8086/api/v2/write?bucket=db&precision=s&org=dc" \
///  --data-raw "mem,host=host1 used_percent=23.43234543 1556896326"
Class dc.sqlstats.influxdb.PushStats Extends %SYS.Task.Definition
{

Parameter TaskName = "Influx DB - Push SQL Stats";

Parameter WRITE = "/api/v2/write?bucket=${BucketName}&precision=s&org=${Org}";

/// InfluxDB address, <protocol>://<host>:<port>
Property Host As %String [ InitialExpression = "http://influxdb2:8086" ];

/// InfluxDB bucket name
Property BucketName As %String [ InitialExpression = "IRIS_SQL_STATS" ];

/// Organization name
Property Org As %String [ InitialExpression = "dc" ];

/// Influx DB Token
/// If you let it empty, it will try to get the token from ^influx("token") global and then environment variable INFLUX_TOKEN
Property Token As %String;

/// If https is used, fill in the SSL configuration name
Property SSLConfig As %String;

Method OnTask() As %Status
{
    Set tSc = $$$OK
    
    Try {
        Set tSc = ..SendData()
    } Catch ex {
        Set tSc = ex.AsStatus()
    }

    Return tSc
}

ClassMethod Test() As %Status
{
    Set obj = ..%New()
    
    Set obj.Host = "http://influxdb2:8086"
    Set obj.BucketName = "IRIS_SQL_STATS"
    Set obj.Org = "dc"
    Set obj.Token = "sDqRnDkU1swVMMaLr_iHSBpa72N-h1nT4fyfBSVjmnMPGtWvYNplcAjKygMxLKhilK7CCuU_ogUKt4ADMSuZ3A=="

    Set sc = obj.SendData($ZdateTime("1,0", 3, 1))

    Return sc
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

    Set ptr = 0, stream = ##class(%Stream.GlobalCharacter).%New()

    While $ListNext(namespaces, ptr, namespace) {
        Set filter.namespace = namespace
        Set filter.from = dailyFrom
        Set results = ##class(dc.sqlstats.services.SQLStats).DailyStats(filter)
        Set sc = ##class(dc.sqlstats.services.SQLStats).ConvertToLineProtocol(results, .stream)
        
        If $$$ISERR(sc) {
            Return sc
        }
        
        Set filter.from = hourlyFrom
        Set results = ##class(dc.sqlstats.services.SQLStats).HourlyStats(filter)
        Set sc = ##class(dc.sqlstats.services.SQLStats).ConvertToLineProtocol(results, .stream)
        
        If $$$ISERR(sc) {
            Return sc
        }

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
