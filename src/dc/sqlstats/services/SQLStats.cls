Class dc.sqlstats.services.SQLStats Extends %RegisteredObject
{

ClassMethod DailyStats(filter As dc.sqlstats.dto.FilterStatsDTO) As %DynamicArray
{
    Set results = ##class(dc.sqlstats.dao.SQLStatsDAO).GetDailyStats(filter)
    Set stats = []
   
   Set serverName = ##class(%SYS.System).GetNodeName(), instanceName = ##class(%SYS.System).GetInstanceName()

    Set key = ""

    For  {
        Set stat = results.GetNext(.key)
        Quit:key=""

        Set stat.AvgExecutionTime = stat.ExecutionTime / stat.Count
        Set stat.AvgCommands = stat.Commands / stat.Count
        Set stat.DateTime = stat.Date _ " 00:00:00"
        Set stat.Period = "daily"
        Set stat.ServerName = serverName
        Set stat.InstanceName = instanceName

        Set item = ""
        Do stat.%JSONExportToString(.item)

        Do stats.%Push({}.%FromJSON(item))
        Kill item

        Do results.RemoveAt(key)
    }

    Return stats
}

ClassMethod HourlyStats(filter As dc.sqlstats.dto.FilterStatsDTO) As %DynamicArray
{
    Set results = ##class(dc.sqlstats.dao.SQLStatsDAO).GetHourlyStats(filter)
    Set stats = []

    Set serverName = ##class(%SYS.System).GetNodeName(), instanceName = ##class(%SYS.System).GetInstanceName()

    #dim stat As dc.sqlstats.dto.SQLStatsDTO

    Set key = ""
    For  {
        Set stat = results.GetNext(.key)
        Quit:key=""

        Set stat.AvgExecutionTime = stat.ExecutionTime / stat.Count
        Set stat.AvgCommands = stat.Commands / stat.Count
        Set stat.DateTime = stat.Date _ " " _ stat.Hour _ ":00:00"
        Set stat.Period = "hourly"
        Set stat.ServerName = serverName
        Set stat.InstanceName = instanceName


        Set item = ""
        Do stat.%JSONExportToString(.item)
        Do stats.%Push({}.%FromJSON(item))
        Kill item

        Do results.RemoveAt(key)
    }

    Return stats
}

ClassMethod GetListNamespaces() As %List
{
    Do ##class(%SYS.Namespace).ListAll(.result)
    Set key = "", list = ""
    For  {
        Set key = $Order(result(key))
        Quit:key=""
        Continue:$Extract(key, 1, 2)="^^"
        Set $List(list, * + 1) = key
    }
    Return list
}

ClassMethod CreateInfluxFile(fileName As %String = "/home/irisowner/dev/influxdb_line.txt") As %Status
{
    If ##class(%File).Exists(fileName) {
        Do ##class(%File).Delete(fileName)
    }

    Set filter = ##class(dc.sqlstats.dto.FilterStatsDTO).%New()
    Set filter.from = $ZDateTime("0,0", 3, 1)
    Set filter.to = $ZDateTime($Horolog, 3, 1)
    
    Set ptr = 0, namespaces = ..GetListNamespaces(), stream = ##class(%Stream.FileCharacter).%New()

    Do stream.LinkToFile(fileName)

    While $ListNext(namespaces, ptr, namespace) {
        Set filter.namespace = namespace
        Set results = ..DailyStats(filter)
        Set sc = ..ConvertToLineProtocol(results, .stream)
        If $$$ISERR(sc) {
            Return sc
        }
        Set results = ..HourlyStats(filter)
        Set sc = ..ConvertToLineProtocol(results, .stream)
        If $$$ISERR(sc) {
            Return sc
        }
    }

    Return stream.%Save()
}

/// Do ##class(dc.sqlstats.services.SQLStats).ConvertToLineProtocol(,)
ClassMethod ConvertToLineProtocol(results As %DynamicArray, Output stream As %Stream.GlobalCharacter = {##class(%Stream.GlobalCharacter).%New()}) As %Status
{
    Set replaceStr = "%%1%%"

    Set iterator = results.%GetIterator()
    Set key = ""
    While iterator.%GetNext(.key, .item) {
        Set item = results.%Get(key)
        Set:item.DateTime="" item.DateTime = $zdt($h,3,1)

        If item.Period = "daily" {
            Set line = "sqlstats_daily"
        } ElseIf item.Period = "hourly" {
            Set line = "sqlstats_hourly"
        } Else {
            $$$ThrowStatus($$$ERROR($$$GeneralError, "Invalid period only daily or hourly are allowed"))
        }
        
        for tag = "server_name", "instance_name", "namespace", "id" {
            Set line = line _ "," _ tag _ "=" _ replaceStr
        }

        For tagValue = item.ServerName, item.InstanceName, item.Namespace, item.id {
            Set escapedTagValue = ..EscapeTagValue(tagValue)
            Set line = $Replace(line, replaceStr, escapedTagValue, 0, 1)
        }
        
        Set line = line _ " count=" _ +item.Count _ "i"
        Set line = line _ ",commands=" _ +item.Commands _ "i"
        Set line = line _ ",row_count=" _ +item.RowCount _ "i"
        Set line = line _ ",execution_time=" _ $s(+item.ExecutionTime<1:$fn(item.ExecutionTime,,12),1:+item.ExecutionTime)
        Set line = line _ ",variance=" _ $s(+item.Variance<1:$fn(item.Variance,,15),1:+item.Variance)
        Set line = line _ ",hash="""_ ..EscapeFieldValue(item.Hash) _ """"
        Set line = line _ ",statement="""_ ..EscapeFieldValue(item.Statement) _""""
        
        Set line = line _ " " _ $ZDateTime($ZDTH(item.DateTime, 3, 1), -2)

        Do stream.WriteLine($Translate(line, $Char(13,10), ""))
    }
    Return $$$OK
}

ClassMethod EscapeTagValue(tagValue As %String) As %String
{
    Set escapedTagValue = $Replace(tagValue, "=", "\=")
    Set escapedTagValue = $Replace(escapedTagValue, " ", "\ ")
    Set escapedTagValue = $Replace(escapedTagValue, ",", "\,")
    Return escapedTagValue
}

ClassMethod EscapeFieldValue(fieldValue As %String) As %String
{
    Set escapedFieldValue = $Replace(fieldValue, "\", "\\")
    Set escapedFieldValue = $Replace(escapedFieldValue, """", "\""")
    Return escapedFieldValue
}

}
