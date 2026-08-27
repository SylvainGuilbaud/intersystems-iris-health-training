from __future__ import annotations

import json
import ssl
import urllib.parse
import urllib.request
from datetime import date, timedelta

import iris
from intersystems_pyprod import (
    BusinessOperation,
    BusinessProcess,
    BusinessService,
    IRISProperty,
    JsonSerialize,
    Status,
)

iris_package_name = "pyprod"

IPP_SYSTEM = "urn:oid:1.2.250.1.999.1"
INS_SYSTEM = "urn:oid:1.2.250.1.213.1.4.8"
SSN_SYSTEM = "urn:oid:1.2.250.1.213.1.4.10"
ENRICHMENT_URL = "https://github.com/SylvainGuilbaud/intersystems-iris-health-training/fhir/StructureDefinition/patient-environment"


class PatientEnrichmentRequest(JsonSerialize):
    patient_id = ""


class PatientEnrichmentResponse(JsonSerialize):
    resource = {}


class GeocodingRequest(JsonSerialize):
    city = ""


class GeocodingResponse(JsonSerialize):
    found = False
    name = ""
    country = ""
    latitude = 0.0
    longitude = 0.0


class WeatherRequest(JsonSerialize):
    latitude = 0.0
    longitude = 0.0


class WeatherResponse(JsonSerialize):
    temperature = 0.0
    unit = ""
    observed_at = ""


class PatientService(BusinessService):
    target_config_name = IRISProperty(
        default="pyprod.PatientProcess",
        settings="Basic:selector?context={Ens.ContextSearch/ProductionItems?targets=1&productionName=@productionId}",
    )

    def OnProcessInput(self, input_message):
        request = PatientEnrichmentRequest(iris_message_object=input_message)
        return self.SendRequestSync(self.target_config_name, request)


class PatientProcess(BusinessProcess):
    geocoding_operation = IRISProperty(
        default="pyprod.GeocodingOperation",
        settings="Basic:selector?context={Ens.ContextSearch/ProductionItems?targets=1&productionName=@productionId}",
    )
    weather_operation = IRISProperty(
        default="pyprod.WeatherOperation",
        settings="Basic:selector?context={Ens.ContextSearch/ProductionItems?targets=1&productionName=@productionId}",
    )

    def OnRequest(self, request):
        try:
            patient = _load_patient(request.patient_id)
            resource = _patient_to_fhir(patient)
            enrichment = {"url": ENRICHMENT_URL, "extension": []}

            for role, prefix in (("birthPlace", "birth"), ("home", "home")):
                location = self._enrich_location(patient, prefix, role)
                if location is not None:
                    enrichment["extension"].append(location)

            if enrichment["extension"]:
                resource.setdefault("extension", []).append(enrichment)
            return Status.OK(), PatientEnrichmentResponse(resource=resource)
        except Exception as exception:
            return Status.ERROR(str(exception)), PatientEnrichmentResponse()

    def _enrich_location(self, patient, prefix, role):
        city = patient.get(f"{prefix}_city") or ""
        if not city:
            return None

        status, geocoding = self.SendRequestSync(
            self.geocoding_operation,
            GeocodingRequest(city=city),
        )
        if status != 1:
            raise RuntimeError(f"Geocoding failed for {role} city '{city}'")
        if not geocoding.found:
            raise RuntimeError(f"No geographic coordinates found for {role} city '{city}'")

        status, weather = self.SendRequestSync(
            self.weather_operation,
            WeatherRequest(
                latitude=geocoding.latitude,
                longitude=geocoding.longitude,
            ),
        )
        if status != 1:
            raise RuntimeError(f"Weather lookup failed for {role} city '{city}'")

        return {
            "url": role,
            "extension": [
                {"url": "city", "valueString": geocoding.name},
                {"url": "country", "valueString": geocoding.country},
                {"url": "latitude", "valueDecimal": geocoding.latitude},
                {"url": "longitude", "valueDecimal": geocoding.longitude},
                {
                    "url": "temperature",
                    "valueQuantity": {
                        "unit": weather.unit,
                        "system": "http://unitsofmeasure.org",
                        "code": "Cel",
                        "value": weather.temperature,
                    },
                },
                {"url": "observedAt", "valueDateTime": weather.observed_at},
            ],
        }


class GeocodingOperation(BusinessOperation):
    server = IRISProperty(
        default="geocoding-api.open-meteo.com",
        settings="Basic",
    )
    timeout = IRISProperty(default=10, datatype=int, settings="Basic")
    MessageMap = {"pyprod.GeocodingRequest": "Geocode"}

    def Geocode(self, request):
        try:
            query = urllib.parse.urlencode(
                {"name": request.city, "count": 1, "language": "fr", "format": "json"}
            )
            payload = _get_json(f"https://{self.server}/v1/search?{query}", self.timeout)
            results = payload.get("results") or []
            if not results:
                return Status.OK(), GeocodingResponse()
            result = results[0]
            return Status.OK(), GeocodingResponse(
                found=True,
                name=result.get("name", ""),
                country=result.get("country", ""),
                latitude=result["latitude"],
                longitude=result["longitude"],
            )
        except Exception as exception:
            return Status.ERROR(str(exception)), GeocodingResponse()


