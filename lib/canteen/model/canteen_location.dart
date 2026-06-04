class CanteenLocation {
  final String id;
  final String name;
  final String? subtitle;
  final CanteenLocationSource source;
  final int? openMensaId;
  final String? dhbwAppSite;
  final int? dhbwAppMensaId;

  const CanteenLocation({
    required this.id,
    required this.name,
    required this.source,
    this.subtitle,
    this.openMensaId,
    this.dhbwAppSite,
    this.dhbwAppMensaId,
  });

  bool get isKarlsruheLegacy => source == CanteenLocationSource.karlsruheLegacy;
}

enum CanteenLocationSource { karlsruheLegacy, openMensa, dhbwApp }

class CanteenLocations {
  static const String karlsruheId = 'karlsruhe_erzbergerstrasse';

  static const List<CanteenLocation> supported = <CanteenLocation>[
    CanteenLocation(
      id: karlsruheId,
      name: 'DHBW Karlsruhe',
      subtitle: 'Mensa Erzbergerstrasse',
      source: CanteenLocationSource.karlsruheLegacy,
    ),
    CanteenLocation(
      id: 'heilbronn_bildungscampus',
      name: 'DHBW CAS / Heilbronn',
      subtitle: 'Mensa am Bildungscampus',
      source: CanteenLocationSource.dhbwApp,
      dhbwAppSite: 'CAS',
      dhbwAppMensaId: 4,
    ),
    CanteenLocation(
      id: 'mannheim_mensaria_metropol',
      name: 'DHBW Mannheim',
      subtitle: 'Mensaria Metropol',
      source: CanteenLocationSource.dhbwApp,
      dhbwAppSite: 'MA',
      dhbwAppMensaId: 5,
    ),
    CanteenLocation(
      id: 'mannheim_mensaria_wohlgelegen',
      name: 'DHBW Mannheim',
      subtitle: 'Mensaria Wohlgelegen',
      source: CanteenLocationSource.dhbwApp,
      dhbwAppSite: 'MA',
      dhbwAppMensaId: 6,
    ),
    CanteenLocation(
      id: 'mannheim_dhbw_eppelheim',
      name: 'DHBW Mannheim',
      subtitle: 'Speisenausgabe DHBW Eppelheim',
      source: CanteenLocationSource.dhbwApp,
      dhbwAppSite: 'MA',
      dhbwAppMensaId: 7,
    ),
    CanteenLocation(
      id: 'mosbach_tannenhof',
      name: 'DHBW Mosbach',
      subtitle: 'Mensa by Tannenhof',
      source: CanteenLocationSource.dhbwApp,
      dhbwAppSite: 'MOS',
      dhbwAppMensaId: 1,
    ),
    CanteenLocation(
      id: 'stuttgart_central',
      name: 'DHBW Stuttgart',
      subtitle: 'Mensa Central',
      source: CanteenLocationSource.dhbwApp,
      dhbwAppSite: 'STG',
      dhbwAppMensaId: 8,
    ),
    CanteenLocation(
      id: 'ravensburg',
      name: 'DHBW Ravensburg',
      subtitle: 'Mensa Ravensburg',
      source: CanteenLocationSource.dhbwApp,
      dhbwAppSite: 'RV',
      dhbwAppMensaId: 11,
    ),
    CanteenLocation(
      id: 'villingen_schwenningen',
      name: 'DHBW Villingen-Schwenningen',
      subtitle: 'Mensa Schwenningen',
      source: CanteenLocationSource.dhbwApp,
      dhbwAppSite: 'VS',
      dhbwAppMensaId: 2,
    ),
    CanteenLocation(
      id: 'loerrach',
      name: 'DHBW Lörrach',
      subtitle: 'Mensa Lörrach',
      source: CanteenLocationSource.dhbwApp,
      dhbwAppSite: 'LÖR',
      dhbwAppMensaId: 3,
    ),
    CanteenLocation(
      id: 'horb',
      name: 'DHBW Horb',
      subtitle: 'Mensa Horb',
      source: CanteenLocationSource.dhbwApp,
      dhbwAppSite: 'HORB',
      dhbwAppMensaId: 9,
    ),
    CanteenLocation(
      id: 'heidenheim',
      name: 'DHBW Heidenheim',
      subtitle: 'Mensa DHBW Heidenheim',
      source: CanteenLocationSource.dhbwApp,
      dhbwAppSite: 'HDH',
      dhbwAppMensaId: 13,
    ),
    CanteenLocation(
      id: 'friedrichshafen_fallenbrunnen',
      name: 'DHBW Friedrichshafen',
      subtitle: 'Mensa Fallenbrunnen',
      source: CanteenLocationSource.dhbwApp,
      dhbwAppSite: 'FN',
      dhbwAppMensaId: 10,
    ),
    CanteenLocation(
      id: 'karlsruhe_dhbw_app_erzbergerstrasse',
      name: 'DHBW Karlsruhe',
      subtitle: 'Mensa Erzbergerstraße (dhbw.app)',
      source: CanteenLocationSource.dhbwApp,
      dhbwAppSite: 'KA',
      dhbwAppMensaId: 12,
    ),
  ];

  static const CanteenLocation defaultLocation = CanteenLocation(
    id: karlsruheId,
    name: 'DHBW Karlsruhe',
    subtitle: 'Mensa Erzbergerstrasse',
    source: CanteenLocationSource.karlsruheLegacy,
  );

  static CanteenLocation? supportedFromId(String? id) {
    if (id == null || id.isEmpty) {
      return null;
    }

    for (final location in supported) {
      if (location.id == id) {
        return location;
      }
    }

    return null;
  }

  static CanteenLocation fromId(String? id) {
    return supportedFromId(id) ?? defaultLocation;
  }
}
