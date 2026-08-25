/// Postal address normalized according to La Poste rules (France).
/// Maximum 6 lines, 38 characters per line, no punctuation, last 3 lines in uppercase.
/// See: https://www.laposte.fr/conseils-pratiques/bien-rediger-l-adresse-d-une-lettre-ou-d-un-colis
Class data.address Extends (%SerialObject, %XML.Adaptor, %JSON.Adaptor,%Populate)
{

/// Line 1: recipient name or company name.
Property Name As %String(MAXLEN = 38);

/// Line 2: recipient complement (apartment, floor, department...).
Property RecipientComplement As %String(MAXLEN = 38);

/// Line 3: geographic complement (building, residence, entrance...).
Property GeographicComplement As %String(MAXLEN = 38);

/// Line 4: number, type and street name (number placed before the street name).
Property Street As %String(MAXLEN = 38,POPSPEC = "Street()");

/// Line 5: locality or PO box.
Property LocalityPOBox As %String(MAXLEN = 38);

/// Line 6 (part 1): 5-digit postal code.
Property PostalCode As %String(MAXLEN = 5, PATTERN = "5N", POPSPEC = "USZip()") [ Required ];

/// Line 6 (part 2): city.
Property City As %String(MAXLEN = 32) [ Required ];

/// Country line for international addresses (uppercase). Empty for France.
Property Country As %String(MAXLEN = 38);

/// Returns the address formatted per La Poste rules (last lines in uppercase, no punctuation).
Method Format() As %String
{
	Set tLines = ""
	For tProp = "Name", "RecipientComplement", "GeographicComplement", "Street", "LocalityPOBox" {
		Set tVal = $ZStrip($Property($This, tProp), "<>W")
		If tVal '= "" {
			Set tLines = tLines _ $Select(tLines = "" : "", 1 : $Char(10)) _ tVal
		}
	}
	Set tCityLine = $ZConvert($ZStrip($ZStrip(..PostalCode, "<>W") _ " " _ ..City, "<>W"), "U")
	Set tLines = tLines _ $Select(tLines = "" : "", 1 : $Char(10)) _ tCityLine
	If $ZStrip(..Country, "<>W") '= "" {
		Set tLines = tLines _ $Char(10) _ $ZConvert($ZStrip(..Country, "<>W"), "U")
	}
	Return tLines
}


Storage Default
{
<Data name="addressState">
<Value name="1">
<Value>Name</Value>
</Value>
<Value name="2">
<Value>RecipientComplement</Value>
</Value>
<Value name="3">
<Value>GeographicComplement</Value>
</Value>
<Value name="4">
<Value>Street</Value>
</Value>
<Value name="5">
<Value>LocalityPOBox</Value>
</Value>
<Value name="6">
<Value>PostalCode</Value>
</Value>
<Value name="7">
<Value>City</Value>
</Value>
<Value name="8">
<Value>Country</Value>
</Value>
</Data>
<State>addressState</State>
<StreamLocation>^data.addressS</StreamLocation>
<Type>%Storage.Serial</Type>
}

}
