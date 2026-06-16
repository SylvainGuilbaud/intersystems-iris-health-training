> Tags: `draft` <br/>
> 🚧 **Page under construction**

See at [IHE-FR-ADT-Segments](/DOCUMENTATION/Patient-Administration-Management-flow/IHE-FR-ADT-Segments) for MSH, PID and PV1 segments.

This flow corresponds to the transaction Order Results management [LAB-3] of the Laboratory Testing Workflow [LTW] IHE profile.

# Segment ORC


| SEQ | LEN | DT  | Usage | Description                  | Repeatable? | Remarks                     | Database column |
| --- | --- | --- | ----- | ---------------------------- | ----------- | --------------------------- | --------------- |
| 1   | 2   | ID  | R     | Order Control                |             | A results message is always `SC` (Status Change) | Constant `SC` |
| 2   | 22  | EI  | O     | Placer Order Number          |             | - | Does not exist in DGLab |
| 3   | 22  | EI  | O     | Filler Order Number          |             | - | Does not exist in DGLab |
| 4   | 22  | EI  | R     | Placer Group Number          |             | Request identifier | LB_DEMANDES.LBDE_NLAB |
| 5   | 2   | ID  | O     | Order Status                 |             | `CM` when the order is closed, otherwise `IP` | Derived from LB_DEMANDES.LBDE_CLOS |
| 7   | 200 | TQ  | O     | Quantity/Timing              |             | - | Not mapped |
| 9   | 26  | TS  | R     | Date/Time of Transaction     |             | Date/time of this release of the laboratory report produced for this Order Group. | Generated at message creation (system date/time) |
| 12  | 120 | XCN | O     | Ordering Provider            |             | - | LB_REQUERANTS.RID_EXTERNE (fallback LB_DEMANDES.RID) |
| 15  | 26  | TS  | O     | Order Effective Date/Time    |             | - | LB_DEMANDES.LBDE_DTDEM |

# Segment OBR

| SEQ | LEN | DT  | Usage | Description                         | Repeatable? | Remarks | Database column |
| --- | --- | --- | ----- | ----------------------------------- | ----------- | ------- | --------------- |
| 1   | 4   | SI  | O     | Set ID - OBR                        |             |   For the first order transmitted, the sequence number shall be 1; for the second order, it shall be 2; and so on. | Sequential index (generated) |
| 2   | 22  | EI  | -     | Placer Order Number                 |             | As assigned by Order Placer  | Does not exist in DGLab |
| 3   | 22  | EI  | -     | Filler Order Number                 |             | As assigned by Order Filler | Does not exist in DGLab |
| 4   | 250 | CE  | R     | Universal Service Identifier        |             |  |  |
| 4.1 |     | ST  | R     | Code                                |             | Test code | LB_ATOMES.LBAT_CDE4 |
| 4.2 |     | ST  | R     | Text                                |             | Test description | LB_DIC2.LIB_IMP (printed label) |
| 4.3 |     | ST  | R     | Name of Coding System               |             | `L` for local or `LN` for LOINC | Constant (`L` / `LN`) |
| 7   | 26  | TS  | O     | Observation Date/Time               |             | Collection time | LB_DEMANDES.LBDE_DTPRV |
| 8   | 26  | TS  | O     | Observation End Date/Time           |             | - | LB_ATOMES.LBAT_DATRES |
| 16  | 120 | XCN | O     | Ordering Provider                   |             | - | LB_REQUERANTS.RID_EXTERNE (fallback LB_DEMANDES.RID) |
| 18  | 60  | EI  | O     | Placer Field 1                      |             | - | Not mapped |
| 24  | 26  | TS  | O     | Diagnostic Serv Sect ID             |             | - | Not mapped |
| 25  | 1   | ID  | R     | Result Status                       |             | P, F, C, X - The report is Preliminary, Final, Corrected (after final) or canceled (X). When existing, it contains only verified results (i.e., clinically validated). | LB_ATOMES.APPREC |

# Segment OBX

Based on example messages:
```
OBX|1|CE|FSCB^FSC MCLIN|1|FSCBO^FSC insérée.||||||F||||||||
OBX|2|TX|NUM^Numération|1|||||||||||||||
OBX|5|ED|PDFREPORT|1|...Base64...||||||F||||||||

```

