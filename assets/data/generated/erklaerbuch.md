# 📓 Erklärbuch — Primärnutzung von Gesundheitsdaten im EHDS

Dieses Buch erklärt die Bachelorarbeit **schnell und anschaulich**: Worum geht es, wie hängt alles zusammen, und wie weit ist Österreich wirklich? Die Rechenzellen greifen live auf die echten Daten der Arbeit zu.

> **In einem Satz:** Österreichs ELGA erfüllt die Primärnutzungs-Anforderungen des EHDS in weiten Teilen schon heute — die verbleibende Arbeit bis 2029 ist vor allem **rechtlich** (Behörden, Benachrichtigung, Opt-In-Frage, Sekundärnutzungs-Widerspruch) und **punktuell technisch** (produktive Patientenkurzakte).

## 1. Der Countdown — wann muss was fertig sein?

```js auto
// Live-Countdown bis zur ersten großen EHDS-Stufe
const ziel = new Date('2029-03-26T00:00:00');
const heute = new Date();
const tage = Math.round((ziel - heute) / 86400000);
show(`<div style="font:600 15px/1.5 var(--font-ui);padding:10px 0">
  ⏳ Noch <b style="font-size:22px;color:var(--accent-ink)">${tage.toLocaleString('de')}</b> Tage bis zur
  <b>EHDS-Stufe 1</b> am 26. März 2029 — ab dann müssen Patientenkurzakte, e-Rezept und e-Abgabe
  grenzüberschreitend über MyHealth@EU laufen.</div>`);
```

```table
Datum | Meilenstein | Ebene | Status
2015-01 | ELGA-Rollout beginnt | 🇦🇹 AT | ✅ erledigt
2019-09 | e-Medikation flächendeckend | 🇦🇹 AT | ✅ erledigt
2025-03 | EHDS-Verordnung tritt in Kraft | 🇪🇺 EU | ✅ erledigt
2026-01 | Genereller Beginn der ELGA-Speicherpflicht | 🇦🇹 AT | ✅ erledigt
2026-02 | MyHealth@EU-Start (EU-Rezept + Kurzakte, mit CZ) | 🇦🇹 AT | ✅ erledigt
2027-03 | Behörden benennen + Durchführungsrechtsakte (EEHRxF) | 🇪🇺 EU | ⏳ offen
2028-12 | Spätester Termin der Erfüllungsfiktion | 🇦🇹 AT | ⏳ offen
2029-03 | Stufe 1: Kurzakte/e-Rezept grenzüberschreitend + Benachrichtigungsrecht | 🇪🇺 EU | ⏳ offen
2031-03 | Stufe 2: Bildgebung, Labor, Entlassungsberichte | 🇪🇺 EU | ⏳ offen
```

> **Lesehilfe:** Die österreichischen Speicherpflichten (ELGA-VO 2015) liegen durchweg **vor** den EU-Fristen — Österreich ist beim „Daten haben“ gut positioniert. Eng wird es nur, weil die **Erfüllungsfiktion** die technische Anbindung bis 31.12.2028 zulässt, also nur ~3 Monate vor Stufe 1.

## 2. Die Grundidee: zwei Welten, sauber getrennt

Der ganze EHDS steht auf einer einzigen Unterscheidung:

```table
 | Primärnutzung | Sekundärnutzung
Wozu? | Behandlung der Person selbst | Forschung, Statistik, Politik, Innovation
Wer entscheidet? | Stelle für digitale Gesundheit (DHA) | Zugangsstelle für Gesundheitsdaten (HDAB)
Infrastruktur | MyHealth@EU | HealthData@EU
Widerspruch (EU) | optional (Art 10) | verpflichtend (Art 71)
Kapitel der VO | II + III | IV
```

Diese Arbeit betrachtet **nur die Primärnutzung** — die Sekundärnutzung dient bloß der Abgrenzung. Merksatz: *Primär = für dich behandelt, Sekundär = über dich geforscht.*

## 3. Die 6 prioritären Datenkategorien — deckt ELGA sie ab?

Der Kern der Primärnutzung sind sechs Datenkategorien (Art 14 EHDS-VO). So steht ELGA dazu:

