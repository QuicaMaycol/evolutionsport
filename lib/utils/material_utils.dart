// Utilidades relacionadas con materiales de ejercicios

// Detecta si value ya existe en la lista de materiales, considerando un índice a excluir
bool isDuplicateMaterial(List<String> materials, String value, {int? excludeIndex}) {
  final trimmedValue = value.trim();
  if (trimmedValue.isEmpty) return false;

  for (int i = 0; i < materials.length; i++) {
    if (excludeIndex != null && i == excludeIndex) continue;
    if (materials[i].trim() == trimmedValue) return true;
  }
  return false;
}
