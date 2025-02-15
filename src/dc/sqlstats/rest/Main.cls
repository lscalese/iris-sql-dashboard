Class dc.sqlstats.rest.Main Extends %CSP.REST
{

XData UrlMap [ XMLNamespace = "http://www.intersystems.com/urlmap" ]
{
<Routes>
    <Route Url="/ping" Method="GET" Call="Ping"/>
    <Route Url="/daily" Method="GET" Call="Daily"/>
    <Route Url="/hourly" Method="GET" Call="Hourly"/>
    <Route Url="/openapi" Method="GET" Call="GetOpenAPISpec"/>
    <Route Url="/_spec" Method="GET" Call="GetOpenAPISpec"/>
    <Route Url="/namespaces" Method="GET" Call="GetListNamespaces"/>
</Routes>
}

ClassMethod Ping() As %Status
{
    Set %response.ContentType = "application/json"
    Set message = {
        "message": "pong",
        "timestamp": ($ZDateTime($Horolog, 3)),
        "version": ($ZVersion),
        "system": ($SYSTEM.Version.SystemMode()),
        "hostname":(##class(%SYS.System).GetNodeName())
    }
    Do message.%ToJSON()
    Return $$$OK
}

ClassMethod Daily() As %Status
{
    Set sc = $$$OK

    If $Get(%request.Data("from",1)) = "" {
        Set from = ##class(%SYSTEM.SQL.Functions).DATEADD("hh", -1, $ZDateTime($Horolog, 3, 1))
        Set from = $Piece(from, " ", 1)
    } Else {
        Set from = $Piece($Get(%request.Data("from",1)), " ", 1)
    }
    
    Set to = $Piece($Get(%request.Data("to",1), $ZDate($Horolog, 3)), " ", 1)
    Set hash = $Get(%request.Data("hash",1))

    Try {
        If '(from ? 4N1"-"2N1"-"2N) {
            ; may be the posix timestamp sent by Grafana
            ; convert epoch to timestamp yyyy-mm-dd
            Set from = $ZDate($ZDTH(from/1000, -2), 3)
        }

        If '(to ? 4N1"-"2N1"-"2N) {
            ; may be the posix timestamp sent by Grafana
            ; convert epoch to timestamp yyyy-mm-dd
            Set to = $ZDate($ZDTH(to/1000, -2), 3)
        }
    } Catch ex {
        Set %response.Status = 400
        Set %response.ContentType = "application/json"
        Set message = {
            "error": "Invalid date",
            "message": "The date must be in the format yyyy-mm-dd or a posix timestamp"
        }
        Do message.%ToJSON()
        Return $$$OK
    }

    Set filter = ##class(dc.sqlstats.dto.FilterStatsDTO).%New()
    Set filter.from = from
    Set filter.to = to
    Set filter.hash = hash
    Set filter.period = "daily"
    
    If $Get(%request.Data("namespace",1)) '= "" {
        Set filter.namespace = $ZConvert($Get(%request.Data("namespace",1)), "U")
    }

    ;Set results = ##class(dc.sqlstats.services.SQLStats).DailyStats(filter)

    // stats is an array of dc.sqlstats.dto.SQLStatsDTO
    // the reponse look like this:
    // [
    //     {
    //         "statement": "SELECT * FROM INFORMATION_SCHEMA.STATEMENTS",
    //         "hash": "ABCEDF123456",
    //         "count": 1,
    //         "execution_time": 0.0001,
    //         "variance": 0.000005,
    //         "commands": 1,
    //         "datetime": "2021-06-01 09:00:00",
    //         "server_name": "IRIS",
    //         "instance_name": "IRIS",
    //         "namespace": "USER",
    //         "period": "daily",
    //         "id": "1",
    //         "row_count": 25
    //     }
    // ]
    
    If $$$LOWER(%request.GetCgiEnv("HTTP_ACCEPT")) [ "text/plain" {
        Set %response.ContentType = "text/plain"
        $$$TOE(sc,##class(dc.sqlstats.services.SQLStats).StatsToStream(filter, .gcs, "influx"))
        Do gcs.OutputToDevice()
        Return $$$OK
    }

    Set %response.ContentType = "application/json"
    $$$TOE(sc,##class(dc.sqlstats.services.SQLStats).StatsToStream(filter, .gcs, "json"))
    Do gcs.OutputToDevice()
    Return $$$OK
}

ClassMethod Hourly() As %Status
{
    Set sc = $$$OK
    If $Get(%request.Data("from",1)) = "" {
        Set from = ##class(%SYSTEM.SQL.Functions).DATEADD("hh", -1, $ZDateTime($Horolog, 3, 1))
    } Else {
        Set from = $Get(%request.Data("from",1))
    }

    Set to = $Get(%request.Data("to",1), $ZDateTime($Horolog, 3, 1))
    Set hash = $Get(%request.Data("hash",1))

    Try {
        If '(from ? 4N1"-"2N1"-"2N1" "2N1":"2N1":"2N) {
            ; may be the posix timestamp sent by Grafana
            ; convert posix to timestamp yyyy-mm-dd
            Set from = $ZDateTime($ZDTH(from/1000, -2), 3, 1)
        }

        If '(to ? 4N1"-"2N1"-"2N1" "2N1":"2N1":"2N) {
            ; may be the posix timestamp sent by Grafana
            ; convert posix to timestamp yyyy-mm-dd
            Set to = $ZDateTime($ZDTH(to/1000, -2), 3, 1)
        }
    } Catch ex {
        Set %response.Status = 400
        Set %response.ContentType = "application/json"
        Set message = {
            "error": "Invalid date",
            "message": "The date must be in the format yyyy-mm-dd hh:mm:ss or a posix timestamp"
        }
        Do message.%ToJSON()
        Return $$$OK
    }

    Set filter = ##class(dc.sqlstats.dto.FilterStatsDTO).%New()
    Set filter.from = from
    Set filter.to = to
    Set filter.hash = hash
    Set filter.period = "hourly"

    If $Get(%request.Data("namespace",1)) '= "" {
       Set filter.namespace = $ZConvert($Get(%request.Data("namespace",1)), "U")
    }

    // stats is an array of dc.sqlstats.dto.SQLStatsDTO
    // the reponse look like this:
    // [
    //     {
    //         "statement": "SELECT * FROM INFORMATION_SCHEMA.STATEMENTS",
    //         "hash": "ABCEDF123456",
    //         "count": 1,
    //         "execution_time": 0.0001,
    //         "variance": 0.000005,
    //         "commands": 1,
    //         "datetime": "2021-06-01 09:00:00",
    //         "server_name": "IRIS",
    //         "instance_name": "IRIS",
    //         "namespace": "USER",
    //         "period": "hourly",
    //         "id": "1",
    //         "row_count": 25
    //     }
    // ]

    If $$$LOWER(%request.GetCgiEnv("HTTP_ACCEPT")) [ "text/plain" {
        Set %response.ContentType = "text/plain"
        $$$TOE(sc,##class(dc.sqlstats.services.SQLStats).StatsToStream(filter, .gcs, "influx"))
        Do gcs.OutputToDevice()
        Return $$$OK
    }

    Set %response.ContentType = "application/json"
    $$$TOE(sc,##class(dc.sqlstats.services.SQLStats).StatsToStream(filter, .gcs, "json"))
    Do gcs.OutputToDevice()
    
    Return $$$OK
}

ClassMethod GetOpenAPISpec() As %Status
{
    Set %response.ContentType = "application/json"

    Set ns = $Namespace 
    New $Namespace 
    Set $Namespace = "%SYS"
    
    Do ##class(Security.Applications).Get(%request.Application, .app)
    Set appDirectory = app("Path")
    Kill app
    Set $Namespace = ns

    Set spec = {}.%FromJSONFile(appDirectory _ "openapi.json")

    Set url = $Select(%request.Secure:"https",1:"http") _ "://"_$Get(%request.CgiEnvs("SERVER_NAME")) _ ":" _ $Get(%request.CgiEnvs("SERVER_PORT")) _ %request.Application
	Set spec.servers = [{"url" : (url)}]

    Set formatter = ##class(%JSON.Formatter).%New()
    Set gcs = ##class(%Stream.GlobalCharacter).%New()
    Do formatter.FormatToStream(spec, .gcs)
    Do gcs.OutputToDevice()

    Return $$$OK
}

ClassMethod GetListNamespaces() As %Status
{
    Set %response.ContentType = "application/json"

    Set list = ##class(dc.sqlstats.services.SQLStats).GetListNamespaces()

    Set array = [], ptr = 0
    While $ListNext(list, ptr, key) {
        Do array.%Push(key)
    }

    Do array.%ToJSON()

    Return $$$OK
}

}
