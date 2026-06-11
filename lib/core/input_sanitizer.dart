import 'package:flutter/foundation.dart';

/// Input sanitization utility to prevent injection attacks and XSS
class InputSanitizer {
  /// SQL injection patterns to block
  static const List<String> _sqlPatterns = [
    r"(?i)(\b(UNION|SELECT|INSERT|UPDATE|DELETE|DROP|CREATE|ALTER|EXEC|EXECUTE|SCRIPT)\b)",
    r"(?i)(-{2}|/\*|\*/|xp_|sp_)",
    r"""(?i)(['"])\s*(OR|AND)\s*(['"]|\d|true|false)""",
  ];

  /// XSS patterns to block
  static const List<String> _xssPatterns = [
    r"(?i)(<\s*script[^>]*>|</\s*script\s*>)",
    r"(?i)(on\w+\s*=)",
    r"(?i)(javascript:|onerror:|onload:)",
    r"(?i)(<\s*iframe|<\s*embed|<\s*object)",
  ];

  /// Special characters that should be escaped
  static const Map<String, String> _escapeMap = {
    '&': '&amp;',
    '<': '&lt;',
    '>': '&gt;',
    '"': '&quot;',
    "'": '&#x27;',
  };

  /// Sanitize email input
  static String sanitizeEmail(String email) {
    email = email.trim().toLowerCase();
    
    // Validate email format
    final emailRegex = RegExp(
      r"""^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$""",
    );
    
    if (!emailRegex.hasMatch(email)) {
      throw FormatException('Invalid email format');
    }
    
    return email;
  }

  /// Sanitize password (validate strength, not modify)
  static void validatePassword(String password) {
    if (password.length < 8) {
      throw FormatException('Password must be at least 8 characters');
    }
    if (!password.contains(RegExp(r'[A-Z]'))) {
      throw FormatException('Password must contain uppercase letter');
    }
    if (!password.contains(RegExp(r'[a-z]'))) {
      throw FormatException('Password must contain lowercase letter');
    }
    if (!password.contains(RegExp(r'[0-9]'))) {
      throw FormatException('Password must contain number');
    }
    if (!password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
      throw FormatException('Password must contain special character');
    }
  }

  /// Sanitize text input to prevent SQL injection
  static String sanitizeSqlInput(String input) {
    input = input.trim();
    
    // Check for SQL injection patterns
    for (final pattern in _sqlPatterns) {
      if (RegExp(pattern).hasMatch(input)) {
        throw FormatException('Invalid input detected');
      }
    }
    
    // Escape single quotes
    input = input.replaceAll("'", "''");
    
    return input;
  }

  /// Sanitize text input to prevent XSS
  static String sanitizeXssInput(String input) {
    input = input.trim();
    
    // Check for XSS patterns
    for (final pattern in _xssPatterns) {
      if (RegExp(pattern).hasMatch(input)) {
        throw FormatException('Invalid input detected');
      }
    }
    
    // HTML encode special characters
    _escapeMap.forEach((key, value) {
      input = input.replaceAll(key, value);
    });
    
    return input;
  }

  /// Sanitize general user input (both SQL and XSS)
  static String sanitizeUserInput(String input) {
    input = input.trim();
    
    // Remove null bytes
    input = input.replaceAll('\u0000', '');
    
    // Limit length
    if (input.length > 1000) {
      input = input.substring(0, 1000);
    }
    
    // Check for SQL injection
    if (_hasSqlInjection(input)) {
      throw FormatException('Invalid input detected');
    }
    
    // Check for XSS
    if (_hasXss(input)) {
      throw FormatException('Invalid input detected');
    }
    
    return input;
  }

  /// Sanitize phone number
  static String sanitizePhoneNumber(String phone) {
    phone = phone.replaceAll(RegExp(r'[^\d+\-\s()]'), '');
    
    if (phone.isEmpty) {
      throw FormatException('Invalid phone number');
    }
    
    return phone;
  }

  /// Sanitize URL
  static String sanitizeUrl(String url) {
    // Only allow http and https
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      throw FormatException('URL must start with http:// or https://');
    }
    
    // Prevent javascript protocol
    if (url.toLowerCase().contains('javascript:')) {
      throw FormatException('Invalid URL');
    }
    
    return url;
  }

  /// Check if input contains SQL injection
  static bool _hasSqlInjection(String input) {
    for (final pattern in _sqlPatterns) {
      if (RegExp(pattern).hasMatch(input)) {
        return true;
      }
    }
    return false;
  }

  /// Check if input contains XSS
  static bool _hasXss(String input) {
    for (final pattern in _xssPatterns) {
      if (RegExp(pattern).hasMatch(input)) {
        return true;
      }
    }
    return false;
  }

  /// Validate input length
  static void validateLength(String input, int minLength, int maxLength) {
    final length = input.trim().length;
    if (length < minLength || length > maxLength) {
      throw FormatException('Input length must be between $minLength and $maxLength');
    }
  }

  /// Check if input contains only safe characters
  static bool isSafeInput(String input) {
    return !_hasSqlInjection(input) && !_hasXss(input);
  }

  /// Sanitize filename
  static String sanitizeFilename(String filename) {
    // Remove path traversal attempts
    filename = filename.replaceAll(RegExp(r'\.\.'), '');
    filename = filename.replaceAll(RegExp(r'[/\\]'), '');
    
    // Remove special characters except dots and dashes
    filename = filename.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '');
    
    if (filename.isEmpty) {
      throw FormatException('Invalid filename');
    }
    
    return filename;
  }
}
