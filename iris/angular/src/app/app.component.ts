import { Component } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { catchError, from, mergeMap, of } from 'rxjs';
import { Hl7Service } from './hl7.service';
import { generateOruMessage, generateAdtMessage, Hl7Params } from './hl7-generator';

interface LogEntry {
  timestamp: string;
  text: string;
  type: 'info' | 'success' | 'error' | 'hl7';
  html?: string;
}

const ENV_MAP: Record<string, { baseUrl: string; oruCfgItem: string; adtCfgItem: string; username: string; password: string }> = {
  'dev-aws':              { baseUrl: '/irisaws/iris-health-training-dev/csp/healthshare/dglab',  oruCfgItem: 'LAB RESULT from DGLAB - HTTP', adtCfgItem: 'Patient Information from IHE PAM - HTTP', username: '_system', password: 'IRIS4Good/' },
  'prod-aws':             { baseUrl: '/irisaws/iris-health-training-prod/csp/healthshare/dglab', oruCfgItem: 'LAB RESULT from DGLAB - HTTP', adtCfgItem: 'Patient Information from IHE PAM - HTTP', username: '_system', password: 'IRIS4Good/' },
  'dev-local-community':  { baseUrl: '/iris881/iris-health-training-dev/csp/healthshare/dglab',  oruCfgItem: 'LAB RESULT from DGLAB - HTTP', adtCfgItem: 'Patient Information from IHE PAM - HTTP', username: '_system', password: 'SYS'        },
  'prod-local-community': { baseUrl: '/iris881/iris-health-training-prod/csp/healthshare/dglab', oruCfgItem: 'LAB RESULT from DGLAB - HTTP', adtCfgItem: 'Patient Information from IHE PAM - HTTP', username: '_system', password: 'SYS'        },
  'dev-local':            { baseUrl: '/iris80/iris-health-training-dev/csp/healthshare/dglab',   oruCfgItem: 'LAB RESULT from DGLAB - HTTP', adtCfgItem: 'Patient Information from IHE PAM - HTTP', username: '_system', password: 'IRIS4Good/' },
  'prod-local':           { baseUrl: '/iris80/iris-health-training-prod/csp/healthshare/dglab',  oruCfgItem: 'LAB RESULT from DGLAB - HTTP', adtCfgItem: 'Patient Information from IHE PAM - HTTP', username: '_system', password: 'IRIS4Good/' },
};

type Lang = 'en' | 'fr' | 'es';

interface Translation {
  headerTitle: string;
  patientId: string;
  firstName: string;
  lastName: string;
  dob: string;
  gender: string;
  sodium: string;
  genderMale: string;
  genderFemale: string;
  genderOther: string;
  randomize: string;
  options: string;
  includePdf: string;
  pdfFile: string;
  noFile: string;
  forwardToFile: string;
  nbMessages: string;
  receiveAdt: string;
  sendOru: string;
  serverConfig: string;
  environment: string;
  baseUrl: string;
  adtCfg: string;
  oruCfg: string;
  username: string;
  password: string;
  hl7Generated: string;
  responses: string;
  sending: string;
  failed: string;
  total: string;
}

