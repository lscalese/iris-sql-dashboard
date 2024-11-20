Class dc.sqlstats.influxdb.bp.IncrementPush Extends Ens.BusinessProcess
{

Parameter ADAPTER = "Ens.InboundAdapter";

Parameter SETTINGS = "NameSpaces";

/// comma seperated list of namespaces
/// use * for all namespaces
Property NameSpaces As %String(MAXLEN = 1000) [ InitialExpression = "*" ];

Method OnProcessInput(pInput As %RegisteredObject, Output pOutput As %RegisteredObject) As %Status
{
    Set sc = $$$OK
	Set BpRequest=##class(Ens.Request).%New()

    Set request = ##class(dc.sqlstats.influxdb.msg.InfluxDataFilter).%New()
    Set request.fromDate = $ZDateTime("0,0", 3, 1)
    Set request.toDate = $ZDateTime($Horolog, 3, 1)
    Set request.namespaces = ..NameSpaces

	;Set sc=..SendRequestSync("YourBusinessProcessName",BpRequest,.BpResponse)
	;
	; OR, if you don't need to wait for the BP to finish:
	;Set sc=..SendRequestAsync("YourBusinessProcessName",BpRequest)
	
	Return sc
}

Storage Default
{
<Data name="IncrementPushDefaultData">
<Subscript>"IncrementPush"</Subscript>
<Value name="1">
<Value>NameSpaces</Value>
</Value>
</Data>
<DefaultData>IncrementPushDefaultData</DefaultData>
<Type>%Storage.Persistent</Type>
}

}
