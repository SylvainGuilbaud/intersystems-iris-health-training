import { Component, HostListener } from '@angular/core';
import { CommonModule } from '@angular/common';
import { HttpErrorResponse } from '@angular/common/http';
import { FormsModule } from '@angular/forms';
import { catchError, finalize, firstValueFrom, from, mergeMap, of, Subscription } from 'rxjs';
import { Hl7Service } from './hl7.service';
import { FhirExtension, FhirPatient, FhirPatientService } from './fhir-patient.service';
import {
  generateOruMessage, generateAdtMessage, Hl7Params,
  generateQbpMessage, generateOmlMessage, generateOulMessage, LawParams, LawTransaction,
} from './hl7-generator';

interface LogEntry {
  timestamp: string;
  text: string;
  type: 'info' | 'success' | 'error' | 'hl7';
  html?: string;
}

interface PatientEnvironment {
  label: string;
  city?: string;
  country?: string;
  latitude?: number;
  longitude?: number;
  temperature?: number;
  temperatureUnit?: string;
}

type EnvConfig = { baseUrl: string; oruCfgItem: string; adtCfgItem: string; username: string; password: string };

const CLOUD_ENV_MAP: Record<string, EnvConfig> = {
  // Cloud (served from the AWS webgateway — direct paths, no ng-serve proxy prefix)
  'dev':            { baseUrl: '/iris-health-training-dev/csp/healthshare/dglab',          oruCfgItem: 'LAB RESULT from DGLAB - HTTP', adtCfgItem: 'Patient Information from IHE PAM - HTTP', username: 'testuser', password: 'IRIS' },
  'prod':           { baseUrl: '/iris-health-training-prod/csp/healthshare/dglab',         oruCfgItem: 'LAB RESULT from DGLAB - HTTP', adtCfgItem: 'Patient Information from IHE PAM - HTTP', username: 'testuser', password: 'IRIS' },
};

const LOCAL_ENV_MAP: Record<string, EnvConfig> = {
  // Local development (ng serve with proxy — prefixes resolved by proxy.conf.json)
  'dev':              { baseUrl: '/irisaws/iris-health-training-dev/csp/healthshare/dglab',  oruCfgItem: 'LAB RESULT from DGLAB - HTTP', adtCfgItem: 'Patient Information from IHE PAM - HTTP', username: 'testuser', password: 'IRIS' },
  'prod':             { baseUrl: '/irisaws/iris-health-training-prod/csp/healthshare/dglab', oruCfgItem: 'LAB RESULT from DGLAB - HTTP', adtCfgItem: 'Patient Information from IHE PAM - HTTP', username: 'testuser', password: 'IRIS' },
  'dev-community':  { baseUrl: '/iris881/iris-health-training-dev/csp/healthshare/dglab',  oruCfgItem: 'LAB RESULT from DGLAB - HTTP', adtCfgItem: 'Patient Information from IHE PAM - HTTP', username: 'testuser', password: 'IRIS'        },
  'prod-community': { baseUrl: '/iris881/iris-health-training-prod/csp/healthshare/dglab', oruCfgItem: 'LAB RESULT from DGLAB - HTTP', adtCfgItem: 'Patient Information from IHE PAM - HTTP', username: 'testuser', password: 'IRIS'        },
  'dev-local':            { baseUrl: '/iris80/iris-health-training-dev/csp/healthshare/dglab',   oruCfgItem: 'LAB RESULT from DGLAB - HTTP', adtCfgItem: 'Patient Information from IHE PAM - HTTP', username: 'testuser', password: 'IRIS' },
  'prod-local':           { baseUrl: '/iris80/iris-health-training-prod/csp/healthshare/dglab',  oruCfgItem: 'LAB RESULT from DGLAB - HTTP', adtCfgItem: 'Patient Information from IHE PAM - HTTP', username: 'testuser', password: 'IRIS' },
};

