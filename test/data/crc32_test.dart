/// CRC32/srcHash-Bitkompatibilität (Master §7 Risiko 8).
///
/// Die Fixtures wurden mit Node aus dem ORIGINAL-Algorithmus erzeugt
/// (ZipUtil.crc32 aus js/ziputil.js + U.srcHash-Normalisierung aus
/// js/util.js:258-265), angewandt auf echte Quellen aus
/// assets/data/bundles/sources.json plus konstruierte Randfälle
/// (Umlaute, ß, ł, fehlende Felder). Weicht Dart hier auch nur ein Bit ab,
/// brechen bestehende Datei-Aufträge/ZIP-Rückläufe der Web-App.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:thesor/core/util/crc32.dart';

/// (input, crc) — rohe CRC-32-Vektoren über UTF-8-Bytes.
const _crcVectors = <(String, int)>[
  ('', 0),
  ('a', 3904355907),
  ('abc', 891568578),
  ('hello world', 222957957),
  ('Thesis Studio 2026', 2389724879),
  ('äöü', 607276175),
];

/// (id, title, longTitle, author, year, erwarteter Basis-String, Hash).
const _hashVectors = <(String, String?, String?, String?, int?, String, String)>[
  (
    'aljarullah2013',
    'A Novel System Architecture for the National Integration of Electronic Health Records: A Semi-Centralized Approach',
    null,
    'AlJarullah, Asma u.a.',
    2013,
    'anovelsystemarchitectureforthenationalintegrationofelectronichealthrecordsasemicentralizedapproach|aljarullahasmaua|2013',
    'ts-b5b9aca8',
  ),
  (
    'ayaz2021',
    'The Fast Health Interoperability Resources (FHIR) Standard: Systematic Literature Review of Implementations, Applications, Challenges and Opportunities',
    null,
    'Ayaz, Muhammad u.a.',
    2021,
    'thefasthealthinteroperabilityresourcesfhirstandardsystematicliteraturereviewofimplementationsapplicationschallengesandopportunities|ayazmuhammadua|2021',
    'ts-c58da7b3',
  ),
  (
    'atlam2025',
    'Enhancing Healthcare Security: A Unified RBAC and ABAC Risk-Aware Access Control Approach',
    null,
    'Atlam, Hany F. u.a.',
    2025,
    'enhancinghealthcaresecurityaunifiedrbacandabacriskawareaccesscontrolapproach|atlamhanyfua|2025',
    'ts-e38e9e2b',
  ),
  (
    'beinke2019',
    'Towards a Stakeholder-Oriented Blockchain-Based Architecture for Electronic Health Records: Design Science Research Study',
    null,
    'Beinke, Jan Heinrich u.a.',
    2019,
    'towardsastakeholderorientedblockchainbasedarchitectureforelectronichealthrecordsdesignscienceresearchstudy|beinkejanheinrichua|2019',
    'ts-52c3a8b7',
  ),
  (
    'bruthans2023',
    'The Current State and Usage of European Electronic Cross-border Health Services (eHDSI)',
    null,
    'Bruthans, Jan u.a.',
    2023,
    'thecurrentstateandusageofeuropeanelectroniccrossborderhealthservicesehdsi|bruthansjanua|2023',
    'ts-49fe39c0',
  ),
  (
    'bossenko2024',
    'Interoperability of health data using FHIR Mapping Language: transforming HL7 CDA to FHIR with reusable visual components',
    null,
    'Bossenko, Igor u.a.',
    2024,
    'interoperabilityofhealthdatausingfhirmappinglanguagetransforminghl7cdatofhirwithreusablevisualcomponents|bossenkoigorua|2024',
    'ts-3e9632a9',
  ),
  (
    'cobrado2024',
    'Access control solutions in electronic health record systems: A systematic review',
    null,
    'Cobrado, Usha Nicole u.a.',
    2024,
    'accesscontrolsolutionsinelectronichealthrecordsystemsasystematicreview|cobradoushanicoleua|2024',
    'ts-f12e5002',
  ),
  // Diakritika in Autor/Titel (NFD-Strip: ö→o, é→e, á→a):
  (
    'froehlich2025',
    'Reality Check: The Aspirations of the European Health Data Space Amidst Challenges in Decentralized Data Analysis',
    null,
    'Fröhlich, Holger u.a.',
    2025,
    'realitychecktheaspirationsoftheeuropeanhealthdataspaceamidstchallengesindecentralizeddataanalysis|frohlichholgerua|2025',
    'ts-ced3c7c9',
  ),
  (
    'fernandez2013',
    'Security and privacy in electronic health records: A systematic literature review',
    null,
    'Fernández-Alemán, José Luis u.a.',
    2013,
    'securityandprivacyinelectronichealthrecordsasystematicliteraturereview|fernandezalemanjoseluisua|2013',
    'ts-d00882c5',
  ),
  (
    'pedrera2023',
    'Can OpenEHR, ISO 13606, and HL7 FHIR Work Together? An Agnostic Approach for the Selection and Application of Electronic Health Record Standards to the Next-Generation Health Data Spaces',
    null,
    'Pedrera-Jiménez, Miguel u.a.',
    2023,
    'canopenehriso13606andhl7fhirworktogetheranagnosticapproachfortheselectionandapplicationofelectronichealthrecordstandardstothenextgenerationhealthdataspaces|pedrerajimenezmiguelua|2023',
    'ts-1ccef7e1',
  ),
  (
    'stasis2018',
    'eIDAS — Electronic Identification for Cross Border eHealth',
    null,
    'Stasis, Antonios Ch. u.a.',
    2018,
    'eidaselectronicidentificationforcrossborderehealth|stasisantonioschua|2018',
    'ts-8f6a2fe6',
  ),
  (
    'jormanainen2023',
    'Implementation, Adoption and Use of the Kanta Services in Finland 2010–2022',
    null,
    'Jormanainen, Vesa u.a.',
    2023,
    'implementationadoptionanduseofthekantaservicesinfinland20102022|jormanainenvesaua|2023',
    'ts-fe971384',
  ),
  // Randfälle: ganz ohne Felder → norm(id); nur Jahr; Umlaute/ł; ß fällt weg.
  ('x-ohne-felder', null, null, null, null, 'xohnefelder', 'ts-e30e1f1f'),
  ('x-nur-jahr', null, null, null, 2020, '2020', 'ts-94a46e7b'),
  (
    'x-umlaut',
    'Größenordnung — Über die Häufigkeit',
    null,
    'Müller, J.; Śẅietłana K.',
    1999,
    'groenordnunguberdiehaufigkeit|mullerjswietanak|1999',
    'ts-459ffcf5',
  ),
  ('x-ss', 'Straße & Maß', null, 'Weiß', 2001, 'straema|wei|2001', 'ts-d141530e'),
];

