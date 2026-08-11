"""email_service.py — server-side transactional email via Gmail SMTP.

Password-reset email must be sent by the backend, not the client: only the
server can prove a request actually reached the account's inbox before a
reset token becomes usable. smtplib is blocking, so sends run in a thread.
"""

from __future__ import annotations

import asyncio
import logging
import smtplib
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText

from app.config import settings

logger = logging.getLogger(__name__)

_SMTP_HOST = "smtp.gmail.com"
_SMTP_PORT = 465


def _build_reset_email_html(user_name: str, reset_link: str) -> str:
    return f"""\
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
                Hello {user_name},
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
              <a href="{reset_link}"
                 style="display: inline-block; background-color: #FF6A00; color: #ffffff !important; text-decoration: none !important; padding: 14px 32px; border-radius: 24px; font-size: 16px; font-weight: 600;">
                Reset Password
              </a>
            </td>
          </tr>
          <tr>
            <td style="padding-bottom: 20px;">
              <p style="color: #90909A; font-size: 14px; line-height: 1.6; margin: 0 0 10px 0;">
                <strong>Note:</strong> If the button above doesn't work, copy the link below, open it on the <strong>same phone</strong> where MyFoodRx is installed (Safari or Chrome):
              </p>
              <div style="background-color: #F7F7F8; padding: 12px; border-radius: 8px; margin: 10px 0;">
                <p style="color: #2C2C2C; font-size: 13px; line-height: 1.6; margin: 0; word-break: break-all; font-family: monospace;">
                  {reset_link}
                </p>
              </div>
              <p style="color: #90909A; font-size: 12px; line-height: 1.6; margin: 10px 0 0 0;">
                That page will try to open the app. If it doesn't, use the "Open MyFoodRx" button on that page.
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
"""


def _build_google_notice_email_html(user_name: str) -> str:
    return f"""\
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>About Your MyFoodRx Account</title>
</head>
<body style="margin: 0; padding: 0; font-family: Arial, sans-serif; background-color: #f7f7f8;">
  <table role="presentation" style="width: 100%; border-collapse: collapse;">
    <tr>
      <td style="padding: 40px 20px; text-align: center;">
        <table role="presentation" style="max-width: 600px; margin: 0 auto; background-color: #ffffff; border-radius: 12px; padding: 40px;">
          <tr>
            <td style="text-align: center; padding-bottom: 30px;">
              <h1 style="color: #2C2C2C; font-size: 24px; margin: 0; font-weight: bold;">About Your MyFoodRx Account</h1>
            </td>
          </tr>
          <tr>
            <td style="padding-bottom: 20px;">
              <p style="color: #545454; font-size: 16px; line-height: 1.6; margin: 0;">
                Hello {user_name},
              </p>
            </td>
          </tr>
          <tr>
            <td style="padding-bottom: 20px;">
              <p style="color: #545454; font-size: 16px; line-height: 1.6; margin: 0;">
                We received a password reset request for this email address. This MyFoodRx account signs in with <strong>Google Sign-In</strong> and doesn't have a password to reset.
              </p>
            </td>
          </tr>
          <tr>
            <td style="padding-bottom: 20px;">
              <p style="color: #545454; font-size: 16px; line-height: 1.6; margin: 0;">
                To sign in, open MyFoodRx and tap <strong>"Continue with Google"</strong> instead.
              </p>
            </td>
          </tr>
          <tr>
            <td style="padding-top: 30px; border-top: 1px solid #E7E9EC;">
              <p style="color: #90909A; font-size: 12px; line-height: 1.6; margin: 0;">
                <strong>Security Notice:</strong> If you didn't request this, please ignore this email or contact support if you have concerns.
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
"""


def _send_sync(to_email: str, subject: str, html: str) -> None:
    message = MIMEMultipart("alternative")
    message["Subject"] = subject
    message["From"] = f"{settings.email_from_name} <{settings.gmail_user}>"
    message["To"] = to_email
    message.attach(MIMEText(html, "html"))

    with smtplib.SMTP_SSL(_SMTP_HOST, _SMTP_PORT, timeout=10) as server:
        server.login(settings.gmail_user, settings.gmail_app_password)
        server.sendmail(settings.gmail_user, [to_email], message.as_string())


async def _send(to_email: str, subject: str, html: str) -> bool:
    """Shared send path. Never raises — callers keep /forgot-password's
    response generic regardless of delivery outcome, so a failed send here
    must not surface as an API error."""
    if not settings.gmail_user or not settings.gmail_app_password:
        logger.warning(
            "Email not sent (%s): GMAIL_USER/GMAIL_APP_PASSWORD not configured "
            "(set them in backend/.env or the deployment's env vars).",
            subject,
        )
        return False
    try:
        await asyncio.to_thread(_send_sync, to_email, subject, html)
        return True
    except Exception:
        logger.exception("Failed to send email (%s) to %s", subject, to_email)
        return False


async def send_password_reset_email(
    email: str, reset_link: str, user_name: str | None = None
) -> bool:
    """Send the password-reset email."""
    html = _build_reset_email_html(user_name or "there", reset_link)
    return await _send(email, "Reset Your Password - MyFoodRx", html)


async def send_google_signin_notice_email(
    email: str, user_name: str | None = None
) -> bool:
    """Tell a Google-linked account holder to use Google Sign-In instead of a
    password reset — sent in place of a reset token/link, which this account
    type must never receive."""
    html = _build_google_notice_email_html(user_name or "there")
    return await _send(email, "About Your MyFoodRx Account", html)
