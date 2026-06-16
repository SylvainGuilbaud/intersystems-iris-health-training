> Tags: `draft`<br/>
> 🚧 **Page under construction**

# HL7 Acknowledgment Message Field Description (ACK - Generic, A01 Reference)

## Source Message (example)
```
MSH|^~\&|LIS|LIS_FAC|PAS|PAS_FAC|20110930104513||ACK^A01^ACK|TD0000027034|P|2.5|||||FR|8859/1|FR|||
MSA|AR|5192_EH10_201|
ERR|||207^Application internal error|E|
```

---

## MSH Segment (Message Header)

| Field | Name | Value | Description |
|------|------|--------|-------------|
| MSH-1 | Field Separator | `|` | Delimiter used to separate fields |
| MSH-2 | Encoding Characters | `^~\&` | Characters used to separate components, repetitions, escape, and subcomponents |
| MSH-3 | Sending Application | `LIS` | Application that sent the message |
| MSH-4 | Sending Facility | `LIS_FAC` | Facility that generated the message |
| MSH-5 | Receiving Application | `PAS` | Destination application |
| MSH-6 | Receiving Facility | `PAS_FAC` | Destination facility |
| MSH-7 | Date/Time of Message | `20110930104513` | Timestamp of message creation (YYYYMMDDHHMMSS) |
| MSH-9 | Message Type | `ACK^A01^ACK` | Acknowledgment message for ADT A01 (generic pattern) |
| MSH-10 | Message Control ID | `TD0000027034` | Unique identifier of the message |
| MSH-11 | Processing ID | `P` | Processing mode (P = Production) |
| MSH-12 | Version ID | `2.5` | HL7 version |
| MSH-17 | Country Code | `FR` | Country of origin |
| MSH-18 | Character Set | `8859/1` | Character encoding (ISO-8859-1) |
| MSH-19 | Principal Language | `FR` | Language of the message |

---

## MSA Segment (Message Acknowledgment)

| Field | Name | Value | Description |
|------|------|--------|-------------|
| MSA-1 | Acknowledgment Code | `AR` | Acknowledgment status: AR = Application Reject |
| MSA-2 | Message Control ID | `5192_EH10_201` | Identifier of the original message being acknowledged |

Common values for MSA-1:
- AA = Application Accept
- AE = Application Error
- AR = Application Reject

---

## ERR Segment (Error)

| Field | Name | Value | Description |
|------|------|--------|-------------|
| ERR-3 | HL7 Error Code | `207` | Standard HL7 error code |
| ERR-3.2 | Error Description | `Application internal error` | Human-readable error description |
| ERR-4 | Severity | `E` | Severity level (E = Error) |

Common severity values:
- I = Information
- W = Warning
- E = Error

---

## Summary

This ACK message indicates:

- A **negative acknowledgment (AR)** at the application level
- The original message was **rejected**
- An **internal processing error** occurred (HL7 code 207)

This structure is generic and applies to any ACK message (e.g., A01, A04), not tied to a specific trigger event.

