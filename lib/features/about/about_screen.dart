import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// A BKK-adatok forrásmegjelölése (CC BY 4.0, kötelező).
const dataAttribution =
    'Adatforrás: BKK Zrt. – BKK FUTÁR (opendata.bkk.hu), '
    'CC BY 4.0 licenc alatt. Az adatokat az app átalakítja '
    '(szűrés, rendezés, időpont-formázás).';

const _ccBy40 =
    'A BKK FUTÁR nyílt adatai a Creative Commons Nevezd meg! 4.0 Nemzetközi '
    '(CC BY 4.0) licenc alatt érhetők el.\n\n'
    'Forrás: BKK Zrt., https://opendata.bkk.hu\n'
    'Licenc: https://creativecommons.org/licenses/by/4.0/\n\n'
    'Az Indulj az adatokat szűri, rendezi és átalakítja; a BKK nem támogatja '
    'és nem hagyta jóvá az appot.';

/// A licenclistába (showLicensePage) a BKK-adatok bejegyzése.
void registerDataLicense() => LicenseRegistry.addLicense(
  () => Stream.value(
    const LicenseEntryWithLineBreaks(['BKK FUTÁR nyílt adatok'], _ccBy40),
  ),
);

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Névjegy')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Indulj', style: text.headlineSmall),
          const SizedBox(height: 4),
          const Text(
            'BKK indulási widget és tábla 1–3 kedvenc megállócsoporthoz.',
          ),
          const SizedBox(height: 24),
          Text('Adatforrás', style: text.titleMedium),
          const SizedBox(height: 4),
          const SelectableText(dataAttribution),
          const SizedBox(height: 24),
          Text('Miért nem „valós idejű" a widget?', style: text.titleMedium),
          const SizedBox(height: 4),
          const Text(
            'Az Android ritkán engedi frissíteni a kezdőképernyő-widgeteket '
            '(15–30 percenként). Ezért a widget abszolút időpontot mutat '
            '(„14:37"), ami legfeljebb elavul, de nem lesz hamis; alul látszik, '
            'mikor frissült. Az első sor natív visszaszámlálóval jár. '
            'Friss adatért koppints a ⟳-ra, vagy nyisd meg az appot.',
          ),
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: () => showLicensePage(
              context: context,
              applicationName: 'Indulj',
              applicationLegalese: dataAttribution,
            ),
            child: const Text('Licencek'),
          ),
        ],
      ),
    );
  }
}
