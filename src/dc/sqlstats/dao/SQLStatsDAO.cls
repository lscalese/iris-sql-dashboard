Class dc.sqlstats.dao.SQLStatsDAO Extends %RegisteredObject
{

ClassMethod FetchDailyStats(filter As dc.sqlstats.dto.FilterStatsDTO, limit As %Integer = 1000, ByRef atEnd As %Boolean = 0, forceNewQuery As %Boolean = {$$$NO}) As %ListOfObjects
{
    Set ns = $Namespace
    Set stats = ##class(%ListOfObjects).%New()
    
    If forceNewQuery {
        Kill %zzTResDailyStats
    }

    Try {
        New $ROLES
        Set $ROLES = "%ALL"
        
        If $Namespace '= filter.namespace {
            New $NAMESPACE
            Set $NAMESPACE = filter.namespace
        }

        Set serverName = ##class(%SYS.System).GetNodeName(), instanceName = ##class(%SYS.System).GetInstanceName()

        Kill:$Data(^||tmp.res) ^||tmp.res

        Set tRes = $Get(%zzTResDailyStats)
        If '$IsObject(tRes) {
            Do ExecuteDailyQuery
        }
        
        Set atEnd = $$$YES
        While tRes.%Next() {
            Set ^||tmp.res(tRes.ID)=$lb(tRes.Hash, tRes.Statement, tRes.Day_" 00:00:00", tRes.StatCount, tRes.StatTotal, tRes.StatCommands, tRes.StatVariance, tRes.StatRowCount, "daily", $Namespace)
            
            Continue:$Increment(countRecord)<limit

            Set atEnd = $$$NO
            Quit
        }

        Kill:atEnd %zzTResDailyStats
        
        Set $Namespace = ns
        
        Set id = ""
        For  {
	    	Set id = $Order(^||tmp.res(id), 1, data)
			Quit:id=""
			Set stat = ##class(dc.sqlstats.dto.SQLStatsDTO).%New()
            Set stat.Id = id
            Set stat.Hash = $ListGet(data, 1)
            Set stat.Statement = $ListGet(data, 2)
            Set stat.DateTime = $ListGet(data, 3)
            Set stat.Count = $ListGet(data, 4)
            Set stat.ExecutionTime = $ListGet(data, 5)
            Set stat.Commands = $ListGet(data, 6)
            Set stat.Variance = $ListGet(data, 7)
            Set stat.RowCount = $ListGet(data, 8)
            Set stat.Period = $ListGet(data, 9)
            Set stat.Namespace = $ListGet(data, 10)
            Do stats.Insert(stat)
            Kill ^||tmp.res(id)
        }
    } Catch ex {
        Kill %zzTResDailyStats
        Kill:$Data(^||tmp.res) ^||tmp.res

        $$$ThrowStatus(ex.AsStatus())
    }

    Return stats

ExecuteDailyQuery
    Set args($Increment(args)) = $Piece(filter.from, " ", 1)
    Set args($Increment(args)) = $Piece(filter.to, " ", 1)

    Set sql = "SELECT t1.ID, t2.Hash, t2.Statement, t1.Day, t1.StatCount, t1.StatTotal, t1.StatRowCount, t1.StatCommands, t1.StatVariance "
                _ "FROM INFORMATION_SCHEMA.STATEMENT_DAILY_STATS t1 "
                _ "INNER JOIN INFORMATION_SCHEMA.STATEMENTS t2 ON t1.Statement = t2.Hash "
                _ "WHERE t1.Day >= ? AND t1.Day <= ?"

    Set irisMajorVersion = $SYSTEM.Version.GetMajor()
    ; try to be compatible with older version
    If irisMajorVersion < 2023  {
        ; StatRowCount is not available in older version
        Set sql = $Replace(sql, "t1.StatRowCount", "0 As StatRowCount")
        ; StatCommands is not available in older version
        Set sql = $Replace(sql, "t1.StatCommands", "0 As StatCommands")
    }
    
    
    If filter.hash '= "" {
        Set sql = sql _ " AND t2.Hash = ?"
        Set args($Increment(args)) = filter.hash
    }

    Set tStatement = ##class(%SQL.Statement).%New()
    Set tStatement.%SelectMode = 1
    Set tRes = ##class(%SQL.Statement).%ExecDirect(.tStatement, sql, args...)

    If tRes.%SQLCODE < 0 {
        Set sc = $$$ERROR($$$SQLError, tRes.%SQLCODE, tRes.%Message)
        $$$ThrowStatus(sc)
    }

    Set %zzTResDailyStats = tRes

    Quit
}

