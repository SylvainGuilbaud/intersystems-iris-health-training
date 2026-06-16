> Tags: `draft`<br/>
> 🚧 **Page under construction**

[[_TOC_]]

Components that will not be used in ITI-30/ITI-31 FR is not listed here.


# Segment PID

| SEQ | LEN | DT  | Usage | Description                           | Repeatable? | Remarks | Database column (ADT) | Database column (ORU to EMR) |
| --- | --- | --- | ----- | ------------------------------------- | ----------- | ------- | --------------------- | ---------------------------- |
| 1   | 4   | SI  | O     | Set ID - PID                          |             | N/A |                       | Constant `1` |
| 3   | 250 | CX  | R     | Patient Identifiers                   | Y           | See #PID-3-Patient-Identifier-List |                       | `LB_CAS_SEJOUR.PID` (local id); INS from `LB_PATIENTS.INS` / `OID_INS` / `TYPE_INS` |
| 5   | 250 | XPN | R     | Patient Name                          | Y           | See #PID-5-Patient-Name |                       | Legal: `LB_PATIENTS.LBPA_NOM`, `LBPA_PRE`, `POLITESSE`; Maiden: `LBPA_JEUNE`, `LBPA_PRE_JEUNE` |
| 6   | 250 | XPN | O     | Mother's Maiden Name                  | Y           | N/A | Not mapped            | Not mapped |
| 7   | 26  | TS  | C     | Date/Time of Birth                    |             | See #PID-7-Date-Time-of-Birth | `LB_PATIENTS.LBPA_NAI`    | `LB_PATIENTS.LBPA_NAI` (precision from `TYPE_DTNAISSANCE`) |
| 8   | 1   | IS  | C     | Administrative Sex Table#0001         |             | See #PID-8-Sex | `LB_PATIENTS.LBPA_SEXE` | `LB_PATIENTS.LBPA_SEXE` |
| 11  | 250 | XAD | C     | Patient Address                       | Y           | See #PID-11-Patient-Address |                       | `LB_PATIENTS.LBPA_ADR1`, `LBPA_ADR2`, `LBPA_CHEZ`, `LBPA_NPA`, `LBPA_PAYS`, `CODE_INTERNATIONAL_NAI` |
| 13  | 250 | XTN | O     | Phone Number - Home                   | Y           | See #PID-13-Phone-Number-Home |                       | `LB_PATIENTS.E_MAIL`, `LBPA_TEL`, `TELEPHONE2` |
| 14  | 250 | XTN | O     | Phone Number - Business               | Y           |     |                       | Not mapped (mobile carried in PID-13) |
| 15  | 250 | CE  | O     | Primary Language Table#0296           |             |     |                       | `LB_PATIENTS.LBPA_LANGUE` |
| 16  | 250 | CE  | O     | Marital Status Table#0002             |             |     |                       | Not mapped |
| 18  | 250 | CX  | C     | Patient Account Number                |             |     |                       | Not mapped |
| 21  | 250 | CX  | O     | Mother's Identifier                   | Y           |     |                       | Not mapped |
| 23  | 250 | ST  | O     | Birth Place                           |             | `LB_PATIENTS.LBPA_LIEU_NAI` |                       | `LB_PATIENTS.LBPA_LIEU_NAI` |
| 24  | 1   | ID  | O     | Multiple Birth Indicator Table#0136   |             |     |                       | Not mapped |
| 25  | 2   | NM  | C     | Birth Order                           |             |     |                       | Not mapped |
| 26  | 250 | CE  | O     | Citizenship Table#0171                | Y           |     |                       | `LB_PATIENTS.LBPA_PAYS` |
| 27  | 250 | CE  | O     | Veterans Military Status Table#0172   |             |     |                       | `LB_PATIENTS.LBPA_PROF` (non-standard use of PID-27) |
| 29  | 26  | TS  | O     | Patient Death Date and Time           |             |     |                       | Not mapped |
| 30  | 1   | ID  | O     | Patient Death Indicator Table#0136    |             |     |                       | Not mapped |
| 31  | 1   | ID  | CE    | Identity Unknown Indicator Table#0136 |             |     |                       | Not mapped |
| 32  | 20  | IS  | R     | Identity Reliability Code Table#0445  | Y           |     | `LB_PATIENTS.STATUS_INS` | `LB_PATIENTS.STATUS_INS` |
| 33  | 26  | TS  | C     | Last Update Date/Time                 |             |     |                       | Not mapped |
| 34  | 241 | HD  | O     | Last Update Facility                  |             |     |                       | Not mapped |
| 35  | 250 | CE  | C     | Species Code Table#446                |             |     |                       | Not mapped |
| 36  | 250 | CE  | C     | Breed Code Table#447                  |             |     |                       | Not mapped |
| 37  | 80  | ST  | O     | Strain                                |             |     |                       | Not mapped |
| 38  | 250 | CE  | O     | Production Class Code Table#429       | Y           |     |                       | Not mapped |
| 39  | 250 | CWE | O     | Tribal Citizenship Table#0171         | Y           |     |                       | Not mapped |

