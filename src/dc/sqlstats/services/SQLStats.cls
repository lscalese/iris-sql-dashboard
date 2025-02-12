Class dc.sqlstats.services.SQLStats Extends %RegisteredObject
{

ClassMethod DailyStats(filter As dc.sqlstats.dto.FilterStatsDTO) As %ListOfObjects
{
    Set results = ##class(%ListOfObjects).%New()
    If filter.namespace = "" {
        Set namespaces = ..GetListNamespaces()
        Set ptr = 0
        While $ListNext(namespaces, ptr, namespace) {
            Set filter.namespace = namespace
            Set results = ##class(dc.sqlstats.dao.SQLStatsDAO).GetDailyStats(filter, .results)
        }
        Set filter.namespace = ""
    } Else {
        Set results = ##class(dc.sqlstats.dao.SQLStatsDAO).GetDailyStats(filter)
    }
    Return results
}

ClassMethod HourlyStats(filter As dc.sqlstats.dto.FilterStatsDTO) As %ListOfObjects
{
    Set resulsts = ##class(%ListOfObjects).%New()
    If filter.namespace = "" {
        Set namespaces = ..GetListNamespaces()
        Set ptr = 0
        While $ListNext(namespaces, ptr, namespace) {
            Set filter.namespace = namespace
            Set results = ##class(dc.sqlstats.dao.SQLStatsDAO).GetHourlyStats(filter, .results)
        }
        Set filter.namespace = ""
    } Else {
        Set results = ##class(dc.sqlstats.dao.SQLStatsDAO).GetHourlyStats(filter)
    }
    Return results
}

ClassMethod ConvertToDynamicArray(results As %ListOfObjects, removeItemAfterConvert As %Boolean = {$$$YES}) As %DynamicArray
{
    #dim item As dc.sqlstats.dto.SQLStatsDTO

    Set array = ##class(%DynamicArray).%New()
    Set key = ""
    For  {
        Set item = results.GetNext(.key)
        Quit:key=""

        If item.%IsA("%DynamicObject") {
            Do array.%Push(item)
        } Else {
            Do item.%JSONExportToString(.json)
            Do array.%Push({}.%FromJSON(json))
        }
        Do results.RemoveAt(key)
    }
    Return array
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

ClassMethod CreateInfluxFile(fileName As %String = "/home/irisowner/dev/influxdb-lines.txt", namespaces As %List = {..GetListNamespaces()}, split As %Boolean = {$$$NO}, splitSize As %Integer = 10000) As %Status
{

    Set directory = ##class(%File).GetDirectory(fileName)
    If '##class(%File).Exists(directory) {
        Do ##class(%File).CreateDirectoryChain(directory)
    }

    If ##class(%File).Exists(fileName) {
        Do ##class(%File).Delete(fileName)
    }

    Set filter = ##class(dc.sqlstats.dto.FilterStatsDTO).%New()
    Set filter.from = $ZDateTime("0,0", 3, 1)
    Set filter.to = $ZDateTime($Horolog, 3, 1)
    
    Set ptr = 0, stream = ##class(%Stream.FileCharacter).%New()
    Set stream.StreamFormatWrite = 0
    Set stream.LineTerminator = $Char(10)

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

    Set sc = stream.%Save()

    If $$$ISERR(sc) {
        Return sc
    }

    If 'split {
        Return sc
    }

    Set sc = ..SplitInluxFile(fileName, splitSize)

    If $$$ISOK(sc) {
        Do ##class(%File).Delete(fileName)
    }

    Return sc
}

ClassMethod SplitInluxFile(fileName As %String = "/home/irisowner/dev/influxdb-lines.txt", splitSize As %Integer = 10000) As %Status
{
    Set sc = $$$OK

    If '##class(%File).Exists(fileName) {
        Return $$$ERROR($$$GeneralError, "File not found")
    }

    Set splitFile = ##class(%Stream.FileCharacter).%New()
    
    Do newSplitFile

    Set file = ##class(%Stream.FileCharacter).%New()
    Do file.LinkToFile(fileName)

    While 'file.AtEnd {
        Set line = file.ReadLine()
        Do splitFile.WriteLine(line)
        Do $Increment(count)
        If count = splitSize {
            Set sc = splitFile.%Save()
            If $$$ISERR(sc) {
                Return sc
            }
            Do newSplitFile
            Set count = 0
        }
    }

    Set sc = splitFile.%Save()

    Return sc

newSplitFile
    Do $Increment(fileNumber)
    Set splitFile = ##class(%Stream.FileCharacter).%New()   
    Do splitFile.LinkToFile(fileName _ "." _ $tr($j(fileNumber, 3), " ", "0"))
    Quit
}

/// Do ##class(dc.sqlstats.services.SQLStats).ConvertToLineProtocol(resulsts,.stream)
ClassMethod ConvertToLineProtocol(results As %ListOfObjects, Output stream As %Stream.GlobalCharacter = {##class(%Stream.GlobalCharacter).%New()}, timeUnit As %String = "ns") As %Status
{
    Set timeFactor = 1
    If timeUnit = "s" {
        Set timeFactor = 1
    } ElseIf timeUnit = "ms" {
        Set timeFactor = 1000
    } ElseIf timeUnit = "µs" {
        Set timeFactor = 1000000
    } ElseIf timeUnit = "ns" {
        Set timeFactor = 1000000000
    } Else {
        $$$ThrowStatus($$$ERROR($$$GeneralError, "Invalid time unit only s, ms, us, ns are allowed"))
    }

    Set replaceStr = "%%1%%"
    Set stream.LineTerminator = $Char(10)

    #dim item As dc.sqlstats.dto.SQLStatsDTO
    Set key = ""

    For  {
        Set item = results.GetNext(.key)
        Quit:key=""

        If item.DateTime = "" {
            Continue
        }

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

        For tagValue = item.ServerName, item.InstanceName, item.Namespace, item.Id {
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
        
        Set line = line _ " " _ ($ZDateTime($ZDTH(item.DateTime, 3, 1), -2) * timeFactor)
        
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
