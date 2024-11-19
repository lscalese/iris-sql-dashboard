Class dc.sqlstats.services.SQLStats Extends %RegisteredObject
{

ClassMethod DailyStats(filter As dc.sqlstats.dto.FilterStatsDTO) As %DynamicArray
{
    Set results = ##class(dc.sqlstats.dao.SQLStatsDAO).GetDailyStats(filter)
    Set stats = []
   
    Set key = ""

    For  {
        Set stat = results.GetNext(.key)
        Quit:key=""

        Set stat.AvgExecutionTime = stat.ExecutionTime / stat.Count
        Set stat.AvgCommands = stat.Commands / stat.Count

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

    #dim stat As dc.sqlstats.dto.SQLStatsDTO

    Set key = ""
    For  {
        Set stat = results.GetNext(.key)
        Quit:key=""

        Set stat.AvgExecutionTime = stat.ExecutionTime / stat.Count
        Set stat.AvgCommands = stat.Commands / stat.Count
        Set stat.DateTime = stat.Date _ " " _ stat.Hour _ ":00:00"


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
        Set $List(list, * + 1) = key
    }
    Return list
}

}