const TRANSLATIONS: Record<Lang, Translation> = {
  en: {
    headerTitle: 'HL7 HTTP TEST TOOL',
    patientId: 'Patient ID',
    firstName: 'First Name',
    lastName: 'Last Name',
    dob: 'Date of Birth',
    gender: 'Gender',
    sodium: 'Sodium (mmol/L)',
    genderMale: 'Male',
    genderFemale: 'Female',
    genderOther: 'Other',
    randomize: 'Randomize',
    options: 'OPTIONS',
    includePdf: 'Include PDF',
    pdfFile: 'PDF file',
    noFile: '(no file selected)',
    forwardToFile: 'Forward to file repository',
    nbMessages: 'Nb messages',
    receiveAdt: 'Receive ADT HTTP',
    sendOru: 'Send ORU HTTP',
    serverConfig: 'SERVER CONFIGURATION',
    environment: 'Environment',
    baseUrl: 'Base URL',
    adtCfg: 'ADT Cfg',
    oruCfg: 'ORU Cfg',
    username: 'Username',
    password: 'Password',
    hl7Generated: 'HL7 message generated',
    responses: 'Responses',
    sending: 'Sending',
    failed: 'failed',
    total: 'total',
  },
  fr: {
    headerTitle: 'OUTIL DE TEST HL7 HTTP',
    patientId: 'Identifiant du patient',
    firstName: 'Prénom',
    lastName: 'Nom',
    dob: 'Date de naissance',
    gender: 'Sexe',
    sodium: 'Sodium (mmol/L)',
    genderMale: 'Homme',
    genderFemale: 'Femme',
    genderOther: 'Autre',
    randomize: 'Aléatoire',
    options: 'OPTIONS',
    includePdf: 'Inclure un PDF',
    pdfFile: 'Fichier PDF',
    noFile: '(aucun fichier sélectionné)',
    forwardToFile: 'Transférer vers le répertoire de fichiers',
    nbMessages: 'Nb messages',
    receiveAdt: 'Recevoir ADT HTTP',
    sendOru: 'Envoyer ORU HTTP',
    serverConfig: 'CONFIGURATION DU SERVEUR',
    environment: 'Environnement',
    baseUrl: 'URL de base',
    adtCfg: 'Cfg ADT',
    oruCfg: 'Cfg ORU',
    username: 'Utilisateur',
    password: 'Mot de passe',
    hl7Generated: 'Message HL7 généré',
    responses: 'Réponses',
    sending: 'Envoi',
    failed: 'échoué(s)',
    total: 'au total',
  },
  es: {
    headerTitle: 'HERRAMIENTA DE PRUEBA HL7 HTTP',
    patientId: 'Identificador del paciente',
    firstName: 'Nombre',
    lastName: 'Apellido',
    dob: 'Fecha de nacimiento',
    gender: 'Género',
    sodium: 'Sodio (mmol/L)',
    genderMale: 'Hombre',
    genderFemale: 'Mujer',
    genderOther: 'Otro',
    randomize: 'Aleatorio',
    options: 'OPCIONES',
    includePdf: 'Incluir PDF',
    pdfFile: 'Archivo PDF',
    noFile: '(ningún archivo seleccionado)',
    forwardToFile: 'Reenviar al repositorio de archivos',
    nbMessages: 'Nº mensajes',
    receiveAdt: 'Recibir ADT HTTP',
    sendOru: 'Enviar ORU HTTP',
    serverConfig: 'CONFIGURACIÓN DEL SERVIDOR',
    environment: 'Entorno',
    baseUrl: 'URL base',
    adtCfg: 'Cfg ADT',
    oruCfg: 'Cfg ORU',
    username: 'Usuario',
    password: 'Contraseña',
    hl7Generated: 'Mensaje HL7 generado',
    responses: 'Respuestas',
    sending: 'Enviando',
    failed: 'fallido(s)',
    total: 'en total',
  },
};


@Component({
  selector: 'app-root',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './app.component.html',
  styleUrl: './app.component.scss'
})
export class AppComponent {
  // Patient fields
  patientId  = '24445670';
  firstName  = 'Anne';
  lastName   = 'VERSAIRE';
  dob        = '1985-01-24';
  gender     = 'F';
  sodium     = 140;

  // Options
  includePdf      = false;
  forwardToFile   = false;
  nbMessages      = 1;
  pdfBase64:  string | null = null;
  pdfFileName = '';

  // Server config
  environment  = 'dev-aws';
  baseUrl      = ENV_MAP['dev-aws'].baseUrl;
  oruCfgItem   = ENV_MAP['dev-aws'].oruCfgItem;
  adtCfgItem   = ENV_MAP['dev-aws'].adtCfgItem;
  username     = ENV_MAP['dev-aws'].username;
  password     = ENV_MAP['dev-aws'].password;

  // Logs
  hl7Log:      LogEntry[] = [];
  responseLog: LogEntry[] = [];
  private progressEntry: LogEntry | null = null;

  sending = false;

  // i18n — runtime language switch (EN / FR / ES)
  lang: Lang = 'en';
  readonly langFlags: Record<Lang, string> = { en: '🇬🇧', fr: '🇫🇷', es: '🇪🇸' };

  get t(): Translation {
    return TRANSLATIONS[this.lang];
  }

  cycleLang(): void {
    const order: Lang[] = ['en', 'fr', 'es'];
    this.lang = order[(order.indexOf(this.lang) + 1) % order.length];
  }

  readonly envKeys = Object.keys(ENV_MAP);

  get genderOpts(): { value: string; label: string }[] {
    return [
      { value: 'M', label: this.t.genderMale },
      { value: 'F', label: this.t.genderFemale },
      { value: 'X', label: this.t.genderOther },
    ];
  }

