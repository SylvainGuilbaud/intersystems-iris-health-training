Class Demo.Vector.Base Extends %Persistent [ Abstract, NoExtent ]
{

Property uid As %String(MAXLEN = 40) [ Required ];

Property document As %String(MAXLEN = 65535);

Property embedding As %Vector(DATATYPE = "DOUBLE", LEN = 3072);

Property userName As %String(MAXLEN = 160);

Property timestamp As %TimeStamp;

Property metadata As %String(MAXLEN = 65535);

Index uidIndex On uid [ Unique ];

Index timestampIndex On timestamp;

Index HNSWIndex On (embedding) As %SQL.Index.HNSW(Distance = "DotProduct") [ Type = index ];

}
