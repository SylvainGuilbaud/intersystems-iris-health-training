import { Injectable } from '@angular/core';
import { HttpClient, HttpHeaders } from '@angular/common/http';
import { Observable } from 'rxjs';

export interface FhirIdentifier {
  system?: string;
  value?: string;
}

export interface FhirHumanName {
  use?: string;
  family?: string;
  given?: string[];
}

export interface FhirAddress {
  use?: string;
  line?: string[];
  city?: string;
  postalCode?: string;
  country?: string;
}

export interface FhirPatient {
  resourceType: 'Patient';
  id?: string;
  identifier?: FhirIdentifier[];
  active?: boolean;
  name?: FhirHumanName[];
  gender?: string;
  birthDate?: string;
  address?: FhirAddress[];
}

@Injectable({ providedIn: 'root' })
export class FhirPatientService {
  constructor(private http: HttpClient) {}

  findByIpp(baseUrl: string, ipp: string, username: string, password: string): Observable<FhirPatient> {
    const url = `${baseUrl}/Patient/${encodeURIComponent(ipp)}`;
    const headers = new HttpHeaders({
      Accept: 'application/fhir+json',
      Authorization: `Basic ${btoa(`${username}:${password}`)}`,
    });
    return this.http.get<FhirPatient>(url, { headers });
  }
}