class WeatherOperation(BusinessOperation):
    server = IRISProperty(default="api.open-meteo.com", settings="Basic")
    timeout = IRISProperty(default=10, datatype=int, settings="Basic")
    MessageMap = {"pyprod.WeatherRequest": "CurrentWeather"}

    def CurrentWeather(self, request):
        try:
            query = urllib.parse.urlencode(
                {
                    "latitude": request.latitude,
                    "longitude": request.longitude,
                    "current": "temperature_2m",
                    "timezone": "GMT",
                }
            )
            payload = _get_json(f"https://{self.server}/v1/forecast?{query}", self.timeout)
            current = payload["current"]
            units = payload["current_units"]
            return Status.OK(), WeatherResponse(
                temperature=current["temperature_2m"],
                unit=units["temperature_2m"],
                observed_at=f"{current['time']}Z",
            )
        except Exception as exception:
            return Status.ERROR(str(exception)), WeatherResponse()


def _get_json(url, timeout):
    request = urllib.request.Request(url, headers={"Accept": "application/json"})
    with urllib.request.urlopen(
        request,
        timeout=int(timeout),
        context=ssl.create_default_context(),
    ) as response:
        if response.status != 200:
            raise RuntimeError(f"External API returned HTTP {response.status}")
        return json.load(response)


def _load_patient(patient_id):
    fields = [
        "id", "ipp", "ins", "ssn", "status", "last_name", "first_name",
        "birth_name", "email", "mobile_phone", "phone", "other_phone", "sex",
        "dob", "dod", "home_street", "home_recipient", "home_geographic",
        "home_po_box", "home_city", "home_postal_code", "home_country",
        "birth_street", "birth_recipient", "birth_geographic", "birth_po_box",
        "birth_city", "birth_postal_code", "birth_country",
    ]
    sql = """
        SELECT ID, IPP, INS, SSN, status, lastName, firstName, birthName,
               email, mobilePhone, phone, otherPhone, sex, DOB, DOD,
               homeAddress_Street, homeAddress_RecipientComplement,
               homeAddress_GeographicComplement, homeAddress_LocalityPOBox,
               homeAddress_City, homeAddress_PostalCode, homeAddress_Country,
               birthPlace_Street, birthPlace_RecipientComplement,
               birthPlace_GeographicComplement, birthPlace_LocalityPOBox,
               birthPlace_City, birthPlace_PostalCode, birthPlace_Country
        FROM data.patient WHERE IPP = ?
    """
    rows = list(iris.sql.prepare(sql).execute(patient_id))
    if not rows:
        raise RuntimeError(f"data.patient '{patient_id}' not found")
    return dict(zip(fields, rows[0]))


def _patient_to_fhir(patient):
    resource = {
        "resourceType": "Patient",
        "id": _logical_id(patient["ipp"]),
        "text": {
            "status": "generated",
            "div": '<div xmlns="http://www.w3.org/1999/xhtml">Patient record</div>',
        },
        "identifier": [],
        "active": patient["status"] != "deleted",
        "name": [],
        "telecom": [],
        "gender": {1: "male", 2: "female", 3: "other"}.get(patient["sex"], "unknown"),
        "deceasedBoolean": False,
    }
    for system, value in (
        (IPP_SYSTEM, patient["ipp"]),
        (INS_SYSTEM, patient["ins"]),
        (SSN_SYSTEM, patient["ssn"]),
    ):
        if value:
            resource["identifier"].append({"system": system, "value": value})

    if patient["last_name"] or patient["first_name"]:
        official_name = {"use": "official"}
        if patient["last_name"]:
            official_name["family"] = patient["last_name"]
        if patient["first_name"]:
            official_name["given"] = [patient["first_name"]]
        resource["name"].append(official_name)
    if patient["birth_name"]:
        resource["name"].append({"use": "maiden", "family": patient["birth_name"]})

    for system, value, use in (
        ("email", patient["email"], None),
        ("phone", patient["mobile_phone"], "mobile"),
        ("phone", patient["phone"], "home"),
        ("phone", patient["other_phone"], "temp"),
    ):
        if value:
            telecom = {"system": system, "value": value}
            if use:
                telecom["use"] = use
            resource["telecom"].append(telecom)

    if patient["dob"] not in (None, ""):
        resource["birthDate"] = _iris_date(patient["dob"])
    if patient["dod"] not in (None, ""):
        resource.pop("deceasedBoolean", None)
        resource["deceasedDateTime"] = _iris_date(patient["dod"])

    home = _address_to_fhir(patient, "home", "home")
    if home:
        resource["address"] = [home]
    birth = _address_to_fhir(patient, "birth", "")
    if birth:
        resource["extension"] = [{
            "url": "http://hl7.org/fhir/StructureDefinition/patient-birthPlace",
            "valueAddress": birth,
        }]
    return resource


def _address_to_fhir(patient, prefix, use):
    address = {"use": use} if use else {}
    lines = [
        patient.get(f"{prefix}_street"),
        patient.get(f"{prefix}_recipient"),
        patient.get(f"{prefix}_geographic"),
        patient.get(f"{prefix}_po_box"),
    ]
    lines = [str(value).strip() for value in lines if value and str(value).strip()]
    if lines:
        address["line"] = lines
    for key, field in (
        ("city", f"{prefix}_city"),
        ("postalCode", f"{prefix}_postal_code"),
        ("country", f"{prefix}_country"),
    ):
        value = patient.get(field)
        if value and str(value).strip():
            address[key] = value
    return address if len(address) > bool(use) else None


def _iris_date(value):
    return (date(1840, 12, 31) + timedelta(days=int(value))).isoformat()


def _logical_id(value):
    return "".join(character if character.isalnum() or character in "-." else "-" for character in value)[:64]