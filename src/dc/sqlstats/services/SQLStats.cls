Class dc.sqlstats.services.SQLStats Extends %RegisteredObject
{

/// format: json, influx
/// This method generates statistics and writes them to a stream in either InfluxDB line protocol format or JSON format.
/// 
/// @param filter The filter criteria for fetching statistics, represented as a dc.sqlstats.dto.FilterStatsDTO object.
/// @param stream The output stream where the statistics will be written. Defaults to a new %Stream.GlobalCharacter instance if not provided.
/// @param format The format of the output stream. Can be either "influx" for InfluxDB line protocol or "json" for JSON format. Defaults to "influx".
/// 
/// @return Returns a %Status indicating the success or failure of the operation.
ClassMethod StatsToStream(filter As dc.sqlstats.dto.FilterStatsDTO, ByRef stream As %Stream.GlobalCharacter = {##class(%Stream.GlobalCharacter).%New()}, format As %String = "influx") As %Status
{
    Set sc = $$$OK

    Try {
        Set results = ##class(%ListOfObjects).%New()
        Set namespaces = $Select(filter.namespace = "": ..GetListNamespaces(), 1:$ListFromString(filter.namespace, ","))
        
        Set ptr = 0, first = $$$YES

        If format '= "influx" {
            Do stream.WriteLine("[")
        }

        While $ListNext(namespaces, ptr, namespace) {
            
            Set filter.namespace = namespace,  atEnd = 0

            While 'atEnd {

                Set results = $Select(filter.period = "hourly": ##class(dc.sqlstats.dao.SQLStatsDAO).FetchHourlyStats(filter, 1000, .atEnd), 1: ##class(dc.sqlstats.dao.SQLStatsDAO).FetchDailyStats(filter, 1000, .atEnd))
                
                If format = "influx" {
                    Do InfluxFormatProcessing
                    Continue
                }
                
                ; it's JSON
                Do JSONFormatProcessing      
            }
        }
        
        If format '= "influx" {
            Do stream.WriteLine("]")
        }

    } Catch ex {
        Kill:$Data(%zzTResDailyStats) %zzTResDailyStats
        Set sc = ex.AsStatus()
    }

    Return sc

InfluxFormatProcessing
    $$$TOE(sc,..ConvertToLineProtocol(results, .stream))
    Quit

JSONFormatProcessing
    Set key = ""
    For  {
        Set item = results.GetNext(.key)
        Quit:key=""
        Do item.%JSONExportToString(.json)
        
        If first {
            Set first = $$$NO
        } Else {
            Do stream.WriteLine(",")
        }

        Do stream.WriteLine(json)
    }
    Quit
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

/// <summary>
/// Creates an InfluxDB line protocol file with SQL statistics data for specified namespaces and time period.
/// </summary>
/// <param name="fileName">The path to the output file. Default is "/home/irisowner/dev/influxdb-lines.txt".</param>
/// <param name="namespaces">A list of namespaces to include in the statistics. Default is the result of GetListNamespaces().</param>
/// <param name="lastXDays">The number of days of statistics to include, counting back from today. Default is 10 days.</param>
/// <returns>A status object indicating success or failure.</returns>
/// <remarks>
/// This method generates a file containing SQL statistics in InfluxDB line protocol format. 
/// It creates the necessary directory if it does not exist, and deletes any existing file with the same name.
/// The statistics are generated for both daily and hourly periods. 
/// If the file is too large, it is split into smaller files to accommodate Telegraf's limitations.
/// </remarks>
ClassMethod CreateInfluxFile(fileName As %String = "/home/irisowner/dev/influxdb-lines.txt", namespaces As %List = {..GetListNamespaces()}, lastXDays As %Integer = 10) As %Status
{
    Set splitSize = 10000, split = $$$YES ; force the split because telegraf does not support large files

    Set directory = ##class(%File).GetDirectory(fileName)
    If '##class(%File).Exists(directory) {
        Do ##class(%File).CreateDirectoryChain(directory)
    }

    If ##class(%File).Exists(fileName) {
        Do ##class(%File).Delete(fileName)
    }

    Set filter = ##class(dc.sqlstats.dto.FilterStatsDTO).%New()

    Set dateFrom = $Horolog - lastXDays
    Set filter.from = $ZDateTime(dateFrom_",0", 3, 1)
    Set filter.to = $ZDateTime($Horolog, 3, 1)
    Set filter.namespace = $ListToString(namespaces, ",")
    
    Set stream = ##class(%Stream.FileCharacter).%New()
    Set stream.StreamFormatWrite = 0
    Set stream.LineTerminator = $Char(10)
    Do stream.LinkToFile(fileName)
   
    Set filter.period = "daily"
    Do ..StatsToStream(filter, .stream, "influx")

    Set filter.period = "hourly"
    Do ..StatsToStream(filter, .stream, "influx")

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

/// Splits a large file into smaller files of specified size.
/// 
/// @param fileName The path to the input file to be split. Default is "/home/irisowner/dev/influxdb-lines.txt".
/// @param splitSize The number of lines each split file should contain. Default is 10000.
/// @return %Status Returns a status indicating success or failure.
/// 
/// @example
/// Set status = ##class(dc.sqlstats.services.SQLStats).SplitInluxFile("/path/to/largefile.txt", 5000)
/// 
/// @note The split files will be named by appending a zero-padded number to the original file name.
///       For example, if the original file name is "data.txt", the split files will be named "data.txt.001", "data.txt.002", etc.
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

/// Convert a list of SQL statistics objects to InfluxDB line protocol format and write to a stream.
/// 
/// @param results A list of SQL statistics objects to be converted.
/// @param Output A stream to which the converted line protocol data will be written. Defaults to a new %Stream.GlobalCharacter instance.
/// @param timeUnit The unit of time to be used for the timestamp in the line protocol. Valid values are "s" (seconds), "ms" (milliseconds), "µs" (microseconds), and "ns" (nanoseconds). Defaults to "ns".
/// 
/// @return A status indicating success or failure of the operation.
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
