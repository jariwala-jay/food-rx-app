import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:flutter_app/core/services/email_service.dart';

/// Gmail SMTP implementation of EmailService
/// This is completely free, doesn't require a domain, and works server-side
/// Requires Gmail app password setup (see EMAIL_SETUP.md)
class GmailSMTPEmailService implements EmailService {
  GmailSMTPEmailService();

  @override
  Future<bool> sendPasswordResetEmail({
    required String email,
    required String resetToken,
    String? userName,
  }) async {
    try {
      // Get Gmail credentials from environment
      final gmailUser = dotenv.env['GMAIL_USER'];
      final gmailPassword = dotenv.env['GMAIL_APP_PASSWORD'];

      if (gmailUser == null || gmailUser.isEmpty) {
        throw Exception('GMAIL_USER is missing in .env file. '
            'Please add your Gmail address (e.g., yourname@gmail.com)');
      }
      if (gmailPassword == null || gmailPassword.isEmpty) {
        throw Exception('GMAIL_APP_PASSWORD is missing in .env file. '
            'Please generate an app password from your Google Account settings. '
            'See EMAIL_SETUP.md for instructions.');
      }

      // Get the app URL from environment or use default deep link scheme
      final appUrl = dotenv.env['APP_URL'] ?? 'foodrx://reset-password';
      // URL encode the token to ensure it works in email links
      final encodedToken = Uri.encodeComponent(resetToken);
      final resetLink = '$appUrl?token=$encodedToken';

      // Get sender name from environment
      final fromName = dotenv.env['EMAIL_FROM_NAME'] ?? 'MyFoodRx';
      final displayName = userName ?? 'User';

      // Create Gmail SMTP server
      final smtpServer = gmail(gmailUser, gmailPassword);

      // Build email message
      final message = Message()
        ..from = Address(gmailUser, fromName)
        ..recipients.add(email)
        ..subject = 'Reset Your Password - MyFoodRx'
        ..html = _buildPasswordResetEmailBody(displayName, resetLink);

      // Send email
      try {
        final sendReport = await send(message, smtpServer);
        return sendReport.toString().contains('Message successfully sent');
      } catch (e) {
        // Check for specific Gmail errors
        if (e.toString().contains('535') ||
            e.toString().contains('authentication')) {
          throw Exception(
              'Gmail authentication failed. Please check your GMAIL_APP_PASSWORD. '
              'Make sure you\'re using an App Password, not your regular Gmail password. '
              'See EMAIL_SETUP.md for setup instructions.');
        }
        rethrow;
      }
    } catch (e) {
      throw Exception('Failed to send password reset email: $e');
    }
  }

  String _buildPasswordResetEmailBody(String userName, String resetLink) {
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Reset Your Password</title>
</head>
<body style="margin: 0; padding: 0; font-family: Arial, sans-serif; background-color: #f7f7f8;">
  <table role="presentation" style="width: 100%; border-collapse: collapse;">
    <tr>
      <td style="padding: 40px 20px; text-align: center;">
        <table role="presentation" style="max-width: 600px; margin: 0 auto; background-color: #ffffff; border-radius: 12px; padding: 40px;">
          <tr>
            <td style="text-align: center; padding-bottom: 30px;">
              <h1 style="color: #2C2C2C; font-size: 24px; margin: 0; font-weight: bold;">Reset Your Password</h1>
            </td>
          </tr>
          <tr>
            <td style="padding-bottom: 20px;">
              <p style="color: #545454; font-size: 16px; line-height: 1.6; margin: 0;">
                Hello $userName,
              </p>
            </td>
          </tr>
          <tr>
            <td style="padding-bottom: 30px;">
              <p style="color: #545454; font-size: 16px; line-height: 1.6; margin: 0;">
                We received a request to reset your password. Click the button below to create a new password:
              </p>
            </td>
          </tr>
          <tr>
            <td style="padding-bottom: 20px; text-align: center;">
              <a href="$resetLink" 
                 style="display: inline-block; background-color: #FF6A00; color: #ffffff !important; text-decoration: none !important; padding: 14px 32px; border-radius: 24px; font-size: 16px; font-weight: 600;">
                Reset Password
              </a>
            </td>
          </tr>
          <tr>
            <td style="padding-bottom: 20px;">
              <p style="color: #90909A; font-size: 14px; line-height: 1.6; margin: 0 0 10px 0;">
                <strong>Note:</strong> If the button above doesn't work, copy the link below and paste it into your mobile browser (Chrome, Safari, etc.):
              </p>
              <div style="background-color: #F7F7F8; padding: 12px; border-radius: 8px; margin: 10px 0;">
                <p style="color: #2C2C2C; font-size: 13px; line-height: 1.6; margin: 0; word-break: break-all; font-family: monospace;">
                  $resetLink
                </p>
              </div>
              <p style="color: #90909A; font-size: 12px; line-height: 1.6; margin: 10px 0 0 0;">
                After pasting in your browser, tap the link and your MyFoodRx app will open automatically.
              </p>
            </td>
          </tr>
          <tr>
            <td style="padding-top: 30px; border-top: 1px solid #E7E9EC;">
              <p style="color: #90909A; font-size: 12px; line-height: 1.6; margin: 0;">
                <strong>Security Notice:</strong> This link will expire in 1 hour. If you didn't request a password reset, please ignore this email or contact support if you have concerns.
              </p>
            </td>
          </tr>
          <tr>
            <td style="padding-top: 20px;">
              <p style="color: #90909A; font-size: 12px; line-height: 1.6; margin: 0;">
                Best regards,<br>
                MyFoodRx Team
              </p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>
''';
  }
}
