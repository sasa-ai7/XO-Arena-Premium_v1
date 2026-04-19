import re
from pathlib import Path

def main():
    dart_file = Path(r'e:\work\xo-main\lib\main.dart')
    
    with open(dart_file, 'r', encoding='utf-8') as f:
        content = f.read()
    
    original_length = len(content)
    
    # 1. Remove addCustomColorConfig and getCustomColorConfigs from LocalStore
    content = re.sub(
        r'  static Future<void> addCustomColorConfig\(bool isX, String name, Color c\) async \{.*?await _syncToFirestore\(\{\'Cosmetics\': payload\}\);\n  \}\n\n',
        '', content, flags=re.DOTALL)
    
    content = re.sub(
        r'  static Future<List<Map<String, dynamic>>> getCustomColorConfigs\(bool isX\) async \{.*?return \[\];\n    \}\n  \}\n\n',
        '', content, flags=re.DOTALL)
    
    # 2. Remove custom color variables from _cosmeticsPayload
    content = re.sub(r',\s*String\? customXConfigs,\s*String\? customOConfigs', '', content)
    content = re.sub(r"\s*'customXConfigsV2': customXConfigs \?\? p\.getString\(Keys\.customXConfigs\) \?\? '\[\]',\n", '', content)
    content = re.sub(r"\s*'customOConfigsV2': customOConfigs \?\? p\.getString\(Keys\.customOConfigs\) \?\? '\[\]',\n", '', content)
    
    # 3. Remove _customXOwned and _customOOwned from StorePage
    content = re.sub(r'\s*bool _customXOwned = false;\n', '', content)
    content = re.sub(r'\s*bool _customOOwned = false;\n', '', content)
    content = re.sub(r'\s*_customXOwned = p\.getBool\(\'customXOwned\'\) \?\? false;\n', '', content)
    content = re.sub(r'\s*_customOOwned = p\.getBool\(\'customOOwned\'\) \?\? false;\n', '', content)
    
    # 4. Remove _buyCustomX and _buyCustomO methods
    content = re.sub(r'  Future<void> _buyCustomX\(\) async \{.*?showTopNotification\(context, \'Crafted \ X!\', color: AppPalette\.success\);\n  \}\n\n', '', content, flags=re.DOTALL)
    content = re.sub(r'  Future<void> _buyCustomO\(\) async \{.*?showTopNotification\(context, \'Crafted \ O!\', color: AppPalette\.success\);\n  \}\n\n', '', content, flags=re.DOTALL)
    
    # 5. Remove _showCustomColorDialog method
    content = re.sub(r'  Future<Map<String, dynamic>\?> _showCustomColorDialog\(\{.*?\n  \}\n\n', '', content, flags=re.DOTALL)
    
    # 6. Remove _CustomColorTile class
    content = re.sub(r'class _CustomColorTile extends StatelessWidget \{.*?(?=class GlowXPainter)', '', content, flags=re.DOTALL)
    
    # 7. Update _ColorsTab constructor calls
    content = re.sub(r',\s*bool customXOwned\s*,', ',', content)
    content = re.sub(r',\s*bool customOOwned\s*,', ',', content)
    content = re.sub(r'required\s*this\.customXOwned\s*,', '', content)
    content = re.sub(r'required\s*this\.customOOwned\s*,', '', content)
    content = re.sub(r'final\s*bool customXOwned\s*;', '', content)
    content = re.sub(r'final\s*bool customOOwned\s*;', '', content)
    content = re.sub(r',\s*Future<void> Function\(\) onBuyCustomX\s*,', ',', content)
    content = re.sub(r',\s*Future<void> Function\(\) onBuyCustomO\s*,', ',', content)
    content = re.sub(r'required\s*this\.onBuyCustomX\s*,', '', content)
    content = re.sub(r'required\s*this\.onBuyCustomO\s*,', '', content)
    content = re.sub(r'final\s*Future<void> Function\(\) onBuyCustomX\s*;', '', content)
    content = re.sub(r'final\s*Future<void> Function\(\) onBuyCustomO\s*;', '', content)
    
    content = re.sub(
        r'_ColorsTab\(\s*ownedX: _ownedX,\s*ownedO: _ownedO,\s*selectedXIndex: _selectedXIndex,\s*selectedOIndex: _selectedOIndex,\s*customXOwned: _customXOwned,\s*customOOwned: _customOOwned,\s*onBuyX: _buyXColor,\s*onBuyO: _buyOColor,\s*onBuyCustomX: _buyCustomX,\s*onBuyCustomO: _buyCustomO,\s*busy: _busy,\s*\)',
        '_ColorsTab(ownedX: _ownedX, ownedO: _ownedO, selectedXIndex: _selectedXIndex, selectedOIndex: _selectedOIndex, onBuyX: _buyXColor, onBuyO: _buyOColor, busy: _busy,)',
        content,
        flags=re.DOTALL
    )
    
    # Custom values in _ColorsTab build
    content = re.sub(r'ownedCount: ownedX\.length \+ \(customXOwned \? 1 : 0\),', 'ownedCount: ownedX.length,', content)
    content = re.sub(r'ownedCount: ownedO\.length \+ \(customOOwned \? 1 : 0\),', 'ownedCount: ownedO.length,', content)
    content = re.sub(r',\s*customOwned: customXOwned', '', content)
    content = re.sub(r',\s*onCustomTap: busy \? null : \(\) => unawaited\(onBuyCustomX\(\)\)', '', content)
    content = re.sub(r',\s*customOwned: customOOwned', '', content)
    content = re.sub(r',\s*onCustomTap: busy \? null : \(\) => unawaited\(onBuyCustomO\(\)\)', '', content)
    
    # 8. Update _ColorSection
    content = re.sub(r'final\s*bool customOwned\s*;', '', content)
    content = re.sub(r'final\s*VoidCallback\? onCustomTap\s*;', '', content)
    content = re.sub(r'required\s*this\.customOwned\s*,', '', content)
    content = re.sub(r'required\s*this\.onCustomTap\s*,', '', content)
    content = re.sub(r'itemCount: colors\.length \+ 1,', 'itemCount: colors.length,', content)
    
    content = re.sub(r'if \(i == colors\.length\) \{.*?return _CustomColorTile\(.*?\);.*?\}', '', content, flags=re.DOTALL)
    
    # 10. Update _VaultTile to be like store
    vault_tile_new = '''class _VaultTile extends StatelessWidget {
  final Color color;
  final bool isX;
  final bool isSelected;
  final VoidCallback? onTap;

  const _VaultTile({
    super.key,
    required this.color,
    required this.isX,
    this.isSelected = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderOpacity = isSelected ? 1.0 : 0.4;
    final borderWidth = isSelected ? 2.5 : 1.2;
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 74,
        height: 74,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: const Color(0xFF141414),
          border: Border.all(
            color: color.withValues(alpha: borderOpacity),
            width: borderWidth,
          ),
          boxShadow: isSelected ? [
            BoxShadow(
              color: color.withValues(alpha: 0.3),
              blurRadius: 15,
              spreadRadius: 2,
            )
          ] : null,
        ),
        child: Center(
          child: SizedBox(
            width: 36,
            height: 36,
            child: isX
                ? CustomPaint(painter: GlowXPainter(color: color))
                : CustomPaint(painter: GlowOPainter(color: color)),
          ),
        ),
      ),
    );
  }
}'''
    
    content = re.sub(r'class _VaultTile extends StatelessWidget \{.*?(?=\nclass _StorePainter)', vault_tile_new + '\n\n', content, flags=re.DOTALL)
    
    # 11. Remove custom color configs from VaultPage
    content = re.sub(r'\s*List<Map<String, dynamic>> _customXConfigs = \[\];\n', '', content)
    content = re.sub(r'\s*List<Map<String, dynamic>> _customOConfigs = \[\];\n', '', content)
    content = re.sub(r'\s*String\? _selectedXCustomHex;\n', '', content)
    content = re.sub(r'\s*String\? _selectedOCustomHex;\n', '', content)
    
    content = re.sub(r'\s*_customXConfigs = await LocalStore\.getCustomColorConfigs\(true\);\n', '', content)
    content = re.sub(r'\s*_customOConfigs = await LocalStore\.getCustomColorConfigs\(false\);\n', '', content)
    
    content = re.sub(r'\s*_selectedXCustomHex = null;\n', '', content)
    content = re.sub(r'\s*_selectedOCustomHex = null;\n', '', content)
    
    # 12. Remove _applyCustomX and _applyCustomO
    content = re.sub(r'  Future<void> _applyCustomX\(String hex\) async \{.*?\}\n\n', '', content, flags=re.DOTALL)
    content = re.sub(r'  Future<void> _applyCustomO\(String hex\) async \{.*?\}\n\n', '', content, flags=re.DOTALL)
    
    with open(dart_file, 'w', encoding='utf-8') as f:
        f.write(content)
        
    print(f'Done! Original: {original_length}, New: {len(content)}. Removed {original_length - len(content)} characters.')

if __name__ == '__main__':
    main()
