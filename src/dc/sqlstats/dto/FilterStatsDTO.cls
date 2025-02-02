Class dc.sqlstats.dto.FilterStatsDTO Extends %RegisteredObject
{

/// Starting date    
Property from As %TimeStamp;

/// Ending date
Property to As %TimeStamp;

/// The SQL statement hash
Property hash As %String;

/// The namespace used to retrieve sql stats
Property namespace As %String;

/// period "daily", "hourly"
Property period As %String;

}