  constructor(private hl7: Hl7Service) {}

  onEnvChange(): void {
    const e = ENV_MAP[this.environment];
    if (!e) return;
    this.baseUrl         = e.baseUrl;
    this.oruCfgItem      = e.oruCfgItem;
    this.adtCfgItem      = e.adtCfgItem;
    this.username        = e.username;
    this.password        = e.password;
  }

  private static readonly MALE_NAMES   = new Set(['Danmark','Marck-Augustus','Carl-Jamie','Francois','Neil','Adrian','Philippe','Jean-Michel','Olivier','Michael','Frederic','Ronald','Jean','Nicolas','Pierre']);
  private static readonly FEMALE_NAMES = new Set(['Delphine','Rochelle','Sophie','Anne','Marie']);

  readonly firstNameOpts = ['Anne','Delphine','Danmark','Marck-Augustus','Carl-Jamie','Francois','Rochelle','Neil','Adrian','Philippe','Jean-Michel','Olivier','Michael','Sophie','Frederic','Ronald'];

  readonly nbMessagesOpts = [1, 5, 10, 20, 50, 100, 200, 500, 1000];

  onFirstNameChange(): void {
    if (AppComponent.MALE_NAMES.has(this.firstName))        this.gender = 'M';
    else if (AppComponent.FEMALE_NAMES.has(this.firstName)) this.gender = 'F';
  }

  randomize(): void {
    const fnames = this.firstNameOpts;
    const lnames = ['DUPONT', 'MARTIN', 'BERNARD', 'THOMAS', 'PETIT', 'NOVIANT', 'GARDET', 'CRUZ'];
    this.patientId = Math.random().toString().slice(2, 10);
    this.firstName = fnames[Math.floor(Math.random() * fnames.length)];
    this.lastName  = lnames[Math.floor(Math.random() * lnames.length)];
    this.sodium    = 135 + Math.floor(Math.random() * 11);
    const y = 1950 + Math.floor(Math.random() * 55);
    const m = String(1 + Math.floor(Math.random() * 12)).padStart(2, '0');
    const d = String(1 + Math.floor(Math.random() * 28)).padStart(2, '0');
    this.dob = `${y}-${m}-${d}`;
    this.onFirstNameChange();
  }

  sendOru(): void { this.doSend('ORU', this.oruCfgItem); }
  sendAdt(): void { this.doSend('ADT', this.adtCfgItem); }

  private dobFormatted(): string {
    return this.dob.replace(/-/g, '');
  }

  onPdfFileSelected(event: Event): void {
    const file = (event.target as HTMLInputElement).files?.[0];
    if (!file) return;
    this.pdfFileName = file.name;
    const reader = new FileReader();
    reader.onload = () => {
      const result = reader.result as string;
      // result is "data:application/pdf;base64,<b64>"
      this.pdfBase64 = result.split(',')[1] ?? null;
    };
    reader.readAsDataURL(file);
  }

  private params(): Hl7Params {
    return {
      patientId:     this.patientId,
      firstName:     this.firstName,
      lastName:      this.lastName,
      dob:           this.dobFormatted(),
      gender:        this.gender,
      sodium:        this.sodium,
      forwardToFile: this.forwardToFile,
      pdfBase64:     this.includePdf && this.pdfBase64 ? this.pdfBase64 : undefined,
    };
  }

  private now(): string {
    return new Date().toISOString().replace('T', ' ').slice(0, 23);
  }

  private addHl7Log(text: string, html?: string): void {
    this.hl7Log = [{ timestamp: this.now(), text, type: 'hl7', html }];
  }

  private static escapeHtml(s: string): string {
    return s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
  }

  private static escapeRegExp(s: string): string {
    return s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  }

  /** Wrap patient demographics and the sodium test value in highlight markers. */
  private static highlightHl7(text: string, p: Hl7Params): string {
    let html = AppComponent.escapeHtml(text);

    const mark = (val: string, cls: string) => {
      if (!val) return;
      const esc = AppComponent.escapeRegExp(AppComponent.escapeHtml(val));
      html = html.replace(new RegExp(esc, 'g'), m => `<mark class="${cls}">${m}</mark>`);
    };

    // Patient demographics (name + id)
    mark(p.lastName, 'hl7-patient');
    mark(p.firstName, 'hl7-patient');
    mark(p.patientId, 'hl7-patient');

    // DOB + gender, highlighted only in their PID position |YYYYMMDD|G|
    html = html.replace(
      new RegExp(`(\\|)(${AppComponent.escapeRegExp(p.dob)})(\\|)([MFX])(\\|)`, 'g'),
      (_m, a, dob, b, g, c) =>
        `${a}<mark class="hl7-patient">${dob}</mark>${b}<mark class="hl7-patient">${g}</mark>${c}`,
    );

    // Sodium test value (S-Sodium OBX segment)
    html = html.replace(
      /(S-Sodium\^L\|1\|)(\d+)/,
      (_m, pre, val) => `${pre}<mark class="hl7-value">${val}</mark>`,
    );

    return html;
  }

