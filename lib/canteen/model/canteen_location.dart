class CanteenLocation {
  final String id;
  final String name;
  final String? subtitle;
  final CanteenLocationSource source;
  final int? openMensaId;

  const CanteenLocation({
    required this.id,
    required this.name,
    required this.source,
    this.subtitle,
    this.openMensaId,
  });

  bool get isKarlsruheLegacy => source == CanteenLocationSource.karlsruheLegacy;
}

enum CanteenLocationSource {
  karlsruheLegacy,
  openMensa,
}

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
      id: 'mannheim_dhbw_eppelheim',
      name: 'DHBW Mannheim',
      subtitle: 'Mensa DHBW Eppelheim',
      source: CanteenLocationSource.openMensa,
      openMensaId: 795,
    ),
    CanteenLocation(
      id: 'horb_dhbw_stuttgart',
      name: 'DHBW Horb',
      subtitle: 'Campus Horb',
      source: CanteenLocationSource.openMensa,
      openMensaId: 923,
    ),
  ];

  static const CanteenLocation defaultLocation = CanteenLocation(
    id: karlsruheId,
    name: 'DHBW Karlsruhe',
    subtitle: 'Mensa Erzbergerstrasse',
    source: CanteenLocationSource.karlsruheLegacy,
  );

  static CanteenLocation fromId(String? id) {
    if (id == null || id.isEmpty) {
      return defaultLocation;
    }

    for (final location in supported) {
      if (location.id == id) {
        return location;
      }
    }

    return defaultLocation;
  }
}