| SEQ | LEN | DT     | Usage | Description                  | Repeatable? | Remarks | Database column |
| --- | --- | ------ | ----- | ---------------------------- | ----------- | ------- | --------------- |
| 1   | 4   | SI     | O     | Set ID - OBX                 |             | Sequence number| Sequential index (generated) |
| 2   | 2   | ID     | R     | Value Type                   |             | `NM`, `CE`, `CWE`, `TX`, `SN`, `TS` | Constant `TX` |
| 3   | 250 | CE     | R     | Observation Identifier       |             |  |  |
| 3.1 |     | ST     | R     | Code                         |             | Test code | LB_ATOMES.LBAT_CDE4 |
| 3.2 |     | ST     | R     | Text                         |             | Test code | LB_DIC2.LIB_IMP (printed label) |
| 3.3 |     | ID     | R     | Name of Coding System        |             | `L` for local or `LN` for LOINC | Constant (`L` / `LN`) |
| 4   | 20  | ST     | O     | Observation Sub-ID           |             | Always `1` | Constant `1` |
| 5   | 999 | Varies | C     | Observation Value            |             | Result value | LB_ATOMES.LBAT_RALPH1 / LBAT_RALPH2 (via ResAlpha) |
| 11  | 1   | ID     | R     | Observation Result Status    |             | The report is Preliminary, Final, Corrected, Deleted, or cannot be produced (X). In the two latter cases (D or X) OBX-5.1 SHALL be nullified (populated with two double quotes)  | LB_ATOMES.APPREC |
| 13  | 250 | ST     | R     | User Defined Access Checks   |             | `P` or empty. P means this report should be viewed only by privileged users. | Configurable (`P` or empty) |
| 15  | 250 | CE     | O     | Producer's ID                |             | Not used | Not used |

OBX segment dedicated to the PDF report of the request:
Only the field differing from standard OBX are writen

| SEQ | LEN | DT     | Usage | Description                  | Repeatable? | Remarks |
| --- | --- | ------ | ----- | ---------------------------- | ----------- | ------- |
| 2   | 2   | ID     | R     | Value Type                   |             | `ED` or `RP` for PDF reports |
| 3   | 250 | CE     | R     | Observation Identifier       |             | The observation is the laboratory report itself `PDFREPORT` for instance - When using LOINC we can use LOINC® code “11502-2” and the corresponding name “LABORATORY REPORT.TOTAL”  |
| 5   | 999 | Varies | R     | Observation Value            |             |  |

When report is only pointed, value type is RP.

| SEQ | LEN | DT     | Usage | Description                  | Repeatable? | Remarks |
| --- | --- | ------ | ----- | ---------------------------- | ----------- | ------- |
| RP.1 |     | ST     | R     | Pointer                      |             | URL of the laboratory report. The syntax of the URL SHALL be conformant with RFC1738 and RFC1808. |
| RP.2 |     | HD     | R     | Application ID               |             | Unique ID assigned to the OF application  |
| RP.3 |     | HD     | R     | Type Of Data                 |             | `AP` - Other application data. The report is not to be interpreted by a HL7 parser. |
| RP.4 |     | ID     | R     | Subtype                      |             | `PDF` - The laboratory report is in pdf format   |

When embedding the report, the value type is ED:
- ED.1 = file name (e.g. `asr01712.pdf`)
- ED.2 = type (`AP`)
- ED.3 = subtype (`Octet-stream` for PDF, `XML` for CDA)
- ED.4 = encoding (`Base64`)
- ED.5 = Base64 content

# parameters to be set in algorithm for ORU to EMR

| Variable name | Datatype | Description |
| ------------- | -------- | ----------- |
| destinationFolder | string | Destination folder (under the root) where the generated HL7 ORU message file is saved (e.g. `Datas\Interface\HL7\ORU`). |
| withPdfReport | bool | Whether to include the PDF report facsimile ("Report Facsimile for Order Group"). `true` = emit the PDF OBX section; `false` = skip it. |
| isPdfEmbedded | bool | How the PDF is sent. `true` = embedded as Base64 (OBX-2 = `ED`); `false` = linked by URL pointer (OBX-2 = `RP`). |
| pdfObrServiceId | string | OBR-4.1 (Universal Service Identifier) for the PDF's own OBR. When set, the report is carried under a dedicated `OBR#PDF` using this value; when empty (`""`), no dedicated OBR is emitted and the report OBX is attached to the main result OBR. |
| pdfObxObservationId | string | OBX-3.1 (Observation Identifier) carried by the PDF report OBX (e.g. `PDFREPORT`, or LOINC `11502-2`). |
| pdfReportBaseUrl | string | Base URL/location used to build the RFC1738/RFC1808-conformant RP.1 pointer when the report is linked (`isPdfEmbedded = false`). The PDF file name is appended to it. |
| includePdfUuid | bool | `true` = emit an extra CE OBX carrying a document UUID alongside the embedded PDF; `false` = send only the ED OBX. |
| sendingApplication | string | MSH-3 Sending Application (e.g. `DGLab`). |
| sendingFacility | string | MSH-4 Sending Facility (e.g. `LAB`). |
| receivingApplication | string | MSH-5 Receiving Application (e.g. `OpenMedical`). |
| receivingFaciity | string | MSH-6 Receiving Facility (e.g. `KIS`). |
| codingSystem | string | Coding system used in OBR-4.3 / OBX-3.3. `#L` for local codes or `#LN` for LOINC. (Prefix `#` bypasses escaping.) |
| accessCheck | string | OBX-13 User Defined Access Checks. `P` = report viewable only by privileged users; empty = no restriction. (Prefix `#` bypasses escaping.) |
| phoneFrenchLayout | bool | PID-13 telecom layout. `true` = French (FR) profile (phone number in XTN.12); `false` = international (INT) profile (phone number in XTN.1). E-mail always uses XTN.4. |



