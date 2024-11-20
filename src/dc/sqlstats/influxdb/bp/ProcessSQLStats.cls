Class dc.sqlstats.influxdb.bp.ProcessSQLStats Extends Ens.BusinessProcess
{

Method OnRequest(pRequest As dc.sqlstats.influxdb.msg.InfluxDataFilter, Output pResponse As Ens.StreamContainer) As %Status
{
    Set sc = $$$OK
    Try {
        
        If pRequest.namespaces = "*" {
            Set namespaces = ##class(dc.sqlstats.services.SQLStats).GetListNamespaces()
        } Else {
            Set namespaces = $ListFromString(pRequest.namespaces, ",")
        }

        Set ptr = 0

        While $ListNext(namespaces, ptr, namespace) {
            Set filter = ##class(dc.sqlstats.dto.FilterStatsDTO).%New()
            Set filter.from = pRequest.fromDate
            Set filter.to = pRequest.toDate
            Set filter.namespace = namespace

            Set daily = ##class(dc.sqlstats.services.SQLStats).DailyStats(filter)
            Set hourly = ##class(dc.sqlstats.services.SQLStats).HourlyStats(filter)
        }

    } Catch ex {
        Set sc = ex.AsStatus()
        $$$LOGERROR(sc)
    }
    Return sc
}

Storage Default
{
<Type>%Storage.Persistent</Type>
}

}
