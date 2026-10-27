import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

void main() {
  test('English and German date data initializes locally', () async {
    await initializeDateFormatting();
    final date = DateTime(2026, 4, 13);
    expect(DateFormat.EEEE('en').format(date), 'Monday');
    expect(DateFormat.EEEE('de').format(date), 'Montag');
    expect(DateFormat.yMMMM('de').format(date), 'April 2026');
  });
}
