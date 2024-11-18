Class dc.sqlstats.rest.Main Extends %CSP.REST
{

XData UrlMap [ XMLNamespace = "http://www.intersystems.com/urlmap" ]
{
<Routes>
    <Route Url="/ping" Method="GET" Call="Ping"/>
    <Route Url="/daily" Method="GET" Call="Daily"/>
    <Route Url="/hourly" Method="GET" Call="Hourly"/>
    <Route Url="/openapi" Method="GET" Call="GetOpenAPISpec"/>
    <Route Url="/spec" Method="GET" Call="GetOpenAPISpec"/>
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
        "hostname":($SYSTEM.INetInfo.LocalHostName())
    }
    Do message.%ToJSON()
    Return $$$OK
}

ClassMethod Daily() As %Status
{
    Set from = $Piece($Get(%request.Data("from",1), $ZDate($Horolog-15, 3)), " ", 1)
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

    Set %response.ContentType = "application/json"

    Set filter = ##class(dc.sqlstats.dto.FilterStatsDTO).%New()
    Set filter.from = from
    Set filter.to = to
    Set filter.hash = hash

    Set stats = ##class(dc.sqlstats.services.SQLStats).DailyStats(filter)

    // stats is an array of dc.sqlstats.dto.SQLStatsDTO
    // the reponse look like this:
    // [
    //     {
    //         "Statement": "SELECT * FROM INFORMATION_SCHEMA.STATEMENTS",
    //         "Hash": "ABCEDF123456",
    //         "Count": 1,
    //         "ExecutionTime": 0.0001,
    //         "Variance": 0,
    //         "AvgExecutionTime": 0.0001,
    //         "Commands": 1,
    //         "AvgCommands": 1,
    //         "Date": "2021-06-01",
    //         "DateTime": "2021-06-01 00:00:00",
    //         "Hour": ""
    //     }
    // ]

    Set gcs = ##class(%Stream.GlobalCharacter).%New()
    Do stats.%ToJSON(.gcs)
    Do gcs.OutputToDevice()

    Return $$$OK
}

ClassMethod Hourly() As %Status
{
    Set from = $Get(%request.Data("from",1), $ZDate($Horolog-15, 3))
    Set to = $Get(%request.Data("to",1), $ZDate($Horolog, 3))
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

    Set %response.ContentType = "application/json"

    Set filter = ##class(dc.sqlstats.dto.FilterStatsDTO).%New()
    Set filter.from = from
    Set filter.to = to
    Set filter.hash = hash

    Set stats = ##class(dc.sqlstats.services.SQLStats).HourlyStats(filter)

    // stats is an array of dc.sqlstats.dto.SQLStatsDTO
    // the reponse look like this:
    // [
    //     {
    //         "Statement": "SELECT * FROM INFORMATION_SCHEMA.STATEMENTS",
    //         "Hash": "ABCEDF123456",
    //         "Count": 1,
    //         "ExecutionTime": 0.0001,
    //         "Variance": 0,
    //         "AvgExecutionTime": 0.0001,
    //         "Commands": 1,
    //         "AvgCommands": 1,
    //         "Date": "2021-06-01",
    //         "DateTime": "2021-06-01 09:00:00",
    //         "Hour": 0
    //     }
    // ]

    Set gcs = ##class(%Stream.GlobalCharacter).%New()
    Do stats.%ToJSON(.gcs)
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

}