```table
EHDS-Datenkategorie | ELGA-Entsprechung | Status
Patientenkurzakte | Austrian Patient Summary (APS) | ⚠️ nur Erprobungsstandard (STU 1.0.0), nicht produktiv
Elektronische Verschreibung | e-Medikation (Verordnung) | ✅ produktiv
Elektronische Abgabe | e-Medikation (Abgabe) | ✅ produktiv
Medizinische Bildgebung | ELGA-Befund Bildgebung | ✅ Speicherpflicht seit 2025 (Rollout)
Laborergebnisse | ELGA-Laborbefund | ✅ Speicherpflicht seit 2025
Entlassungsberichte | ELGA-Entlassungsbrief | ✅ seit 2015 in Betrieb
```

```js auto
chart({
  type: 'donut', title: 'Datenkategorie-Abdeckung durch ELGA',
  labels: ['produktiv / in Betrieb', 'nur Erprobungsstandard'],
  series: [{ name: 'Kategorien', values: [5, 1] }],
  height: 220,
});
md('**5 von 6** Kategorien sind abgedeckt. Der kritische Pfad bis 2029 ist die **produktive** Austrian Patient Summary — sie liegt seit Februar 2026 erst als *Standard for Trial Use* vor.');
```

## 4. Wie ELGA technisch gebaut ist (hybrid!)

ELGA ist **kein** zentraler Datentopf und **kein** rein verteiltes System, sondern **hybrid**: zentrale Verzeichnis-/Berechtigungsdienste + dreizehn dezentrale ELGA-Bereiche, die die Befunde selbst halten. e-Medikation und e-Impfpass durchbrechen das dezentrale Modell und liegen zentral.

```figure
abb-5-1
```

Der Abruf läuft zweistufig: Der **zentrale Patientenindex** weiß, in welchen Bereichen Daten liegen; die eigentlichen Dokumente kommen per **XCA** aus den dezentralen Repositories. Das ist der Grund, warum ELGA gleichzeitig „alles auffindbar“ und „Daten bleiben beim Ersteller“ verspricht.

```table
Ebene | Komponente | Rolle
Zentral | Z-PI, GDA-Index, Berechtigungssystem, A-ARR, Portal | Finden, Erlauben, Protokollieren
Netz | e-card-System + GIN (SVC-GmbH) | Identifikation + geschlossenes Netz
Dezentral | 13 ELGA-Bereiche (Repository + Registry + L-PI) | Befunde speichern und ausliefern
Sonderfall | e-Medikation, e-Impfpass | zentral, ohne Verweise
```

## 5. Das kniffligste Detail: Opt-Out trifft Opt-In

National nimmt jede:r automatisch an ELGA teil (**Opt-Out**). Für den *grenzüberschreitenden* Austausch über MyHealth@EU verlangt Österreich aber ein zusätzliches, ausdrückliches **Opt-In**. Aus der Kombination entstehen vier Situationen:

```table
Situation | National (ELGA) | Grenzüberschreitend (MyHealth@EU)
Kein Widerspruch + Opt-In | alle Dokumente | EU-Rezept + EU-Kurzakte
Kein Widerspruch, kein Opt-In | alle Dokumente | kein Austausch
Genereller Widerspruch (+ Opt-In) | keine Dokumente | EU-Rezept ja, Kurzakte entfällt (keine Daten)
Partieller Widerspruch (+ Opt-In) | nur nicht-gesperrte Daten | nur nicht betroffene Daten
```

> **Der Streitpunkt der Arbeit:** Die EHDS-VO erlaubt den Mitgliedstaaten *optional* ein Widerspruchsrecht (Opt-Out). Österreich verlangt stattdessen ein **strengeres** Opt-In. Das stärkt die Selbstbestimmung, **begrenzt** aber die Reichweite des Austauschs — und könnte ab 2029 mit dem Anwendungsvorrang der unmittelbar geltenden Verordnung kollidieren.

## 6. Wo die echten Lücken sind (die Bilanz der Arbeit)

