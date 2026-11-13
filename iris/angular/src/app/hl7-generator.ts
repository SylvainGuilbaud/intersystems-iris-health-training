export interface Hl7Params {
  patientId: string;
  firstName: string;
  lastName: string;
  dob: string;       // YYYYMMDD
  gender: string;    // M / F / X
  sodium: number;
  forwardToFile: boolean;
  pdfBase64?: string;  // base64-encoded PDF content
}

let messageControlId = 0;

function ts(): string {
  return new Date().toISOString().replace(/[-:T.Z]/g, '').slice(0, 14);
}

function nextOruId(): string {
  return String(++messageControlId).padStart(9, '0');
}

/** Name prefix (XPN-5) consistent with the administrative sex. */
function civility(gender: string): string {
  return gender === 'M' ? 'MONSIEUR' : gender === 'F' ? 'MADAME' : '';
}

function nextAdtId(): string {
  return `MSG-${String(++messageControlId).padStart(3, '0')}`;
}

export function generateOruMessage(p: Hl7Params): string {
  const now = ts();
  const msgId = nextOruId();
  const rcvFacility = p.forwardToFile ? 'FILE' : 'KIS';

  const segments = [
    `MSH|^~\\&|DGLab|LAB|OpenMedical|${rcvFacility}|${now}||ORU^R01|${msgId}|P|2.3|||||CH|8859/1|de`,
    `PID|1||18^^^LAB^PI~${p.patientId}^^^ASIP-SANTE-INS-NIA&1.2.250.1.213.1.4.9&ISO^INS-NIA||${p.lastName}^${p.firstName}^^^${civility(p.gender)}^^L||${p.dob}|${p.gender}|||^^^^^^H||||F|||||||||||||||||VALI`,
    `PV1|1|I|^^^||||||||||||||||0|||||||||||||||||||||||||202605280000|190001010000|||||17`,
    `ORC|SC|||6100130|IP||||20260610144322|||3|||${now}`,
    `OBR|1|||296^S-Sodium^L|||${now}|20260610141505||||||||3|||||||||F`,
    `OBX|1|TX|296^S-Sodium^L|1|${p.sodium}||||||F||`,
    `OBR|2||6100130|PDFREPORT^LABORATORY REPORT^L|||${now}|||||||||||||||20260610144322|||P`,
    p.pdfBase64
      ? `OBX|1|ED|PDFREPORT^LABORATORY REPORT^L|1|DGLab^AP^PDF^Base64^${p.pdfBase64}|||N|||F|||||||DOC`
      : `OBX|1|RP|PDFREPORT^LABORATORY REPORT^L|1|file:////data/pdf/Report_131724791_3_6100130_001_110.pdf^DGLab^AP^PDF|||N|||P|||||||DOC`,
  ];
  return segments.join('\r');
}

export function generateAdtMessage(p: Hl7Params): string {
  const now = ts();
  const msgId = nextAdtId();
  const rcvFacility = p.forwardToFile ? 'FILE' : 'LAB';

  const segments = [
    `MSH|^~\\&|EMETTEUR|ETABLISSEMENT|DATAMED|${rcvFacility}|${now}||ADT^A08^ADT_A08|${msgId}|P|2.5|||NE|AL|FRA|8859/1`,
    `EVN|A08|${now}`,
    `PID|1||${p.patientId}^^^ETABLISSEMENT&1.2.250.1.99.1&ISO^PI~285031512345678^^^INS-NIR&1.2.250.1.213.1.4.8&ISO^INS-NIR||${p.lastName}^${p.firstName}^^^${civility(p.gender)}^^D~${p.lastName}^${p.firstName}^^^^^L||${p.dob}|${p.gender}|||15 RUE DE LA PAIX^^PARIS^^75001^FRA^H||||||||||||||||||||75056`,
    `PV1|1|N`,
    `ZBE|MVT-003^ETABLISSEMENT^1.2.250.1.99.1^ISO|${now}||INSERT|N|A08`,
  ];
  return segments.join('\r');
}

// ── IHE LAW (Laboratory Analytical Workflow) — HL7 v2.5.1 ─────────────────
// LAB-27 Query for AWOS        QBP^Q11  Automate -> Analyzer Manager   (answer RSP^K11)
// LAB-28 AWOS Broadcast        OML^O33  Analyzer Manager -> Automate   (answer ORL^O34)
// LAB-29 AWOS Status Change    OUL^R22  Automate -> Analyzer Manager   (answer ACK)
// AWOS = Analytical Work Order Step.

export type LawTransaction = 'LAB-27' | 'LAB-28' | 'LAB-29';

export interface LawTest {
  code: string;   // e.g. 296
  text: string;   // e.g. S-Sodium
  unit: string;
}

