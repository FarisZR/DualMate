import 'package:dhbwstudentapp/canteen/service/allergen_legend.dart';
import 'package:test/test.dart';

void main() {
  test('Allergen legend resolves known codes', () {
    expect(AllergenLegend.resolve('Se'), 'Sellerie');
    expect(AllergenLegend.resolve('Sf'), 'Schwefeldioxid/Sulfit');
    expect(AllergenLegend.resolve('GEL'), 'mit Gelatine');
  });

  test('Allergen legend returns null for unknown codes', () {
    expect(AllergenLegend.resolve('XYZ'), isNull);
  });
}
