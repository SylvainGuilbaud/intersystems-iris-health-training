Class IRISAPP.transfo.sqltofhir.Util Extends %RegisteredObject
{

/// Deterministic urn:uuid for stable ids (good for Bundle internal references)
ClassMethod UrnUuid(prefix As %String, id As %String) As %String [ Language = python ]
{
    import uuid

    prefix = (prefix or "").strip().lower()
    id = (id or "").strip()
    uuid = str(uuid.uuid4())

    #; return f"urn:uuid:{prefix}-{id}-{uuid}"
    return f"urn:uuid:{uuid}"
}

ClassMethod ToFHIRDateTime(x As %String) As %String [ Language = python ]
{
from datetime import datetime
from zoneinfo import ZoneInfo

# Parse input string (naive datetime)
dt_naive = datetime.strptime(x, "%Y-%m-%d %H:%M:%S")

# Attach Europe/Paris timezone
dt_paris = dt_naive.replace(tzinfo=ZoneInfo("Europe/Paris"))

# Return ISO 8601 format with timezone
return dt_paris.isoformat()
}

}
