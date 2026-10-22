using System.Net;
using System.Net.Mail;
using Microsoft.Extensions.Configuration;

public class EmailService : IEmailService
{
    private readonly IConfiguration _configuration;

    public EmailService(IConfiguration configuration)
    {
        _configuration = configuration;
    }

    public async Task SendEmailAsync(string email, string subject, string message)
    {
        // Đọc cấu hình từ tệp appsettings.json
        var emailSettings = _configuration.GetSection("EmailSettings");
        var server = emailSettings["Server"];
        var port = int.Parse(emailSettings["Port"] ?? "587");
        var senderName = emailSettings["SenderName"];
        var senderEmail = emailSettings["SenderEmail"];
        var password = emailSettings["Password"];

        using var client = new SmtpClient(server, port)
        {
            Credentials = new NetworkCredential(senderEmail, password),
            EnableSsl = true,
        };

        var mailMessage = new MailMessage
        {
            From = new MailAddress(senderEmail!, senderName),
            Subject = subject,
            Body = message,
            IsBodyHtml = true, // Cho phép sử dụng định dạng HTML cho nội dung email (gửi mã OTP đẹp mắt)
        };

        mailMessage.To.Add(email);

        await client.SendMailAsync(mailMessage);
    }
}