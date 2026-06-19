import { Injectable } from '@angular/core';
import { HttpClient, HttpHeaders } from '@angular/common/http';
import { Observable } from 'rxjs';

@Injectable({ providedIn: 'root' })
export class Hl7Service {
  constructor(private http: HttpClient) {}

  send(baseUrl: string, cfgItem: string, username: string, password: string, message: string): Observable<string> {
    const url = `${baseUrl}/EnsLib.HL7.Service.HTTPService.cls?CfgItem=${encodeURIComponent(cfgItem)}`;
    const auth = btoa(`${username}:${password}`);
    const headers = new HttpHeaders({
      'Content-Type': 'text/plain',
      'Authorization': `Basic ${auth}`,
    });
    return this.http.post(url, message, { headers, responseType: 'text' });
  }
}

