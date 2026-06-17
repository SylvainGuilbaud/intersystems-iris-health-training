Class utils.tools Extends %RegisteredObject
{
ClassMethod DecodeOBX5Document(
    pHL7 As EnsLib.HL7.Message,
    pOBXIndex As %Integer = 1,
    pOutputFile As %String = "/tmp/oru-document.pdf"
) As %Status
{
    set sc = $$$OK

    try {
        // Iterate all segments by index to find the nth OBX with ED datatype
        set edFound = 0
        set segPos = ""

        for i = 1:1:pHL7.SegCount {
            set seg = pHL7.GetSegmentAt(i)
            continue:'$isobject(seg)
            continue:(seg.Name '= "OBX")
            set vt = $zcvt(seg.GetValueAt("2"), "U")
            continue:(vt '= "ED")
            set edFound = edFound + 1
            if edFound = pOBXIndex {
                set segPos = i
                quit
            }
        }

        if segPos = "" {
            set sc = $$$ERROR($$$GeneralError, "No ED-type OBX segment found (looking for occurrence "_pOBXIndex_", found "_edFound_")")
            return sc
        }

        set edSeg = pHL7.GetSegmentAt(segPos)
        set encoding = $zcvt(edSeg.GetValueAt("5.4"), "U")
        set base64   = edSeg.GetValueAt("5.5")

        if encoding '= "BASE64" {
            set sc = $$$ERROR($$$GeneralError, "OBX-5.4 is not Base64")
            return sc
        }

        if base64 = "" {
            set sc = $$$ERROR($$$GeneralError, "No Base64 data found in OBX-5.5")
            return sc
        }

        set base64 = $replace(base64, $char(13), "")
        set base64 = $replace(base64, $char(10), "")

        set binary = $SYSTEM.Encryption.Base64Decode(base64)

        set file = ##class(%Stream.FileBinary).%New()
        set file.Filename = pOutputFile
        do file.Write(binary)
        set sc = file.%Save()
    }
    catch ex {
        set sc = ex.AsStatus()
    }

    return sc
}
}
