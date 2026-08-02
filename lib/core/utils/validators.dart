class Validators {
  Validators._();

  static final RegExp _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  // Matches the backend's Zod regex for file/folder names.
  static final RegExp _invalidNameChars = RegExp(r'[/\\:*?"<>|]');

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) return 'Email is required';
    if (!_emailRegex.hasMatch(value.trim())) return 'Enter a valid email address';
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (value.length < 6) return 'Password must be at least 6 characters';
    return null;
  }

  static String? confirmPassword(String? value, String original) {
    if (value != original) return 'Passwords do not match';
    return null;
  }

  static String? itemName(String? value) {
    if (value == null || value.trim().isEmpty) return 'Name is required';
    final trimmed = value.trim();
    if (trimmed.length > 255) return 'Name is too long';
    if (_invalidNameChars.hasMatch(trimmed)) {
      return 'Name can\'t contain / \\ : * ? " < > |';
    }
    return null;
  }
}
