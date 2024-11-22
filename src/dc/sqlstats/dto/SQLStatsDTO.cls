/// this class is used to store the statistics of a SQL statement
Class dc.sqlstats.dto.SQLStatsDTO Extends (%RegisteredObject, %JSON.Adaptor)
{

/// The SQL statement
Property Statement As %String(%JSONFIELDNAME = "statement");

/// The hash of the SQL statement (used in INFORMATION_SCHEMA)
Property Hash As %String(%JSONFIELDNAME = "hahs");

/// The number of times the SQL statement was executed
Property Count As %Integer(%JSONFIELDNAME = "count");

/// The total execution time of the SQL statement in seconds
Property ExecutionTime As %Double(%JSONFIELDNAME = "execution_time");

/// The variance of the execution time.
Property Variance As %Double(%JSONFIELDNAME = "variance");

/// The total commands executed by the SQL statement
Property Commands As %Integer(%JSONFIELDNAME = "commands");

/// Date and time in format yyyy-mm-dd hh:mm:ss
Property DateTime As %String(%JSONFIELDNAME = "datetime");

/// The server name...
Property ServerName As %String(%JSONFIELDNAME = "server_name") [ InitialExpression = {##class(%SYS.System).GetNodeName()} ];

/// IRIS instance name
Property InstanceName As %String(%JSONFIELDNAME = "instance_name") [ InitialExpression = {##class(%SYS.System).GetInstanceName()} ];

/// Namespace of the SQL statement
Property Namespace As %String(%JSONFIELDNAME = "namespace") [ InitialExpression = {$Namespace} ];

/// The period of the statistics
/// daily or hourly
Property Period As %String(%JSONFIELDNAME = "period");

Property Id As %String(%JSONFIELDNAME = "id");

Property RowCount As %Integer(%JSONFIELDNAME = "row_count");

}