## PID-3 Patient Identifier List
ID Type can be one of the following identified by `PID-3.5` or `CX-5` (Identifier Type Code):

| Name    | Code      | `LB_PATIENTS.INS_TYPE` |OID                |
| ------- | --------- | ---------------------- |-------------------|
| INS-NIR | `INS-NIR` | 2                      |1.2.250.1.213.1.4.8|
| INS-NIA | `INS-NIA` | 1                      |1.2.250.1.213.1.4.9|
| IPP     | `PI`      |                        |                   |
| Unknown | N/A       | 0                      |                   |

No mapping yet for the above identifiers, but they should be used in the French context.

| Database Mapping           | Max Length | Description                            |
| ---------------------------| ---------- | -------------------------------------- |
| `LB_PATIENTS.NPAT_EXTERNE` | 20         | Patient number from an external system |
| `LB_PATIENTS.INS`          | 255        | Patient INS                            |
| `LB_PATIENTS.OID_INS`      | 255        | OID of INS issuer                      |

## PID-5 Patient Name
Name Type Code can be one of the following identified by `PID-5.7` or `XPN-7` (Name Type Code):

| Name           | Code | Description                           | Remarks |
| -------------- | ---- | ------------------------------------- | ------- |
| Preferred Name | `D`  | Common name, but not legal            |         |
| Legal Name     | `L`  | Official name used for legal purposes |         |
| Maiden Name    | `M`  | Not specified                         | Should not used in French context |

**ALWAYS**

| XPN | XPN-7            | Database Mapping               | Description                      | Max Length |
| --- | ---------------- | ------------------------------ | -------------------------------- | ---------- |
| 1   | `L`              | `LB_PATIENTS.LBPA_NOM`         | Last Name                        | 100        |
| 2   | `L`              | `LB_PATIENTS.LBPA_PRE`         | First Name                       | 40         |
| 5   | (first entry)?   | `LB_PATIENTS.POLITESSE`        | Title (e.g. Mr. Mrs.)            | `smallint`<br/>Synonym.xml will be used to transcode |

**FRENCH CONTEXT** (the birth name remains the legal name for life)

| XPN | XPN-7            | Database Mapping               | Description                      | Max Length |
| --- | ---------------- | ------------------------------ | -------------------------------- | ---------- |
| 1   | Always `L`       | `LB_PATIENTS.LBPA_NOM`         | Last Name                        | 100        |
| 2   | Always `L`       | `LB_PATIENTS.LBPA_PRE`         | First Name                       | 40         |
| 1   | `D`              | `LB_PATIENTS.JEUNE`            | Name at Birth (Maiden Name)      | 30         |
| 2   | `D`              | `LB_PATIENTS.LBPA_PRE_JEUNE`   | First Name at Birth (Maiden Name)| 255        |

**USA CONTEXT** (or any country where the legal name is not necessarily the birth name)

| XPN | XPN-7            | Database Mapping               | Description                            | Max Length |
| --- | ---------------- | ------------------------------ | -------------------------------------- | ---------- |
| 1   | `M`              | `LB_PATIENTS.JEUNE`            | Fr. _Nom utilisé_ / Alternate name     | 30         |
| 2   | `M`              | `LB_PATIENTS.LBPA_PRE_JEUNE`   | Fr. _Prénom utilisé_ / First Name      | 255        |



## PID-7 Date/Time of Birth

| Database Mapping | Description |
| --- | --- |
| `LB_PATIENTS.LBPA_NAI` | Date of Birth |
| `LB_PATIENTS.TYPE_DTNAISSANCE` | Date Type: <br/> `0` - Complete <br/> `1` - Month + Year <br/> `2` - Year  <br/> `3` - Unknown   |

## PID-8 Sex

Allowed values for `LB_PATIENTS.LBPA_SEXE` are:

| Code | Description |
|------|-------------|
| `M`  | Male        |
| `F`  | Female      |
| `N`  | Unknown     |

ToDo 🚩Should be `U` and not `N` for Unknown

## PID-11 Patient Address

