Class dc.sqlstats.dao.SQLStatsDAO Extends %RegisteredObject
{

ClassMethod GetDailyStats(filter As dc.sqlstats.dto.FilterStatsDTO, initList As %ListOfObjects = "") As %ListOfObjects
{
    If $IsObject(initList) {
        Set stats = initList
    } Else {
        Set stats = ##class(%ListOfObjects).%New()
    }
    
    Try {
        New $ROLES
        Set $ROLES = "%ALL"
        
        If $Namespace '= filter.namespace {
            New $NAMESPACE
            Set $NAMESPACE = filter.namespace
        }

        Set args($Increment(args)) = $Piece(filter.from, " ", 1)
        Set args($Increment(args)) = $Piece(filter.to, " ", 1)

        Set sql = "SELECT t1.ID, t2.Hash, t2.Statement, t1.Day, t1.StatCount, t1.StatTotal, t1.StatRowCount, t1.StatCommands, t1.StatVariance, t1.StatRowCount "
                    _ "FROM INFORMATION_SCHEMA.STATEMENT_DAILY_STATS t1 "
                    _ "INNER JOIN INFORMATION_SCHEMA.STATEMENTS t2 ON t1.Statement = t2.Hash "
                    _ "WHERE t1.Day >= ? AND t1.Day <= ?"
        
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

        Set serverName = ##class(%SYS.System).GetNodeName(), instanceName = ##class(%SYS.System).GetInstanceName()

        While tRes.%Next() {
            Set stat = ##class(dc.sqlstats.dto.SQLStatsDTO).%New()
            Set stat.Id = tRes.ID
            Set stat.Hash = tRes.Hash
            Set stat.Statement = tRes.Statement
            Set stat.DateTime = tRes.Day_" 00:00:00"
            Set stat.Count = tRes.StatCount
            Set stat.ExecutionTime = tRes.StatTotal
            Set stat.Commands = tRes.StatCommands
            Set stat.Variance = tRes.StatVariance
            Set stat.RowCount = tRes.StatRowCount
            Set stat.Period = "daily"
            Do stats.Insert(stat)
        }
    } Catch ex {
        Set sc = ex.AsStatus()
        $$$ThrowStatus(sc)
    }

    Quit stats
}

ClassMethod GetHourlyStats(filter As dc.sqlstats.dto.FilterStatsDTO, initList As %ListOfObjects = "") As %ListOfObjects
{

    If $IsObject(initList) {
        Set stats = initList
    } Else {
        Set stats = ##class(%ListOfObjects).%New()
    }

    Try {
        New $ROLES
        Set $ROLES = "%ALL"
        
        If $Namespace '= filter.namespace {
            New $NAMESPACE
            Set $NAMESPACE = filter.namespace
        }
        
    
    
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

        Set sql = "SELECT ID, Day->Day, ""Hour"", StatCount, StatTotal, StatRowCount, StatCommands, StatVariance, StatRowCount, Day->Statement->Hash, Day->Statement->Statement "
                    _ "FROM INFORMATION_SCHEMA.STATEMENT_HOURLY_STATS "
                    _ "WHERE (Day->Day > ? OR (Day->Day = ? AND ""Hour"" >= ?)) "
                    _ "AND (Day->Day < ? OR (Day->Day = ? AND ""Hour"" <= ?)) "
        
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

        While tRes.%Next() {
            Set stat = ##class(dc.sqlstats.dto.SQLStatsDTO).%New()
            Set stat.Id = tRes.ID
            Set stat.Hash = tRes.Hash
            Set stat.Statement = tRes.Statement
            Set stat.DateTime = $ZDate(tRes.Day, 3) _ " " _ tRes.Hour _ ":00:00"
            Set stat.Count = tRes.StatCount
            Set stat.ExecutionTime = tRes.StatTotal
            Set stat.Commands = tRes.StatCommands
            Set stat.Variance = tRes.StatVariance
            Set stat.RowCount = tRes.StatRowCount
            Set stat.Period = "hourly"
            Do stats.Insert(stat)
        }

    } Catch ex {
        Set sc = ex.AsStatus()
        $$$ThrowStatus(sc)
    }

    Quit stats
}

}
