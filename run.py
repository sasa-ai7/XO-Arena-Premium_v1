import re
path = r'e:\work\xo-main\lib\main.dart'
with open(path, 'r', encoding='utf-8') as f:
    c = f.read()
original = c
c = re.sub(r' +Future<void> _buyCustom[XO]\(\) async \{(.*?)\n  \}\n\n', '', c, flags=re.DOTALL)
c = re.sub(r' +Future<Map<String, dynamic>\?> _showCustomColorDialog\(\{.*?\n  \}\n\n', '', c, flags=re.DOTALL)
c = re.sub(r'class _CustomColorTile extends StatelessWidget \{.*?(?=class GlowXPainter)', '\n', c, flags=re.DOTALL)
c = re.sub(r' +if \(i == colors\.length\) \{.*?(return _CustomColorTile\(.*?\);).*?\}', '', c, flags=re.DOTALL)
c = re.sub(r'itemCount: colors\.length \+ 1,', 'itemCount: colors.length,', c)
c = re.sub(r'\} else \{\s*final customConfig = _custom[XO]Configs\[index - _owned[XO]\.length\];.*?_applyCustom[XO]\(hex\),\s*\);?\s*\}', '', c, flags=re.DOTALL)
c = re.sub(r'itemCount: _owned[XO]\.length \+ _custom[XO]Configs\.length,', 'itemCount: _ownedX.length,', c)
c = c.replace('itemCount: _ownedO.length,', 'itemCount: _ownedO.length,')
with open(path, 'w', encoding='utf-8') as f:
    f.write(c)
print(f'Done! Removed {len(original) - len(c)} characters')
