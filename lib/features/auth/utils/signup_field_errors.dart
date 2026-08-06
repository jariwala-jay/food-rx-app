/// Set of field keys; [mark] / [show] gate inline errors on non-[TextFormField] inputs.
class SignupFieldErrors {
  final Set<String> _fields = {};

  bool show(String field) => _fields.contains(field);

  void mark(Iterable<String> fields) => _fields.addAll(fields);

  void clear(String field) => _fields.remove(field);

  void clearAll() => _fields.clear();
}
