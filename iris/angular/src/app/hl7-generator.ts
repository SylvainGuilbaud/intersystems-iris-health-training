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

function nextAdtId(): string {
  return `MSG-${String(++messageControlId).padStart(3, '0')}`;
}

export function generateOruMessage(p: Hl7Params): string {
  const now = ts();
  const msgId = nextOruId();
  const rcvFacility = p.forwardToFile ? 'FILE' : 'KIS';

  const segments = [
    `MSH|^~\\&|DGLab|LAB|OpenMedical|${rcvFacility}|${now}||ORU^R01|${msgId}|P|2.3|||||CH|8859/1|de`,
    `PID|1||18^^^LAB^PI~${p.patientId}^^^ASIP-SANTE-INS-NIA&1.2.250.1.213.1.4.9&ISO^INS-NIA||${p.lastName}^${p.firstName}^^^MADAME^^L||${p.dob}|${p.gender}|||^^^^^^H||||F|||||||||||||||||VALI`,
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
    `PID|1||${p.patientId}^^^ETABLISSEMENT&1.2.250.1.99.1&ISO^PI~285031512345678^^^INS-NIR&1.2.250.1.213.1.4.8&ISO^INS-NIR||${p.lastName}^${p.firstName}^^^MADAME^^D~${p.lastName}^${p.firstName}^^^^^L||${p.dob}|${p.gender}|||15 RUE DE LA PAIX^^PARIS^^75001^FRA^H||||||||||||||||||||75056`,
    `PV1|1|N`,
    `ZBE|MVT-003^ETABLISSEMENT^1.2.250.1.99.1^ISO|${now}||INSERT|N|A08`,
  ];
  return segments.join('\r');
}