| Database Mapping           | XAD-7 | XAD | Max Length | Remarks                              |
| ---------------------------| ----- | --- | ---------- | ------------------------------------ |
| `LB_PATIENTS.LBPA_ADR1`    | `H`   | 1   | 30         | Rue                                  |
| `LB_PATIENTS.LBPA_ADR2`    | `H`   | 2   | 30         | Localite                             |
| `LB_PATIENTS.LBPA_CHEZ`    | `H`   | 3   | 30         | lign complementaire, par ex. c/o     |
| `LB_PATIENTS.LBPA_NPA`     | `H`   | 5   | 10         | postal number                        |
| `LB_PATIENTS.LBPA_PAYS`    | `H`   | 6   | 25         | Country code                         |
| `LB_PATIENTS.CODE_INTERNATIONAL_NAI`| `BDL`  | 6   | 25         | Country code at birth                |

## PID-13 Phone Number - Home

| Database Mapping         | XTN-3      | Max Length | XTN SEG FR | XTN SEG INT | Remarks |
| ------------------------ | ---------- | ---------- | -------    |-------------|---------|
| `LB_PATIENTS.E_MAIL`     | `Internet` | 256        | 4          | 4           | E-Mail |
| `LB_PATIENTS.LBPPA_TEL`  | `PH`       | 20         | 12         | 1           | Home phone number   |
| `LB_PATIENTS.TELEPHONE2` | `CP`       | 30         | 12         | 1           | Mobile phone number |

# Segment PV1

HL7 PV1 Segment (IHE FR, up to PV1-52)

| SEQ | DT  | Usage | Repeatable | HL7 TBL# | ELEMENT NAME                   | IHE FR | Database Mapping | Database column (ORU to EMR) |
|-----|-----|-------|------------|----------|--------------------------------|--------|------------------|------------------------------|
| 1   | SI  | O     |            |          | Set ID - PV1                   |        |                  | Constant `1` |
| 2   | IS  | R     |            | 0004     | Patient Class                  | *      | `LB_CAS_SEJOUR.AMBHOS` (string max length = 1) | `LB_CAS_SEJOUR.AMBHOS` (mapped to HL7 0004: `A`→`O`, else `I`) |
| 3   | PL  | C     |            |          | Assigned Patient Location      | *      |                  | `LB_CAS_SEJOUR.LIT`, `LB_CAS_SEJOUR.UNIT`, `LB_CAS_SEJOUR.CLIN` |
| 4   | IS  | O     |            | 0007     | Admission Type                 |        |                  |                  |
| 5   | CX  | C     |            |          | Preadmit Number                | *      |                  |                  |
| 6   | PL  | C     |            |          | Prior Patient Location         |        |                  |                  |
| 7   | XCN | O     | Y          | 0010     | Attending Doctor               | *      |                  |                  |
| 8   | XCN | O     | Y          | 0010     | Referring Doctor               |        | `LB_REQUERANTS.RID_EXTERNE` | `LB_REQUERANTS.RID_EXTERNE` |
| 9   | XCN | X     |            | 0010     | Consulting Doctor              |        |                  |                  |
| 10  | IS  | O     |            | 0069     | Hospital Service               | *      |                  |                  |
| 11  | PL  | C     |            |          | Temporary Location             |        |                  | `LB_CAS_SEJOUR.CLIN` |
| 12  | IS  | O     |            | 0087     | Preadmit Test Indicator        |        |                  |                  |
| 13  | IS  | O     |            | 0092     | Re-admission Indicator         |        |                  |                  |
| 14  | IS  | O     |            | 0023     | Admit Source                   | *      |                  |                  |
| 15  | IS  | O     | Y          | 0009     | Ambulatory Status              |        |                  |                  |
| 16  | IS  | O     |            | 0099     | VIP Indicator                  |        |                  |                  |
| 17  | XCN | O     | Y          |          | Admitting Doctor               | *      |                  |                  |
| 18  | IS  | O     |            | 0018     | Patient Type                   |        |                  |                  |
| 19  | CX  | C     |            |          | Visit Number                   |        | `LB_CAS_SEJOUR.FID` (int) | `LB_CAS_SEJOUR.FID` |
| 20  | IS  | O     | Y          | 0064     | Financial Class                |        |                  |                  |
| 21  | IS  | O     |            | 0032     | Charge Price Indicator         |        |                  | `LB_CAS_SEJOUR.CC` |
| 22  | IS  | O     |            | 0045     | Courtesy Code                  |        |                  |                  |
| 23  | IS  | O     |            | 0046     | Credit Rating                  |        |                  |                  |
| 24  | DT  | O     | Y          | 0044     | Contract Code                  |        |                  |                  |
| 25  | DT  | O     | Y          |          | Contract Effective Date        |        |                  |                  |
| 26  | NM  | O     | Y          |          | Contract Amount                |        |                  |                  |
| 27  | NM  | O     | Y          |          | Contract Period                |        |                  |                  |
| 28  | IS  | O     |            | 0073     | Interest Code                  |        |                  |                  |
| 29  | DT  | O     |            | 0110     | Transfer to Bad Debt Code      |        |                  |                  |
| 30  | DT  | O     |            |          | Transfer to Bad Debt Date      |        |                  |                  |
| 31  | IS  | O     |            | 0021     | Bad Debt Agency Code           |        |                  |                  |
| 32  | NM  | O     |            |          | Bad Debt Transfer Amount       |        |                  |                  |
| 33  | NM  | O     |            |          | Bad Debt Recovery Amount       |        |                  |                  |
| 34  | IS  | O     |            | 0111     | Delete Account Indicator       |        |                  |                  |
| 35  | DT  | O     |            |          | Delete Account Date            |        |                  |                  |
| 36  | IS  | C     |            | 0112     | Discharge Disposition          | *      |                  |                  |
| 37  | PL  | O     |            | 0113     | Discharged to Location         |        |                  |                  |
| 38  | IS  | O     |            | 0114     | Diet Type                      |        |                  |                  |
| 39  | IS  | O     |            | 0115     | Servicing Facility             |        |                  |                  |
| 40  | IS  | X     |            |          | Bed Status                     |        |                  |                  |
| 41  | IS  | O     |            | 0117     | Account Status                 |        |                  |                  |
| 42  | PL  | C     |            |          | Pending Location               |        |                  |                  |
| 43  | PL  | O     |            |          | Prior Temporary Location       |        |                  |                  |
| 44  | TS  | C     |            |          | Admit Date/Time                |        | `LB_CAS_SEJOUR.ENTREE` | `LB_CAS_SEJOUR.ENTREE` |
| 45  | TS  | C     |            |          | Discharge Date/Time            |        | `LB_CAS_SEJOUR.SORTIE` | `LB_CAS_SEJOUR.SORTIE` |
| 46  | NM  | O     |            |          | Current Patient Balance        |        |                  |                  |
| 47  | NM  | O     |            |          | Total Charges                  |        |                  |                  |
| 48  | NM  | O     |            |          | Total Adjustments              |        |                  |                  |
| 49  | NM  | O     |            |          | Total Payments                 |        |                  |                  |
| 50  | CX  | O     |            | 0203     | Alternate Visit ID             |        |                  | `LB_CAS_SEJOUR.ADM` (first token before `-`/space) |
| 51  | ID  | O     |            | 0326     | Visit Indicator                |        |                  |                  |
| 52  | CX  | X     |            |          | Service Episode ID             |        |                  |                  |

