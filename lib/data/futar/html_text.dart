/// A zavar-szövegek egyszerű HTML-t tartalmaznak (`<p>`, `<ul><li>`,
/// `<strong>`); ezt sima szöveggé alakítjuk: listaelem → „• ", bekezdés és
/// sortörés → új sor, a többi tag eltűnik, a gyakori entitások feloldódnak.
String htmlToText(String html) {
  var text = html
      .replaceAll(RegExp(r'<li[^>]*>', caseSensitive: false), '\n• ')
      .replaceAll(
        RegExp(r'<br\s*/?>|</p>|</li>|</ul>', caseSensitive: false),
        '\n',
      )
      .replaceAll(RegExp(r'<[^>]*>'), '');
  const entities = {
    '&nbsp;': ' ',
    '&lt;': '<',
    '&gt;': '>',
    '&quot;': '"',
    '&#39;': "'",
    '&amp;': '&', // utoljára, hogy a `&amp;lt;` ne legyen `<`
  };
  entities.forEach((entity, char) => text = text.replaceAll(entity, char));
  return text
      .split('\n')
      .map((line) => line.replaceAll(RegExp(r'[ \t]+'), ' ').trim())
      .where((line) => line.isNotEmpty)
      .join('\n');
}