/// Fetches hourly statistics based on the provided filter and limit.
/// 
/// # Parameters
/// - `filter` (dc.sqlstats.dto.FilterStatsDTO): The filter criteria for fetching the statistics.
/// - `limit` (%Integer): The maximum number of records to fetch. Default is 1000.
/// - `atEnd` (ByRef %Boolean): A reference parameter that indicates if the end of the result set is reached. Default is 0.
/// 
/// # Returns
/// - (%ListOfObjects): A list of SQLStatsDTO objects containing the fetched statistics.
/// 
/// # Throws
/// - Throws an exception if there is an error during the execution of the SQL query.
/// 
/// # Description
/// This method fetches hourly statistics from the `INFORMATION_SCHEMA.STATEMENT_HOURLY_STATS` table based on the provided filter criteria.
/// It handles namespace switching, role setting, and temporary result storage. The method also ensures compatibility with older versions of IRIS.
/// The fetched statistics are returned as a list of `SQLStatsDTO` objects.
ClassMethod FetchHourlyStats(filter As dc.sqlstats.dto.FilterStatsDTO, limit As %Integer = 1000, ByRef atEnd As %Boolean = 0, forceNewQuery As %Boolean = {$$$NO}) As %ListOfObjects
{
    Set ns = $Namespace

    Set stats = ##class(%ListOfObjects).%New()

    Try {
        New $ROLES
        Set $ROLES = "%ALL"
        
        If $Namespace '= filter.namespace {
            New $NAMESPACE
            Set $NAMESPACE = filter.namespace
        }
        

        Kill:$Data(^||tmp.res) ^||tmp.res
        
        Set tRes = $Get(%zzTResHourlyStats)
        Do:'$IsObject(tRes) ExecuteHourlyStats
        
        Set atEnd = $$$YES
        
        While tRes.%Next() {
            ; If we use SQLStatsDTO, we can add package mapping
            ; Adding package mapping rebuilds all Extent indexes for the namespace            
            Set ^||tmp.res(tRes.ID)=$lb(tRes.Hash, tRes.Statement, $ZDate(tRes.Day, 3) _ " " _ tRes.Hour _ ":00:00", tRes.StatCount, tRes.StatTotal, tRes.StatCommands, tRes.StatVariance, tRes.StatRowCount, "hourly", $Namespace)

            Continue:$Increment(countRecord)<limit

            Set atEnd = $$$NO
            Quit
        }

        Kill:atEnd %zzTResHourlyStats

        Set $Namespace = ns

        Set id = ""
        For  {
            Set id = $Order(^||tmp.res(id), 1, data)
            Quit:id=""
            Set stat = ##class(dc.sqlstats.dto.SQLStatsDTO).%New()
            Set stat.Id = id
            Set stat.Hash = $ListGet(data, 1)
            Set stat.Statement = $ListGet(data, 2)
            Set stat.DateTime = $ListGet(data, 3)
            Set stat.Count = $ListGet(data, 4)
            Set stat.ExecutionTime = $ListGet(data, 5)
            Set stat.Commands = $ListGet(data, 6)
            Set stat.Variance = $ListGet(data, 7)
            Set stat.RowCount = $ListGet(data, 8)
            Set stat.Period = $ListGet(data, 9)
            Set stat.Namespace = $ListGet(data, 10)
            Do stats.Insert(stat)
            Kill ^||tmp.res(id)
        }
        
    } Catch ex {
        Kill %zzTResHourlyStats
        Kill:$Data(^||tmp.res) ^||tmp.res

        $$$ThrowStatus(ex.AsStatus())
    }

    Quit stats

ExecuteHourlyStats
    Set dayStart = $ZDateH($Piece(filter.from, " ", 1), 3)
    Set dayEnd = $ZDateH($Piece(filter.to, " ", 1), 3)

    Set startHour = +$Extract(filter.from, 12, 13)
    Set endHour = +$Extract(filter.to, 12, 13)

    Set args($Increment(args)) = dayStart
    Set args($Increment(args)) = dayStart
    Set args($Increment(args)) = startHour
    Set args($Increment(args)) = dayEnd
    Set args($Increment(args)) = dayEnd
    Set args($Increment(args)) = endHour

    Set sql = "SELECT ID, Day->Day, ""Hour"", StatCount, StatTotal, StatRowCount, StatCommands, StatVariance, Day->Statement->Hash, Day->Statement->Statement "
                _ "FROM INFORMATION_SCHEMA.STATEMENT_HOURLY_STATS "
                _ "WHERE (Day->Day > ? OR (Day->Day = ? AND ""Hour"" >= ?)) "
                _ "AND (Day->Day < ? OR (Day->Day = ? AND ""Hour"" <= ?)) "
    
    Set irisMajorVersion = $SYSTEM.Version.GetMajor()

    ; try to be compatible with older version
    If irisMajorVersion < 2023  {
        ; StatRowCount is not available in older version
        Set sql = $Replace(sql, "StatRowCount", "0 As StatRowCount")
        ; StatCommands is not available in older version
        Set sql = $Replace(sql, "StatCommands", "0 As StatCommands")
        
        ; note : the table STATEMENT_DAILY_STATS exists from 2022.1
        ; so consider this tools works only from 2022.1
    }
    
    If filter.hash '= "" {
        Set sql = sql _ " AND Day->Statement->Hash = ?"
        Set args($Increment(args)) = filter.hash
    }
    
    Set tStatement = ##class(%SQL.Statement).%New()
    Set tStatement.%SelectMode = 0
    Set tRes = ##class(%SQL.Statement).%ExecDirect(.tStatement, sql, args...)

    If tRes.%SQLCODE < 0 {
        Set sc = $$$ERROR($$$SQLError, tRes.%SQLCODE, tRes.%Message)
        $$$ThrowStatus(sc)
    }

    Set %zzTResHourlyStats = tRes

    Quit
}

}