# Segment ZBE
Action on a movement

| SEQ | DT  | Usage | Repeatable | ELEMENT NAME                     | IHE FR | Remarks | Handling |
|-----|-----|-------|------------|----------------------------------|--------|---------| -------- |
| 1   | EI  | R     | Y          | Movement ID                      | *      | Unique identifier for the movement. EI-1 = ID, EI-2 = Namespace ID, EI-3 = Universal ID, EI-4 = Universal ID Type | Ignored |
| 2   | TS  | R     |            | Start of Movement Date/Time      | *      | Date/time when the movement begins | Ignored |
| 4   | ID  | R     |            | Movement Action                  | *      | See [ZBE-4](#ZBE-4-Movement-Action) | Ignored |
| 5   | ID  | R     |            | Historical Movement Indicator    | *      | `Y` = Historical, `N` = Current | Current movements are handled, Historical movements are ignored |
| 6   | ID  | C     |            | Original Trigger Event Code      | *      | Original ADT event code (e.g. `A01`, `A02`) that triggered this movement |  |
| 7   | XON | C     |            | Responsible Medical Ward         |        | Responsible unit/entity for the movement | Ignored |
| 8   | XON | C     |            | Responsible Nursing Ward         |        | Responsible unit/entity for the movement | Ignored |
| 9   | CWE | R     |            | Nature of Movement               | *      |  | Ignored |

## ZBE-4 Movement Action

| Code     | Description |
|----------|-------------|
| `INSERT` | New movement creation |
| `UPDATE` | Update of an existing movement |
| `CANCEL` | Cancel a movement |

# Segment ZFA

ZFA segment is ignored