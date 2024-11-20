Class dc.sqlstats.influxdb.msg.InfluxDataFilter Extends Ens.Request
{

/// Starting date    
Property fromDate As %TimeStamp;

/// Ending date
Property toDate As %TimeStamp;

/// comma seperated list of namespaces
/// use * for all namespaces
Property namespaces As %String [ InitialExpression = {$Namespace} ];

Storage Default
{
<Data name="InfluxDataFilterDefaultData">
<Subscript>"InfluxDataFilter"</Subscript>
<Value name="1">
<Value>fromDate</Value>
</Value>
<Value name="2">
<Value>toDate</Value>
</Value>
<Value name="3">
<Value>namespaces</Value>
</Value>
</Data>
<DefaultData>InfluxDataFilterDefaultData</DefaultData>
<Type>%Storage.Persistent</Type>
}

}