```js auto
const luecken = [
  ['Automatisches Benachrichtigungsrecht (Art 9)', 'technisch/formal', 3],
  ['Behörden noch nicht benannt (DHA, Marktüberwachung, HDAB)', 'institutionell', 3],
  ['Produktive Patientenkurzakte (APS)', 'technisch', 2],
  ['Opt-In vs. Anwendungsvorrang der VO', 'rechtlich', 2],
  ['Sekundärnutzungs-Widerspruch', 'rechtlich/institutionell', 2],
  ['e-Impfpass ohne Art-8-Einschränkungsrecht', 'rechtlich (Detail)', 1],
];
chart({
  type: 'barh', title: 'Offene Baustellen bis 2029 (Dringlichkeit 1–3)',
  labels: luecken.map(l => l[0]),
  series: [{ name: 'Dringlichkeit', values: luecken.map(l => l[2]) }],
  height: 260,
});
print('Auffällig: die meisten Lücken sind NICHT technischer, sondern rechtlich-institutioneller Natur. Die Infrastruktur steht — es fehlen Behörden, Rechtsgrundlagen und ein Benachrichtigungskanal.');
```

Die Benachrichtigungslücke ist dabei die „freundlichste“: Das **A-ARR protokolliert ohnehin jeden Zugriff in Echtzeit** — es fehlt nur der Ausgangskanal (E-Mail/SMS/App). Kein Neubau, sondern eine Ausbaustufe.

## 7. Die Arbeit in Zahlen (live)

```js auto
const k = data.kapitel;
chart({
  type: 'bar', title: 'Belegdichte je Kapitel (Fußnoten)',
  labels: k.map(c => 'Kap. ' + c.num),
  series: [{ name: 'Fußnoten', values: k.map(c => c.fussnoten) }],
  y: 'Fußnoten', height: 230,
});
const s = data.belegStatus;
if (s && s.gesamt) chart({
  type: 'donut', title: 'Belegstatus der ' + s.gesamt + ' Fußnoten',
  labels: ['✓ belegt', '❝ Original', '✦ vermutet', 'offen'],
  series: [{ name: 'Fußnoten', values: [s.belegt, s.original, s.vermutet, s.offen] }],
  height: 230,
});
table([['Kennzahl', 'Wert'],
  ['Kapitel', String(k.length)],
  ['Fußnoten gesamt', String(k.reduce((a, c) => a + c.fussnoten, 0))],
  ['Quellen', String(data.quellen.length)],
  ['Verbindungen', String(data.verbindungen ? data.verbindungen.gesamt : 0)]]);
```

## 8. Quellenlandschaft — worauf sich die Arbeit stützt

```js auto
const typen = {};
for (const q of data.quellen) typen[q.typ] = (typen[q.typ] || 0) + 1;
chart({
  type: 'pie', title: 'Quellen nach Typ',
  labels: Object.keys(typen),
  series: [{ name: 'Quellen', values: Object.values(typen) }],
  height: 230,
});
const top = data.quellen.slice().sort((a, b) => b.zitierstellen - a.zitierstellen).slice(0, 8);
chart({
  type: 'barh', title: 'Meistzitierte Quellen',
  labels: top.map(q => q.kurz || q.id),
  series: [{ name: 'Zitierstellen', values: top.map(q => q.zitierstellen) }],
  height: 260,
});
md('Die Mischung ist typisch für eine Rechts-Technik-Arbeit: **Primärrecht** (EHDS-VO, DSGVO, GTelG) trägt die Argumentation, **Peer-Review-Artikel** liefern die technischen Grundlagen (FHIR, IHE, Zugriffskontrolle), **amtliche Berichte** (v. a. der Rechnungshof) die Fakten zu ELGA.');
```

## 9. Der rote Faden (aus dem Fazit hergeleitet)

Die Arbeit ist eine **Konformitätsanalyse**: Sie baut in Kapitel 2–4 einen Maßstab (EU-Anforderungen, Technik, nationales Recht) und misst in Kapitel 5 die Realität daran. So kommt der Schluss zustande:

```include
6.0
```

---

*Dieses Erklärbuch ist vorab generiert und lebt mit den Daten der Arbeit. Über ✎ Bearbeiten oder ⭱ Import lässt sich eine eigene Fassung erstellen; ↺ stellt dieses eingebaute Buch wieder her.*