const IS_CLOUD_DEPLOYED = typeof window !== 'undefined' && !/^(localhost|127\.0\.0\.1)$/.test(window.location.hostname);
const ENV_MAP: Record<string, EnvConfig> = IS_CLOUD_DEPLOYED ? CLOUD_ENV_MAP : LOCAL_ENV_MAP;
// Local ng serve defaults to the dev-local environment and the DGLAB namespace; the cloud deployment keeps dev / TRAINING.
const DEFAULT_ENV_KEY = IS_CLOUD_DEPLOYED
  ? (ENV_MAP['dev'] ? 'dev' : Object.keys(ENV_MAP)[0])
  : (ENV_MAP['dev-local'] ? 'dev-local' : Object.keys(ENV_MAP)[0]);
const DEFAULT_NAMESPACE = IS_CLOUD_DEPLOYED ? 'TRAINING' : 'DGLAB';
const DEFAULT_ENV_CONFIG: EnvConfig = ENV_MAP[DEFAULT_ENV_KEY] ?? {
  baseUrl: '/csp/healthshare/dglab',
  oruCfgItem: 'LAB RESULT from DGLAB - HTTP',
  adtCfgItem: 'Patient Information from IHE PAM - HTTP',
  username: 'testuser',
  password: 'IRIS',
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
  rawMessage: string;
  clearRaw: string;
  serverConfig: string;
  environment: string;
  namespace: string;
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
  fhirSearch: string;
  ipp: string;
  search: string;
  searching: string;
  patientResult: string;
  noPatient: string;
  birthPlace: string;
  home: string;
  temperature: string;
  coordinates: string;
  lawTitle: string;
  lawHint: string;
  lawContainer: string;
  lawQuery: string;
  lawBroadcast: string;
  lawStatus: string;
  lawCycle: string;
  lawRoleAutomate: string;
  lawRoleManager: string;
  lawNewContainer: string;
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
    rawMessage: 'Raw message — paste to override the form',
    clearRaw: 'Clear',
    serverConfig: 'SERVER CONFIGURATION',
    environment: 'Environment',
    namespace: 'Namespace',
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
    fhirSearch: 'FHIR PATIENT SEARCH',
    ipp: 'Patient IPP',
    search: 'Search',
    searching: 'Searching...',
    patientResult: 'FHIR Patient result',
    noPatient: 'Enter an IPP to search for a Patient.',
    birthPlace: 'Birth place',
    home: 'Home',
    temperature: 'Temperature',
    coordinates: 'Coordinates',
    lawTitle: 'IHE LAW — Laboratory Analytical Workflow',
    lawHint: 'AWOS = Analytical Work Order Step. The production plays the peer system of each transaction.',
    lawContainer: 'Container (tube) ID',
    lawQuery: 'LAB-27 Query for AWOS',
    lawBroadcast: 'LAB-28 AWOS Broadcast',
    lawStatus: 'LAB-29 Status Change',
    lawCycle: 'Run full LAW cycle',
    lawRoleAutomate: 'Automate → Analyzer Manager',
    lawRoleManager: 'Analyzer Manager → Automate',
    lawNewContainer: 'New container',
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
    rawMessage: 'Message brut — collez pour ignorer le formulaire',
    clearRaw: 'Effacer',
    serverConfig: 'CONFIGURATION DU SERVEUR',
    environment: 'Environnement',
    namespace: 'Namespace',
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
    fhirSearch: 'RECHERCHE PATIENT FHIR',
    ipp: 'IPP du patient',
    search: 'Rechercher',
    searching: 'Recherche...',
    patientResult: 'Résultat Patient FHIR',
    noPatient: 'Saisissez un IPP pour rechercher un Patient.',
    birthPlace: 'Lieu de naissance',
    home: 'Domicile',
    temperature: 'Température',
    coordinates: 'Coordonnées',
    lawTitle: 'IHE LAW — Laboratory Analytical Workflow',
    lawHint: 'AWOS = Analytical Work Order Step (étape de travail analytique). La production joue le système en face de chaque transaction.',
    lawContainer: 'Identifiant du tube',
    lawQuery: 'LAB-27 Demande des AWOS',
    lawBroadcast: 'LAB-28 Transmission des AWOS',
    lawStatus: 'LAB-29 Statuts et résultats',
    lawCycle: 'Dérouler le cycle LAW complet',
    lawRoleAutomate: 'Automate → Analyzer Manager',
    lawRoleManager: 'Analyzer Manager → Automate',
    lawNewContainer: 'Nouveau tube',
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
    rawMessage: 'Mensaje sin procesar — pegar para anular el formulario',
    clearRaw: 'Borrar',
    serverConfig: 'CONFIGURACIÓN DEL SERVIDOR',
    environment: 'Entorno',
    namespace: 'Namespace',
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
    fhirSearch: 'BÚSQUEDA DE PACIENTE FHIR',
    ipp: 'IPP del paciente',
    search: 'Buscar',
    searching: 'Buscando...',
    patientResult: 'Resultado Patient FHIR',
    noPatient: 'Introduzca un IPP para buscar un Patient.',
    birthPlace: 'Lugar de nacimiento',
    home: 'Domicilio',
    temperature: 'Temperatura',
    coordinates: 'Coordenadas',
    lawTitle: 'IHE LAW — Laboratory Analytical Workflow',
    lawHint: 'AWOS = Analytical Work Order Step (paso de trabajo analítico). La producción hace de sistema contrario en cada transacción.',
    lawContainer: 'Identificador del tubo',
    lawQuery: 'LAB-27 Consulta de AWOS',
    lawBroadcast: 'LAB-28 Difusión de AWOS',
    lawStatus: 'LAB-29 Estados y resultados',
    lawCycle: 'Ejecutar el ciclo LAW completo',
    lawRoleAutomate: 'Autómata → Analyzer Manager',
    lawRoleManager: 'Analyzer Manager → Autómata',
    lawNewContainer: 'Nuevo tubo',
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
  // Fake UI-only authentication gate
  isLoggedIn = false;
  loginUser = '';
  loginPassword = '';
  loginError = '';

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

  // Raw message override (paste any content to send as-is, independent of the form)
  rawMessage = '';

  // Server config
  environment  = DEFAULT_ENV_KEY;
  baseUrl      = DEFAULT_ENV_CONFIG.baseUrl;
  namespace    = DEFAULT_NAMESPACE;
  oruCfgItem   = DEFAULT_ENV_CONFIG.oruCfgItem;
  adtCfgItem   = DEFAULT_ENV_CONFIG.adtCfgItem;
  username     = DEFAULT_ENV_CONFIG.username;
  password     = DEFAULT_ENV_CONFIG.password;

  readonly namespaceOptions = [
    'Adrian', 'Carl-Jamie', 'Danmark', 'Delphine', 'DGLAB', 'Francois', 'Frederic',
    'Jean-Michel', 'Marck-Augustus', 'Michael', 'Neil', 'Olivier', 'Philippe',
    'QA-TESTING', 'Rochelle', 'Ronald', 'Sophie', 'STAGE', 'Sylvain', 'TRAINING', 'UAT'
  ];

  // Logs
  hl7Log:      LogEntry[] = [];
  private lastHl7Type: 'ORU' | 'ADT' | null = null;
  responseLog: LogEntry[] = [];
  private progressEntry: LogEntry | null = null;

  sending = false;

  // IHE LAW (LAB-27 / LAB-28 / LAB-29) simulation
  lawContainerId = AppComponent.newContainerId();
  lawQbpCfgItem  = 'LAW LAB-27 Query for AWOS - HTTP';
  lawOmlCfgItem  = 'LAW LAB-28 AWOS Broadcast - HTTP';
  lawOulCfgItem  = 'LAW LAB-29 AWOS Status Change - HTTP';
  lawCycleRunning = false;

  // FHIR Patient search
  fhirIpp = 'G7809';
  fhirPatient: FhirPatient | null = null;
  fhirPatientJson = '';
  fhirError = '';
  fhirLoading = false;
  fhirSearchExpanded = true;
  private fhirSearchSubscription?: Subscription;

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

  fakeLogin(): void {
    if (this.loginUser.trim() === 'testuser' && this.loginPassword === 'IRIS') {
      this.isLoggedIn = true;
      this.loginError = '';
      this.loginPassword = '';
      return;
    }
    this.loginError = 'Invalid credentials. Use testuser / IRIS.';
  }

  fakeLogout(): void {
    this.isLoggedIn = false;
    this.loginUser = '';
    this.loginPassword = '';
    this.loginError = '';
  }

  readonly envKeys = Object.keys(ENV_MAP);

  get genderOpts(): { value: string; label: string }[] {
    return [
      { value: 'M', label: this.t.genderMale },
      { value: 'F', label: this.t.genderFemale },
      { value: 'X', label: this.t.genderOther },
    ];
  }

  constructor(private hl7: Hl7Service, private fhirPatientService: FhirPatientService) {
    this.onEnvChange();
  }

  get adminPortalUrl(): string {
    const marker = '/csp/healthshare/';
    const i = this.baseUrl.indexOf(marker);
    const root = i >= 0 ? this.baseUrl.slice(0, i) : this.baseUrl.replace(/\/$/, '');
    // Local web-gateway environments (dev-local/prod-local, community): link straight to the
    // local gateway instead of the ng-serve proxy prefix.
    const local = root.match(/^\/(iris80|iris881)(\/.*)$/);
    if (local) {
      const host = local[1] === 'iris881' ? 'http://localhost:881' : 'http://localhost';
      return `${host}${local[2]}/csp/sys/%25CSP.Portal.Home.zen`;
    }
    // AWS environments (dev/prod): open the System Management Portal home (UtilHome.csp).
    const aws = root.match(/^\/irisaws(\/.*)$/);
    const awsHost = 'http://ec2-63-177-72-122.eu-central-1.compute.amazonaws.com';
    return `${aws ? awsHost + aws[1] : root}/csp/sys/UtilHome.csp`;
  }

  get fhirBaseUrl(): string {
    const marker = '/csp/healthshare/';
    const markerIndex = this.baseUrl.indexOf(marker);
    const instanceRoot = markerIndex >= 0 ? this.baseUrl.slice(0, markerIndex) : this.baseUrl.replace(/\/$/, '');
    return `${instanceRoot}/specfirst/foch`;
  }

  get fhirPatientName(): string {
    const name = this.fhirPatient?.name?.find(item => item.use === 'official') ?? this.fhirPatient?.name?.[0];
    return [...(name?.given ?? []), name?.family].filter(Boolean).join(' ');
  }

  get fhirPatientAddress(): string {
    const address = this.fhirPatient?.address?.find(item => item.use === 'home') ?? this.fhirPatient?.address?.[0];
    if (!address) return '';
    return [...(address.line ?? []), address.postalCode, address.city, address.country].filter(Boolean).join(', ');
  }

  get fhirPatientEnvironment(): PatientEnvironment[] {
    const enrichment = this.fhirPatient?.extension?.find(item => item.url?.endsWith('/patient-environment'));
    if (!enrichment) return [];

    return [
      this.readPatientEnvironment(enrichment, 'birthPlace', this.t.birthPlace),
      this.readPatientEnvironment(enrichment, 'home', this.t.home),
    ].filter((item): item is PatientEnvironment => item !== null);
  }

  private readPatientEnvironment(root: FhirExtension, role: string, label: string): PatientEnvironment | null {
    const location = root.extension?.find(item => item.url === role);
    if (!location) return null;

    const value = (url: string) => location.extension?.find(item => item.url === url);
    const temperature = value('temperature')?.valueQuantity;
    return {
      label,
      city: value('city')?.valueString,
      country: value('country')?.valueString,
      latitude: value('latitude')?.valueDecimal,
      longitude: value('longitude')?.valueDecimal,
      temperature: temperature?.value,
      temperatureUnit: temperature?.unit,
    };
  }

  searchFhirPatient(): void {
    const ipp = this.fhirIpp.trim();
    this.fhirSearchSubscription?.unsubscribe();
    this.fhirPatient = null;
    this.fhirPatientJson = '';
    this.fhirError = '';

    if (!ipp) {
      this.fhirError = this.t.noPatient;
      return;
    }

    this.fhirLoading = true;
    this.fhirSearchSubscription = this.fhirPatientService
      .findByIpp(this.fhirBaseUrl, ipp, this.username, this.password)
      .pipe(finalize(() => this.fhirLoading = false))
      .subscribe({
        next: patient => {
          this.fhirPatient = patient;
          this.fhirPatientJson = JSON.stringify(patient, null, 2);
        },
        error: (error: HttpErrorResponse) => {
          const diagnostics = error.error?.issue?.[0]?.diagnostics;
          this.fhirError = diagnostics || error.message || `HTTP ${error.status}`;
        },
      });
  }

  private extractNamespaceFromBaseUrl(url: string): string {
    const m = url.match(/\/csp\/healthshare\/([^/]+)\/?$/);
    return m?.[1] ?? 'TRAINING';
  }

  private applyNamespaceToBaseUrl(url: string, ns: string): string {
    if (!ns.trim()) return url;
    const normalizedNs = ns.trim().toLowerCase();
    const marker = '/csp/healthshare/';
    const idx = url.indexOf(marker);
    if (idx >= 0) {
      const prefix = url.slice(0, idx);
      return `${prefix}${marker}${normalizedNs}`;
    }
    return `/csp/healthshare/${normalizedNs}`;
  }

  onEnvChange(): void {
    const e = ENV_MAP[this.environment];
    if (!e) return;
    this.baseUrl         = this.applyNamespaceToBaseUrl(e.baseUrl, this.namespace);
    this.oruCfgItem      = e.oruCfgItem;
    this.adtCfgItem      = e.adtCfgItem;
    this.username        = e.username;
    this.password        = e.password;
  }

  onNamespaceChange(): void {
    this.baseUrl = this.applyNamespaceToBaseUrl(this.baseUrl, this.namespace);
  }

  private static readonly MALE_NAMES   = new Set(['Danmark','Marck-Augustus','Carl-Jamie','Francois','Neil','Adrian','Philippe','Jean-Michel','Olivier','Michael','Frederic','Ronald','Jean','Nicolas','Pierre']);
  private static readonly FEMALE_NAMES = new Set(['Delphine','Rochelle','Sophie','Anne','Marie']);

  readonly firstNameOpts = ['Anne','Delphine','Danmark','Marck-Augustus','Carl-Jamie','Francois','Rochelle','Neil','Adrian','Philippe','Jean-Michel','Olivier','Michael','Sophie','Frederic','Ronald'];

  readonly nbMessagesOpts = [1, 5, 10, 20, 50, 100, 200, 500, 1000];

  // Editable Nb messages combobox
  nbOpen = false;
  namespaceOpen = false;

  toggleNb(): void { this.nbOpen = !this.nbOpen; }

  selectNb(n: number): void {
    this.nbMessages = n;
    this.nbOpen = false;
  }

  @HostListener('document:click', ['$event'])
  onDocumentClick(event: MouseEvent): void {
    if (!(event.target as HTMLElement).closest('.combo')) {
      this.nbOpen = false;
      this.namespaceOpen = false;
    }
  }

  toggleNamespace(): void { this.namespaceOpen = !this.namespaceOpen; }

  selectNamespace(ns: string): void {
    this.namespace = ns;
    this.onNamespaceChange();
    this.namespaceOpen = false;
  }

  onFirstNameChange(): void {
    if (AppComponent.MALE_NAMES.has(this.firstName))        this.gender = 'M';
    else if (AppComponent.FEMALE_NAMES.has(this.firstName)) this.gender = 'F';
    this.refreshHl7Preview();
  }

  /** Keep the displayed HL7 message in sync with the form when the form changes (gender, last name, birthdate, sodium). */
  refreshHl7Preview(): void {
    if (!this.hl7Log.length || !this.lastHl7Type || (this.rawMessage ?? '').trim()) return;
    const params = this.params();
    const msg = this.lastHl7Type === 'ORU' ? generateOruMessage(params) : generateAdtMessage(params);
    const display = msg.replace(/\r/g, '\n')
      .replace(/(Base64\^)([A-Za-z0-9+/=]{200})[A-Za-z0-9+/=]+/g, '$1$2[...]');
    this.addHl7Log(display, AppComponent.highlightHl7(display, params));
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

    // Civility prefix (XPN-5), tied to the selected gender
    html = html.replace(
      /(\^\^\^)(MONSIEUR|MADAME)(\^\^)/g,
      (_m, a, t, b) => `${a}<mark class="hl7-patient">${t}</mark>${b}`,
    );

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

  // ── IHE LAW ─────────────────────────────────────────────────────────────
  private static newContainerId(): string {
    return 'C' + String(Math.floor(Math.random() * 1e8)).padStart(8, '0');
  }

  newLawContainer(): void {
    this.lawContainerId = AppComponent.newContainerId();
  }

  private lawParams(): LawParams {
    return {
      containerId: this.lawContainerId.trim(),
      patientId:   this.patientId,
      firstName:   this.firstName,
      lastName:    this.lastName,
      dob:         this.dobFormatted(),
      gender:      this.gender,
      sodium:      this.sodium,
    };
  }

  private lawMessage(tx: LawTransaction): { msg: string; cfgItem: string; label: string } {
    const p = this.lawParams();
    switch (tx) {
      case 'LAB-27': return { msg: generateQbpMessage(p), cfgItem: this.lawQbpCfgItem, label: 'LAB-27 QBP^Q11 → RSP^K11' };
      case 'LAB-28': return { msg: generateOmlMessage(p), cfgItem: this.lawOmlCfgItem, label: 'LAB-28 OML^O33 → ORL^O34' };
      case 'LAB-29': return { msg: generateOulMessage(p), cfgItem: this.lawOulCfgItem, label: 'LAB-29 OUL^R22 → ACK' };
    }
  }

  private static lawDisplay(msg: string): string {
    return msg.replace(/\r/g, '\n');
  }

  /** Sends one LAW transaction and logs the request and the answer. */
  sendLaw(tx: LawTransaction): void {
    if (!this.isLoggedIn) {
      this.addResponse('ERROR: Please login first with testuser / IRIS.', 'error');
      return;
    }
    if (!this.lawContainerId.trim()) {
      this.addResponse('ERROR: container ID is required.', 'error');
      return;
    }
    const { msg, cfgItem, label } = this.lawMessage(tx);
    const display = AppComponent.lawDisplay(msg);
    this.lastHl7Type = null;
    this.addHl7Log(display, AppComponent.highlightHl7(display, this.params()));
    this.addResponse(`▶ ${label} → ${this.baseUrl}?CfgItem=${cfgItem}`, 'info');

    const start = Date.now();
    this.hl7.send(this.baseUrl, cfgItem, this.username, this.password, msg).pipe(
      catchError(err => of(`ERROR: ${err.message ?? err.statusText ?? 'Unknown'}`)),
    ).subscribe(resp => {
      const isError = resp.startsWith('ERROR:');
      const elapsed = ((Date.now() - start) / 1000).toFixed(2);
      this.addResponse(`${resp.replace(/\r/g, '\n')} — ${AppComponent.fmtBytes(new Blob([msg]).size)} — ${elapsed}s`, isError ? 'error' : 'success');
    });
  }

  /**
   * Plays the whole LAW cycle of a tube: the Automate queries the work (LAB-27), the Analyzer Manager
   * broadcasts it (LAB-28), then the Automate reports statuses and results (LAB-29).
   */
  async sendLawCycle(): Promise<void> {
    if (!this.isLoggedIn) {
      this.addResponse('ERROR: Please login first with testuser / IRIS.', 'error');
      return;
    }
    if (!this.lawContainerId.trim()) {
      this.addResponse('ERROR: container ID is required.', 'error');
      return;
    }
    this.lawCycleRunning = true;
    this.lastHl7Type = null;
    const expectedAnswers: Record<LawTransaction, string> = { 'LAB-27': 'RSP^K11', 'LAB-28': 'ORL^O34', 'LAB-29': 'ACK' };
    const sent: string[] = [];
    try {
      for (const tx of ['LAB-27', 'LAB-28', 'LAB-29'] as LawTransaction[]) {
        const { msg, cfgItem, label } = this.lawMessage(tx);
        sent.push(`── ${label.split(' → ')[0]} ──\n${AppComponent.lawDisplay(msg)}`);
        const display = sent.join('\n\n');
        this.addHl7Log(display, AppComponent.highlightHl7(display, this.params()));
        this.addResponse(`▶ ${label} → ${this.baseUrl}?CfgItem=${cfgItem}`, 'info');

        const resp = await firstValueFrom(
          this.hl7.send(this.baseUrl, cfgItem, this.username, this.password, msg).pipe(
            catchError(err => of(`ERROR: ${err.message ?? err.statusText ?? 'Unknown'}`)),
          ),
        );
        const answerOk = !resp.startsWith('ERROR:') && resp.includes(expectedAnswers[tx]);
        this.addResponse(resp.replace(/\r/g, '\n'), answerOk ? 'success' : 'error');
        if (!answerOk) {
          this.addResponse(`❌ ${tx}: expected a ${expectedAnswers[tx]} answer — cycle stopped`, 'error');
          return;
        }
      }
      this.addResponse(`✅ LAW cycle done for container ${this.lawContainerId.trim()} (LAB-27 → LAB-28 → LAB-29)`, 'success');
    } finally {
      this.lawCycleRunning = false;
    }
  }

  private static readonly CONCURRENCY = 6;

  private doSend(type: 'ORU' | 'ADT', cfgItem: string): void {
    if (!this.isLoggedIn) {
      this.addResponse('ERROR: Please login first with testuser / IRIS.', 'error');
      return;
    }

    const count = Math.max(1, Math.min(Math.floor(Number(this.nbMessages)) || 1, 1000));
    const params = this.params();
    const startTime = Date.now();
    let ok = 0, fail = 0, bytesTotal = 0;

    // Pre-generate all messages (or use the pasted raw override, sent as-is)
    const override = (this.rawMessage ?? '').trim();
    const overrideMsg = override ? override.replace(/\r\n/g, '\n').replace(/\n/g, '\r') : '';
    const messages = Array.from({ length: count }, () =>
      overrideMsg ? overrideMsg : (type === 'ORU' ? generateOruMessage(params) : generateAdtMessage(params))
    );
    bytesTotal = messages.reduce((sum, m) => sum + new Blob([m]).size, 0);

    const display = messages[0].replace(/\r/g, '\n')
      .replace(/(Base64\^)([A-Za-z0-9+/=]{200})[A-Za-z0-9+/=]+/g, '$1$2[...]');
    this.lastHl7Type = overrideMsg ? null : type;
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
