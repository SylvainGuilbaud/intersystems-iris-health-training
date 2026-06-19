import { Component } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { catchError, of } from 'rxjs';
import { Hl7Service } from './hl7.service';
import { generateOruMessage, generateAdtMessage, Hl7Params } from './hl7-generator';

interface LogEntry {
  timestamp: string;
  text: string;
  type: 'info' | 'success' | 'error' | 'hl7';
}

const ENV_MAP: Record<string, { baseUrl: string; oruCfgItem: string; adtCfgItem: string; username: string; password: string }> = {
  'dev-aws':              { baseUrl: '/irisaws/iris-health-training-dev/csp/healthshare/dglab',  oruCfgItem: 'LAB RESULT from DGLAB - HTTP', adtCfgItem: 'Patient Information from IHE PAM - HTTP', username: '_system', password: 'IRIS4Good/' },
  'prod-aws':             { baseUrl: '/irisaws/iris-health-training-prod/csp/healthshare/dglab', oruCfgItem: 'LAB RESULT from DGLAB - HTTP', adtCfgItem: 'Patient Information from IHE PAM - HTTP', username: '_system', password: 'IRIS4Good/' },
  'dev-local-community':  { baseUrl: '/iris881/iris-health-training-dev/csp/healthshare/dglab',  oruCfgItem: 'LAB RESULT from DGLAB - HTTP', adtCfgItem: 'Patient Information from IHE PAM - HTTP', username: '_system', password: 'SYS'        },
  'prod-local-community': { baseUrl: '/iris881/iris-health-training-prod/csp/healthshare/dglab', oruCfgItem: 'LAB RESULT from DGLAB - HTTP', adtCfgItem: 'Patient Information from IHE PAM - HTTP', username: '_system', password: 'SYS'        },
  'dev-local':            { baseUrl: '/iris80/iris-health-training-dev/csp/healthshare/dglab',   oruCfgItem: 'LAB RESULT from DGLAB - HTTP', adtCfgItem: 'Patient Information from IHE PAM - HTTP', username: '_system', password: 'IRIS4Good/' },
  'prod-local':           { baseUrl: '/iris80/iris-health-training-prod/csp/healthshare/dglab',  oruCfgItem: 'LAB RESULT from DGLAB - HTTP', adtCfgItem: 'Patient Information from IHE PAM - HTTP', username: '_system', password: 'IRIS4Good/' },
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

  sending = false;

  readonly envKeys    = Object.keys(ENV_MAP);
  readonly genderOpts = [
    { value: 'M', label: 'Male / Homme' },
    { value: 'F', label: 'Female / Femme' },
    { value: 'X', label: 'Other / Autre' },
  ];

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

  private addHl7Log(text: string): void {
    this.hl7Log = [{ timestamp: this.now(), text, type: 'hl7' }];
  }

  private addResponse(text: string, type: LogEntry['type'] = 'info'): void {
    this.responseLog = [{ timestamp: this.now(), text, type }, ...this.responseLog].slice(0, 200);
  }

  private doSend(type: 'ORU' | 'ADT', cfgItem: string): void {
    const count = Math.max(1, Math.min(this.nbMessages, 1000));
    const params = this.params();
    const startTime = Date.now();
    let ok = 0, fail = 0;

    this.addResponse(`▶ ${type} → ${this.baseUrl}?CfgItem=${cfgItem}`, 'info');

    for (let i = 0; i < count; i++) {
      const msg = type === 'ORU' ? generateOruMessage(params) : generateAdtMessage(params);
      if (i === 0) this.addHl7Log(msg.replace(/\r/g, '\n'));

      this.hl7.send(this.baseUrl, cfgItem, this.username, this.password, msg).pipe(
        catchError(err => of(`ERROR: ${err.message ?? err.statusText ?? 'Unknown'}`)),
      ).subscribe(resp => {
        const isError = resp.startsWith('ERROR:');
        isError ? fail++ : ok++;
        const done = ok + fail;

        if (count === 1) {
          this.addResponse(resp, isError ? 'error' : 'success');
        } else if (done === count) {
          const elapsed = ((Date.now() - startTime) / 1000).toFixed(2);
          const rate    = (ok / parseFloat(elapsed)).toFixed(1);
          const prefix  = fail === 0 ? '✅' : '❌';
          const failPart = fail > 0 ? ` ${fail} failed —` : '';
          this.addResponse(
            `${prefix} ${ok}/${count} OK,${failPart} ${elapsed}s (${rate} msg/s)`,
            fail === 0 ? 'success' : 'error',
          );
        }
      });
    }
  }
}