  private addResponse(text: string, type: LogEntry['type'] = 'info'): void {
    this.responseLog = [{ timestamp: this.now(), text, type }, ...this.responseLog].slice(0, 200);
  }

  private setProgress(text: string): void {
    if (this.progressEntry) {
      this.progressEntry.text = text;
      this.responseLog = [...this.responseLog];
    } else {
      this.progressEntry = { timestamp: this.now(), text, type: 'info' };
      this.responseLog = [this.progressEntry, ...this.responseLog].slice(0, 200);
    }
  }

  private clearProgress(): void {
    if (this.progressEntry) {
      this.responseLog = this.responseLog.filter(e => e !== this.progressEntry);
      this.progressEntry = null;
    }
  }

  private static fmtBytes(n: number): string {
    const units = ['bytes', 'KB', 'MB', 'GB'];
    let v = n;
    for (const u of units) {
      if (v < 1024) return `${v.toFixed(1)} ${u}`;
      v /= 1024;
    }
    return `${v.toFixed(1)} TB`;
  }

  private static readonly CONCURRENCY = 6;

  private doSend(type: 'ORU' | 'ADT', cfgItem: string): void {
    const count = Math.max(1, Math.min(Math.floor(Number(this.nbMessages)) || 1, 1000));
    const params = this.params();
    const startTime = Date.now();
    let ok = 0, fail = 0, bytesTotal = 0;

    // Pre-generate all messages
    const messages = Array.from({ length: count }, () =>
      type === 'ORU' ? generateOruMessage(params) : generateAdtMessage(params)
    );
    bytesTotal = messages.reduce((sum, m) => sum + new Blob([m]).size, 0);

    const display = messages[0].replace(/\r/g, '\n')
      .replace(/(Base64\^)([A-Za-z0-9+/=]{200})[A-Za-z0-9+/=]+/g, '$1$2[...]');
    this.addHl7Log(display, AppComponent.highlightHl7(display, params));

    this.addResponse(`▶ ${type} → ${this.baseUrl}?CfgItem=${cfgItem}`, 'info');
    if (count > 1) {
      this.setProgress(`⏳ ${this.t.sending} 0 / ${count}...`);
    }

    from(messages).pipe(
      mergeMap(
        msg => this.hl7.send(this.baseUrl, cfgItem, this.username, this.password, msg).pipe(
          catchError(err => of(`ERROR: ${err.message ?? err.statusText ?? 'Unknown'}`)),
        ),
        AppComponent.CONCURRENCY,
      ),
    ).subscribe({
      next: resp => {
        const isError = resp.startsWith('ERROR:');
        isError ? fail++ : ok++;
        const done = ok + fail;

        if (count === 1) {
          const elapsed = ((Date.now() - startTime) / 1000).toFixed(2);
          const suffix = ` — ${AppComponent.fmtBytes(bytesTotal)} — ${elapsed}s`;
          this.addResponse(resp + suffix, isError ? 'error' : 'success');
        } else {
          this.setProgress(`⏳ ${this.t.sending} ${done} / ${count}${fail > 0 ? ' (' + fail + ' ' + this.t.failed + ')' : ''}...`);
        }
      },
      complete: () => {
        if (count > 1) {
          const elapsed = ((Date.now() - startTime) / 1000).toFixed(2);
          const rate    = (ok / parseFloat(elapsed)).toFixed(1);
          const prefix  = fail === 0 ? '✅' : '❌';
          const failPart = fail > 0 ? ` ${fail} ${this.t.failed} —` : '';
          this.clearProgress();
          this.addResponse(
            `${prefix} ${ok}/${count} OK,${failPart} ${elapsed}s (${rate} msg/s) — ${AppComponent.fmtBytes(bytesTotal)} ${this.t.total}`,
            fail === 0 ? 'success' : 'error',
          );
        }
      },
    });
  }
}
