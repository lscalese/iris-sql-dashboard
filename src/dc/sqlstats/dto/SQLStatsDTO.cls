/// this class is used to store the statistics of a SQL statement
Class dc.sqlstats.dto.SQLStatsDTO Extends (%RegisteredObject, %JSON.Adaptor)
{

/// The SQL statement
Property Statement As %String;

/// The hash of the SQL statement (used in INFORMATION_SCHEMA)
Property Hash As %String;

/// The number of times the SQL statement was executed
Property Count As %Integer;

/// The total execution time of the SQL statement in seconds
Property ExecutionTime As %Double;

/// The variance of the execution time.
Property Variance As %Double;

/// The average execution time of the SQL statement in seconds
Property AvgExecutionTime As %Double;

/// The total commands executed by the SQL statement
Property Commands As %Integer;

/// The average commands executed by the SQL statement
Property AvgCommands As %Double;

/// Date in formatoin yyyy-mm-dd
Property Date As %String;

/// Hour of the day (ex : consider 8 is the range beteween 8 and 9)
Property Hour As %Integer;

/// Date and time in format yyyy-mm-dd hh:mm:ss
Property DateTime As %String;

/// The server name...
Property ServerName As %String;

/// IRIS instance name
Property InstanceName As %String;

/// Namespace of the SQL statement
Property Namespace As %String;

/// The period of the statistics
/// daily or hourly
Property Period As %String;

Property id As %String;

Property RowCount As %Integer;

}
