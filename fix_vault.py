import re

FILE_PATH = r'e:\work\xo-main\lib\main.dart'

with open(FILE_PATH, 'r', encoding='utf-8') as f:
    content = f.read()

original_content = content

# 10. Replace the _VaultTile class
vault_tile_pattern = r'class _VaultTile extends StatelessWidget \{.*?(?=class _StorePainter|class [A-Z])'
new_vault_tile = '''class _VaultTile extends StatelessWidget {
  final Color color;
  final bool isX;
  final bool isSelected;
  final VoidCallback? onTap;

  const _VaultTile({
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
}
'''
import re
content = re.sub(vault_tile_pattern, new_vault_tile, content, flags=re.DOTALL)

with open(FILE_PATH, 'w', encoding='utf-8') as f:
    f.write(content)
