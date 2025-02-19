Class dc.sqlstats.tasks.ExportSQLStats Extends %SYS.Task.Definition
{

Parameter TaskName = "Export SQL Stats";

Property ExportDirectory As %String(MAXLEN = 1024) [ InitialExpression = {##class(%SYS.System).TempDirectory()} ];

/// leave empty for all namespaces
/// otherwise, fill in the namespace name
/// you can use comma separated list for multiple namespaces
Property Namespaces As %String(MAXLEN = 1024);

Property LastXDays As %Integer [ InitialExpression = 7 ];

Method OnTask() As %Status
{
    Set tSc = $$$OK
    
    Try {
        Set directory = ##class(%File).NormalizeDirectory(..ExportDirectory)
        Set fileName = directory _ "sqlstats_" _ $Translate($ZDATETIME($HOROLOG, 3, 1), " :","_") _ ".txt"

        If ..Namespaces '= "" {
            Set namespaces = $ListFromString(..Namespaces, ",")
        } Else {
            Set namespaces = ##class(dc.sqlstats.services.SQLStats).GetListNamespaces()
        }

        Set tSc = ##class(dc.sqlstats.services.SQLStats).CreateInfluxFile(fileName, namespaces, ..LastXDays)

    } Catch ex {
        Set tSc = ex.AsStatus()
    }

    Return tSc
}

ClassMethod CreateOnDemandTask(SkipErrorIfTaskAlreadyExists As %Boolean = {$$$YES}) As %Status
{
    Set sc = $$$OK
    Set task = ##class(%SYS.Task).%New()

    Set className = ..%ClassName(1)
    &SQL(SELECT TOP 1 id INTO:taskId FROM %SYS.Task WHERE TaskClass = :className)
    If SQLCODE = 0 {
        Return:SkipErrorIfTaskAlreadyExists $$$OK
        Set sc = $$$ERROR($$$GeneralError, "Task already exists with ID: "_taskId)
        Return sc
    }

    Set task.Name = ..#TaskName
    Set task.Description = "Export SQL Stats in format Line Protocol."
    Set task.NameSpace = $Namespace
    Set task.RunAsUser = $USERNAME
    Set task.TaskClass = ..%ClassName(1)
    
    Set task.TimePeriod=5	; On demand

    Set def = ..%New()
    Do task.AssignSettings(def)

    Set sc = task.%Save()

    If $$$ISERR(sc) {
        Return sc
    }

    Return sc
}

}
