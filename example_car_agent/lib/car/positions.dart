// Windows and doors by place (port of the RN example's src/car/positions.ts): front_left / front_right / rear_left / rear_right,
// the relative driver / passenger (resolved from the car's steering-wheel side, never assumed), the sides front / rear / left /
// right, and all. Pure functions (the language is a parameter) so the replies can be tested without the app.

const positions = ['front_left', 'front_right', 'rear_left', 'rear_right'];

/// The physical positions a target means in this car, or null for a value the car doesn't know.
List<String>? resolvePositions(Object? target, String steering) {
  final t = (target == null || target == '') ? 'all' : target.toString();
  final driver = steering == 'right' ? 'front_right' : 'front_left';
  final passenger = steering == 'right' ? 'front_left' : 'front_right';
  switch (t) {
    case 'all':
      return [...positions];
    case 'driver':
      return [driver];
    case 'passenger':
      return [passenger];
    case 'front':
      return ['front_left', 'front_right'];
    case 'rear':
      return ['rear_left', 'rear_right'];
    case 'left':
      return ['front_left', 'rear_left'];
    case 'right':
      return ['front_right', 'rear_right'];
    default:
      return positions.contains(t) ? [t] : null;
  }
}

/// How the reply names it: the user's own words for the target (driver stays "the driver's window", not a place).
class PositionName {
  const PositionName(this.text, {required this.plural, required this.fem});
  final String text;
  final bool plural;
  final bool fem;
}

const _enOne = {
  'driver': "the driver's", 'passenger': 'the passenger', 'front_left': 'the front left', 'front_right': 'the front right',
  'rear_left': 'the rear left', 'rear_right': 'the rear right',
};
const _enMany = {'all': 'all the', 'front': 'the front', 'rear': 'the rear', 'left': 'the left', 'right': 'the right'};
const _ptPlace = {
  'front_left': ['dianteiro esquerdo', 'dianteira esquerda'], 'front_right': ['dianteiro direito', 'dianteira direita'],
  'rear_left': ['traseiro esquerdo', 'traseira esquerda'], 'rear_right': ['traseiro direito', 'traseira direita'],
};
const _ptSide = {'front': 'da frente', 'rear': 'de trás', 'left': 'do lado esquerdo', 'right': 'do lado direito'};

/// [obj] is 'window' or 'door'; [lang] 'en' or 'pt-BR'.
PositionName positionName(Object? target, String obj, String lang) {
  final t = (target == null || target == '') ? 'all' : target.toString();
  final fem = lang == 'pt-BR' && obj == 'door';
  if (lang != 'pt-BR') {
    if (_enMany.containsKey(t)) return PositionName('${_enMany[t]} ${obj}s', plural: true, fem: fem);
    return PositionName('${_enOne[t] ?? 'the'} $obj', plural: false, fem: fem);
  }
  final noun = obj == 'door' ? 'porta' : 'vidro';
  if (t == 'all') return PositionName(fem ? 'todas as portas' : 'todos os vidros', plural: true, fem: fem);
  if (_ptSide.containsKey(t)) return PositionName('${fem ? 'as' : 'os'} ${noun}s ${_ptSide[t]}', plural: true, fem: fem);
  if (t == 'driver' || t == 'passenger') {
    return PositionName('${fem ? 'a' : 'o'} $noun do ${t == 'driver' ? 'motorista' : 'passageiro'}', plural: false, fem: fem);
  }
  final place = _ptPlace[t];
  if (place != null) return PositionName('${fem ? 'a' : 'o'} $noun ${place[fem ? 1 : 0]}', plural: false, fem: fem);
  return PositionName('${fem ? 'a' : 'o'} $noun', plural: false, fem: fem);
}

/// pt-BR adjective agreement: adj('fechad', n) -> fechado / fechada / fechados / fechadas.
String adj(String stem, PositionName n) => stem + (n.fem ? 'a' : 'o') + (n.plural ? 's' : '');
String cap(String t) => t.isEmpty ? t : t[0].toUpperCase() + t.substring(1);

/// "is" / "are", "está" / "estão".
String be(PositionName n, String lang) => lang != 'pt-BR' ? (n.plural ? 'are' : 'is') : (n.plural ? 'estão' : 'está');