void main() {
  group('Crc32', () {
    test('rohe Vektoren (Polynom 0xedb88320)', () {
      for (final (input, expected) in _crcVectors) {
        expect(Crc32.ofString(input), expected, reason: 'CRC32("$input")');
      }
    });

    test('hex8 padded', () {
      expect(Crc32.hex8(0), '00000000');
      expect(Crc32.hex8(0xdeadbeef), 'deadbeef');
    });
  });

  group('srcHash', () {
    test('Basis-String exakt wie util.js norm/join', () {
      for (final (id, title, longTitle, author, year, basis, _) in _hashVectors) {
        expect(
          srcHashBasis(id: id, title: title, longTitle: longTitle, author: author, year: year),
          basis,
          reason: 'Basis für $id',
        );
      }
    });

    test('ts-Hashes bit-identisch zum JS-Original', () {
      for (final (id, title, longTitle, author, year, _, hash) in _hashVectors) {
        expect(
          srcHashOf(id: id, title: title, longTitle: longTitle, author: author, year: year),
          hash,
          reason: 'Hash für $id',
        );
      }
    });

    test('leerer longTitle fällt auf title zurück (JS ||-Semantik)', () {
      expect(
        srcHashOf(id: 'x', title: 'Titel', longTitle: '', author: 'A', year: 2020),
        srcHashOf(id: 'x', title: 'Titel', author: 'A', year: 2020),
      );
    });

    test('Hash-Muster im Dateinamen finden', () {
      expect(srcHashInFilename('TS-B5B9ACA8.pdf'), 'ts-b5b9aca8');
      expect(srcHashInFilename('paper_final.pdf'), isNull);
    });
  });
}
