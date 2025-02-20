Class dc.sqlstats.services.Install
{

/// <summary>
/// Initializes the SQL statistics service by setting up the necessary namespace and package mappings.
/// </summary>
/// <remarks>
/// This method performs the following steps:
/// 1. Retrieves the current namespace.
/// 2. Switches to the "%SYS" namespace and sets the default database for globals.
/// 3. Checks if the "%All" namespace exists, and if not, creates it.
/// 4. Retrieves the properties of the original namespace.
/// 5. Checks if the "dc.sqlstats" package is mapped in the "%All" namespace, and if not, maps it.
/// 6. Returns the final status code.
/// </remarks>
/// <returns>%Status - The status code indicating the success or failure of the initialization process.</returns>
ClassMethod Init() As %Status
{
    Set sc = $$$OK

    Set ns = $Namespace
    
    New $Namespace 
    Set $Namespace = "%SYS", p("Globals") = "%DEFAULTDB"

    Set webName = "/csp/sqlstats/api"
    If '##class(Security.Applications).Exists(webName) {
        ; Should be done by zpm, but in case of manual installation, we need to do it here
        Set cspDirectory = $System.Util.InstallDirectory()_"csp/sqlstats/api/"
        set webProperties("Path") = cspDirectory
        set webProperties("CookiePath")="/csp/sqlstats/api/"
        set webProperties("NameSpace") = ns
        set webProperties("Enabled") = 1
        set webProperties("CSPZENEnabled") = 1
        set webProperties("AutheEnabled") = 32
        set webProperties("DeepSeeEnabled") = 0
        set webProperties("iKnowEnabled") = 0
        Set webProperties("DispatchClass")="dc.sqlstats.rest.Main"
        Set webProperties("IsNameSpaceDefault") = 0
        set sc = $$$ADDSC(sc,##class(Security.Applications).Create(webName,.webProperties))
    }

    Set $Namespace = ns
    
    Set sc = ##class(dc.sqlstats.tasks.ExportSQLStats).CreateOnDemandTask()
    
    Return sc
}

ClassMethod GenExportXML(exportSourceFile As %String = "/home/irisowner/dev/export.xml") As %Status
{
    Set sc = $SYSTEM.OBJ.Export("dc.sqlstats.*.CLS",exportSourceFile)
    Return sc
}

/// copy / paste the lines below to the terminal to update the code from GitHub
ClassMethod UpdateFromGitHub()
{
    set ns=$namespace,$namespace="%SYS" do ##class(Security.SSLConfigs).Create("ssl") set $namespace=ns,r=##class(%Net.HttpRequest).%New(),r.Server="raw.githubusercontent.com",r.SSLConfiguration="ssl" do r.Get("/lscalese/iris-sql-dashboard/refs/heads/master/export.xml"),$system.OBJ.LoadStream(r.HttpResponse.Data,"c"),##class(dc.sqlstats.services.Install).Init()
}

}