/** Tests simulated by the Analyzer Manager (same defaults as DGLAB.law.Messages). */
export const LAW_TESTS: LawTest[] = [
  { code: '296', text: 'S-Sodium',    unit: 'mmol/L' },
  { code: '297', text: 'S-Potassium', unit: 'mmol/L' },
  { code: '298', text: 'S-Chloride',  unit: 'mmol/L' },
];

export interface LawParams {
  containerId: string;
  patientId: string;
  firstName: string;
  lastName: string;
  dob: string;       // YYYYMMDD
  gender: string;    // M / F / X
  sodium: number;
}

let lawControlId = 0;

function lawId(prefix: string): string {
  return `${prefix}${String(++lawControlId).padStart(8, '0')}`;
}

function lawMsh(type: string, ctrlId: string, tx: LawTransaction, sendApp: string, recvApp: string): string {
  return `MSH|^~\\&|${sendApp}|LAB|${recvApp}|LAB|${ts()}||${type}|${ctrlId}|P|2.5.1|||NE|AL||UNICODE UTF-8|||${tx}^IHE`;
}

function lawPid(p: LawParams): string {
  return `PID|1||${p.patientId}^^^LAB^PI||${p.lastName}^${p.firstName}||${p.dob}|${p.gender}`;
}

function lawOrderNumber(p: LawParams, rank: number): string {
  return `${p.containerId}-${rank}`;
}

/** Plausible deterministic value of a test (the sodium follows the form value). */
function lawValue(p: LawParams, rank: number): string {
  if (rank === 1) return String(p.sodium);
  const seed = [...p.containerId].reduce((a, c) => a + c.charCodeAt(0), 0);
  return rank === 2 ? (3.5 + (seed % 15) / 10).toFixed(1) : String(98 + (seed % 10));
}

/** LAB-27 — QBP^Q11 Query for AWOS: the analyzer asks for the work of a container (tube). */
export function generateQbpMessage(p: LawParams): string {
  return [
    lawMsh('QBP^Q11^QBP_Q11', lawId('QBP'), 'LAB-27', 'ANALYZER', 'LIS'),
    `QPD|WOS^Work Order Step^IHE_LABTF|Q${ts()}|${p.containerId}`,
    'RCP|I||R',
  ].join('\r');
}

/** LAB-28 — OML^O33 AWOS Broadcast: the Analyzer Manager transmits the work orders of a container.
 *  In the HL7 2.5.1 OML_O33 definition an SPM group carries one order (ORC/TQ1/OBR), so the specimen and its
 *  container are repeated for each test of the container. */
export function generateOmlMessage(p: LawParams): string {
  const now = ts();
  const segments = [
    lawMsh('OML^O33^OML_O33', lawId('OML'), 'LAB-28', 'LIS', 'ANALYZER'),
    lawPid(p),
  ];
  LAW_TESTS.forEach((t, i) => {
    const order = lawOrderNumber(p, i + 1);
    segments.push(
      `SPM|${i + 1}|SP${p.containerId}^LIS||BLD^Blood^HL70487|||||||P^Patient^HL70369|||||||${now}`,
      `SAC|||${p.containerId}`,
      `ORC|NW|${order}^LIS|${order}^LIS`,
      'TQ1|1||||||||R',
      `OBR|${i + 1}|${order}^LIS|${order}^LIS|${t.code}^${t.text}^L|||${now}`,
    );
  });
  return segments.join('\r');
}

/** LAB-29 — OUL^R22 AWOS Status Change: the analyzer reports the status and results of the work orders. */
export function generateOulMessage(p: LawParams): string {
  const now = ts();
  const segments = [
    lawMsh('OUL^R22^OUL_R22', lawId('OUL'), 'LAB-29', 'ANALYZER', 'LIS'),
    lawPid(p),
    `SPM|1|SP${p.containerId}^LIS||BLD^Blood^HL70487|||||||P^Patient^HL70369|||||||${now}`,
    `SAC|||${p.containerId}`,
  ];
  LAW_TESTS.forEach((t, i) => {
    const order = lawOrderNumber(p, i + 1);
    // In the HL7 2.5.1 OUL_R22 definition the ORC follows its OBR
    segments.push(
      `OBR|${i + 1}|${order}^LIS|${order}^LIS|${t.code}^${t.text}^L|||${now}${'|'.repeat(18)}F`,
      `ORC|SC|${order}^LIS|${order}^LIS||CM`,
      `OBX|1|NM|${t.code}^${t.text}^L||${lawValue(p, i + 1)}|${t.unit}^${t.unit}^UCUM||N|||F|||${now}`,
    );
  });
  return segments.join('\r');
}
