/// Form validation shared by login, signup and the story composer.
abstract final class Validate {
  static final RegExp _email = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$');

  static String? name(String? value) {
    final String v = (value ?? '').trim();
    if (v.isEmpty) return 'Please enter your name';
    if (v.length < 2) return 'That name is too short';
    if (v.length > 40) return 'Please use 40 characters or fewer';
    return null;
  }

  static String? email(String? value) {
    final String v = (value ?? '').trim();
    if (v.isEmpty) return 'Please enter your email';
    if (!_email.hasMatch(v)) return 'That email address does not look right';
    return null;
  }

  static String? password(String? value) {
    final String v = value ?? '';
    if (v.isEmpty) return 'Please enter a password';
    if (v.length < 8) return 'Use at least 8 characters';
    if (!v.contains(RegExp('[A-Za-z]')) || !v.contains(RegExp('[0-9]'))) {
      return 'Include at least one letter and one number';
    }
    return null;
  }

  static String? Function(String?) confirmPassword(String Function() original) {
    return (String? value) {
      if ((value ?? '').isEmpty) return 'Please confirm your password';
      if (value != original()) return 'Passwords do not match';
      return null;
    };
  }

  static String? story(String? value) {
    final String v = (value ?? '').trim();
    if (v.length < 40) return 'Please write at least 40 characters';
    if (v.length > 1200) return 'Please keep it under 1200 characters';
    return null;
  }
}
