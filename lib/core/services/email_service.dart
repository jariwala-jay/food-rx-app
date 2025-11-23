/// Abstract interface for email services
abstract class EmailService {
  /// Send a password reset email to the user
  /// 
  /// [email] - Recipient email address
  /// [resetToken] - The password reset token to include in the link
  /// [userName] - Optional user name for personalization
  /// 
  /// Returns true if email was sent successfully, false otherwise
  Future<bool> sendPasswordResetEmail({
    required String email,
    required String resetToken,
    String? userName,
  });
}


